<p align="right"><a href="SETUP.md">English</a> | <b>日本語</b></p>

# mugen-shell — セットアップガイド

## ディレクトリ構成

```
mugen-shell/
├── shell/                    # Quickshell QML ツリー (デスクトップ UI 本体)
│   ├── assets/
│   │   ├── branding/         # ロゴとバナー
│   │   └── icons/            # SVG アイコン
│   ├── components/
│   │   ├── bar/              # バー (左/右セクション + サブウィジェット)
│   │   ├── common/           # 共有 UI プリミティブ
│   │   ├── content/          # mode 別の content panel
│   │   │   ├── ai/           # AI メッセージバブル + モデルセレクタ
│   │   │   ├── bluetooth/    # ペアリング済 / 利用可能デバイスのデリゲート
│   │   │   ├── settings/     # Settings の行ごとに 1 ファイル
│   │   │   └── volume/       # オーディオデバイスのドロップダウン
│   │   ├── managers/         # Audio、WiFi、Bluetooth など
│   │   ├── notification/     # 通知コンポーネント
│   │   ├── ui/               # 時計、ワークスペース、Power Menu など
│   │   └── yura/             # Yura コーナーポップアップ用のコンポーネント
│   ├── lib/                  # ModeManager、Colors、Typography、YuraState など
│   ├── scripts/              # Shell / Python スクリプト (blur preset、ロックタイマーなど)
│   ├── windows/              # Bar.qml (トップレベルサーフェス)
│   ├── settings.default.json # OSS 向けデフォルト
│   ├── shell.qml             # メイン Quickshell エントリ (バー + 通知)
│   ├── yura-shell.qml        # Yura 用スタンドアロン Quickshell エントリ (別プロセス)
│   ├── settings-shell.qml    # スタンドアロン Settings ウィンドウ
│   └── shortcuts-shell.qml   # スタンドアロンキーボードショートカットリファレンスウィンドウ
├── ai/                       # mugen-ai Go バックエンド
│   ├── cmd/                  # CLI サブコマンド (chat、serve)
│   ├── internal/             # プロバイダレジストリ、サーバ (HTTP + SSE /events)、履歴など
│   └── contrib/systemd/      # systemd user unit
├── voice/                    # Yura 音声入力デーモン (オプション。音声入力の節を参照)
│   ├── yurad.py              # wake word -> VAD -> whisper.cpp -> /chat -> VOICEVOX
│   ├── models/               # 自作「Hey Yura」openWakeWord モデル
│   └── train/                # wake word 訓練パイプライン (VOICEVOX ベース)
├── system/                   # 周辺ツール用 dotfiles
│   ├── hypr/                 # Hyprland (configs/、scripts/、hyprland.conf など)
│   │   └── configs/          # autostart.conf / ime.conf / keybinds.conf など
│   ├── kitty/                # Kitty terminal
│   ├── fastfetch/            # システム情報表示
│   ├── matugen/              # Material You カラー生成 + テンプレート
│   ├── cava/                 # 音声ビジュアライザ (テーマ + GLSL シェーダ)
│   ├── systemd/user/         # user unit (yura-voice、voicevox-engine、event notifier)
│   └── starship.toml         # Starship prompt
├── nix/
│   └── home-manager.nix      # home-manager モジュール (Arch + Nix 経路)
├── nixos/
│   ├── flake.nix             # アンブレラ NixOS flake (root を再エクスポート + nixosModules 追加)
│   └── module.nix            # NixOS システムモジュール本体
├── flake.nix                 # ルート Nix flake (user レベル、home-manager 用)
├── flake.lock
├── Makefile                  # Nix を使わない場合の `make install`
├── .zshrc
├── README.md
└── SETUP.md                  # このファイル
```

ランタイムデータはリポジトリ外、XDG ディレクトリ配下に置かれます。

| 場所 | 中身 |
|---|---|
| `$XDG_CONFIG_HOME/mugen-shell/settings.json` | 保存されたユーザ設定 |
| `$XDG_STATE_HOME/mugen-shell/{theme-mode,idle-inhibitor.json}` | トグル状態 |
| `$XDG_CACHE_HOME/mugen-shell/{colors.json,wallp/,wallpaper-thumbs/}` | 再生成できるキャッシュ |
| `$XDG_DATA_HOME/mugen-shell/{wallpapers/,sounds/}` | ユーザが置くメディア |
| `$XDG_PICTURES_DIR/mugen-screenshots/` | キャプチャしたスクリーンショット |

メディア類は対応する XDG パスに置きます。通知音のドロップダウンは Settings を開くたびに再スキャンします。音をすぐ鳴らしたいときは:

```bash
mkdir -p ~/.local/share/mugen-shell/sounds && cp /usr/share/sounds/freedesktop/stereo/{bell,message,message-new-instant}.oga ~/.local/share/mugen-shell/sounds/
```

---

## インストール

インストール経路は 3 つあります。環境に合うものを選んでください。

### Path A — NixOS

NixOS では、アンブレラ flake (`?dir=nixos`) を使います。`programs.hyprland` の有効化、ランタイムスタックの `environment.systemPackages` への投入、home-manager モジュールの再エクスポートまでまとめて面倒を見てくれるので、ユーザ単位の部品 (mugen-ai の user service、dotfiles) も同じ input から取れます。

