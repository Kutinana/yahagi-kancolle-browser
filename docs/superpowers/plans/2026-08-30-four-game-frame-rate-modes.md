# 游戏四档帧率模式实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 将游戏帧率设置扩展为自动、60 帧、30 帧和高刷四档，并在进入不自动降档的运行时高刷前显示账号与设备风险确认。

**架构：** Flutter 设置模型持久化四个用户模式，运行控制器把模式映射为 `fps30`、`fps60` 或 `highRefresh` 三个运行目标。Android 文档开始阶段注入的 `YahagiFrameRate` Bridge 负责直接调整 CreateJS Ticker；高刷只设置裸 `RAF`，不恢复 `main.js` 拦截。自动档保留现有性能、省电和温度策略，三个手动档不被 Yahagi 主动改写。

**技术栈：** Flutter、Dart、Material 3、SharedPreferences、Flutter gen-l10n、Kotlin、AndroidX WebKit、JUnit 4。

---

## 文件结构

- 修改 `lib/src/settings/game_frame_rate_settings.dart`：定义四档设置值及历史配置迁移。
- 修改 `test/game_frame_rate_settings_test.dart`：覆盖四档往返、历史高刷安全迁移和串行保存。
- 修改 `lib/src/browser/game_frame_rate_runtime_controller.dart`：定义高刷运行目标及自动／手动生命周期策略。
- 修改 `lib/src/browser/game_frame_rate_policy.dart`：保证性能策略只控制自动档。
- 修改 `lib/src/browser/game_frame_rate_script.dart`：为非原生 WebView 端口生成裸 `RAF` 脚本。
- 修改 `lib/src/browser/game_frame_rate_port.dart`：沿用枚举名称发送 `highRefresh`，不新增协议转换层。
- 修改 `test/game_frame_rate_runtime_controller_test.dart`、`test/game_frame_rate_policy_test.dart`、`test/game_frame_rate_script_test.dart`：覆盖三个运行目标和手动档不降档。
- 修改 `lib/src/settings/game_frame_rate_settings_section.dart`：显示四档并承载高刷风险确认。
- 修改 `lib/l10n/app_zh.arb`、`lib/l10n/app_zh_Hant.arb`、`lib/l10n/app_ja.arb`：增加四档说明和风险弹窗文案。
- 重新生成 `lib/l10n/app_localizations*.dart`：同步本地化接口。
- 修改 `test/game_frame_rate_settings_section_test.dart`、`test/localization_resource_audit_test.dart`：覆盖四档 UI、确认／取消和本地化键集合。
- 修改 `android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameFrameRateBridge.kt`：解析并应用 `highRefresh`。
- 修改 `android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameFrameRateManager.kt`：解析四个设置模式并映射初始目标。
- 修改 `android/app/src/test/kotlin/app/yahagi/kancollebrowser/browser/GameFrameRateScriptTest.kt`：锁定运行时裸 `RAF`，并禁止网络或事件注入。
- 修改 `android/app/src/test/kotlin/app/yahagi/kancollebrowser/browser/GameFrameRateSystemConstraintsTest.kt`：证明系统约束只覆盖自动档。
- 修改 `test/native_activity_game_surface_test.dart`：覆盖手动 60 与高刷跨生命周期保持目标。

### 任务 1：扩展四档设置模型与安全迁移

**文件：**

- 修改：`lib/src/settings/game_frame_rate_settings.dart:4-65`
- 测试：`test/game_frame_rate_settings_test.dart:10-72`

- [ ] **步骤 1：先写四档解析与迁移失败测试**

在 `test/game_frame_rate_settings_test.dart` 中把枚举往返测试固定为四个值，并保留历史高刷回退自动的断言：

