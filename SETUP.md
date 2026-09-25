<p align="right"><a href="SETUP.en.md">English</a> | <b>日本語</b></p>

# mugen-shell: セットアップガイド

## インストール

**Hyprland 0.55 以上**と **PipeWire** (`pipewire-pulse`) が前提です。

### Arch Linux

```bash
git clone https://github.com/tmy7533018/mugen-shell.git
cd mugen-shell
./install.sh
```

非対話で走らせる場合:

```bash
./install.sh --yes
```

オプションの一覧は `./install.sh --help` で出ます。

終わったらログアウトして、ディスプレイマネージャのセッション一覧から **mugen-shell** を選んでください。

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
        ./configuration.nix  # nixos-generate-config が作った既存の設定
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

`nixos-rebuild switch --flake "/etc/nixos#mybox"` を実行してください。

**ターミナルの設定もそろえる (オプション)**: 次の 2 行を足し、`~/.zshrc` に `source ~/.config/mugen-shell/mugen-shell.zshrc` を書きます。

```nix
programs.mugen-shell.zsh.enable = true;                    # システム層
home-manager.users.YOUR_USER.programs.mugen-shell.zsh.enable = true;
```

**日本語入力**: fcitx5 はこのオプションで入れます。直接インストールすると IME がログインセッションに登録されず、入力欄で使えません。

```nix
programs.mugen-shell.fcitx5Addons = with pkgs; [ fcitx5-mozc ];
# または: [ fcitx5-rime ]    中国語
# または: [ fcitx5-hangul ]  韓国語
```

</details>

Hyprland の個人設定は `~/.config/hypr/configs/user-overrides.lua` (キーバインドは `keybind-overrides.lua`) に書きます。`~/.config/hypr` (`hypridle.conf` を除く) と `~/.config/matugen` にある同梱のファイルは編集しても元に戻ります。mugen-shell が最初に置き換えた自分のファイルは `*.pre-mugen-shell` として残ります。

`~/.config/gtk-3.0/gtk.css` や `~/.config/gtk-4.0/gtk.css` を元から持っていた場合は、先頭に `@import url("colors.css");` を足してください。足さないと GTK アプリが壁紙の配色に追従しません。

---

## mugen-ai の設定

設定は **Settings → Yura** から。手で編集する場合は同じ画面の **Edit toml** で `~/.config/mugen-ai/config.toml` を開きます。テンプレートは `ai/config.toml.example` で、Arch では `/usr/share/mugen-ai/config.toml.example` にあります。

最初にやること:

1. **モデルを用意する。** `ollama pull qwen3:4b` のように Ollama でモデルを pull するか、下の API キーを置きます。
2. **Allowed apps でアプリを許可する。** 許可するまで Yura はアプリを起動しません。
3. **`mugen-ai.service` が止まっていたら**、Yura のチャットパネルに出るコマンドで起動します。

### プロバイダ API キー

`ai/.env.example` (Arch では `/usr/share/mugen-ai/.env.example`) を `~/.config/mugen-ai/.env` にコピーして埋めるか、直接追記します:

```sh
cat >> ~/.config/mugen-ai/.env <<'EOF'
ANTHROPIC_API_KEY=sk-ant-...
GEMINI_API_KEY=...
OPENAI_API_KEY=...
EOF
chmod 600 ~/.config/mugen-ai/.env
systemctl --user restart mugen-ai.service
```

### モデル選び

ツール実行が安定するのは API 経由の Claude / Gemini です。Ollama なら `qwen3:14b`。`qwen3:4b` を使う場合は **Thinking** を ON にします。

<details>
<summary><b>MCP サーバ</b>: 外部ツールを取り込む</summary>

サーバごとに `[mcp.servers.<name>]` を 1 つ書きます:

```toml
[mcp.servers.memory]
command = "npx"
args = ["-y", "@modelcontextprotocol/server-memory"]
# env = { MEMORY_FILE_PATH = "/home/you/.local/state/mugen-ai/memory.json" }
# disabled = false   # エントリは残したまま、起動だけスキップ
# trusted = false    # true にすると、このサーバのツールでは承認プロンプトを省略
```

