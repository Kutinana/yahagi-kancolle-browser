# 原生 WebView 后台恢复实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 防止原生 Activity WebView 在后台页面完成时因等待 Flutter 帧而误报超时，并在真实初始化失败时提供有限重试和一次自动重载。

**架构：** 在 `NativeActivityGameSurface` 中引入生命周期感知的页面收尾调度器：后台只保存最新任务，恢复前台后再执行。页面初始化使用独立的 10 秒超时，失败后重试一次，再以熔断标记保护一次自动重载；最终失败显示阶段化错误和手动重载入口。

**技术栈：** Dart、Flutter Widget 生命周期、MethodChannel 原生 WebView 端口、`flutter_test`。

---

## 文件结构

- 修改：`lib/src/native_activity_game_surface.dart` — 生命周期调度、页面初始化超时、重试、自动/手动重载与错误阶段。
- 修改：`test/native_activity_game_surface_test.dart` — 后台恢复、超时拆分、重试和熔断回归测试；扩展现有测试夹具故障注入能力。

### 任务 1：后台页面完成延迟到前台

**文件：**
- 修改：`test/native_activity_game_surface_test.dart`
- 修改：`lib/src/native_activity_game_surface.dart`

- [ ] **步骤 1：编写失败的后台恢复测试**

```dart
testWidgets('page completion waits for foreground before finalizing', (tester) async {
  final fixture = _SurfaceFixture();
  addTearDown(() async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await fixture.dispose();
  });
  await fixture.pump(
    tester,
    pageInitializationTimeout: const Duration(milliseconds: 20),
  );
  await tester.pump();
  fixture.port.calls.clear();
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  fixture.port.addEvent(
    _event('pageFinished', generationId: 7, url: 'https://game.example/'),
  );
  await tester.pump(const Duration(seconds: 1));

  expect(fixture.port.calls, isNot(contains('fit')));
  expect(fixture.statusController.loadState, isNot(WebViewLoadState.failed));

  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pump();
  await tester.pump();
  expect(fixture.port.calls.where((call) => call == 'fit'), hasLength(1));
  expect(fixture.statusController.loadState, WebViewLoadState.ready);
});
```

- [ ] **步骤 2：运行测试并确认因后台仍执行 `fit` 而失败**

运行：`flutter test test/native_activity_game_surface_test.dart --plain-name "page completion waits for foreground before finalizing"`

预期：FAIL，调用记录包含 `fit` 或页面进入 `failed`。

- [ ] **步骤 3：实现最小生命周期调度**

在 State 中保存当前生命周期和最新待处理任务：

```dart
AppLifecycleState? _appLifecycleState = WidgetsBinding.instance.lifecycleState;
_PendingPageFinish? _pendingPageFinish;
Future<void>? _pageFinishFuture;

bool get _isForeground => _appLifecycleState == AppLifecycleState.resumed;
```

`pageFinished` 调用 `_schedulePageFinish(...)`；后台仅保存任务。`didChangeAppLifecycleState` 在 `resumed` 时启动仍有效的任务。`pageStarted`、`_invalidateOperations` 和 `dispose` 清除旧任务。

- [ ] **步骤 4：运行目标测试并确认通过**

运行：`flutter test test/native_activity_game_surface_test.dart --plain-name "page completion waits for foreground before finalizing"`

预期：PASS。

- [ ] **步骤 5：提交生命周期修复**

```powershell
git add lib/src/native_activity_game_surface.dart test/native_activity_game_surface_test.dart
git commit -m "fix(原生模式): 前台恢复后再完成页面初始化"
```

### 任务 2：拆分页面初始化超时并标记失败阶段

**文件：**
- 修改：`test/native_activity_game_surface_test.dart`
- 修改：`lib/src/native_activity_game_surface.dart`

- [ ] **步骤 1：编写失败的超时阶段测试**

```dart
testWidgets('page initialization reports the timed out stage', (tester) async {
  final fixture = _SurfaceFixture();
  fixture.port.fitCompleters.add(Completer<void>());
  addTearDown(fixture.dispose);
  await fixture.pump(
    tester,
    cleanupTimeout: const Duration(seconds: 1),
    pageInitializationTimeout: const Duration(milliseconds: 10),
  );
  await tester.pump();
  fixture.port.addEvent(
    _event('pageFinished', generationId: 7, url: 'https://game.example/'),
  );
  await tester.pump(const Duration(milliseconds: 11));

  expect(
    fixture.browserController.errorMessage,
    contains('[fitGameScreen]'),
  );
});
```

- [ ] **步骤 2：运行测试并确认错误信息缺少阶段名**

运行：`flutter test test/native_activity_game_surface_test.dart --plain-name "page initialization reports the timed out stage"`

预期：FAIL，现有错误只包含 `TimeoutException`。

- [ ] **步骤 3：新增独立页面超时并包装阶段异常**

为 Widget 新增可注入参数：

```dart
final Duration? pageInitializationTimeout;
```

