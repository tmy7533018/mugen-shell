<p align="right"><b>English</b> | <a href="SETUP.md">日本語</a></p>

# mugen-shell: Setup Guide

## Runtime data

Everything lives outside the repo, under XDG dirs:

| Where | What |
|---|---|
| `$XDG_CONFIG_HOME/mugen-shell/settings.json` | Persisted user settings |
| `$XDG_STATE_HOME/mugen-shell/{theme-mode,idle-inhibitor.json}` | Toggleable state |
| `$XDG_CACHE_HOME/mugen-shell/{colors.json,wallp/,wallpaper-thumbs/}` | Regenerable cache |
| `$XDG_DATA_HOME/mugen-shell/{wallpapers/,sounds/,timer-sounds/,tts/}` | User-supplied media |
| `$XDG_PICTURES_DIR/mugen-screenshots/` | Captured screenshots |

Audio files dropped into `sounds/` and `timer-sounds/` above show up in the Settings dropdowns for notification and timer sounds.

---

## Install

Two install paths. Open the one that matches your setup. Both need **Hyprland 0.55 or newer**.

<details>
<summary><b>Path A: NixOS</b></summary>

NixOS users just need the repo root flake:

```nix
# /etc/nixos/flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    mugen-shell.url = "github:tmy7533018/mugen-shell";
    mugen-shell.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { nixpkgs, home-manager, mugen-shell, ... }: {
    nixosConfigurations.mybox = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        mugen-shell.nixosModules.default
        home-manager.nixosModules.home-manager
        ({ ... }: {
          # System layer
          programs.mugen-shell.enable = true;

          # Required — home-manager won't see the mugen-shell overlay without it
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.YOUR_USER = {
            imports = [ mugen-shell.homeManagerModules.default ];
            programs.mugen-shell.enable = true;
            programs.mugen-shell.includeSystemDeps = false; # already on the system path
            home.stateVersion = "26.05";
          };
        })
      ];
    };
  };
}
```

Then `nixos-rebuild switch --flake /etc/nixos#mybox`.

**Making the terminal match the desktop**

The starship prompt, fish-style completion and history, aliases like `ls` → `eza`, and an ASCII-art `fastfetch`. The tools come from the system layer and the config from the home-manager one, so both need it:

```nix
programs.mugen-shell.zsh.enable = true;                    # system layer
home-manager.users.YOUR_USER.programs.mugen-shell.zsh.enable = true;
```

