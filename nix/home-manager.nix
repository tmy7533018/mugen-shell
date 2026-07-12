{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.mugen-shell;
in
{
  options.programs.mugen-shell = {
    enable = lib.mkEnableOption "the mugen-shell desktop (Quickshell + Hyprland)";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.mugen-shell or null;
      defaultText = lib.literalExpression "pkgs.mugen-shell";
      description = "The mugen-shell QML package (UI tree, scripts, assets).";
    };

    includeSystemDeps = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to install mugen-shell's runtime dependencies (Hyprland,
        Quickshell, hypridle, hyprlock, mpvpaper, awww, matugen,
        playerctl, ...) via Nix.

        Set to <literal>false</literal> if those packages are already
        installed by your OS (e.g. via pacman on Garuda / Arch). The
        only thing the module then installs is mugen-ai and the QML
        symlink, which avoids duplicating ~1-3 GiB of binaries that
        already live in /usr.
      '';
    };

    ai = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to install and run the mugen-ai backend service.";
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.mugen-ai or null;
        defaultText = lib.literalExpression "pkgs.mugen-ai";
        description = "The mugen-ai package (Go backend binary).";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Readonly symlink so `quickshell -c mugen-shell` finds the QML tree.
    # The result is a single symlink into /nix/store, regenerated on every
    # home-manager activation so flake updates propagate automatically.
    xdg.configFile."quickshell/mugen-shell".source = cfg.package;

    # list-apps.py imports `gi` and calls `gi.require_version("Gtk", "3.0")`
    # / `("Gio", "2.0")`. Wrapping python3 with pygobject3 puts the bindings
    # on sys.path but the typelibs live in the gtk3/glib derivations and
    # need GI_TYPELIB_PATH to be findable at runtime. Set it once for the
    # whole user session so Hyprland → quickshell → python3 inherits it.
    home.sessionVariables = lib.mkIf cfg.includeSystemDeps {
      GI_TYPELIB_PATH = lib.concatStringsSep ":" [
        "${pkgs.gtk3}/lib/girepository-1.0"
        "${pkgs.glib.out}/lib/girepository-1.0"
      ];
      # Qt5Compat.GraphicalEffects, which nixpkgs' quickshell doesn't bundle.
      QML2_IMPORT_PATH = "${pkgs.qt6Packages.qt5compat}/lib/qt-6/qml";
    };

    # Runtime dependencies. Everything mugen-shell launches via Process or
    # references from a script. Gated by includeSystemDeps so users whose
    # OS already provides this stack (pacman, dpkg, NixOS module, ...)
    # can opt out instead of double-installing 1-3 GiB into Nix.
    home.packages =
      lib.optionals cfg.includeSystemDeps (
        with pkgs;
        [
          quickshell
          hypridle
          hyprlock
          mpvpaper
          awww
          matugen
          playerctl
          wl-clipboard
          cliphist
          libnotify
          grim
          slurp
          cava
          ffmpeg
          imv
          pavucontrol
          pulseaudio   # provides `pactl` (audio panel set-sink-volume / mute / etc.)
          brightnessctl  # backlight slider + brightness tools
          jq             # App Launcher running-apps filter, several shell scripts
          xdg-utils      # `xdg-open` for Settings → Personality → Edit toml
          socat
          curl
          fastfetch
          # list-apps.py imports `gi` (PyGObject) to enumerate desktop entries;
          # gtk3 carries the GI typelibs the script needs (Gtk / Gio 2.0).
          (python3.withPackages (ps: [ ps.pygobject3 ]))
          gtk3
          # $terminal/$fileManager/$browser defaults; override via home.packages.
          kitty
          thunar
          firefox
        ]
      )
      ++ lib.optionals cfg.ai.enable [ cfg.ai.package ];

    systemd.user.services.mugen-ai = lib.mkIf cfg.ai.enable {
      Unit = {
        Description = "mugen-ai backend HTTP server";
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${cfg.ai.package}/bin/mugen-ai serve";
        # Load API keys (GEMINI_API_KEY, ANTHROPIC_API_KEY, ...) from the
        # user's mugen-ai config dir if they have written one. The leading
        # dash makes the file optional so the service still starts when
        # the user only uses local Ollama models.
        EnvironmentFile = "-%h/.config/mugen-ai/.env";
        Restart = "on-failure";
        RestartSec = 2;
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };

    systemd.user.services.mugen-event-notifier = {
      Unit = {
        Description = "mugen-shell calendar event notifications";
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${pkgs.python3}/bin/python3 ${cfg.package}/scripts/notify-events.py";
      };
    };

    systemd.user.timers.mugen-event-notifier = {
      Unit = {
        Description = "Trigger mugen-shell calendar event notifications every minute";
      };
      Timer = {
        OnCalendar = "*:*:00";
        Persistent = true;
        Unit = "mugen-event-notifier.service";
      };
      Install = {
        WantedBy = [ "timers.target" ];
      };
    };

    # Mutable defaults for the system/ dotfiles (Hyprland config, cava,
    # kitty, matugen templates, starship, fastfetch). Copied from the
    # /nix/store defaults on first activation; subsequent activations
    # leave existing files untouched so user edits stick around (this is
    # the personal-first / Nix-distributable balance from NIX-PLAN).
    home.activation.installMugenSystemDefaults =
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        install_dir() {
          local src="$1" dst="$2"
          if [[ ! -e "$dst" ]]; then
            $DRY_RUN_CMD mkdir -p "$dst"
            $DRY_RUN_CMD cp -r "$src"/. "$dst"/
            $DRY_RUN_CMD chmod -R u+w "$dst"
          fi
        }
        install_file() {
          local src="$1" dst="$2"
          if [[ ! -e "$dst" ]]; then
            $DRY_RUN_CMD mkdir -p "$(dirname "$dst")"
            $DRY_RUN_CMD install -m 644 "$src" "$dst"
          fi
        }

        install_dir   ${./../system/hypr}      "$HOME/.config/hypr"
        install_dir   ${./../system/cava}      "$HOME/.config/cava"
        install_dir   ${./../system/kitty}     "$HOME/.config/kitty"
        install_dir   ${./../system/matugen}   "$HOME/.config/matugen"
        install_dir   ${./../system/fastfetch} "$HOME/.config/fastfetch"
        install_file  ${./../system/starship.toml} "$HOME/.config/starship.toml"
      '';
  };
}