```nix
# /etc/nixos/flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    mugen-shell.url = "github:tmy7533018/mugen-shell?dir=nixos";
    mugen-shell.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { nixpkgs, home-manager, mugen-shell, ... }: {
    nixosConfigurations.mybox = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        mugen-shell.nixosModules.default
        home-manager.nixosModules.home-manager
        ({ ... }: {
          # System layer
          programs.mugen-shell.enable = true;

          # User layer — same input, home-manager pieces
          home-manager.users.YOUR_USER = {
            imports = [ mugen-shell.homeManagerModules.default ];
            programs.mugen-shell.enable = true;
            programs.mugen-shell.includeSystemDeps = false; # already on the system path
            home.stateVersion = "26.05";
          };
        })
      ];
    };
  };
}
```

そのあと `nixos-rebuild switch --flake /etc/nixos#mybox`。

#### fcitx5 で日本語入力 (他言語も)

モジュールが `fcitx5Addons` オプションを公開しています。これが `i18n.inputMethod` を設定し、GTK / Qt / SDL 用の環境変数をシステム全体に通します。NixOS では fcitx5 を直接 `systemPackages` に入れても**この設定は走りません**。

```nix
programs.mugen-shell.fcitx5Addons = with pkgs; [ fcitx5-mozc ];
# または: [ fcitx5-rime ]    中国語
# または: [ fcitx5-hangul ]  韓国語
```

デフォルトは `[]` (IME なし)。`hyprland.conf` の `source = ime.conf` 行はどちらでも残して大丈夫です。Hyprland が同じ環境変数を 2 回エクスポートするだけです。

### Path B — Arch / Garuda / NixOS 以外の Linux + Nix

NixOS ではないけど Nix (flakes) は使える、という環境では、リポジトリ root の user レベル flake を使い、Wayland とコンポジタ系は pacman 側で入れます。

```nix
# ~/.config/home-manager/flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    mugen-shell.url = "github:tmy7533018/mugen-shell";
    mugen-shell.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { nixpkgs, home-manager, mugen-shell, ... }:
  let system = "x86_64-linux"; in {
    homeConfigurations.YOUR_USER = home-manager.lib.homeManagerConfiguration {
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ mugen-shell.overlays.default ];
      };
      modules = [
        mugen-shell.homeManagerModules.default
        { home.username = "YOUR_USER"; home.homeDirectory = "/home/YOUR_USER"; }
        ({ ... }: {
          programs.mugen-shell.enable = true;
          # Wayland stack already on the OS path, skip the Nix copies
          programs.mugen-shell.includeSystemDeps = false;
          # Opt out of the AI backend with: programs.mugen-shell.ai.enable = false;
          home.stateVersion = "26.05";
        })
      ];
    };
  };
}
```

`home-manager switch --flake ~/.config/home-manager#YOUR_USER` でアクティベートします。

最初の switch を走らせる前に、システムスタックを pacman で入れておきます:

```bash
yay -S hyprland quickshell hypridle hyprlock zsh kitty starship libnotify \
       pipewire pipewire-pulse pavucontrol cava playerctl \
       networkmanager network-manager-applet bluez bluez-utils \
       fcitx5 fcitx5-mozc fcitx5-im fcitx5-configtool \
       awww mpvpaper ffmpeg matugen-bin socat \
       grim slurp wl-clipboard cliphist imv curl jq xdg-utils brightnessctl \
       zsh-syntax-highlighting zsh-autosuggestions zsh-history-substring-search fzf \
       eza bat ugrep fastfetch jp2a thunar \
       ttf-mplus-nerd bibata-cursor-theme colloid-gtk-theme-git \
       python-gobject
```

これを Nix 側で全部抱えたいときは `includeSystemDeps = true` にしてください。ディストリ側でパッケージが揃わない場合や、hermetic に入れたい場合に便利です。

ディスプレイマネージャやログインセッションへの Hyprland の組み込み (TTY からの `Hyprland`、sddm の session entry など) は自分でやってください。

home-manager アクティベートは、`~/.config/hypr/` が空のときだけ同梱の `system/hypr/` デフォルトをコピーします。初回ユーザはそれで mugen-shell autostart 入りの Hyprland 設定がそのまま手に入ります。既に `~/.config/hypr/hyprland.conf` がある場合はコピーされません。mugen-shell の autostart を取り込むには、既存設定にこの 1 行を足してください:

```hypr
source = ~/.config/hypr/configs/mugen-shell.conf
```

このファイルはパッケージ出力 (`$(nix path-info .#mugen-shell)/hypr/configs/mugen-shell.conf`) に含まれます。一度 `~/.config/hypr/configs/` にコピーすれば、`source =` 行のおかげで rebuild 後も追従します。この行がないと `quickshell -c mugen-shell` が走らず、バーも Yura パネルも立ち上がりません。

NixOS モジュールが自動でやってくれる、Arch 固有のハマりどころが 2 つあります:

- **`hyprlock` の PAM ファイル。** Arch はデフォルトで同梱していないので、`hyprlock` が画面ロック解除を拒否します。upstream のサンプルを `/etc/pam.d/hyprlock` に置いてください:
  ```bash
  sudo curl -fsSL https://raw.githubusercontent.com/hyprwm/hyprlock/main/pam/hyprlock \
    -o /etc/pam.d/hyprlock
  ```
