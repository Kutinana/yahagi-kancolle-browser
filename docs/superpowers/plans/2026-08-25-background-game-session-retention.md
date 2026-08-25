# 后台保持游戏会话实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在“画面与声音”中提供默认开启的“后台保持游戏”开关，只在舰 C 游戏页进入后台时用统一前台服务保护会话，回前台或离开游戏时撤销会话通知。

**架构：** Flutter 用持久化 Controller 保存开关，用 Coordinator 合并开关、游戏页面阶段和应用生命周期，再通过 MethodChannel 下发单一布尔目标。Android 扩展现有 `NotificationProgressService`，合并“会话保活”和“任务进度刷新”两种需求并只发布一条 ongoing 通知。

**技术栈：** Flutter/Dart、SharedPreferences、MethodChannel、Android Kotlin Service、NotificationCompat、JUnit4、flutter_test。

---

## 文件结构

- 创建 `lib/src/settings/background_game_retention_controller.dart`：设置存储、平台端口和状态协调。
- 创建 `test/background_game_retention_controller_test.dart`：默认值、回滚、生命周期和阶段组合测试。
- 修改 `lib/src/browser/game_toolbar_controller.dart`：游戏阶段变化对监听者可观察。
- 修改 `test/game_toolbar_controller_test.dart`：阶段通知契约。
- 修改 `lib/src/settings/screen_settings_page.dart`、`settings_page.dart`、`lib/main.dart`：设置项和依赖接线。
- 修改三份 ARB 并重新生成 `app_localizations*.dart`：三语 UI 和通知文案。
- 创建 `test/background_game_retention_settings_test.dart`：设置页位置、默认值和本地化测试。
- 创建 `android/.../notification/NotificationForegroundMode.kt`：纯函数决定停止、会话通知或任务通知。
- 创建 `android/.../notification/NotificationForegroundModeTest.kt`：服务需求合并测试。
- 修改 `NotificationProgressService.kt`、`AppNotificationManager.kt`、`MainActivity.kt`、`AndroidManifest.xml`：平台通道、统一服务和通知。
- 修改/补充 Android 通知测试：保证现有任务行为不回归。

### 任务 1：设置 Controller 与状态协调器

**文件：**
- 创建：`test/background_game_retention_controller_test.dart`
- 创建：`lib/src/settings/background_game_retention_controller.dart`
- 修改：`test/game_toolbar_controller_test.dart`
- 修改：`lib/src/browser/game_toolbar_controller.dart`

- [ ] **步骤 1：编写默认开启、持久化失败回滚和组合状态的失败测试**

```dart
test('defaults enabled when no value was saved', () async {
  final controller = await BackgroundGameRetentionController.load(
    MemoryBackgroundGameRetentionStore(),
  );
  expect(controller.enabled, isTrue);
});

test('retains only while enabled game is active and app is backgrounded', () async {
  final controller = await BackgroundGameRetentionController.load(store);
  final toolbar = GameToolbarController();
  final port = RecordingBackgroundGameRetentionPort();
  final coordinator = BackgroundGameRetentionCoordinator(
    controller: controller,
    toolbarController: toolbar,
    port: port,
  );
  toolbar.onStageChanged(GameSurfaceStage.game);
  await coordinator.handleLifecycleState(AppLifecycleState.paused);
  await coordinator.settle();
  expect(port.values, contains(true));
  await coordinator.handleLifecycleState(AppLifecycleState.resumed);
  await coordinator.settle();
  expect(port.values.last, isFalse);
});
```

- [ ] **步骤 2：运行测试，确认因类型不存在和阶段不通知而失败**

运行：`flutter test test/background_game_retention_controller_test.dart test/game_toolbar_controller_test.dart`

预期：FAIL，缺少 `BackgroundGameRetentionController`，阶段监听断言未满足。

- [ ] **步骤 3：实现最小 Store、Controller、Port 和 Coordinator**

实现接口：

```dart
abstract interface class BackgroundGameRetentionStore {
  Future<bool?> readEnabled();
  Future<void> writeEnabled(bool enabled);
}

abstract interface class BackgroundGameRetentionPort {
  Future<void> setRetaining(bool retaining);
}

final class BackgroundGameRetentionController extends ChangeNotifier {
  static Future<BackgroundGameRetentionController> load(...);
  bool get enabled;
  String? get errorMessage;
  Future<void> setEnabled(bool enabled);
}

final class BackgroundGameRetentionCoordinator {
  Future<void> handleLifecycleState(AppLifecycleState state);
  Future<void> settle();
  void dispose();
}
```

`resumed` 设置前台，`hidden`/`paused` 设置后台，`inactive` 不改变状态，`detached` 强制停止。所有平台调用通过 Future 队列串行化并以最新目标为准。

同时让 `GameToolbarController.onStageChanged()` 在阶段真正变化时调用 `notifyListeners()`，但不改变工具栏显隐。

