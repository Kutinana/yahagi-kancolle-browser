# 原生 Activity WebView 实验模式实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 保留现有 Poi 页面布局与 3 种渲染模式，新增「原生直连（实验）」模式；该模式由现有 `MainActivity` 直接承载唯一的 Android `WebView`，Flutter 只提供游戏区域、控制界面和状态层，以降低长期运行时的内存与合成开销。

**架构：** Flutter 通过原生游戏表面占位组件上报游戏区域和可见性；Android 在 `MainActivity` 根布局中挂载同级 `WebView` 并按物理像素定位。业务命令走 `MethodChannel`，页面及渲染进程事件走 `EventChannel`，每次创建均携带 `generationId` 以丢弃过期回调。现有 3 种 `WebViewWidget` 路径保持不变；实验模式连续启动失败时自动回退到 `compatibility`。

**技术栈：** Flutter / Dart、Kotlin、Android `WebView`、Flutter `MethodChannel` / `EventChannel`、AndroidX WebKit、`flutter_test`、JUnit、Android instrumentation test。

---

## 开始前约束

- 当前工作区含有用户未提交的 Dart、Kotlin、测试和文档改动，其中 `MainActivity.kt` 已引用未跟踪的 `GameSurfaceRecoveryTrigger.kt`。执行实现前必须先让用户保存、提交或明确携带这些改动；不得清理、覆盖或顺带提交。
- 建议从包含上述用户改动的明确基线创建独立 worktree。若直接在当前工作区执行，每次提交只暂存本任务列出的文件，并用 `git diff --cached --name-only` 复核。
- 不修改现有 3 种模式存储名：`standard`、`compatibility`、`canvasCompatibility`。新存储名固定为 `nativeActivityExperimental`。
- 通道名固定为 `app.yahagi.kancollebrowser/native_game_webview` 和 `app.yahagi.kancollebrowser/native_game_webview_events`。
- 坐标协议使用 Flutter 视图内逻辑像素和 `devicePixelRatio`；Android 统一换算并裁剪到 Activity 内容区域。

## 文件结构

### 新增文件

- `lib/src/browser/native_game_webview_contract.dart`：命令、事件、边界和严格解码协议。
- `lib/src/browser/native_game_webview_port.dart`：实现 `GameBrowserPort` 并封装平台通道。
- `lib/src/browser/native_game_surface_slot.dart`：上报游戏矩形。
- `lib/src/browser/native_game_surface_visibility.dart`：协调路由、生命周期与宿主可见性。
- `lib/src/native_activity_game_surface.dart`：复用启动、抓包、音频和帧率编排，不创建 `WebViewController`。
- `android/app/src/main/kotlin/app/yahagi/kancollebrowser/nativewebview/NativeGameWebViewBounds.kt`：坐标换算与裁剪。
- `android/app/src/main/kotlin/app/yahagi/kancollebrowser/nativewebview/NativeGameWebViewHostState.kt`：宿主状态与代际规则。
- `android/app/src/main/kotlin/app/yahagi/kancollebrowser/nativewebview/NativeWebViewStartupGuard.kt`：连续失败计数和回退。
- `android/app/src/main/kotlin/app/yahagi/kancollebrowser/nativewebview/NativeGameWebViewConfigurator.kt`：集中配置 WebView。
- `android/app/src/main/kotlin/app/yahagi/kancollebrowser/nativewebview/NativeGameWebViewClient.kt`：导航、错误及渲染进程事件。
- `android/app/src/main/kotlin/app/yahagi/kancollebrowser/nativewebview/ActivityWebViewHost.kt`：挂载、定位、隐藏和销毁。
- `android/app/src/main/kotlin/app/yahagi/kancollebrowser/nativewebview/NativeGameWebViewChannel.kt`：Flutter 通道适配。
- 对应 Dart、Kotlin JVM 和 Android instrumentation 测试。
- `docs/testing/native-activity-webview-benchmark.md`：真机对照记录模板。

### 修改文件

- `lib/src/settings/game_rendering_mode.dart`、`game_rendering_mode_section.dart`、`diagnostics_section.dart`。
- `lib/l10n/app_zh.arb`、`app_zh_Hant.arb`、`app_ja.arb`，生成文件通过 `flutter gen-l10n` 更新。
- `lib/src/browser/game_browser_controller.dart`、`lib/src/game_webview.dart`、`lib/main.dart`。
- `android/app/src/main/kotlin/app/yahagi/kancollebrowser/MainActivity.kt` 和 `GameRenderingModeHcppPolicy.kt`。
- Android 与 Dart 诊断协议、监控器、隐私白名单及其测试。

