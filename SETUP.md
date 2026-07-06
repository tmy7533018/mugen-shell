<p align="right"><b>English</b> | <a href="SETUP.ja.md">日本語</a></p>

# mugen-shell — Setup Guide

## Directory Structure

```
mugen-shell/
├── shell/                    # Quickshell QML tree (the desktop UI itself)
│   ├── assets/
│   │   ├── branding/         # Logo and banner
│   │   └── icons/            # SVG icons
│   ├── components/
│   │   ├── bar/              # Bar (left/right sections + sub-widgets)
│   │   ├── common/           # Shared UI primitives
│   │   ├── content/          # Per-mode content panels
│   │   │   ├── ai/           # AI message bubble + model selector
│   │   │   ├── bluetooth/    # Paired / available device delegates
│   │   │   ├── settings/     # One file per Settings row
│   │   │   └── volume/       # Audio device dropdown
│   │   ├── managers/         # Audio, WiFi, Bluetooth, etc.
│   │   ├── notification/     # Notification components
│   │   ├── ui/               # Clock, workspaces, power menu, etc.
│   │   └── yura/             # Yura corner-popup window components
│   ├── lib/                  # ModeManager, Colors, Typography, YuraState, ...
│   ├── scripts/              # Shell + Python scripts (blur preset, lock timer, ...)
│   ├── windows/              # Bar.qml (top-level surface)
│   ├── settings.default.json # OSS-friendly defaults
│   ├── shell.qml             # Main Quickshell entry (bar + notifications)
│   ├── yura-shell.qml        # Standalone Quickshell entry for Yura (separate process)
│   ├── settings-shell.qml    # Standalone Settings window
│   └── shortcuts-shell.qml   # Standalone keyboard shortcut reference window
├── ai/                       # mugen-ai Go backend
│   ├── cmd/                  # CLI subcommands (chat, serve)
│   ├── internal/             # Provider registry, server (HTTP + SSE /events), history, ...
│   └── contrib/systemd/      # systemd user unit
├── voice/                    # Yura voice input daemon (optional; see Voice input)
│   ├── yurad.py              # wake word -> VAD -> whisper.cpp -> /chat -> VOICEVOX
│   ├── models/               # custom "Hey Yura" openWakeWord model
│   └── train/                # wake word training pipeline (VOICEVOX-based)
├── system/                   # Dotfiles for the surrounding tools
│   ├── hypr/                 # Hyprland (configs/, scripts/, hyprland.conf, ...)
│   │   └── configs/          # autostart.conf / ime.conf / keybinds.conf / ...
│   ├── kitty/                # Kitty terminal
│   ├── fastfetch/            # System info display
│   ├── matugen/              # Material You color generation + templates
│   ├── cava/                 # Audio visualizer (themes + GLSL shaders)
│   ├── systemd/user/         # User units (yura-voice, voicevox-engine, event notifier)
│   └── starship.toml         # Starship prompt
├── nix/
│   └── home-manager.nix      # home-manager module (Arch + Nix path)
├── nixos/
│   ├── flake.nix             # Umbrella NixOS flake (re-exports root + adds nixosModules)
│   └── module.nix            # NixOS system module body
├── flake.nix                 # Root Nix flake (user-level, home-manager target)
├── flake.lock
├── Makefile                  # `make install` for non-Nix users
├── .zshrc
├── README.md
└── SETUP.md                  # This file
```

Runtime data lives outside the repo under XDG dirs:

| Where | What |
|---|---|
| `$XDG_CONFIG_HOME/mugen-shell/settings.json` | Persisted user settings |
| `$XDG_STATE_HOME/mugen-shell/{theme-mode,idle-inhibitor.json}` | Toggleable state |
| `$XDG_CACHE_HOME/mugen-shell/{colors.json,wallp/,wallpaper-thumbs/}` | Regenerable cache |
| `$XDG_DATA_HOME/mugen-shell/{wallpapers/,sounds/}` | User-supplied media |
| `$XDG_PICTURES_DIR/mugen-screenshots/` | Captured screenshots |

User-supplied media goes under the corresponding XDG path. The notification sound dropdown rescans every time Settings opens. Quickest way to get a sound working:

