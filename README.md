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

デスクトップのアシスタントです。バーの入力欄と、チャットパネルから使えます。

- モデル: Ollama のローカルモデル、Claude、Gemini、OpenAI 互換 API
- デスクトップの操作: 「音量 30 にして」「5 分タイマー計って」で、対応するパネルが動きます
- 外部の MCP サーバにも対応しています。書き込み系の操作は実行前に確認します

設定は [SETUP.md](SETUP.md#mugen-ai-の設定) にまとめました。

---

## インストール

手順は [SETUP.md](SETUP.md) にあります。

インストールせずに試すにはデモ VM を使います。ユーザー名とロック解除・sudo のパスワードはどちらも `mugen` です。

```sh
nix build "github:tmy7533018/mugen-shell#nixosConfigurations.vm.config.system.build.vm" && ./result/bin/run-mugen-vm-vm
```

---

## クレジット

mugen-shell は [Hyprland](https://hypr.land/) と [Quickshell](https://quickshell.outfoxxed.me/) をはじめ、多くのプロジェクトの上に成り立っています。全リストは [SETUP.md → クレジット](SETUP.md#クレジット) にあります。

---

## ライセンス

MIT License
