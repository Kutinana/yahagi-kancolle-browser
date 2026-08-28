# Yahagi 官方页面识别与缩放修复实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 让 Yahagi 官方 DMM 登录页保持普通网页显示，并在四种渲染模式下可靠识别舰 C 游戏画面、隐藏 DMM 外壳和保持 1200×720 自适应缩放，同时完全保留 OOI 现有行为。

**架构：** 页面脚本使用精确顶层 URL 将页面划分为账号页、游戏候选页和普通网页，再以可见游戏容器确认 `game`，以 `pending` 表示候选页尚在加载。Flutter 与 Android 原生桥接共享 `game/web/pending` 语义；只有 `game` 绑定固定画布、`web` 释放、`pending` 保持现状。

**技术栈：** Flutter/Dart、`webview_flutter`、JavaScript DOM、Android Kotlin WebView、JUnit 4、Flutter Test、ADB。

---

## 文件结构

- 创建：`lib/src/browser/game_presentation_state.dart` —— 定义 `game/web/pending` 状态、WebView 返回值解析和对应平台动作。
- 删除：`lib/src/browser/game_surface_detection_result.dart` —— 旧布尔解析器无法表达加载中状态。
- 创建：`test/game_presentation_state_test.dart` —— 验证布尔兼容、字符串解析、带引号 Android 返回值和 `pending` 无动作。
- 删除：`test/game_surface_detection_result_test.dart` —— 由三态解析测试替代。
- 修改：`lib/src/browser/game_page_alignment_script.dart` —— 精确识别 Yahagi URL、删除全链接登录检测、检测可见游戏容器并返回三态；保留 OOI 分支行为。
- 修改：`test/game_page_alignment_script_test.dart` —— 固化精确 URL、`pending`、可见性、账号链接不参与判断和 OOI 不变约束。
- 修改：`lib/src/game_webview.dart` —— 消费三态结果，`pending` 不执行平台动作，并移除 PlatformView 导航开始时的无条件释放。
- 修改：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/nativewebview/NativeGameWebViewConfigurator.kt` —— 原生桥记录 `pending`，但不调用绑定或释放。
- 修改：`android/app/src/test/kotlin/app/yahagi/kancollebrowser/nativewebview/NativeGameWebViewConfiguratorTest.kt` —— 验证 `game → pending → game` 会重新应用且 `pending` 本身无平台动作。
- 修改：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/MainActivity.kt` —— 移除原生 Activity 页面开始时的无条件缩放释放。
- 修改：`test/android_game_surface_recovery_test.dart` —— 静态约束原生页面开始回调不再释放固定画布。

### 任务 1：引入三态展示模型

**文件：**
- 创建：`lib/src/browser/game_presentation_state.dart`
- 删除：`lib/src/browser/game_surface_detection_result.dart`
- 创建：`test/game_presentation_state_test.dart`
- 删除：`test/game_surface_detection_result_test.dart`

- [ ] **步骤 1：先编写三态解析失败测试**

创建测试，要求解析 WebView 的布尔兼容值、普通字符串和 Android 可能返回的带引号字符串：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_presentation_state.dart';

void main() {
  test('decodes game web and pending presentation states', () {
    expect(decodeGamePresentationState(true), GamePresentationState.game);
    expect(decodeGamePresentationState(false), GamePresentationState.web);
    expect(decodeGamePresentationState('game'), GamePresentationState.game);
    expect(decodeGamePresentationState('"game"'), GamePresentationState.game);
    expect(decodeGamePresentationState('web'), GamePresentationState.web);
    expect(
      decodeGamePresentationState('pending'),
      GamePresentationState.pending,
    );
  });

  test('unknown results remain non-actionable', () {
    expect(decodeGamePresentationState(null), isNull);
    expect(decodeGamePresentationState(1), isNull);
    expect(decodeGamePresentationState('unknown'), isNull);
  });

  test('pending never binds or releases fixed canvas', () {
    expect(
      GamePresentationState.pending.platformAction,
      GamePresentationPlatformAction.none,
    );
    expect(
      GamePresentationState.game.platformAction,
      GamePresentationPlatformAction.bind,
    );
    expect(
      GamePresentationState.web.platformAction,
      GamePresentationPlatformAction.release,
    );
  });
}
```

- [ ] **步骤 2：运行测试并确认红灯**

运行：

```powershell
flutter test test/game_presentation_state_test.dart
```

预期：FAIL，原因是 `game_presentation_state.dart` 和三态 API 尚不存在。

- [ ] **步骤 3：实现最小三态模型**

创建生产文件：

```dart
enum GamePresentationState { game, web, pending }