```bash
mkdir -p ~/.local/share/mugen-shell/sounds && cp /usr/share/sounds/freedesktop/stereo/{bell,message,message-new-instant}.oga ~/.local/share/mugen-shell/sounds/
```

---

## Install

Three install paths. Pick whichever matches your setup.

### Path A — NixOS

NixOS users go through the umbrella flake at `?dir=nixos`. It enables `programs.hyprland`, adds the runtime stack to `environment.systemPackages`, and re-exports the home-manager module so the per-user pieces (mugen-ai user service, dotfiles) come from the same input.

```nix
# /etc/nixos/flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    mugen-shell.url = "github:tmy7533018/mugen-shell?dir=nixos";
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

          # User layer — same input, home-manager pieces
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

#### Japanese (or other) input via fcitx5

The module exposes a `fcitx5Addons` option that wires up `i18n.inputMethod`, which sets the GTK / Qt / SDL env vars system-wide. Installing fcitx5 directly into `systemPackages` does **not** do this on NixOS.

```nix
programs.mugen-shell.fcitx5Addons = with pkgs; [ fcitx5-mozc ];
# or:  [ fcitx5-rime ]    for Chinese
# or:  [ fcitx5-hangul ]  for Korean
```

The default is `[]` (no IME). The `source = ime.conf` line in `hyprland.conf` is safe to keep either way; Hyprland just exports the same env vars a second time.

### Path B — Arch / Garuda / any non-NixOS Linux + Nix

If you have Nix with flakes enabled but you're not on NixOS, point at the user-level flake (the repo root) and install the Wayland and compositor stack via pacman.

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
yay -S hyprland quickshell hypridle hyprlock zsh kitty starship libnotify \
       pipewire pipewire-pulse pavucontrol cava playerctl \
       networkmanager network-manager-applet bluez bluez-utils \
       fcitx5 fcitx5-mozc fcitx5-im fcitx5-configtool \
       awww mpvpaper ffmpeg matugen-bin socat \
       grim slurp wl-clipboard cliphist imv curl jq xdg-utils brightnessctl \
       zsh-syntax-highlighting zsh-autosuggestions zsh-history-substring-search fzf \
       eza bat ugrep fastfetch jp2a thunar \
       ttf-mplus-nerd bibata-cursor-theme colloid-gtk-theme-git \
       python-gobject
```

Set `includeSystemDeps = true` to pull all of that into Nix instead. Useful when the distro doesn't package something or you want a hermetic install.

Wiring Hyprland into your display manager or login session is left to you (`Hyprland` from TTY, sddm session entry, etc.).

The home-manager activation copies the shipped `system/hypr/` defaults into `~/.config/hypr/` only when the directory is empty, so first-time users get a working Hyprland config with mugen-shell autostart configured. If you already have your own `~/.config/hypr/hyprland.conf`, the copy is skipped. To adopt the mugen-shell autostart, add this line to your existing config:

```hypr
source = ~/.config/hypr/configs/mugen-shell.conf
```

That file ships in the package output (`$(nix path-info .#mugen-shell)/hypr/configs/mugen-shell.conf`). Copy it into `~/.config/hypr/configs/` once and the `source =` line keeps it up to date across rebuilds. Without that line nothing spawns `quickshell -c mugen-shell`, and the bar and Yura panels will not start.

Two Arch-specific items the NixOS module handles automatically:

- **`hyprlock` PAM file.** Arch does not ship one by default, so `hyprlock` refuses to unlock the screen. Drop the upstream sample into `/etc/pam.d/hyprlock`:
  ```bash
  sudo curl -fsSL https://raw.githubusercontent.com/hyprwm/hyprlock/main/pam/hyprlock \
    -o /etc/pam.d/hyprlock
  ```
- **fcitx5 env vars.** `fcitx5` itself does not export `GTK_IM_MODULE` / `QT_IM_MODULE` / `XMODIFIERS`. The shipped `system/hypr/configs/ime.conf` covers Hyprland sessions. For non-Hyprland processes (login shells, GUI apps started outside the compositor), put the same vars in `/etc/environment`.

### Path C — Pure manual (no Nix)

