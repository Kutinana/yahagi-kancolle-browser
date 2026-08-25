# 大破进击后提醒实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 将大破安全弹窗从战果出现时延后到危险的 `/api_req_map/next` 成功响应后，并保留战斗中受损震动、增加一次进击后提醒震动。

**架构：** `BattleResultWarningOverlay` 继续监听已捕获的 KCSAPI 响应，但改为一个局部待处理状态机：成功战果只记录风险，成功进击原子消费风险并提醒，撤退或回港清空风险。该实现不轮询画面、不拦截请求，且以 `api_result == 1` 作为状态转换条件。

**技术栈：** Flutter/Dart、`flutter_test`、Flutter gen-l10n、Android Gradle Debug APK

---

## 文件结构

- 修改：`test/battle_result_warning_overlay_test.dart`——覆盖延迟触发、单次消费、清理、失败响应、设置与震动行为。
- 修改：`lib/src/capture/battle_result_warning_overlay.dart`——实现待进击警告状态机及弹窗去重。
- 修改：`lib/l10n/app_zh.arb`——简体中文进击后警告文案。
- 修改：`lib/l10n/app_zh_Hant.arb`——繁体中文进击后警告文案。
- 修改：`lib/l10n/app_ja.arb`——日文进击后警告文案。
- 生成：`lib/l10n/app_localizations.dart`、`lib/l10n/app_localizations_zh.dart`、`lib/l10n/app_localizations_ja.dart`——由 `flutter gen-l10n` 同步生成。

### 任务 1：用失败测试锁定进击后触发时序

**文件：**
- 修改：`test/battle_result_warning_overlay_test.dart`
- 测试：`test/battle_result_warning_overlay_test.dart`

- [ ] **步骤 1：将原立即弹窗测试改成战果仅挂起**

在 fixture 中把 `showWarning` 拆成 `publishRiskResult` 与 `publishEvent`，战果后断言：

```dart
await fixture.publishRiskResult(tester);

expect(fixture.alerts.alerts, isEmpty);
expect(find.byType(AlertDialog), findsNothing);
```

- [ ] **步骤 2：新增成功进击后恰好提醒一次的测试**

```dart
await fixture.publishRiskResult(tester);
await fixture.publishEvent(
  tester,
  kcsapiEvent('/kcsapi/api_req_map/next', const <String, Object?>{}),
);

expect(fixture.alerts.alerts, <BattleDamageAlertSeverity>[
  BattleDamageAlertSeverity.postBattleWarning,
]);
expect(find.byType(AlertDialog), findsOneWidget);
expect(find.text('已在大破状态下选择进击！请立即停止后续操作，避免进入下一场战斗。'), findsOneWidget);
```

关闭弹窗后再次发布同一进击事件，断言提醒列表仍只有一项且没有新弹窗。

- [ ] **步骤 3：新增清理与失败响应测试**

分别验证以下序列均不弹窗、不震动：

```dart
riskResult -> goback_port(api_result: 1) -> map/next(api_result: 1)
riskResult -> api_port/port(api_result: 1) -> map/next(api_result: 1)
riskResult -> map/next(api_result: 0)
```

失败的 `map/next` 后再发成功 `map/next`，应触发一次，证明失败响应没有错误消费待提醒。

- [ ] **步骤 4：更新设置相关测试**

`BattleWarningMode.off` 在成功进击时消费风险但不提醒；关闭震动时成功进击仍弹窗但 `alerts` 为空。

- [ ] **步骤 5：运行目标测试确认失败**

运行：

```powershell
flutter test test/battle_result_warning_overlay_test.dart
```

预期：FAIL；现实现仍会在战果时立即弹窗，且进击后新文案/单次消费断言不成立。

### 任务 2：实现最小待进击警告状态机

**文件：**
- 修改：`lib/src/capture/battle_result_warning_overlay.dart`
- 测试：`test/battle_result_warning_overlay_test.dart`

- [ ] **步骤 1：增加局部状态与路径分类**

在 `_BattleResultWarningOverlayState` 中增加：

```dart
bool _pendingAdvanceWarning = false;
bool _warningDialogVisible = false;

bool _isRetreatOrPortPath(String path) =>
    path == '/kcsapi/api_req_sortie/goback_port' ||
    path == '/kcsapi/api_req_combined_battle/goback_port' ||
    path == '/kcsapi/api_port/port';
```

- [ ] **步骤 2：将事件监听器改成成功响应状态机**

