<p align="right"><a href="README.md">English</a> | <b>日本語</b></p>

<h1 align="center">
  <img src="shell/assets/branding/mugen-shell_logo.png" width="200" alt="mugen-shell logo" /><br/>
  mugen-shell
</h1>

<p align="center"><i>Quickshell + Hyprland で組んだ、夢幻デスクトップ。</i></p>

https://github.com/user-attachments/assets/375659b6-8b1d-4d08-8621-7451d6791e71

Hyprland + Quickshell デスクトップ向けの個人 dotfiles を、Nix flake または `make install` で入れられる形にまとめたものです。色は Matugen が壁紙から起こし、アシスタントがチャットと音声でシェルを動かします。

インストールせずに試すならデモ VM が使えます。Hyprland に自動ログインします (資格情報は `mugen` / `mugen`):

```sh
cd nixos && nix build .#nixosConfigurations.vm.config.system.build.vm && ./result/bin/run-mugen-vm-vm
```

インストール先、依存、キーバインド、それに Yura まわりの設定項目はすべて [SETUP.ja.md](SETUP.ja.md) にまとめました。シェルを起動したあとなら `Super + /` でも一覧が出ます。

---

## 環境

| | |
|---|---|
| OS | NixOS |
| GPU | AMD Radeon RX 9070 XT |
| WM | Hyprland |
| Shell | Zsh + Starship |
| Terminal | Kitty |
| Desktop Shell | Quickshell |
| Wallpaper | awww / mpvpaper |
| Colors | Matugen |

---

## Yura

Yura はデスクトップのアシスタントです。バーの入力 (`Super + Y`) と画面コーナーのチャットパネル (`Super + Shift + Y`) の 2 か所に出てきて、会話履歴は共有します。バックエンドは [`ai/`](ai/) 配下の Go サーバ **mugen-ai** で、[Ollama](https://ollama.com) 経由のローカルモデル、Anthropic Claude、Google Gemini、OpenAI 互換 API に対応しています。メッセージにはファイルを添えられます。画像は目のあるモデルへ渡り、テキストとして読めるものはプロンプトに畳み込むので、視覚のないモデルでも中身は届きます。

Yura はデスクトップの操作も可能です。「音量 30 にして」「25 分タイマー」と言えば、自分でクリックするのと同じパネルに届きます。ツール呼び出しはカテゴリ単位で塞げますし、アプリの起動は許可リスト制です。電源まわりは最初から渡していません。外部の [MCP](https://modelcontextprotocol.io) サーバも同じ枠に入り、書き込み系は実行前に確認します。

音声入力は任意です。`Super + Z` を押しながら話すと、返事は声で返ってきます。既定の声は日本語で、どの言語もそのまま読み上げます。言語ごとに別の声を割り当てたいときは Settings で選べます。設定は **Settings → AI / Yura** に集約してあり、残りは [SETUP.ja.md](SETUP.ja.md#mugen-ai-の設定) にまとめました。

---

## 機能

- 壁紙から Material You のパレットを起こし直します。静止画でも動画でも同じように扱います
- 日常のためのパネルが揃っています — カレンダー、タイマー、音楽、クリップボード、通知、アプリランチャー、スクリーンショットなど
- ひととおりのシステム操作ができます — オーディオ、バックライト、WiFi、Bluetooth、IME、バッテリー、システムトレイ
- Settings ウィンドウが独立しているので、設定ファイルを開かずにカスタマイズできます

---

## クレジット

mugen-shell は [Hyprland](https://hyprland.org/) と [Quickshell](https://quickshell.outfoxxed.me/) をはじめ、多くのプロジェクトの上に成り立っています。全リストは [SETUP.ja.md → クレジット](SETUP.ja.md#クレジット) にあります。

---

## ライセンス

MIT License