- [ ] **步骤 4：运行目标测试确认通过**

运行：`flutter test test/background_game_retention_controller_test.dart test/game_toolbar_controller_test.dart`

预期：PASS。

- [ ] **步骤 5：提交任务 1**

```bash
git add lib/src/settings/background_game_retention_controller.dart lib/src/browser/game_toolbar_controller.dart test/background_game_retention_controller_test.dart test/game_toolbar_controller_test.dart
git commit -m "feat(后台): 添加游戏会话保活状态协调"
```

### 任务 2：设置页与三语文案

**文件：**
- 创建：`test/background_game_retention_settings_test.dart`
- 修改：`lib/src/settings/screen_settings_page.dart`
- 修改：`lib/src/settings/settings_page.dart`
- 修改：`lib/l10n/app_zh.arb`
- 修改：`lib/l10n/app_zh_Hant.arb`
- 修改：`lib/l10n/app_ja.arb`
- 生成：`lib/l10n/app_localizations.dart`
- 生成：`lib/l10n/app_localizations_zh.dart`
- 生成：`lib/l10n/app_localizations_ja.dart`

- [ ] **步骤 1：编写设置项位置与默认开启的失败 Widget 测试**

```dart
testWidgets('background game retention appears after background audio and defaults on', (tester) async {
  final retention = await BackgroundGameRetentionController.load(memoryStore);
  await tester.pumpWidget(localizedScreenSettings(retention));
  final tile = find.byKey(const Key('settings-background-game-retention'));
  expect(tile, findsOneWidget);
  expect(tester.getTopLeft(tile).dy,
      greaterThan(tester.getTopLeft(find.byKey(const Key('settings-background-audio'))).dy));
  expect(tester.widget<Switch>(find.descendant(of: tile, matching: find.byType(Switch))).value, isTrue);
});
```

- [ ] **步骤 2：运行测试确认设置项缺失**

运行：`flutter test test/background_game_retention_settings_test.dart`

预期：FAIL，找不到 `settings-background-game-retention`。

- [ ] **步骤 3：添加三语 ARB 文案并生成本地化代码**

新增键：

```json
"backgroundGameRetention": "后台保持游戏",
"backgroundGameRetentionDesc": "进入后台时显示常驻通知以降低游戏会话被系统回收的概率，可能增加耗电。",
"backgroundGameRetentionNotificationTitle": "矢矧正在后台运行",
"backgroundGameRetentionNotificationBody": "游戏会话保持中 · 点击返回游戏"
```

繁体中文和日文提供对应自然翻译。运行：`flutter gen-l10n`。

- [ ] **步骤 4：把开关接入“游戏与声音”卡片**

`ScreenSettingsPage` 接收可选 `BackgroundGameRetentionController`，在后台音频开关后添加 Divider 和稳定 Key 的 `buildSwitchTile`。`SettingsPage` 透传同一个 Controller。

- [ ] **步骤 5：运行 Widget 和本地化审计测试**

运行：`flutter test test/background_game_retention_settings_test.dart test/localization_resource_audit_test.dart`

预期：PASS。

- [ ] **步骤 6：提交任务 2**

```bash
git add lib/src/settings/screen_settings_page.dart lib/src/settings/settings_page.dart lib/l10n test/background_game_retention_settings_test.dart
git commit -m "feat(设置): 添加后台保持游戏开关"
```

### 任务 3：Android 统一前台服务

**文件：**
- 创建：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/notification/NotificationForegroundMode.kt`
- 创建：`android/app/src/test/kotlin/app/yahagi/kancollebrowser/notification/NotificationForegroundModeTest.kt`
- 修改：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/notification/NotificationProgressService.kt`
- 修改：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/notification/AppNotificationManager.kt`
- 修改：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/MainActivity.kt`
- 修改：`android/app/src/main/AndroidManifest.xml`

- [ ] **步骤 1：编写前台模式纯函数失败测试**

```kotlin
@Test fun `session without tasks shows session notification`() {
    assertEquals(SESSION, NotificationForegroundMode.resolve(true, false, false))
}

@Test fun `tasks take priority over session`() {
    assertEquals(PROGRESS, NotificationForegroundMode.resolve(true, true, true))
}

@Test fun `no requirements stops service`() {
    assertEquals(STOP, NotificationForegroundMode.resolve(false, false, false))
}
```

- [ ] **步骤 2：运行 Android 测试确认类型不存在**

运行：`cd android && ./gradlew app:testDebugUnitTest --tests '*NotificationForegroundModeTest'`

预期：FAIL，缺少 `NotificationForegroundMode`。

- [ ] **步骤 3：实现模式投影和会话通知 builder**

模式枚举为 `STOP`、`SESSION`、`PROGRESS`。`AppNotificationManager` 新增构建低打扰会话通知的方法，复用 ongoing channel、通知 ID 和点击返回 `MainActivity` 的 PendingIntent。

