<p align="right"><b>English</b> | <a href="SETUP.md">日本語</a></p>

# mugen-shell: Setup Guide

## Runtime data

Everything lives outside the repo, under XDG dirs:

| Where | What |
|---|---|
| `$XDG_CONFIG_HOME/mugen-shell/settings.json` | Persisted user settings |
| `$XDG_STATE_HOME/mugen-shell/{theme-mode,idle-inhibitor.json,keybinds.json,launcher.json,notifications.json,timer.json,notified.json}` | Toggleable state and exported listings |
| `$XDG_CACHE_HOME/mugen-shell/{colors.json,weather.json,apps_v4.json,apps_v4.sha256,wallp/,wallpaper-thumbs/,clipboard-thumbs/,art/}` | Regenerable cache |
| `$XDG_DATA_HOME/mugen-shell/{wallpapers/,sounds/,timer-sounds/,tts/}` | User-supplied media |
| `$XDG_DATA_HOME/mugen-shell/calendar.db` | Calendar SQLite database |
| `$XDG_PICTURES_DIR/mugen-screenshots/` | Captured screenshots |

Audio files dropped into `sounds/` and `timer-sounds/` above show up in the Settings dropdowns for notification and timer sounds.

---

## Install

Needs **Hyprland 0.55 or newer**. Arch Linux installs from packages; on any other distribution, open one of the Nix routes below.

### Arch Linux

```bash
git clone https://github.com/tmy7533018/mugen-shell.git
cd mugen-shell
./install.sh
```

A menu lets you pick what goes in. Taking the defaults leaves you with a desktop you can log into.
Read-aloud is off by default: it builds `onnxruntime` from source, which takes hours.

To run it without the menu:

```bash
./install.sh --yes                      # the defaults
./install.sh --with-voice --without-zsh # pick individually (--help lists them)
```

When it finishes, log out and pick **mugen-shell** from your display manager's session list.

<details>
<summary>Installing by hand instead</summary>

**1. Install what the build needs**

```bash
sudo pacman -S --needed base-devel git
```

**2. Install an AUR helper**

`paru-bin` is pinned to the libalpm it was built against and will not run, so build `yay` from source:

```bash
git clone https://aur.archlinux.org/yay.git
(cd yay && makepkg -si)
```

**3. Install the dependencies that come from the AUR**

```bash
yay -S --needed mpvpaper awww matugen ttf-mplus-git libcava
```

The UI names `M PLUS 2` and `M PLUS 1 Code`, so the Nerd Fonts build (`ttf-mplus-nerd`) is not a substitute.

**4. Build and install**

```bash
git clone https://github.com/tmy7533018/mugen-shell.git
cd mugen-shell/arch/mugen-shell
makepkg -si
```

