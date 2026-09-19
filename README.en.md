<p align="right"><b>English</b> | <a href="README.md">日本語</a></p>

<h1 align="center">
  <img src="shell/assets/branding/mugen-shell_logo.png" width="200" alt="mugen-shell logo" /><br/>
  mugen-shell
</h1>

<p align="center"><i>A 夢幻 shell, built on Quickshell + Hyprland.</i></p>

https://github.com/user-attachments/assets/cd9e2538-a30f-4c8c-a143-9f8c2c7b3a8f

My dotfiles for a Hyprland + Quickshell desktop, packaged so they can be installed from Arch packages or a Nix flake.

---

## Features

- Panels: calendar, timer, weather, music, clipboard, notifications, app launcher, screenshots
- System controls: audio, backlight, WiFi, Bluetooth, IME, battery, system tray
- Image and video wallpapers
- Colors generated from the wallpaper: applied to GTK apps and Hyprland too
- Light / dark switch
- Lock screen
- Yura, the desktop assistant
- Smooth animation
- Customization: bar shape and color, transparency, blur, animation speed, and more

---

## Yura

Yura is the desktop assistant. It can be used from an input row in the bar (`Super + Y`) and from a chat panel anchored to a screen corner (`Super + Shift + Y`), with the conversation history shared between them. The backend is **mugen-ai**, a Go server in [`ai/`](ai/) that talks to local models through [Ollama](https://ollama.com), to Anthropic Claude, to Google Gemini, or to any OpenAI-compatible API. Files can be attached to a message from the panel.

Yura also runs the desktop. "Set volume to 30" or "start a 5 minute timer" reaches the same panels you would click. It will not do anything dangerous. External [MCP](https://modelcontextprotocol.io) servers are supported as well, with their writes held for approval.

Press the speaker icon on a reply and a voice model reads it back (optional). The default voice is Japanese; install a model from [AivisHub](https://hub.aivis-project.com/) and pick it in Settings. [SETUP.en.md](SETUP.en.md#configuring-mugen-ai) has the details.

---

## Installation

Try it without installing anything (Yura needs a model of your own before it will answer). The demo VM autologins into Hyprland, with `mugen` / `mugen` as the credentials:

```sh
nix build "github:tmy7533018/mugen-shell#nixosConfigurations.vm.config.system.build.vm" && ./result/bin/run-mugen-vm-vm
```

Install steps and configuration are documented in [SETUP.en.md](SETUP.en.md). On Arch, `./install.sh` does the whole thing.

---

## Credits

mugen-shell stands on [Hyprland](https://hypr.land/), [Quickshell](https://quickshell.outfoxxed.me/), and many other projects. The full list is in [SETUP.en.md → Credits](SETUP.en.md#credits).

---

## License

MIT License
