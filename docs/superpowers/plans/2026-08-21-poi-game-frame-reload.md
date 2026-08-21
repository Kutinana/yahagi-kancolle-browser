# POI 游戏框架重载修复实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 使用全 frame 文档开始注入修复 Android WebView 的跨域重载失败，仅重新载入 `#htmlWrap`，并为旧 WebView 显示明确提示。

**架构：** 新增一个 AndroidX WebKit 子框架消息桥，在页面导航前向受信任来源的所有 frame 注入脚本。Flutter 的两种 WebView 渲染路径共用一个 MethodChannel 端口：启动时配置桥，操作时发送带请求 ID 的重载命令并接收严格枚举结果。

**技术栈：** Flutter、Dart、Kotlin、AndroidX WebKit `1.16.0`、MethodChannel、WebMessage、JUnit 4、Flutter Test。

---

## 文件结构

- 创建 `android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameFrameReloadBridge.kt`：注入脚本、来源校验、请求协调、WebView 绑定和超时。
- 创建 `android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameFrameReloadManager.kt`：暴露 `configure` 与 `reload` MethodChannel 方法。
- 创建 `android/app/src/test/kotlin/app/yahagi/kancollebrowser/browser/GameFrameReloadBridgeTest.kt`：覆盖脚本语义、请求 ID、重复回包、超时和不支持状态。
- 创建 `android/app/src/test/kotlin/app/yahagi/kancollebrowser/browser/GameFrameReloadManagerTest.kt`：覆盖 MethodChannel 参数和 wire 结果。
- 创建 `lib/src/browser/game_frame_reload_port.dart`：Flutter 侧统一端口及 wire 状态解码。
- 创建 `test/game_frame_reload_port_test.dart`：覆盖配置、结果映射和非法结果。
- 修改 `android/app/src/main/kotlin/app/yahagi/kancollebrowser/MainActivity.kt`：注册和释放重载 Manager。
- 修改 `lib/src/browser/game_browser_controller.dart`：增加 `unsupported` 结果。
- 修改 `lib/src/browser/native_game_webview_port.dart`：从顶层 JavaScript 改为统一子框架端口。
- 修改 `lib/src/game_webview.dart`：兼容渲染路径在导航前配置桥，并使用统一端口重载。
- 修改 `lib/src/native_activity_game_surface.dart`：原生 Activity 路径在创建 WebView 后、导航前配置桥。
- 修改 `lib/src/browser/game_refresh_dialog.dart` 与本地化文件：显示旧 WebView 专用提示。
- 修改现有 Flutter/Kotlin 测试：更新接口、启动顺序和结果枚举。
- 删除 `lib/src/browser/game_frame_reload_script.dart` 与 `test/game_frame_reload_script_test.dart`：移除会触发同源限制的顶层脚本方案。

### 任务 1：建立可测试的子框架脚本与请求协调器

**文件：**

- 创建：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameFrameReloadBridge.kt`
- 创建：`android/app/src/test/kotlin/app/yahagi/kancollebrowser/browser/GameFrameReloadBridgeTest.kt`

- [ ] **步骤 1：编写脚本语义和请求协调的失败测试**

```kotlin
@Test
fun scriptReloadsOnlyHtmlWrapAndNeverReloadsTopWindow() {
    val source = GameFrameReloadBridgeScript.source
    assertTrue(source.contains("getElementById('htmlWrap')"))
    assertTrue(source.contains("game.contentWindow.location.reload()"))
    assertTrue(source.contains("game.setAttribute('src', source)"))
    assertFalse(source.contains("window.location.reload()"))
}

