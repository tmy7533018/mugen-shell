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

    # Runtime dependencies. Anything mugen-shell launches via Process or
    # references from a script lives here. Compositor / shell framework
    # are included so a fresh install is functional even if the user
    # hasn't installed them via the OS package manager.
    home.packages =
      with pkgs;
      [
        hyprland
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
        pulseaudio # paplay
        socat # mpvpaper IPC in change-wallpaper.sh
        python3
      ]
      ++ lib.optionals cfg.ai.enable [ cfg.ai.package ];

    systemd.user.services.mugen-ai = lib.mkIf cfg.ai.enable {
      Unit = {
        Description = "mugen-ai backend HTTP server";
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${cfg.ai.package}/bin/mugen-ai serve";
        Restart = "on-failure";
        RestartSec = 2;
      };
      Install = {
        WantedBy = [ "default.target" ];
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
