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
│   │   └── ui/               # Clock, workspaces, power menu, etc.
│   ├── lib/                  # ModeManager, Colors, Typography, ...
│   ├── scripts/              # Shell + Python scripts (blur preset, lock timer, ...)
│   ├── windows/              # Bar.qml (top-level surface)
│   ├── settings.default.json # OSS-friendly defaults
│   └── shell.qml             # Quickshell entry point
├── ai/                       # mugen-ai Go backend
│   ├── cmd/                  # CLI subcommands (chat, serve)
│   ├── internal/             # Provider registry, server, history, ...
│   └── contrib/systemd/      # systemd user unit
├── system/                   # Dotfiles for the surrounding tools
│   ├── hypr/                 # Hyprland (configs/, scripts/, hyprland.conf, ...)
│   ├── kitty/                # Kitty terminal
│   ├── fastfetch/            # System info display
│   ├── matugen/              # Material You color generation + templates
│   ├── cava/                 # Audio visualizer (themes + GLSL shaders)
│   └── starship.toml         # Starship prompt
├── nix/
│   └── home-manager.nix      # home-manager module
├── flake.nix                 # Nix flake entry point
├── flake.lock
├── Makefile                  # `make install` for non-Nix users
├── .zshrc
├── README.md
└── SETUP.md                  # This file
```

**Runtime data lives outside the repo** under XDG dirs:

| Where | What |
|---|---|
| `$XDG_CONFIG_HOME/mugen-shell/settings.json` | Persisted user settings |
| `$XDG_STATE_HOME/mugen-shell/{theme-mode,idle-inhibitor.json}` | Toggleable state |
| `$XDG_CACHE_HOME/mugen-shell/{colors.json,wallp/,wallpaper-thumbs/}` | Regenerable cache |
| `$XDG_DATA_HOME/mugen-shell/{wallpapers/,sounds/}` | User-supplied media |
| `$XDG_PICTURES_DIR/mugen-screenshots/` | Captured screenshots |

Dropping wallpapers / notification sounds: place files under the corresponding XDG path. The notification sound dropdown rescans on every Settings open. Quickest sound start: `mkdir -p ~/.local/share/mugen-shell/sounds && cp /usr/share/sounds/freedesktop/stereo/{bell,message,message-new-instant}.oga ~/.local/share/mugen-shell/sounds/`.

---

## Install

Two paths. Pick whichever matches your setup.

### Path A — Nix flake (recommended)

If you have Nix with flakes enabled (any Linux distro, including non-NixOS), you can pull mugen-shell into your home-manager configuration:

```nix
# flake.nix in your home config
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

          # Skip the runtime-dep block if your OS already provides
          # Hyprland / Quickshell / hypridle / hyprlock / mpvpaper / awww
          # / matugen / etc. (e.g. Garuda or Arch with pacman) — avoids
          # duplicating several GiB of binaries that already live in /usr.
          # programs.mugen-shell.includeSystemDeps = false;

          # Opt out of the mugen-ai backend if you don't want the AI panel.
          # programs.mugen-shell.ai.enable = false;

          home.stateVersion = "26.05";
        })
      ];
    };
  };
}
```

Then:

```bash
home-manager switch --flake .#YOUR_USER
```

The module symlinks the Quickshell tree (readonly) into `~/.config/quickshell/mugen-shell`, copies the system/ dotfiles into `~/.config/{hypr,kitty,cava,matugen,fastfetch}` and `~/.config/starship.toml` on first activation (subsequent activations leave your edits alone), pulls in every runtime dep (Hyprland / hypridle / mpvpaper / awww / matugen / playerctl / grim / slurp / cava / cliphist / wl-clipboard / libnotify / pulseaudio / python3 / ...), and runs `mugen-ai` as a systemd user service.

The runtime-deps block is gated behind `includeSystemDeps`. Set it to `false` if your OS already ships those packages — that one toggle keeps the Nix install footprint to mugen-ai + the QML tree + module overhead, instead of pulling the entire compositor stack into /nix/store next to the copies you already have in /usr.

You still need to wire Hyprland into your display manager / login session yourself (NixOS module, or `Hyprland` from a TTY).

### Path B — manual (Garuda / Arch / any non-Nix Linux)

```bash
git clone https://github.com/tmy7533018/mugen-shell.git ~/mugen-shell
cd ~/mugen-shell
make install        # symlinks + builds and enables mugen-ai
```

`make install` runs both:
- `install-symlinks` — points `~/.config/quickshell/mugen-shell`, `~/.config/{cava,fastfetch,hypr,kitty,matugen}`, and `~/.config/starship.toml` at this checkout
- `install-ai` — `go install` the mugen-ai binary, install + enable the systemd user unit

If you only want one, run that target by itself: `make install-symlinks` or `make install-ai`. To remove: `make uninstall`.

You're responsible for the OS-level packages on this path:

```bash
# Arch / Garuda
yay -S hyprland quickshell hypridle hyprlock zsh kitty starship libnotify \
       pipewire pipewire-pulse pavucontrol cava playerctl pamixer \
       networkmanager network-manager-applet bluez bluez-utils \
       fcitx5 fcitx5-mozc fcitx5-im fcitx5-configtool \
       awww mpvpaper ffmpeg matugen-bin socat \
       grim slurp wl-clipboard cliphist \
       zsh-syntax-highlighting zsh-autosuggestions zsh-history-substring-search fzf \
       eza bat ugrep fastfetch jp2a thunar \
       ttf-mplus-nerd bibata-cursor-theme colloid-gtk-theme-git \
       python-gobject
