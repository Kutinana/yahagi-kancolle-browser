<div align="center">
  <img src="assets/app_icon.png" width="96" alt="Yahagi app icon">

# ヤハギ

An iOS port of [Yahagi KanColle Browser](https://github.com/yamatosaki/yahagi-kancolle-browser)

[Releases](https://github.com/Kutinana/yahagi-kancolle-browser/releases) · [iOS issue reports](https://github.com/Kutinana/yahagi-kancolle-browser/issues) · [Upstream project](https://github.com/yamatosaki/yahagi-kancolle-browser)

[简体中文](README.md) ｜ [繁體中文](README.zh-Hant.md) ｜ [日本語](README.ja.md) ｜ English ｜ [한국어](README.ko.md)

</div>

This repository is an unofficial, independent fork. Shared business logic and UI follow the upstream repository. No new feature code is added; platform integration is adapted to the specifics of iOS.

For the Android version and a complete feature overview, please see the [upstream project](https://github.com/yamatosaki/yahagi-kancolle-browser).

## Download and installation

You can download the latest released .ipa file from this repository's [Releases](https://github.com/Kutinana/yahagi-kancolle-browser/releases).

An .ipa file is an iOS application package. This project is not available on the App Store, so you need to install the app on your device yourself through sideloading. For instructions on sideloading, please see [AltStore](https://altstore.io/) or [Sideloadly](https://sideloadly.io/).

## Limitations

- **In-app proxies:** iOS 17 and later expose the underlying APIs for configuring a dedicated HTTP/SOCKS5 proxy within the app. iOS 15–16 do not support this feature and can only use the system network (a global proxy).

- **Mods and caching:** iOS cannot provide full game resource caching or game mods.

- **Background operation:** iOS cannot keep the game running in the background in the same way as Android foreground services, so the corresponding setting is unavailable. Notifications and background audio are still affected by system permissions and the app's running state.

Please note that Apple will officially raise the minimum supported iOS version for iOS apps to iOS 15.0 in spring 2027. Therefore, this project does not support systems below iOS 15.0. If possible, we recommend using the latest versions of iOS and sideloading tools.

## Other information

If you encounter a problem while using the app, you are welcome to submit an [Issue](https://github.com/Kutinana/yahagi-kancolle-browser/issues) to this repository. Please include the app version, device, OS version, and steps to reproduce it. If you would like to send a video or another attachment that is difficult to upload to GitHub, you can also contact me at kanade@yoisaki.com.

This repository does not add any new features. For questions or suggestions about shared features, please consider contacting the upstream repository through [Discussion and feedback](https://github.com/Kutinana/yahagi-kancolle-browser#%E4%BA%A4%E6%B5%81%E4%B8%8E%E5%8F%8D%E9%A6%88). We recommend joining the official QQ group: 1104904097.

This project is an unofficial derivative of the upstream project. Please refer to the upstream repository for data handling, privacy policies, licensing, and related information.
