# 保守帧率模式实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 删除未限速高刷模式，使“自动”和“低耗”均不再改写舰 C 的 `main.js`，并将历史高刷配置迁移为自动。

**架构：** Flutter 层只保留自动与固定 30 帧两种模式，运行控制器只发送 `fps60`/`fps30`；Android Bridge 继续在文档内保守设置 CreateJS Ticker，但删除主脚本拦截补丁与屏幕高刷请求。历史 wire 值在读取边界统一映射为自动，避免升级失败。

**技术栈：** Flutter/Dart、Android Kotlin、AndroidX WebKit、SharedPreferences、Flutter Test、JUnit 4、Gradle。

---

## 文件结构

- 修改 `lib/src/settings/game_frame_rate_settings.dart`：收敛模式枚举并迁移历史高刷设置。
- 修改 `lib/src/settings/game_frame_rate_settings_section.dart`：设置页只显示自动与低耗。
- 修改 `lib/src/browser/game_frame_rate_policy.dart`：删除高刷专用决策。
- 修改 `lib/src/browser/game_frame_rate_runtime_controller.dart`：删除高刷运行目标。
- 修改 `lib/src/browser/game_frame_rate_script.dart`：只生成 30/60 帧脚本。
- 修改 `lib/l10n/app_zh.arb`、`app_zh_Hant.arb`、`app_ja.arb`：删除高刷文案。
- 重新生成 `lib/l10n/app_localizations*.dart`：同步本地化接口。
- 修改对应 `test/game_frame_rate_*_test.dart` 与 `test/localization_resource_audit_test.dart`：锁定迁移、UI 和运行行为。
- 修改 `android/.../GameFrameRateManager.kt`：只接受自动与低耗模式。
- 修改 `android/.../GameFrameRateBridge.kt`：只接受 30/60 帧目标。
- 修改 `android/.../GameFrameRateSystemConstraints.kt`：删除高刷防御分支。
- 删除 `android/.../GameFrameRateScript.kt`：彻底移除 `main.js` 帧率补丁与下载器。
- 修改 `android/.../GadgetBypassWebViewClient.kt`：删除帧率补丁拦截路径。
- 修改 `android/.../MainActivity.kt`：删除高刷屏幕请求以及为帧率补丁包装 WebViewClient 的逻辑。
- 修改、重命名 Android 帧率测试：验证历史模式回退、Bridge 不含 RAF 高刷路径以及系统约束。

### 任务 1：收敛 Flutter 设置模式与历史迁移

**文件：**
- 修改：`test/game_frame_rate_settings_test.dart`
- 修改：`lib/src/settings/game_frame_rate_settings.dart`

- [ ] **步骤 1：先把迁移测试改成保守期望**

将旧布尔值和旧字符串的期望改为：

```dart
for (final entry in <bool, GameFrameRateMode>{
  true: GameFrameRateMode.automatic,
  false: GameFrameRateMode.stable30,
}.entries) {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'game.unlockFrameRate': entry.key,
  });
  final store = SharedPreferencesGameFrameRateSettingsStore();
  expect(await store.loadMode(), entry.value);
}

for (final entry in <String, GameFrameRateMode>{
  'max60': GameFrameRateMode.automatic,
  'followDisplay': GameFrameRateMode.automatic,
  'off': GameFrameRateMode.stable30,
}.entries) {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'game.frameRateMode': entry.key,
  });
  final store = SharedPreferencesGameFrameRateSettingsStore();
  expect(await store.loadMode(), entry.value);
}

test('removed high refresh wire value falls back to automatic', () {
  expect(
    GameFrameRateMode.fromWireName('prefer60'),
    GameFrameRateMode.automatic,
  );
});
```

删除直接构造或断言 `GameFrameRateMode.highRefresh` 的控制器测试，只保留自动与低耗的持久化、排队和失败回退测试。

- [ ] **步骤 2：运行设置测试并确认红灯**

运行：

```powershell
flutter test test/game_frame_rate_settings_test.dart
```

预期：至少一个迁移断言失败，因为旧布尔 `true` 或 `followDisplay` 仍返回 `highRefresh`。

- [ ] **步骤 3：实现两模式枚举与迁移**

将枚举和迁移分支收敛为：

```dart
enum GameFrameRateMode {
  automatic('auto'),
  stable30('stable30');

  const GameFrameRateMode(this.wireName);
  final String wireName;

  static GameFrameRateMode fromWireName(String? value) {
    return values.firstWhere(
      (mode) => mode.wireName == value,
      orElse: () => GameFrameRateMode.automatic,
    );
  }
}
```

