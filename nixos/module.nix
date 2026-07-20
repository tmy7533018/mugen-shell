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

      # Thunar (what Super+N opens) needs the module, not the bare package: the
      # package has no xfconf D-Bus service, so every preference it writes is
      # lost by the next launch. tumbler adds thumbnails, gvfs trash and mounts.
      programs.thunar.enable = true;
      programs.xfconf.enable = true;
      services.tumbler.enable = true;
      services.gvfs.enable = true;

      # kitty ships a desktop entry claiming inode/directory, so without an
      # explicit default `xdg-open <dir>` — what the shell's folder buttons
      # call — opens a terminal instead of the file manager.
      xdg.mime.defaultApplications."inode/directory" = "thunar.desktop";
      # xdg-document-portal (pulled in by hyprland) FUSE-mounts /run/user/*/doc
      # and fails every boot without the setuid fusermount3 wrapper.
      programs.fuse.enable = true;

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

      # Session-wide so it reaches the python that list-apps.py runs in,
      # via Hyprland → quickshell.
      environment.sessionVariables.GI_TYPELIB_PATH =
        import ../nix/gi-typelib-dirs.nix pkgs;

      # The QML tree imports Qt5Compat.GraphicalEffects, which nixpkgs'
      # quickshell doesn't bundle.
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
        pulseaudio    # provides `pactl`, which the audio panel shells out to
        brightnessctl
        jq            # App Launcher running-apps filter, several shell scripts
        xdg-utils     # `xdg-open` for Settings → Personality → Edit toml
        socat
        curl
        fastfetch
        hyprpolkitagent # mugen-shell.conf starts its user unit via exec-once
        # pygobject3 for list-apps.py, pillow+numpy for extract-color.py.
        (python3.withPackages (ps: [ ps.pygobject3 ps.pillow ps.numpy ]))
        gtk3
        kitty
        firefox
        # Referenced by the shipped .zshrc.
        starship
        jp2a
        fzf
        zsh-syntax-highlighting
        zsh-autosuggestions
        zsh-history-substring-search
      ];

      # systemPackages alone doesn't register a package's user units, which the
      # hypr configs start with `systemctl --user start`.
      systemd.packages = with pkgs; [
        hypridle
        hyprpolkitagent
      ];
    })
  ]);
}