```bash
git clone https://github.com/tmy7533018/mugen-shell.git ~/mugen-shell
cd ~/mugen-shell
make install        # symlinks + builds and enables mugen-ai
```

`make install` runs:
- `install-symlinks`: points `~/.config/quickshell/mugen-shell`, `~/.config/{cava,fastfetch,hypr,kitty,matugen}`, and `~/.config/starship.toml` at the checkout.
- `install-ai`: `go install` the mugen-ai binary, install and enable the systemd user unit.

`make install-symlinks` and `make install-ai` are independent if you only want one. Remove with `make uninstall`. Same `yay -S` list as Path B for the system stack. `mugen-ai` requires Go on this path; Paths A and B ship a prebuilt binary.

---

## Configuring mugen-ai

Yura (`Super + Y` for the bar row, `Super + Shift + Y` for the corner pop-up) talks to the local Go server. Configuration lives under **Settings → AI / Yura**. Every panel writes through the backend's HTTP API and triggers a hot restart, so a terminal trip is not required.

- **Personality**: name, tone, language, and system prompt. Save & Apply writes `~/.config/mugen-ai/config.toml` and bounces the systemd unit. Two escape hatches sit on the same row: **Edit toml** opens the file in `$EDITOR`, and **Restart AI** restarts the service after manual edits.
- **Providers**: read-only status card showing which API keys are set, each provider's host or base_url, and the models list. Refresh re-fetches.
- **Bar Yura model**: pins the model used by the bar row. Leave it on the default to follow whichever model the corner pop-up most recently selected.
- **Bar Yura thinking**: routes the bar's chat through each provider's reasoning channel for capable models (qwen3, Claude sonnet+opus, Gemini 2.5, OpenAI o-series). Falls back silently otherwise.
- **Tool categories**: toggle whole groups (audio, music, brightness, theme, wallpaper, notification, timer, calendar, panels, app launcher) on or off. Disabled categories disappear from Yura's tool list, and Yura reports back when you ask for something turned off.
- **Allowed apps**: strict allowlist for `app_launch`. The default is empty, meaning Yura cannot open anything until you pick apps. The picker shows installed desktop apps with a search; toggle pills for individual apps, or use "All on / All off" against the current filter. Shell metacharacters (`; | & $` etc.) in launch requests are always rejected.
- **Yura panel side**: Left or Right for the corner pop-up.

When `mugen-ai.service` is not running, the bar shows an install hint instead of the chat UI. The bar icon is safe to ignore if you skip this feature.

A full annotated template lives at `ai/config.toml.example` (or `$(nix path-info .#mugen-ai)/share/mugen-ai/config.toml.example` if you installed via Nix). A minimal `~/.config/mugen-ai/config.toml`:

```toml
[personality]
# Optional auto-header. When name is empty (or "Yura"), a default
# gender-neutral assistant identity is used. Leave all three of
# name/tone/language empty to use system_prompt verbatim.
name = "Yura"
tone = "calm"
language = "en"
system_prompt = "You are a helpful desktop assistant. Be concise."

[provider.google]
models = ["gemini-2.5-flash"]

[provider.anthropic]
models = ["claude-haiku-4-5", "claude-sonnet-4-6", "claude-opus-4-7"]

[provider.openai]
# Any OpenAI-compatible backend: OpenAI, OpenRouter, LM Studio, vLLM, etc.
# base_url = "https://api.openai.com/v1"        # OpenAI itself
# base_url = "https://openrouter.ai/api/v1"     # OpenRouter
# base_url = "http://localhost:1234/v1"         # LM Studio (no API key needed)
# models = ["gpt-4o-mini", "gpt-4o"]            # leave empty to query /v1/models

[tools.app_launch]
# Strict by default: empty list = Yura cannot launch anything. The
# Settings → AI / Yura → Allowed apps picker is the easiest way to
# populate this. Hand-editing also works.
allowed_commands = ["firefox", "kitty", "code"]

[tools]
# Tool categories to hide from Yura (audio / music / brightness /
# theme / wallpaper / notification / timer / calendar / panel / app).
# Empty = every category enabled. Toggle via Settings → AI / Yura →
# Tool categories.
disabled_categories = []
```