```dart
test('all four modes round-trip and unknown values use automatic', () async {
  final store = SharedPreferencesGameFrameRateSettingsStore();
  expect(GameFrameRateMode.values, <GameFrameRateMode>[
    GameFrameRateMode.automatic,
    GameFrameRateMode.stable60,
    GameFrameRateMode.stable30,
    GameFrameRateMode.highRefresh,
  ]);
  for (final mode in GameFrameRateMode.values) {
    await store.saveMode(mode);
    expect(await store.loadMode(), mode);
  }

  SharedPreferences.setMockInitialValues(<String, Object>{
    'game.frameRateMode.v2': 'future-mode',
  });
  expect(
    await SharedPreferencesGameFrameRateSettingsStore().loadMode(),
    GameFrameRateMode.automatic,
  );
});

test('historical high refresh values still require explicit consent', () {
  expect(GameFrameRateMode.fromWireName('prefer60'), GameFrameRateMode.automatic);
});
```

在旧字符串迁移表中继续断言 `followDisplay → automatic`，不要把历史值静默恢复为高刷。

- [ ] **步骤 2：运行设置测试并确认因缺少枚举值失败**

运行：

```powershell
flutter test test/game_frame_rate_settings_test.dart
```

预期：编译失败，提示 `stable60` 或 `highRefresh` 未定义。

- [ ] **步骤 3：添加四档枚举值**

将设置枚举改为：