旧配置迁移使用：

```dart
oldBoolean ? GameFrameRateMode.automatic : GameFrameRateMode.stable30
```

以及：

```dart
final legacyMode = switch (preferences.getString(_legacyModeKey)) {
  'max60' || 'followDisplay' => GameFrameRateMode.automatic,
  'off' => GameFrameRateMode.stable30,
  _ => null,
};
```

- [ ] **步骤 4：运行设置测试并确认绿灯**

运行：`flutter test test/game_frame_rate_settings_test.dart`

预期：PASS。

- [ ] **步骤 5：提交设置迁移**

```powershell
git add -- lib/src/settings/game_frame_rate_settings.dart test/game_frame_rate_settings_test.dart
git commit -m "fix(帧率): 将历史高刷设置迁移为自动"
```

### 任务 2：删除 Flutter 高刷 UI、策略和脚本目标

**文件：**
- 修改：`test/game_frame_rate_settings_section_test.dart`
- 修改：`test/game_frame_rate_policy_test.dart`
- 修改：`test/game_frame_rate_runtime_controller_test.dart`
- 修改：`test/game_frame_rate_script_test.dart`
- 修改：`lib/src/settings/game_frame_rate_settings_section.dart`
- 修改：`lib/src/browser/game_frame_rate_policy.dart`
- 修改：`lib/src/browser/game_frame_rate_runtime_controller.dart`
- 修改：`lib/src/browser/game_frame_rate_script.dart`

- [ ] **步骤 1：先把 UI 与运行测试改成两档期望**

设置界面测试要求：

```dart
expect(find.text('自动'), findsOneWidget);
expect(find.text('低耗'), findsOneWidget);
expect(find.text('高刷'), findsNothing);
expect(
  tester.widget<SegmentedButton<GameFrameRateMode>>(
    find.byType<SegmentedButton<GameFrameRateMode>>(),
  ).segments,
  hasLength(2),
);
```

脚本测试只遍历：

```dart
final scripts = <String>[
  gameFrameRateApplyScript(GameFrameRateTarget.fps30),
  gameFrameRateApplyScript(GameFrameRateTarget.fps60),
  gameFrameRateMeasurementScript,
];
```

运行控制器测试删除高刷用例，并保留以下期望：自动前台应用 `fps60`、后台应用 `fps30`、低耗前台应用 `fps30`、自动持续不稳定后降至 `fps30`。

- [ ] **步骤 2：运行四组测试并确认红灯或编译失败**

运行：

```powershell
flutter test test/game_frame_rate_settings_section_test.dart test/game_frame_rate_policy_test.dart test/game_frame_rate_runtime_controller_test.dart test/game_frame_rate_script_test.dart
```

预期：FAIL；设置页仍有第三个分段，生产枚举和脚本仍包含高刷。

- [ ] **步骤 3：实现最少的两档 UI 与策略**

设置组件的 segments 只保留：

```dart
ButtonSegment<GameFrameRateMode>(
  value: GameFrameRateMode.automatic,
  label: Text(l10n.gameFrameRateAutomatic),
),
ButtonSegment<GameFrameRateMode>(
  value: GameFrameRateMode.stable30,
  label: Text(l10n.gameFrameRatePowerSaving),
),
```

`GameFrameRateTarget` 改为：

```dart
enum GameFrameRateTarget { fps30, fps60 }
```

模式选择只保留：

```dart
final target = switch (settings.mode) {
  GameFrameRateMode.stable30 => GameFrameRateTarget.fps30,
  GameFrameRateMode.automatic when policy.isLockedTo30 =>
    GameFrameRateTarget.fps30,
  GameFrameRateMode.automatic => GameFrameRateTarget.fps60,
};
```

删除策略中的 `highRefresh` 提前返回和脚本生成器中的未限速 `RAF` 分支。

- [ ] **步骤 4：运行四组测试并确认绿灯**

运行任务 2 步骤 2 的同一命令。

预期：PASS。

- [ ] **步骤 5：提交 Flutter 运行行为**

```powershell
git add -- lib/src/settings/game_frame_rate_settings_section.dart lib/src/browser/game_frame_rate_policy.dart lib/src/browser/game_frame_rate_runtime_controller.dart lib/src/browser/game_frame_rate_script.dart test/game_frame_rate_settings_section_test.dart test/game_frame_rate_policy_test.dart test/game_frame_rate_runtime_controller_test.dart test/game_frame_rate_script_test.dart
git commit -m "refactor(帧率): 移除高刷界面与运行目标"
```

