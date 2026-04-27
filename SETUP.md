# mugen-shell — Setup Guide

## Directory Structure

```
mugen-shell/
├── .config/
│   ├── mugen-shell/          # Mugen Shell (Quickshell config)
│   │   ├── assets/
│   │   │   ├── branding/     # Logo and banner
│   │   │   ├── icons/        # SVG icons
│   │   │   └── screenshots/  # Screenshot storage (user-generated)
│   │   ├── components/
│   │   │   ├── bar/          # Bar components (left/right sections)
│   │   │   ├── common/       # Shared UI components
│   │   │   ├── content/      # Per-mode content panels
│   │   │   ├── managers/     # Managers (Window, WiFi, Bluetooth, etc.)
│   │   │   ├── notification/ # Notification components
│   │   │   └── ui/           # UI elements (clock, workspaces, etc.)
│   │   ├── lib/              # Libraries (ModeManager, Colors, Typography, etc.)
│   │   ├── scripts/          # Shell and Python scripts
│   │   ├── wallpapers/       # Wallpapers (images/ and videos/, user-supplied)
│   │   ├── windows/          # Window definitions (Bar.qml)
│   │   ├── settings.default.json
│   │   └── shell.qml         # Entry point
│   ├── hypr/                 # Hyprland config
│   │   ├── configs/          # Config files (keybinds, windowrules, etc.)
│   │   ├── scripts/          # Hyprland scripts
│   │   └── hyprland.conf     # Main config
│   ├── kitty/                # Kitty terminal
│   ├── fastfetch/            # System info
│   ├── matugen/              # Material You colors
│   │   └── templates/        # Color templates
│   ├── cava/                 # Audio visualizer
│   │   ├── shaders/          # GLSL shaders
│   │   └── themes/           # Color themes
│   └── starship.toml         # Starship prompt config
├── mugen-ai/                 # Bundled AI backend (Go)
├── Makefile                  # `make install-ai` builds and installs mugen-ai
├── .zshrc                    # Zsh configuration
├── README.md
└── SETUP.md                  # This file
```

**Notes:**
- mugen-shell must be symlinked to `~/.config/quickshell/mugen-shell`.
- The `wallpapers/images/` and `wallpapers/videos/` directories are excluded from git (large files); place your own wallpapers there.

---

## Dependencies

### Core

| Package | Purpose |
|---------|---------|
| **hyprland** | Wayland compositor |
| **quickshell** | Shell framework (bar and widgets) |
| **zsh** | Shell |
| **xdg-desktop-portal-hyprland** | Desktop portal |
| **polkit-gnome** | Authentication agent |

### Audio

| Package | Purpose |
|---------|---------|
| **pipewire** | Audio server |
| **pipewire-pulse** | PulseAudio compatibility layer |
| **pactl** (pulseaudio-utils) | Volume control |
| **pamixer** | CLI audio mixer |
| **cava** | Real-time audio visualizer |
| **playerctl** | Media player control (MPRIS D-Bus) |
| **libnotify** | Notification command (`notify-send`) |

### Network & Bluetooth

| Package | Purpose |
|---------|---------|
| **NetworkManager** | Network management |
| **nmcli** | WiFi management |
| **nm-applet** | Network connection indicator |
| **bluez** | Bluetooth stack |
| **bluetoothctl** | Bluetooth management |

### Input Method

| Package | Purpose |
|---------|---------|
| **fcitx5** | Input method framework |
| **fcitx5-mozc** | Japanese input (Mozc) |
| **fcitx5-remote** | IME status query |
| **fcitx5-im** | Meta package for environment variables |
| **fcitx5-configtool** | GUI configuration tool |

### Wallpaper

| Package | Purpose |
|---------|---------|
| **awww** | Image wallpaper with transitions (active fork of swww) |
| **mpvpaper** | Video wallpaper |
| **ffmpeg** | Thumbnail generation and frame extraction |
| **matugen** | Material You color generation |
| **socat** or **netcat-openbsd** | mpvpaper IPC communication |

### Screenshot

| Package | Purpose |
|---------|---------|
| **grim** | Screen capture |
| **slurp** | Region selection |
| **swappy** | Screenshot editor |

### Clipboard

| Package | Purpose |
|---------|---------|
| **wl-clipboard** | Clipboard operations (`wl-copy`, `wl-paste`) |
| **cliphist** | Clipboard history manager |

### Screen Lock & Idle

| Package | Purpose |
|---------|---------|
| **hypridle** | Idle detection (systemd user service) |
| **hyprlock** | Lock screen |

### Terminal & Shell

| Package | Purpose |
|---------|---------|
| **kitty** | Terminal emulator |
| **starship** | Shell prompt |
| **zen-browser** (optional) | Default browser |
| **zsh-syntax-highlighting** | Syntax highlighting |
| **zsh-autosuggestions** | Command suggestions |
| **zsh-history-substring-search** | History search |
| **fzf** | Fuzzy finder |
| **mcfly** | AI command history search |

### CLI Utilities

