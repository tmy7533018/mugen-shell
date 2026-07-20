{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.mugen-shell;

  voiceDir =
    if cfg.voice.sourceDir != null then cfg.voice.sourceDir else "${cfg.package}/voice";

  voicePython = pkgs.python314.withPackages (ps: [
    (ps.callPackage ./voice/openwakeword.nix { })
    ps.sounddevice
    ps.numpy
    ps.scipy
    ps.scikit-learn
    ps.requests
    ps.onnxruntime
  ]);

  # Pinned to a revision rather than resolve/main: main would only fail the
  # hash later, on some unrelated rebuild.
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
    # mkOutOfStoreSymlink keeps a live checkout editable without home-manager
    # reclaiming the path on every rebuild.
    xdg.configFile."quickshell/mugen-shell".source =
      if cfg.qmlDir != null
      then config.lib.file.mkOutOfStoreSymlink cfg.qmlDir
      else cfg.package;

    # Session-wide so Hyprland → quickshell → python3 inherits it.
    home.sessionVariables = lib.mkIf cfg.includeSystemDeps {
      GI_TYPELIB_PATH =
        lib.concatStringsSep ":" (import ./gi-typelib-dirs.nix pkgs);
      # Qt5Compat.GraphicalEffects, which nixpkgs' quickshell doesn't bundle.
      QML2_IMPORT_PATH = "${pkgs.qt6Packages.qt5compat}/lib/qt-6/qml";
    };

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
          pulseaudio   # provides `pactl`, which the audio panel shells out to
          brightnessctl
          jq             # App Launcher running-apps filter, several shell scripts
          xdg-utils      # `xdg-open` for Settings → Personality → Edit toml
          socat
          curl
          fastfetch
          # pygobject3 for list-apps.py, pillow+numpy for extract-color.py.
          (python3.withPackages (ps: [ ps.pygobject3 ps.pillow ps.numpy ]))
          gtk3
          # Referenced by the shipped .zshrc.
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

    # graphical-session.target sets RefuseManualStart, so Hyprland (no session
    # manager here) can't start it directly. It starts this target instead,
    # which binds to it and pulls it up.
    systemd.user.targets.mugen-shell-session = {
      Unit = {
        Description = "mugen-shell graphical session";
        BindsTo = [ "graphical-session.target" ];
        Before = [ "graphical-session.target" ];
        Wants = [ "graphical-session-pre.target" ];
        After = [ "graphical-session-pre.target" ];
      };
    };

    systemd.user.services.mugen-ai = lib.mkIf cfg.ai.enable {
      Unit = {
        Description = "mugen-ai backend HTTP server";
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${cfg.ai.package}/bin/mugen-ai serve";
        # Leading dash marks the API-key file optional, so the service still
        # starts for users on local Ollama models only.
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
        # Bootstrap only — yurad re-reads voice.wakeThreshold from settings.json,
        # which the shell writes on its first save of any setting. Keep this
        # equal to the GUI default or an unrelated change moves the wake gate.
        Environment = [
          "YURA_WAKEWORD=${voiceDir}/models/hey_yura.onnx"
          "YURA_WAKE_THRESHOLD=0.85"
          "YURA_WHISPER_BIN=${pkgs.whisper-cpp-vulkan}/bin/whisper-server"
          "YURA_WHISPER_MODEL=${whisperModel}"
        ]
        # yurad defaults to VOICEVOX, which the Nix path never installs, so
        # without this every reply is silent. The style id is left off on
        # purpose: it depends on which models the engine has downloaded.
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
          # CPU mode: the bundled onnxruntime-gpu is CUDA-only. First start
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

    # Copied rather than symlinked from the store so these stay writable and
    # user edits survive later activations.
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