### 任务 3：删除高刷本地化资源

**文件：**
- 修改：`lib/l10n/app_zh.arb`
- 修改：`lib/l10n/app_zh_Hant.arb`
- 修改：`lib/l10n/app_ja.arb`
- 修改：`lib/l10n/app_localizations.dart`
- 修改：`lib/l10n/app_localizations_zh.dart`
- 修改：`lib/l10n/app_localizations_ja.dart`
- 修改：`test/localization_resource_audit_test.dart`

- [ ] **步骤 1：先更新本地化审计测试**

从允许共享的产品短标签集合删除 `gameFrameRateHighRefresh`，并新增扫描断言：

```dart
for (final path in <String>[
  'lib/l10n/app_zh.arb',
  'lib/l10n/app_zh_Hant.arb',
  'lib/l10n/app_ja.arb',
]) {
  final text = File(path).readAsStringSync();
  expect(text, isNot(contains('gameFrameRateHighRefresh')));
}
```

- [ ] **步骤 2：运行审计测试并确认红灯**

运行：`flutter test test/localization_resource_audit_test.dart`

预期：FAIL，因为 ARB 仍包含高刷键。

- [ ] **步骤 3：删除 ARB 高刷键并重新生成代码**

从三份 ARB 删除：

```text
gameFrameRateHighRefresh
gameFrameRateHighRefreshDesc
```

运行：

```powershell
flutter gen-l10n
```

预期：生成的本地化接口和实现不再包含这两个 getter。

- [ ] **步骤 4：运行 UI 与审计测试**

运行：

```powershell
flutter test test/game_frame_rate_settings_section_test.dart test/localization_resource_audit_test.dart
```

预期：PASS。

- [ ] **步骤 5：提交本地化清理**

```powershell
git add -- lib/l10n test/localization_resource_audit_test.dart
git commit -m "refactor(本地化): 删除高刷模式文案"
```

### 任务 4：删除 Android 高刷和 `main.js` 帧率补丁

**文件：**
- 修改：`android/app/src/test/kotlin/app/yahagi/kancollebrowser/browser/GameFrameRateScriptTest.kt`
- 修改：`android/app/src/test/kotlin/app/yahagi/kancollebrowser/browser/GameFrameRateSystemConstraintsTest.kt`
- 修改：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameFrameRateManager.kt`
- 修改：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameFrameRateBridge.kt`
- 修改：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameFrameRateSystemConstraints.kt`
- 删除：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameFrameRateScript.kt`
- 修改：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GadgetBypassWebViewClient.kt`
- 修改：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/MainActivity.kt`

- [ ] **步骤 1：先把 Android 测试改成保守期望**

模式解析测试使用：

```kotlin
assertEquals(GameFrameRateMode.AUTO, GameFrameRateMode.fromWireName("auto"))
assertEquals(GameFrameRateMode.STABLE_30, GameFrameRateMode.fromWireName("stable30"))
assertEquals(GameFrameRateMode.AUTO, GameFrameRateMode.fromWireName("prefer60"))
assertEquals(GameFrameRateMode.AUTO, GameFrameRateMode.fromWireName("future-mode"))
```

Bridge 测试使用：

```kotlin
val script = GameFrameRateBridgeScript.source
assertTrue(script.contains("ticker.RAF_SYNCHED"))
assertTrue(script.contains("ticker.TIMEOUT"))
assertFalse(script.contains("highRefresh"))
assertFalse(script.contains("ticker.RAF;"))
assertFalse(script.contains("fetch("))
assertFalse(script.contains("XMLHttpRequest"))
```

系统约束测试删除所有 `HIGH_REFRESH` 输入，仅验证自动在省电/发热时转为 `FPS_30`、正常时保持 `FPS_60`，低耗目标保持 `FPS_30`。

- [ ] **步骤 2：运行 Android 帧率测试并确认红灯**

运行：

```powershell
android\gradlew.bat -p android :app:testDebugUnitTest --tests "app.yahagi.kancollebrowser.browser.GameFrameRateScriptTest" --tests "app.yahagi.kancollebrowser.browser.GameFrameRateSystemConstraintsTest" --console=plain
```

预期：FAIL，因为 `prefer60` 仍解析为高刷且 Bridge 仍包含 `highRefresh`/`RAF`。

- [ ] **步骤 3：收敛 Android 枚举与 Bridge**

模式与目标改成：

```kotlin
enum class GameFrameRateMode(val wireName: String) {
    AUTO("auto"),
    STABLE_30("stable30");
}

enum class GameFrameRateTarget(val wireName: String) {
    FPS_30("fps30"),
    FPS_60("fps60");
}
```

