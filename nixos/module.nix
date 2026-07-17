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
    enable = lib.mkEnableOption "system-wide mugen-shell desktop bits (Quickshell + Hyprland + runtime deps)";

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
        Install mugen-shell's runtime dependencies (Quickshell, hypridle,
        hyprlock, mpvpaper, awww, matugen, playerctl, ...) into
        environment.systemPackages, enable programs.hyprland and
        programs.hyprlock so the Wayland session and PAM lock screen are
        wired up, and turn on the supporting services (pipewire,
        bluetooth, NetworkManager) the shell expects to be running.

        Set to <literal>false</literal> if you already manage Hyprland and
        the rest of the stack yourself; the module will then only put
        cfg.package on the system path.
      '';
    };

    fcitx5Addons = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [];
      example = lib.literalExpression "with pkgs; [ fcitx5-mozc ]";
      description = ''
        fcitx5 input-method engines to install. Empty disables IME entirely.

        Setting this to a non-empty list enables i18n.inputMethod with
        fcitx5, which is the only correct way to wire up the IME on NixOS
        (it sets the GTK_IM_MODULE / QT_IM_MODULE / XMODIFIERS env vars
        for every login session — installing fcitx5 directly does not).

        Examples: <literal>[ pkgs.fcitx5-mozc ]</literal> for Japanese,
        <literal>[ pkgs.fcitx5-rime ]</literal> for Chinese,
        <literal>[ pkgs.fcitx5-hangul ]</literal> for Korean.
      '';
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      environment.systemPackages = [ cfg.package ];
    }

    (lib.mkIf (cfg.fcitx5Addons != []) {
      i18n.inputMethod = {
        type = "fcitx5";
        enable = true;
        fcitx5.addons = cfg.fcitx5Addons;
      };
    })

    (lib.mkIf cfg.includeSystemDeps {
      programs.hyprland.enable = true;
      programs.hyprlock.enable = true;

      services.pipewire = {
        enable = true;
        alsa.enable = true;
        pulse.enable = true;
      };

      hardware.bluetooth.enable = true;
      networking.networkmanager.enable = true;

      fonts.packages = with pkgs; [
        mplus-outline-fonts.githubRelease # "M PLUS 2", the shell's primary UI font
        nerd-fonts.jetbrains-mono # AI panel code blocks
        nerd-fonts.fira-code # kitty.conf's font_family
        noto-fonts-color-emoji
      ];

      # list-apps.py needs GTK 3.0 / Gio 2.0 typelibs at runtime. Setting
      # this as a session variable propagates into Hyprland → quickshell →
      # the python invocation that calls gi.require_version().
      environment.sessionVariables.GI_TYPELIB_PATH = [
        "${pkgs.gtk3}/lib/girepository-1.0"
        "${pkgs.glib.out}/lib/girepository-1.0"
      ];

      # The QML tree imports Qt5Compat.GraphicalEffects, which nixpkgs'
      # quickshell doesn't bundle (Arch splits it out as qt6-5compat too).
      environment.sessionVariables.QML2_IMPORT_PATH = [
        "${pkgs.qt6Packages.qt5compat}/lib/qt-6/qml"
      ];

      environment.systemPackages = with pkgs; [
        quickshell
        hypridle
        # hyprlock comes from programs.hyprlock.enable above (sets up PAM).
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
        pulseaudio    # provides `pactl` (audio panel set-sink-volume / mute / etc.)
        brightnessctl # backlight slider + brightness tools
        jq            # App Launcher running-apps filter, several shell scripts
        xdg-utils     # `xdg-open` for Settings → Personality → Edit toml
        socat
        curl
        fastfetch
        hyprpolkitagent # mugen-shell.conf starts its user unit via exec-once
        # list-apps.py imports `gi` (PyGObject) to enumerate desktop entries;
        # gtk3 carries the GI typelibs the script needs (Gtk / Gio 2.0).
        # extract-color.py wants pillow+numpy for album-art accent colors.
        (python3.withPackages (ps: [ ps.pygobject3 ps.pillow ps.numpy ]))
        gtk3
        kitty
        thunar
        firefox
        # .zshrc quality-of-life: prompt, splash art, fuzzy finder, fish-style plugins
        starship
        jp2a
        fzf
        zsh-syntax-highlighting
        zsh-autosuggestions
        zsh-history-substring-search
      ];

      # The hypr configs start these with `systemctl --user start`;
      # systemPackages alone doesn't register a package's user units.
      systemd.packages = with pkgs; [
        hypridle
        hyprpolkitagent
      ];
    })
  ]);
}