@Test
fun coordinatorCompletesMatchingRequestOnlyOnce() {
    val coordinator = GameFrameReloadRequestCoordinator()
    val results = mutableListOf<String>()
    val request = coordinator.start(results::add)

    assertFalse(coordinator.complete("wrong", "reloaded"))
    assertTrue(coordinator.complete(request, "reloaded"))
    assertFalse(coordinator.complete(request, "reloaded"))
    assertEquals(listOf("reloaded"), results)
}
```

- [ ] **步骤 2：运行测试并确认因类型不存在而失败**

运行：

```powershell
./android/gradlew.bat -p android app:testDebugUnitTest --tests "app.yahagi.kancollebrowser.browser.GameFrameReloadBridgeTest"
```

预期：FAIL，编译器报告 `GameFrameReloadBridgeScript` 和 `GameFrameReloadRequestCoordinator` 未定义。

- [ ] **步骤 3：实现最小脚本和请求协调器**

```kotlin
internal object GameFrameReloadBridgeScript {
    const val objectName = "YahagiGameFrameReload"
    val source = """
        (() => {
          'use strict';
          if (window.__yahagiGameFrameReloadInstalled) return;
          const bridge = window.YahagiGameFrameReload;
          if (!bridge || typeof bridge.postMessage !== 'function') return;
          window.__yahagiGameFrameReloadInstalled = true;

          const post = (payload) => bridge.postMessage(JSON.stringify(payload));
          const reportTarget = () => post({
            kind: 'target',
            available: document.getElementById('htmlWrap') !== null,
          });

          bridge.onmessage = (event) => {
            let data;
            try {
              data = typeof event.data === 'string' ? JSON.parse(event.data) : event.data;
            } catch (_) { return; }
            if (!data || data.kind !== 'reload' || typeof data.requestId !== 'string') return;
            const game = document.getElementById('htmlWrap');
            if (!game) return;
            let result = 'reloaded';
            try {
              game.contentWindow.location.reload();
            } catch (_) {
              const source = game.getAttribute('src');
              if (!source) result = 'blocked';
              else game.setAttribute('src', source);
            }
            post({kind: 'result', requestId: data.requestId, result: result});
          };

          if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', reportTarget, {once: true});
          } else {
            reportTarget();
          }
        })();
    """.trimIndent()
}

internal class GameFrameReloadRequestCoordinator {
    private var pending: Pair<String, (String) -> Unit>? = null

    fun start(onComplete: (String) -> Unit): String {
        val requestId = java.util.UUID.randomUUID().toString()
        pending = requestId to onComplete
        return requestId
    }

    fun complete(requestId: String, result: String): Boolean {
        val active = pending ?: return false
        if (active.first != requestId) return false
        pending = null
        active.second(result)
        return true
    }

    fun cancel(result: String): Boolean {
        val active = pending ?: return false
        pending = null
        active.second(result)
        return true
    }
}
```

- [ ] **步骤 4：运行测试并确认通过**

运行同步骤 2。预期：PASS，0 failures。

- [ ] **步骤 5：提交脚本与协调器**

```powershell
git add android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameFrameReloadBridge.kt android/app/src/test/kotlin/app/yahagi/kancollebrowser/browser/GameFrameReloadBridgeTest.kt
git commit -m "feat(android): 添加游戏子框架重载脚本"
```

### 任务 2：绑定 WebView 并暴露原生 MethodChannel

**文件：**

- 修改：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameFrameReloadBridge.kt`
- 创建：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameFrameReloadManager.kt`
- 创建：`android/app/src/test/kotlin/app/yahagi/kancollebrowser/browser/GameFrameReloadManagerTest.kt`
- 修改：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/MainActivity.kt`

- [ ] **步骤 1：编写不支持、未配置和成功结果的失败测试**

```kotlin
@Test
fun reloadReturnsUnsupportedWhenFrameInjectionIsUnavailable() {
    val bridge = FakeFrameReloadBridge(supported = false)
    val manager = GameFrameReloadManager(bridge)
    val result = RecordingResult()

    manager.onMethodCall(MethodCall("reload", null), result)

    assertEquals("unsupported", result.successValue)
}

@Test
fun configureAttachesBeforeReload() {
    val bridge = FakeFrameReloadBridge(supported = true)
    val manager = GameFrameReloadManager(bridge)
    val result = RecordingResult()

    manager.onMethodCall(MethodCall("configure", null), result)

    assertEquals(1, bridge.configureCalls)
    assertNull(result.successValue)
}
```

- [ ] **步骤 2：运行 Manager 测试并确认正确失败**

```powershell
./android/gradlew.bat -p android app:testDebugUnitTest --tests "app.yahagi.kancollebrowser.browser.GameFrameReloadManagerTest"
```

