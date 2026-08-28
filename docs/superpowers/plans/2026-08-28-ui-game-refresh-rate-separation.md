# UI 与游戏刷新率解耦实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 让 Flutter UI 请求当前屏幕支持的最高刷新率，同时保持游戏 CreateJS Ticker 仅使用 30/60 FPS，并允许 Android 因省电或温控降低实际刷新率。

**架构：** 新增纯 Kotlin `UiRefreshRatePolicy` 选择最大有效刷新率，由 `MainActivity` 在创建、恢复、配置变化和换屏时应用窗口偏好。删除 `GameFrameRateManager` 到 Activity 的 Host 回调，使游戏帧率管理器只控制 WebView 内的 CreateJS Ticker。

**技术栈：** Flutter、Dart、Android Kotlin、Android Display API、Flutter Test、JUnit 4、Gradle。

---

## 文件结构

- 创建 `android/app/src/main/kotlin/app/yahagi/kancollebrowser/UiRefreshRatePolicy.kt`：过滤无效刷新率并返回最大有效值。
- 创建 `android/app/src/test/kotlin/app/yahagi/kancollebrowser/UiRefreshRatePolicyTest.kt`：覆盖 60/90/120 Hz、乱序、重复和无效值。
- 创建 `test/android_ui_refresh_rate_contract_test.dart`：锁定 Activity 与游戏帧率管理器的解耦边界。
- 修改 `android/app/src/main/kotlin/app/yahagi/kancollebrowser/MainActivity.kt`：应用当前屏幕最高刷新率，并删除游戏模式回调。
- 修改 `android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameFrameRateManager.kt`：删除 Host 接口、构造参数和回调。

### 任务 1：实现 UI 最高刷新率选择策略

**文件：**

- 创建：`android/app/src/test/kotlin/app/yahagi/kancollebrowser/UiRefreshRatePolicyTest.kt`
- 创建：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/UiRefreshRatePolicy.kt`

- [ ] **步骤 1：编写失败的 Kotlin 单元测试**

创建测试：

```kotlin
package app.yahagi.kancollebrowser

import org.junit.Assert.assertEquals
import org.junit.Test

class UiRefreshRatePolicyTest {
    @Test
    fun selectsTheHighestSupportedRefreshRate() {
        assertEquals(60f, UiRefreshRatePolicy.highestSupported(listOf(60f)))
        assertEquals(90f, UiRefreshRatePolicy.highestSupported(listOf(60f, 90f)))
        assertEquals(
            120f,
            UiRefreshRatePolicy.highestSupported(listOf(120f, 60f, 90f, 120f)),
        )
    }

    @Test
    fun ignoresInvalidRefreshRates() {
        assertEquals(
            90f,
            UiRefreshRatePolicy.highestSupported(
                listOf(Float.NaN, Float.POSITIVE_INFINITY, -1f, 0f, 90f),
            ),
        )
    }

    @Test
    fun returnsNoPreferenceWhenNoValidRateExists() {
        assertEquals(
            0f,
            UiRefreshRatePolicy.highestSupported(
                listOf(Float.NaN, Float.NEGATIVE_INFINITY, -1f, 0f),
            ),
        )
        assertEquals(0f, UiRefreshRatePolicy.highestSupported(emptyList()))
    }
}
```

- [ ] **步骤 2：运行测试并确认红灯**

运行：

```powershell
android\gradlew.bat -p android :app:testDebugUnitTest --tests "app.yahagi.kancollebrowser.UiRefreshRatePolicyTest" --console=plain
```

预期：FAIL，Kotlin 编译报告 `Unresolved reference 'UiRefreshRatePolicy'`。

- [ ] **步骤 3：实现最小策略组件**

创建生产代码：

```kotlin
package app.yahagi.kancollebrowser