## 任务 1：扩展渲染模式模型和设置入口

**文件：**

- 修改：`lib/src/settings/game_rendering_mode.dart`
- 修改：`lib/src/settings/game_rendering_mode_section.dart`
- 修改：`lib/src/settings/diagnostics_section.dart`
- 修改：3 个 ARB 和生成的本地化文件
- 测试：`test/game_rendering_mode_test.dart`、`test/game_rendering_mode_section_test.dart`、`test/diagnostics_rendering_mode_test.dart`
- 测试：`android/app/src/test/kotlin/app/yahagi/kancollebrowser/GameRenderingModeHcppPolicyTest.kt`

- [ ] 先添加失败测试，断言新模式不使用 Platform View、Canvas 或工具栏模糊，并能按存储名往返：

```dart
test('native activity mode bypasses Flutter platform views', () {
  const mode = GameRenderingMode.nativeActivityExperimental;
  expect(mode.usesPlatformView, isFalse);
  expect(mode.usesHybridComposition, isFalse);
  expect(mode.usesCanvasRenderer, isFalse);
  expect(mode.enablesToolbarBlur, isFalse);
  expect(GameRenderingModeCodec.decode(mode.storageName), mode);
});
```

- [ ] 在组件测试中断言 `rendering-mode-native-activity` 存在，排在 3 种现有模式之后，诊断页显示「原生直连（实验）」。
- [ ] 运行失败测试：

```powershell
flutter test test/game_rendering_mode_test.dart test/game_rendering_mode_section_test.dart test/diagnostics_rendering_mode_test.dart
```

预期：缺少枚举值、属性和本地化 getter。

- [ ] 最小实现模式属性：

```dart
enum GameRenderingMode {
  standard,
  compatibility,
  canvasCompatibility,
  nativeActivityExperimental;

  bool get usesActivityWebView => this == nativeActivityExperimental;
  bool get usesPlatformView => !usesActivityWebView;
  bool get usesHybridComposition =>
      this == compatibility || this == canvasCompatibility;
  bool get usesCanvasRenderer => this == canvasCompatibility;
  bool get enablesToolbarBlur => this == standard;
  String get storageName => name;
}
```

- [ ] 3 个 ARB 新增 `gameRenderingModeNativeActivity` 和 `gameRenderingModeNativeActivityDesc`。简体中文固定为「原生直连（实验）」和「Activity 直接承载 WebView，保留当前 Poi 布局；用于验证长时间运行时的内存稳定性。」
- [ ] 运行 `flutter gen-l10n`，不要手改生成文件。
- [ ] 给 HCPP 策略测试补充 `nativeActivityExperimental` 返回 `false` 的断言。
- [ ] 运行上述 Dart 测试和：

```powershell
Set-Location android
.\gradlew.bat testDebugUnitTest --tests "app.yahagi.kancollebrowser.GameRenderingModeHcppPolicyTest"
Set-Location ..
```

- [ ] 仅暂存本任务文件，复核后提交：

```powershell
git diff --cached --name-only
git commit -m "feat(渲染模式): 添加原生直连实验入口"
```

## 任务 2：定义 Dart 原生 WebView 协议和可解绑端口

**文件：**

- 新增：`lib/src/browser/native_game_webview_contract.dart`
- 新增：`lib/src/browser/native_game_webview_port.dart`
- 修改：`lib/src/browser/game_browser_controller.dart`
- 新增测试：`test/native_game_webview_contract_test.dart`、`test/native_game_webview_port_test.dart`
- 修改测试：`test/game_browser_controller_test.dart`

- [ ] 先写严格解码测试：缺字段、多字段、错误类型、负 `generationId` 和未知事件类型均抛出 `NativeGameWebViewSchemaException`。
- [ ] 写方法通道测试，覆盖 `create`、`setBounds`、`setVisible`、`loadUri`、`reload`、`canGoBack`、`goBack`、`runJavaScript`、`fitGameScreen`、`clearCache`、`clearSession`、`destroy` 的精确参数。
- [ ] 写按身份解绑测试：第二个端口替换第一个后，解绑第一个不得清空第二个。
- [ ] 运行失败测试：

