<p align="right"><a href="SETUP.en.md">English</a> | <b>日本語</b></p>

# mugen-shell: セットアップガイド

## インストール

インストール経路は 2 つあります。どちらも **Hyprland 0.55 以上**が前提です。自分の環境に合う方を開いてください。

- **Path A: NixOS** — リポジトリの flake を読み込むだけ
- **Path B: Arch など NixOS 以外の Linux + Nix** — home-manager (ユーザ単位) + distro のパッケージ

<details>
<summary><b>Path A: NixOS</b></summary>

リポジトリ root の flake を読み込むだけでインストールできます:

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
        mugen-shell.nixosModules.default
        home-manager.nixosModules.home-manager
        ({ ... }: {
          # System layer
          programs.mugen-shell.enable = true;

          # Required — home-manager won't see the mugen-shell overlay without it
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
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

書けたら `nixos-rebuild switch --flake /etc/nixos#mybox` を実行してください。

**ターミナルも mugen-shell の見た目にする (オプション)**

有効にすると、starship のプロンプト、fish 風の補完と履歴、`ls` → `eza` のエイリアス、kitty 起動時のスプラッシュが入ります。ツールはシステム層、設定ファイルは home-manager 層に入るため、次の 2 行が両方必要です:

```nix
programs.mugen-shell.zsh.enable = true;                    # システム層
home-manager.users.YOUR_USER.programs.mugen-shell.zsh.enable = true;
```

最後に、自分の `~/.zshrc` に次の 1 行を足してください (home-manager の `programs.zsh` を使っている場合は不要です):

```sh
source ~/.config/mugen-shell/mugen-shell.zshrc
```

**fcitx5 で日本語入力 (他の言語も同様)**

使いたい IME を `fcitx5Addons` に書くと、ログインセッションごとに IME が登録されます。**注意:** NixOS では、fcitx5 を自分で `systemPackages` に入れる方法では動きません。必ずこのオプションを使ってください。

```nix
programs.mugen-shell.fcitx5Addons = with pkgs; [ fcitx5-mozc ];
# または: [ fcitx5-rime ]    中国語
# または: [ fcitx5-hangul ]  韓国語
```

</details>

<details>
<summary><b>Path B: Arch や NixOS 以外の Linux + Nix</b></summary>

リポジトリ root の flake を home-manager (ユーザ単位) から使う経路です。Hyprland 本体と Wayland まわりは distro 側 (pacman など) で入れます。

**1. システム側のパッケージを入れる**

home-manager を switch する前に、まずシステム側を揃えます:

```bash
yay -S hyprland quickshell qt6-5compat hypridle zsh kitty libnotify \
       pipewire pipewire-pulse pavucontrol cava playerctl \
       networkmanager network-manager-applet bluez bluez-utils \
       fcitx5 fcitx5-mozc fcitx5-im fcitx5-configtool \
       awww mpvpaper ffmpeg matugen-bin socat \
       grim slurp wl-clipboard cliphist imv curl jq xdg-utils brightnessctl fzf \
       thunar \
       ttf-mplus-nerd bibata-cursor-theme colloid-gtk-theme-git \
       python-gobject
```

なお `includeSystemDeps = true` にする場合、このうちユーザ空間のツール (Quickshell、hypridle、awww、matugen、kitty など) は Nix 側から入るため pacman では不要になります。ただし Hyprland 本体・システムサービス・テーマ類は、どちらの設定でも pacman で入れてください。

**2. home-manager の flake を書く**

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

**3. アクティベートする**

```bash
home-manager switch --flake ~/.config/home-manager#YOUR_USER
```

アクティベートすると、同梱の `system/hypr/` と `matugen/` が `~/.config/` に配置されます。中身は次回以降のアクティベートでも更新されますが、`hypridle.conf`・`colors.lua`・`configs/blur.lua`・`configs/user-overrides.lua`・`configs/keybind-overrides.lua` はその場所にまだ無いときだけ作られ、以降は触られません。`cava`・`kitty`・`fastfetch` の設定と `starship.toml` は今まで通りその場所にまだ設定が無いときだけコピーされます。

Hyprland の起動方法 (TTY から `Hyprland` を叩く、sddm にセッションを登録する、など) は自分で用意してください。

**4. 自前の Hyprland 設定を使っている場合: autostart を足す**

すでに自分の Hyprland 設定を持っている場合、autostart は自動では入りません。次の 1 行を自分で足してください。これが無いと `quickshell -c mugen-shell` が起動しません:

```lua
dofile(os.getenv("HOME") .. "/.config/hypr/configs/mugen-shell.lua")
```

読み込むファイル自体は、アクティベート時に `~/.config/hypr/configs/mugen-shell.lua` へ置かれます。コピーは要りません。

自前の config がまだ hyprlang (`.conf`) の場合は、同じ内容の hyprlang 版を使ってください:

```hypr
source = ~/.config/hypr/configs/mugen-shell.conf
```

**5. Arch で追加で必要な設定 (2 つ)**

- **ロック画面の PAM ファイル。** これが無いとロック画面で認証できず、`ext-session-lock` がセッションを掴んだままになります。先に作っておいてください:
  ```bash
  printf '#%%PAM-1.0\nauth include system-auth\n' | sudo tee /etc/pam.d/mugen-lock
  ```
- **fcitx5 の環境変数。** Hyprland セッション内では、同梱の `system/hypr/hyprland.lua` が `XMODIFIERS` を設定してくれます。コンポジタの外から起動するアプリのために、`/etc/environment` にも同じものを書いておいてください。

**ターミナルも mugen-shell の見た目にする (オプション)**

starship のプロンプト、fish 風の補完と履歴、`ls` → `eza` のエイリアス、kitty 起動時のスプラッシュが入ります。

```nix
programs.mugen-shell.zsh.enable = true;
```

`includeSystemDeps = false` のままの場合は、必要なツールを pacman で入れてください:

```bash
yay -S starship jp2a fastfetch eza bat ugrep \
       zsh-syntax-highlighting zsh-autosuggestions zsh-history-substring-search
```

そのうえで、自分の `~/.zshrc` に次の 1 行を足してください (home-manager の `programs.zsh` を使っている場合は不要です):

```sh
source ~/.config/mugen-shell/mugen-shell.zshrc
```

**トラブルシューティング: `version 'Qt_6.11' not found`**

オーディオビジュアライザの QML モジュールは Nix 側でビルドされます。quickshell が `Mugen.Audio` の import に失敗してこのエラーを出す場合、distro の Qt6 がビルド時のものより古いのが原因です。Qt を更新するか、`plugin/` を自分でビルドしてインストール先を `QML2_IMPORT_PATH` に足してください。

</details>

---

## mugen-ai の設定

設定は **Settings → Yura** にまとまっています。personality、プロバイダの状態、モデル、tool categories、allowed apps、パネルの左右位置まで、すべてここから変更できます。保存すると、必要なサービスの再起動も自動で行われます。手で編集したい場合は、同じ画面の **Edit toml** から `~/.config/mugen-ai/config.toml` を `$EDITOR` で開けます。

**インストール直後につまずきやすいポイントが 3 つあります:**

1. **モデルは同梱されていません。** Ollama を入れてモデルを 1 つ pull する (`ollama pull qwen3:4b` など) か、`~/.config/mugen-ai/.env` に API キーを置くまで、入力欄は "No model yet" のままです。
2. **Allowed apps は空の状態から始まります。** ここでアプリを許可するまで、Yura は何も起動できません。
3. **`mugen-ai.service` が止まっている場合**は、バーに起動用のコマンドが表示されます。

注釈付きのフル版テンプレートは `ai/config.toml.example` にあります (Nix インストールの場合は `$(nix build --no-link --print-out-paths github:tmy7533018/mugen-shell#mugen-ai)/share/mugen-ai/config.toml.example`)。

<details>
<summary>最小構成の <code>~/.config/mugen-ai/config.toml</code></summary>

```toml
[personality]
# Optional auto-header. Leave all three empty to use system_prompt verbatim.
name = "Yura"
tone = "calm"
language = "en"
system_prompt = "You are a helpful desktop assistant. Be concise."

[provider.google]
# models = [...]   # omit for the provider's default model

[provider.anthropic]
# models = [...]   # omit for the provider's default model

[provider.openai]
# Any OpenAI-compatible backend: OpenAI, OpenRouter, LM Studio, vLLM, etc.
# base_url = "https://api.openai.com/v1"        # OpenAI itself
# base_url = "https://openrouter.ai/api/v1"     # OpenRouter
# base_url = "http://localhost:1234/v1"         # LM Studio (no API key needed)
# models = [...]                                # leave empty to query /v1/models

[tools.app_launch]
# Empty = Yura cannot launch anything. The Allowed apps picker fills this.
allowed_commands = ["firefox", "kitty", "code"]

[tools]
# Categories to hide from Yura (audio / music / brightness / theme /
# wallpaper / notification / timer / calendar / panel / app / memory /
# weather). Disabling "memory" also hides saved memories.
disabled_categories = []
```

- `[provider.ollama]`: 既定で `http://localhost:11434` を見に行きますが、**Ollama 本体はどのインストール経路にも含まれていません**。自分でインストールしてモデルを pull してください。デーモンを別の場所で動かしている場合のみ `host` を上書きします。
- `[provider.google]` には `GEMINI_API_KEY` が、`[provider.anthropic]` には `ANTHROPIC_API_KEY` が必要です。`models` はどちらも省略でき、その場合はプロバイダごとの既定モデルが 1 本だけ使われます。指定したいときは、各プロバイダのドキュメントで現行のモデル ID を確認してください。
- `[provider.openai]`: OpenAI 互換プロバイダ用です。`OPENAI_API_KEY` が設定されているか、`base_url` がローカルサーバを指していれば有効になります。`models` を空にすると、バックエンドの `/v1/models` に問い合わせます。
- `[tools.app_launch].allowed_commands`: バイナリの basename で照合します。`$PATH` に無いものは `.desktop` ファイルから解決され、Flatpak アプリは `flatpak` が入ってさえいれば表示名で指定できます。
- `[tools].disabled_categories`: MCP のサーバ名も指定できます。指定すると、そのサーバごと無効になります。

</details>

<details>
<summary><b>MCP サーバ</b>: 外部ツールを取り込む</summary>

mugen-ai は、外部の [Model Context Protocol](https://modelcontextprotocol.io) サーバ (memory、filesystem、GitHub など) からツールを取り込み、組み込みのシェルツールと一緒に Yura に渡せます。サーバごとに `[mcp.servers.<name>]` ブロックを 1 つ書きます:

```toml
[mcp.servers.memory]
command = "npx"
args = ["-y", "@modelcontextprotocol/server-memory"]
# env = { MEMORY_FILE_PATH = "/home/you/.local/state/mugen-ai/memory.json" }
# disabled = false   # エントリは残したまま、起動だけスキップ
# trusted = false    # true にすると、このサーバのツールでは承認プロンプトを省略
```

`command` は、サービスの `PATH` から見える場所にある必要があります。mugen-ai はサーバのランタイムを同梱していないため、`npx` 系なら Node.js を、`uvx` 系なら [uv](https://docs.astral.sh/uv/) を別途インストールしてください。Nix の場合は `home.packages` に足しておきます。

`command` の代わりに `url = "https://example.com/mcp"` を書くと、リモートの Streamable HTTP サーバに接続します。この場合、ローカルのランタイムは不要です。

ツールは `<name>__<tool>` という名前で取り込まれます。そのため、サーバ名は短く・小文字で・アンダースコア無しにしてください。設定を変更したら、`mugen-ai.service` を再起動すると反映されます。

**承認プロンプト。** 取り返しのつかない変更を起こしうるツールは、Yura が呼び出した時点で一度停止します。チャット UI に Approve / Deny が表示されるので、そこで判断してください。Deny を押す・タイムアウトする・チャットを閉じる、のいずれも拒否として扱われます。中身を信用しているサーバには `trusted = true` を付けると、プロンプトを省略できます。

**`env` のシークレット。** `${VAR}` は mugen-ai 自身の環境変数から展開されます。トークンは `~/.config/mugen-ai/.env` に置き、`config.toml` 側では `env = { GITHUB_TOKEN = "${GITHUB_TOKEN}" }` と参照するだけにしておけば、キーそのものが設定ファイルに残りません。

</details>

### プロバイダ API キー

`ai/.env.example` (Nix インストールの場合は `$(nix build --no-link --print-out-paths github:tmy7533018/mugen-shell#mugen-ai)/share/mugen-ai/.env.example`) を `~/.config/mugen-ai/.env` にコピーして手持ちのキーを埋めるか、次のように直接追記してください:

```sh
cat >> ~/.config/mugen-ai/.env <<'EOF'
ANTHROPIC_API_KEY=sk-ant-...
GEMINI_API_KEY=...
OPENAI_API_KEY=...
EOF
chmod 600 ~/.config/mugen-ai/.env
systemctl --user restart mugen-ai.service
```

値が入っているキーの分だけ、プロバイダが有効になります。`GEMINI_API_KEY` が空のときは `GOOGLE_API_KEY` も読まれます。

### シェル操作に向くモデル

Yura がチャットだけでなく実際にシェル操作までこなせるかは、モデルの tool-calling 性能で決まります。API 経由の Claude や Gemini が最も安定します。ローカルの Ollama を使うなら、最近の中規模モデルを選んでください。`qwen3:14b` は安定してツールを実行できますし、`qwen3:4b` でも **Thinking** を ON にすれば動きます。ツール非対応のモデルを選んだ場合は、自動的にチャット専用モードに切り替わります。

### リスナーアドレス

サーバは TCP ポートを開かず、`$XDG_RUNTIME_DIR/mugen-ai/mugen-ai.sock` の unix ソケットで待ち受けます。そのため、同じマシンの他のユーザからはアクセスできません。場所を変えたい場合は、`~/.config/mugen-ai/.env` に `MUGEN_AI_SOCKET` を書いてサービスを再起動してください。シェルも音声デーモンも同じ変数を参照するので、三者の指す先がずれることはありません。

会話とメッセージは SQLite (`~/.local/state/mugen-ai/history.db`) に保存されます。ターミナルから話したい場合は `mugen-ai chat` を使ってください。

---

## 音声入力 (オプション)

Yura は音声での入出力にも対応しています。`Super + Z` を長押ししながら話しかけると、返事が読み上げられます。

```
mic → silero VAD → whisper.cpp → mugen-ai /chat → TTS (VOICEVOX / AivisSpeech / Piper)
```

前提として mugen-ai が動いている必要があります。有効化は home-manager モジュール (Path A・B 共通) の 1 行だけで、必要なものは一式まとめて入ります:

```nix
programs.mugen-shell.voice.enable = true;
# programs.mugen-shell.voice.aivis.enable = false;      # AivisSpeech エンジンを外す場合
```

必要なファイルはすべて Nix store から来るので、リポジトリの clone も `nix-ld` も不要です。ただし AivisSpeech エンジンだけは、初回起動時に既定の音声モデル (約 900 MB) をダウンロードします。ネットワークが必要なのはこの一度だけです。

読み上げは既定でこのエンジンを使うため、Settings で声を選ばなくても音は出ます。VOICEVOX は Nix 側の構成に含まれていませんが、自分で立てれば同じピッカーに並びます。

エンジンは常駐させると約 2.6 GB 使うため、必要になったときだけ起動する仕組みになっています。合成が `voice.idleStopMin` 分 (既定 10 分。`settings.json` を直接編集して変更) 途切れると自動で停止します。自分で管理したい場合は、unit の `YURA_TTS_SERVICE=` を空にしてください。

日常的な調整は **Settings → Voice input** から行えます。声の選択、話速、チャイム音まで一通り揃っています。デーモンが `settings.json` を監視しているので、変更は再起動なしで次の発話から反映されます。

マイクは、ターンが始まるまで開きません。ターンを始めるのは `Super + Z` の長押しか、どちらの Yura UI にもある push-to-talk ボタンです。

<details>
<summary><b>Yura の音声を他の言語で使う</b></summary>

エンジンに縛られるのは返事の声だけで、それ以外はもともと多言語に対応しています:

- **TTS**: ローカル音声は sherpa-onnx がプロセス内で再生するため、`piper` バイナリのインストールは不要です。[sherpa-onnx の TTS モデル配布](https://github.com/k2-fsa/sherpa-onnx/releases/tag/tts-models) からモデルを取得し (Piper/VITS でも Kokoro でも動きます)、`.onnx`・`tokens.txt`・`espeak-ng-data/` を含む**ディレクトリごと** `~/.local/share/mugen-shell/tts/` に展開してください。置き場所は `YURA_TTS_MODELS` で変更できます。展開したディレクトリはそのまま Settings のピッカーに並ぶので、この構成なら VOICEVOX は無くても構いません。Nix 経路には `vits-piper-en_US-lessac-high` が最初から含まれています。
- **STT**: 認識する言語は Settings → Yura → Personality の Language に従います。Auto (既定) なら発話ごとに whisper が判定し、言語を決め打ちするとそれで固定されます。whisper は約 100 言語をカバーします。
- **返事の言語**: Settings → Yura → Personality の language で指定します。

**環境変数** (unit か drop-in で設定): `YURA_SILERO_VAD`、`YURA_TTS` (`<engine>:<style-id>`)、`YURA_VOICEVOX_SPEAKER`、`YURA_VOICE_LANG`、`YURA_VOICE_SPEED`、`YURA_WHISPER_URL`、`YURA_VOICEVOX_URL`、`YURA_AIVIS_URL`。Settings にも同じ項目があるものは、シェルが保存した時点で `settings.json` が優先されます。

</details>

<details>
<summary><b>ヘッドホンじゃなくてスピーカー派?</b>: エコーキャンセル</summary>

PipeWire の WebRTC エコーキャンセルを使うと、スピーカーから出ている音がマイク入力から差し引かれます。これにより、読み上げの最中に話しかけても認識が通ります。

`~/.config/pipewire/pipewire.conf.d/99-yura-echo-cancel.conf` に次を置いてください。`target.object` は、`wpctl inspect` で調べた自分のマイクの `node.name` に書き換えます。PipeWire を再起動したら、`wpctl set-default <id>` で新しいソースを既定の入力にします:

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

</details>

---

## キーバインド

シェルが動いている状態で `Super + /` を押すと、キーバインドの一覧が表示されます。ここでは、最初に知っておくと便利なものだけ挙げます。

| キー | 動作 |
|---|---|
| `Super + R` | アプリランチャー |
| `Super + Y` / `Super + Shift + Y` | Yura (バーの入力行 / コーナーパネル) |
| `Super + ,` | Settings |
| `Super + Enter` | ターミナル |
| `Super + Backspace` | アクティブなウィンドウを閉じる |
| `Super + 1-9` / `Super + 0` | ワークスペース 1-10 へ切替 |
| `Super + hjkl` | フォーカス移動 (vim 風) |
| `Super + Z` | 長押しで Yura に話しかける |
| `Print` / `Super + F12` | 範囲スクリーンショット、クリップボードへコピー |

メディアキー、マイク、輝度キーは他の環境と同じように効きます。定義はすべて `system/hypr/configs/keybinds.lua` にあります。

---

## ランタイムデータの置き場所

設定・状態・キャッシュ・ユーザメディアは、すべてリポジトリの外の XDG ディレクトリに置かれます。

| 場所 | 中身 |
|---|---|
| `$XDG_CONFIG_HOME/mugen-shell/settings.json` | 保存されたユーザ設定 |
| `$XDG_STATE_HOME/mugen-shell/{theme-mode,idle-inhibitor.json}` | トグル状態 |
| `$XDG_CACHE_HOME/mugen-shell/{colors.json,wallp/,wallpaper-thumbs/}` | 再生成できるキャッシュ |
| `$XDG_DATA_HOME/mugen-shell/{wallpapers/,sounds/,timer-sounds/,tts/}` | ユーザが置くメディア |
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
- [Silero VAD](https://github.com/snakers4/silero-vad): 音声区間検出
- [whisper.cpp](https://github.com/ggml-org/whisper.cpp): 音声認識
- [VOICEVOX](https://voicevox.hiroshiba.jp/): TTS エンジン
- [AivisSpeech Engine](https://github.com/Aivis-Project/AivisSpeech-Engine): VOICEVOX 互換の Style-Bert-VITS2 系 TTS。モデルは [AivisHub](https://hub.aivis-project.com/) から
- [Piper](https://github.com/rhasspy/piper): 日本語以外の声向け TTS
- [LRO WAC の月面モザイク](https://commons.wikimedia.org/wiki/File:Moon_nearside_LRO.jpg): ロック画面の月。NASA/GSFC/Arizona State University、パブリックドメイン（明るさを調整して 320px に縮小したものを収録）