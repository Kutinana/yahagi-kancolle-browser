# 游戏框架刷新快捷入口实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 增加默认隐藏的顶部框架刷新胶囊、可记忆的二次确认，以及默认关闭的游戏画面鼠标右键刷新。

**架构：** 顶部入口复用 `CompactResourceBar` 的排序与显隐模型，并把确认偏好和鼠标右键偏好保存在 `SharedPreferences`。顶部与右键最终都调用现有 `GameFrameReloadPort`；Android 文档起始脚本只负责识别可信的游戏画面右键，刷新结果回传 Flutter 统一显示错误。

**技术栈：** Flutter、Dart、SharedPreferences、Android Kotlin、AndroidX WebKit、Flutter Test、JUnit、Gradle。

---

## 文件结构

- `lib/src/settings/game_frame_refresh_shortcut_settings.dart`：保存跳过顶部确认和右键刷新两个偏好。
- `lib/src/browser/game_frame_refresh_shortcut_dialog.dart`：顶部胶囊确认弹窗及「确认后保存」规则。
- `lib/src/browser/game_frame_refresh_shortcut_action.dart`：串行执行框架刷新并把失败结果转换为现有顶部提示。
- `lib/src/fleet/header_resource_catalog.dart`、`lib/src/fleet/resource_grid.dart`：注册、显示、筛选和点击顶部胶囊。
- `lib/src/layout/workspace_context_header.dart`、`lib/main.dart`：把刷新回调与偏好控制器接入应用壳。
- `lib/src/settings/game_mouse_wheel_settings_section.dart`、`lib/src/settings/screen_settings_page.dart`：显示独立的右键刷新开关。
- `android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameFrameReloadBridge.kt`：识别游戏 Canvas 的可信右键事件并请求快捷刷新。
- `android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameFrameReloadManager.kt`、`android/app/src/main/kotlin/app/yahagi/kancollebrowser/MainActivity.kt`：把右键请求串行化，并将结果回传 Flutter。
- `lib/l10n/app_zh.arb`、`lib/l10n/app_zh_Hant.arb`、`lib/l10n/app_ja.arb`：新增三语文案；生成文件由 `flutter gen-l10n` 更新。

### 任务 1：偏好控制器

**文件：**
- 创建：`lib/src/settings/game_frame_refresh_shortcut_settings.dart`
- 创建：`test/game_frame_refresh_shortcut_settings_test.dart`

- [ ] **步骤 1：编写失败的偏好测试**

```dart
test('frame refresh shortcuts default off and persist independently', () async {
  SharedPreferences.setMockInitialValues({});
  final settings = await GameFrameRefreshShortcutSettings.load();
  expect(settings.skipHeaderConfirmation, isFalse);
  expect(settings.rightClickEnabled, isFalse);
  await settings.setSkipHeaderConfirmation(true);
  await settings.setRightClickEnabled(true);
  final reloaded = await GameFrameRefreshShortcutSettings.load();
  expect(reloaded.skipHeaderConfirmation, isTrue);
  expect(reloaded.rightClickEnabled, isTrue);
});
```

- [ ] **步骤 2：运行测试并确认因类型不存在而失败**

运行：`flutter test test/game_frame_refresh_shortcut_settings_test.dart`

- [ ] **步骤 3：实现两个布尔偏好和保存失败回滚**

偏好键固定为 `game.frameRefreshSkipConfirmation` 和 `game.mouseRightClickFrameRefresh`，默认值均为 `false`；保存时复用现有鼠标滚轮控制器的 `_saving`、`_saveFailed` 和回滚模式。

- [ ] **步骤 4：重新运行测试并确认通过**

运行：`flutter test test/game_frame_refresh_shortcut_settings_test.dart`

### 任务 2：顶部胶囊目录与自定义

**文件：**
- 修改：`lib/src/fleet/header_resource_catalog.dart`
- 修改：`lib/src/fleet/resource_grid.dart`
- 修改：`test/compact_resource_bar_test.dart`
- 修改：`test/layout_settings_behavior_test.dart`

