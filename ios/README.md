# iOS 构建说明

当前使用 Flutter 3.47.9 stable / Dart 3.13，应用最低系统版本保持 iOS 15.0。

```sh
flutter pub get
flutter build ios --no-codesign
```

Xcode 使用 `Runner.xcworkspace` 和 Runner scheme；Flutter 入口由 xcconfig 指向
`lib/main_ios.dart`。签名和真机运行使用自己的开发者配置。

Runner 的构建预操作会运行 `scripts/patch_device_info.py`。它只把已解析的
`device_info_plus` iOS 插件中已知的 32 位内存累加变量改为 64 位，避免内存值
截断。补丁在本机 Pub 缓存中通过源码匹配后原子应用，依赖重新下载后会自动
重放；上游移除该实现后自动跳过，无须维护整个插件分叉。Android 源码不受影响。

Flutter 二进制框架的头文件使用引号导入，因此 Runner 关闭了针对该导入风格的
`CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER` 提示，其它编译诊断保持开启。