- `command` はサービスの `PATH` から見える必要があります。`npx` 系なら Node.js、`uvx` 系なら [uv](https://docs.astral.sh/uv/) を別途入れてください。Nix なら `home.packages` に足します
- リモートサーバは `command` の代わりに `url = "https://example.com/mcp"`
- サーバ名は英小文字で始め、英小文字・数字・`-` だけにします。ツール名が `<name>__<tool>` になるためで、数字で始まる名前や `.`・`__` を含む名前のサーバは起動時にスキップされ、設定画面にエラーが出ます。変更したら `mugen-ai.service` を再起動
- 信用するサーバは `trusted = true` で承認プロンプトを省略できます
- トークンは `~/.config/mugen-ai/.env` に置き、`env = { GITHUB_TOKEN = "${GITHUB_TOKEN}" }` のように参照します

</details>

---

## キーバインド

一覧は `Super + /`。変更は `~/.config/hypr/configs/keybind-overrides.lua` に書きます (書き方は一覧の下に出ます)。

| キー | 動作 |
|---|---|
| `Super + R` | アプリランチャー |
| `Super + Y` / `Super + Shift + Y` | Yura のバーの入力欄 / チャットパネル |
| `Super + ,` | Settings |
| `Super + Enter` | ターミナル |
| `Super + Backspace` | アクティブなウィンドウを閉じる |
| `Super + 1-9` / `Super + 0` | ワークスペース 1-10 へ切替 |
| `Super + hjkl` | フォーカス移動 (vim 風) |
| `Print` / `Super + F12` | 範囲スクリーンショット、クリップボードへコピー |

---

## ランタイムデータの置き場所

設定・状態・キャッシュ・ユーザメディアは、すべてリポジトリの外の XDG ディレクトリに置かれます。

| 場所 | 中身 |
|---|---|
| `$XDG_CONFIG_HOME/mugen-shell/settings.json` | 保存されたユーザ設定 |
| `$XDG_STATE_HOME/mugen-shell/{theme-mode,idle-inhibitor.json,keybinds.json,launcher.json,notifications.json,timer.json,notified.json}` | トグル状態と、書き出された一覧 |
| `$XDG_CACHE_HOME/mugen-shell/{colors.json,weather.json,apps_v4.json,apps_v4.sha256,wallp/,wallpaper-thumbs/,clipboard-thumbs/,art/}` | 再生成できるキャッシュ |
| `$XDG_DATA_HOME/mugen-shell/{wallpapers/,sounds/,timer-sounds/}` | ユーザが置くメディア |
| `$XDG_DATA_HOME/mugen-shell/calendar.db` | カレンダーの SQLite DB |
| `$XDG_STATE_HOME/mugen-ai/history.db` | Yura の会話履歴 (SQLite) |
| `$XDG_PICTURES_DIR/mugen-screenshots/` | キャプチャしたスクリーンショット |

通知音とタイマー音は、上の `sounds/` と `timer-sounds/` に音声ファイルを置くと Settings のドロップダウンに並びます。

---

## クレジット

- [Hyprland](https://hypr.land/): Wayland コンポジタ
- [Quickshell](https://quickshell.outfoxxed.me/): シェルフレームワーク
- [Matugen](https://github.com/InioX/matugen): 壁紙からのカラー生成
- [Cava](https://github.com/karlstav/cava): 音声ビジュアライザ
- [Kitty](https://sw.kovidgoyal.net/kitty/): ターミナルエミュレータ
- [playerctl](https://github.com/altdesktop/playerctl): メディアプレイヤー制御
- [grim](https://sr.ht/~emersion/grim/) / [slurp](https://github.com/emersion/slurp): スクリーンショットツール
- [cliphist](https://github.com/sentriz/cliphist): クリップボード履歴