```powershell
flutter test test/native_game_webview_contract_test.dart test/native_game_webview_port_test.dart test/game_browser_controller_test.dart
```

- [ ] 定义边界值对象，字段固定为 `left`、`top`、`width`、`height`、`devicePixelRatio`，全部为有限正数或合法坐标。
- [ ] 定义事件 `created`、`pageStarted`、`pageFinished`、`mainFrameError`、`navigationBlocked`、`renderProcessGone`、`destroyed`；每个事件包含 `generationId`，URL 必须由安全地址类型清洗。
- [ ] 实现 `MethodChannelNativeGameWebViewPort implements GameBrowserPort`。`create` 返回非负代际；所有后续命令携带代际；`dispose` 先取消事件，再请求销毁。
- [ ] 为控制器添加按身份解绑：

```dart
void detachPort(GameBrowserPort port) {
  if (identical(_port, port)) _port = null;
}
```

- [ ] 运行测试通过并提交：

```powershell
git commit -m "feat(WebView协议): 添加原生宿主通道契约"
```

## 任务 3：实现 Flutter 区域上报与可见性协调

**文件：**

- 新增：`lib/src/browser/native_game_surface_visibility.dart`
- 新增：`lib/src/browser/native_game_surface_slot.dart`
- 新增测试：`test/native_game_surface_slot_test.dart`

- [ ] 用假端口先写组件测试，覆盖首次布局、相同矩形去重、尺寸变化、路由遮挡隐藏、路由恢复显示、应用后台隐藏和销毁隐藏。
- [ ] 运行失败测试：`flutter test test/native_game_surface_slot_test.dart`。
- [ ] 实现 `NativeGameSurfaceVisibility`，分别记录 `routeVisible`、`appVisible`、`slotAttached`，最终可见性取逻辑与；只有结果变化才调用端口。
- [ ] 使用 `LayoutBuilder`、`RenderBox.localToGlobal(Offset.zero)` 和 `View.of(context).devicePixelRatio` 在帧尾上报逻辑坐标；拒绝非有限数和非正面积。
- [ ] 使用同一个 `RouteObserver<ModalRoute<void>>` 处理 `didPushNext` / `didPopNext`；生命周期仅 `resumed` 可见。
- [ ] 运行测试通过并提交：

```powershell
git commit -m "feat(游戏表面): 上报原生 WebView 区域和可见性"
```

## 任务 4：实现 Android 坐标、代际和启动保护纯逻辑

**文件：**

- 新增：`NativeGameWebViewBounds.kt`、`NativeGameWebViewHostState.kt`、`NativeWebViewStartupGuard.kt`
- 新增：对应的 3 个 Kotlin JVM 测试

- [ ] 先写坐标测试：逻辑像素乘 DPR、四舍五入、负边界裁剪、超出根布局裁剪、零面积及 NaN/Infinity 拒绝。
- [ ] 写代际测试：创建单调递增；旧代的定位、显隐和销毁均被拒绝；当前代只销毁一次。
- [ ] 写启动保护测试：第一次失败保留实验模式；连续 2 次在创建后 30 秒内未收到主框架 `pageFinished` 或发生 `renderProcessGone` 时，将偏好改为 `compatibility`；一次成功清零计数。
- [ ] 运行失败测试：

```powershell
Set-Location android
.\gradlew.bat testDebugUnitTest --tests "app.yahagi.kancollebrowser.nativewebview.*Test"
Set-Location ..
```

- [ ] 坐标换算只产出 `android.graphics.Rect`，Flutter 值不得直接写入 `LayoutParams`。
- [ ] 实现状态机 `Absent -> Creating -> Ready -> Destroying -> Absent`，每次变更校验代际。
- [ ] 启动保护使用独立键 `nativeWebView.consecutiveStartupFailures` 和 `nativeWebView.lastStartupStartedAtMs`；回退写既有 `flutter.game.renderingMode=compatibility` 后清零计数。
- [ ] 运行测试通过并提交：

```powershell
git commit -m "feat(原生宿主): 添加坐标代际和启动保护模型"
```

## 任务 5：实现 Activity 直属 WebView 宿主

**文件：**

- 新增：`NativeGameWebViewConfigurator.kt`、`NativeGameWebViewClient.kt`、`ActivityWebViewHost.kt`
- 新增：`android/app/src/androidTest/kotlin/app/yahagi/kancollebrowser/nativewebview/ActivityWebViewHostTest.kt`
- 新增/修改：WebViewClient 事件委托的 JVM 测试

