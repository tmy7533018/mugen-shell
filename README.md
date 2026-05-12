<h1 align="center">
  <img src="shell/assets/branding/mugen-shell_logo.png" width="200" alt="mugen-shell logo" /><br/>
  mugen-shell
</h1>

<p align="center"><i>A 夢幻 desktop, built on Quickshell + Hyprland.</i></p>

https://github.com/user-attachments/assets/2a8fe2e5-ced6-4de1-acda-d7e0493882a6

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

https://github.com/user-attachments/assets/7220fe2f-6c55-4620-ae1a-79c6ad4caec9

<sub><i>A casual hello in the bar; over in the corner pop-up, Yura swaps the wallpaper and flips into light mode through tool calls.</i></sub>

Yura is the desktop chat persona — a Spotlight-style row in the bar (`Super + Y`) and a corner pop-up chat panel that slides in from off-screen (`Super + Shift + Y`). It's powered by **mugen-ai**, a Go server bundled in this repo under [`ai/`](ai/) that fronts:

- **Local** — any [Ollama](https://ollama.com) model on your machine (no network)
- **Cloud** — Anthropic Claude, Google Gemini, or any OpenAI-compatible backend (OpenAI, OpenRouter, LM Studio, vLLM, …)

Built and enabled automatically on any install path (NixOS, Arch + Nix, or pure manual `make install` — see [SETUP.md](SETUP.md)). Everything Yura-related — providers, personality, tool toggles, allowed apps — lives under **Settings → AI / Yura**, no TOML editing required.

- Spotlight-style one-row prompt in the bar — Yura icon + input pill, response streams into the placeholder, navigable read-only after streaming, clicking the icon detaches into the corner panel
- Corner pop-up panel (left or right, configurable); sidebar of past conversations, cosmic gradient background, drifting particles, and a soft breathing indicator that follows the latest reply
- The bar row and the corner pop-up stay in sync — send a message in one and it shows up in the other instantly
- Multi-conversation history persisted on disk — pick up old chats from the sidebar, delete with a hover trash, "+ New chat" stays empty until you actually send something
- Per-conversation model binding — each chat stays on the provider it was started with; the panel dropdown locks to read-only mid-conversation, and the Settings → AI / Yura tab pins the bar's default model
- Markdown rendering for assistant replies, with monospace code blocks that have their own hover-reveal copy button
- Streaming responses with a stop button, a breathing indicator, and an IME-aware placeholder
- Configurable personality (name / tone / language / system prompt) edited in-app — Save & Apply writes the config and hot-restarts the backend, no terminal trip
- Per-conversation Thinking toggle that routes to each provider's reasoning channel (qwen3 think / Claude extended thinking / Gemini thinkingConfig / OpenAI reasoning_effort), with a silent fallback for models that don't support it
- **Strict-by-default allowed-apps gate**: the picker shows your installed desktop apps, and until you enable one Yura can't open anything. Shell metacharacters (`; | & $` etc.) are always rejected so an allowed app can't be turned into a shell-injection.
- **Per-category tool toggles** (audio, music, brightness, theme, wallpaper, notifications, timer, calendar, panels, app launcher) — disabled categories vanish from Yura's tool list, and Yura proactively tells you when you ask for something turned off
- Natural-language shell control via function-calling tools — see *Shell control by chat* below

#### Shell control by chat

Yura speaks function calls back to mugen-shell. Tools route through
`qs ipc call` so the existing managers stay the source of truth.
Reversible actions fire immediately; destructive ones (clearing
notification history, deleting calendar events, etc.) are confirmed in
plain language in chat first — no modal popups.

| Domain | What Yura can do |
|---|---|
| Audio output | set / read volume, toggle mute |
| Audio input | set / read mic volume, toggle mic mute |
| Display | set / read brightness |
| Theme | switch dark / light, toggle, read |
| Wallpaper | switch, list available, read current |
| Music (MPRIS) | play / pause, next, previous |
| Notifications | set / toggle DnD, clear history, read unread count |
| Apps | launch any app you've enabled in Settings → AI / Yura → Allowed apps (off-$PATH binaries resolved via `.desktop` Exec) |
| Timer | start / pause / resume / cancel, read state |
| Calendar | add / delete events, list today or a date range |
| Panels | open named panel, close any panel |

Each row above can be turned off as a whole category in Settings → AI / Yura → Tool categories, and app launches are gated by the Allowed apps picker (the example "launch firefox" works only once you've enabled firefox there). Power actions (lock / suspend / logout / reboot / shutdown) intentionally stay out of Yura's reach — drive those from the Power Menu directly.

Examples that land today: "set volume to 30", "lower the brightness",
"switch to light mode", "shuffle the wallpaper", "next track", "DnD on",
"open settings", "set a 25 minute timer", "add a calendar event tomorrow
at 3pm", "launch firefox".

Configuration, the HTTP API, and the Gemini API key step live in [SETUP.md → Configuring mugen-ai](SETUP.md#configuring-mugen-ai).

---

## Preview

[TikTok demo — @ripnk6498](https://www.tiktok.com/@ripnk6498/video/7579183858038492433?is_from_webapp=1&sender_device=pc)

---

## Features

- Wallpaper-driven Material You color scheme via Matugen
- Video and image wallpaper switching (mpvpaper + awww) with a wallpaper picker UI
- Cava audio visualizer
- Calendar in a standalone night-sky window — month grid, events list, inline add / edit, today ring
- Countdown timer with preset durations, free-form M:SS input, glowing progress ring, and a live remaining-time pill in the bar
- Music player integration (playerctl / MPRIS) with YouTube thumbnail fallback and a seekable glowing progress slider
- Clipboard history and notification center
- Speaker / microphone control sharing the volume panel with a swap toggle
- Laptop backlight slider with hardware-key integration (auto-hidden on desktops without a backlight)
- WiFi / Bluetooth / IME management
- Battery indicator (water-level fill inside the power menu icon, opt-in) and a collapsible system tray
- App launcher, idle inhibitor toggle, screenshot capture with clipboard copy, screenshot gallery, power menu
- Standalone settings window — theme, blur, animations, notification + timer sounds, lock timer, date format, and a Yura tab covering personality (name / tone / language / system prompt), providers, bar model, thinking toggle, tool categories, allowed apps, and panel side

---

## Usage

Once installed (see [SETUP.md](SETUP.md)), the bar starts automatically with the Hyprland session. Press `Super + /` for the keyboard shortcut reference, right-click the power menu icon to jump straight into Settings, or click the chevron next to the notification icon to expand the system tray. The full keybind list lives in [SETUP.md → Keybindings](SETUP.md#keybindings).

---

## License

MIT License
