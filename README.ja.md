<div align="center">
  <img src="assets/app_icon.png" width="96" alt="ヤハギのアプリアイコン">

# ヤハギ

[Yahagi KanColle Browser](https://github.com/yamatosaki/yahagi-kancolle-browser) の iOS 移植版

[リリース](https://github.com/Kutinana/yahagi-kancolle-browser/releases) · [iOS の不具合報告](https://github.com/Kutinana/yahagi-kancolle-browser/issues) · [上流プロジェクト](https://github.com/yamatosaki/yahagi-kancolle-browser)

[简体中文](README.md) ｜ [繁體中文](README.zh-Hant.md) ｜ 日本語 ｜ [English](README.en.md) ｜ [한국어](README.ko.md)

</div>

本リポジトリは非公式の独立したフォークです。共通ロジックと UI は上流リポジトリに追従し、新しい機能コードは追加せず、iOS の仕様に合わせてプラットフォーム対応を行います。

Android 版の入手方法と詳しい機能紹介については、[上流プロジェクト](https://github.com/yamatosaki/yahagi-kancolle-browser)をご覧ください。

## 入手とインストール

本リポジトリの [Releases](https://github.com/Kutinana/yahagi-kancolle-browser/releases) から、最新リリースの .ipa ファイルを入手できます。

.ipa ファイルは iOS のアプリケーションパッケージです。本プロジェクトは App Store で配信していないため、サイドロード（Sideload）によってご自身の端末にインストールする必要があります。サイドロードの方法については、[AltStore](https://altstore.io/) または [Sideloadly](https://sideloadly.io/) をご覧ください。

## 制限事項

- **アプリ内プロキシ：** iOS 17 以降では基盤となる API が公開されており、アプリ内で専用の HTTP/SOCKS5 プロキシを設定できます。iOS 15–16 はこの機能に対応しておらず、システムのネットワーク（端末全体のプロキシ）のみ利用できます。

- **MOD とキャッシュ：** iOS ではゲームリソース全体のキャッシュやゲーム MOD を提供できません。

- **バックグラウンドでの動作維持：** iOS では Android のフォアグラウンドサービスと同様にゲームをバックグラウンドで維持できないため、該当する設定は利用できません。通知とバックグラウンド音声も、システム権限とアプリの実行状態に影響されます。

Apple は 2027 年春に、iOS アプリの最低対応バージョンを iOS 15.0 へ正式に引き上げる予定です。そのため、本プロジェクトは iOS 15.0 未満のシステムに対応していません。可能であれば、最新版の iOS とサイドロードツールの利用をお勧めします。

## その他

ご利用中に問題が発生した場合は、本リポジトリの [Issue](https://github.com/Kutinana/yahagi-kancolle-browser/issues) からいつでもご報告ください。バージョン、端末、OS、再現手順を添えていただけると助かります。動画など GitHub にアップロードしにくい添付ファイルを送りたい場合は、kanade@yoisaki.com でもご連絡いただけます。

本リポジトリは新しい機能を追加しないため、共通機能に関するご質問やご提案は、上流リポジトリの[交流とフィードバック](https://github.com/Kutinana/yahagi-kancolle-browser#%E4%BA%A4%E6%B5%81%E4%B8%8E%E5%8F%8D%E9%A6%88)へのご連絡をご検討ください。公式交流 QQ グループ：1104904097 への参加もお勧めします。

本プロジェクトは上流プロジェクトの非公式な派生版です。データの取り扱い、プライバシーポリシー、ライセンスなどは、上流リポジトリをご確認ください。