- [ ] 先写 instrumentation 测试：创建后 Activity 内容根布局只有 1 个 WebView；边界更新正确；隐藏使用 `INVISIBLE`；销毁后从父节点移除且重复销毁安全。
- [ ] 写主框架错误、外部协议阻止和 `onRenderProcessGone` 的事件测试。
- [ ] 集中配置 JavaScript、DOM storage、媒体自动播放、第三方 Cookie 和硬件加速；沿用当前 User-Agent、缓存、代理与 Gadget bypass 接入点。本实验不改变缓存策略。
- [ ] `create` 在 UI 线程创建覆盖层并添加到 Activity 内容根布局末尾；WebView 是唯一子视图且初始 `INVISIBLE`。
- [ ] `setBounds` 仅更新覆盖层 `FrameLayout.LayoutParams`；WebView 始终 `MATCH_PARENT`。
- [ ] 实现确定性销毁顺序：隐藏、`stopLoading`、`about:blank`、`clearHistory`、移除子视图与父视图、替换 client、`destroy`。不得调用全局 `clearCache(true)`。
- [ ] `onRenderProcessGone` 返回 `true`，发事件后立即销毁当前代。
- [ ] 有设备时运行：

```powershell
Set-Location android
.\gradlew.bat connectedDebugAndroidTest -Pandroid.testInstrumentationRunnerArguments.class=app.yahagi.kancollebrowser.nativewebview.ActivityWebViewHostTest
Set-Location ..
```

无设备时明确记录待真机项，JVM 测试仍须通过。

- [ ] 提交：`git commit -m "feat(原生宿主): 在 Activity 挂载直属 WebView"`。

## 任务 6：接入平台通道与 MainActivity 生命周期

**文件：**

- 新增：`NativeGameWebViewChannel.kt`
- 修改：`MainActivity.kt`
- 新增：`NativeGameWebViewChannelTest.kt`

- [ ] 先写通道测试：严格参数、未知方法、`stale_generation`、重复创建先销毁旧宿主、销毁后不发事件。
- [ ] 运行失败测试：

```powershell
Set-Location android
.\gradlew.bat testDebugUnitTest --tests "app.yahagi.kancollebrowser.nativewebview.NativeGameWebViewChannelTest"
Set-Location ..
```

- [ ] 实现 `MethodCallHandler` 和 `EventChannel.StreamHandler`；UI 操作全部切到主线程。
- [ ] `MainActivity.onCreate` 只在持久化模式为 `nativeActivityExperimental` 时启用宿主；启动保护触发时先写偏好再走现有重启路径。
- [ ] 在 `configureFlutterEngine` 注册两条通道。截图、抓包、缩放、代理、缓存、音频和帧率管理器继续通过 `collectWebViews(decorView)` 找唯一实例，不另建一套管理器。
- [ ] `onDestroy` 顺序固定为：禁用通道、销毁宿主、释放依赖 WebView 的管理器、`super.onDestroy()`。
- [ ] 运行 `.\gradlew.bat testDebugUnitTest`，预期 `BUILD SUCCESSFUL`。
- [ ] 提交：`git commit -m "feat(Android): 接入原生 WebView 通道和生命周期"`。

## 任务 7：构建不含 WebViewWidget 的 Flutter 游戏表面

**文件：**

- 新增：`lib/src/native_activity_game_surface.dart`
- 修改：`lib/src/game_webview.dart`
- 修改：`lib/main.dart`
- 新增：`test/native_activity_game_surface_test.dart`
- 修改：`test/game_environment_host_test.dart`

- [ ] 先写组件测试：实验模式存在 `NativeGameSurfaceSlot` 且不存在 `WebViewWidget`；其他 3 种模式仍构建 `GameWebView`；4 种模式均保留 `BattleResultWarningOverlay`。
- [ ] 写生命周期测试：创建后附着浏览器端口；销毁顺序为隐藏、解绑、取消事件、原生销毁；旧代事件不改变控制器。
- [ ] 运行失败测试：

```powershell
flutter test test/native_activity_game_surface_test.dart test/game_environment_host_test.dart
```

- [ ] 从 `GameWebView` 抽取不依赖 `WebViewController` 的共享编排：网络设置、抓包启动序列、音频端口、帧率平台端口。现有 `GameWebView` 行为不得改变。
- [ ] 实现 `NativeActivityGameSurface`：创建端口、订阅当前代事件、转发页面状态、运行共享启动编排并返回占位组件。
- [ ] `main.dart` 仅增加以下分支：