Read-aloud is a separate package. If you want it, see [Read aloud](#read-aloud-optional).

**5. Log in**

Pick **mugen-shell** from your display manager's session list (sddm, for instance; install and enable one first if you have none). No environment variables to set.

**Japanese input (other languages work the same way)**

```bash
sudo pacman -S --needed fcitx5 fcitx5-mozc fcitx5-gtk fcitx5-qt fcitx5-configtool
# or:  fcitx5-rime    for Chinese
# or:  fcitx5-hangul  for Korean
```

The session wrapper sets `XMODIFIERS` inside the session. For apps launched outside the compositor, add `XMODIFIERS=@im=fcitx` to `/etc/environment` as well.

**Make the terminal match mugen-shell too**

Gets you the starship prompt, fish-style completion and history, `ls` → `eza` aliases, and the fastfetch ASCII art splash.

```bash
sudo pacman -S --needed zsh starship jp2a fastfetch eza bat ugrep \
     zsh-syntax-highlighting zsh-autosuggestions zsh-history-substring-search
```

Then add this one line to your own `~/.zshrc`:

```sh
source /usr/share/mugen-shell/zsh/mugen-shell.zshrc
```

</details>

<details>
<summary><b>NixOS</b></summary>

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
        ./configuration.nix  # the config nixos-generate-config already made
        mugen-shell.nixosModules.default
        home-manager.nixosModules.home-manager
        ({ ... }: {
          # System layer
          programs.mugen-shell.enable = true;

          # Required: home-manager won't see the mugen-shell overlay without it
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.YOUR_USER = {
            imports = [ mugen-shell.homeManagerModules.default ];
            programs.mugen-shell.enable = true;
            programs.mugen-shell.includeSystemDeps = false; # already on the system path
            programs.mugen-shell.quickshellExecutable = "/run/current-system/sw/bin/quickshell";
            home.stateVersion = "26.05";
          };
        })
      ];
    };
  };
}
```

Then `nixos-rebuild switch --flake "/etc/nixos#mybox"`.

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
<summary><b>Any non-NixOS Linux, with Nix</b></summary>

Point at the user-level flake (the repo root); the Wayland and compositor stack comes from your distribution. The package names below are Arch's.

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
          # Puts the home-manager CLI in your profile, for updates after the first switch
          programs.home-manager.enable = true;
          programs.mugen-shell.enable = true;
          # Wayland stack already on the OS path, skip the Nix copies
          programs.mugen-shell.includeSystemDeps = false;
          programs.mugen-shell.quickshellExecutable = "/usr/bin/quickshell";
          # Stop the mugen-ai service with: programs.mugen-shell.ai.enable = false;
          home.stateVersion = "26.05";
        })
      ];
    };
  };
}
```

Install the system stack with pacman before the first switch. Some of it comes from the AUR, so install an AUR helper such as `yay` first:

```bash
yay -S hyprland quickshell qt6-5compat hypridle hyprpolkitagent zsh kitty firefox libnotify \
       pipewire pipewire-pulse pavucontrol cava playerctl \
       networkmanager bluez bluez-utils \
       fcitx5 fcitx5-mozc fcitx5-gtk fcitx5-qt fcitx5-configtool \
       awww mpvpaper ffmpeg matugen-bin socat \
       grim slurp wl-clipboard cliphist imv curl jq xdg-utils brightnessctl fzf \
       thunar gtk3 gnome-themes-extra dconf gsettings-desktop-schemas \
       xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-hyprland \
       ttf-mplus-git ttf-firacode-nerd ttf-jetbrains-mono-nerd noto-fonts-emoji \
       python-gobject
```

The UI names `M PLUS 2` and `M PLUS 1 Code`, so the Nerd Fonts build (`ttf-mplus-nerd`) is not a substitute.

The audio visualiser's QML module is built by Nix. If quickshell fails to import `Mugen.Audio` with `version 'Qt_6.11' not found`, your Qt6 is older than the one it was built against: update Qt.

`includeSystemDeps = true` pulls the user-space tools on that list (Quickshell, hypridle, awww, matugen, kitty, …) into Nix instead; Hyprland itself, the system services, and the fonts stay on pacman either way.

**Activating**

Turn on Nix flakes, which the official installer leaves off. A command-line flag is not enough, because home-manager shells out to `nix` itself:

```bash
echo 'experimental-features = nix-command flakes' | sudo tee -a /etc/nix/nix.conf
sudo systemctl restart nix-daemon
```

There is no `home-manager` command yet on a fresh machine, so run the first activation through `nix run`:

```bash
nix run home-manager/master -- switch --flake ~/".config/home-manager#YOUR_USER"
```

After that, `home-manager switch --flake ~/".config/home-manager#YOUR_USER"` updates it.

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

`QML2_IMPORT_PATH` has to be in Hyprland's environment or the shell will not start. home-manager writes it into `hm-session-vars.sh`, so a TTY login shell picks it up on its own; from a display manager, source that file in the session (`echo $QML2_IMPORT_PATH` tells you whether it is there).

