<p align="right"><b>English</b> | <a href="README.ja.md">日本語</a></p>

<h1 align="center">
  <img src="shell/assets/branding/mugen-shell_logo.png" width="200" alt="mugen-shell logo" /><br/>
  mugen-shell
</h1>

<p align="center"><i>A 夢幻 desktop, built on Quickshell + Hyprland.</i></p>

https://github.com/user-attachments/assets/a5a8922e-459f-483f-9c7d-a3e103529a60

Personal dotfiles for a Hyprland + Quickshell desktop, packaged so they can be installed via Nix flake or `make install`.

For directory layout, install paths, dependencies, and keybindings see [SETUP.md](SETUP.md).

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

https://github.com/user-attachments/assets/ec637cc4-be2f-40a7-ba4e-0047ab0d6399

<sub><i>A casual hello in the bar; the corner pop-up shuffles the wallpaper, switches to light mode, and opens Chrome through tool calls.</i></sub>

Yura is the desktop chat assistant. It runs in two places: a single input row in the bar (`Super + Y`) and a chat panel anchored to a screen corner (`Super + Shift + Y`).

The backend is **mugen-ai**, a Go server in [`ai/`](ai/). It supports:

- Local models via [Ollama](https://ollama.com)
- Anthropic Claude
- Google Gemini
- OpenAI-compatible APIs (OpenAI, OpenRouter, LM Studio, vLLM, etc.)

Set up alongside mugen-shell via NixOS, Arch + Nix, or `make install`; see [SETUP.md](SETUP.md). All Yura configuration (providers, personality, tool toggles, allowed apps) lives under **Settings → AI / Yura**.

### Features

- Bar row: input pill with Yura icon. Responses stream into the placeholder. Clicking the icon opens the corner panel on the same conversation.
- Corner panel (left or right): sidebar of past conversations with an indicator that pulses while a reply streams.
- Bar row and corner panel stay in sync. A message sent in one appears in the other.
- Multi-conversation history persisted on disk. Pick up old chats from the sidebar; delete via the hover trash icon.
- Per-conversation model binding. Each conversation keeps the provider it started with, and the panel dropdown is read-only mid-conversation.
- Markdown rendering for assistant replies. Code blocks have a copy button revealed on hover.
- Streaming responses with a stop button and an IME-aware input placeholder.
- Personality (name, tone, language, system prompt) is editable in the Settings GUI. Save & Apply writes the config and restarts the backend.
- Per-conversation Thinking toggle. Routes through each provider's reasoning channel (qwen3 think, Claude extended thinking, Gemini thinkingConfig, OpenAI reasoning_effort), with a silent fallback for unsupported models.
- Strict-by-default app launch allowlist. Until an app is enabled in the picker, Yura cannot launch anything. Shell metacharacters (`; | & $` etc.) are always rejected.
- Per-category tool toggles (audio, music, brightness, theme, wallpaper, notifications, timer, calendar, panels, app launcher).
- External [MCP](https://modelcontextprotocol.io) server support. Configured servers have their tools merged into the same gated set, with live connection status shown in Settings.

### Shell control by chat

Tool calls from Yura are dispatched through `qs ipc call`, so the existing shell managers remain the single source of truth. Reversible tools run immediately. Built-in destructive tools (clearing notifications, deleting calendar events) ask for confirmation in chat. External MCP tools that may write are held behind an Approve / Deny prompt in the UI.

| Domain | What Yura can do |
|---|---|
| Audio output | set / read volume, toggle mute |
| Audio input | set / read mic volume, toggle mic mute |
| Display | set / read brightness |
| Theme | switch dark / light, toggle, read |
| Wallpaper | switch, list available, read current |
| Music (MPRIS) | play / pause, next, previous |
| Notifications | set / toggle DnD, clear history, read unread count |
| Apps | launch any app enabled in Settings → AI / Yura → Allowed apps (off-$PATH binaries resolved via `.desktop` Exec) |
| Timer | start / pause / resume / cancel, read state |
| Calendar | add / delete events, list today or a date range |
| Panels | open named panel, close any panel |

Each row above can be disabled as a category in Settings → AI / Yura → Tool categories. App launches are also gated by the Allowed apps picker, so "launch firefox" only works once firefox is enabled there.

External MCP servers feed into the same gated set. Add `[mcp.servers.*]` blocks to the config (memory, filesystem, GitHub, etc.) and the tools merge with the same per-category gate, audit log, result sanitisation, and approval prompt before any write. See [SETUP.md](SETUP.md#mcp-servers).

Power actions (lock, suspend, logout, reboot, shutdown) are not exposed to Yura. Use the Power Menu directly for those.

Example prompts that work today: "set volume to 30", "lower the brightness", "switch to light mode", "shuffle the wallpaper", "next track", "DnD on", "open settings", "set a 25 minute timer", "add a calendar event tomorrow at 3pm", "launch firefox".

Provider API keys, the config file layout, and the HTTP API are documented in [SETUP.md → Configuring mugen-ai](SETUP.md#configuring-mugen-ai).

---

## Preview

[TikTok demo — @ripnk6498](https://www.tiktok.com/@ripnk6498/video/7579183858038492433?is_from_webapp=1&sender_device=pc)

---

## Features

- Material You color scheme generated from the current wallpaper via Matugen
- Video and image wallpaper switching (mpvpaper + awww) with a picker UI
- Cava audio visualizer
- Standalone Calendar window with month grid, events list, and inline add / edit
- Countdown timer with preset durations, free-form M:SS input, a progress ring, and a remaining-time pill in the bar
- Music player integration (playerctl / MPRIS) with YouTube thumbnail fallback and a seekable progress slider
- Clipboard history and notification center
- Speaker and microphone control sharing one volume panel
- Laptop backlight slider with hardware-key integration (hidden on systems without a backlight)
- WiFi, Bluetooth, and IME management
- Battery indicator (optional water-level fill inside the power menu icon) and a collapsible system tray
- App launcher, idle inhibitor toggle, screenshot capture with clipboard copy, screenshot gallery, power menu
- Standalone Settings window for theme, blur, animations, notification and timer sounds, lock timer, date format, plus the Yura tab (personality, providers, bar model, thinking, tool categories, allowed apps, panel side)

---

## Usage

After installation (see [SETUP.md](SETUP.md)), the bar starts automatically with the Hyprland session. Press `Super + /` for the keyboard shortcut reference. Right-click the power menu icon to open Settings. Click the chevron next to the notification icon to expand the system tray. The full keybind list is in [SETUP.md → Keybindings](SETUP.md#keybindings).

---

## License

MIT License