```dart
if (mode.usesActivityWebView) {
  return withBattleWarning(_buildNativeActivityGameSurface(key));
}
return withBattleWarning(_buildGameWebView(key, renderingMode: mode));
```

- [ ] 把同一个路由观察器注入应用导航器和原生表面，禁止创建第二个 Navigator。
- [ ] 运行聚焦回归：

```powershell
flutter test test/native_activity_game_surface_test.dart test/game_environment_host_test.dart test/game_webview_widget_test.dart test/game_rendering_mode_test.dart
```

- [ ] 提交：`git commit -m "feat(游戏页面): 接入原生 Activity WebView 模式"`。

## 任务 8：补齐现有浏览器与平台能力

**文件：**

- 修改：原生 Dart 协议、端口和游戏表面
- 修改：Android 通道、配置器及相关测试
- 必要时修改：`lib/src/game_webview.dart` 以共享脚本常量

- [ ] 建立功能对照测试：主页、刷新、后退、适配画面、清缓存、退出清会话、截图、静音和帧率切换均命中原生端口。
- [ ] 导航策略仅允许现有安全策略认可的 HTTP(S) 地址；外部 scheme 发 `navigationBlocked`，不得隐式启动系统 Activity。
- [ ] `fitGameScreen` 执行与现有 `synchronizeGamePresentation()` 相同脚本，脚本文本只保留一份共享常量。
- [ ] 原生 `created` 后依次接入现有代理、资源缓存、Gadget bypass、GameCaptureBridge、音频和帧率管理器；失败使用固定错误码并保留重试状态。
- [ ] 验证抓包桥仍只发现 1 个 WebView，文档启动脚本和 WebMessage listener 正常挂载。
- [ ] 运行：

```powershell
flutter test test/game_browser_controller_test.dart test/game_capture_startup_sequence_test.dart test/game_audio_controller_test.dart test/game_frame_rate_settings_controller_test.dart test/game_screenshot_controller_test.dart
Set-Location android
.\gradlew.bat testDebugUnitTest
Set-Location ..
```

- [ ] 提交前逐文件暂存，不得使用会包含用户改动的宽泛 `git add test` 或 `git add lib`。
- [ ] 提交：`git commit -m "feat(原生模式): 补齐游戏控制和平台能力"`。

## 任务 9：实现渲染进程恢复和自动回退

**文件：**

- 修改：`native_activity_game_surface.dart`、`NativeGameWebViewClient.kt`、`NativeWebViewStartupGuard.kt`、`MainActivity.kt`
- 修改：3 个 ARB、生成的本地化文件和相关测试

- [ ] 先写失败测试：`renderProcessGone` 后显示恢复卡片而非退出 Flutter 应用；点击「重新加载」只创建一个新代；连续 2 次启动失败回退 `compatibility` 并只重建一次。
- [ ] 添加「游戏渲染进程已退出」「重新加载」「原生模式连续启动失败，已回退到标准模式」及繁中、日文文案，运行 `flutter gen-l10n`。
- [ ] 收到当前代渲染退出后解绑端口、进入失败状态、保留 Poi 顶栏和侧栏。重试先销毁旧代，再创建新代。
- [ ] 启动保护只在实验模式生效；收到主框架 `pageFinished` 才算成功；正常退出或用户切换模式不计失败。
- [ ] 回退重启失败时保留恢复卡片并记录诊断错误，不得循环重启。
- [ ] 运行 Dart 恢复测试和 `NativeWebViewStartupGuardTest`。
- [ ] 提交：`git commit -m "fix(原生模式): 添加渲染进程恢复和安全回退"`。

## 任务 10：扩展诊断数据验证闪退假设

**文件：**

- 修改：`DiagnosticPlatformHandler.kt`
- 修改：`diagnostic_platform_port.dart`、`diagnostic_event.dart`、`diagnostic_performance_monitor.dart`、`diagnostic_privacy_policy.dart`
- 修改：原生宿主状态桥和对应 Dart/Kotlin 测试

- [ ] 先扩展严格 schema 测试。运行时快照新增 `graphicsKb`、`privateOtherKb`、`systemAvailableKb`；性能事件新增 `webViewHost`、`renderer`、`generationId`；设备快照新增 `previousExitReason`。
- [ ] 枚举值固定为：

