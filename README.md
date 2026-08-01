<p align="right"><b>English</b> | <a href="README.ja.md">日本語</a></p>

<h1 align="center">
  <img src="shell/assets/branding/mugen-shell_logo.png" width="200" alt="mugen-shell logo" /><br/>
  mugen-shell
</h1>

<p align="center"><i>A 夢幻 desktop, built on Quickshell + Hyprland.</i></p>

https://github.com/user-attachments/assets/beaaf135-5cdf-46d9-975d-91e3e6f04068

Personal dotfiles for a Hyprland + Quickshell desktop, packaged so they can be installed via Nix flake or `make install`. Colors follow the wallpaper through Matugen, and a built-in assistant can drive the shell by chat or by voice.

Try it without installing anything — the demo VM autologins into Hyprland, with `mugen` / `mugen` as the credentials:

```sh
cd nixos && nix build .#nixosConfigurations.vm.config.system.build.vm && ./result/bin/run-mugen-vm-vm
```

Install paths, dependencies, keybindings, and configuration all live in [SETUP.md](SETUP.md); `Super + /` also brings up the shortcut reference in a running shell. There is a longer walkthrough in this [TikTok demo](https://www.tiktok.com/@ripnk6498/video/7579183858038492433).

---

## Environment

| | |
|---|---|
| OS | NixOS |
| GPU | AMD Radeon RX 9070 XT |
| WM | Hyprland |
| Shell | Zsh + Starship |
| Terminal | Kitty |
| Desktop Shell | Quickshell |
| Wallpaper | awww / mpvpaper |
| Colors | Matugen |

---

## Yura

https://github.com/user-attachments/assets/61328371-aa8e-4f96-aae8-2817fadf3ed4

<sub><i>A casual hello in the bar; the corner pop-up shuffles the wallpaper, switches to light mode, and opens a browser through tool calls.</i></sub>

Yura is the desktop assistant. It appears as an input row in the bar (`Super + Y`) and as a chat panel anchored to a screen corner (`Super + Shift + Y`), both sharing one conversation history. The backend is **mugen-ai**, a Go server in [`ai/`](ai/) that talks to local models through [Ollama](https://ollama.com), to Anthropic Claude, to Google Gemini, or to any OpenAI-compatible API.

Yura also runs the desktop. "Set volume to 30" or "set a 25 minute timer" reaches the same panels you would click. Tool calls can be switched off per category, launching apps goes through an allowlist, and power actions were never handed over. External [MCP](https://modelcontextprotocol.io) servers join the same set, with their writes held for approval.

Voice input is optional. Say **"Hey Yura"**, talk, and the reply comes back spoken; the voice that ships is Japanese, and other languages route to a Piper voice instead. Everything is configured under **Settings → AI / Yura**, and [SETUP.md](SETUP.md#configuring-mugen-ai) covers the rest.

---

## Features

- A Material You palette regenerated from whatever wallpaper is up, still or video
- Panels for the everyday things — calendar, timer, music, clipboard, notifications, app launcher, screenshots, and more
- The usual system controls: audio, backlight, WiFi, Bluetooth, IME, battery, tray
- A standalone Settings window, so none of it needs a config file to change

---

## Credits

mugen-shell stands on [Hyprland](https://hyprland.org/), [Quickshell](https://quickshell.outfoxxed.me/), and many other projects — the full list is in [SETUP.md → Credits](SETUP.md#credits).

The "Hey Yura" wake word model is a custom [openWakeWord](https://github.com/dscripka/openWakeWord) model trained on speech synthesized with [VOICEVOX](https://voicevox.hiroshiba.jp/).

---

## License

MIT License
