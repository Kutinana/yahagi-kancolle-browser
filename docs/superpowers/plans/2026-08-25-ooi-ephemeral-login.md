# OOI 临时登录会话实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** OOI 在冷启动和每次切入时重新手动登录，Yahagi/DMM 自动登录及所有本地数据继续保留，并把 Debug 版本更新为 `1.0.5-beta.2+7`。

**架构：** 新增独立的精确 Origin Cookie 平台通道，Dart 只在新的 OOI 连接周期开始前调用；`GameBrowserController` 用进程内状态避免页面刷新或 WebView 恢复时重复清理。平台端仅允许 `https://ooi.moe`，定向使其 Cookie 过期，不调用全局 Cookie 清理。

**技术栈：** Dart、Flutter MethodChannel、Kotlin、Android CookieManager、JUnit、flutter_test、ADB。

---

## 文件结构

- 创建 `lib/src/browser/origin_cookie_manager_port.dart`：定义定向 Cookie 平台端口与 MethodChannel 实现。
- 创建 `android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/OriginCookieManagerChannel.kt`：验证精确 Origin 并使该 Origin Cookie 过期。
- 创建 `android/app/src/test/kotlin/app/yahagi/kancollebrowser/browser/OriginCookieManagerChannelTest.kt`：原生安全与隐私行为测试。
- 修改 `android/app/src/main/kotlin/app/yahagi/kancollebrowser/MainActivity.kt`：注册平台通道。
- 修改 `lib/src/browser/game_browser_controller.dart`：冷启动一次性准备和切入 OOI 清理顺序。
- 修改 `lib/src/game_webview.dart`、`lib/src/native_activity_game_surface.dart`：首次导航前调用冷启动准备。
- 修改 `lib/src/browser/native_game_webview_port.dart` 及测试假端口：实现新增端口能力。
- 修改 `test/game_browser_controller_test.dart`、`test/game_connector_section_test.dart`：覆盖生命周期边界。
- 创建 `test/app_version_contract_test.dart`：锁定 Beta 版本名与 Android 版本码。
- 修改 `pubspec.yaml`：版本更新为 `1.0.5-beta.2+7`。

### 任务 1：Dart 生命周期红灯与最小实现

- [ ] 在 `test/game_browser_controller_test.dart` 写测试：初始 OOI 的 `prepareInitialHome()` 只清理一次；初始 Yahagi 不清理；`switchHome(ooi)` 每次先清理再导航；`reload()` 与 `goHome()` 不清理；清理失败时不导航。
- [ ] 在 `test/game_connector_section_test.dart` 把 OOI 切换期望改为 `clear:https://ooi.moe` 后 `load:https://ooi.moe/`，并确认切换 Yahagi 不清理。
- [ ] 运行 `flutter test test/game_browser_controller_test.dart test/game_connector_section_test.dart`，确认因新 API/行为尚不存在而失败。
- [ ] 在 `GameBrowserPort` 增加 `clearCookiesForOrigin(Uri origin)`；在 `GameBrowserController` 增加进程内首次准备状态，并让 OOI 切换严格执行清理后导航。
- [ ] 两套 WebView 启动序列首次导航前调用 `prepareInitialHome()`；更新所有测试假端口以编译。
- [ ] 重跑两项测试确认通过，并提交 `feat(登录): 隔离 OOI 临时登录周期`。

### 任务 2：平台定向 Cookie 清理红灯与最小实现

- [ ] 在 `OriginCookieManagerChannelTest.kt` 写测试：只允许无 path/query/fragment 的 `https://ooi.moe`；空 Cookie 成功；合法名称同时写入 host-only 和 domain 过期 Cookie；非法名称忽略；结果与错误不含 Cookie 值。
- [ ] 运行 `android\\gradlew.bat :app:testDebugUnitTest --tests app.yahagi.kancollebrowser.browser.OriginCookieManagerChannelTest`，确认类不存在导致红灯。
- [ ] 实现可注入的 Cookie Store 接口与 `OriginCookieManagerChannel`，注册 `app.yahagi.kancollebrowser/origin_cookies`。
- [ ] 实现 Dart `MethodChannelOriginCookieManagerPort`，Flutter 与 Native Activity 两个 `GameBrowserPort` 均委托该端口。
- [ ] 重跑平台与 Dart 相关测试确认通过，并提交 `feat(登录): 定向清理 OOI Cookie`。

### 任务 3：版本修正与回归

- [ ] 创建 `test/app_version_contract_test.dart`，读取 `pubspec.yaml` 并断言包含独立行 `version: 1.0.5-beta.2+7`，运行该测试确认红灯。
- [ ] 修改 `pubspec.yaml`，运行版本测试确认绿灯，执行 `flutter pub get` 更新生成的 Android 版本属性。
- [ ] 运行 `flutter test` 和 `android\\gradlew.bat :app:testDebugUnitTest`。
- [ ] 执行 `flutter build apk --debug`，用 APK 工具确认 `versionName=1.0.5-beta.2`、`versionCode=7`。
- [ ] 提交 `chore(版本): 更新至 1.0.5-beta.2`。

### 任务 4：实机验收

- [ ] 使用 `adb install -r build/app/outputs/flutter-apk/app-debug.apk` 更新安装，不卸载、不清数据。
- [ ] 冷启动 OOI：确认打开 `https://ooi.moe/` 且要求手动登录。
- [ ] 登录后刷新：确认仍保持登录并继续捕获 `/kcsapi/*`。
- [ ] OOI 切 Yahagi再切回 OOI：确认回到登录首页；同时 Yahagi Cookie未清理。
- [ ] 检查舰队、航海日志和本地缓存设置仍存在；审计 diff 只包含计划文件，清理临时诊断文件并保持工作区干净。
