<div align="center">
  <img src="assets/app_icon.png" width="96" alt="ヤハギ應用程式圖示">

# ヤハギ

[Yahagi KanColle Browser](https://github.com/yamatosaki/yahagi-kancolle-browser) 的 iOS 移植版

[發布版本](https://github.com/Kutinana/yahagi-kancolle-browser/releases) · [iOS 問題回報](https://github.com/Kutinana/yahagi-kancolle-browser/issues) · [上游專案](https://github.com/yamatosaki/yahagi-kancolle-browser)

[简体中文](README.md) ｜ 繁體中文 ｜ [日本語](README.ja.md) ｜ [English](README.en.md) ｜ [한국어](README.ko.md)

</div>

本儲存庫為非官方獨立分支，共享業務邏輯與介面跟隨上游儲存庫，不新增功能性程式碼，並依 iOS 系統的具體情況進行平台適配。

有關 Android 版本的取得及完整功能介紹，請參見 [上游專案](https://github.com/yamatosaki/yahagi-kancolle-browser)。

## 取得與安裝

您可以從本儲存庫的 [Releases](https://github.com/Kutinana/yahagi-kancolle-browser/releases) 取得最新發布的 .ipa 檔案。

.ipa 檔案是 iOS 系統的應用程式套件。本專案並未上架 App Store，因此您需要透過側載（Sideload）在您的裝置上自行安裝本軟體。關於如何進行側載，請參見 [AltStore](https://altstore.io/) 或 [Sideloadly](https://sideloadly.io/)。

## 限制

- **應用程式內代理：** iOS 17 及以上開放了底層 API，支援在應用程式內設定專用的 HTTP/SOCKS5 代理。iOS 15–16 不支援此功能，僅能使用系統網路（全域代理）。

- **模改與快取：** iOS 無法提供完整遊戲資源快取、遊戲模改。

- **背景保持執行：** iOS 無法提供與 Android 前景服務相同的背景保持遊戲能力，相關設定無法使用；通知與背景聲音仍受系統權限及執行狀態影響。

請注意，Apple 將於 2027 年春季正式將 iOS 應用程式最低支援版本提高至 iOS 15.0，因此本專案不支援 iOS 15.0 以下的系統。若條件允許，建議您使用最新版的 iOS 系統與側載工具。

## 其他

若您在使用過程中遇到問題，您可以隨時向本儲存庫提交 [Issue](https://github.com/Kutinana/yahagi-kancolle-browser/issues)，並請附上版本、裝置、系統及重現步驟。若您希望傳送影片或其他不易在 GitHub 平台上傳的附件，您也可以使用 kanade@yoisaki.com 聯絡我。

本儲存庫不新增任何功能，因此若有通用功能的疑問或建議，請考慮聯絡上游儲存庫 [交流與回饋](https://github.com/Kutinana/yahagi-kancolle-browser#%E4%BA%A4%E6%B5%81%E4%B8%8E%E5%8F%8D%E9%A6%88)。推薦您加入官方交流 QQ 群組：1104904097。

本專案為上游專案的非官方衍生版本，資料處理、隱私權政策、License 等請以上游儲存庫為準。