- [ ] **步骤 4：扩展服务命令和生命周期**

为 `NotificationProgressService` 增加 `ACTION_SET_SESSION_RETENTION` 和布尔 extra：

- true：`startForegroundService` 并显示会话或任务通知；
- false：若服务运行则发送普通 `startService` 命令重新投影；
- 有任务时优先现有任务卡；
- 无任务且无会话请求时移除通知并停止；
- `onTaskRemoved` 清除会话请求，再按任务需求决定继续或停止；
- 返回 `START_STICKY` 以保持现有任务恢复语义，但空 Intent 不恢复已失效的会话请求。

- [ ] **步骤 5：在 MainActivity 注册 MethodChannel**

新增 `app.yahagi.kancollebrowser/background_game_retention` 通道，处理：

```kotlin
"setRetaining" -> NotificationProgressService.setSessionRetention(
    this,
    call.argument<Boolean>("retaining") == true,
)
```

通道成功返回 null，失败返回结构化 `retention_failed`。

- [ ] **步骤 6：运行 Android 通知测试**

运行：`cd android && ./gradlew app:testDebugUnitTest --tests '*NotificationForegroundModeTest' --tests '*NotificationProgressProjectionTest' --tests '*NotificationSnapshotTest'`

预期：PASS。

- [ ] **步骤 7：提交任务 3**

```bash
git add android/app/src/main android/app/src/test
git commit -m "feat(安卓): 统一游戏会话与任务前台服务"
```

### 任务 4：应用接线与生命周期集成

**文件：**
- 修改：`lib/main.dart`
- 修改：`test/prototype_shell_test.dart`
- 修改：`test/background_game_retention_controller_test.dart`

- [ ] **步骤 1：编写 Shell 生命周期接线失败测试**

构造带内存 Controller/Port 的 Shell，进入 `GameSurfaceStage.game`，发送 `paused`，断言请求 true；发送 `resumed`，断言请求 false。为 `YahagiShell` 增加仅测试与依赖注入使用的可选 Port 参数，默认使用 MethodChannel Port。

- [ ] **步骤 2：运行测试确认 Shell 尚未接线**

运行：`flutter test test/prototype_shell_test.dart test/background_game_retention_controller_test.dart`

预期：FAIL，Shell 不接受 Controller/Port 或生命周期未同步。

- [ ] **步骤 3：在 main 加载设置并由 Shell 创建/销毁 Coordinator**

- `main()` 加载 `SharedPreferencesBackgroundGameRetentionStore`，默认 true。
- `YahagiApp`、`YahagiShell`、`SettingsPage` 透传 Controller。
- `_YahagiShellState.initState()` 创建 Coordinator。
- `didChangeAppLifecycleState()` 转发状态。
- `dispose()` 请求停止并释放监听。
- 测试未传 Controller 时保持原有行为。

- [ ] **步骤 4：运行集成相关 Flutter 测试**

运行：`flutter test test/prototype_shell_test.dart test/background_game_retention_controller_test.dart test/background_game_retention_settings_test.dart`

预期：PASS。

- [ ] **步骤 5：提交任务 4**

```bash
git add lib/main.dart test/prototype_shell_test.dart test/background_game_retention_controller_test.dart
git commit -m "feat(后台): 接入游戏会话前后台生命周期"
```

### 任务 5：完整验证与真机检查

**文件：**
- 按失败结果仅修改本功能相关文件。

- [ ] **步骤 1：格式化并运行静态分析**

运行：`dart format lib/src/settings/background_game_retention_controller.dart lib/src/settings/screen_settings_page.dart lib/src/settings/settings_page.dart lib/main.dart test/background_game_retention_controller_test.dart test/background_game_retention_settings_test.dart`

运行：`flutter analyze`

预期：0 error。

- [ ] **步骤 2：运行完整 Flutter 测试**

运行：`flutter test`

预期：全部通过，0 failures。

- [ ] **步骤 3：运行完整 Android 单元测试**

运行：`cd android && ./gradlew app:testDebugUnitTest`

预期：BUILD SUCCESSFUL。

- [ ] **步骤 4：构建 Release APK**

运行：`flutter build apk --release`

预期：生成 `build/app/outputs/flutter-apk/app-release.apk`。

- [ ] **步骤 5：真机验证进程优先级**

安装经授权的测试 APK 后：进入游戏页，按 Home，确认 ongoing 通知出现；运行 `adb shell dumpsys activity oom`，确认主进程不再是 `cached`/`oom_adj=900`。返回前台确认会话通知消失；关闭开关后再次按 Home 确认不启动会话保活。

- [ ] **步骤 6：检查最终差异并提交验证修正**

运行：`git status --short && git diff --check`

若验证引入修正，提交：

```bash
git add <本功能相关文件>
git commit -m "test(后台): 完善游戏会话保活验证"
```