Then add one line to your own `~/.zshrc` (not needed if you use home-manager's `programs.zsh`):

```sh
source ~/.config/mugen-shell/mugen-shell.zshrc
```

**Japanese (or other) input via fcitx5**

Set `fcitx5Addons` and the module registers the IME for every login session. Installing fcitx5 into `systemPackages` yourself does **not** work on NixOS.

```nix
programs.mugen-shell.fcitx5Addons = with pkgs; [ fcitx5-mozc ];
# or:  [ fcitx5-rime ]    for Chinese
# or:  [ fcitx5-hangul ]  for Korean
```

</details>

<details>
<summary><b>Path B: Arch or any non-NixOS Linux, with Nix</b></summary>

Point at the user-level flake (the repo root); the Wayland and compositor stack comes from pacman.

```nix
# ~/.config/home-manager/flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    mugen-shell.url = "github:tmy7533018/mugen-shell";
    mugen-shell.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { nixpkgs, home-manager, mugen-shell, ... }:
  let system = "x86_64-linux"; in {
    homeConfigurations.YOUR_USER = home-manager.lib.homeManagerConfiguration {
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ mugen-shell.overlays.default ];
      };
      modules = [
        mugen-shell.homeManagerModules.default
        { home.username = "YOUR_USER"; home.homeDirectory = "/home/YOUR_USER"; }
        ({ ... }: {
          programs.mugen-shell.enable = true;
          # Wayland stack already on the OS path, skip the Nix copies
          programs.mugen-shell.includeSystemDeps = false;
          # Opt out of the AI backend with: programs.mugen-shell.ai.enable = false;
          home.stateVersion = "26.05";
        })
      ];
    };
  };
}
```

`home-manager switch --flake ~/.config/home-manager#YOUR_USER` activates it.

Install the system stack with pacman before the first switch:

```bash
yay -S hyprland quickshell qt6-5compat hypridle hyprpolkitagent zsh kitty libnotify \
       pipewire pipewire-pulse pavucontrol cava playerctl \
       networkmanager network-manager-applet bluez bluez-utils \
       fcitx5 fcitx5-mozc fcitx5-im fcitx5-configtool \
       awww mpvpaper ffmpeg matugen-bin socat \
       grim slurp wl-clipboard cliphist imv curl jq xdg-utils brightnessctl fzf \
       thunar \
       ttf-mplus-nerd bibata-cursor-theme colloid-gtk-theme-git \
       python-gobject
```

The audio visualiser's QML module is built by Nix. If quickshell fails to import `Mugen.Audio` with `version 'Qt_6.11' not found`, your Qt6 is older than the one it was built against: update Qt, or build `plugin/` yourself and put its install prefix on `QML2_IMPORT_PATH`.

`includeSystemDeps = true` pulls the user-space tools on that list (Quickshell, hypridle, awww, matugen, kitty, …) into Nix instead; Hyprland itself, the system services, and the themes stay on pacman either way.

**Making the terminal match the desktop**

The starship prompt, fish-style completion and history, aliases like `ls` → `eza`, and an ASCII-art `fastfetch`.

```nix
programs.mugen-shell.zsh.enable = true;
```

With `includeSystemDeps = false`, take the tools from pacman:

```bash
yay -S starship jp2a fastfetch eza bat ugrep \
       zsh-syntax-highlighting zsh-autosuggestions zsh-history-substring-search
```

Then add one line to your own `~/.zshrc` (not needed if you use home-manager's `programs.zsh`):

```sh
source ~/.config/mugen-shell/mugen-shell.zshrc
```

Wiring Hyprland into your display manager or login session is left to you (`Hyprland` from TTY, sddm session entry, etc.).

Activation places the shipped `system/hypr/` and `matugen/` under `~/.config/`. Their contents are refreshed on every later activation too, except `hypridle.conf`, which is created only once and left alone after that. `colors.lua`, `configs/blur.lua`, `configs/user-overrides.lua` and `configs/keybind-overrides.lua` are not created by activation at all: the first two are written when matugen and `blur-preset.sh` run, and the two override files are yours to create when you need them. `cava`, `kitty`, `fastfetch` and `starship.toml` still copy only when that path does not exist yet, as before. If you already have a Hyprland config, add the autostart to it by hand; without it nothing spawns `quickshell -c mugen-shell`:

```lua
dofile(os.getenv("HOME") .. "/.config/hypr/configs/mugen-shell.lua")
```

Activation already places that file at `~/.config/hypr/configs/mugen-shell.lua`, so there is nothing to copy.

**Still on a hyprlang (`.conf`) config?** The equivalent line is:

```hypr
source = ~/.config/hypr/configs/mugen-shell.conf
```

Two things to do yourself on Arch:

- **Lock screen PAM file.** Without it the lock screen cannot authenticate, and
  `ext-session-lock` holds the session locked. Create one:
  ```bash
  printf '#%%PAM-1.0\nauth include system-auth\n' | sudo tee /etc/pam.d/mugen-lock
  ```
- **fcitx5 env vars.** The shipped `system/hypr/hyprland.lua` exports `XMODIFIERS` for Hyprland sessions; add it to `/etc/environment` for anything started outside the compositor.

</details>

---

## Configuring mugen-ai

Everything is configured under **Settings → Yura**: personality, provider status, model, tool categories, allowed apps, panel side. Saving bounces the service for you. **Edit toml** on the same page opens `~/.config/mugen-ai/config.toml` in `$EDITOR` when you would rather write it by hand.

Three defaults worth knowing. **No model ships with this.** The input reads "No model yet" until you install Ollama and pull one (`ollama pull qwen3:4b`, say) or put an API key in `~/.config/mugen-ai/.env`. **Allowed apps starts empty** too, so Yura cannot launch anything until you pick apps there. And when `mugen-ai.service` itself is not running, the bar shows the command to start it.

A full annotated template lives at `ai/config.toml.example` (or `$(nix build --no-link --print-out-paths github:tmy7533018/mugen-shell#mugen-ai)/share/mugen-ai/config.toml.example` if you installed via Nix).

<details>
<summary>A minimal <code>~/.config/mugen-ai/config.toml</code></summary>

```toml
[personality]
# Optional auto-header. Leave all three empty to use system_prompt verbatim.
name = "Yura"
tone = "calm"
language = "en"
system_prompt = "You are a helpful desktop assistant. Be concise."

[provider.google]
# models = [...]   # omit for the provider's default model

[provider.anthropic]
# models = [...]   # omit for the provider's default model

[provider.openai]
# Any OpenAI-compatible backend: OpenAI, OpenRouter, LM Studio, vLLM, etc.
# base_url = "https://api.openai.com/v1"        # OpenAI itself
# base_url = "https://openrouter.ai/api/v1"     # OpenRouter
# base_url = "http://localhost:1234/v1"         # LM Studio (no API key needed)
# models = [...]                                # leave empty to query /v1/models

[tools.app_launch]
# Empty = Yura cannot launch anything. The Allowed apps picker fills this.
allowed_commands = ["firefox", "kitty", "code"]

[tools]
# Categories to hide from Yura (audio / music / brightness / theme /
# wallpaper / notification / timer / calendar / panel / app / memory /
# weather). Disabling "memory" also hides saved memories.
disabled_categories = []
```

- `[provider.ollama]`: pointed at `http://localhost:11434` out of the box, but **no install path ships Ollama itself**, so install it and pull a model yourself. Override `host` only if your daemon lives elsewhere.
- `[provider.google]` needs `GEMINI_API_KEY`; `[provider.anthropic]` needs `ANTHROPIC_API_KEY`. `models` is optional for both — omitted, each provider falls back to a single default model. To pin one, check that provider's own docs for a current model ID.
- `[provider.openai]`: any OpenAI-compatible provider. Active once `OPENAI_API_KEY` is set or `base_url` points at a local server. Leave `models` empty to query the backend's `/v1/models`.
- `[tools.app_launch].allowed_commands`: matched on binary basename. Off-`$PATH` binaries resolve through their `.desktop` entry, and Flatpak apps match by display name once `flatpak` itself is listed.
- `[tools].disabled_categories`: an MCP server name works here too, which disables that whole server.

</details>

<details>
<summary><b>MCP servers</b>: pulling in external tools</summary>

mugen-ai can pull tools from external [Model Context Protocol](https://modelcontextprotocol.io) servers (memory, filesystem, GitHub, etc.) and expose them to Yura alongside the built-in shell tools. Add one `[mcp.servers.<name>]` block per server:

```toml
[mcp.servers.memory]
command = "npx"
args = ["-y", "@modelcontextprotocol/server-memory"]
# env = { MEMORY_FILE_PATH = "/home/you/.local/state/mugen-ai/memory.json" }
# disabled = false   # keep the entry but skip spawning it
# trusted = false    # true = skip the approval prompt for this server's tools
```

`command` must be on the service's `PATH`, and mugen-ai bundles no server runtimes: an `npx`-based server needs Node.js, a `uvx`-based one needs [uv](https://docs.astral.sh/uv/). Nix users add the runtime to `home.packages`. Use `url = "https://example.com/mcp"` instead of `command` to dial a remote Streamable HTTP server, which needs no local runtime at all.

Tools are merged under a `<name>__<tool>` prefix, so keep the server name short, lowercase, and free of underscores. Restart `mugen-ai.service` after editing to pick up server changes.

**Approval prompt.** A tool that may make an irreversible change is held when Yura calls it, and an Approve / Deny prompt appears in the chat UI. Denial, timeout, and a closed chat all count as declined. Set `trusted = true` on a server you fully control to skip the prompt.

**Secrets in `env`.** `${VAR}` references resolve from mugen-ai's own environment. Put the token in `~/.config/mugen-ai/.env` and write `env = { GITHUB_TOKEN = "${GITHUB_TOKEN}" }`, so it stays out of `config.toml`.

</details>

### Provider API keys

Copy `ai/.env.example` (Nix install: `$(nix build --no-link --print-out-paths github:tmy7533018/mugen-shell#mugen-ai)/share/mugen-ai/.env.example`) to `~/.config/mugen-ai/.env` and fill in the keys you have, or append directly:

```sh
cat >> ~/.config/mugen-ai/.env <<'EOF'
ANTHROPIC_API_KEY=sk-ant-...
GEMINI_API_KEY=...
OPENAI_API_KEY=...
EOF
chmod 600 ~/.config/mugen-ai/.env
systemctl --user restart mugen-ai.service
```

Only keys with a non-empty value enable their provider.

### Choosing a model for shell control

How reliably Yura can *do* things (not just chat) depends on the model's tool-calling skill. Hosted API models (Claude, Gemini) are the most reliable; on local Ollama, prefer a recent mid-sized model. `qwen3:14b` drives the tools well, and `qwen3:4b` does too with the **Thinking** toggle on. A model with no tool support falls back to chat-only automatically.

### Listen address

The server listens on a unix socket at `$XDG_RUNTIME_DIR/mugen-ai/mugen-ai.sock`, not a TCP port, so no other user on the machine can reach it. To move it, set `MUGEN_AI_SOCKET` in `~/.config/mugen-ai/.env` and restart the service. The shell and the voice daemon read the same variable, so the three never disagree.

Conversations live in SQLite at `~/.local/state/mugen-ai/history.db`. For terminal use: `mugen-ai chat`.

---

## Voice input (optional)

Yura also takes spoken input: hold `Super + Z`, speak, and the reply is read aloud.

```
mic → silero VAD → whisper.cpp → mugen-ai /chat → TTS (AivisSpeech / VOICEVOX / sherpa-onnx)
```

The default stack is Japanese-first but not Japanese-only (see *Other languages* below). It sits on top of a running mugen-ai, and the home-manager module (Paths A and B) packages the whole thing behind one option:

```nix
programs.mugen-shell.voice.enable = true;
# programs.mugen-shell.voice.aivis.enable = false;      # skip the AivisSpeech engine
```

Everything comes from the store, so there is no checkout and no need for `nix-ld`. The AivisSpeech engine downloads its default voice model (~900 MB) on first start, so it needs the network once. Replies are routed at it automatically, so they are audible before any voice is picked in Settings. VOICEVOX is not part of the Nix wiring; run it yourself and its voices join the same picker.

The engine starts on demand (it costs ~2.6 GB resident) and stops after `voice.idleStopMin` minutes without synthesis (default 10, hand-edited in `settings.json`). Set `YURA_TTS_SERVICE=` empty in the unit to run it yourself instead.

Runtime control lives in **Settings → Voice input**: voice picker, speech speed, cue sounds, and the rest. Everything applies from the next utterance; the daemon watches `settings.json`, so nothing needs a restart.

The microphone stays closed until a turn starts, from `Super + Z` held down or from the push-to-talk button in either Yura UI.

<details>
<summary><b>Running Yura's voice in another language</b></summary>

Only the reply voice is engine-specific; everything else is multilingual already:

- **TTS**: local voices run in-process through sherpa-onnx, so there is no `piper` binary to install. Take a model from the [sherpa-onnx TTS models release](https://github.com/k2-fsa/sherpa-onnx/releases/tag/tts-models) (Piper/VITS and Kokoro both work) and unpack the whole **model directory** (the `.onnx` next to its `tokens.txt` and `espeak-ng-data/`) into `~/.local/share/mugen-shell/tts/`, or point `YURA_TTS_MODELS` somewhere else. Each directory then appears in the Settings voice picker, and VOICEVOX becomes optional. The Nix path already ships `vits-piper-en_US-lessac-high`.
- **STT**: the recognition language follows Settings → Yura → Personality → Language. Auto (the default) detects per utterance, a fixed language pins it; whisper covers ~100 languages.
- **Replies**: set the assistant's language under Settings → Yura → Personality.

**Environment knobs**, set in the unit or a drop-in: `YURA_SILERO_VAD`, `YURA_TTS` (`<engine>:<style-id>`), `YURA_VOICEVOX_SPEAKER`, `YURA_VOICE_LANG`, `YURA_VOICE_SPEED`, `YURA_WHISPER_URL`, `YURA_VOICEVOX_URL`, `YURA_AIVIS_URL`. Anything Settings also exposes wins from `settings.json` once the shell has saved it.

</details>

<details>
<summary><b>Using speakers instead of headphones</b>: echo cancellation</summary>

PipeWire's WebRTC echo cancellation subtracts what the speakers are playing from the mic, so speaking over a reply works. Drop this into `~/.config/pipewire/pipewire.conf.d/99-yura-echo-cancel.conf` (set `target.object` to your mic's `node.name` from `wpctl inspect`), restart PipeWire, then make the new source the default input with `wpctl set-default <id>`:

```
context.modules = [
    { name = libpipewire-module-echo-cancel
      args = {
          monitor.mode = true
          audio.channels = 1
          capture.props = { node.name = "yura_aec_capture" target.object = "<your-mic-node-name>" node.passive = true }
          source.props = { node.name = "yura_aec_source" node.description = "Mic (echo-cancelled)" }
      }
    }
]
```

</details>

---

## Keybindings

`Super + /` opens the full list inside the running shell. The ones worth knowing before that:

| Key | Action |
|---|---|
| `Super + R` | App launcher |
| `Super + Y` / `Super + Shift + Y` | Yura (bar row / corner panel) |
| `Super + ,` | Settings |
| `Super + Enter` | Terminal |
| `Super + Backspace` | Close the active window |
| `Super + 1-9` / `Super + 0` | Switch to workspace 1-10 |
| `Super + hjkl` | Move focus, vim-style |
| `Super + Z` | Hold to talk to Yura |
| `Print` / `Super + F12` | Region screenshot, copied to the clipboard |

Media, microphone and brightness keys work as they do anywhere else. Every binding is defined in `system/hypr/configs/keybinds.lua`.

---

## Credits

- [Hyprland](https://hypr.land/): Wayland compositor
- [Quickshell](https://quickshell.outfoxxed.me/): Shell framework
- [Matugen](https://github.com/InioX/matugen): Wallpaper-based color generation
- [Cava](https://github.com/karlstav/cava): Audio visualizer
- [Kitty](https://sw.kovidgoyal.net/kitty/): Terminal emulator
- [playerctl](https://github.com/altdesktop/playerctl): Media player control
- [grim](https://sr.ht/~emersion/grim/) / [slurp](https://github.com/emersion/slurp): Screenshot tools
- [cliphist](https://github.com/sentriz/cliphist): Clipboard history
- [Silero VAD](https://github.com/snakers4/silero-vad): Voice activity detection
- [whisper.cpp](https://github.com/ggml-org/whisper.cpp): Speech-to-text
- [VOICEVOX](https://voicevox.hiroshiba.jp/): TTS engine
- [AivisSpeech Engine](https://github.com/Aivis-Project/AivisSpeech-Engine): VOICEVOX-compatible TTS with Style-Bert-VITS2 voices, models from [AivisHub](https://hub.aivis-project.com/)
- [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx): in-process TTS for local voices
- [Piper](https://github.com/rhasspy/piper): the model behind the default English voice
- [LRO WAC moon mosaic](https://commons.wikimedia.org/wiki/File:Moon_nearside_LRO.jpg): the moon on the lock screen. NASA/GSFC/Arizona State University, public domain (bundled brightness-adjusted and scaled down to 320px)