Bridge 的 JavaScript 只保留 `fps30` 与 `fps60` 分支；`initialTarget` 只返回 `FPS_30` 或 `FPS_60`。系统策略直接在自动节能时返回 `FPS_30`，否则返回请求目标。

- [ ] **步骤 4：移除 `main.js` 拦截路径与屏幕高刷请求**

删除 `GameFrameRateScript.kt`。从 `GadgetBypassWebViewClient` 构造函数删除 `mainScriptTickerMode`、`mainScriptFetcher`，并删除两个 `shouldInterceptRequest` 中的帧率补丁分支及 `servePatchedMainScript`。

`MainActivity.onFrameRateModeChanged` 只保留 60 Hz 首选值：

```kotlin
override fun onFrameRateModeChanged(mode: GameFrameRateMode) {
    val attributes = window.attributes
    if (attributes.preferredRefreshRate != 60f) {
        attributes.preferredRefreshRate = 60f
        window.attributes = attributes
    }
}
```

同时从 WebViewClient 包装/恢复判断中删除 `mainScriptTickerMode` 条件和构造参数，使包装仅由 gadget bypass 或资源缓存决定。

- [ ] **步骤 5：运行 Android 帧率测试并确认绿灯**

运行任务 4 步骤 2 的同一命令。

预期：PASS。

- [ ] **步骤 6：静态扫描确认没有帧率 `main.js` 补丁**

运行：

```powershell
rg -n -S "HIGH_REFRESH|highRefresh|GameMainScriptTickerMode|GameMainScriptPatcher|GameMainScriptFetcher|mainScriptTickerMode|createjs\.Ticker\.RAF," android/app/src/main android/app/src/test
```

预期：无匹配；命令退出码为 1。

- [ ] **步骤 7：提交 Android 清理**

```powershell
git add -- android/app/src/main/kotlin/app/yahagi/kancollebrowser/MainActivity.kt android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser android/app/src/test/kotlin/app/yahagi/kancollebrowser/browser
git commit -m "refactor(安卓): 删除高刷与主脚本补丁"
```

### 任务 5：全量验证并生成 Debug APK

**文件：**
- 验证：本计划涉及的全部文件
- 产物：`build/app/outputs/flutter-apk/app-debug.apk`

- [ ] **步骤 1：格式化本次 Dart 文件**

```powershell
dart format lib/src/settings/game_frame_rate_settings.dart lib/src/settings/game_frame_rate_settings_section.dart lib/src/browser/game_frame_rate_policy.dart lib/src/browser/game_frame_rate_runtime_controller.dart lib/src/browser/game_frame_rate_script.dart test/game_frame_rate_settings_test.dart test/game_frame_rate_settings_section_test.dart test/game_frame_rate_policy_test.dart test/game_frame_rate_runtime_controller_test.dart test/game_frame_rate_script_test.dart test/localization_resource_audit_test.dart
```

预期：命令成功。

- [ ] **步骤 2：运行 Flutter 全量测试**

运行：`flutter test`

预期：全部测试通过；跳过项可保留，失败数为 0。

- [ ] **步骤 3：运行 Android 全量单元测试**

运行：

```powershell
android\gradlew.bat -p android :app:testDebugUnitTest --console=plain
```

预期：`BUILD SUCCESSFUL`。

- [ ] **步骤 4：运行静态分析**

运行：`flutter analyze`

预期：无本次改动引入的新错误；若仓库存在既有 warning/info，记录数量并确认不涉及本次文件。

- [ ] **步骤 5：扫描已删除能力**

```powershell
rg -n -S "prefer60|highRefresh|HIGH_REFRESH|gameFrameRateHighRefresh|GameMainScriptPatcher|GameMainScriptFetcher|mainScriptTickerMode" lib test android/app/src/main android/app/src/test
```

预期：除了明确用于历史迁移测试的 `prefer60`/`highRefresh` 文本外，不存在生产代码匹配。

- [ ] **步骤 6：构建 Debug APK**

运行：`flutter build apk --debug`

预期：构建成功，产物位于 `build/app/outputs/flutter-apk/app-debug.apk`。

- [ ] **步骤 7：检查工作区和最终差异**

```powershell
git status --short
git diff --check HEAD
git diff --stat HEAD
```

预期：只看到用户原有未提交文件，以及本计划尚未提交的必要变更；无空白错误。

不得暂存用户原有的捕获、状态归约或触摸反馈文件。