```

`mugen-ai` needs Go (Path B builds from source via `go install`). Path A bundles a prebuilt binary via the flake.

---

## Configuring mugen-ai

The AI panel (`Super + A`) talks to a local Go server. Settings → AI Assistant has "Edit Config" / "Restart AI" buttons that open `~/.config/mugen-ai/config.toml` in your default editor and bounce the systemd unit, so you don't have to drop to a terminal for tweaks. The neighbouring "Bar AI model" dropdown pins which model the bar `Super + A` panel uses — leave it on "Default (last used in float)" to follow whichever model the floating window most recently selected. When `mugen-ai.service` isn't running, the panel shows an install hint instead of the chat UI — safe to leave the bar icon if you skip this feature.

`~/.config/mugen-ai/config.toml`:

```toml
[personality]
system_prompt = "You are a helpful desktop assistant. Be concise."

[context]
locale = "en"
city = ""

[provider.google]
model = "gemini-2.5-flash"

[provider.openai]
# Any OpenAI-compatible backend: OpenAI, OpenRouter, LM Studio, vLLM, ...
# base_url = "https://api.openai.com/v1"        # OpenAI itself
# base_url = "https://openrouter.ai/api/v1"     # OpenRouter
# base_url = "http://localhost:1234/v1"         # LM Studio (no API key needed)
# models = ["gpt-4o-mini", "gpt-4o"]            # leave empty to ask /v1/models
```

- **`city`** — enables live weather via [wttr.in](https://wttr.in). Leave empty to disable.
- **`[provider.google].model`** — enables Gemini (requires `GEMINI_API_KEY`). Omit to disable.
- **`[provider.openai]`** — enables any OpenAI-compatible provider. Activated when either `OPENAI_API_KEY` is set (cloud providers) or `base_url` points at a local server. `models` is optional; when empty the provider asks the backend's `/v1/models` endpoint.

### Provider API keys

Save secrets in the env file the systemd unit reads:

```sh
cat >> ~/.config/mugen-ai/.env <<'EOF'
GEMINI_API_KEY=...
OPENAI_API_KEY=...
EOF
chmod 600 ~/.config/mugen-ai/.env
systemctl --user restart mugen-ai.service
```

### HTTP API

`mugen-ai serve` runs on `:11435`. The shell talks to it over plain HTTP. Conversations and messages are persisted in SQLite at `~/.local/state/mugen-ai/history.db`.

| Method | Path | Description |
|--------|------|-------------|
| POST | `/chat` | Send a message, receive SSE stream. Body: `{message, conversation_id, model}` — `conversation_id: 0` auto-creates a new conversation, `>0` appends to that one. The first SSE event is `{conversation_id, model}` so the client can sync state. The model bound to a conversation always wins; the request's `model` field only seeds the model on a brand-new conversation. |
| GET | `/health` | Server status and active model |
| GET | `/models` | List available models |
| PUT | `/model` | Set the default model for the *next* new conversation (`{"model": "name"}`). Existing conversations keep their bound model. |
| GET | `/conversations` | List every conversation (id, title, model, timestamps) |
| GET | `/conversations/current` | Current conversation with its messages |
| GET | `/conversations/{id}` | A specific conversation with its messages |
| POST | `/conversations` | Create an empty conversation explicitly |
| POST | `/conversations/{id}/select` | Make a conversation current |
| DELETE | `/conversations/{id}` | Delete a conversation |

For terminal use: `mugen-ai chat`.

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
| `Super + A` | AI assistant |
| `Super + Shift + A` | AI assistant (floating window) |
| `Super + C` | Calendar |
| `Super + S` | Screenshot gallery |
| `Super + U` | Volume / microphone control |
| `Super + I` | WiFi panel |
| `Super + E` | Bluetooth panel |
| `Super + ,` | Settings |
| `Super + Shift + T` | Countdown timer |
| `Super + /` | Keyboard shortcuts reference |
| `Super + Shift + I` | Toggle idle inhibitor |
| `Super + Shift + B` | Pick blur preset (rofi) |

Panel keybinds dispatch through `shell/scripts/mugen-shell-ipc.sh` over a Unix socket — see that script if you want to add more.

### Window Management

| Keybinding | Action |
|-----------|--------|
| `Super + Enter` | Terminal (Kitty) |
| `Super + N` | File manager (Thunar) |
| `Super + B` | Browser (Zen Browser) |
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
| `F10` / `XF86AudioLowerVolume` | Volume down |
| `F11` / `XF86AudioRaiseVolume` | Volume up |
| `F9` / `XF86AudioMute` | Toggle mute |
| `XF86AudioMicMute` | Toggle mic mute |
| `XF86AudioPlay` | Play/pause |
| `XF86AudioNext` | Next track |
| `XF86AudioPrev` | Previous track |

---

## Components

### Content panels (`shell/components/content/`)
- **AppLauncherContent** - App search and launch
- **MusicPlayerContent** - Music player UI with seekable progress slider
- **NotificationContent** - Notification center
- **ClipboardContent** - Clipboard history
- **WiFiContent** - WiFi management UI
- **BluetoothContent** - Bluetooth management UI
- **VolumeContent** - Volume / microphone control UI
- **WallpaperContent** - Wallpaper management UI
- **PowerMenuContent** - Power menu
- **ScreenshotGalleryContent** - Screenshot gallery
- **SettingsContent** - Settings panel (rows in `settings/`)
- **CalendarFloatingContent** - Standalone two-pane Calendar window with SQLite-backed events (opens in its own window via Super + C)
- **TimerContent** - Countdown timer UI (idle / running, ring + presets, keyboard control)
- **SettingsFloatingContent** - Standalone scrolling Settings window (detach target)
- **AiAssistantContent** - AI chat panel

### Managers (`shell/components/managers/`)
MusicPlayerManager, NotificationManager, ClipboardManager, WiFiManager, BluetoothManager, AudioManager, AudioLevel, CavaManager, MicCavaManager, BatteryManager, WallpaperManager, ScreenshotManager, IdleInhibitorManager, ImeStatus.

### Core libraries (`shell/lib/`)
ModeManager, SettingsManager, TimerManager, Colors, Typography, Animations, IconProvider, IconResolver.

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

**Symptom:** Switching to a wireless headset kills audio; logs show `Failed to get percentage from UPower`.
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

---

## License

MIT License
