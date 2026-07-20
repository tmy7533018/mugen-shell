{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.mugen-shell;

  # Packaged copy by default so the Nix path needs no checkout; voice.sourceDir
  # points it at a live one for hacking, mirroring qmlDir.
  voiceDir =
    if cfg.voice.sourceDir != null then cfg.voice.sourceDir else "${cfg.package}/voice";

  # The daemon runs from the live ~/mugen-shell checkout (same dev-mode
  # thinking as qmlDir), so we only hand it an interpreter carrying the right
  # libs. openwakeword is our own derivation; the rest are stock nixpkgs.
  voicePython = pkgs.python314.withPackages (ps: [
    (ps.callPackage ./voice/openwakeword.nix { })
    ps.sounddevice
    ps.numpy
    ps.scipy
    ps.scikit-learn
    ps.requests
    ps.onnxruntime
  ]);

  # whisper.cpp STT model — not in nixpkgs, fetched straight from HuggingFace.
  # Pinned to a revision rather than resolve/main: the hash would still catch a
  # swap, but as a build failure on an unrelated rebuild instead of never.
  whisperModel = pkgs.fetchurl {
    url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/5359861c739e955e79d9a303bcbc70fb988958b1/ggml-large-v3-turbo.bin";
    hash = "sha256-H8cPd0046xaZk6w5Huo1fvR8iHV+9y7llDh5t+jivGk=";
  };

  aivisEngine = pkgs.callPackage ./voice/aivisspeech-engine.nix { };
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

    qmlDir = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/home/you/mugen-shell/shell";
      description = ''
        Absolute path to a live checkout's shell/ directory. When set,
        ~/.config/quickshell/mugen-shell points at it instead of the
        packaged QML tree, so edits hot-reload without a rebuild.
        The path must exist by the time the session starts; quickshell
        has nothing to load otherwise.
      '';
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

    voice = {
      enable = lib.mkEnableOption "the Yura voice input daemon (wake word → STT → chat → TTS)";

      sourceDir = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "/home/you/mugen-shell/voice";
        description = ''
          Absolute path to a live checkout's voice/ directory. When set the
          daemon runs yurad.py from there instead of the packaged copy, so
          edits need a service restart rather than a rebuild.
        '';
      };

      aivis.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Run the AivisSpeech engine (primary Japanese TTS) as a user service.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Symlink so `quickshell -c mugen-shell` finds the QML tree. Packaged
    # tree by default (flake updates propagate on activation); qmlDir swaps
    # in a live checkout via mkOutOfStoreSymlink for the edit → hot-reload
    # dev workflow without fighting home-manager on rebuilds.
    xdg.configFile."quickshell/mugen-shell".source =
      if cfg.qmlDir != null
      then config.lib.file.mkOutOfStoreSymlink cfg.qmlDir
      else cfg.package;

    # list-apps.py imports `gi` (PyGObject); the typelib dir list lives in
    # gi-typelib-dirs.nix, shared with the NixOS module. Set once for the
    # whole user session so Hyprland → quickshell → python3 inherits it.
    home.sessionVariables = lib.mkIf cfg.includeSystemDeps {
      GI_TYPELIB_PATH =
        lib.concatStringsSep ":" (import ./gi-typelib-dirs.nix pkgs);
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
          # extract-color.py wants pillow+numpy for album-art accent colors.
          (python3.withPackages (ps: [ ps.pygobject3 ps.pillow ps.numpy ]))
          gtk3
          # .zshrc quality-of-life: prompt, splash art, fuzzy finder, fish-style plugins
          starship
          jp2a
          fzf
          zsh-syntax-highlighting
          zsh-autosuggestions
          zsh-history-substring-search
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

    systemd.user.services.yura-voice = lib.mkIf cfg.voice.enable {
      Unit = {
        Description = "Yura voice input daemon (wake word → STT → chat → TTS)";
        After = [
          "graphical-session.target"
          "aivisspeech-engine.service"
          "mugen-ai.service"
        ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        WorkingDirectory = voiceDir;
        # Bootstrap default only: yurad re-reads voice.wakeThreshold from
        # settings.json every frame, and the shell writes that key on its
        # first save of any setting. Keep this equal to the GUI default or
        # an unrelated settings change would silently move the wake gate.
        Environment = [
          "YURA_WAKEWORD=${voiceDir}/models/hey_yura.onnx"
          "YURA_WAKE_THRESHOLD=0.85"
          "YURA_WHISPER_BIN=${pkgs.whisper-cpp-vulkan}/bin/whisper-server"
          "YURA_WHISPER_MODEL=${whisperModel}"
        ]
        # Route replies at the engine this module actually starts. The daemon's
        # built-in default is VOICEVOX, which the Nix path never installs, so
        # without this every reply is silent until a voice is picked by hand.
        # Naming only the engine is deliberate: style ids depend on which
        # models the engine has downloaded, so they can't be pinned here.
        ++ lib.optional cfg.voice.aivis.enable "YURA_TTS=aivis:";
        ExecStart = "${voicePython}/bin/python ${voiceDir}/yurad.py";
        Restart = "on-failure";
        RestartSec = 3;
      };
      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };

    systemd.user.services.aivisspeech-engine =
      lib.mkIf (cfg.voice.enable && cfg.voice.aivis.enable) {
        Unit = {
          Description = "AivisSpeech TTS engine (VOICEVOX-compatible API on :10101)";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
        };
        Service = {
          # CPU mode: the bundled onnxruntime-gpu is CUDA-only and this is an
          # AMD box; upstream says CPU is plenty for a single user. First start
          # pulls the default model + BERT (~900 MB), so it needs the network.
          ExecStart = "${aivisEngine}/bin/aivisspeech-engine --host 127.0.0.1 --port 10101";
          Restart = "on-failure";
          RestartSec = 5;
        };
        Install = {
          WantedBy = [ "graphical-session.target" ];
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
