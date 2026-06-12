<p align="right"><a href="README.md">English</a> | <b>日本語</b></p>

<h1 align="center">
  <img src="shell/assets/branding/mugen-shell_logo.png" width="200" alt="mugen-shell logo" /><br/>
  mugen-shell
</h1>

<p align="center"><i>Quickshell + Hyprland で組んだ、夢幻デスクトップ。</i></p>

https://github.com/user-attachments/assets/2a8fe2e5-ced6-4de1-acda-d7e0493882a6

Hyprland + Quickshell デスクトップ向けの個人 dotfiles を、Nix flake または `make install` で入れられる形にまとめたものです。

ディレクトリ構成、インストール先、依存、キーバインドは [SETUP.ja.md](SETUP.ja.md) を見てください。

---

## 環境

| | |
|---|---|
| OS | Garuda Linux (Arch 系) |
| GPU | AMD Radeon RX 9070 XT |
| WM | Hyprland |
| Shell | Zsh + Starship |
| Terminal | Kitty |
| Desktop Shell | Quickshell |
| Wallpaper | awww / mpvpaper |
| Colors | Matugen (Material You) |

---

## Yura

https://github.com/user-attachments/assets/aba8efb6-d528-42d3-af7b-d85f4b66913e

<sub><i>バーで軽く挨拶した後、コーナーの Yura が壁紙をシャッフル、ライトモードに切替え、ツール呼び出しで Chrome を開きます。</i></sub>

Yura はデスクトップのチャットアシスタント。バーの 1 行入力 (`Super + Y`) と、画面コーナーに張り付くチャットパネル (`Super + Shift + Y`) の 2 か所で使えます。

バックエンドは [`ai/`](ai/) 配下の Go サーバ **mugen-ai**。対応プロバイダ:

- [Ollama](https://ollama.com) 経由のローカルモデル
- Anthropic Claude
- Google Gemini
- OpenAI 互換 API (OpenAI、OpenRouter、LM Studio、vLLM ほか)

mugen-shell と一緒に NixOS / Arch + Nix / `make install` のどれかで入れます。詳細は [SETUP.ja.md](SETUP.ja.md)。Yura まわりの設定 (プロバイダ、Personality、ツール ON/OFF、許可アプリ) は全部 **Settings → AI / Yura** にまとまっています。

### 機能

- バー行: Yura アイコン付きの入力ピル。返信はプレースホルダにそのまま流れてきます。アイコンをクリックすると、同じ会話がコーナーパネルで開きます。
- コーナーパネル (左 or 右、設定で切替): 過去の会話のサイドバーあり。返信が流れている間はインジケータが揺れます。
- バー行とコーナーパネルは同期します。片方で送ったメッセージは、もう一方にもそのまま出ます。
- 会話履歴はディスクに保存されます。サイドバーから過去のチャットを開けて、ホバーで出るゴミ箱で削除できます。
- 会話ごとにモデル固定。各会話は開始時のプロバイダのまま動き、会話中はパネルのドロップダウンも読み取り専用になります。
- アシスタントの返信は Markdown で表示。コードブロックにはホバーで出てくるコピーボタン付き。
- ストリーミング中は停止ボタンが出ます。入力プレースホルダは IME に追従します。
- Personality (名前、トーン、言語、システムプロンプト) は Settings GUI から編集できます。Save & Apply で設定が書き込まれ、裏でバックエンドが再起動します。
- 会話ごとに Thinking トグルあり。各プロバイダの reasoning チャンネル (qwen3 think、Claude extended thinking、Gemini thinkingConfig、OpenAI reasoning_effort) に振り分けられます。未対応モデルでは何も言わずチャット応答に戻ります。
- アプリ起動は厳格な allowlist 方式 (デフォルトは空)。ピッカーでアプリを ON にするまで、Yura は何も起動できません。シェルメタ文字 (`; | & $` 等) は常に弾かれます。
- ツールカテゴリ単位の ON/OFF (audio、music、brightness、theme、wallpaper、notification、timer、calendar、panel、app launcher)。
- 外部 [MCP](https://modelcontextprotocol.io) サーバにも対応。設定したサーバのツールは同じ gated set にマージされ、接続状態は Settings から確認できます。

### チャットからのシェル操作

Yura からのツール呼び出しは `qs ipc call` を経由します。既存の shell manager がそのまま single source of truth として残る形です。可逆な操作はその場で実行。組み込みの破壊的な操作 (通知履歴のクリア、カレンダーイベントの削除) はチャット内で一度確認を取ります。書き込みが入りうる外部 MCP ツールは、UI の Approve / Deny プロンプトを通してから実行されます。

| ドメイン | Yura ができること |
|---|---|
| 音声出力 | 音量の設定 / 取得、ミュート切替 |
| 音声入力 | マイク音量の設定 / 取得、マイクミュート切替 |
| ディスプレイ | 輝度の設定 / 取得 |
| テーマ | ダーク / ライト切替、トグル、取得 |
| 壁紙 | 切替、一覧、現在のものを取得 |
| 音楽 (MPRIS) | 再生 / 一時停止、次へ、前へ |
| 通知 | DnD の設定 / トグル、履歴クリア、未読数取得 |
| アプリ | Settings → AI / Yura → Allowed apps で ON にしたアプリを起動 (PATH 外のバイナリは `.desktop` の Exec から解決) |
| タイマー | 開始 / 一時停止 / 再開 / キャンセル、状態取得 |
| カレンダー | イベント追加 / 削除、当日 or 範囲指定で一覧 |
| パネル | 名前指定でパネルを開く、任意のパネルを閉じる |

上の各行は Settings → AI / Yura → Tool categories でカテゴリ単位で OFF にできます。アプリ起動は Allowed apps ピッカー側でも縛られるので、「firefox 開いて」と言っても firefox を ON にするまでは動きません。

外部 MCP サーバも同じ gated set に入ります。設定ファイルに `[mcp.servers.*]` ブロックを足せば (memory、filesystem、GitHub など)、ツールが per-category gate、監査ログ、結果サニタイズ、書き込み前の Approve プロンプトを全部通して動くようになります。[SETUP.ja.md](SETUP.ja.md#mcp-サーバ) を参照。

電源操作 (ロック、サスペンド、ログアウト、再起動、シャットダウン) は Yura に公開していません。Power Menu から直接どうぞ。

今動くプロンプト例: 「音量 30 にして」「輝度下げて」「ライトモードに」「壁紙シャッフルして」「次の曲」「DnD on」「設定開いて」「25 分タイマー」「明日 15 時にカレンダーイベント追加」「firefox 起動」。

プロバイダ API キー、設定ファイルの書き方、HTTP API は [SETUP.ja.md → mugen-ai の設定](SETUP.ja.md#mugen-ai-の設定) を見てください。

---

## プレビュー

[TikTok デモ — @ripnk6498](https://www.tiktok.com/@ripnk6498/video/7579183858038492433?is_from_webapp=1&sender_device=pc)

---

## 機能

- 現在の壁紙から Matugen で Material You カラーを生成
- 動画・画像両対応の壁紙切替 (mpvpaper + awww)、ピッカー UI 付き
- Cava の音声ビジュアライザ
- スタンドアロンの Calendar ウィンドウ (月グリッド、イベント一覧、その場で追加・編集)
- カウントダウンタイマー (プリセット、M:SS 自由入力、進捗リング、バーに残り時間ピル表示)
- 音楽プレイヤー連携 (playerctl / MPRIS)。YouTube サムネイル fallback とシーク可能な進捗スライダ付き
- クリップボード履歴と通知センター
- スピーカーとマイクを 1 つの音量パネルに統合
- ラップトップ向けのバックライトスライダ (ハードウェアキー連動、バックライトが無いマシンでは非表示)
- WiFi / Bluetooth / IME 管理
- バッテリーインジケータ (任意で Power Menu アイコン内に水位風の塗りつぶし) と折りたたみ可能なシステムトレイ
- アプリランチャー、idle inhibitor トグル、クリップボードコピー付きスクリーンショット、スクリーンショットギャラリー、Power Menu
- スタンドアロン Settings ウィンドウ。テーマ / ブラー / アニメーション / 通知 + タイマー音 / ロックタイマー / 日付フォーマット、加えて Yura タブ (Personality、プロバイダ、Bar Yura model、Thinking、ツールカテゴリ、許可アプリ、パネル位置) を持ちます

---

## 使い方

インストール後 ([SETUP.ja.md](SETUP.ja.md))、バーは Hyprland セッション開始時に自動で立ち上がります。キーボードショートカット一覧は `Super + /`。Power Menu アイコンを右クリックすると Settings に飛びます。通知アイコンの隣のシェブロンをクリックでシステムトレイが展開されます。キーバインドの全リストは [SETUP.ja.md → キーバインド](SETUP.ja.md#キーバインド)。

---

## ライセンス

MIT License