预期：FAIL，`GameFrameReloadManager` 未定义。

- [ ] **步骤 3：实现桥绑定和 Manager**

`GameFrameReloadBridge` 必须：

```kotlin
interface GameFrameReloadBridgePort {
    fun isSupported(): Boolean
    fun configure(): String?
    fun reload(onComplete: (String) -> Unit)
    fun dispose()
}
```

生产实现使用 `WebViewCompat.addWebMessageListener` 与 `addDocumentStartJavaScript`，只允许 `CaptureOriginPolicy.allowedOriginRules`。`target.available == true` 时保存对应 `JavaScriptReplyProxy`；`reload` 向所有候选代理发送以下 JSON：

```json
{"kind":"reload","requestId":"<uuid>"}
```

若能力缺失返回 `unsupported`；未配置返回 `blocked`；候选为空返回 `html_wrap_not_found`；5 秒超时返回 `blocked`。收到匹配请求 ID 的 `reloaded` 后只完成一次。

Manager 的公开 wire 协议固定为：

```kotlin
when (call.method) {
    "isSupported" -> result.success(bridge.isSupported())
    "configure" -> result.success(bridge.configure())
    "reload" -> bridge.reload(result::success)
    else -> result.notImplemented()
}
```

在 `MainActivity` 注册：

```kotlin
const val GAME_FRAME_RELOAD_CHANNEL =
    "app.yahagi.kancollebrowser/game_frame_reload"

val frameReloadManager = GameFrameReloadManager(AndroidGameFrameReloadBridge(this))
gameFrameReloadManager = frameReloadManager
MethodChannel(
    flutterEngine.dartExecutor.binaryMessenger,
    GAME_FRAME_RELOAD_CHANNEL,
).setMethodCallHandler(frameReloadManager)
```

并在 `onDestroy()` 调用 `dispose()`。

- [ ] **步骤 4：运行 Bridge 与 Manager 测试**

```powershell
./android/gradlew.bat -p android app:testDebugUnitTest --tests "app.yahagi.kancollebrowser.browser.GameFrameReload*Test"
```

预期：PASS，来源错误、请求 ID 错误、重复回包和超时测试均通过。

- [ ] **步骤 5：提交原生桥接**

```powershell
git add android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameFrameReloadBridge.kt android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameFrameReloadManager.kt android/app/src/main/kotlin/app/yahagi/kancollebrowser/MainActivity.kt android/app/src/test/kotlin/app/yahagi/kancollebrowser/browser/GameFrameReloadBridgeTest.kt android/app/src/test/kotlin/app/yahagi/kancollebrowser/browser/GameFrameReloadManagerTest.kt
git commit -m "feat(android): 接入全 frame 游戏重载桥"
```

### 任务 3：接入 Flutter 统一端口与旧 WebView 提示

**文件：**

- 创建：`lib/src/browser/game_frame_reload_port.dart`
- 创建：`test/game_frame_reload_port_test.dart`
- 修改：`lib/src/browser/game_browser_controller.dart`
- 修改：`lib/src/browser/game_refresh_dialog.dart`
- 修改：`lib/l10n/app_ja.arb`
- 修改：`lib/l10n/app_zh.arb`
- 修改：`lib/l10n/app_zh_Hant.arb`
- 修改生成的 `lib/l10n/app_localizations*.dart`
- 修改：`test/game_refresh_dialog_test.dart`

- [ ] **步骤 1：编写端口与提示的失败测试**

```dart
test('maps unsupported wire result', () async {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async => 'unsupported');
  expect(
    await MethodChannelGameFrameReloadPort(channel: channel).reload(),
    GameFrameReloadResult.unsupported,
  );
});

testWidgets('shows old Android WebView message', (tester) async {
  await openDialog(
    tester,
    result: GameFrameReloadResult.unsupported,
  );
  await tester.tap(find.byKey(const Key('reload-game-frame')));
  await tester.pumpAndSettle();
  expect(
    find.text('当前设备的 Android WebView 太旧，不支持对子框架注入。'),
    findsOneWidget,
  );
});
```

