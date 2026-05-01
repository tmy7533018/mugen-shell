# mugen-shell

https://github.com/user-attachments/assets/c82fab1d-ac78-4d50-b770-a7dbd00ec94f

Built with **Quickshell + Hyprland**.

> Personal dotfiles — not intended for general use, but installable via Nix flake or a plain Makefile if you want to.

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

https://github.com/user-attachments/assets/6c9af2a4-cdf1-4941-b417-14837393db36

AI chat panel (`Super + A`) powered by **mugen-ai** — a Go server bundled in this repo under [`ai/`](ai/), supporting local [Ollama](https://ollama.com) models and Google Gemini.

Built and enabled automatically on either install path (Nix flake or `make install` — see [SETUP.md](SETUP.md)).

- Streaming SSE responses with stop button
- Runtime model switching from the UI
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
- Calendar widget
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
- In-shell settings panel

---

## Usage

Once installed (see [SETUP.md](SETUP.md)), the bar starts via Hyprland's `exec-once`.

Most-used panels:

| Key | Action |
|---|---|
| `Super + R` | App launcher |
| `Super + W` | Wallpaper picker |
| `Super + V` | Clipboard history |
| `Super + L` | Power menu |
| `Super + A` | AI assistant |
| `Super + T` | Notification center |
| `Super + ,` | Settings |

Right-click the power menu icon to jump straight into settings. Click the chevron next to the notification icon to expand the system tray. Full keybind list lives in [SETUP.md](SETUP.md).

---

## License

MIT License