- **fcitx5 の環境変数。** `fcitx5` 本体は `GTK_IM_MODULE` / `QT_IM_MODULE` / `XMODIFIERS` を自分でエクスポートしません。同梱の `system/hypr/configs/ime.conf` が Hyprland セッションをカバーします。Hyprland 外のプロセス (ログインシェル、コンポジタ外から起動した GUI アプリ) には、同じ変数を `/etc/environment` にも書いておきます。

### Path C — 純粋な手動インストール (Nix 不使用)

```bash
git clone https://github.com/tmy7533018/mugen-shell.git ~/mugen-shell
cd ~/mugen-shell
make install        # symlinks + mugen-ai のビルドと有効化
```

`make install` がやること:

- `install-symlinks`: `~/.config/quickshell/mugen-shell`、`~/.config/{cava,fastfetch,hypr,kitty,matugen}`、`~/.config/starship.toml` をチェックアウト先に向けます。
- `install-ai`: mugen-ai バイナリを `go install` して、systemd user unit を入れて有効化します。

`make install-symlinks` と `make install-ai` は独立しているので、片方だけ走らせることもできます。`make uninstall` で外せます。システムスタックは Path B と同じ `yay -S` リスト。この経路では `mugen-ai` に Go が必要です (Path A・B はビルド済みバイナリを同梱しています)。

---

## mugen-ai の設定

Yura (バー行が `Super + Y`、コーナーポップアップが `Super + Shift + Y`) は、ローカルの Go サーバと通信します。設定は **Settings → AI / Yura** にまとまっています。各パネルはバックエンドの HTTP API 経由で書き込んで、裏でホットリスタートまでやってくれるので、ターミナルを開かなくても済みます。

- **Personality**: 名前、トーン、言語、システムプロンプト。Save & Apply で `~/.config/mugen-ai/config.toml` を書き出して、systemd unit を再起動します。同じ行に escape hatch が 2 つ: **Edit toml** で `$EDITOR` でファイルを開けて、**Restart AI** で手書き編集後にサービスを再起動できます。
- **Providers**: 読み取り専用のステータスカード。どの API キーが入っているか、各プロバイダの host or base_url、モデル一覧を表示します。Refresh で取り直し。
- **Bar Yura model**: バー行と音声ターンが使うモデルを固定します (両者は Spotlight を共有しているため同じ knob です)。デフォルトのままにしておけば、コーナーポップアップで直近に選んだモデルに追従します。
- **Bar Yura thinking**: 対応モデル (qwen3、Claude sonnet+opus、Gemini 2.5、OpenAI o-series) では、バーのチャットを各プロバイダの reasoning チャンネルに流します。未対応モデルでは何も言わずチャットに戻ります。
- **Tool categories**: グループ単位 (audio、music、brightness、theme、wallpaper、notification、timer、calendar、panel、app launcher) で ON/OFF。OFF にしたカテゴリは Yura のツール一覧から消えて、OFF のものを頼まれたら Yura がそう返します。
- **Allowed apps**: `app_launch` の strict allowlist。デフォルトは空で、ピッカーでアプリを選ぶまで Yura は何も開けません。ピッカーには検索付きでインストール済の desktop app が並びます。pill のトグルで個別に切り替えるか、検索結果に対して "All on / All off" が効きます。起動リクエストに混じったシェルメタ文字 (`; | & $` 等) は常に弾かれます。
- **Yura panel side**: コーナーポップアップを左右どちらに置くか。

`mugen-ai.service` が動いていないと、バーはチャット UI の代わりにインストール案内を出します。AI 機能を使わないなら、バーのアイコンは無視して大丈夫です。

注釈付きのフル版テンプレートは `ai/config.toml.example` (Nix インストールなら `$(nix path-info .#mugen-ai)/share/mugen-ai/config.toml.example`) にあります。最小構成の `~/.config/mugen-ai/config.toml` はこんな感じ:

```toml
[personality]
# Optional auto-header. When name is empty (or "Yura"), a default
# gender-neutral assistant identity is used. Leave all three of
# name/tone/language empty to use system_prompt verbatim.
name = "Yura"
tone = "calm"
language = "en"
system_prompt = "You are a helpful desktop assistant. Be concise."

[provider.google]
models = ["gemini-2.5-flash"]

[provider.anthropic]
models = ["claude-haiku-4-5", "claude-sonnet-4-6", "claude-opus-4-7"]

[provider.openai]
# Any OpenAI-compatible backend: OpenAI, OpenRouter, LM Studio, vLLM, etc.
# base_url = "https://api.openai.com/v1"        # OpenAI itself
# base_url = "https://openrouter.ai/api/v1"     # OpenRouter
# base_url = "http://localhost:1234/v1"         # LM Studio (no API key needed)
# models = ["gpt-4o-mini", "gpt-4o"]            # leave empty to query /v1/models

[tools.app_launch]
# Strict by default: empty list = Yura cannot launch anything. The
# Settings → AI / Yura → Allowed apps picker is the easiest way to
# populate this. Hand-editing also works.
allowed_commands = ["firefox", "kitty", "code"]

[tools]
# Tool categories to hide from Yura (audio / music / brightness /
# theme / wallpaper / notification / timer / calendar / panel / app).
# Empty = every category enabled. Toggle via Settings → AI / Yura →
# Tool categories.
disabled_categories = []
```