```dart
enum GameFrameRateMode {
  automatic('auto'),
  stable60('stable60'),
  stable30('stable30'),
  highRefresh('highRefresh');

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

保持现有迁移规则：旧布尔 `true`、`max60`、`followDisplay` 和旧 wire value
`prefer60` 均回退自动；`false` 与 `off` 迁移为 30 帧。不要更换
`game.frameRateMode.v2` 存储键。

- [ ] **步骤 4：补充控制器四档串行应用测试**

扩展现有控制器测试，使端口依次收到：

```dart
expect(port.configuredModes, <GameFrameRateMode>[
  GameFrameRateMode.automatic,
  GameFrameRateMode.stable60,
  GameFrameRateMode.stable30,
  GameFrameRateMode.highRefresh,
]);
```

测试中按相同顺序 `await controller.setMode(...)`，确保保存和端口配置均能处理新增模式。

- [ ] **步骤 5：格式化并运行设置测试**

运行：

```powershell
dart format lib/src/settings/game_frame_rate_settings.dart test/game_frame_rate_settings_test.dart
flutter test test/game_frame_rate_settings_test.dart
```

预期：全部通过。

- [ ] **步骤 6：提交设置模型**

```powershell
git add -- lib/src/settings/game_frame_rate_settings.dart test/game_frame_rate_settings_test.dart
git commit -m "feat(帧率): 添加四档设置模型"
```

### 任务 2：实现三个运行目标和手动档不降档

**文件：**

- 修改：`lib/src/browser/game_frame_rate_runtime_controller.dart:8-174`
- 修改：`lib/src/browser/game_frame_rate_policy.dart:22-76`
- 修改：`lib/src/browser/game_frame_rate_script.dart:3-26`
- 验证：`lib/src/browser/game_frame_rate_port.dart:49-59`
- 测试：`test/game_frame_rate_runtime_controller_test.dart`
- 测试：`test/game_frame_rate_policy_test.dart`
- 测试：`test/game_frame_rate_script_test.dart`

- [ ] **步骤 1：先写高刷脚本失败测试**

在 `test/game_frame_rate_script_test.dart` 增加：

```dart
test('high refresh script uses uncapped CreateJS RAF', () {
  final script = gameFrameRateApplyScript(GameFrameRateTarget.highRefresh);
  expect(script, contains('ticker.timingMode=ticker.RAF;'));
  expect(script, isNot(contains('framerate=60')));
  expect(script, isNot(contains('RAF_SYNCHED')));
});
```

把 `highRefresh` 脚本加入禁止 `fetch`、`XMLHttpRequest`、合成点击和事件派发的脚本集合。

- [ ] **步骤 2：先写固定 60 与高刷不降档失败测试**

让 `_Fixture.create` 接受初始模式：

```dart
static Future<_Fixture> create({
  GameFrameRateMode mode = GameFrameRateMode.automatic,
  List<double> measurements = const <double>[],
}) async {
  final settings = await GameFrameRateSettingsController.load(
    MemoryGameFrameRateSettingsStore(mode),
  );
  // 保留其余现有装配代码。
}
```

增加两个生命周期测试：

```dart
for (final entry in <GameFrameRateMode, GameFrameRateTarget>{
  GameFrameRateMode.stable60: GameFrameRateTarget.fps60,
  GameFrameRateMode.highRefresh: GameFrameRateTarget.highRefresh,
}.entries) {
  test('${entry.key.name} keeps its target across lifecycle changes', () async {
    final fixture = await _Fixture.create(mode: entry.key);
    addTearDown(fixture.dispose);
    await fixture.runtime.onPageReady();
    expect(fixture.port.appliedTargets.last, entry.value);

    fixture.runtime.onLifecycleChanged(AppLifecycleState.paused);
    await fixture.runtime.idle;
    expect(fixture.port.appliedTargets.last, entry.value);

    fixture.runtime.onLifecycleChanged(AppLifecycleState.resumed);
    await fixture.runtime.idle;
    expect(fixture.port.appliedTargets.last, entry.value);
  });
}
```

保留自动档后台降至 30、回前台恢复 60 的现有测试。

- [ ] **步骤 3：先写性能策略只控制自动档的失败测试**

在 `test/game_frame_rate_policy_test.dart` 增加：

```dart
test('manual 60 and high refresh ignore unstable samples', () {
  for (final mode in <GameFrameRateMode>[
    GameFrameRateMode.stable60,
    GameFrameRateMode.highRefresh,
  ]) {
    final policy = GameFrameRatePolicy(mode: mode);
    _addUnstableCreateJsWindow(policy);
    _addUnstableFlutterWindow(policy);
    expect(policy.completeWindow(), FrameRateDecision.keep60);
    expect(policy.isLockedTo30, isFalse);
  }
});
```

- [ ] **步骤 4：运行三组测试并确认红灯**

运行：

```powershell
flutter test test/game_frame_rate_script_test.dart test/game_frame_rate_policy_test.dart test/game_frame_rate_runtime_controller_test.dart
```

预期：因 `GameFrameRateTarget.highRefresh` 及新增模式分支缺失而失败。

- [ ] **步骤 5：实现运行目标和脚本**

把运行目标扩展为：

```dart
enum GameFrameRateTarget { fps30, fps60, highRefresh }
```

在 `gameFrameRateApplyScript` 的 switch 中增加：

```dart
GameFrameRateTarget.highRefresh =>
  '''
  if (typeof ticker.RAF !== 'undefined') ticker.timingMode=ticker.RAF;
''',
```

`MethodChannelGameFrameRateRuntimePort` 已发送 `target.name`，因此会自然发送
`highRefresh`；只需用测试确认，不增加重复映射。

- [ ] **步骤 6：实现自动／手动运行策略**

`_applySelectedMode` 使用完整映射：

```dart
final target = switch (settings.mode) {
  GameFrameRateMode.stable60 => GameFrameRateTarget.fps60,
  GameFrameRateMode.stable30 => GameFrameRateTarget.fps30,
  GameFrameRateMode.highRefresh => GameFrameRateTarget.highRefresh,
  GameFrameRateMode.automatic when policy.isLockedTo30 =>
    GameFrameRateTarget.fps30,
  GameFrameRateMode.automatic => GameFrameRateTarget.fps60,
};
```

把生命周期目标选择改为仅自动档在后台主动请求 30 FPS：

```dart
Future<void> _applyCurrentLifecycleTarget() =>
    !_foreground && settings.mode == GameFrameRateMode.automatic
        ? _applyBackgroundTarget()
        : _applySelectedMode();
