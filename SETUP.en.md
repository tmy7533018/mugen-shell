<p align="right"><b>English</b> | <a href="SETUP.md">日本語</a></p>

# mugen-shell: Setup Guide

## Install

**Hyprland 0.55 or newer** and **PipeWire** (`pipewire-pulse`) are required.

### Arch Linux

```bash
git clone https://github.com/tmy7533018/mugen-shell.git
cd mugen-shell
./install.sh
```

To run it without the menu:

```bash
./install.sh --yes
```

`./install.sh --help` lists the options.

When it finishes, log out and pick **mugen-shell** from your display manager's session list.

<details>
<summary><b>NixOS</b></summary>

```nix
# /etc/nixos/flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    mugen-shell.url = "github:tmy7533018/mugen-shell";
    mugen-shell.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { nixpkgs, home-manager, mugen-shell, ... }: {
    nixosConfigurations.mybox = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix  # the config nixos-generate-config already made
        mugen-shell.nixosModules.default
        home-manager.nixosModules.home-manager
        ({ ... }: {
          # System layer
          programs.mugen-shell.enable = true;

          # Required: home-manager won't see the mugen-shell overlay without it
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.YOUR_USER = {
            imports = [ mugen-shell.homeManagerModules.default ];
            programs.mugen-shell.enable = true;
            programs.mugen-shell.includeSystemDeps = false; # already on the system path
            programs.mugen-shell.quickshellExecutable = "/run/current-system/sw/bin/quickshell";
            home.stateVersion = "26.05";
          };
        })
      ];
    };
  };
}
```

Then run `nixos-rebuild switch --flake "/etc/nixos#mybox"`.

**Terminal styling (optional)**: add both lines below and put `source ~/.config/mugen-shell/mugen-shell.zshrc` in your `~/.zshrc`.

```nix
programs.mugen-shell.zsh.enable = true;                    # system layer
home-manager.users.YOUR_USER.programs.mugen-shell.zsh.enable = true;
```

**Japanese input**: install fcitx5 through this option. Installed directly, the IME is not registered for the login session and the input fields cannot use it.

```nix
programs.mugen-shell.fcitx5Addons = with pkgs; [ fcitx5-mozc ];
# or:  [ fcitx5-rime ]    for Chinese
# or:  [ fcitx5-hangul ]  for Korean
```

</details>

---

## Configuring mugen-ai

Configure it under **Settings → Yura**. To edit by hand, **Edit toml** on the same page opens `~/.config/mugen-ai/config.toml`. The template is `ai/config.toml.example`, or `/usr/share/mugen-ai/config.toml.example` on Arch.

First steps:

1. **Get a model.** Pull one with Ollama, such as `ollama pull qwen3:4b`, or add an API key below.
2. **Allow apps under Allowed apps.** Yura launches nothing until you do.
3. **If `mugen-ai.service` is not running**, start it with the command Yura's chat panel shows.

### Provider API keys

Copy `ai/.env.example` (Arch: `/usr/share/mugen-ai/.env.example`) to `~/.config/mugen-ai/.env` and fill it in, or append directly:

```sh
cat >> ~/.config/mugen-ai/.env <<'EOF'
ANTHROPIC_API_KEY=sk-ant-...
GEMINI_API_KEY=...
OPENAI_API_KEY=...
EOF
chmod 600 ~/.config/mugen-ai/.env
systemctl --user restart mugen-ai.service
```

### Choosing a model

Hosted Claude and Gemini drive the tools most reliably. On Ollama use `qwen3:14b`. If you use `qwen3:4b`, turn **Thinking** on.

<details>
<summary><b>MCP servers</b>: pulling in external tools</summary>

One `[mcp.servers.<name>]` block per server:

```toml
[mcp.servers.memory]
command = "npx"
args = ["-y", "@modelcontextprotocol/server-memory"]
# env = { MEMORY_FILE_PATH = "/home/you/.local/state/mugen-ai/memory.json" }
# disabled = false   # keep the entry but skip spawning it
# trusted = false    # true = skip the approval prompt for this server's tools
```

- `command` has to be on the service's `PATH`. Install Node.js for `npx` servers or [uv](https://docs.astral.sh/uv/) for `uvx` ones yourself. On Nix, add them to `home.packages`
- For a remote server, use `url = "https://example.com/mcp"` instead of `command`
- Keep server names short, lowercase and without underscores, because tools are named `<name>__<tool>`. Restart `mugen-ai.service` after changes
- `trusted = true` skips the approval prompt for a server you trust
- Keep tokens in `~/.config/mugen-ai/.env` and reference them as `env = { GITHUB_TOKEN = "${GITHUB_TOKEN}" }`

</details>

---

## Keybindings

Full list: `Super + /`. Definitions: `system/hypr/configs/keybinds.lua`.

| Key | Action |
|---|---|
| `Super + R` | App launcher |
| `Super + Y` / `Super + Shift + Y` | Yura's bar input / chat panel |
| `Super + ,` | Settings |
| `Super + Enter` | Terminal |
| `Super + Backspace` | Close the active window |
| `Super + 1-9` / `Super + 0` | Switch to workspace 1-10 |
| `Super + hjkl` | Move focus, vim-style |
| `Print` / `Super + F12` | Region screenshot, copied to the clipboard |

---

## Runtime data

Everything lives outside the repo, under XDG dirs:

| Where | What |
|---|---|
| `$XDG_CONFIG_HOME/mugen-shell/settings.json` | Persisted user settings |
| `$XDG_STATE_HOME/mugen-shell/{theme-mode,idle-inhibitor.json,keybinds.json,launcher.json,notifications.json,timer.json,notified.json}` | Toggleable state and exported listings |
| `$XDG_CACHE_HOME/mugen-shell/{colors.json,weather.json,apps_v4.json,apps_v4.sha256,wallp/,wallpaper-thumbs/,clipboard-thumbs/,art/}` | Regenerable cache |
| `$XDG_DATA_HOME/mugen-shell/{wallpapers/,sounds/,timer-sounds/}` | User-supplied media |
| `$XDG_DATA_HOME/mugen-shell/calendar.db` | Calendar SQLite database |
| `$XDG_STATE_HOME/mugen-ai/history.db` | Yura conversation history (SQLite) |
| `$XDG_PICTURES_DIR/mugen-screenshots/` | Captured screenshots |

Audio files dropped into `sounds/` and `timer-sounds/` above show up in the Settings dropdowns for notification and timer sounds.

---

## Credits

- [Hyprland](https://hypr.land/): Wayland compositor
- [Quickshell](https://quickshell.outfoxxed.me/): Shell framework
- [Matugen](https://github.com/InioX/matugen): Wallpaper-based color generation
- [Cava](https://github.com/karlstav/cava): Audio visualizer
- [Kitty](https://sw.kovidgoyal.net/kitty/): Terminal emulator
- [playerctl](https://github.com/altdesktop/playerctl): Media player control
- [grim](https://sr.ht/~emersion/grim/) / [slurp](https://github.com/emersion/slurp): Screenshot tools
- [cliphist](https://github.com/sentriz/cliphist): Clipboard history

- [LRO WAC moon mosaic](https://commons.wikimedia.org/wiki/File:Moon_nearside_LRO.jpg): the moon on the lock screen. NASA/GSFC/Arizona State University, public domain (bundled brightness-adjusted and scaled down to 320px)