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

  # Off NixOS a user unit inherits no profile, so home.packages resolves nowhere.
  unitPath = lib.concatStringsSep ":" [
    "${config.home.profileDirectory}/bin"
    "/run/wrappers/bin"
    "/run/current-system/sw/bin"
    "/usr/local/bin"
    "/usr/bin"
    "/bin"
  ];

  sileroVad = pkgs.callPackage ./voice/silero-vad.nix { };

  voicePython = pkgs.python314.withPackages (
    ps:
    [
      ps.sounddevice
      ps.numpy
      ps.requests
      ps.onnxruntime
      ps.sherpa-onnx
    ]
  );

  # Pinned to a revision rather than resolve/main: main would only fail the
  # hash later, on some unrelated rebuild.
  whisperModel = pkgs.fetchurl {
    url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/5359861c739e955e79d9a303bcbc70fb988958b1/ggml-large-v3-turbo.bin";
    hash = "sha256-H8cPd0046xaZk6w5Huo1fvR8iHV+9y7llDh5t+jivGk=";
  };

  # The default non-Japanese voice. Piper rather than Kokoro: Kokoro's Japanese
  # has no G2P here (its jf_* voices garble kanji) and its English measured
  # ~20% of energy above 6 kHz against Piper's 4%, which is the harshness you
  # hear. Japanese stays on AivisSpeech, picked per-language by voice.ttsByLang.
  piperVoice = pkgs.stdenvNoCC.mkDerivation {
    name = "piper-en_US-lessac-high";
    src = pkgs.fetchurl {
      url = "https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-piper-en_US-lessac-high.tar.bz2";
      hash = "sha256-hhnSBMcAWGb+T0IBgd+nliKvamIiOJ8LCBjSrzHg2w4=";
    };
    sourceRoot = ".";
    installPhase = "mkdir -p $out && cp -r vits-piper-en_US-lessac-high $out/";
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
        Quickshell, hypridle, mpvpaper, awww, matugen,
        playerctl, ...) via Nix.

        Set to <literal>false</literal> if those packages are already
        installed by your OS (e.g. via pacman on Garuda / Arch). The
        only thing the module then installs is mugen-ai and the QML
        symlink, which avoids duplicating ~1-3 GiB of binaries that
        already live in /usr.
      '';
    };

    zsh.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Install the packaged zsh config (starship prompt, fish-style
        plugins, aliases, and the jp2a + fastfetch splash) and the tools
        it calls. The fastfetch and starship configs it draws are
        installed either way.

        Your own <filename>~/.zshrc</filename> is never written over.
        Enable <literal>programs.zsh</literal> as well and the source
        line is added for you; otherwise add the line SETUP gives you.
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
      enable = lib.mkEnableOption "the Yura voice input daemon (push-to-talk → STT → chat → TTS)";

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
    xdg.configFile = {
      "quickshell/mugen-shell".source =
        if cfg.qmlDir != null
        then config.lib.file.mkOutOfStoreSymlink cfg.qmlDir
        else cfg.package;
    } // lib.optionalAttrs cfg.zsh.enable {
      # A stable path to source: the store path it points at changes every update.
      "mugen-shell/mugen-shell.zshrc".source =
        "${cfg.package}/share/zsh/mugen-shell.zshrc";
    };

    # Inert unless programs.zsh is enabled too; SETUP covers the manual line.
    programs.zsh.initContent = lib.mkIf cfg.zsh.enable
      "source ${config.xdg.configHome}/mugen-shell/mugen-shell.zshrc";

    # Session-wide so Hyprland → quickshell → python3 inherits it.
    home.sessionVariables = {
      # Mugen.Audio is built from this repo, so no distro can supply it in our place.
      QML2_IMPORT_PATH = lib.concatStringsSep ":" (
        [ "${pkgs.mugen-audio}/lib/qt-6/qml" ]
        ++ lib.optional cfg.includeSystemDeps
          "${pkgs.qt6Packages.qt5compat}/lib/qt-6/qml"
      );
    } // lib.optionalAttrs cfg.includeSystemDeps {
      GI_TYPELIB_PATH =
        lib.concatStringsSep ":" (import ./gi-typelib-dirs.nix pkgs);
    };

    home.packages =
      lib.optionals cfg.includeSystemDeps (
        with pkgs;
        [
          quickshell
          hypridle
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
          fzf            # the blur preset picker falls back to it
          # pygobject3 for list-apps.py.
          (python3.withPackages (ps: [ ps.pygobject3 ]))
          gtk3
          # $terminal/$fileManager/$browser defaults; override via home.packages.
          kitty
          thunar
          firefox
        ]
      )
      # What the packaged .zshrc calls; nothing else in the desktop needs them.
      ++ lib.optionals (cfg.includeSystemDeps && cfg.zsh.enable) (
        with pkgs;
        [
          starship
          jp2a
          fastfetch
          eza
          bat
          ugrep
          zsh-syntax-highlighting
          zsh-autosuggestions
          zsh-history-substring-search
        ]
      )
      # Ungated: the music module shells out to `mugen-ai art` regardless.
      ++ [ cfg.ai.package ];

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

    # Both packages ship a share/systemd/user unit, which systemd finds when the
    # NixOS module puts them in systemPackages but not from a home-manager
    # profile — there, mugen-shell.lua's `systemctl --user start` would report
    # Unit not found. No [Install]: the shell starts them itself, and hypridle
    # in particular must stay off when the idle inhibitor is on.
    systemd.user.services.hypridle = lib.mkIf cfg.includeSystemDeps {
      Unit = {
        Description = "Hyprland's idle daemon";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
        ConditionEnvironment = "WAYLAND_DISPLAY";
      };
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.hypridle}/bin/hypridle";
        Restart = "on-failure";
      };
    };

    systemd.user.services.hyprpolkitagent = lib.mkIf cfg.includeSystemDeps {
      Unit = {
        Description = "Hyprland Polkit Authentication Agent";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
        ConditionEnvironment = "WAYLAND_DISPLAY";
      };
      Service = {
        ExecStart = "${pkgs.hyprpolkitagent}/libexec/hyprpolkitagent";
        Slice = "session.slice";
        TimeoutStopSec = "5sec";
        Restart = "on-failure";
      };
    };

    systemd.user.services.mugen-ai = lib.mkIf cfg.ai.enable {
      Unit = {
        Description = "mugen-ai backend server";
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${cfg.ai.package}/bin/mugen-ai serve";
        # An MCP server's command (npx, uvx, ...) is resolved by this PATH.
        Environment = [ "PATH=${unitPath}" ];
        # The socket lives here; systemd creates it 0700 and clears it on stop.
        RuntimeDirectory = "mugen-ai";
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
        Description = "Yura voice input daemon (push-to-talk → STT → chat → TTS)";
        After = [
          "graphical-session.target"
          "aivisspeech-engine.service"
          "mugen-ai.service"
        ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        WorkingDirectory = voiceDir;
        Environment = [
          "PATH=${unitPath}"
          "YURA_SILERO_VAD=${sileroVad}"
          "YURA_WHISPER_BIN=${pkgs.whisper-cpp-vulkan}/bin/whisper-server"
          "YURA_WHISPER_MODEL=${whisperModel}"
          # Colon-separated search path. A voice dropped in the writable dir
          # shadows a packaged one of the same name.
          "YURA_TTS_MODELS=%h/.local/share/mugen-shell/tts:${piperVoice}"
        ]
        ++ lib.optionals cfg.voice.aivis.enable [
          "YURA_TTS=aivis:"
          "YURA_TTS_SERVICE=aivisspeech-engine.service"
        ];
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
      };

    systemd.user.services.mugen-event-notifier = {
      Unit = {
        Description = "mugen-shell calendar event notifications";
      };
      Service = {
        Type = "oneshot";
        Environment = [ "PATH=${unitPath}" ];
        ExecStart = "${cfg.ai.package}/bin/mugen-ai calendar notify";
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

    # Copied rather than symlinked so matugen, blur-preset.sh and the user can keep writing into these.
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

        # Product is refreshed every activation, or an existing ~/.config keeps a shipped fix out forever.
        install_product_tree() {
          local src="$1" dst="$2"; shift 2
          local f rel mode skip
          # Trailing names are seeded once: the machine or the user owns them afterwards.
          while IFS= read -r -d "" f; do
            rel="''${f#"$src"/}"
            for skip in "$@"; do
              if [[ "$rel" == "$skip" ]]; then
                install_file "$f" "$dst/$rel"
                continue 2
              fi
            done
            mode=644
            [[ -x "$f" ]] && mode=755
            $DRY_RUN_CMD install -D -m "$mode" "$f" "$dst/$rel"
          done < <(find "$src" -type f -print0)
        }

        install_product_tree ${./../system/hypr} "$HOME/.config/hypr" \
          hypridle.conf colors.lua configs/blur.lua configs/.blur-current \
          configs/user-overrides.lua configs/keybind-overrides.lua
        install_product_tree ${./../system/matugen} "$HOME/.config/matugen"
        install_dir   ${./../system/cava}      "$HOME/.config/cava"
        install_dir   ${./../system/kitty}     "$HOME/.config/kitty"
        install_dir   ${./../system/fastfetch} "$HOME/.config/fastfetch"
        install_file  ${./../system/starship.toml} "$HOME/.config/starship.toml"
      '';
  };
}
