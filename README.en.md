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

The desktop assistant. You reach it from the input row in the bar or the chat panel.

- Models: local models through Ollama, Claude, Gemini, any OpenAI-compatible API
- Desktop control: "set volume to 30" or "start a 5 minute timer" moves the matching panel
- External MCP servers are supported; writes are held for approval

Configuration is in [SETUP.en.md](SETUP.en.md#configuring-mugen-ai).

---

## Installation

The steps are in [SETUP.en.md](SETUP.en.md).

To try it without installing, use the demo VM. The user name, and the password for unlocking and sudo, are both `mugen`.

```sh
nix build "github:tmy7533018/mugen-shell#nixosConfigurations.vm.config.system.build.vm" && ./result/bin/run-mugen-vm-vm
```

---

## Credits

mugen-shell stands on [Hyprland](https://hypr.land/), [Quickshell](https://quickshell.outfoxxed.me/), and many other projects. The full list is in [SETUP.en.md → Credits](SETUP.en.md#credits).

---

## License

MIT License