```text
webViewHost: flutterPlatformView | activityDirect | absent
renderer: webgl | canvas | unknown
previousExitReason: lowMemory | crash | anr | userRequested | systemUpdate | unknown | unavailable
```

- [ ] 运行失败测试：

```powershell
flutter test test/diagnostic_platform_port_test.dart test/diagnostic_event_test.dart test/diagnostic_performance_monitor_test.dart test/diagnostic_privacy_policy_test.dart
```

- [ ] Android 用 `Debug.MemoryInfo` 采集 PSS、Graphics、Private Other，用 `ActivityManager.MemoryInfo.availMem` 采集系统可用内存。API 支持时读取最近一次 `ApplicationExitInfo`，只映射固定枚举。
- [ ] 监控器从渲染模式和原生宿主状态读取宿主、渲染器、代际；非实验模式代际固定为 0。
- [ ] 隐私白名单只加入固定字段；URL、Cookie、账号和 JavaScript 不进入 JSON。
- [ ] 运行诊断测试、导出测试和 Android 单元测试。
- [ ] 提交：`git commit -m "feat(诊断): 记录 WebView 宿主和内存分项"`。

## 任务 11：全量验证和真机对照

**文件：**

- 新增：`docs/testing/native-activity-webview-benchmark.md`
- 必要时仅修改本任务新增代码和测试

- [ ] 仅格式化本任务新增/修改的 Dart 文件。
- [ ] 运行 `flutter analyze`，预期 `No issues found!`；若是用户既有改动造成问题，只记录，不改无关文件。
- [ ] 运行 `flutter test`，预期全部通过。
- [ ] 在 `android` 目录运行 `.\gradlew.bat testDebugUnitTest`，预期 `BUILD SUCCESSFUL`。
- [ ] 在 SM-F9460 上冒烟：切换 4 种模式、登录、进入游戏、折叠/展开、设置与对话框、主页/后退/刷新、适配、静音、截图、清缓存、退出账号、后台恢复。确认 WebView 不覆盖顶栏、侧栏和 Flutter 覆盖层。
- [ ] 用 `adb shell dumpsys activity top`、`adb shell dumpsys meminfo app.yahagi.kancollebrowser` 和过滤后的 `adb logcat` 确认只存在 1 个 WebView，并记录内存与渲染退出信息。
- [ ] 对标准模式和实验模式各运行 3 次、每次 60 分钟，操作脚本相同。记录 WebView 版本、PSS 中位数/峰值、Graphics、Private Other、系统可用内存、低内存回调、渲染退出及应用退出原因。
- [ ] 验收门槛：
  - 3 次均无应用闪退；
  - 实验模式 PSS 中位数下降至少 15% 或至少 150 MB；
  - 实验模式 PSS 峰值目标低于 900 MB；
  - 游戏画面、抓包、截图、音频和工具栏无功能回退；
  - 另做 1 次 2 小时连续运行，无持续单调增长且无低内存退出。
- [ ] 未达内存门槛时不标记为推荐，继续保留「实验」；出现功能回退时默认模式仍为 `compatibility`。
- [ ] 用 `git status --short`、`git diff --stat`、`git log --oneline -12` 复核任务边界。
- [ ] 提交：`git commit -m "docs(测试): 添加原生 WebView 对照验证记录"`。

## 规格覆盖自检

- [ ] 保留原有 3 种模式并新增独立实验模式。
- [ ] 使用现有 `MainActivity` 和单个 Flutter Engine；没有新 Activity、第二 Engine 或第二 WebView。
- [ ] Flutter 保留 Poi 顶栏、侧栏、状态与覆盖层；Android WebView 只占游戏矩形。
- [ ] 页面、对话框遮挡和后台状态不会让 WebView 穿透显示。
- [ ] 浏览器控制、抓包、代理、缓存、截图、音频、缩放和帧率均有自动化或真机验证。
- [ ] 有 `generationId`、确定性销毁、`onRenderProcessGone` 恢复和连续失败回退。
- [ ] 诊断可区分宿主、渲染器和代际，并包含低内存定位所需分项。
- [ ] 没有 TODO、占位实现、伪代码路径或未定义的通道字段。
- [ ] 新增 Dart API、Kotlin 方法、事件字段与测试类型名称一致。
- [ ] 默认模式仍为 `compatibility`；实验结果达标前不改为推荐。