internal object UiRefreshRatePolicy {
    fun highestSupported(refreshRates: Iterable<Float>): Float =
        refreshRates
            .filter { it.isFinite() && it > 0f }
            .maxOrNull()
            ?: 0f
}
```

- [ ] **步骤 4：运行测试并确认绿灯**

运行任务 1 步骤 2 的同一命令。

预期：`BUILD SUCCESSFUL`，`UiRefreshRatePolicyTest` 全部通过。

- [ ] **步骤 5：提交刷新率选择策略**

```powershell
git add -- android/app/src/main/kotlin/app/yahagi/kancollebrowser/UiRefreshRatePolicy.kt android/app/src/test/kotlin/app/yahagi/kancollebrowser/UiRefreshRatePolicyTest.kt
git commit -m "feat(界面): 选择屏幕最高刷新率"
```

### 任务 2：解耦 Activity UI 与游戏帧率管理器

**文件：**

- 创建：`test/android_ui_refresh_rate_contract_test.dart`
- 修改：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/MainActivity.kt`
- 修改：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameFrameRateManager.kt`

- [ ] **步骤 1：编写失败的静态契约测试**

创建测试：

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final activityPath =
      'android/app/src/main/kotlin/app/yahagi/kancollebrowser/MainActivity.kt';
  final managerPath =
      'android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/'
      'GameFrameRateManager.kt';

  test('activity requests the current display highest refresh rate', () {
    final activity = File(activityPath).readAsStringSync();

    expect(activity, contains('UiRefreshRatePolicy.highestSupported'));
    expect(activity, contains('supportedModes'));
    expect(activity, contains('override fun onResume()'));
    expect(activity, contains('override fun onMovedToDisplay('));
    expect(activity, isNot(contains('preferredRefreshRate = 60f')));
  });

  test('game frame rate manager cannot change the activity refresh rate', () {
    final activity = File(activityPath).readAsStringSync();
    final manager = File(managerPath).readAsStringSync();

    expect(activity, isNot(contains('GameFrameRateManager.Host')));
    expect(activity, isNot(contains('onFrameRateModeChanged')));
    expect(manager, isNot(contains('interface Host')));
    expect(manager, isNot(contains('host.onFrameRateModeChanged')));
  });
}
```

- [ ] **步骤 2：运行契约测试并确认红灯**

运行：

```powershell
flutter test test/android_ui_refresh_rate_contract_test.dart
```

预期：FAIL，因为 Activity 仍固定使用 `60f`，并且 Manager 仍声明 Host 回调。

- [ ] **步骤 3：让 Activity 应用当前屏幕最高刷新率**

从 `MainActivity` 的接口列表删除 `GameFrameRateManager.Host`，并删除不再使用的
`GameFrameRateMode` import。

在 `onCreate` 末尾应用 UI 偏好：

```kotlin
applyPreferredUiRefreshRate()
```

增加恢复、配置变化和换屏处理：

```kotlin
override fun onResume() {
    super.onResume()
    applyPreferredUiRefreshRate()
}

override fun onConfigurationChanged(newConfig: Configuration) {
    super.onConfigurationChanged(newConfig)
    gameSurfaceRecoveryTrigger.onConfigurationChanged()
    applyPreferredUiRefreshRate()
}

@androidx.annotation.RequiresApi(Build.VERSION_CODES.O)
override fun onMovedToDisplay(displayId: Int, config: Configuration) {
    super.onMovedToDisplay(displayId, config)
    applyPreferredUiRefreshRate()
}
```

新增私有方法，并删除原有 `onFrameRateModeChanged`：

```kotlin
private fun applyPreferredUiRefreshRate() {
    val refreshRates = window.decorView.display
        ?.supportedModes
        ?.map { mode -> mode.refreshRate }
        .orEmpty()
    val preferredRefreshRate = UiRefreshRatePolicy.highestSupported(refreshRates)
    val attributes = window.attributes
    if (attributes.preferredRefreshRate == preferredRefreshRate) return
    attributes.preferredRefreshRate = preferredRefreshRate
    window.attributes = attributes
}
```

将 Manager 创建代码改为：

```kotlin
val frameRateManager = GameFrameRateManager(
    GameFrameRateBridge(this),
    AndroidGameFrameRateSystemConstraints(this),
)
```

