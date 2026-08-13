<p align="right"><b>English</b> | <a href="README.md">日本語</a></p>

<h1 align="center">
  <img src="shell/assets/branding/mugen-shell_logo.png" width="200" alt="mugen-shell logo" /><br/>
  mugen-shell
</h1>

<p align="center"><i>A 夢幻 shell, built on Quickshell + Hyprland.</i></p>

https://github.com/user-attachments/assets/375659b6-8b1d-4d08-8621-7451d6791e71

My dotfiles for a Hyprland + Quickshell desktop, packaged so they can be installed via Nix flake or `make install`.

---

## Features

- Panels for the everyday things — calendar, timer, music, clipboard, notifications, app launcher, and screenshots
- Wallpapers can be images or video, and they change through a smooth transition
- Several color palettes generated from the wallpaper; the one you pick is applied across the desktop
- The usual system controls: audio, backlight, WiFi, Bluetooth, IME, battery, and the system tray
- The lock screen is part of the shell — a grid of the clock, calendar, current track, and weather, with no external locker involved
- Yura, the desktop assistant, reachable by chat or by voice
- Smooth animation throughout, and it is easy to customize
- A Settings window for changing all sorts of things

---

## Yura

Yura is the desktop assistant. It can be used from an input row in the bar (`Super + Y`) and from a chat panel anchored to a screen corner (`Super + Shift + Y`), with the conversation history shared between them. The backend is **mugen-ai**, a Go server in [`ai/`](ai/) that talks to local models through [Ollama](https://ollama.com), to Anthropic Claude, to Google Gemini, or to any OpenAI-compatible API. Files can be attached to a message.

Yura also runs the desktop. "Set volume to 30" or "start a 5 minute timer" reaches the same panels you would click. It will not do anything dangerous. External [MCP](https://modelcontextprotocol.io) servers are supported as well, with their writes held for approval.

Voice input works from a button or from push-to-talk. Hold `Super + Z`, talk, and a voice model reads the reply back. The voice that ships is Japanese; install a model from [AivisHub](https://hub.aivis-project.com/) and pick it in Settings. [SETUP.en.md](SETUP.en.md#configuring-mugen-ai) has the details.

---

## Installation

Try it without installing anything — the demo VM autologins into Hyprland, with `mugen` / `mugen` as the credentials:

```sh
nix build .#nixosConfigurations.vm.config.system.build.vm && ./result/bin/run-mugen-vm-vm
```

Every configuration option is documented in [SETUP.en.md](SETUP.en.md).

---

## Credits

mugen-shell stands on [Hyprland](https://hypr.land/), [Quickshell](https://quickshell.outfoxxed.me/), and many other projects — the full list is in [SETUP.en.md → Credits](SETUP.en.md#credits).

---

## License

MIT License