- [ ] **步骤 2：运行测试并确认因枚举和端口缺失而失败**

```powershell
flutter test test/game_frame_reload_port_test.dart test/game_refresh_dialog_test.dart
```

预期：FAIL，`MethodChannelGameFrameReloadPort` 或 `unsupported` 未定义。

- [ ] **步骤 3：实现最小 Flutter 端口和提示映射**

```dart
const gameFrameReloadMethodChannelName =
    'app.yahagi.kancollebrowser/game_frame_reload';

abstract interface class GameFrameReloadPort {
  Future<void> configure();
  Future<GameFrameReloadResult> reload();
}

final class MethodChannelGameFrameReloadPort implements GameFrameReloadPort {
  MethodChannelGameFrameReloadPort({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(gameFrameReloadMethodChannelName);

  final MethodChannel _channel;

  @override
  Future<void> configure() => _channel.invokeMethod<void>('configure');

  @override
  Future<GameFrameReloadResult> reload() async => switch (
        await _channel.invokeMethod<String>('reload')
      ) {
        'reloaded' => GameFrameReloadResult.reloaded,
        'game_frame_not_found' => GameFrameReloadResult.gameFrameNotFound,
        'html_wrap_not_found' => GameFrameReloadResult.htmlWrapNotFound,
        'unsupported' => GameFrameReloadResult.unsupported,
        'blocked' => GameFrameReloadResult.blocked,
        _ => throw StateError('Invalid game frame reload result'),
      };
}
```

在枚举加入 `unsupported`，在对话框 switch 中映射 `gameFrameReloadUnsupported`。中文文案必须精确为：

```text
当前设备的 Android WebView 太旧，不支持对子框架注入。
```

- [ ] **步骤 4：生成本地化并运行测试**

```powershell
flutter gen-l10n
flutter test test/game_frame_reload_port_test.dart test/game_refresh_dialog_test.dart test/localization_contract_test.dart
```

预期：PASS，0 failures。

- [ ] **步骤 5：提交 Flutter 协议与提示**

```powershell
git add lib/src/browser/game_frame_reload_port.dart lib/src/browser/game_browser_controller.dart lib/src/browser/game_refresh_dialog.dart lib/l10n test/game_frame_reload_port_test.dart test/game_refresh_dialog_test.dart
git commit -m "feat: 添加子框架重载端口与兼容提示"
```

### 任务 4：让两种 WebView 路径在导航前配置桥

**文件：**

- 修改：`lib/src/browser/native_game_webview_port.dart`
- 修改：`lib/src/game_webview.dart`
- 修改：`lib/src/native_activity_game_surface.dart`
- 修改：`test/native_game_webview_port_test.dart`
- 修改：`test/native_activity_game_surface_test.dart`
- 修改：`test/game_capture_startup_sequence_test.dart`
- 删除：`lib/src/browser/game_frame_reload_script.dart`
- 删除：`test/game_frame_reload_script_test.dart`

- [ ] **步骤 1：编写启动顺序和委托行为的失败测试**

```dart
test('configures frame reload before first real navigation', () async {
  final calls = <String>[];
  await runStartup(
    configureFrameReload: () async => calls.add('frame-reload'),
    navigate: () async => calls.add('navigate'),
  );
  expect(calls, <String>['frame-reload', 'navigate']);
});

test('native port delegates reload without top-level javascript', () async {
  final reloadPort = FakeGameFrameReloadPort(GameFrameReloadResult.reloaded);
  final port = createNativePort(frameReloadPort: reloadPort);
  await port.create();

  expect(await port.reloadGameFrame(), GameFrameReloadResult.reloaded);
  expect(reloadPort.reloadCalls, 1);
  expect(nativeMethodCalls, isNot(contains('reloadGameFrame')));
});
```

- [ ] **步骤 2：运行目标测试并确认正确失败**

```powershell
flutter test test/native_game_webview_port_test.dart test/native_activity_game_surface_test.dart test/game_capture_startup_sequence_test.dart
```

预期：FAIL，启动 API 尚无 `configureFrameReload`，native port 仍调用旧 JavaScript 方法。

- [ ] **步骤 3：实现两条路径的导航前配置和统一重载**

