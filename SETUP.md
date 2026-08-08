<p align="right"><a href="SETUP.en.md">English</a> | <b>日本語</b></p>

# mugen-shell — セットアップガイド

## ランタイムデータ

すべてリポジトリ外、XDG ディレクトリ配下に置かれます。

| 場所 | 中身 |
|---|---|
| `$XDG_CONFIG_HOME/mugen-shell/settings.json` | 保存されたユーザ設定 |
| `$XDG_STATE_HOME/mugen-shell/{theme-mode,idle-inhibitor.json}` | トグル状態 |
| `$XDG_CACHE_HOME/mugen-shell/{colors.json,wallp/,wallpaper-thumbs/}` | 再生成できるキャッシュ |
| `$XDG_DATA_HOME/mugen-shell/{wallpapers/,sounds/,timer-sounds/,tts/}` | ユーザが置くメディア |
| `$XDG_PICTURES_DIR/mugen-screenshots/` | キャプチャしたスクリーンショット |

通知音のドロップダウンは Settings を開くたびに再スキャンします。音をすぐ鳴らしたいときは:

```bash
mkdir -p ~/.local/share/mugen-shell/sounds && cp /usr/share/sounds/freedesktop/stereo/{bell,message,message-new-instant}.oga ~/.local/share/mugen-shell/sounds/
# NixOS の場合 (/usr/share が無いので sound-theme-freedesktop を入れてから):
mkdir -p ~/.local/share/mugen-shell/sounds && cp /run/current-system/sw/share/sounds/freedesktop/stereo/{bell,message,message-new-instant}.oga ~/.local/share/mugen-shell/sounds/
```

---

## インストール

インストール経路は 3 つあります。環境に合うものを開いてください。

<details>
<summary><b>Path A — NixOS</b></summary>

NixOS では、アンブレラ flake (`?dir=nixos`) を使います:

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

そのあと `nixos-rebuild switch --flake /etc/nixos#mybox`。

**fcitx5 で日本語入力 (他言語も)**

`fcitx5Addons` を設定すると、モジュールがログインセッションごとに IME を登録します。NixOS では fcitx5 を自分で `systemPackages` に入れても**動きません**。

```nix
programs.mugen-shell.fcitx5Addons = with pkgs; [ fcitx5-mozc ];
# または: [ fcitx5-rime ]    中国語
# または: [ fcitx5-hangul ]  韓国語
```

</details>

<details>
<summary><b>Path B — Arch や NixOS 以外の Linux + Nix</b></summary>

リポジトリ root の user レベル flake を使い、Wayland とコンポジタ系は pacman 側で入れます。

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

`includeSystemDeps = true` にすると、このリストのうちユーザ空間側のツール (Quickshell、hypridle、awww、matugen、kitty など) を Nix 側で抱えられます。Hyprland 本体・システムサービス・テーマ類はどちらにせよ pacman のままです。

ディスプレイマネージャやログインセッションへの Hyprland の組み込み (TTY からの `Hyprland`、sddm の session entry など) は自分でやってください。

アクティベートは同梱の `system/hypr/` を `~/.config/hypr/` にコピーします。`cava` / `kitty` / `matugen` / `fastfetch` と `starship.toml` も同様です。どれもそのパスがまだ無いときだけなので、既にある設定には触りません。既に自前の Hyprland 設定があるなら、autostart は自分で足してください。この行がないと `quickshell -c mugen-shell` が走りません:

```hypr
source = ~/.config/hypr/configs/mugen-shell.conf
```

このファイルはパッケージ出力から一度コピーしておきます: `$(nix path-info .#mugen-shell)/hypr/configs/mugen-shell.conf`。

**自前の config が Lua なら**、同じ行の Lua 版はこれです:

```lua
dofile(os.getenv("HOME") .. "/.config/hypr/configs/mugen-shell.lua")
```

config 言語の切り替えには relog が必要で、`hyprctl reload` では切り替わりません。

NixOS モジュールが自動でやってくれる、Arch 固有のハマりどころが 2 つあります:

- **`hyprlock` の PAM ファイル。** Arch はデフォルトで同梱していないので、`hyprlock` が画面ロック解除を拒否します。upstream のサンプルを `/etc/pam.d/hyprlock` に置いてください:
  ```bash
  sudo curl -fsSL https://raw.githubusercontent.com/hyprwm/hyprlock/main/pam/hyprlock \
    -o /etc/pam.d/hyprlock
  ```
- **fcitx5 の環境変数。** 同梱の `system/hypr/configs/ime.conf` が Hyprland セッション向けに `XMODIFIERS` をエクスポートします。コンポジタ外から起動するもの向けには `/etc/environment` にも書いておきます。`GTK_IM_MODULE` / `QT_IM_MODULE` / `SDL_IM_MODULE` は**設定しないでください** — 壊れた旧経路に引き戻されます。

</details>

<details>
<summary><b>Path C — Nix なし</b></summary>

```bash
git clone https://github.com/tmy7533018/mugen-shell.git ~/mugen-shell
cd ~/mugen-shell
make install
```

設定を checkout に symlink したあと、mugen-ai をビルドして有効化します — この経路だけ Go が要ります。システムスタックは Path B と同じ `yay -S` リスト。`make uninstall` で外せます。`~/.config/hypr`・`kitty`・`cava`・`matugen`・`fastfetch` と `starship.toml` は clone への symlink になるので、あとから設定をいじるとその差分が `git status` に出ます。

</details>

---

## mugen-ai の設定

設定は **Settings → AI / Yura** に全部あります — personality、プロバイダの状態、モデル、tool categories、allowed apps、パネルの左右。保存すると裏でサービスの再起動までやってくれます。手で書きたいときは同じページの **Edit toml** から `~/.config/mugen-ai/config.toml` を `$EDITOR` で開けます。

既定値で 2 つだけ知っておくと楽です。**Allowed apps は空から始まる**ので、そこでアプリを選ぶまで Yura は何も起動できません。それと `mugen-ai.service` が動いていないと、バーはチャット UI の代わりにインストール案内を出します。

注釈付きのフル版テンプレートは `ai/config.toml.example` (Nix インストールなら `$(nix path-info .#mugen-ai)/share/mugen-ai/config.toml.example`) にあります。

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
# Empty = Yura cannot launch anything. The Allowed apps picker fills this.
allowed_commands = ["firefox", "kitty", "code"]

[tools]
# Categories to hide from Yura (audio / music / brightness / theme /
# wallpaper / notification / timer / calendar / panel / app / memory /
# weather). Disabling "memory" also hides saved memories.
disabled_categories = []
```

- `[provider.ollama]`: ローカル Ollama は `http://localhost:11434` で最初から有効です。デーモンが別の場所にあるときだけ `host` を上書きしてください。
- `[provider.google].models` には `GEMINI_API_KEY`、`[provider.anthropic].models` には `ANTHROPIC_API_KEY` が要ります (後者は `models` を省略すると `claude-haiku-4-5` になります)。
- `[provider.openai]`: OpenAI 互換プロバイダ用。`OPENAI_API_KEY` が入っているか、`base_url` がローカルサーバを指していれば有効です。`models` を空にするとバックエンドの `/v1/models` に聞きに行きます。
- `[tools.app_launch].allowed_commands`: マッチはバイナリの basename です。`$PATH` 外のバイナリは `.desktop` 経由で解決され、Flatpak アプリは `flatpak` 自体を入れておけば display name で拾えます。
- `[tools].disabled_categories`: MCP サーバ名も書けて、その場合はそのサーバ全体が無効になります。

</details>

<details>
<summary><b>MCP サーバ</b> — 外部ツールを取り込む</summary>

