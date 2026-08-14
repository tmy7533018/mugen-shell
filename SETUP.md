<p align="right"><a href="SETUP.en.md">English</a> | <b>日本語</b></p>

# mugen-shell: セットアップガイド

## ランタイムデータ

設定も状態もキャッシュも、リポジトリの外の XDG ディレクトリに置かれます。

| 場所 | 中身 |
|---|---|
| `$XDG_CONFIG_HOME/mugen-shell/settings.json` | 保存されたユーザ設定 |
| `$XDG_STATE_HOME/mugen-shell/{theme-mode,idle-inhibitor.json}` | トグル状態 |
| `$XDG_CACHE_HOME/mugen-shell/{colors.json,wallp/,wallpaper-thumbs/}` | 再生成できるキャッシュ |
| `$XDG_DATA_HOME/mugen-shell/{wallpapers/,sounds/,timer-sounds/,tts/}` | ユーザが置くメディア |
| `$XDG_PICTURES_DIR/mugen-screenshots/` | キャプチャしたスクリーンショット |

通知音のドロップダウンは、Settings を開くたびに中身を読み直します。とりあえず鳴らしてみたいなら、何個か放り込んでおけばそのまま選べます:

```bash
mkdir -p ~/.local/share/mugen-shell/sounds && cp /usr/share/sounds/freedesktop/stereo/{bell,message,message-new-instant}.oga ~/.local/share/mugen-shell/sounds/
# NixOS の場合 (/usr/share が無いので sound-theme-freedesktop を入れてから):
mkdir -p ~/.local/share/mugen-shell/sounds && cp /run/current-system/sw/share/sounds/freedesktop/stereo/{bell,message,message-new-instant}.oga ~/.local/share/mugen-shell/sounds/
```

---

## インストール

インストールの経路は 3 つです。自分の環境に合うものを開いてください。どれも **Hyprland 0.55 以上**が前提になります。

<details>
<summary><b>Path A: NixOS</b></summary>

NixOS なら、リポジトリ root の flake だけで済みます:

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

そのあと `nixos-rebuild switch --flake /etc/nixos#mybox`。

**fcitx5 で日本語入力 (他言語も)**

`fcitx5Addons` に書いておくと、ログインセッションごとに IME が登録されます。NixOS では、fcitx5 を自分で `systemPackages` に入れるやり方だと**動きません**。

```nix
programs.mugen-shell.fcitx5Addons = with pkgs; [ fcitx5-mozc ];
# または: [ fcitx5-rime ]    中国語
# または: [ fcitx5-hangul ]  韓国語
```

</details>

<details>
<summary><b>Path B: Arch や NixOS 以外の Linux + Nix</b></summary>

リポジトリ root の flake を home-manager (ユーザ単位) から使います。Wayland まわりとコンポジタは pacman 側で入れてください。

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

最初の switch の前に、システム側を pacman で揃えておきます:

```bash
yay -S hyprland quickshell hypridle zsh kitty starship libnotify \
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

`includeSystemDeps = true` にすれば、このうちユーザ空間のツール (Quickshell、hypridle、awww、matugen、kitty など) は Nix 側から入ります。Hyprland 本体とシステムサービス、テーマ類は、どちらにしても pacman のままです。

Hyprland をどう起動するか (TTY から `Hyprland` を叩く、sddm にセッションを登録する、など) は自分で用意してください。

アクティベートすると、同梱の `system/hypr/` が `~/.config/hypr/` にコピーされます。`cava`・`kitty`・`matugen`・`fastfetch` と `starship.toml` も同じです。コピーされるのはその場所がまだ無いときだけなので、すでにある設定が上書きされることはありません。

自前の Hyprland 設定を持っている人には autostart が入りません。次の 1 行を自分で足してください。これが無いと `quickshell -c mugen-shell` が起動しません:

```lua
dofile(os.getenv("HOME") .. "/.config/hypr/configs/mugen-shell.lua")
```

このファイルはパッケージ出力から一度コピーしておきます: `$(nix path-info .#mugen-shell)/hypr/configs/mugen-shell.lua`。

**自前の config がまだ hyprlang (`.conf`) なら**、同じ行の hyprlang 版はこれです:

```hypr
source = ~/.config/hypr/configs/mugen-shell.conf
```

Arch では自分でやる必要があるものが 2 つあります:

- **ロック画面の PAM ファイル。** これが無いとロック画面が認証できず、`ext-session-lock`
  がセッションを掴んだままになります。先に作っておいてください:
  ```bash
  printf '#%%PAM-1.0\nauth include system-auth\n' | sudo tee /etc/pam.d/mugen-lock
  ```
- **fcitx5 の環境変数。** Hyprland のセッション内は、同梱の `system/hypr/hyprland.lua` が `XMODIFIERS` を出してくれます。コンポジタの外から起動するアプリのために、`/etc/environment` にも同じものを書いておいてください。

</details>

---

## mugen-ai の設定

設定は **Settings → Yura** にまとまっています。personality、プロバイダの状態、モデル、tool categories、allowed apps、パネルの左右まで、ここから触れます。保存すると、裏でサービスの再起動までやってくれます。手で書きたいときは、同じ画面の **Edit toml** から `~/.config/mugen-ai/config.toml` を `$EDITOR` で開けます。

既定のままだと引っかかるところが 3 つあります。まず、**モデルは同梱していません**。Ollama を入れて 1 つ pull する (`ollama pull qwen3:4b` など) か、`~/.config/mugen-ai/.env` に API キーを置くまで、入力欄は "No model yet" のままです。次に、**Allowed apps も空から始まります**。ここでアプリを選ぶまで、Yura は何も起動できません。最後に、`mugen-ai.service` 自体が止まっているときは、バーが起動用のコマンドを出します。

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

- `[provider.ollama]`: 設定は最初から `http://localhost:11434` を見に行きますが、**Ollama 本体はどのインストール経路にも含まれません**。自分で入れてモデルを pull してください。デーモンが別の場所にあるときだけ `host` を上書きします。
- `[provider.google].models` には `GEMINI_API_KEY`、`[provider.anthropic].models` には `ANTHROPIC_API_KEY` が要ります (後者は `models` を省略すると `claude-haiku-4-5` になります)。
- `[provider.openai]`: OpenAI 互換プロバイダ用。`OPENAI_API_KEY` が入っているか、`base_url` がローカルサーバを指していれば有効です。`models` を空にするとバックエンドの `/v1/models` に聞きに行きます。
- `[tools.app_launch].allowed_commands`: 照合はバイナリの basename で行います。`$PATH` の外にあるものは `.desktop` から解決され、Flatpak アプリは `flatpak` さえ入っていれば表示名で拾えます。
- `[tools].disabled_categories`: MCP のサーバ名も書けます。書くと、そのサーバごと無効になります。

</details>

<details>
<summary><b>MCP サーバ</b>: 外部ツールを取り込む</summary>

mugen-ai は外部の [Model Context Protocol](https://modelcontextprotocol.io) サーバ (memory、filesystem、GitHub など) からツールを引っ張ってきて、組み込みのシェルツールと並べて Yura に渡せます。サーバごとに `[mcp.servers.<name>]` ブロックを 1 つ書きます:

```toml
[mcp.servers.memory]
command = "npx"
args = ["-y", "@modelcontextprotocol/server-memory"]
# env = { MEMORY_FILE_PATH = "/home/you/.local/state/mugen-ai/memory.json" }
# disabled = false   # エントリは残したまま、起動だけスキップ
# trusted = false    # true にすると、このサーバのツールでは承認プロンプトを省略
```

`command` は、サービスの `PATH` から見える場所に無いといけません。mugen-ai はサーバのランタイムを同梱していないので、`npx` 系なら Node.js、`uvx` 系なら [uv](https://docs.astral.sh/uv/) を別に入れてください。Nix なら `home.packages` に足しておきます。

`command` の代わりに `url = "https://example.com/mcp"` と書けば、リモートの Streamable HTTP サーバに繋がります。この場合、ローカルのランタイムは要りません。

ツールは `<name>__<tool>` という名前で取り込まれます。そのため、サーバ名は短く・小文字で・アンダースコア無しにしてください。設定を書き換えたら、`mugen-ai.service` を再起動すると反映されます。

**承認プロンプト。** 取り返しのつかない変更をしうるツールは、Yura が呼んだ時点でいったん止まります。チャット UI に Approve / Deny が出るので、そこで決めてください。Deny を押す・タイムアウトする・チャットを閉じる、のいずれも拒否として扱われます。中身を信用しているサーバなら、`trusted = true` を付けてプロンプトを省けます。

**`env` のシークレット。** `${VAR}` は mugen-ai 自身の環境から展開されます。トークンは `~/.config/mugen-ai/.env` に置き、`config.toml` 側には `env = { GITHUB_TOKEN = "${GITHUB_TOKEN}" }` と書いておけば、キーそのものは設定ファイルに残りません。

</details>

### プロバイダ API キー

`ai/.env.example` (Nix インストールなら `$(nix path-info .#mugen-ai)/share/mugen-ai/.env.example`) を `~/.config/mugen-ai/.env` にコピーして手持ちのキーを埋めるか、次のように直接足してください:

```sh
cat >> ~/.config/mugen-ai/.env <<'EOF'
ANTHROPIC_API_KEY=sk-ant-...
GEMINI_API_KEY=...
OPENAI_API_KEY=...
EOF
chmod 600 ~/.config/mugen-ai/.env
systemctl --user restart mugen-ai.service
```

値が入っているキーのぶんだけ、プロバイダが有効になります。

### シェル操作に向くモデル

チャットするだけでなく実際にシェルを動かせるかどうかは、モデルの tool-calling 性能で決まります。いちばん安定するのは API 経由の Claude や Gemini です。ローカルの Ollama なら、最近の中規模モデルを選んでください。`qwen3:14b` は安定してツールを動かせますし、`qwen3:4b` でも **Thinking** を ON にすれば動きます。ツールに対応していないモデルを選んだときは、自動でチャット専用に切り替わります。

### リスナーアドレス

サーバは TCP ポートを開かず、`$XDG_RUNTIME_DIR/mugen-ai/mugen-ai.sock` の unix ソケットで待ち受けます。同じマシンの他のユーザーからは届きません。場所を変えたいときは、`~/.config/mugen-ai/.env` に `MUGEN_AI_SOCKET` を書いてサービスを再起動してください。シェルも音声デーモンも同じ変数を見るので、三者の指す先がずれることはありません。

会話とメッセージは SQLite (`~/.local/state/mugen-ai/history.db`) に溜まります。ターミナルから話したいときは `mugen-ai chat` です。

---

## 音声入力 (オプション)

Yura は音声の入出力も対応しています。`Super + Z` を押しながら話しかけると、返事が読み上げられます。

```
mic → silero VAD → whisper.cpp → mugen-ai /chat → TTS (VOICEVOX / AivisSpeech / Piper)
```

mugen-ai が動いていることが前提です。有効化は home-manager モジュール (Path A・B) の 1 行で、必要なものは一式まとめて入ります:

```nix
programs.mugen-shell.voice.enable = true;
# programs.mugen-shell.voice.aivis.enable = false;      # AivisSpeech エンジンを外す場合
```

必要なものは全部 store から来るので、clone も `nix-ld` も要りません。ただし AivisSpeech エンジンだけは、初回起動で既定の音声モデル (約 900 MB) を取りに行きます。ここで一度だけネットワークが必要です。

読み上げは最初からこのエンジンに向くので、Settings で声を選ばなくても音は出ます。VOICEVOX は Nix 側の配線に入っていません。自分で立てれば、同じピッカーに並びます。

エンジンは常駐させると ~2.6GB 使うので、必要になった時だけ起動します。合成が `voice.idleStopMin` 分 (既定 10。`settings.json` を直接編集) 途切れたら止まります。自分で管理したいときは、unit の `YURA_TTS_SERVICE=` を空にしてください。

動かしはじめてからの調整は **Settings → Voice input** です。声の選択、話速、チャイム音まで、ひととおり揃っています。変更はどれも次の発話から効きます。デーモンが `settings.json` を見ているので、再起動は要りません。

マイクは、ターンが始まるまで開きません。ターンを始めるのは `Super + Z` の長押しか、どちらの Yura UI にもある push-to-talk ボタンです。

<details>
<summary><b>Yura の音声を他の言語で使う</b></summary>

エンジンに縛られるのは返事の声だけで、それ以外はもともと多言語に対応しています:

- **TTS**: ローカルの声は sherpa-onnx がプロセス内で鳴らすので、`piper` のバイナリを入れる必要はありません。[sherpa-onnx の TTS モデル配布](https://github.com/k2-fsa/sherpa-onnx/releases/tag/tts-models) からモデルを取ってきて (Piper/VITS でも Kokoro でも動きます)、`.onnx` と `tokens.txt`・`espeak-ng-data/` を含む**ディレクトリごと** `~/.local/share/mugen-shell/tts/` に展開してください。置き場所は `YURA_TTS_MODELS` で変えられます。展開したディレクトリはそのまま Settings のピッカーに並ぶので、この場合 VOICEVOX は無くても構いません。Nix 経路には `vits-piper-en_US-lessac-high` が最初から入っています。
- **STT**: 認識する言語は Settings → Yura → Personality の Language に従います。Auto (既定) なら発話ごとに whisper が判定し、言語を決め打ちするとそれで固定されます。whisper は約 100 言語をカバーします。
- **返事の言語**: Settings → Yura → Personality の language で指定します。

**環境変数** (unit か drop-in で設定): `YURA_SILERO_VAD`、`YURA_TTS` (`<engine>:<style-id>`)、`YURA_VOICEVOX_SPEAKER`、`YURA_VOICE_LANG`、`YURA_VOICE_SPEED`、`YURA_WHISPER_URL`、`YURA_VOICEVOX_URL`、`YURA_AIVIS_URL`。Settings にも同じ項目があるものは、シェルが保存した時点で `settings.json` が勝ちます。

</details>

<details>
<summary><b>ヘッドホンじゃなくてスピーカー派?</b>: エコーキャンセル</summary>

PipeWire の WebRTC エコーキャンセルは、スピーカーから出ている音をマイク入力から差し引いてくれます。おかげで、読み上げの最中に話しかけても通ります。

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

シェルが動いている状態で `Super + /` を押すと全部出ます。ここでは、先に知っておくと楽なものだけ挙げます。

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

メディアキー、マイク、輝度キーは他と同じように効きます。定義はすべて `system/hypr/configs/keybinds.lua` にあります。

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