enum GamePresentationPlatformAction { bind, release, none }

extension GamePresentationStateAction on GamePresentationState {
  GamePresentationPlatformAction get platformAction => switch (this) {
    GamePresentationState.game => GamePresentationPlatformAction.bind,
    GamePresentationState.web => GamePresentationPlatformAction.release,
    GamePresentationState.pending => GamePresentationPlatformAction.none,
  };
}

GamePresentationState? decodeGamePresentationState(Object? result) {
  if (result is bool) {
    return result ? GamePresentationState.game : GamePresentationState.web;
  }
  if (result is! String) return null;

  var value = result.trim().toLowerCase();
  if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
    value = value.substring(1, value.length - 1).trim();
  }
  return switch (value) {
    'game' || 'true' => GamePresentationState.game,
    'web' || 'false' => GamePresentationState.web,
    'pending' => GamePresentationState.pending,
    _ => null,
  };
}
```

删除旧布尔解析文件和测试。

- [ ] **步骤 4：运行三态测试并确认绿灯**

运行：

```powershell
flutter test test/game_presentation_state_test.dart
```

预期：PASS，3 个测试通过。

- [ ] **步骤 5：提交三态模型**

```powershell
git add -- lib/src/browser/game_presentation_state.dart lib/src/browser/game_surface_detection_result.dart test/game_presentation_state_test.dart test/game_surface_detection_result_test.dart
git commit -m "refactor(缩放): 引入游戏展示三态模型"
```

### 任务 2：修复 Yahagi URL 与 DOM 判断

**文件：**
- 修改：`test/game_page_alignment_script_test.dart`
- 修改：`lib/src/browser/game_page_alignment_script.dart`

- [ ] **步骤 1：添加精确 URL 与误判回归的失败测试**

在脚本测试中增加以下约束：

```dart
test('Yahagi presentation uses exact official game routes', () {
  expect(
    gamePageAlignmentScript,
    contains('/netgame/social/-/gadgets/=/app_id=854854/'),
  );
  expect(gamePageAlignmentScript, contains("host === 'osapi.dmm.com'"));
  expect(gamePageAlignmentScript, contains("host.endsWith('.kancolle-server.com')"));
  expect(gamePageAlignmentScript, isNot(contains("pathname.includes('kancolle')")));
});

test('normal DMM account links cannot disable the game presentation', () {
  expect(gamePageAlignmentScript, isNot(contains('document.links')));
  expect(gamePageAlignmentScript, isNot(contains("href.includes('/login')")));
});

test('game candidates remain pending until a visible surface exists', () {
  expect(gamePageAlignmentScript, contains("return 'pending'"));
  expect(gamePageAlignmentScript, contains('getBoundingClientRect()'));
  expect(gamePageAlignmentScript, contains('element.isConnected'));
  expect(gamePageAlignmentScript, contains("notifyPresentationState('pending')"));
});
```

更新旧测试，移除把 `document.links` 当成正确行为的断言，同时保留全部 OOI 断言。

- [ ] **步骤 2：运行脚本测试并确认红灯**

运行：

```powershell
flutter test test/game_page_alignment_script_test.dart
```

预期：FAIL，显示脚本仍包含宽泛 `kancolle` 路径和 `document.links`，且没有 `pending`。

- [ ] **步骤 3：实现精确 Yahagi 分类和可见性检测**

在现有 OOI URL 判断之后定义 Yahagi 分类：

```javascript
const host = location.hostname.toLowerCase();
const pathname = location.pathname.toLowerCase();
const isAccountPage =
  host === 'accounts.dmm.com' || host === 'accounts.dmm.co.jp';
const isKancolleServerPage =
  host === 'kancolle-server.com' ||
  host.endsWith('.kancolle-server.com');
const isOfficialDmmGamePage =
  (host === 'www.dmm.com' || host === 'dmm.com' || host === 'games.dmm.com') &&
  pathname.includes('/netgame/social/-/gadgets/=/app_id=854854/');
const isGamePage =
  isOfficialDmmGamePage || host === 'osapi.dmm.com' || isKancolleServerPage;