mugen-ai は外部の [Model Context Protocol](https://modelcontextprotocol.io) サーバ (memory、filesystem、GitHub など) からツールを引っ張ってきて、組み込みのシェルツールと並べて Yura に渡せます。サーバごとに `[mcp.servers.<name>]` ブロックを 1 つ書きます:

```toml
[mcp.servers.memory]
command = "npx"
args = ["-y", "@modelcontextprotocol/server-memory"]
# env = { MEMORY_FILE_PATH = "/home/you/.local/state/mugen-ai/memory.json" }
# disabled = false   # エントリは残したまま、起動だけスキップ
# trusted = false    # true にすると、このサーバのツールでは承認プロンプトを省略
```

`command` はサービスの `PATH` 上にある必要があります。mugen-ai はサーバランタイムを同梱していないので、`npx` 系なら Node.js、`uvx` 系なら [uv](https://docs.astral.sh/uv/) が要ります。Nix ユーザは `home.packages` に足しておいてください。`command` の代わりに `url = "https://example.com/mcp"` を書けばリモートの Streamable HTTP サーバに繋がるので、その場合はローカルのランタイムが要りません。

ツールは `<name>__<tool>` プレフィックス付きで取り込まれるため、サーバ名は小文字短めでアンダースコアなしにしてください。設定を編集したあとは `mugen-ai.service` を再起動すると反映されます。

**承認プロンプト。** 取り返しのつかない変更を起こしうるツールは、Yura が呼んだ時点で止まり、チャット UI に Approve / Deny プロンプトが出ます。Deny、タイムアウト、チャットを閉じた、はすべて拒否扱いです。完全に信頼できるサーバには `trusted = true` を付けるとプロンプトを飛ばせます。

**`env` のシークレット。** `${VAR}` 参照は mugen-ai 自身の環境から解決されます。トークンは `~/.config/mugen-ai/.env` に置いて `env = { GITHUB_TOKEN = "${GITHUB_TOKEN}" }` と書けば、`config.toml` に残らずに済みます。

</details>

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

値が入っているキーだけがそのプロバイダを有効化します。

### シェル操作に向くモデル

「ちゃんと動かせるか」(チャットするだけでなく) はモデルの tool-calling 性能に左右されます。ホスト API モデル (Claude、Gemini) が一番安定です。ローカル Ollama なら最近の中規模モデル — `qwen3:14b` は安定してツールを動かせますし、`qwen3:4b` も **Thinking** を ON にすれば動きます。ツール未対応のモデルは自動でチャット専用にフォールバックします。

### リスナーアドレス

サーバは TCP ポートではなく `$XDG_RUNTIME_DIR/mugen-ai/mugen-ai.sock` の unix ソケットで listen します。同じマシンの他ユーザーからは到達できません。場所を変えたいときは `~/.config/mugen-ai/.env` に `MUGEN_AI_SOCKET` を書いてサービスを再起動してください。シェルと音声デーモンも同じ変数を読むので、三者がずれることはありません。

会話とメッセージは SQLite (`~/.local/state/mugen-ai/history.db`) に保存されます。ターミナル用途は `mugen-ai chat`。

---

## 音声入力 (オプション)

Yura は声でも操作できます。`Super + Z` を押しながら話すと、返答が読み上げられます。

```
mic → silero VAD → whisper.cpp → mugen-ai /chat → TTS (VOICEVOX / AivisSpeech / Piper)
```

デフォルト構成は日本語ファーストですが、日本語専用ではありません (後述の「他言語で使う」参照)。セットアップ経路は 2 つ。どちらも mugen-ai が動いている前提です。

<details>
<summary><b>Nix 経路</b> — 一行で全部入る</summary>

home-manager モジュール (Path A・B) がスタック一式をパッケージしています:

```nix
programs.mugen-shell.voice.enable = true;
# programs.mugen-shell.voice.aivis.enable = false;      # AivisSpeech エンジンを外す場合
```

必要なものは全部 store から来るので clone は不要ですし、`nix-ld` も要りません。AivisSpeech エンジンだけは初回起動でデフォルト音声モデル (約 900 MB) を取りに行くので、一度ネットワークが要ります。返答の読み上げは自動でここに向くため、Settings で声を選ぶ前から音が出ます。VOICEVOX は Nix 配線に含まれないので、Aivis と並べたければ下の手順 3 で手動追加してください。

エンジンは必要になった時に起動し (常駐で ~2.6GB 使うため)、合成が `voice.idleStopMin` 分 (既定 10、`settings.json` を直接編集) 途切れたら止まります。自分で管理したい場合は unit の `YURA_TTS_SERVICE=` を空にしてください。

下の手動セットアップから移行する場合は、切り替える前に `~/.config/systemd/user/{yura-voice,aivisspeech-engine}.service` の symlink を消してください。home-manager が同じ名前で unit を書くので、管理外のファイルがあると activation が失敗します。

</details>

<details>
<summary><b>手動セットアップ</b> — venv・whisper.cpp・TTS を自分で</summary>

Nix を使わない環境向けです。`make install` も音声はカバーしていないので、こちらを使います。NixOS でこのルートを通すには `programs.nix-ld.enable = true` が必要です (pip の wheel と AivisSpeech エンジンのプレビルドが FHS 前提のバイナリなため):

1. **デーモン用の Python venv** と、unit が指す VAD モデル:
   ```bash
   cd ~/mugen-shell/voice
   python -m venv .venv
   .venv/bin/pip install onnxruntime numpy requests sounddevice sherpa-onnx
   mkdir -p ~/.local/share/mugen-shell
   curl -Lo ~/.local/share/mugen-shell/silero_vad.onnx \
     https://github.com/dscripka/openWakeWord/releases/download/v0.5.1/silero_vad.onnx
   ```
2. **whisper.cpp** をローカルビルドして、サーババイナリを `~/.local/src/whisper.cpp/build/bin/whisper-server`、モデルを `~/.local/share/whisper/ggml-large-v3-turbo.bin` に配置 (`YURA_WHISPER_BIN` / `YURA_WHISPER_MODEL` で上書き可)。サーバの起動と監視はデーモンがやります。
3. **VOICEVOX engine** を `127.0.0.1:50021` で待受。同梱の `voicevox-engine.service` は nixpkgs の `voicevox-engine` が `~/.nix-profile/bin` にある前提なので、他の入れ方をした場合は `ExecStart` を調整してください。[AivisSpeech Engine](https://github.com/Aivis-Project/AivisSpeech-Engine) は VOICEVOX 互換のもっと自然な声が使える選択肢で、`~/.local/opt/aivisspeech-engine` に展開すると (ポート `10101`、unit 同梱) 同じピッカーに並びます。
4. **systemd unit**:
   ```bash
   ln -s ~/mugen-shell/system/systemd/user/{yura-voice,voicevox-engine,aivisspeech-engine}.service ~/.config/systemd/user/
   # graphical-session.target refuses a manual start, so the shell brings
   # up this one instead; without it nothing bound to the session starts.
   ln -s ~/mugen-shell/system/systemd/user/mugen-shell-session.target ~/.config/systemd/user/
   systemctl --user daemon-reload
   # 使う声の TTS エンジンだけ enable する
   systemctl --user enable --now voicevox-engine.service yura-voice.service
   ```

</details>

実行中の制御は **Settings → Voice input** から — ボイスピッカー、話速、チャイム音、その他ひととおり揃っています。どれも次の発話から反映されます。デーモンが `settings.json` を監視しているので、再起動は要りません。

マイクはターンが始まるまで開きません。ターンは `Super + Z` の長押しか、どちらの Yura UI にもある push-to-talk ボタンから始めます。

<details>
<summary><b>Yura の音声を他の言語で使う</b></summary>

エンジン依存なのは返答の声だけで、それ以外はもともと多言語対応です:

- **TTS**: ローカルのボイスは sherpa-onnx でインプロセス実行されるので、`piper` バイナリを入れる必要はありません。[sherpa-onnx の TTS モデル配布](https://github.com/k2-fsa/sherpa-onnx/releases/tag/tts-models) からモデルを取ってきて (Piper/VITS でも Kokoro でも動きます)、`.onnx` と `tokens.txt`・`espeak-ng-data/` を含む**モデルディレクトリごと** `~/.local/share/mugen-shell/tts/` に展開します。`YURA_TTS_MODELS` で別の場所も指せます。展開したディレクトリはそのまま Settings のボイスピッカーに並び、この場合 VOICEVOX は無くても動きます。Nix 経路には `vits-piper-en_US-lessac-high` が同梱済みです。
- **STT**: 認識言語は Settings → AI / Yura → Personality の Language に従います。Auto (既定) なら発話ごとに whisper が判定し、言語を固定するとそれに固定されます。whisper は約 100 言語をカバーします。
- **返答の言語**: Settings → AI / Yura → Personality の language で指定します。

**環境変数ノブ** (unit か drop-in で設定): `YURA_SILERO_VAD`、`YURA_TTS` (`<engine>:<style-id>`)、`YURA_VOICEVOX_SPEAKER`、`YURA_VOICE_LANG`、`YURA_VOICE_SPEED`、`YURA_WHISPER_URL`、`YURA_VOICEVOX_URL`、`YURA_AIVIS_URL`。Settings 側にもある項目は、シェルが保存した時点で `settings.json` が勝ちます。

</details>

<details>
<summary><b>ヘッドホンじゃなくてスピーカー派?</b> — エコーキャンセル</summary>

PipeWire の WebRTC エコーキャンセルがスピーカーの再生内容をマイク入力から差し引くので、返答の再生中に話しかけても通ります。`~/.config/pipewire/pipewire.conf.d/99-yura-echo-cancel.conf` に以下を置いて (`target.object` は `wpctl inspect` で調べた自分のマイクの `node.name` に)、PipeWire を再起動後、`wpctl set-default <id>` で新しいソースをデフォルト入力にします:

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

起動中のシェルで `Super + /` を押すと全一覧が出ます。その前に知っておくと便利なものだけ挙げます。

| キー | 動作 |
|---|---|
| `Super + R` | アプリランチャー |
| `Super + Y` / `Super + Shift + Y` | Yura — バーの入力行 / コーナーパネル |
| `Super + ,` | Settings |
| `Super + Enter` | ターミナル |
| `Super + Backspace` | アクティブなウィンドウを閉じる |
| `Super + 1-9` / `Super + 0` | ワークスペース 1-10 へ切替 |
| `Super + hjkl` | フォーカス移動 (vim 風) |
| `Super + Z` | 長押しで Yura に話しかける |
| `Print` / `Super + F12` | 範囲スクリーンショット、クリップボードへコピー |

メディアキー、マイク、輝度キーは他と同じように効きます。定義はすべて `system/hypr/hyprland.lua` にあります。

---

## クレジット

- [Hyprland](https://hypr.land/) — Wayland コンポジタ
- [Quickshell](https://quickshell.outfoxxed.me/) — シェルフレームワーク
- [Matugen](https://github.com/InioX/matugen) — 壁紙からのカラー生成
- [Cava](https://github.com/karlstav/cava) — 音声ビジュアライザ
- [Kitty](https://sw.kovidgoyal.net/kitty/) — ターミナルエミュレータ
- [playerctl](https://github.com/altdesktop/playerctl) — メディアプレイヤー制御
- [grim](https://sr.ht/~emersion/grim/) / [slurp](https://github.com/emersion/slurp) — スクリーンショットツール
- [cliphist](https://github.com/sentriz/cliphist) — クリップボード履歴
- [Silero VAD](https://github.com/snakers4/silero-vad) — 音声区間検出
- [whisper.cpp](https://github.com/ggml-org/whisper.cpp) — 音声認識
- [VOICEVOX](https://voicevox.hiroshiba.jp/) — TTS エンジン
- [AivisSpeech Engine](https://github.com/Aivis-Project/AivisSpeech-Engine) — VOICEVOX 互換の Style-Bert-VITS2 系 TTS。モデルは [AivisHub](https://hub.aivis-project.com/) から
- [Piper](https://github.com/rhasspy/piper) — 日本語以外の声向け TTS
- [LRO WAC の月面モザイク](https://commons.wikimedia.org/wiki/File:Moon_nearside_LRO.jpg) — ロック画面の月。NASA/GSFC/Arizona State University、パブリックドメイン（明るさを調整して 320px に縮小したものを収録）