- `MethodChannelNativeGameWebViewPort` 注入 `GameFrameReloadPort`，`reloadGameFrame()` 直接委托其 `reload()`。
- `WebViewGameBrowserPort` 注入同一端口并直接委托。
- `GameWebView` 在平台 WebView 已挂载后、首次真实导航前调用 `configure()`。
- `NativeActivityGameSurface` 在 `port.create()` 成功后、`loadUri()` 前调用 `configure()`。
- WebView 重建或渲染模式切换后重新执行 `configure()`，原生桥负责解绑旧 WebView。
- 删除顶层 `gameFrameReloadScript` 及其字符串测试。
- 从 `NativeGameWebViewChannel` 移除不再使用的 JavaScript 参数和异步回调分支；保留整页 `reload` 方法供「刷新页面」使用。

- [ ] **步骤 4：运行相关 Flutter 与 Android 回归测试**

```powershell
flutter test test/game_browser_controller_test.dart test/native_game_webview_port_test.dart test/native_activity_game_surface_test.dart test/game_capture_startup_sequence_test.dart test/game_refresh_dialog_test.dart
./android/gradlew.bat -p android app:testDebugUnitTest --tests "app.yahagi.kancollebrowser.nativewebview.NativeGameWebViewChannelTest" --tests "app.yahagi.kancollebrowser.browser.GameFrameReload*Test"
```

预期：PASS，旧 native channel 测试不再期待 `reloadGameFrame` JavaScript。

- [ ] **步骤 5：提交两种渲染路径接线**

```powershell
git add lib/src/browser/native_game_webview_port.dart lib/src/game_webview.dart lib/src/native_activity_game_surface.dart android/app/src/main/kotlin/app/yahagi/kancollebrowser/nativewebview/NativeGameWebViewChannel.kt android/app/src/test/kotlin/app/yahagi/kancollebrowser/nativewebview/NativeGameWebViewChannelTest.kt test
git commit -m "fix: 通过子框架桥重载舰 C 游戏"
```

### 任务 5：完整验证与当前设备验收

**文件：**

- 验证：全部改动文件

- [ ] **步骤 1：格式化并运行静态分析**

```powershell
dart format lib test
flutter analyze
```

预期：格式化完成，`flutter analyze` 退出码为 0。

- [ ] **步骤 2：运行完整自动化测试**

```powershell
flutter test
./android/gradlew.bat -p android app:testDebugUnitTest
```

预期：两条命令均退出码为 0，0 failures。

- [ ] **步骤 3：构建调试 APK**

```powershell
flutter build apk --debug
```

预期：生成 `build/app/outputs/flutter-apk/app-debug.apk`。

- [ ] **步骤 4：安装前记录并告知进程影响**

运行：

```powershell
adb devices -l
adb shell pidof app.yahagi.kancollebrowser
adb shell dumpsys activity activities
```

预期：`emulator-5554` 在线，应用为前台。安装 `-r` 会结束当前应用进程，但保留应用数据与登录 Cookie；执行安装前在 commentary 明确告知用户。

- [ ] **步骤 5：覆盖安装、启动并采集诊断日志**

```powershell
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell am start -n app.yahagi.kancollebrowser/.MainActivity
adb logcat -c
```

预期：安装和启动成功，应用重新进入游戏且保留登录状态。

- [ ] **步骤 6：执行严格 POI 真机验收**

通过当前应用界面触发「刷新游戏 → 重新载入游戏」，同时采集：

```powershell
adb logcat -d | Select-String -Pattern "GameFrameReload|chromium|AndroidRuntime"
```

验收条件：

- 日志出现一个请求 ID 的一次 `reloaded` 完成。
- 游戏画面重新初始化。
- 外层 DMM 页面未重新导航，应用未退回登录页。
- 没有出现 `AndroidRuntime` 崩溃。
- 不执行演习匹配、战斗、编成或其他账号业务操作。

- [ ] **步骤 7：检查最终差异和提交状态**

```powershell
git diff --check
git status --short
git log -6 --oneline
```

预期：无空白错误；除明确保留的用户改动外工作区干净；实现提交均存在。