- `[personality]`: `name`, `tone`, and `language` build the auto-header. `system_prompt` is appended as free-form text. Empty fields are skipped.
- `[provider.ollama]`: local Ollama is enabled out of the box at `http://localhost:11434`. Override `host` only if your Ollama daemon lives elsewhere.
- `[provider.google].models`: enables Gemini. Requires `GEMINI_API_KEY`. The legacy single-string `model` is still honoured when `models` is empty.
- `[provider.openai]`: enables any OpenAI-compatible provider. Activated when either `OPENAI_API_KEY` is set (for cloud providers) or `base_url` points at a local server. `models` is optional; when empty the provider queries the backend's `/v1/models` endpoint.
- `[provider.anthropic].models`: enables Claude. Requires `ANTHROPIC_API_KEY`. Omit `models` to default to `claude-haiku-4-5`. Recommended for tool-calling (fast, accurate, low cost).
- `[tools.app_launch].allowed_commands`: strict allowlist for the `app_launch` tool. Empty (or block omitted) means no apps can be launched. Matched on binary basename. The backend resolves the basename to the real Exec path from the matching `.desktop` entry, so off-`$PATH` binaries (like Zen Browser's `/opt/zen-browser-bin/zen-bin`) launch correctly. Flatpak apps whose binary is `flatpak` rather than the app name (Discord, Spotify, etc.) are matched by display name as a fallback: as long as `flatpak` is in this list, asking Yura for "Discord" finds the matching `.desktop` entry and launches via its full Exec line.
- `[tools].disabled_categories`: list any of `audio music brightness theme wallpaper notification timer calendar panel app` to hide that group of tools. An MCP server name (see below) also works here as a category.
- `[mcp.servers.<name>]`: registers an external [Model Context Protocol](https://modelcontextprotocol.io) server whose tools are merged into Yura's tool set. See *MCP servers* below.

### MCP servers

mugen-ai can pull tools from external [Model Context Protocol](https://modelcontextprotocol.io) servers (memory, filesystem, GitHub, etc.) and expose them to Yura alongside the built-in shell tools. Add one `[mcp.servers.<name>]` block per server:

```toml
[mcp.servers.memory]
command = "npx"
args = ["-y", "@modelcontextprotocol/server-memory"]
# env = { MEMORY_FILE_PATH = "/home/you/.local/state/mugen-ai/memory.json" }
# disabled = false   # keep the entry but skip spawning it
# trusted = false    # true = skip the approval prompt for this server's tools
```

`command` must be on the service's `PATH`. mugen-ai bundles no server runtimes: an `npx`-based server needs Node.js installed, a `uvx`-based one needs [uv](https://docs.astral.sh/uv/), and so on. Nix users should add the runtime (e.g. `nodejs`) to their `home.packages`.

Each server is spawned as a stdio subprocess when mugen-ai starts. Its tools are merged under a `<name>__<tool>` prefix (`memory__read_graph`, `filesystem__read_file`), so the server name doubles as a tool category: disable a whole server from Yura by adding its name to `[tools].disabled_categories`. Use a short lowercase server name with no underscores so the prefix stays unambiguous. The same security gates as the built-in tools apply (audit log, category gate, result sanitisation), plus the approval prompt below.

A server that fails to spawn or complete the handshake is logged to the journal and skipped. The rest still load. If a connected server later crashes, it is re-dialed automatically the next time one of its tools is used. Restart `mugen-ai.service` after editing the config to pick up server changes.

**Approval prompt.** A tool that may make an irreversible change (sending a message, deleting a record) is held when Yura calls it. An Approve / Deny prompt appears in the chat UI, and the tool runs only if approved. A denial, a timeout, or a closed chat all count as "declined" and are reported back to Yura. mugen-ai decides which tools are gated from the server's `readOnlyHint` and `destructiveHint` tool annotations, falling back to the tool name when a server sends neither (a leading `get` / `list` / `read` / `search` / etc. verb counts as a read). Set `trusted = true` on a server you fully control to run all of its tools without the prompt.

**Secrets in `env`.** Values in a server's `env` table support `${VAR}` references, resolved from mugen-ai's own environment. Put a token in `~/.config/mugen-ai/.env` (loaded by the systemd unit) and reference it as `env = { GITHUB_TOKEN = "${GITHUB_TOKEN}" }` so the secret stays out of `config.toml`. `config.toml` itself is kept at mode `600` regardless.

### Provider API keys

Copy `ai/.env.example` (Nix install: `$(nix path-info .#mugen-ai)/share/mugen-ai/.env.example`) to `~/.config/mugen-ai/.env` and fill in the keys you have, or append directly:

```sh
cat >> ~/.config/mugen-ai/.env <<'EOF'
ANTHROPIC_API_KEY=sk-ant-...
GEMINI_API_KEY=...
OPENAI_API_KEY=...
EOF
chmod 600 ~/.config/mugen-ai/.env
systemctl --user restart mugen-ai.service
```

Only keys with a non-empty value enable their provider. Leave a line blank to opt out of a provider entirely.

### Choosing a model for shell control

Yura acts on the desktop through function-calling tools, so how reliably it can *do* things (not just chat) depends on the model's tool-calling skill.

- **Hosted API models** (Claude, Gemini) are the most reliable. They emit structured tool calls consistently even with the full tool set.
- **Local Ollama**: prefer a recent, mid-sized model. `qwen3:14b` drives the tools reliably. `qwen3:4b` works too, but turn the **Thinking** toggle on for it. With thinking off, it leaks reasoning into the reply. Older or small models (such as `qwen2.5:7b`) tend to print tool calls as plain text instead of emitting them: fine for chat, unreliable for shell control.

A model with no tool support at all is detected and the conversation falls back to chat-only automatically.

### Listen address

`mugen-ai serve --port 11436` switches the listen port for that invocation. To make it sticky for the systemd unit, set `MUGEN_AI_PORT` (and optionally `MUGEN_AI_HOST`, default `127.0.0.1`) in `~/.config/mugen-ai/.env`. The same env vars are read by the shell client (`shell/lib/AiBackend.qml`) so the bar and floating panels stay in sync.

```sh
echo 'MUGEN_AI_PORT=11436' >> ~/.config/mugen-ai/.env
systemctl --user restart mugen-ai.service
```

### HTTP API

`mugen-ai serve` listens on `127.0.0.1:11435` by default. The shell talks to it over plain HTTP. Conversations and messages are persisted in SQLite at `~/.local/state/mugen-ai/history.db`.

| Method | Path | Description |
|--------|------|-------------|
| POST | `/chat` | Send a message, receive an SSE stream. Body: `{message, conversation_id, model, thinking?}`. `conversation_id: 0` auto-creates a new conversation, `>0` appends to that one. `thinking` is an optional bool: absent inherits the conversation's stored value, present overrides it (and persists for that conversation). The first SSE event is `{conversation_id, model}` so the client can sync state. The model bound to a conversation always wins; the request's `model` field only seeds the model on a brand-new conversation. |
| POST | `/chat/confirm` | Answer an approval prompt raised mid-`/chat` by a destructive MCP tool. Body: `{confirm_id, approved}`. `confirm_id` arrives in the stream's `tool_confirm` event. The chat UI calls this. A 404 means the prompt already lapsed (answered or timed out). |
| GET | `/health` | Server status and active model. |
| GET | `/models` | List available models. |
| PUT | `/model` | Set the default model for the *next* new conversation (`{"model": "name"}`). Existing conversations keep their bound model. |
| GET | `/conversations` | List every conversation (id, title, model, thinking, timestamps). |
| GET | `/conversations/current` | Current conversation with its messages. |
| GET | `/conversations/{id}` | A specific conversation with its messages. |
| POST | `/conversations` | Create an empty conversation explicitly. |
| POST | `/conversations/{id}/select` | Make a conversation current. |
| DELETE | `/conversations/{id}` | Delete a conversation. |
| DELETE | `/conversations` | Delete every conversation. The Settings GUI calls this behind a confirm step. |
| GET | `/conversations/stats` | History database path, conversation count, and on-disk size. |
| GET | `/conversations/export` | Every conversation with its messages as one JSON document. |
| GET | `/events` | Server-Sent Events stream of state changes (new conversations / messages) for live UI sync. |
| GET | `/tools` | List the tools the backend exposes to the LLM: built-in shell tools plus any MCP server tools. |
| POST | `/tools/call` | Debug path: invoke a tool by name with no LLM involvement. Body: `{name, args}`. |
| GET | `/mcp/servers` | Startup status of each configured MCP server (`{name, connected, tool_count, error, disabled}`). |
| GET | `/config` | Read the on-disk config plus an `api_key_configured` map (provider env-var presence; value never exposed). |
| PUT | `/config` | Replace the on-disk config atomically. The Settings GUI uses this. Response is `{saved: true, restart_required: true}`. |
| POST | `/config/restart` | Bounce the systemd unit so changes from `/config` take effect. Requires the service to be managed by systemd. |

For terminal use: `mugen-ai chat`.

---

## Voice input (optional)

Yura can also be driven hands-free: say **"Hey Yura"**, speak, and the reply is read aloud.

```
mic → openWakeWord (voice/models/hey_yura.onnx) → silero VAD → whisper.cpp → mugen-ai /chat → VOICEVOX
```

The default stack is Japanese-first but not Japanese-only (see *Other languages* below), and is **not covered by the Nix flake or `make install` yet** — it expects a manual setup on top of a running mugen-ai:

1. **Python venv** for the daemon (Python 3.14 has no tflite wheel, so openwakeword is installed `--no-deps` and runs its ONNX path; the pinned runtime deps are listed in `voice/requirements.txt`):
   ```bash
   cd ~/mugen-shell/voice
   python -m venv .venv
   .venv/bin/pip install --no-deps openwakeword==0.6.0
   .venv/bin/pip install onnxruntime numpy scipy scikit-learn tqdm requests sounddevice
   ```
2. **whisper.cpp** built locally, with the server binary at `~/.local/src/whisper.cpp/build/bin/whisper-server` and a model at `~/.local/share/whisper/ggml-large-v3-turbo.bin` (override via `YURA_WHISPER_BIN` / `YURA_WHISPER_MODEL`). The daemon spawns and supervises the server itself.
3. **VOICEVOX engine** answering on `127.0.0.1:50021`. The shipped `voicevox-engine.service` expects the nixpkgs `voicevox-engine` on `~/.nix-profile/bin`; adjust `ExecStart` for other install methods.
4. **systemd units**:
   ```bash
   ln -s ~/mugen-shell/system/systemd/user/{yura-voice,voicevox-engine}.service ~/.config/systemd/user/
   systemctl --user daemon-reload
   systemctl --user enable --now yura-voice.service
   ```

Runtime control lives in **Settings → Voice input**: an enable toggle (off releases the microphone; picked up live, no restart needed), a follow-up toggle (after a reply the mic stays open a few seconds for the next utterance — no wake word needed; silence returns to idle), a wake-open target (panel / bar / none), a voice picker with per-voice preview, a speech-speed selector, and a speech-recognition language (Auto / JA / EN). Voice, speed, and language apply from the next utterance — the daemon watches `settings.json`. Both Yura UIs get a push-to-talk mic button — it works even with the wake word disabled — which flips into a cancel control while listening.

### Other languages

Only the reply voice is engine-specific; everything else is multilingual already. To run Yura's voice in English (or any other language):

- **TTS**: install [Piper](https://github.com/rhasspy/piper) (`piper` on `PATH`, or `YURA_PIPER_BIN`) and drop voices (`.onnx` + `.onnx.json` pairs from [rhasspy/piper-voices](https://huggingface.co/rhasspy/piper-voices)) into `~/.local/share/piper/voices/`. They appear in the same Settings voice picker as `Piper: <name>` entries — the picked voice carries the engine, so there is no separate engine switch. VOICEVOX is then optional.
- **STT**: set Speech recognition to Auto (per-utterance detection) or a fixed language; whisper covers ~100 languages.
- **Wake word**: with `YURA_WAKEWORD` unset, the daemon uses openWakeWord's bundled English `hey_jarvis`. The shipped `hey_yura.onnx` is tuned for Japanese pronunciation; retrain via `voice/train/` for other accents.
- **Replies**: set the assistant's language under Settings → AI / Yura → Personality.

Environment knobs, set in the unit or a drop-in: `YURA_WAKEWORD` (path to a custom model; default `hey_jarvis`), `YURA_WAKE_THRESHOLD` (ships at `0.7` for the custom model), `YURA_WAKE_PATIENCE` (consecutive frames over the threshold; default `2`), `YURA_VOICEVOX_SPEAKER` (default `14`), `YURA_VOICE_LANG`, `YURA_VOICE_SPEED`, `YURA_WHISPER_URL`, `YURA_VOICEVOX_URL`.

**Speakers instead of headphones?** Media audio reaching the mic both causes false wakes and drowns out real ones. PipeWire's WebRTC echo cancellation solves both — it subtracts whatever the default sink is playing from the mic, so the wake word works even mid-playback. Drop this into `~/.config/pipewire/pipewire.conf.d/99-yura-echo-cancel.conf` (set `target.object` to your mic's `node.name` from `wpctl inspect`), restart PipeWire, then make the new source the default input with `wpctl set-default <id>`:

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

### Wake word model

`voice/models/hey_yura.onnx` is a custom openWakeWord model trained on VOICEVOX-synthesized Japanese pronunciations of "Hey Yura" (127 speaker styles, ~9,600 clips), so it fits Japanese-accented speech much better than the stock English models. Held-out recall@0.7 is 0.91 with 2.8% false positives on deliberately similar phrases. The full pipeline — clip generation, augmentation, training, verification — lives in [`voice/train/`](voice/train/README.md) and runs locally (ROCm GPU supported).

---

## Keybindings

### Mugen Shell

| Keybinding | Action |
|-----------|--------|
| `Super + R` | App launcher |
| `Super + W` | Wallpaper picker |
| `Super + P` | Power menu |
| `Super + V` | Clipboard history |
| `Super + M` | Music player |
| `Super + T` | Notification center |
| `Super + Y` | Yura (bar) |
| `Super + Shift + Y` | Yura (corner pop-up) |
| `Super + C` | Calendar |
| `Super + S` | Screenshot gallery |
| `Super + U` | Volume / microphone control |
| `Super + I` | WiFi panel |
| `Super + E` | Bluetooth panel |
| `Super + ,` | Settings |
| `Super + Shift + T` | Countdown timer |
| `Super + /` | Keyboard shortcuts reference |
| `Super + Shift + I` | Toggle idle inhibitor |

Most panel keybinds dispatch through `shell/scripts/mugen-shell-ipc.sh` over a Unix socket. The standalone windows (Calendar, Settings, Keyboard shortcuts) live in their own Quickshell processes and are toggled via the matching `toggle-*.sh` scripts instead.

### Window Management

| Keybinding | Action |
|-----------|--------|
| `Super + Enter` | Terminal (`$terminal` in `autostart.conf`, default: kitty) |
| `Super + N` | File manager (`$fileManager`, default: thunar) |
| `Super + B` | Browser (`$browser`, default: firefox) |
| `Super + Backspace` | Close active window |
| `Super + 1-5` | Switch workspace |
| `Super + Shift + 1-5` | Move window to workspace (silent) |
| `Alt + Shift + 1-5` | Move window to workspace |
| `Super + Tab` | Cycle windows in workspace |
| `Super + hjkl` | Move focus between windows (vim-style) |
| `Super + Shift + hjkl` | Move window in tile (vim-style) |
| `Super + Shift + Space` | Toggle floating |
| `Super + F` | Fullscreen |
| `Super + F12` / `Print` | Region screenshot (grim + slurp + wl-copy) |
| `Super + Shift + S` | Toggle special workspace |
| `Super + Shift + R` | Reload Hyprland config |

### Media & System

| Keybinding | Action |
|-----------|--------|
| `XF86AudioLowerVolume` | Volume down |
| `XF86AudioRaiseVolume` | Volume up |
| `XF86AudioMute` | Toggle mute |
| `XF86AudioMicMute` | Toggle mic mute |
| `XF86AudioPlay` | Play/pause |
| `XF86AudioNext` | Next track |
| `XF86AudioPrev` | Previous track |
| `XF86MonBrightnessUp` | Brightness up (laptops with backlight) |
| `XF86MonBrightnessDown` | Brightness down (laptops with backlight) |

---

## Components

### Content panels (`shell/components/content/`)
- **AppLauncherContent**: App search and launch.
- **MusicPlayerContent**: Music player UI with seekable progress slider.
- **NotificationContent**: Notification center.
- **ClipboardContent**: Clipboard history.
- **WiFiContent**: WiFi management UI.
- **BluetoothContent**: Bluetooth management UI.
- **VolumeContent**: Volume / microphone control UI.
- **BrightnessContent**: Backlight slider (laptops only; hidden when no backlight is present).
- **WallpaperContent**: Wallpaper management UI.
- **PowerMenuContent**: Power menu.
- **ScreenshotGalleryContent**: Screenshot gallery.
- **CalendarFloatingContent**: Standalone two-pane Calendar window with SQLite-backed events. Opens in its own window via `Super + C`.
- **TimerContent**: Countdown timer UI (idle / running, ring + presets, keyboard control).
- **SettingsFloatingContent**: Standalone Settings window with sidebar categories (rows in `settings/`).
- **KeyboardShortcutsContent**: Standalone keyboard shortcut reference (`Super + /`).
- **AiAssistantContent**: Bar input row (`Super + Y`).
- **AiAssistantFloatingContent**: Chat tree mounted inside the Yura corner panel (sidebar, message list, model dropdown, in-panel Yura indicator).

### Yura (`shell/components/yura/`, `shell/yura-shell.qml`)
- **yura-shell.qml**: Standalone Quickshell process. Auto-started by Hyprland and toggled via `qs ipc call yura toggle`.
- **YuraChatPanel**: Side-anchored layer-shell window that loads `AiAssistantFloatingContent`. The indicator orb is rendered inside the panel rather than as a separate overlay.

### Managers (`shell/components/managers/`)
MusicPlayerManager, NotificationManager, ClipboardManager, WiFiManager, BluetoothManager, AudioManager, AudioLevel, CavaManager, MicCavaManager, BatteryManager, BrightnessManager, WallpaperManager, ScreenshotManager, IdleInhibitorManager, ImeStatus.

### Core libraries (`shell/lib/`)
ModeManager, SettingsManager, TimerManager, Colors, Typography, Animations, IconProvider, IconResolver, AiBackend, IpcRouter, YuraState.

---

## Troubleshooting

### USB keyboard/mouse becomes unresponsive (e.g. when opening pavucontrol)

**Symptom:** Keyboard and mouse stop working after opening `pavucontrol`.
**Cause:** USB polling triggers the wireless dongle to enter power-saving (suspend) mode.
**Fix:** Disable USB autosuspend via kernel parameter.

```bash
sudo nano /etc/default/grub
# Add: GRUB_CMDLINE_LINUX_DEFAULT="... usbcore.autosuspend=-1"
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

### Audio/video freezes when using a wireless headset

**Symptom:** Switching to a wireless headset kills audio. Logs show `Failed to get percentage from UPower`.
**Fix:** `sudo systemctl enable --now upower`

### Firefox / Zen Browser conflicts with PipeWire

**Symptom:** Opening audio settings while the browser is running causes a crash.
**Fix:** In `about:config`, set `media.cubeb.sandbox` to `false` and restart the browser.

### Unwanted audio output devices appearing

**Fix:** Open `pavucontrol` → Configuration tab → set unused devices (e.g. GPU audio) to Off.

---

## Credits

- [Hyprland](https://hyprland.org/) — Wayland compositor
- [Quickshell](https://quickshell.outfoxxed.me/) — Shell framework
- [Matugen](https://github.com/InioX/matugen) — Material You color generation
- [Cava](https://github.com/karlstav/cava) — Audio visualizer
- [Kitty](https://sw.kovidgoyal.net/kitty/) — Terminal emulator
- [playerctl](https://github.com/altdesktop/playerctl) — Media player control
- [grim](https://sr.ht/~emersion/grim/) / [slurp](https://github.com/emersion/slurp) — Screenshot tools
- [cliphist](https://github.com/sentriz/cliphist) — Clipboard history