```

删除 `hasAuthenticationControls`。增加真实可见性检查：

```javascript
const isVisibleElement = (element) => {
  if (!element?.isConnected) return false;
  const style = getComputedStyle(element);
  if (
    style.display === 'none' ||
    style.visibility === 'hidden' ||
    style.visibility === 'collapse'
  ) {
    return false;
  }
  const rect = element.getBoundingClientRect();
  return rect.width > 0 && rect.height > 0;
};
```

将同步结果改为：

```javascript
if (!isGamePage || isAccountPage || hasBlockingPageDialog()) {
  cleanupGamePresentation();
  notifyPresentationState('web');
  return 'web';
}
if (!hasGameSurface) {
  notifyPresentationState('pending');
  return 'pending';
}
applyGamePresentation();
notifyPresentationState('game');
return 'game';
```

OOI `/kancolle` 分支继续应用原有 CSS，并继续通知 `web` 以隔离 DMM 固定画布。

- [ ] **步骤 4：运行脚本测试并确认绿灯**

运行：

```powershell
flutter test test/game_page_alignment_script_test.dart
```

预期：PASS，且 OOI 相关测试仍全部通过。

- [ ] **步骤 5：提交 Yahagi 页面判断修复**

```powershell
git add -- lib/src/browser/game_page_alignment_script.dart test/game_page_alignment_script_test.dart
git commit -m "fix(缩放): 精确识别Yahagi游戏页面"
```

### 任务 3：让 PlatformView 正确消费 `pending`

**文件：**
- 修改：`lib/src/game_webview.dart`
- 测试：`test/game_presentation_state_test.dart`

- [ ] **步骤 1：扩充无动作状态测试**

在三态测试中确认 `null` 和 `pending` 都不会产生绑定或释放动作；已有断言若全部覆盖，则运行该测试作为修改前门禁。

- [ ] **步骤 2：运行门禁测试**

运行：

```powershell
flutter test test/game_presentation_state_test.dart
```

预期：PASS，证明动作映射已固定，随后只接线不改变策略。

- [ ] **步骤 3：接入三态并删除导航开始时的释放**

将旧导入替换为 `game_presentation_state.dart`。JavaScript 通道只在收到可执行状态时重新同步：

```dart
final state = decodeGamePresentationState(message.message);
if (state == null || state == GamePresentationState.pending) return;
_synchronizeGamePresentation().catchError((Object _) {});
```

同步脚本返回值后调用：

```dart
await _applyGamePresentation(
  decodeGamePresentationState(gameSurfaceResult),
  navigationEpoch,
);
```

平台动作使用 `platformAction`：

```dart
switch (state?.platformAction ?? GamePresentationPlatformAction.none) {
  case GamePresentationPlatformAction.bind:
    await _scaleChannel.invokeMethod<void>('bindFixedCanvas', <String, Object>{
      'contentWidth': 1200,
      'contentHeight': 720,
    });
  case GamePresentationPlatformAction.release:
    await _scaleChannel.invokeMethod<void>('releaseFixedCanvas');
  case GamePresentationPlatformAction.none:
    return;
}
```

删除 `onPageStarted` 中 `_releaseFixedCanvas()` 的无条件调用；保留销毁和明确离开页面时使用的 `_releaseFixedCanvas` 方法。

- [ ] **步骤 4：运行相关 Flutter 测试和分析**

运行：

```powershell
flutter test test/game_presentation_state_test.dart test/game_page_alignment_script_test.dart test/game_browser_controller_test.dart
dart analyze lib/src/game_webview.dart lib/src/browser/game_presentation_state.dart lib/src/browser/game_page_alignment_script.dart
```

预期：所有测试通过，分析结果无 error。

- [ ] **步骤 5：提交 PlatformView 接线**

```powershell
git add -- lib/src/game_webview.dart
git commit -m "fix(缩放): 加载中保持PlatformView画布状态"
```

### 任务 4：让原生 Activity 正确处理 `pending`

**文件：**
- 修改：`android/app/src/test/kotlin/app/yahagi/kancollebrowser/nativewebview/NativeGameWebViewConfiguratorTest.kt`
- 修改：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/nativewebview/NativeGameWebViewConfigurator.kt`
- 修改：`test/android_game_surface_recovery_test.dart`
- 修改：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/MainActivity.kt`

- [ ] **步骤 1：编写原生桥失败测试**

将桥接测试序列改为：

```kotlin
bridge.postMessage("game")
bridge.postMessage("pending")
bridge.postMessage("pending")
bridge.postMessage("game")
bridge.postMessage("web")