State 默认设置为 10 秒；通过 `_runPageInitializationStage('fitGameScreen', action)` 分别包装 `fitGameScreen`、`prepareCapture` 和 `attachAudioPortOnce`，错误消息包含阶段名称。生命周期等待不包含在阶段超时内。

- [ ] **步骤 4：运行阶段测试和原生页面测试文件**

运行：`flutter test test/native_activity_game_surface_test.dart`

预期：全部 PASS。

- [ ] **步骤 5：提交超时拆分**

```powershell
git add lib/src/native_activity_game_surface.dart test/native_activity_game_surface_test.dart
git commit -m "fix(原生模式): 拆分页面初始化超时"
```

### 任务 3：重试一次并自动重载一次

**文件：**
- 修改：`test/native_activity_game_surface_test.dart`
- 修改：`lib/src/native_activity_game_surface.dart`

- [ ] **步骤 1：编写失败的有限恢复测试**

测试夹具为 `fitGameScreen` 增加按调用次数配置的失败队列。新增两个测试：第一次失败、第二次成功时 `reload` 为 0；连续两次失败时 `reload` 为 1。

```dart
fixture.port.fitFailures.addAll(<Object>[
  StateError('first'),
  StateError('second'),
]);
// 触发 pageFinished，推进 500 ms 重试延迟。
expect(fixture.port.calls.where((call) => call == 'fit'), hasLength(2));
expect(fixture.port.calls.where((call) => call == 'reload'), hasLength(1));
```

- [ ] **步骤 2：运行两个测试并确认现有代码不会重试或自动重载**

运行：`flutter test test/native_activity_game_surface_test.dart --plain-name "page initialization"`

预期：FAIL，`fit` 仅调用一次且 `reload` 为 0。

- [ ] **步骤 3：实现恢复策略和熔断**

页面收尾第一次失败后，在前台等待 500 毫秒并重试。第二次失败时，如 `_automaticRecoveryReloadUsed` 为 `false`，先置为 `true` 再调用 `port.reload()`；只有后续页面成功进入 `ready` 才重置标记。任何延迟后都重新校验端口、操作世代和页面世代。

- [ ] **步骤 4：运行恢复测试并确认通过**

运行：`flutter test test/native_activity_game_surface_test.dart --plain-name "page initialization"`

预期：新增恢复测试全部 PASS。

- [ ] **步骤 5：提交自动恢复**

```powershell
git add lib/src/native_activity_game_surface.dart test/native_activity_game_surface_test.dart
git commit -m "fix(原生模式): 限制页面初始化自动恢复"
```

### 任务 4：防止重载循环并提供手动重载

**文件：**
- 修改：`test/native_activity_game_surface_test.dart`
- 修改：`lib/src/native_activity_game_surface.dart`

- [ ] **步骤 1：编写失败的熔断和手动恢复测试**

模拟自动重载后新页面仍连续失败，断言 `reload` 总数仍为 1，错误界面存在 `native-game-surface-page-reload`。点击按钮后只增加一次用户发起的 `reload`。

- [ ] **步骤 2：运行测试并确认缺少手动按钮或发生重复重载**

运行：`flutter test test/native_activity_game_surface_test.dart --plain-name "automatic page recovery"`

预期：FAIL。

- [ ] **步骤 3：实现错误态手动重载入口**

新增 `_pageReloadAvailable`。最终失败或自动 `reload` 调用失败时设置为 `true`；错误覆盖层显示按钮。按钮将状态切回 `loadingGame`，清理当前待处理任务，并调用一次 `port.reload()`；调用失败时恢复错误态，不递归调用自动恢复。

- [ ] **步骤 4：运行原生页面完整测试**

运行：`flutter test test/native_activity_game_surface_test.dart`

预期：全部 PASS。

- [ ] **步骤 5：提交熔断和手动入口**

```powershell
git add lib/src/native_activity_game_surface.dart test/native_activity_game_surface_test.dart
git commit -m "fix(原生模式): 添加页面恢复熔断与手动重载"
```

### 任务 5：全量验证

**文件：**
- 验证：`lib/src/native_activity_game_surface.dart`
- 验证：`test/native_activity_game_surface_test.dart`

- [ ] **步骤 1：格式化修改文件**

运行：`dart format lib/src/native_activity_game_surface.dart test/native_activity_game_surface_test.dart`

- [ ] **步骤 2：运行相关测试**

运行：`flutter test test/native_activity_game_surface_test.dart test/native_game_surface_slot_test.dart test/native_game_webview_port_test.dart`

预期：全部 PASS。

- [ ] **步骤 3：运行静态分析**

运行：`flutter analyze`

预期：无新增 error 或 warning。

- [ ] **步骤 4：检查差异和工作区边界**

运行：`git diff --check HEAD~4..HEAD` 和 `git status --short`。

预期：本修复只修改计划列出的生产和测试文件；用户原有未提交修改保持原样。