```dart
void _onGameCaptureUpdate() {
  final event = widget.gameCaptureController.latestEvent;
  if (event == null || event.apiResult != 1) return;

  if (event.path.endsWith('/battleresult')) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _pendingAdvanceWarning = shouldShowPostBattleWarning(
        widget.battleController.current,
      );
    });
    return;
  }

  if (_isRetreatOrPortPath(event.path)) {
    _pendingAdvanceWarning = false;
    return;
  }

  if (event.path == '/kcsapi/api_req_map/next' &&
      _pendingAdvanceWarning) {
    _pendingAdvanceWarning = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showPendingWarning();
    });
  }
}
```

- [ ] **步骤 3：只在消费后按设置提醒**

将 `_checkWarning` 改为 `_showPendingWarning`：关闭模式时直接返回；开启震动时仅调用一次 `postBattleWarning`；然后调用 `_showWarningDialog()`。

- [ ] **步骤 4：防止并发弹出重复路由**

```dart
void _showWarningDialog() {
  if (_warningDialogVisible) return;
  _warningDialogVisible = true;
  unawaited(
    showDialog<void>(...).whenComplete(() {
      _warningDialogVisible = false;
    }),
  );
}
```

关闭后的状态写回不得调用 `setState`，避免组件销毁后的上下文访问。

- [ ] **步骤 5：运行目标测试确认状态机行为**

运行：

```powershell
flutter test test/battle_result_warning_overlay_test.dart
```

预期：除尚未更新的本地化文案断言外，状态机相关测试 PASS。

### 任务 3：更新三种语言的事后警告文案

**文件：**
- 修改：`lib/l10n/app_zh.arb`
- 修改：`lib/l10n/app_zh_Hant.arb`
- 修改：`lib/l10n/app_ja.arb`
- 生成：`lib/l10n/app_localizations.dart`
- 生成：`lib/l10n/app_localizations_zh.dart`
- 生成：`lib/l10n/app_localizations_ja.dart`
- 测试：`test/battle_result_warning_overlay_test.dart`

- [ ] **步骤 1：替换 `postBattleWarningBody`**

```json
"postBattleWarningBody": "已在大破状态下选择进击！请立即停止后续操作，避免进入下一场战斗。"
```

```json
"postBattleWarningBody": "已在大破狀態下選擇進擊！請立即停止後續操作，避免進入下一場戰鬥。"
```

```json
"postBattleWarningBody": "大破艦がいる状態で進撃しました！直ちに操作を止め、次の戦闘へ進まないでください。"
```

- [ ] **步骤 2：重新生成本地化文件**

运行：

```powershell
flutter gen-l10n
```

预期：命令成功，三个生成文件中的 getter 与 ARB 文案一致。

- [ ] **步骤 3：运行目标测试确认全部通过**

运行：

```powershell
flutter test test/battle_result_warning_overlay_test.dart
```

预期：PASS。

### 任务 4：回归验证并生成测试 APK

**文件：**
- 验证：`lib/src/capture/battle_result_warning_overlay.dart`
- 验证：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/BattleDamageVibration.kt`
- 输出：`build/app/outputs/flutter-apk/app-debug.apk`

- [ ] **步骤 1：格式化和静态分析**

运行：

```powershell
dart format lib/src/capture/battle_result_warning_overlay.dart test/battle_result_warning_overlay_test.dart
flutter analyze
```

预期：格式化成功，静态分析无错误。

- [ ] **步骤 2：运行关联测试**

运行：

```powershell
flutter test test/battle_result_warning_overlay_test.dart test/battle_damage_alert_port_test.dart test/fcf_retreat_battle_warning_test.dart test/game_environment_host_test.dart
```

预期：全部 PASS；原有中破/大破震动端口测试不受影响。

- [ ] **步骤 3：运行完整测试套件**

运行：

```powershell
flutter test
```

预期：全部 PASS；若存在与本次无关的既有失败，记录准确测试名与失败证据，不把它宣称为本次通过。

- [ ] **步骤 4：构建 Debug APK**

运行：

```powershell
flutter build apk --debug
```

预期：生成 `build/app/outputs/flutter-apk/app-debug.apk`。

- [ ] **步骤 5：检查 APK 与 Git 状态后提交**

运行：

```powershell
Get-Item build/app/outputs/flutter-apk/app-debug.apk | Select-Object FullName, Length, LastWriteTime
git diff --check
git status --short --branch
```

确认只有本功能相关源码、测试、本地化生成文件及计划文件后提交：

```powershell
git add lib/src/capture/battle_result_warning_overlay.dart test/battle_result_warning_overlay_test.dart lib/l10n/app_zh.arb lib/l10n/app_zh_Hant.arb lib/l10n/app_ja.arb lib/l10n/app_localizations.dart lib/l10n/app_localizations_zh.dart lib/l10n/app_localizations_ja.dart
git commit -m "feat(大破提醒): 延后到危险进击后触发"
```
