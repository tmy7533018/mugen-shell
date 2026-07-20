<p align="right"><b>English</b> | <a href="README.ja.md">日本語</a></p>

<h1 align="center">
  <img src="shell/assets/branding/mugen-shell_logo.png" width="200" alt="mugen-shell logo" /><br/>
  mugen-shell
</h1>

<p align="center"><i>A 夢幻 desktop, built on Quickshell + Hyprland.</i></p>

https://github.com/user-attachments/assets/beaaf135-5cdf-46d9-975d-91e3e6f04068

Personal dotfiles for a Hyprland + Quickshell desktop, packaged so they can be installed via Nix flake or `make install`.

To try it without installing anything, boot the demo VM: `cd nixos && nix build .#nixosConfigurations.vm.config.system.build.vm && ./result/bin/run-mugen-vm-vm` (autologins into Hyprland; credentials are `mugen` / `mugen`).

For directory layout, install paths, dependencies, and keybindings see [SETUP.md](SETUP.md).

---

## Environment

| | |
|---|---|
| OS | NixOS (also runs on Arch-based distros) |
| GPU | AMD Radeon RX 9070 XT |
| WM | Hyprland (Lua config — the classic `.conf` twins are kept as a fallback) |
| Shell | Zsh + Starship |
| Terminal | Kitty |
| Desktop Shell | Quickshell |
| Wallpaper | awww / mpvpaper |
| Colors | Matugen (Material You) |

---

## Yura

https://github.com/user-attachments/assets/61328371-aa8e-4f96-aae8-2817fadf3ed4

<sub><i>A casual hello in the bar; the corner pop-up shuffles the wallpaper, switches to light mode, and opens a browser through tool calls.</i></sub>

Yura is the desktop chat assistant. It runs in two places: a single input row in the bar (`Super + Y`) and a chat panel anchored to a screen corner (`Super + Shift + Y`).

The backend is **mugen-ai**, a Go server in [`ai/`](ai/). It supports:

- Local models via [Ollama](https://ollama.com)
- Anthropic Claude
- Google Gemini
- OpenAI-compatible APIs (OpenAI, OpenRouter, LM Studio, vLLM, etc.)

Set up alongside mugen-shell via NixOS, Arch + Nix, or `make install`; see [SETUP.md](SETUP.md). All Yura configuration (providers, personality, tool toggles, allowed apps) lives under **Settings → AI / Yura**.

### Features

- Bar row and corner panel share the same conversations and stay in sync; the sidebar keeps multi-conversation history on disk.
- Per-conversation model binding, plus a per-conversation Thinking toggle routed through each provider's reasoning channel.
- Markdown replies with code-block copy, streaming with a stop button, IME-aware input.
- Personality, providers, and every other Yura knob editable from the Settings GUI — Save & Apply hot-restarts the backend.
- Voice input (optional): say **"Hey Yura"**, talk, and the reply is spoken back via VOICEVOX / AivisSpeech (or Piper for non-Japanese voices). The mic stays open for follow-ups, and both UIs get a push-to-talk button. Setup in [SETUP.md → Voice input](SETUP.md#voice-input-optional).
- Strict-by-default app allowlist, per-category tool toggles, and external [MCP](https://modelcontextprotocol.io) servers merged into the same gated set.

### Shell control by chat

Yura drives the desktop through gated tool calls: volume, mic, brightness, theme, wallpaper, music, notifications, timers, calendar, panels, and an allowlisted app launcher. Reversible actions run immediately, destructive ones confirm in chat, and external MCP writes sit behind an Approve / Deny prompt. Power actions are deliberately not exposed. Try "set volume to 30", "shuffle the wallpaper", or "set a 25 minute timer" — the full domain table, gating details, and config are in [SETUP.md → Shell control by chat](SETUP.md#shell-control-by-chat).

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
- Standalone Settings window: theme, blur, animations, sounds, lock timer, date format, plus the full Yura and Voice input sections

---

## Usage

After installation (see [SETUP.md](SETUP.md)), the bar starts automatically with the Hyprland session. Press `Super + /` for the shortcut reference. Right-clicking the power menu icon opens Settings, and the chevron next to the notification icon expands the system tray. The full keybind list is in [SETUP.md → Keybindings](SETUP.md#keybindings).

---

## Credits

mugen-shell stands on [Hyprland](https://hyprland.org/), [Quickshell](https://quickshell.outfoxxed.me/), and many other projects — the full list is in [SETUP.md → Credits](SETUP.md#credits).

The bundled "Hey Yura" wake word model (`voice/models/hey_yura.onnx`) is a custom [openWakeWord](https://github.com/dscripka/openWakeWord) model trained on Japanese speech synthesized with [VOICEVOX](https://voicevox.hiroshiba.jp/).

---

## License

MIT License
