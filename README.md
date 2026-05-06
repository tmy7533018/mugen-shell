<p align="center">
  <img src="shell/assets/branding/mugen-shell_logo.png" width="120" alt="mugen-shell logo" />
</p>

<h1 align="center">mugen-shell</h1>

<p align="center"><i>A 夢幻 desktop, built on Quickshell + Hyprland.</i></p>

https://github.com/user-attachments/assets/618c182d-ecc1-4f84-a228-bddcf990beb1

> Personal dotfiles, packaged so others can try them via Nix flake or a plain Makefile.

For directory layout, install paths (Nix flake home-manager module or manual `make install`), dependencies, and keybindings see [SETUP.md](SETUP.md).

---

## Environment

| | |
|---|---|
| OS | Garuda Linux (Arch-based) |
| GPU | AMD Radeon RX 9070 XT |
| WM | Hyprland |
| Shell | Zsh + Starship |
| Terminal | Kitty |
| Desktop Shell | Quickshell |
| Wallpaper | awww / mpvpaper |
| Colors | Matugen (Material You) |

---

## AI Assistant

https://github.com/user-attachments/assets/6cd18b39-5ec2-4c23-8c08-95fd2457db64

AI chat panel (`Super + A` for the bar version, `Super + Shift + A` for a dedicated floating window) powered by **mugen-ai** — a Go server bundled in this repo under [`ai/`](ai/), supporting local [Ollama](https://ollama.com) models and Google Gemini.

Built and enabled automatically on either install path (Nix flake or `make install` — see [SETUP.md](SETUP.md)).

- Streaming SSE responses with stop button
- Runtime model switching from the UI
- Dedicated floating window with a dream-styled UI (cosmic gradient, drifting particles, ambient orb that travels from the centre to follow the latest AI reply)
- Welcome screen with suggestion chips
- Multiline input (Shift + Enter)
- Copy button per message
- Smart auto-scroll
- BlobEffect breathing indicator
- Configurable personality and real-time context injection (date/time, weather)

Configuration, the HTTP API, and the Gemini API key step live in [SETUP.md → Configuring mugen-ai](SETUP.md#configuring-mugen-ai).

---

## Preview

[TikTok demo — @ripnk6498](https://www.tiktok.com/@ripnk6498/video/7579183858038492433?is_from_webapp=1&sender_device=pc)

---

## Features

- Wallpaper-driven Material You color scheme via Matugen
- Video and image wallpaper switching (mpvpaper + awww)
- Wallpaper picker UI
- Music player integration (playerctl / MPRIS) with YouTube thumbnail fallback and a seekable glowing progress slider
- Cava audio visualizer
- Notification center
- Calendar with SQLite-backed events in a standalone night-sky window (purple gradient + starfield + crescent moon, two-pane month grid + events list, add / edit / inline modal, weekday-tinted grid, today ring, event dots, monthly count, jump-to-today)
- Countdown Timer (`Super + Shift + T`) with preset durations, free-form M:SS input, full keyboard control, glowing progress ring, configurable completion sound, and a live remaining-time pill in the bar
- Configurable bar date format (Qt date tokens, e.g. `ddd M/d`, `yyyy-MM-dd`)
- Detach panel — Settings can open as a standalone floating window (state synced with the bar via JSON + FileView watcher)
- Clipboard history (`Super + V`) with item limit
- WiFi / Bluetooth / IME management
- Speaker / microphone control sharing the volume panel (`Super + U`) with a swap toggle
- System Tray (collapsible)
- Battery indicator (water-level fill inside the power menu icon, opt-in)
- Idle inhibitor toggle
- App Launcher (`Super + R`)
- Screenshot capture with clipboard copy (`Super + F12`)
- Screenshot gallery
- Power menu
- In-shell settings panel with configurable notification + timer sounds, theme, blur, animations, lock-timer, and date format

---

## Usage

Once installed (see [SETUP.md](SETUP.md)), the bar starts via Hyprland's `exec-once`.

Most-used panels:

| Key | Action |
|---|---|
| `Super + R` | App launcher |
| `Super + W` | Wallpaper picker |
| `Super + M` | Music player |
| `Super + U` | Volume / mic control |
| `Super + V` | Clipboard history |
| `Super + T` | Notification center |
| `Super + A` | AI assistant |
| `Super + Shift + A` | AI assistant (floating window) |
| `Super + C` | Calendar |
| `Super + Shift + T` | Timer |
| `Super + H` | WiFi |
| `Super + J` | Bluetooth |
| `Super + S` | Screenshot gallery |
| `Super + L` | Power menu |
| `Super + ,` | Settings |
| `Super + /` | Keyboard shortcuts reference |

Right-click the power menu icon to jump straight into settings. Click the chevron next to the notification icon to expand the system tray. Full keybind list lives in [SETUP.md](SETUP.md).

---

## License

MIT License