Activation places the shipped `system/hypr/` and `matugen/` under `~/.config/`. Their contents are refreshed on every later activation too, except `hypridle.conf`, which is created only once and left alone after that. `colors.lua`, `configs/blur.lua`, `configs/user-overrides.lua` and `configs/keybind-overrides.lua` are not created by activation at all: the first two are written when matugen and `blur-preset.sh` run, and the two override files are yours to create when you need them. `cava`, `kitty`, `fastfetch`, `starship.toml`, and the `gtk-3.0/gtk.css` and `gtk-4.0/gtk.css` that let GTK follow matugen's colours still copy only when that path does not exist yet, as before. If you already have a Hyprland config, add the autostart to it by hand; without it nothing spawns `quickshell -c mugen-shell`:

```lua
dofile(os.getenv("HOME") .. "/.config/hypr/configs/mugen-shell.lua")
```

Activation already places that file at `~/.config/hypr/configs/mugen-shell.lua`, so there is nothing to copy.

**Still on a hyprlang (`.conf`) config?** The equivalent line is:

```hypr
source = ~/.config/hypr/configs/mugen-shell.conf
```

Two things to do yourself:

- **Lock screen PAM file.** The lock screen falls back to hyprlock's or
  swaylock's stack if one exists; with none of them it cannot authenticate and
  `ext-session-lock` holds the session locked. Install the shipped stack (an
  `include system-auth` would let a passwordless account unlock on an empty
  password):
  ```bash
  sudo curl -fLo /etc/pam.d/mugen-lock \
    https://raw.githubusercontent.com/tmy7533018/mugen-shell/main/system/pam/mugen-lock
  ```
- **fcitx5 env vars.** The shipped `system/hypr/hyprland.lua` exports `XMODIFIERS=@im=fcitx` for Hyprland sessions; add the same line to `/etc/environment` for anything started outside the compositor.

</details>

---

## Configuring mugen-ai

Everything is configured under **Settings → Yura**: personality, provider status, model, tool categories, allowed apps, panel side. Saving bounces the service for you. **Edit toml** on the same page opens `~/.config/mugen-ai/`, so you can edit `config.toml` there by hand.

Three defaults worth knowing. **No model ships with this.** Yura's panel reads "No model yet" until you install Ollama and pull one (`ollama pull qwen3:4b`, say) or put an API key in `~/.config/mugen-ai/.env`. **Allowed apps starts empty** too, so Yura cannot launch anything until you pick apps there. And when `mugen-ai.service` itself is not running, that panel (`Super + Shift + Y`) shows the command to start it.

A full annotated template lives at `ai/config.toml.example`. Arch installs it to `/usr/share/mugen-ai/config.toml.example`; Nix puts it at `$(nix build --no-link --print-out-paths "github:tmy7533018/mugen-shell#mugen-ai")/share/mugen-ai/config.toml.example`.

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
- `[provider.google]` needs `GEMINI_API_KEY`; `[provider.anthropic]` needs `ANTHROPIC_API_KEY`. `models` is optional for both. Omit it and each provider falls back to a single default model. To pin one, check that provider's own docs for a current model ID.
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

Copy `ai/.env.example` (Arch: `/usr/share/mugen-ai/.env.example`; Nix: `$(nix build --no-link --print-out-paths "github:tmy7533018/mugen-shell#mugen-ai")/share/mugen-ai/.env.example`) to `~/.config/mugen-ai/.env` and fill in the keys you have, or append directly:

```sh
cat >> ~/.config/mugen-ai/.env <<'EOF'
ANTHROPIC_API_KEY=sk-ant-...
GEMINI_API_KEY=...
OPENAI_API_KEY=...
EOF
chmod 600 ~/.config/mugen-ai/.env
systemctl --user restart mugen-ai.service
```

Only keys with a non-empty value enable their provider. `GOOGLE_API_KEY` is read too when `GEMINI_API_KEY` is empty.

### Choosing a model for shell control

How reliably Yura can *do* things (not just chat) depends on the model's tool-calling skill. Hosted API models (Claude, Gemini) are the most reliable; on local Ollama, prefer a recent mid-sized model. `qwen3:14b` drives the tools well, and `qwen3:4b` does too with the **Thinking** toggle on. A model with no tool support falls back to chat-only automatically.

### Listen address