```

从 `_applySelectedMode` 的前置条件中删除 `!_foreground`，使手动档在进入后台和恢复
前台时都重新发送自身目标。保留 `_canSample` 的 `_foreground` 与 `automatic` 限制，
三个手动档不得启动性能采样或性能降档。

在 `GameFrameRatePolicy.completeWindow` 中显式处理：30 帧返回 `lock30`；60 帧与高刷
清空窗口后返回 `keep60`；只有自动档累计不稳定窗口。

- [ ] **步骤 7：格式化并运行定向测试**

运行：

```powershell
dart format lib/src/browser/game_frame_rate_runtime_controller.dart lib/src/browser/game_frame_rate_policy.dart lib/src/browser/game_frame_rate_script.dart test/game_frame_rate_runtime_controller_test.dart test/game_frame_rate_policy_test.dart test/game_frame_rate_script_test.dart
flutter test test/game_frame_rate_script_test.dart test/game_frame_rate_policy_test.dart test/game_frame_rate_runtime_controller_test.dart
```

预期：全部通过；自动档生命周期测试仍为后台 30、前台 60，两个手动档保持自身目标。

- [ ] **步骤 8：提交运行策略**

```powershell
git add -- lib/src/browser/game_frame_rate_runtime_controller.dart lib/src/browser/game_frame_rate_policy.dart lib/src/browser/game_frame_rate_script.dart test/game_frame_rate_runtime_controller_test.dart test/game_frame_rate_policy_test.dart test/game_frame_rate_script_test.dart
git commit -m "feat(帧率): 添加固定 60 与运行时高刷目标"
```

### 任务 3：实现四档设置界面和高刷风险确认

**文件：**

- 修改：`lib/src/settings/game_frame_rate_settings_section.dart`
- 修改：`lib/l10n/app_zh.arb:463-468`
- 修改：`lib/l10n/app_zh_Hant.arb:463-468`
- 修改：`lib/l10n/app_ja.arb:463-468`
- 生成：`lib/l10n/app_localizations.dart`
- 生成：`lib/l10n/app_localizations_zh.dart`
- 生成：`lib/l10n/app_localizations_ja.dart`
- 测试：`test/game_frame_rate_settings_section_test.dart`
- 测试：`test/localization_resource_audit_test.dart:60-77`

- [ ] **步骤 1：先写四档界面失败测试**

把原来的两档测试改成：

```dart
expect(find.text('自动'), findsOneWidget);
expect(find.text('60 帧'), findsOneWidget);
expect(find.text('30 帧'), findsOneWidget);
expect(find.text('高刷'), findsOneWidget);
expect(
  tester
      .widget<SegmentedButton<GameFrameRateMode>>(
        find.byType(SegmentedButton<GameFrameRateMode>),
      )
      .segments,
  hasLength(4),
);
```

点击 `60 帧` 后断言控制器与内存存储均为 `stable60`；点击 `30 帧` 后断言均为
`stable30`。

- [ ] **步骤 2：先写高刷取消与确认失败测试**

增加两个独立组件测试：

```dart
await tester.tap(find.text('高刷'));
await tester.pumpAndSettle();
expect(find.text('开启高刷模式？'), findsOneWidget);
expect(find.textContaining('未知的账号风险'), findsOneWidget);

