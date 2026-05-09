<p align="center">
  <img src="shell/assets/branding/mugen-shell_logo.png" width="120" alt="mugen-shell logo" />
</p>

<h1 align="center">mugen-shell</h1>

<p align="center"><i>A 夢幻 desktop, built on Quickshell + Hyprland.</i></p>

https://github.com/user-attachments/assets/a432c3e0-0c1b-4fb7-9ab8-f04bb521743a

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

## Yura

https://github.com/user-attachments/assets/e9fef972-9445-4ec4-a08e-2d1ae98c8a11

Yura is the desktop chat persona — a Spotlight-style row in the bar (`Super + A`), a dedicated floating window (`Super + Shift + A`), and a corner orb that pops up a chat panel (`Super + Shift + Y`). It's powered by **mugen-ai**, a Go server bundled in this repo under [`ai/`](ai/) that fronts local [Ollama](https://ollama.com) models, Google Gemini, and any OpenAI-compatible backend (OpenAI, OpenRouter, LM Studio, vLLM, ...).

Built and enabled automatically on either install path (Nix flake or `make install` — see [SETUP.md](SETUP.md)).

- Spotlight-style one-row prompt in the bar — orb + input pill, response streams into the placeholder, navigable read-only after streaming, orb click detaches into the floating window
- Floating window with a dream-styled UI (cosmic gradient, drifting particles, ambient orb that travels from the centre to follow the latest reply) and a collapsible sidebar of past conversations
- SQLite-persisted multi-conversation history (`~/.local/state/mugen-ai/history.db`) — pick up old chats from the sidebar, delete with a hover trash, "+ New chat" stays empty until you actually send something
- Per-conversation model binding — each chat stays on the provider it was started with; the float dropdown locks to read-only mid-conversation, and a Settings entry pins the bar AI's model
- Markdown rendering for assistant replies, with monospace code blocks that have their own hover-reveal copy button
- Streaming SSE responses with stop button, BlobEffect breathing indicator, IME-aware placeholder
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
- In-shell settings panel with configurable notification + timer sounds, theme, blur, animations, lock-timer, date format, and bar AI model

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
| `Super + A` | Yura (bar) |
| `Super + Shift + A` | Yura (floating window) |
| `Super + Shift + Y` | Yura (corner orb) |
| `Super + C` | Calendar |
| `Super + Shift + T` | Timer |
| `Super + I` | WiFi |
| `Super + E` | Bluetooth |
| `Super + S` | Screenshot gallery |
| `Super + P` | Power menu |
| `Super + ,` | Settings |
| `Super + /` | Keyboard shortcuts reference |
| `Super + hjkl` | Move focus between windows (vim-style) |
| `Super + Shift + hjkl` | Move window in tile (vim-style) |
| `Super + Shift + Space` | Toggle floating |

Right-click the power menu icon to jump straight into settings. Click the chevron next to the notification icon to expand the system tray. Full keybind list lives in [SETUP.md](SETUP.md).

---

## License

MIT License