- [ ] **步骤 1：编写失败的顶部显隐与点击测试**

```dart
expect(defaultVisibleHeaderResourceIds, isNot(contains(headerFrameRefreshId)));
expect(find.byKey(const Key('header-resource-frame-refresh')), findsNothing);
await controller.toggleHeaderResourceVisible(headerFrameRefreshId);
await tester.pump();
expect(find.byKey(const Key('header-resource-frame-refresh')), findsOneWidget);
await tester.tap(find.byKey(const Key('header-resource-frame-refresh')));
expect(refreshCalls, 1);
```

- [ ] **步骤 2：运行目标测试并确认缺少新目录项**

运行：`flutter test test/compact_resource_bar_test.dart test/layout_settings_behavior_test.dart`

- [ ] **步骤 3：实现 `headerFrameRefreshId` 特殊项目**

把该 ID 加入 `allHeaderResourceIds`，但不加入 `defaultVisibleHeaderResourceIds`。在显示态渲染固定宽度 98 px、30 px 高的图标文字胶囊；在编辑态和筛选抽屉中复用特殊项目行；通过 `CompactResourceBar.onFrameRefreshTap` 触发回调。

- [ ] **步骤 4：重新运行目标测试并确认通过**

运行：`flutter test test/compact_resource_bar_test.dart test/layout_settings_behavior_test.dart`

### 任务 3：顶部二级确认与刷新反馈

**文件：**
- 创建：`lib/src/browser/game_frame_refresh_shortcut_dialog.dart`
- 创建：`lib/src/browser/game_frame_refresh_shortcut_action.dart`
- 修改：`lib/src/browser/game_refresh_dialog.dart`
- 修改：`lib/src/layout/workspace_context_header.dart`
- 修改：`lib/main.dart`
- 创建：`test/game_frame_refresh_shortcut_dialog_test.dart`

- [ ] **步骤 1：编写失败的确认行为测试**

```dart
await tester.tap(find.byKey(const Key('header-resource-frame-refresh')));
expect(find.byKey(const Key('frame-refresh-confirm-dialog')), findsOneWidget);
await tester.tap(find.byKey(const Key('frame-refresh-skip-confirmation')));
await tester.tap(find.byKey(const Key('frame-refresh-cancel')));
expect(settings.skipHeaderConfirmation, isFalse);
await tester.tap(find.byKey(const Key('header-resource-frame-refresh')));
await tester.tap(find.byKey(const Key('frame-refresh-skip-confirmation')));
await tester.tap(find.byKey(const Key('frame-refresh-confirm')));
expect(settings.skipHeaderConfirmation, isTrue);
expect(reloadCalls, 1);
```

- [ ] **步骤 2：运行测试并确认弹窗尚不存在**

运行：`flutter test test/game_frame_refresh_shortcut_dialog_test.dart`

- [ ] **步骤 3：实现确认弹窗和串行刷新动作**

弹窗使用 `StatefulBuilder` 保存临时勾选状态；取消只关闭弹窗；确认时先保存勾选偏好，再调用刷新。跳过确认后直接刷新。提取现有 `GameFrameReloadResult` 到 `TopNotice` 的映射供原刷新弹窗和快捷入口共同使用，并用运行中标记阻止并发触发。

- [ ] **步骤 4：重新运行确认与现有刷新测试**

运行：`flutter test test/game_frame_refresh_shortcut_dialog_test.dart test/game_browser_controller_test.dart`

### 任务 4：鼠标右键设置与 Android 事件桥