await tester.tap(find.text('取消'));
await tester.pumpAndSettle();
expect(controller.mode, GameFrameRateMode.automatic);
expect(await store.loadMode(), GameFrameRateMode.automatic);
```

确认路径重新创建 fixture，弹窗出现后点击 `了解风险并开启`，再断言控制器和存储均为
`highRefresh`。另建一个初始值为 `highRefresh` 的 fixture，首次渲染不得出现弹窗。

- [ ] **步骤 3：先更新本地化审计失败测试**

删除「所有语言省略已移除高刷设置」测试，改为要求三个 ARB 都包含：

```dart
const keys = <String>{
  'gameFrameRateStable60',
  'gameFrameRateStable60Desc',
  'gameFrameRateStable30',
  'gameFrameRateStable30Desc',
  'gameFrameRateHighRefresh',
  'gameFrameRateHighRefreshDesc',
  'gameFrameRateHighRefreshDialogTitle',
  'gameFrameRateHighRefreshDialogBody',
  'gameFrameRateHighRefreshDialogConfirm',
};
```

- [ ] **步骤 4：运行 UI 与本地化测试并确认红灯**

运行：

```powershell
flutter test test/game_frame_rate_settings_section_test.dart test/localization_resource_audit_test.dart
```

预期：缺少四档、本地化 getter 与弹窗而失败。

- [ ] **步骤 5：添加三语本地化资源**

简体中文使用：

```json
"gameFrameRateStable60": "60 帧",
"gameFrameRateStable60Desc": "始终以 60 FPS 运行，不自动降档。",
"gameFrameRateStable30": "30 帧",
"gameFrameRateStable30Desc": "始终以 30 FPS 运行，降低耗电和发热。",
"gameFrameRateHighRefresh": "高刷",
"gameFrameRateHighRefreshDesc": "解除 60 FPS 限制，跟随屏幕刷新率运行，耗电和发热可能增加。",
"gameFrameRateHighRefreshDialogTitle": "开启高刷模式？",
"gameFrameRateHighRefreshDialogBody": "高刷会修改游戏运行帧率，可能增加耗电、发热或引发动画异常，并存在未知的账号风险。请自行承担后果。",
"gameFrameRateHighRefreshDialogConfirm": "了解风险并开启"
```

繁体中文使用对应繁体字形；日文使用「60 FPS」「30 FPS」「高リフレッシュ」及自然
日文风险说明。三个 ARB 必须保持完全相同的消息键与元数据结构。删除不再使用的
`gameFrameRatePowerSaving` 与 `gameFrameRatePowerSavingDesc`。

- [ ] **步骤 6：生成本地化 Dart 文件**

运行：

```powershell
flutter gen-l10n
```

预期：`app_localizations.dart` 及中日实现类出现上述新 getter，不再出现已删除的低耗
getter。

- [ ] **步骤 7：实现四档组件与确认事务**

在 `GameFrameRateSettingsSection` 中增加一个方法，确认成功前不调用控制器：

```dart
Future<void> _selectMode(
  BuildContext context,
  AppLocalizations l10n,
  GameFrameRateMode mode,
) async {
  if (mode == GameFrameRateMode.highRefresh) {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.gameFrameRateHighRefreshDialogTitle),
        content: Text(l10n.gameFrameRateHighRefreshDialogBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.gameFrameRateHighRefreshDialogConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
  }
  await controller.setMode(mode);
}
```

`SegmentedButton` 按自动、60 帧、30 帧、高刷顺序提供四个 segment。
`onSelectionChanged` 使用 `unawaited(_selectMode(context, l10n, selection.single))`。
说明文本 switch 覆盖四个模式，不提供默认分支。

- [ ] **步骤 8：格式化并运行 UI 测试**

运行：

```powershell
dart format lib/src/settings/game_frame_rate_settings_section.dart test/game_frame_rate_settings_section_test.dart test/localization_resource_audit_test.dart lib/l10n/app_localizations*.dart
flutter test test/game_frame_rate_settings_section_test.dart test/localization_resource_audit_test.dart
```

PowerShell 不展开 Dart 参数中的 glob；如 `dart format` 报路径错误，改为显式列出
`app_localizations.dart`、`app_localizations_zh.dart` 和 `app_localizations_ja.dart`。
预期：全部通过。

- [ ] **步骤 9：提交设置界面**

```powershell
git add -- lib/src/settings/game_frame_rate_settings_section.dart lib/l10n/app_zh.arb lib/l10n/app_zh_Hant.arb lib/l10n/app_ja.arb lib/l10n/app_localizations.dart lib/l10n/app_localizations_zh.dart lib/l10n/app_localizations_ja.dart test/game_frame_rate_settings_section_test.dart test/localization_resource_audit_test.dart
git commit -m "feat(设置): 添加四档帧率与高刷风险确认"
```

### 任务 4：扩展 Android 运行时 Bridge 与系统约束边界

**文件：**

- 修改：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameFrameRateBridge.kt:16-81`
- 修改：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameFrameRateManager.kt:8-121`
- 测试：`android/app/src/test/kotlin/app/yahagi/kancollebrowser/browser/GameFrameRateScriptTest.kt`
- 测试：`android/app/src/test/kotlin/app/yahagi/kancollebrowser/browser/GameFrameRateSystemConstraintsTest.kt`

- [ ] **步骤 1：先写四档 wire name 和裸 RAF 失败测试**

在 `GameFrameRateScriptTest` 中断言：

```kotlin
assertEquals(GameFrameRateMode.STABLE_60, GameFrameRateMode.fromWireName("stable60"))
assertEquals(GameFrameRateMode.HIGH_REFRESH, GameFrameRateMode.fromWireName("highRefresh"))
assertEquals(GameFrameRateMode.AUTO, GameFrameRateMode.fromWireName("prefer60"))
assertEquals(GameFrameRateTarget.HIGH_REFRESH, GameFrameRateTarget.fromWireName("highRefresh"))