- [ ] **步骤 4：删除游戏 Manager 的窗口 Host 边界**

将 Manager 构造函数改为：

```kotlin
class GameFrameRateManager(
    private val bridge: GameFrameRateBridge,
    private val systemConstraints: GameFrameRateSystemConstraintSource,
) : MethodChannel.MethodCallHandler {
```

删除内部 `Host` 接口，并从 `configure` 成功分支删除：

```kotlin
host.onFrameRateModeChanged(mode)
```

游戏目标、系统省电／温控策略和 Bridge 脚本保持不变。

- [ ] **步骤 5：格式化 Kotlin 文件**

运行：

```powershell
dart format test/android_ui_refresh_rate_contract_test.dart
```

Kotlin 文件保持现有 4 空格缩进和项目换行风格，不运行会重写整个文件的批量格式化。

- [ ] **步骤 6：运行定向测试并确认绿灯**

运行：

```powershell
flutter test test/android_ui_refresh_rate_contract_test.dart test/game_frame_rate_runtime_controller_test.dart test/game_frame_rate_script_test.dart
android\gradlew.bat -p android :app:testDebugUnitTest --tests "app.yahagi.kancollebrowser.UiRefreshRatePolicyTest" --tests "app.yahagi.kancollebrowser.browser.GameFrameRateScriptTest" --tests "app.yahagi.kancollebrowser.browser.GameFrameRateSystemConstraintsTest" --console=plain
```

预期：Flutter 测试全部通过，Gradle 输出 `BUILD SUCCESSFUL`。

- [ ] **步骤 7：提交解耦实现**

```powershell
git add -- test/android_ui_refresh_rate_contract_test.dart android/app/src/main/kotlin/app/yahagi/kancollebrowser/MainActivity.kt android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameFrameRateManager.kt
git commit -m "perf(界面): 解耦 UI 与游戏刷新率"
```

### 任务 3：全量验证并生成 Debug APK

**文件：**

- 验证：任务 1 和任务 2 涉及的全部文件。
- 产物：`build/app/outputs/flutter-apk/app-debug.apk`。

- [ ] **步骤 1：运行 Flutter 全量测试**

运行：

```powershell
flutter test
```

预期：测试失败数为 0；已有明确跳过项可以保留。

- [ ] **步骤 2：运行 Android 全量单元测试**

运行：

```powershell
android\gradlew.bat -p android :app:testDebugUnitTest --console=plain
```

预期：`BUILD SUCCESSFUL`。

- [ ] **步骤 3：运行静态分析**

运行：

```powershell
flutter analyze
```

预期：无 error；若仓库存在既有 warning 或 info，记录数量并确认不来自本次文件。

- [ ] **步骤 4：检查刷新率边界和工作区**

运行：

```powershell
rg -n -S "preferredRefreshRate = 60f|GameFrameRateManager\.Host|onFrameRateModeChanged" android/app/src/main test
git diff --check HEAD
git status --short
```

预期：`rg` 无匹配；Git 没有未提交的实现改动；`git diff --check` 无空白错误。

- [ ] **步骤 5：构建 Debug APK**

运行：

```powershell
flutter build apk --debug
```

预期：构建成功并生成 `build/app/outputs/flutter-apk/app-debug.apk`。

- [ ] **步骤 6：核对 APK 信息且不安装**

运行：

```powershell
Get-Item build/app/outputs/flutter-apk/app-debug.apk | Select-Object FullName,Length,LastWriteTime
Get-FileHash build/app/outputs/flutter-apk/app-debug.apk -Algorithm SHA256
```

预期：文件存在且散列成功。不得运行 `adb install`、`flutter install`、`flutter run`、
`am force-stop`、`pm clear` 或任何手机控制命令。

- [ ] **步骤 7：报告结果**

报告以下内容：

- UI 刷新率与游戏 30/60 FPS 的最终边界。
- Flutter 测试、Android 单元测试和静态分析结果。
- Debug APK 的绝对路径、大小、修改时间和 SHA-256。
- 明确说明未安装、未重启、未操作用户手机上的游戏。