**文件：**
- 修改：`lib/src/settings/game_mouse_wheel_settings_section.dart`
- 修改：`lib/src/settings/screen_settings_page.dart`
- 修改：`test/game_mouse_wheel_settings_section_test.dart`
- 修改：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameFrameReloadBridge.kt`
- 修改：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameFrameReloadManager.kt`
- 修改：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/MainActivity.kt`
- 修改：`android/app/src/test/kotlin/app/yahagi/kancollebrowser/browser/GameFrameReloadBridgeTest.kt`

- [ ] **步骤 1：编写失败的 Widget 与 Kotlin 策略测试**

```dart
final toggle = find.byKey(const Key('settings-mouse-right-click-frame-refresh'));
expect(tester.widget<Switch>(toggle).value, isFalse);
await tester.tap(toggle);
expect(settings.rightClickEnabled, isTrue);
```

```kotlin
assertTrue(GameFrameRightClickPolicy.accepts(true, true, 2))
assertFalse(GameFrameRightClickPolicy.accepts(false, true, 2))
assertFalse(GameFrameRightClickPolicy.accepts(true, false, 2))
assertFalse(GameFrameRightClickPolicy.accepts(true, true, 0))
```

- [ ] **步骤 2：运行测试并确认新开关与策略不存在**

运行：`flutter test test/game_mouse_wheel_settings_section_test.dart`

运行：`cd android; .\gradlew.bat testDebugUnitTest --tests "app.yahagi.kancollebrowser.browser.GameFrameReloadBridgeTest"`

- [ ] **步骤 3：实现可信游戏右键转发**

文档起始脚本只在 `/kcs2/` 页面、事件 `isTrusted`、`button == 2` 且目标位于可见 Canvas 内时发送 `secondary_click`，并阻止该次系统菜单。Android 端读取 `flutter.game.mouseRightClickFrameRefresh`；开关关闭时忽略请求，开启时通过现有 Manager 执行一次刷新。结果以 `shortcutResult` 回传 Flutter，失败复用任务 3 的顶部错误提示；该路径不读取也不修改顶部「下次不再提醒」。

- [ ] **步骤 4：重新运行 Flutter 与 Kotlin 测试**

运行：`flutter test test/game_mouse_wheel_settings_section_test.dart`

运行：`cd android; .\gradlew.bat testDebugUnitTest --tests "app.yahagi.kancollebrowser.browser.GameFrameReloadBridgeTest"`

### 任务 5：本地化与回归验证

**文件：**
- 修改：`lib/l10n/app_zh.arb`
- 修改：`lib/l10n/app_zh_Hant.arb`
- 修改：`lib/l10n/app_ja.arb`
- 生成：`lib/l10n/app_localizations.dart`
- 生成：`lib/l10n/app_localizations_zh.dart`
- 生成：`lib/l10n/app_localizations_ja.dart`

- [ ] **步骤 1：加入三语文案并生成本地化代码**

简体中文使用「框架刷新」「确定刷新游戏框架？」「下次不再提醒」「鼠标右键刷新框架」；繁体中文使用对应繁体；日文使用「ゲームフレームを更新」「ゲームフレームを更新しますか？」「次回から表示しない」「右クリックでゲームフレームを更新」。

运行：`flutter gen-l10n`

- [ ] **步骤 2：运行格式化与静态分析**

运行：`dart format lib/src/settings/game_frame_refresh_shortcut_settings.dart lib/src/browser/game_frame_refresh_shortcut_dialog.dart lib/src/browser/game_frame_refresh_shortcut_action.dart lib/src/fleet/header_resource_catalog.dart lib/src/fleet/resource_grid.dart lib/src/layout/workspace_context_header.dart lib/main.dart test/game_frame_refresh_shortcut_settings_test.dart test/game_frame_refresh_shortcut_dialog_test.dart`

运行：`flutter analyze`

- [ ] **步骤 3：运行完整测试**

运行：`flutter test`

运行：`cd android; .\gradlew.bat testDebugUnitTest`

- [ ] **步骤 4：构建 Debug APK 并记录产物**

运行：`flutter build apk --debug`

预期产物：`build/app/outputs/flutter-apk/app-debug.apk`。复制到仓库根目录 `outputs/Yahagi-frame-refresh-shortcuts-debug-20260914.apk`，并计算 SHA-256。
