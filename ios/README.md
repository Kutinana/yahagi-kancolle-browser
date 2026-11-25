# 构建 Yahagi iOS 1.10

发布构建沿用 build 40 的 Flutter 3.50.0 stable。请让当前终端的 `flutter` 指向该版本，再从仓库根目录运行以下命令。

```sh
flutter pub get
flutter build ios --release --no-codesign --target lib/main_ios.dart
```

真机签名使用 `ios/Runner.xcworkspace` 的 Runner scheme。应用最低支持 iOS 15，应用内代理从 iOS 17 起可用，AlarmKit 预览从 iOS 26 起可用。

iOS 构建在项目内修复 WKWebView 销毁时的迟到 KVO 回调和 device_info_plus 的空闲内存溢出。两个包分别保留上游锁定的 3.26.0 和 13.2.0，各自的 LICENSE 随源码分发。iPad 沿用 build 40 的 Metal layer 和广色域设置，旧 iPad 的实际渲染效果仍需在原设备验证。[移植差异与验证记录](../docs/ios-1.10-adaptation.md)
