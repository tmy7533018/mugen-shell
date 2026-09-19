<p align="right"><a href="README.en.md">English</a> | <b>日本語</b></p>

<h1 align="center">
  <img src="shell/assets/branding/mugen-shell_logo.png" width="200" alt="mugen-shell logo" /><br/>
  mugen-shell
</h1>

<p align="center"><i>Quickshell + Hyprland で組んだ、夢幻シェル。</i></p>


https://github.com/user-attachments/assets/cd9e2538-a30f-4c8c-a143-9f8c2c7b3a8f


Hyprland + Quickshell デスクトップ向けの私の dotfiles を、Arch のパッケージと Nix flake で入れられる形にまとめたものです。

---

## 機能

- パネル: カレンダー、タイマー、天気、音楽、クリップボード、通知、アプリランチャー、スクリーンショット
- システム操作: オーディオ、バックライト、WiFi、Bluetooth、IME、バッテリー、システムトレイ
- 画像と動画の壁紙
- 壁紙から生成した配色: GTK アプリや Hyprland にも適用
- ライト / ダークの切り替え
- ロック画面
- デスクトップアシスタント Yura
- なめらかなアニメーション
- カスタマイズ: バーの形と色、透明度、ブラー、アニメーション速度など

---

## Yura

Yura はデスクトップのアシスタントです。バーの入力 (`Super + Y`) と画面コーナーのチャットパネル (`Super + Shift + Y`) の 2 か所で使用できて、会話履歴は共有されます。バックエンドは [`ai/`](ai/) 配下の Go サーバ **mugen-ai** で、[Ollama](https://ollama.com) 経由のローカルモデル、Anthropic Claude、Google Gemini、OpenAI 互換 API に対応しています。パネルからはメッセージにファイルを添えられます。

Yura はデスクトップの操作も可能です。「音量 30 にして」「5 分タイマー計って」と言えば、自分でクリックするのと同じパネルに届きます。危険な操作はしません。外部の [MCP](https://modelcontextprotocol.io) サーバにも対応しており、書き込み系は実行前に確認します。

返事はスピーカーアイコンを押すと読み上げられます (オプション)。既定の声は日本語です。[AivisHub](https://hub.aivis-project.com/) のモデルをインストールして Settings で選べます。詳細は [SETUP.md](SETUP.md#mugen-ai-の設定) にまとめました。

---

## インストール

インストールせずに試すならデモ VM が使えます (Yura を動かすにはモデルの用意が要ります)。Hyprland に自動ログインします (資格情報は `mugen` / `mugen`):

```sh
nix build "github:tmy7533018/mugen-shell#nixosConfigurations.vm.config.system.build.vm" && ./result/bin/run-mugen-vm-vm
```

インストール手順と設定については [SETUP.md](SETUP.md) にまとめました。Arch なら `./install.sh` 一本で入ります。

---

## クレジット

mugen-shell は [Hyprland](https://hypr.land/) と [Quickshell](https://quickshell.outfoxxed.me/) をはじめ、多くのプロジェクトの上に成り立っています。全リストは [SETUP.md → クレジット](SETUP.md#クレジット) にあります。

---

## ライセンス

MIT License
