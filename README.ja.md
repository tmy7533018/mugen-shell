<p align="right"><a href="README.md">English</a> | <b>日本語</b></p>

<h1 align="center">
  <img src="shell/assets/branding/mugen-shell_logo.png" width="200" alt="mugen-shell logo" /><br/>
  mugen-shell
</h1>

<p align="center"><i>Quickshell + Hyprland で組んだ、夢幻デスクトップ。</i></p>

https://github.com/user-attachments/assets/beaaf135-5cdf-46d9-975d-91e3e6f04068

Hyprland + Quickshell デスクトップ向けの個人 dotfiles を、Nix flake または `make install` で入れられる形にまとめたものです。

インストールせずに試すならデモ VM をどうぞ: `cd nixos && nix build .#nixosConfigurations.vm.config.system.build.vm && ./result/bin/run-mugen-vm-vm` (Hyprland に自動ログイン。資格情報は `mugen` / `mugen`)。

ディレクトリ構成、インストール先、依存、キーバインドは [SETUP.ja.md](SETUP.ja.md) を見てください。

---

## 環境

| | |
|---|---|
| OS | NixOS (Arch 系でも動作) |
| GPU | AMD Radeon RX 9070 XT |
| WM | Hyprland (Lua config — 従来の `.conf` 版も fallback として同梱) |
| Shell | Zsh + Starship |
| Terminal | Kitty |
| Desktop Shell | Quickshell |
| Wallpaper | awww / mpvpaper |
| Colors | Matugen (Material You) |

---

## Yura

https://github.com/user-attachments/assets/61328371-aa8e-4f96-aae8-2817fadf3ed4

<sub><i>バーで軽く挨拶した後、コーナーの Yura が壁紙をシャッフル、ライトモードに切替え、ツール呼び出しでブラウザを開きます。</i></sub>

Yura はデスクトップのチャットアシスタント。バーの 1 行入力 (`Super + Y`) と、画面コーナーに張り付くチャットパネル (`Super + Shift + Y`) の 2 か所で使えます。

バックエンドは [`ai/`](ai/) 配下の Go サーバ **mugen-ai**。対応プロバイダ:

- [Ollama](https://ollama.com) 経由のローカルモデル
- Anthropic Claude
- Google Gemini
- OpenAI 互換 API (OpenAI、OpenRouter、LM Studio、vLLM ほか)

mugen-shell と一緒に NixOS / Arch + Nix / `make install` のどれかで入れます。詳細は [SETUP.ja.md](SETUP.ja.md)。Yura まわりの設定 (プロバイダ、Personality、ツール ON/OFF、許可アプリ) は全部 **Settings → AI / Yura** にまとまっています。

### 機能

- バー行とコーナーパネルは同じ会話を共有して同期。サイドバーに複数会話の履歴が残ります (ディスク保存)。
- 会話ごとにモデル固定。Thinking トグルも会話単位で、各プロバイダの reasoning チャンネルに振り分けます。
- 返信は Markdown 表示 (コードブロックはコピー付き)、ストリーミング中は停止ボタン、入力は IME 追従。
- Personality・プロバイダはじめ Yura の設定は全部 Settings GUI から — Save & Apply でバックエンドがホットリスタートします。
- 音声入力 (オプション)。**「Hey Yura」**と呼びかけて話すだけで、返答は VOICEVOX / AivisSpeech (日本語以外の声は Piper) が読み上げます。返答後もマイクは開いたままで会話を続けられて、両 UI に push-to-talk ボタン付き。セットアップは [SETUP.ja.md → 音声入力](SETUP.ja.md#音声入力-オプション)。
- アプリ起動は厳格 allowlist (デフォルト空)、ツールはカテゴリ単位 ON/OFF、外部 [MCP](https://modelcontextprotocol.io) サーバも同じ gated set に統合。

### チャットからのシェル操作

Yura は gated なツール呼び出しでデスクトップを操作します: 音量・マイク・輝度・テーマ・壁紙・音楽・通知・タイマー・カレンダー・パネル・allowlist 制のアプリ起動。可逆な操作は即実行、破壊的な操作はチャット内で確認、外部 MCP の書き込みは Approve / Deny を挟みます。電源操作はあえて非公開。「音量 30 にして」「壁紙シャッフルして」「25 分タイマー」のように使えます — ドメイン別の全テーブルと詳細は [SETUP.ja.md → チャットからのシェル操作](SETUP.ja.md#チャットからのシェル操作) へ。

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
- スタンドアロン Settings ウィンドウ: テーマ / ブラー / アニメーション / サウンド / ロックタイマー / 日付フォーマット、加えて Yura と Voice input の設定タブ一式

---

## 使い方

インストール後 ([SETUP.ja.md](SETUP.ja.md))、バーは Hyprland セッション開始と同時に自動で立ち上がります。ショートカット一覧は `Super + /`。Power Menu アイコンを右クリックすると Settings に飛び、通知アイコン隣のシェブロンをクリックするとシステムトレイが展開されます。キーバインドの全リストは [SETUP.ja.md → キーバインド](SETUP.ja.md#キーバインド) へ。

---

## クレジット

mugen-shell は [Hyprland](https://hyprland.org/) と [Quickshell](https://quickshell.outfoxxed.me/) をはじめ多くのプロジェクトの上に成り立っています — 全リストは [SETUP.ja.md → クレジット](SETUP.ja.md#クレジット) へ。

同梱の「Hey Yura」ウェイクワードモデル (`voice/models/hey_yura.onnx`) は、[VOICEVOX](https://voicevox.hiroshiba.jp/) で合成した日本語音声で学習したカスタム [openWakeWord](https://github.com/dscripka/openWakeWord) モデルです。

---

## ライセンス

MIT License
