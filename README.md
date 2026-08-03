<p align="right"><b>English</b> | <a href="README.ja.md">日本語</a></p>

<h1 align="center">
  <img src="shell/assets/branding/mugen-shell_logo.png" width="200" alt="mugen-shell logo" /><br/>
  mugen-shell
</h1>

<p align="center"><i>A 夢幻 desktop, built on Quickshell + Hyprland.</i></p>

https://github.com/user-attachments/assets/375659b6-8b1d-4d08-8621-7451d6791e71

Personal dotfiles for a Hyprland + Quickshell desktop, packaged so they can be installed via Nix flake or `make install`. Colors follow the wallpaper through Matugen, and a built-in assistant can drive the shell by chat or by voice.

Try it without installing anything — the demo VM autologins into Hyprland, with `mugen` / `mugen` as the credentials:

```sh
cd nixos && nix build .#nixosConfigurations.vm.config.system.build.vm && ./result/bin/run-mugen-vm-vm
```

Install paths, dependencies, keybindings, and configuration all live in [SETUP.md](SETUP.md); `Super + /` also brings up the shortcut reference in a running shell.

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

Yura is the desktop assistant. It appears as an input row in the bar (`Super + Y`) and as a chat panel anchored to a screen corner (`Super + Shift + Y`), both sharing one conversation history. The backend is **mugen-ai**, a Go server in [`ai/`](ai/) that talks to local models through [Ollama](https://ollama.com), to Anthropic Claude, to Google Gemini, or to any OpenAI-compatible API. Files can ride along with a message: images go to models that can see, and anything that decodes as text is folded into the prompt, so a model without vision still reads what you attached.

Yura also runs the desktop. "Set volume to 30" or "set a 25 minute timer" reaches the same panels you would click. Tool calls can be switched off per category, launching apps goes through an allowlist, and power actions were never handed over. External [MCP](https://modelcontextprotocol.io) servers join the same set, with their writes held for approval.

Voice input is optional. Hold `Super + Z`, talk, and the reply comes back spoken; the voice that ships is Japanese and reads whatever language it is given, until you hand a language its own voice in Settings. Everything is configured under **Settings → AI / Yura**, and [SETUP.md](SETUP.md#configuring-mugen-ai) covers the rest.

---

## Features

- A Material You palette regenerated from whatever wallpaper is up, still or video
- Panels for the everyday things — calendar, timer, music, clipboard, notifications, app launcher, screenshots, and more
- The usual system controls: audio, backlight, WiFi, Bluetooth, IME, battery, and the system tray
- A standalone Settings window, so none of it needs a config file to change

---

## Credits

mugen-shell stands on [Hyprland](https://hyprland.org/), [Quickshell](https://quickshell.outfoxxed.me/), and many other projects — the full list is in [SETUP.md → Credits](SETUP.md#credits).

---

## License

MIT License