The server listens on a unix socket at `$XDG_RUNTIME_DIR/mugen-ai/mugen-ai.sock`, not a TCP port, so no other user on the machine can reach it. To move it, set `MUGEN_AI_SOCKET` as a login-session environment variable. The server, the shell and the voice daemon each read it from their own environment, so putting it in `~/.config/mugen-ai/.env` moves the server alone and leaves the other two unable to connect.

Conversations live in SQLite at `~/.local/state/mugen-ai/history.db`. For terminal use: `mugen-ai chat`.

---

## Read aloud (optional)

Yura can speak its replies: press the speaker icon on a reply in the panel.

The default stack is Japanese-first but not Japanese-only (see *Running Yura's voice in another language* below). It sits on top of a running mugen-ai.

**Arch Linux.** `python-sherpa-onnx` builds from source on the AUR, and it builds `onnxruntime` with it, so expect hours:

```bash
yay -S --needed python-sherpa-onnx python-sounddevice
cd mugen-shell/arch/mugen-voice
makepkg -si
```

For a Japanese voice, add the AivisSpeech engine. Installing it is what switches the default voice over to it:

```bash
cd ../aivisspeech-engine
makepkg -si
```

**Nix (NixOS and home-manager alike).** One option packages the whole thing:

```nix
programs.mugen-shell.voice.enable = true;
# programs.mugen-shell.voice.aivis.enable = false;      # skip the AivisSpeech engine
```

Everything comes from the store, so there is no checkout and no need for `nix-ld`.

On either route the AivisSpeech engine downloads its default voice model (~900 MB) on first start, so it needs the network once. With the engine installed, replies are routed at it automatically and are audible before any voice is picked in Settings. VOICEVOX is not part of either route; run it yourself and its voices join the same picker.

The engine starts on demand (it costs ~2.6 GB resident) and stops after `voice.idleStopMin` minutes without synthesis (default 10, hand-edited in `settings.json`). Set `YURA_TTS_SERVICE=` empty in the unit to run it yourself instead.

Runtime control lives in **Settings → Yura → Voice**: voice picker, speech speed and volume. The daemon watches `settings.json`, so nothing needs a restart.

<details>
<summary><b>Running Yura's voice in another language</b></summary>

Only the reply voice is engine-specific; everything else is multilingual already:

- **TTS**: local voices run in-process through sherpa-onnx, so there is no `piper` binary to install. Take a model from the [sherpa-onnx TTS models release](https://github.com/k2-fsa/sherpa-onnx/releases/tag/tts-models) (Piper/VITS and Kokoro both work) and unpack the whole **model directory** (the `.onnx` next to its `tokens.txt` and `espeak-ng-data/`) into `~/.local/share/mugen-shell/tts/`, or point `YURA_TTS_MODELS` somewhere else. Each directory then appears in the Settings voice picker, and VOICEVOX becomes optional. `vits-piper-en_US-lessac-high` ships on both routes.
- **Replies**: set the assistant's language under Settings → Yura → Model → Personality.

**Environment knobs**, set in the unit or a drop-in: `YURA_TTS` (`<engine>:<style-id>`), `YURA_VOICEVOX_SPEAKER`, `YURA_VOICE_SPEED`, `YURA_VOICEVOX_URL`, `YURA_AIVIS_URL`. Anything Settings also exposes wins from `settings.json` once the shell has saved it.

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
- [VOICEVOX](https://voicevox.hiroshiba.jp/): TTS engine
- [AivisSpeech Engine](https://github.com/Aivis-Project/AivisSpeech-Engine): VOICEVOX-compatible TTS with Style-Bert-VITS2 voices, models from [AivisHub](https://hub.aivis-project.com/)
- [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx): in-process TTS for local voices
- [Piper](https://github.com/rhasspy/piper): the model behind the default English voice
- [LRO WAC moon mosaic](https://commons.wikimedia.org/wiki/File:Moon_nearside_LRO.jpg): the moon on the lock screen. NASA/GSFC/Arizona State University, public domain (bundled brightness-adjusted and scaled down to 320px)