| Package | Purpose |
|---------|---------|
| **eza** | `ls` replacement |
| **bat** | `cat` replacement |
| **ugrep** | `grep` replacement |
| **fastfetch** | System information display |
| **jp2a** | Image to ASCII art |
| **thunar** | File manager |

### D-Bus

mugen-shell uses D-Bus for real-time updates:

| Service | Purpose |
|---------|---------|
| **org.freedesktop.NetworkManager** | WiFi connection state |
| **org.bluez** | Bluetooth state |
| **org.freedesktop.DBus.Properties** (MPRIS) | Media player |
| **org.fcitx.Fcitx5** | IME state |
| **org.freedesktop.systemd1** | hypridle service state |

Required tool: **dbus-monitor**

### Python

Required for `list-apps.py` (app launcher):

```bash
# Arch Linux
pacman -S python-gobject
```

### Themes & Fonts

| Package | Purpose |
|---------|---------|
| **Colloid-gtk-theme** | GTK theme (Colloid-Grey-Dark) |
| **Bibata-Modern-Classic** | Cursor theme |
| **M PLUS 2** font | UI and lock screen |
| **Nerd Fonts** (optional) | Icon display |

### AI Assistant (optional)

The `Super + A` panel is powered by **mugen-ai**, a Go HTTP server bundled in this repo under [`mugen-ai/`](mugen-ai/). It supports local [Ollama](https://ollama.com) models and Google Gemini.

Build and install via the bundled Makefile:

```bash
make install-ai
```

This builds the binary, installs the systemd user unit (`~/.config/systemd/user/mugen-ai.service`), and enables it. To uninstall: `make uninstall-ai`.

API keys (for Gemini) live in `~/.config/mugen-ai/.env`. When `mugen-ai.service` is not running, the AI panel shows an install hint instead of the chat UI, so the bar icon stays harmless if you don't want this feature.

### Optional

| Package | Purpose |
|---------|---------|
| **hyprpolkitagent** | Polkit agent for Hyprland |
| **apply-gsettings** | Apply GSettings |
| **xrdb** | Load Xresources |
| **reflector** | Mirror optimization (Arch Linux) |
| **expac** | Package info query |

### Install all (Arch Linux)

```bash
yay -S hyprland quickshell zsh kitty starship libnotify
yay -S pipewire pipewire-pulse pavucontrol cava playerctl pamixer
yay -S networkmanager network-manager-applet bluez bluez-utils
yay -S fcitx5 fcitx5-mozc fcitx5-im fcitx5-configtool
yay -S awww mpvpaper ffmpeg matugen-bin socat
yay -S grim slurp swappy wl-clipboard cliphist
yay -S hypridle hyprlock
yay -S zsh-syntax-highlighting zsh-autosuggestions zsh-history-substring-search fzf mcfly
yay -S eza bat ugrep fastfetch jp2a thunar
yay -S ttf-mplus-nerd bibata-cursor-theme colloid-gtk-theme-git
yay -S python-gobject
```

---

## Installation

### 1. Clone

```bash
git clone https://github.com/tmy7533018/mugen-shell.git ~/mugen-shell
cd ~/mugen-shell
```

### 2. Create symlinks

```bash
mkdir -p ~/.config/quickshell

ln -sf ~/mugen-shell/.config/mugen-shell ~/.config/quickshell/mugen-shell
ln -sf ~/mugen-shell/.config/hypr ~/.config/hypr
ln -sf ~/mugen-shell/.config/kitty ~/.config/kitty
ln -sf ~/mugen-shell/.config/fastfetch ~/.config/fastfetch
ln -sf ~/mugen-shell/.config/matugen ~/.config/matugen
ln -sf ~/mugen-shell/.config/cava ~/.config/cava
ln -sf ~/mugen-shell/.config/starship.toml ~/.config/starship.toml
ln -sf ~/mugen-shell/.zshrc ~/.zshrc
```

### 3. Set permissions

```bash
chmod +x ~/.config/hypr/scripts/*.sh
chmod +x ~/.config/quickshell/mugen-shell/scripts/*.sh
```

### 4. (Optional) Install mugen-ai

```bash
make install-ai
```

### 5. Autostart

mugen-shell starts automatically via `hyprland.conf`:

```ini
exec-once = quickshell -c mugen-shell
```

To start manually:

```bash
quickshell -c mugen-shell
```

### 6. Generate color scheme (optional)

```bash
matugen image ~/.config/quickshell/mugen-shell/wallpapers/images/your-wallpaper.png
```

The wallpaper picker UI (`Super + W`) regenerates the color scheme each time you switch wallpapers.

---

## Keybindings

### Mugen Shell

| Keybinding | Action |
|-----------|--------|
| `Super + R` | App launcher |
| `Super + W` | Wallpaper manager |
| `Super + L` | Power menu |
| `Super + V` | Clipboard history |
| `Super + M` | Music player |
| `Super + T` | Notification center |
| `Super + A` | AI assistant (requires mugen-ai) |
| `Super + C` | Calendar |
| `Super + S` | Screenshot gallery |
| `Super + U` | Volume control |
| `Super + H` | WiFi panel |
| `Super + J` | Bluetooth panel |
| `Super + ,` | Settings |
| `Super + Shift + I` | Toggle idle inhibitor |
| `Super + Shift + B` | Pick blur preset (rofi) |

Panel keybinds dispatch through `scripts/mugen-shell-ipc.sh` which talks to the Quickshell IPC over a Unix socket — see [`scripts/mugen-shell-ipc.sh`](.config/mugen-shell/scripts/mugen-shell-ipc.sh) if you want to add more.

### Window Management

| Keybinding | Action |
|-----------|--------|
| `Super + Enter` | Terminal (Kitty) |
| `Super + N` | File manager (Thunar) |
| `Super + B` | Browser (Zen Browser) |
| `Super + Shift + M` | YouTube Music (Zen Browser, new window) |
| `Super + Backspace` | Close active window |
| `Super + 1-5` | Switch workspace |
| `Super + Shift + 1-5` | Move window to workspace (silent) |
| `Alt + Shift + 1-5` | Move window to workspace |
| `Super + Tab` | Cycle windows in workspace |
| `Super + F` | Fullscreen |
| `Super + F12` / `Print` | Screenshot (grim + swappy) |
| `Super + Shift + S` | Toggle special workspace |
| `Super + Shift + mouse:272` | Toggle floating |
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

### Content panels
- **AppLauncherContent** - App search and launch
- **MusicPlayerContent** - Music player UI
- **NotificationContent** - Notification center
- **ClipboardContent** - Clipboard history
- **WiFiContent** - WiFi management UI
- **BluetoothContent** - Bluetooth management UI
- **VolumeContent** - Volume control UI
- **WallpaperContent** - Wallpaper management UI
- **PowerMenuContent** - Power menu
- **ScreenshotGalleryContent** - Screenshot gallery
- **SettingsContent** - Settings panel
- **CalendarContent** - Calendar display
- **AiAssistantContent** - AI chat panel (requires mugen-ai)

### Managers
- **MusicPlayerManager** - Media control via playerctl
- **NotificationManager** - Notification management
- **ClipboardManager** - Clipboard management
- **WiFiManager** - WiFi connection management
- **BluetoothManager** - Bluetooth management
- **AudioManager** - Audio sink/source state and volume
- **AudioLevel** - Per-application audio levels
- **CavaManager** - Cava visualizer management
- **WallpaperManager** - Wallpaper switching
- **ScreenshotManager** - Screenshot management
- **IdleInhibitorManager** - Idle inhibition management
- **ImeStatus** - Input method state

### Core libraries
- **ModeManager** - Mode management (normal, launcher, music, etc.)
- **SettingsManager** - Settings management
- **Colors** - Theme color definitions
- **Typography** - Font and typography
- **Animations** - Animation definitions
- **IconProvider** - Icon resolution
- **IconResolver** - Icon path resolution helpers

---

## Troubleshooting

### USB keyboard/mouse becomes unresponsive (e.g. when opening pavucontrol)

**Symptom:** Keyboard and mouse stop working after opening `pavucontrol`.

**Cause:** USB polling triggers the wireless dongle to enter power-saving (suspend) mode.

**Fix:** Disable USB autosuspend via kernel parameter.

```bash
# Edit /etc/default/grub
sudo nano /etc/default/grub

# Add to GRUB_CMDLINE_LINUX_DEFAULT
GRUB_CMDLINE_LINUX_DEFAULT="... usbcore.autosuspend=-1"

# Apply
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

---

### Audio/video freezes when using a wireless headset

**Symptom:** Switching to a wireless headset kills audio; opening `pavucontrol` during video playback freezes audio and video; logs show `Failed to get percentage from UPower`.

**Cause:** PipeWire (WirePlumber) crashes when UPower is not running and it tries to read headset battery level.

**Fix:**

```bash
sudo systemctl enable --now upower
```

---

### Firefox / Zen Browser conflicts with PipeWire

**Symptom:** Opening audio settings while the browser is running causes a crash.

**Cause:** The browser's audio sandbox deadlocks with the system audio server.

**Fix:** In `about:config`, set `media.cubeb.sandbox` to `false` and restart the browser.

---

### Unwanted audio output devices appearing

**Fix:** Open `pavucontrol`, go to the Configuration tab, and set unused devices (e.g. GPU audio) to Off.

---

## Credits

- [Hyprland](https://hyprland.org/) - Wayland compositor
- [Quickshell](https://quickshell.outfoxxed.me/) - Shell framework
- [Matugen](https://github.com/InioX/matugen) - Material You color generation
- [Fastfetch](https://github.com/fastfetch-cli/fastfetch) - System information
- [Cava](https://github.com/karlstav/cava) - Audio visualizer
- [Kitty](https://sw.kovidgoyal.net/kitty/) - Terminal emulator
- [playerctl](https://github.com/altdesktop/playerctl) - Media player control
- [grim](https://sr.ht/~emersion/grim/) / [slurp](https://github.com/emersion/slurp) / [swappy](https://github.com/jtheoof/swappy) - Screenshot tools
- [cliphist](https://github.com/sentriz/cliphist) - Clipboard history

---

## License

MIT License