val script = GameFrameRateBridgeScript.source
assertTrue(script.contains("data.target === 'highRefresh'"))
assertTrue(script.contains("ticker.timingMode = ticker.RAF"))
assertFalse(script.contains("fetch("))
assertFalse(script.contains("XMLHttpRequest"))
assertFalse(script.contains("dispatchEvent"))
```

- [ ] **步骤 2：先写手动模式不受系统约束失败测试**

在 `GameFrameRateSystemConstraintsTest` 中用省电与严重热状态分别验证：

```kotlin
for ((mode, target) in listOf(
    GameFrameRateMode.STABLE_60 to GameFrameRateTarget.FPS_60,
    GameFrameRateMode.STABLE_30 to GameFrameRateTarget.FPS_30,
    GameFrameRateMode.HIGH_REFRESH to GameFrameRateTarget.HIGH_REFRESH,
)) {
    assertEquals(
        target,
        GameFrameRateSystemPolicy.effectiveTarget(
            mode = mode,
            requestedTarget = target,
            state = GameFrameRateSystemState(
                powerSaveEnabled = true,
                thermalStatus = PowerManager.THERMAL_STATUS_SEVERE,
            ),
        ),
    )
}
```

保留自动档在省电和中度发热时返回 `FPS_30` 的现有测试。

- [ ] **步骤 3：运行 Android 定向测试并确认红灯**

运行：

```powershell
android\gradlew.bat -p android :app:testDebugUnitTest --tests "app.yahagi.kancollebrowser.browser.GameFrameRateScriptTest" --tests "app.yahagi.kancollebrowser.browser.GameFrameRateSystemConstraintsTest" --console=plain
```

预期：因 `STABLE_60`、`HIGH_REFRESH` 和 Bridge 高刷分支缺失而失败。

- [ ] **步骤 4：实现 Kotlin 模式与目标枚举**

模式枚举改为：

```kotlin
enum class GameFrameRateMode(val wireName: String) {
    AUTO("auto"),
    STABLE_60("stable60"),
    STABLE_30("stable30"),
    HIGH_REFRESH("highRefresh");
}
```

目标枚举增加：

```kotlin
HIGH_REFRESH("highRefresh")
```

`initialTarget` 映射为自动和固定 60 → `FPS_60`，固定 30 → `FPS_30`，高刷 →
`HIGH_REFRESH`。`fromWireName` 继续让 `prefer60` 和未知模式回退 `AUTO`。

- [ ] **步骤 5：实现 Bridge 裸 RAF 分支**

`applyTarget` 使用三个明确分支：

```javascript
if (requestedTarget === 'fps30') {
  // 保留现有 30 FPS 实现。
} else if (requestedTarget === 'fps60') {
  // 保留现有 60 FPS 实现。
} else if (ticker.timingMode !== ticker.RAF) {
  ticker.timingMode = ticker.RAF;
}
```

消息白名单增加 `data.target === 'highRefresh'`。定期 `applyTarget()` 保持不变，从而在
游戏覆盖 Ticker 后重新应用高刷。不要增加 `main.js` 下载或 WebView 请求拦截。

- [ ] **步骤 6：确认系统策略只判断自动档**

保持 `GameFrameRateSystemPolicy.effectiveTarget` 的核心条件为：

```kotlin
return if (mode == GameFrameRateMode.AUTO && state.shouldConservePower) {
    GameFrameRateTarget.FPS_30
} else {
    requestedTarget
}
```

不要为 `STABLE_60` 或 `HIGH_REFRESH` 增加温度、省电、性能或实际 FPS 回退。

- [ ] **步骤 7：运行 Android 定向测试**

运行：

```powershell
android\gradlew.bat -p android :app:testDebugUnitTest --tests "app.yahagi.kancollebrowser.browser.GameFrameRateScriptTest" --tests "app.yahagi.kancollebrowser.browser.GameFrameRateSystemConstraintsTest" --console=plain
```

预期：`BUILD SUCCESSFUL`。

- [ ] **步骤 8：提交 Android Bridge**

```powershell
git add -- android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameFrameRateBridge.kt android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameFrameRateManager.kt android/app/src/test/kotlin/app/yahagi/kancollebrowser/browser/GameFrameRateScriptTest.kt android/app/src/test/kotlin/app/yahagi/kancollebrowser/browser/GameFrameRateSystemConstraintsTest.kt
git commit -m "feat(安卓): 支持固定 60 与运行时高刷"
```

### 任务 5：补齐原生游戏表面集成回归

**文件：**

- 修改：`test/native_activity_game_surface_test.dart:376-423`

- [ ] **步骤 1：保留自动档生命周期回归**

现有 `native surface drives the frame-rate runtime on game pages` 测试继续断言自动档：

```dart
expect(frameRatePort.appliedTargets, contains(GameFrameRateTarget.fps60));
tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
await tester.pump();
await tester.pump();
expect(frameRatePort.appliedTargets.last, GameFrameRateTarget.fps30);
tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
await tester.pump();
await tester.pump();
expect(frameRatePort.appliedTargets.last, GameFrameRateTarget.fps60);
```

- [ ] **步骤 2：增加手动档跨生命周期集成测试**

抽取现有原生 surface fixture 装配方式，为 `stable60` 和 `highRefresh` 分别创建
`MemoryGameFrameRateSettingsStore(mode)`，页面完成后触发 paused/resumed，并断言最后
目标始终分别为 `fps60` 与 `highRefresh`。测试必须在 tearDown 中恢复
`AppLifecycleState.resumed`，避免污染后续组件测试。

- [ ] **步骤 3：运行原生表面和全部帧率测试**

运行：

```powershell
dart format test/native_activity_game_surface_test.dart
flutter test test/game_frame_rate_settings_test.dart test/game_frame_rate_settings_section_test.dart test/game_frame_rate_policy_test.dart test/game_frame_rate_runtime_controller_test.dart test/game_frame_rate_script_test.dart test/native_activity_game_surface_test.dart test/localization_resource_audit_test.dart
```

预期：全部通过。

- [ ] **步骤 4：提交集成回归**

```powershell
git add -- test/native_activity_game_surface_test.dart
git commit -m "test(帧率): 补齐四档生命周期回归"
```

### 任务 6：全量验证并生成 Debug APK

**文件：**

- 验证：任务 1 至任务 5 涉及的全部文件。
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

- [ ] **步骤 4：检查高刷实现边界**

运行：

```powershell
rg -n -S "GameMainScriptPatcher|mainScriptTickerMode|kcs2/js/main\.js" android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameFrameRate* lib/src/browser/game_frame_rate*
rg -n -S "highRefresh|ticker\.RAF" android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser lib/src/browser test android/app/src/test
git diff --check HEAD
git status --short
```

预期：第一条命令无匹配；第二条只命中设置、运行时 Bridge、脚本和测试；没有因帧率
功能恢复 `main.js` 拦截。Git 无未提交实现改动，`git diff --check` 无空白错误。

- [ ] **步骤 5：构建 Debug APK**

运行：

```powershell
flutter build apk --debug
```

预期：生成 `build/app/outputs/flutter-apk/app-debug.apk`。不得自动安装 APK，也不得
停止、清除或重启用户设备上的游戏。

- [ ] **步骤 6：核对 APK 信息**

运行：

```powershell
Get-Item build/app/outputs/flutter-apk/app-debug.apk | Select-Object FullName,Length,LastWriteTime
Get-FileHash build/app/outputs/flutter-apk/app-debug.apk -Algorithm SHA256
```

预期：文件存在，大小大于 0，SHA-256 计算成功。

- [ ] **步骤 7：报告验证结果**

报告以下内容：

- 自动、60 帧、30 帧与高刷的最终行为。
- 风险弹窗取消与确认的测试结果。
- Flutter 全量测试、Android 单元测试和静态分析结果。
- Debug APK 的绝对路径、大小、修改时间和 SHA-256。
- 明确说明没有安装 APK，也没有操作用户设备上的现有游戏会话。