- `[personality]`: `name`、`tone`、`language` が auto-header を組み立てます。`system_prompt` はそのあとに自由記述として足されます。空欄のフィールドはスキップ。
- `[provider.ollama]`: ローカル Ollama は `http://localhost:11434` で最初から有効です。Ollama デーモンが別の場所にあるときだけ `host` を上書きしてください。
- `[provider.google].models`: Gemini を有効化します (`GEMINI_API_KEY` が必要)。`models` が空のときは、レガシの単数 `model` も認識します。
- `[provider.openai]`: OpenAI 互換プロバイダ用。`OPENAI_API_KEY` が入っている (クラウド向け)、または `base_url` がローカルサーバを指している、のどちらかで有効になります。`models` は任意で、空ならバックエンドの `/v1/models` に聞きに行きます。
- `[provider.anthropic].models`: Claude を有効化します (`ANTHROPIC_API_KEY` が必要)。`models` を省略すると `claude-haiku-4-5` がデフォルトに。tool-calling 用途におすすめ (速い、正確、低コスト)。
- `[tools.app_launch].allowed_commands`: `app_launch` ツールの strict allowlist。空 (またはブロックそのものなし) ならどのアプリも起動できません。マッチはバイナリの basename で行います。バックエンドは basename を、対応する `.desktop` の Exec パスに解決するので、`$PATH` 外のバイナリ (例: Zen Browser の `/opt/zen-browser-bin/zen-bin`) もちゃんと起動できます。バイナリが `flatpak` でアプリ名と一致しない Flatpak アプリ (Discord、Spotify など) は、display name フォールバックで拾います。`flatpak` がリストに入っていれば、Yura に「Discord」と頼めば対応する `.desktop` から full Exec で起動します。
- `[tools].disabled_categories`: `audio music brightness theme wallpaper notification timer calendar panel app` から任意のものをリストに入れると、そのグループのツールが Yura から隠れます。MCP サーバ名 (後述) もカテゴリとして使えます。
- `[mcp.servers.<name>]`: 外部 [Model Context Protocol](https://modelcontextprotocol.io) サーバを登録し、そのツールを Yura のツールセットにマージします。下の *MCP サーバ* を参照。

### MCP サーバ

mugen-ai は外部の [Model Context Protocol](https://modelcontextprotocol.io) サーバ (memory、filesystem、GitHub など) からツールを引っ張ってきて、組み込みのシェルツールと並べて Yura に渡せます。サーバごとに `[mcp.servers.<name>]` ブロックを 1 つ書きます:

```toml
[mcp.servers.memory]
command = "npx"
args = ["-y", "@modelcontextprotocol/server-memory"]
# env = { MEMORY_FILE_PATH = "/home/you/.local/state/mugen-ai/memory.json" }
# disabled = false   # エントリは残したまま、起動だけスキップ
# trusted = false    # true にすると、このサーバのツールでは承認プロンプトを省略
```

`command` はサービスの `PATH` 上にある必要があります。mugen-ai はサーバランタイムを同梱していません。`npx` 系のサーバなら Node.js、`uvx` 系なら [uv](https://docs.astral.sh/uv/) が要ります。Nix ユーザは `home.packages` にランタイム (例: `nodejs`) を足しておいてください。

各サーバは mugen-ai 起動時に stdio サブプロセスとして立ち上げられます。ツールは `<name>__<tool>` プレフィックス付き (`memory__read_graph`、`filesystem__read_file`) で取り込まれるので、サーバ名がそのままツールカテゴリにもなります。サーバ丸ごと Yura から外したいときは、サーバ名を `[tools].disabled_categories` に足してください。プレフィックスが曖昧にならないよう、サーバ名は小文字短めでアンダースコアなしを推奨します。組み込みツールと同じセキュリティゲート (監査ログ、カテゴリゲート、結果サニタイズ) と、下の承認プロンプトがそのまま効きます。

起動やハンドシェイクに失敗したサーバは journal にログを残してスキップされます。残りのサーバは普通にロードされます。一度繋がったあとにクラッシュした場合は、そのサーバのツールが次に呼ばれたタイミングで自動で再ダイヤルされます。設定を編集したあとは `mugen-ai.service` を再起動して変更を反映してください。

**承認プロンプト。** 取り返しのつかない変更を起こしうるツール (メッセージ送信、レコード削除など) は、Yura が呼んだ時点でいったん止まります。チャット UI に Approve / Deny プロンプトが出て、承認したときだけ実行されます。Deny、タイムアウト、チャットを閉じた、はすべて「拒否」として扱われ、Yura に伝わります。どのツールをゲートするかは、サーバが返す `readOnlyHint` / `destructiveHint` のアノテーションで判定します。どちらも来ない場合はツール名でフォールバック判定します (先頭が `get` / `list` / `read` / `search` などなら read 扱い)。完全に信頼できるサーバには `trusted = true` を付けると、全ツールがプロンプト無しで通ります。

**`env` のシークレット。** サーバの `env` テーブルの値では `${VAR}` 参照が使えます。mugen-ai 自身の環境から解決されます。トークンは `~/.config/mugen-ai/.env` (systemd unit が読み込みます) に置いて、`env = { GITHUB_TOKEN = "${GITHUB_TOKEN}" }` のように書けば、シークレットが `config.toml` に残らずに済みます。`config.toml` 自体はパーミッション `600` で保護されています。

### プロバイダ API キー

`ai/.env.example` (Nix インストールなら `$(nix path-info .#mugen-ai)/share/mugen-ai/.env.example`) を `~/.config/mugen-ai/.env` にコピーして手持ちのキーを埋めるか、直接追記してください:

```sh
cat >> ~/.config/mugen-ai/.env <<'EOF'
ANTHROPIC_API_KEY=sk-ant-...
GEMINI_API_KEY=...
OPENAI_API_KEY=...
EOF
chmod 600 ~/.config/mugen-ai/.env
systemctl --user restart mugen-ai.service
```

値が入っているキーだけがそのプロバイダを有効化します。使わないプロバイダの行は空のままにしておけば OK です。

### シェル操作に向くモデル

Yura は function-calling ツールでデスクトップを操作するので、「ちゃんと動かせるか」(チャットするだけでなく) はモデルの tool-calling 性能に左右されます。

- **ホスト API モデル** (Claude、Gemini) が一番安定です。ツールセットが多めでも構造化されたツール呼び出しを安定して返してくれます。
- **ローカル Ollama**: 最近の中規模モデルがおすすめです。`qwen3:14b` は安定してツールを動かせます。`qwen3:4b` も動きますが、**Thinking** トグルを ON にしてください。Thinking OFF だと reasoning が返信に漏れ出します。古めや小さめのモデル (例: `qwen2.5:7b`) は、ツール呼び出しをただのテキストとして出してしまいがちで、チャットには使えてもシェル操作には頼りにくいです。

ツールサポートが一切ないモデルは検出して、自動でチャット専用にフォールバックします。

### リスナーアドレス

`mugen-ai serve --port 11436` で、その起動分だけリスナーポートを変えられます。systemd unit にずっと反映させたいときは、`~/.config/mugen-ai/.env` で `MUGEN_AI_PORT` (お好みで `MUGEN_AI_HOST`、デフォルト `127.0.0.1`) を設定してください。同じ環境変数はシェル側のクライアント (`shell/lib/AiBackend.qml`) からも読まれるので、バーとフローティングパネルがずれません。

```sh
echo 'MUGEN_AI_PORT=11436' >> ~/.config/mugen-ai/.env
systemctl --user restart mugen-ai.service
```

### HTTP API

`mugen-ai serve` はデフォルトで `127.0.0.1:11435` を listen します。シェルとはプレーン HTTP で話します。会話とメッセージは SQLite (`~/.local/state/mugen-ai/history.db`) に保存されます。

| Method | Path | 説明 |
|--------|------|-------------|
| POST | `/chat` | メッセージを送って SSE ストリームを受け取ります。Body: `{message, conversation_id, model, thinking?}`。`conversation_id: 0` で新規会話を自動作成、`>0` ならその会話に追記します。`thinking` は任意の bool で、未指定なら会話に保存された値を継承、指定すればその会話に永続化されます。最初の SSE イベントは `{conversation_id, model}` でクライアントが状態を合わせられるようにしています。会話にバインドされたモデルが常に優先されます。リクエストの `model` フィールドは新規会話のときだけモデルのシードに使われます。 |
| POST | `/chat/confirm` | `/chat` 中に destructive な MCP ツールが上げた承認プロンプトに答えます。Body: `{confirm_id, approved}`。`confirm_id` はストリームの `tool_confirm` イベントから来ます。チャット UI が呼びます。404 が返るのはプロンプトが既に失効した (回答済 or タイムアウト) ときです。 |
| GET | `/health` | サーバの状態とアクティブモデル。 |
| GET | `/models` | 利用可能なモデル一覧。 |
| PUT | `/model` | *次に*作る新規会話のデフォルトモデルを設定します (`{"model": "name"}`)。既存の会話はそれぞれのバインド済モデルのままです。 |
| GET | `/conversations` | 全会話の一覧 (id、title、model、thinking、timestamps)。 |
| GET | `/conversations/current` | 現在の会話とそのメッセージ。 |
| GET | `/conversations/{id}` | 指定 ID の会話とそのメッセージ。 |
| POST | `/conversations` | 空の会話を明示的に作成。 |
| POST | `/conversations/{id}/select` | 指定の会話をカレントにします。 |
| DELETE | `/conversations/{id}` | 会話を削除します。 |
| DELETE | `/conversations` | 全会話を削除します。Settings GUI が confirm を挟んで呼びます。 |
| GET | `/conversations/stats` | 履歴 DB のパス、会話数、ディスク上のサイズ。 |
| GET | `/conversations/export` | 全会話とそのメッセージを 1 つの JSON にまとめて返します。 |
| GET | `/events` | 状態変化 (新規会話 / メッセージ) を流す Server-Sent Events ストリーム。UI のライブ同期用。 |
| GET | `/tools` | バックエンドが LLM に公開しているツール一覧 (組み込みシェルツール + MCP サーバのツール)。 |
| POST | `/tools/call` | デバッグ用。名前指定でツールを LLM 抜きで呼びます。Body: `{name, args}`。 |
| GET | `/mcp/servers` | 設定済 MCP サーバの起動ステータス (`{name, connected, tool_count, error, disabled}`)。 |
| GET | `/config` | ディスク上の設定と `api_key_configured` マップ (プロバイダ環境変数の有無のみで値そのものは返しません) を返します。 |
| PUT | `/config` | ディスク上の設定をアトミックに置き換えます。Settings GUI が使います。レスポンスは `{saved: true, restart_required: true}`。 |
| POST | `/config/restart` | systemd unit を再起動して `/config` での変更を反映します。サービスが systemd 管理であることが前提です。 |

ターミナル用途は `mugen-ai chat`。

---

## 音声入力 (オプション)

Yura はハンズフリーでも操作できます。**「Hey Yura」**と呼びかけて話すと、返答が読み上げられます。

```
mic → openWakeWord (voice/models/hey_yura.onnx) → silero VAD → whisper.cpp → mugen-ai /chat → VOICEVOX
```

デフォルト構成は日本語ファーストですが、日本語専用ではありません (後述の「他言語で使う」参照)。**Nix flake / `make install` にはまだ含まれていません** — mugen-ai が動いている前提で、手動セットアップになります:

1. **デーモン用の Python venv** (Python 3.14 には tflite の wheel が無いので、openwakeword は `--no-deps` で入れて ONNX 経路で動かします。ピン留めしたランタイム依存は `voice/requirements.txt` にあります):
   ```bash
   cd ~/mugen-shell/voice
   python -m venv .venv
   .venv/bin/pip install --no-deps openwakeword==0.6.0
   .venv/bin/pip install onnxruntime numpy scipy scikit-learn tqdm requests sounddevice
   ```
2. **whisper.cpp** をローカルビルドして、サーババイナリを `~/.local/src/whisper.cpp/build/bin/whisper-server`、モデルを `~/.local/share/whisper/ggml-large-v3-turbo.bin` に配置 (`YURA_WHISPER_BIN` / `YURA_WHISPER_MODEL` で上書き可)。サーバの起動と監視はデーモンがやります。
3. **VOICEVOX engine** を `127.0.0.1:50021` で待受。同梱の `voicevox-engine.service` は nixpkgs の `voicevox-engine` が `~/.nix-profile/bin` にある前提なので、他の入れ方をした場合は `ExecStart` を調整してください。オプションで [AivisSpeech Engine](https://github.com/Aivis-Project/AivisSpeech-Engine)(VOICEVOX 互換 API で、Style-BERT-VITS2 のずっと自然な声が使えるエンジン)を `~/.local/opt/aivisspeech-engine` に展開すると (ポート `10101`、`aivisspeech-engine.service` 同梱)、同じピッカーに `Aivis:` として並びます。
4. **systemd unit**:
   ```bash
   ln -s ~/mugen-shell/system/systemd/user/{yura-voice,voicevox-engine,aivisspeech-engine}.service ~/.config/systemd/user/
   systemctl --user daemon-reload
   # 使う声の TTS エンジンだけ enable する
   systemctl --user enable --now voicevox-engine.service yura-voice.service
   ```

実行中の制御は **Settings → Voice input** から: 有効トグル (OFF でマイクを解放。再起動なしで即反映)、連続会話トグル (返答のあと数秒マイクを開けたままにして、wake word 無しで次の発話を聞く。無音なら idle へ)、wake word で開く先 (panel / bar / none)、試聴ボタン付きのボイスピッカー、話速セレクタ、音声認識の言語 (Auto / JA / EN)。声・話速・言語は次の発話から反映されます (デーモンが `settings.json` を監視)。両方の Yura UI に push-to-talk のマイクボタンが付き (wake word 無効でも使えます)、listening 中はキャンセルボタンに変わります。

### 他言語で使う

エンジン依存なのは返答の声だけで、それ以外はもともと多言語対応です。英語 (や他の言語) で Yura の音声を使うには:

- **TTS**: [Piper](https://github.com/rhasspy/piper) を入れて (`PATH` 上の `piper`、または `YURA_PIPER_BIN`)、[rhasspy/piper-voices](https://huggingface.co/rhasspy/piper-voices) の声 (`.onnx` + `.onnx.json` のペア) を `~/.local/share/piper/voices/` に置きます。Settings の同じボイスピッカーに `Piper: <名前>` として並び、**選んだ声がエンジンを決める**ので、別途エンジン切替はありません。この場合 VOICEVOX は無くても動きます。
- **STT**: Speech recognition を Auto (発話ごとに自動判定) か固定言語に。whisper は約 100 言語をカバーします。
- **Wake word**: `YURA_WAKEWORD` 未設定ならデーモンは openWakeWord 同梱の英語モデル `hey_jarvis` を使います。同梱の `hey_yura.onnx` は日本語発音チューニングなので、他のアクセント向けには `voice/train/` で再訓練を。
- **返答の言語**: Settings → AI / Yura → Personality の language で指定します。

環境変数ノブ (unit か drop-in で設定): `YURA_WAKEWORD` (カスタムモデルのパス。デフォルト `hey_jarvis`)、`YURA_WAKE_THRESHOLD` (自作モデル用に `0.7` を設定済み)、`YURA_WAKE_PATIENCE` (閾値を連続で超えるべきフレーム数。デフォルト `2`)、`YURA_VOICEVOX_SPEAKER` (デフォルト `14`)、`YURA_VOICE_LANG`、`YURA_VOICE_SPEED`、`YURA_WHISPER_URL`、`YURA_VOICEVOX_URL`、`YURA_AIVIS_URL`。

**ヘッドホンじゃなくてスピーカー派?** メディア音声がマイクに入ると、誤起動の原因になる上に本物の呼びかけも埋もれます。PipeWire の WebRTC エコーキャンセルで両方解決できます — デフォルト sink の再生内容をマイク入力から差し引くので、再生中でも wake word が通ります。`~/.config/pipewire/pipewire.conf.d/99-yura-echo-cancel.conf` に以下を置いて (`target.object` は `wpctl inspect` で調べた自分のマイクの `node.name` に)、PipeWire を再起動後、`wpctl set-default <id>` で新しいソースをデフォルト入力にします:

```
context.modules = [
    { name = libpipewire-module-echo-cancel
      args = {
          monitor.mode = true
          audio.channels = 1
          capture.props = { node.name = "yura_aec_capture" target.object = "<your-mic-node-name>" node.passive = true }
          source.props = { node.name = "yura_aec_source" node.description = "Mic (echo-cancelled)" }
      }
    }
]
```

### wake word モデル

`voice/models/hey_yura.onnx` は、VOICEVOX で合成した「Hey Yura」の日本語発音 (127 スピーカースタイル、約 9,600 クリップ) で訓練した自作 openWakeWord モデルです。既製の英語モデルより日本語アクセントにずっと良く合います。held-out での recall@0.7 は 0.91、わざと似せたフレーズへの誤反応は 2.8%。クリップ生成〜augmentation〜訓練〜検証のパイプライン一式は [`voice/train/`](voice/train/README.md) にあり、ローカルで回せます (ROCm GPU 対応)。

---

## キーバインド

### Mugen Shell

| キー | アクション |
|-----------|--------|
| `Super + R` | アプリランチャー |
| `Super + W` | 壁紙ピッカー |
| `Super + P` | Power Menu |
| `Super + V` | クリップボード履歴 |
| `Super + M` | 音楽プレイヤー |
| `Super + T` | 通知センター |
| `Super + Y` | Yura (バー) |
| `Super + Shift + Y` | Yura (コーナーポップアップ) |
| `Super + C` | カレンダー |
| `Super + S` | スクリーンショットギャラリー |
| `Super + U` | 音量 / マイクコントロール |
| `Super + I` | WiFi パネル |
| `Super + E` | Bluetooth パネル |
| `Super + ,` | Settings |
| `Super + Shift + T` | カウントダウンタイマー |
| `Super + /` | キーボードショートカット一覧 |
| `Super + Shift + I` | Idle inhibitor のトグル |

ほとんどのパネルキーバインドは `shell/scripts/mugen-shell-ipc.sh` を介して Unix socket で投げます。スタンドアロンのウィンドウ (カレンダー、Settings、キーボードショートカット) は別の Quickshell プロセスで動いていて、対応する `toggle-*.sh` スクリプトでトグルします。

### ウィンドウ管理

| キー | アクション |
|-----------|--------|
| `Super + Enter` | ターミナル (`autostart.conf` の `$terminal`、デフォルト: kitty) |
| `Super + N` | ファイルマネージャ (`$fileManager`、デフォルト: thunar) |
| `Super + B` | ブラウザ (`$browser`、デフォルト: firefox) |
| `Super + Backspace` | アクティブウィンドウを閉じる |
| `Super + 1-5` | ワークスペース切替 |
| `Super + Shift + 1-5` | ウィンドウを別ワークスペースへ (silent) |
| `Alt + Shift + 1-5` | ウィンドウを別ワークスペースへ |
| `Super + Tab` | ワークスペース内のウィンドウを循環 |
| `Super + hjkl` | ウィンドウ間のフォーカス移動 (vim 風) |
| `Super + Shift + hjkl` | タイル内のウィンドウ移動 (vim 風) |
| `Super + Shift + Space` | フローティングのトグル |
| `Super + F` | フルスクリーン |
| `Super + F12` / `Print` | 範囲スクリーンショット (grim + slurp + wl-copy) |
| `Super + Shift + S` | special workspace のトグル |
| `Super + Shift + R` | Hyprland 設定のリロード |

### メディア & システム

| キー | アクション |
|-----------|--------|
| `XF86AudioLowerVolume` | 音量ダウン |
| `XF86AudioRaiseVolume` | 音量アップ |
| `XF86AudioMute` | ミュート切替 |
| `XF86AudioMicMute` | マイクミュート切替 |
| `XF86AudioPlay` | 再生 / 一時停止 |
| `XF86AudioNext` | 次のトラック |
| `XF86AudioPrev` | 前のトラック |
| `XF86MonBrightnessUp` | 輝度アップ (バックライト付きラップトップ) |
| `XF86MonBrightnessDown` | 輝度ダウン (バックライト付きラップトップ) |

---

## コンポーネント

### コンテンツパネル (`shell/components/content/`)
- **AppLauncherContent**: アプリの検索と起動。
- **MusicPlayerContent**: シーク可能な進捗スライダ付きの音楽プレイヤー UI。
- **NotificationContent**: 通知センター。
- **ClipboardContent**: クリップボード履歴。
- **WiFiContent**: WiFi 管理 UI。
- **BluetoothContent**: Bluetooth 管理 UI。
- **VolumeContent**: 音量 / マイクコントロール UI。
- **BrightnessContent**: バックライトスライダ (ラップトップ専用、バックライトが無いマシンでは非表示)。
- **WallpaperContent**: 壁紙管理 UI。
- **PowerMenuContent**: Power Menu。
- **ScreenshotGalleryContent**: スクリーンショットギャラリー。
- **CalendarFloatingContent**: SQLite 保存のイベント付きスタンドアロン 2 ペインカレンダー。`Super + C` で独自ウィンドウとして開きます。
- **TimerContent**: カウントダウンタイマー UI (idle / running、リング + プリセット、キーボード操作)。
- **SettingsFloatingContent**: サイドバーカテゴリ付きスタンドアロン Settings ウィンドウ (各行は `settings/`)。
- **KeyboardShortcutsContent**: スタンドアロンのキーボードショートカット一覧 (`Super + /`)。
- **AiAssistantContent**: バー入力行 (`Super + Y`)。
- **AiAssistantFloatingContent**: Yura コーナーパネル内のチャット (サイドバー、メッセージリスト、モデルドロップダウン、パネル内 Yura インジケータ)。

### Yura (`shell/components/yura/`、`shell/yura-shell.qml`)
- **yura-shell.qml**: スタンドアロン Quickshell プロセス。Hyprland から自動起動され、`qs ipc call yura toggle` でトグルされます。
- **YuraChatPanel**: `AiAssistantFloatingContent` を読み込むサイドアンカーの layer-shell ウィンドウ。インジケータの orb は別オーバーレイではなくパネル内に描画されます。

### マネージャ (`shell/components/managers/`)
MusicPlayerManager、NotificationManager、ClipboardManager、WiFiManager、BluetoothManager、AudioManager、AudioLevel、CavaManager、MicCavaManager、BatteryManager、BrightnessManager、WallpaperManager、ScreenshotManager、IdleInhibitorManager、ImeStatus。

### コアライブラリ (`shell/lib/`)
ModeManager、SettingsManager、TimerManager、Colors、Typography、Animations、IconProvider、IconResolver、AiBackend、IpcRouter、YuraState。

---

## トラブルシューティング

### USB キーボード / マウスが反応しなくなる (例: pavucontrol を開いたとき)

**症状:** `pavucontrol` を開いたあと、キーボードとマウスが効かなくなる。
**原因:** USB のポーリングがワイヤレスドングルを省電力 (suspend) モードに入れる。
**対処:** カーネルパラメータで USB autosuspend を無効化する。

```bash
sudo nano /etc/default/grub
# 追加: GRUB_CMDLINE_LINUX_DEFAULT="... usbcore.autosuspend=-1"
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

### ワイヤレスヘッドセット使用時に音声 / 動画がフリーズ

**症状:** ワイヤレスヘッドセットに切り替えると音声が落ちる。ログに `Failed to get percentage from UPower`。
**対処:** `sudo systemctl enable --now upower`

### Firefox / Zen Browser が PipeWire と競合

**症状:** ブラウザ起動中に音声設定を開くとクラッシュ。
**対処:** `about:config` で `media.cubeb.sandbox` を `false` にして、ブラウザを再起動。

### 使っていない音声出力デバイスが出てくる

**対処:** `pavucontrol` → Configuration タブで、使わないデバイス (GPU オーディオなど) を Off に。

---

## クレジット

- [Hyprland](https://hyprland.org/) — Wayland コンポジタ
- [Quickshell](https://quickshell.outfoxxed.me/) — シェルフレームワーク
- [Matugen](https://github.com/InioX/matugen) — Material You カラー生成
- [Cava](https://github.com/karlstav/cava) — 音声ビジュアライザ
- [Kitty](https://sw.kovidgoyal.net/kitty/) — ターミナルエミュレータ
- [playerctl](https://github.com/altdesktop/playerctl) — メディアプレイヤー制御
- [grim](https://sr.ht/~emersion/grim/) / [slurp](https://github.com/emersion/slurp) — スクリーンショットツール
- [cliphist](https://github.com/sentriz/cliphist) — クリップボード履歴
- [openWakeWord](https://github.com/dscripka/openWakeWord) — ウェイクワード検出
- [Silero VAD](https://github.com/snakers4/silero-vad) — 音声区間検出
- [whisper.cpp](https://github.com/ggml-org/whisper.cpp) — 音声認識
- [VOICEVOX](https://voicevox.hiroshiba.jp/) — TTS エンジン。同梱の `hey_yura.onnx` ウェイクワードモデルの学習に使った合成音声の生成元でもあります
- [AivisSpeech Engine](https://github.com/Aivis-Project/AivisSpeech-Engine) — VOICEVOX 互換の Style-Bert-VITS2 系 TTS。モデルは [AivisHub](https://hub.aivis-project.com/) から
- [Piper](https://github.com/rhasspy/piper) — 日本語以外の声向け TTS