assertEquals(listOf(true, true, false), presentationStates)
```

这证明 `pending` 本身不调用平台动作，但会打破相邻两次 `game` 的去重，使新文档能够重新绑定。

在 Dart 静态测试中增加断言，确保 `onPageStarted()` 的生命周期回调体不再调用 `releaseFixedCanvasScaling`。

- [ ] **步骤 2：运行 Android 与 Flutter 测试并确认红灯**

运行：

```powershell
android\gradlew.bat -p android :app:testDebugUnitTest --tests "app.yahagi.kancollebrowser.nativewebview.NativeGameWebViewConfiguratorTest"
flutter test test/android_game_surface_recovery_test.dart
```

预期：Kotlin 测试因 `pending` 未被记录而失败；Dart 测试因页面开始仍释放缩放而失败。

- [ ] **步骤 3：实现原生三态去重和移除无条件释放**

桥接记录最后收到的合法字符串状态：

```kotlin
private var lastPresentationState: String? = null

@JavascriptInterface
fun postMessage(message: String) {
    if (message != "game" && message != "web" && message != "pending") return
    if (message == lastPresentationState) return
    lastPresentationState = message
    when (message) {
        "game" -> onPresentationStateChanged(true)
        "web" -> onPresentationStateChanged(false)
        "pending" -> Unit
    }
}
```

从 `MainActivity` 的 `NativeGameWebViewLifecycleObserver.onPageStarted()` 删除 `releaseFixedCanvasScaling(...)`，由后续明确状态控制缩放。

- [ ] **步骤 4：运行原生相关测试并确认绿灯**

运行：

```powershell
android\gradlew.bat -p android :app:testDebugUnitTest --tests "app.yahagi.kancollebrowser.nativewebview.NativeGameWebViewConfiguratorTest"
flutter test test/android_game_surface_recovery_test.dart
```

预期：全部通过。

- [ ] **步骤 5：提交原生桥接修复**

```powershell
git add -- android/app/src/main/kotlin/app/yahagi/kancollebrowser/MainActivity.kt android/app/src/main/kotlin/app/yahagi/kancollebrowser/nativewebview/NativeGameWebViewConfigurator.kt android/app/src/test/kotlin/app/yahagi/kancollebrowser/nativewebview/NativeGameWebViewConfiguratorTest.kt test/android_game_surface_recovery_test.dart
git commit -m "fix(缩放): 加载中保持原生画布状态"
```

### 任务 5：自动化回归、构建和无线真机验证

**文件：**
- 验证：上述所有修改文件
- 不修改：OOI 连接器、Cookie、缓存与捕获策略文件

- [ ] **步骤 1：运行定向 Flutter 回归**

```powershell
flutter test test/game_presentation_state_test.dart test/game_page_alignment_script_test.dart test/game_browser_controller_test.dart test/native_activity_game_surface_test.dart test/game_connector_controller_test.dart test/game_connector_section_test.dart test/game_navigation_policy_test.dart
```

预期：全部通过，OOI 页面零注入测试保持通过。

- [ ] **步骤 2：运行全量 Flutter 测试和静态分析**

```powershell
flutter test
flutter analyze
```

预期：测试无失败；分析无新增 error。既有 warning/info 单独记录，不通过修改无关文件消除。

- [ ] **步骤 3：运行 Android JVM 回归并构建 Debug APK**

```powershell
android\gradlew.bat -p android :app:testDebugUnitTest
flutter build apk --debug
```

预期：Android 测试和 Debug APK 构建成功，APK 位于 `build/app/outputs/flutter-apk/app-debug.apk`。

- [ ] **步骤 4：确认无线设备并安装 Debug APK**

```powershell
adb devices -l
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

预期：仅选择状态为 `device` 的目标，安装返回 `Success`。如存在多个设备，所有后续命令使用 `adb -s <serial>` 精确指定目标。

- [ ] **步骤 5：执行 Yahagi 官方链路多轮真机验证**

每种渲染模式至少执行登录页、进入游戏、刷新、前后台切换和手动适应屏幕；使用 `adb logcat` 与截图确认：

```text
登录页：accounts.dmm.*，DMM 表单完整，无固定游戏样式。
游戏页：app_id=854854 或官方游戏宿主，DMM 顶栏隐藏，画面比例 1200:720，底部无裁切。
加载中：状态 pending，不出现 releaseFixedCanvas 抖动。
恢复后：状态 game，固定缩放重新绑定。
```

四种模式分别记录结果：轻量、均衡、Canvas 兼容、原生独立。

- [ ] **步骤 6：执行 OOI 不变回归**

打开 OOI 连接，确认登录页模式 1/3/4 原样存在，应用不自动选择或提交；若进入 `/kancolle`，确认仍使用 `iframe#externalswf` 专用适配而非 DMM 固定画布。

- [ ] **步骤 7：检查最终差异和提交状态**

```powershell
git diff --check
git status --short
git log --oneline -6
```

预期：没有空白错误；仅保留用户原先的装备相关未提交文件；本修复的生产代码和测试均已提交在 `master`。
