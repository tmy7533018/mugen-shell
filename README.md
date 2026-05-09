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

https://github.com/user-attachments/assets/2409880e-4214-4b38-951c-834876570aaa

Yura is the desktop chat persona — a Spotlight-style row in the bar (`Super + A`) and a corner pop-up chat panel that slides in from off-screen (`Super + Y`). The older floating window (`Super + Shift + A`) is still around while I'm using both side by side, and will go once the pop-up has settled in. Yura is powered by **mugen-ai**, a Go server bundled in this repo under [`ai/`](ai/) that fronts local [Ollama](https://ollama.com) models, Google Gemini, and any OpenAI-compatible backend (OpenAI, OpenRouter, LM Studio, vLLM, ...).

Built and enabled automatically on any install path (NixOS, Arch + Nix, or pure manual `make install` — see [SETUP.md](SETUP.md)).

- Spotlight-style one-row prompt in the bar — Yura icon + input pill, response streams into the placeholder, navigable read-only after streaming, clicking the icon detaches into the corner panel
- Corner pop-up panel (left or right, configurable); sidebar of past conversations, cosmic gradient background, drifting particles, and a soft breathing indicator that follows the latest reply
- The bar row and the corner pop-up stay in sync — send a message in one and it shows up in the other instantly
- Multi-conversation history persisted on disk — pick up old chats from the sidebar, delete with a hover trash, "+ New chat" stays empty until you actually send something
- Per-conversation model binding — each chat stays on the provider it was started with; the panel dropdown locks to read-only mid-conversation, and a Settings entry pins the bar's model
- Markdown rendering for assistant replies, with monospace code blocks that have their own hover-reveal copy button
- Streaming responses with a stop button, a breathing indicator, and an IME-aware placeholder
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
- Calendar in a standalone night-sky window — month grid + events list, inline add / edit modal, today ring, event dots
- Countdown Timer (`Super + Shift + T`) with preset durations, free-form M:SS input, full keyboard control, glowing progress ring, configurable completion sound, and a live remaining-time pill in the bar
- Configurable bar date format (Qt date tokens, e.g. `ddd M/d`, `yyyy-MM-dd`)
- Settings can detach into a standalone floating window, kept in sync with the bar
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
- In-shell settings panel covering theme, blur, animations, notification + timer sounds, lock timer, date format, and Yura's bar model + panel side

---

## Usage

Once installed (see [SETUP.md](SETUP.md)), the bar starts automatically with the Hyprland session.

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
| `Super + Y` | Yura (corner pop-up) |
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
