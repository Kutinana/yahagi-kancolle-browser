# KCWiki 数据贡献上报实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在“设置 → 数据”加入默认关闭的 KCWiki 总开关，并在开启时以不阻塞原功能的方式收集、组装和上传六类 `report2` 数据。

**架构：** 新模块 `lib/src/kcwiki_report/` 将设置、会话组包和 HTTP 发送隔离。现有游戏事件管线只向 consumer 投递轻量事件；consumer 在自己的串行 Future 队列中等待游戏状态更新并组包，上传器使用另一条有界单并发队列，任何错误都被转换为无正文状态。原生捕获脚本根据总开关动态加入 KCWiki 独占路径。

**技术栈：** Flutter/Dart、`http`、`shared_preferences`、现有 `GameApiEventPipeline`、Flutter widget/unit tests。

---

## 文件结构

- 创建 `lib/src/kcwiki_report/kcwiki_report_settings.dart`：默认关闭的设置 Store、Controller 和只读传输状态。
- 创建 `lib/src/kcwiki_report/kcwiki_report_request.dart`：六类模块、编码方式和不可变请求对象。
- 创建 `lib/src/kcwiki_report/kcwiki_report_transport.dart`：HTTP 编码、正文限制、超时和 2xx 判定。
- 创建 `lib/src/kcwiki_report/kcwiki_report_dispatcher.dart`：独立有界单并发队列及启停生命周期。
- 创建 `lib/src/kcwiki_report/kcwiki_report_collector.dart`：六类跨事件会话状态与字段白名单组包。
- 创建 `lib/src/kcwiki_report/kcwiki_report_consumer.dart`：游戏事件管线隔离适配器。
- 创建 `lib/src/kcwiki_report/kcwiki_report_section.dart`：数据设置页中的贡献开关和状态。
- 修改 `lib/src/capture/game_capture_path_catalog.dart`：声明 KCWiki 独占及共享路径集合。
- 修改 `lib/src/bridge/native_game_capture_script.dart`：按开关构建不同目标路径脚本。
- 修改 `lib/src/game_webview.dart`：开关变化时只重新配置捕获脚本。
- 修改 `lib/src/settings/data_settings_page.dart`、`lib/src/settings/settings_page.dart`、`lib/main.dart`：依赖装配、设置入口和生命周期。
- 修改 `lib/l10n/app_zh.arb`、`lib/l10n/app_zh_Hant.arb`、`lib/l10n/app_ja.arb`：用户可见说明。
- 创建 `test/kcwiki_report_settings_test.dart`、`test/kcwiki_report_transport_test.dart`、`test/kcwiki_report_dispatcher_test.dart`、`test/kcwiki_report_collector_test.dart`、`test/kcwiki_report_consumer_test.dart`、`test/kcwiki_report_section_test.dart`：新功能测试。
- 修改 `test/game_capture_path_catalog_test.dart`、`test/native_game_capture_script_test.dart`、`test/data_settings_page_test.dart`：动态捕获及页面回归测试。

### 任务 1：默认关闭的设置和状态控制

**文件：**
- 创建：`lib/src/kcwiki_report/kcwiki_report_settings.dart`
- 测试：`test/kcwiki_report_settings_test.dart`

- [ ] **步骤 1：编写失败测试**

```dart
test('missing preference keeps KCWiki reporting disabled', () async {
  final store = MemoryKcwikiReportSettingsStore();
  final controller = await KcwikiReportController.load(store);
  expect(controller.enabled, isFalse);
});

test('disabling persists before notifying listeners', () async {
  final store = MemoryKcwikiReportSettingsStore(true);
  final controller = await KcwikiReportController.load(store);
  final seen = <bool>[];
  controller.addListener(() => seen.add(controller.enabled));
  await controller.setEnabled(false);
  expect(store.enabled, isFalse);
  expect(seen, <bool>[false]);
});
```

- [ ] **步骤 2：运行测试并确认因类型不存在而失败**

运行：`flutter test test/kcwiki_report_settings_test.dart`

- [ ] **步骤 3：实现最小设置 API**

实现 `KcwikiReportSettingsStore.loadEnabled/saveEnabled`、SharedPreferences key `kcwiki.report.enabled.v1`、默认 `false`、串行化 `setEnabled` 和 `KcwikiReportStatus`（模块、时间、HTTP 状态、成功/失败计数，不含正文）。

- [ ] **步骤 4：运行测试、格式化并提交**

运行：`dart format lib/src/kcwiki_report/kcwiki_report_settings.dart test/kcwiki_report_settings_test.dart && flutter test test/kcwiki_report_settings_test.dart`

提交：`git commit -m "feat: 添加 KCWiki 默认关闭设置（任务 1/7）"`

### 任务 2：有界且可停止的 HTTP 上传链路

**文件：**
- 创建：`lib/src/kcwiki_report/kcwiki_report_request.dart`
- 创建：`lib/src/kcwiki_report/kcwiki_report_transport.dart`
- 创建：`lib/src/kcwiki_report/kcwiki_report_dispatcher.dart`
- 测试：`test/kcwiki_report_transport_test.dart`
- 测试：`test/kcwiki_report_dispatcher_test.dart`

- [ ] **步骤 1：编写请求编码和失败隔离测试**

```dart
test('quest uses form encoding and battle uses JSON', () async {
  final client = RecordingClient();
  final transport = HttpKcwikiReportTransport(client: client, baseUri: base);
  await transport.send(KcwikiReportRequest.form(KcwikiReportModule.quest, {'current': 101}));
  await transport.send(KcwikiReportRequest.json(KcwikiReportModule.battle, {'data': {}}));
  expect(client.requests[0].headers['content-type'], contains('application/x-www-form-urlencoded'));
  expect(client.requests[1].headers['content-type'], contains('application/json'));
});

test('disabled dispatcher drops queued work and accepts no new work', () async {
  final transport = BlockingTransport();
  final dispatcher = KcwikiReportDispatcher(transportFactory: () => transport);
  dispatcher.start();
  expect(dispatcher.submit(request), isTrue);
  dispatcher.stop();
  expect(dispatcher.submit(request), isFalse);
  expect(dispatcher.pendingCount, 0);
});
```

- [ ] **步骤 2：运行两个测试并确认失败**

运行：`flutter test test/kcwiki_report_transport_test.dart test/kcwiki_report_dispatcher_test.dart`

- [ ] **步骤 3：实现传输和队列**

`KcwikiReportModule` 固定映射六个 `/api/report/*` 路径；请求对象在构造时 JSON/Form 编码并计算 UTF-8 字节数。Transport 使用 8 秒超时、2 MiB 单条上限且仅接受 2xx。Dispatcher 单并发、最多 16 条或 4 MiB；`stop()` 先翻转 epoch，再清空等待队列并关闭专用 transport，未捕获异常不得逃出 drain Future。

- [ ] **步骤 4：补充边界测试**

覆盖非 2xx、超时、2 MiB 超限、16 条/4 MiB 超限、停止后迟到响应以及传输异常后继续处理下一条。

- [ ] **步骤 5：运行测试、格式化并提交**

运行：`dart format lib/src/kcwiki_report test/kcwiki_report_transport_test.dart test/kcwiki_report_dispatcher_test.dart && flutter test test/kcwiki_report_transport_test.dart test/kcwiki_report_dispatcher_test.dart`

提交：`git commit -m "feat: 添加隔离的 KCWiki 上传队列（任务 2/7）"`

### 任务 3：六类白名单组包状态机

**文件：**
- 创建：`lib/src/kcwiki_report/kcwiki_report_collector.dart`
- 测试：`test/kcwiki_report_collector_test.dart`

- [ ] **步骤 1：先写任务和改修红灯测试**

```dart
test('completed quest reports newly unlocked quests only', () {
  collector.accept(questList([101, 102]), state);
  collector.accept(questClear(101), state);
  final reports = collector.accept(questList([102, 201, 301]), state);
  expect(reports.single.module, KcwikiReportModule.quest);
  expect(reports.single.fields['current'], 101);
  expect(reports.single.fields['after'], <int>[301]);
});

test('remodel detail includes assistant ship and selected recipe', () {
  collector.accept(remodelList(), stateWithAssistant);
  final reports = collector.accept(remodelDetail(apiId: 7), stateWithAssistant);
  expect(reports.single.fields.keys, containsAll(<String>['ship', 'list', 'timestamp', 'version']));
});
```

- [ ] **步骤 2：运行测试确认失败，然后实现 quest/remodel 最小逻辑**

运行：`flutter test test/kcwiki_report_collector_test.dart`

- [ ] **步骤 3：先写带路、陆航、友军和战斗红灯测试**

每类使用固定 `CapturedApiEvent` 和最小 `GameState`，分别断言模块、必需键、JSON/Form 编码、跨节点聚合、退出/重置清空，以及字段中递归不存在 `api_token`、`api_starttime`、`cookie`、`headers`。

- [ ] **步骤 4：实现六类组包**

使用 `decodedEnvelope['api_data']`，不重复 JSON 解析；舰队快照从 `GameState` 映射成旧 schema 的 `deck1/deck2/slot1/slot2`；33 式复用 `FleetMetrics`。战斗包只接收 `GameCapturePathCatalog.battlePhases/battleResults` 的响应，加入 `poi_time/poi_path` 兼容字段，并在下一节点或回港时封装 `data`。所有 Map/List 在进入请求前递归复制和敏感键过滤。

- [ ] **步骤 5：运行测试、格式化并提交**

运行：`dart format lib/src/kcwiki_report/kcwiki_report_collector.dart test/kcwiki_report_collector_test.dart && flutter test test/kcwiki_report_collector_test.dart`

提交：`git commit -m "feat: 实现 KCWiki 六类数据组包（任务 3/7）"`

### 任务 4：接入事件管线且不反向阻塞

**文件：**
- 创建：`lib/src/kcwiki_report/kcwiki_report_consumer.dart`
- 测试：`test/kcwiki_report_consumer_test.dart`
- 修改：`test/game_api_event_pipeline_test.dart`

- [ ] **步骤 1：编写失败隔离测试**

```dart
test('accept returns before state wait and upload finish', () {
  final stateGate = Completer<void>();
  final consumer = KcwikiReportConsumer(waitForGameState: () => stateGate.future, ...);
  consumer.accept(mapStartEvent);
  expect(consumer.pendingEventCount, 1);
});

test('report failures never stop another pipeline consumer', () async {
  final pipeline = GameApiEventPipeline(consumers: [failingReporter, recorder]);
  pipeline.add(event);
  await pipeline.idle;
  expect(recorder.events, <CapturedApiEvent>[event]);
});
```

- [ ] **步骤 2：运行测试确认失败并实现 consumer**

Consumer 的 `supportsPath` 在关闭时直接返回 `false`；开启时只匹配 KCWiki 白名单。`accept` 只追加到自身串行队列；队列等待已经排在它之前的 `GameStateController.idle`，再组包并调用 dispatcher。所有异常只更新 controller 状态。

- [ ] **步骤 3：运行测试、格式化并提交**

运行：`dart format lib/src/kcwiki_report/kcwiki_report_consumer.dart test/kcwiki_report_consumer_test.dart test/game_api_event_pipeline_test.dart && flutter test test/kcwiki_report_consumer_test.dart test/game_api_event_pipeline_test.dart`

提交：`git commit -m "feat: 隔离 KCWiki 游戏事件处理（任务 4/7）"`

### 任务 5：动态捕获路径和应用装配

**文件：**
- 修改：`lib/src/capture/game_capture_path_catalog.dart`
- 修改：`lib/src/bridge/native_game_capture_script.dart`
- 修改：`lib/src/game_webview.dart`
- 修改：`lib/main.dart`
- 修改：`test/game_capture_path_catalog_test.dart`
- 修改：`test/native_game_capture_script_test.dart`

- [ ] **步骤 1：写动态路径红灯测试**

```dart
test('default capture script excludes KCWiki-only paths', () {
  expect(buildNativeGameCaptureScript(kcwikiEnabled: false), isNot(contains('remodel_slotlist_detail')));
});

test('enabled capture script contains every KCWiki path', () {
  final script = buildNativeGameCaptureScript(kcwikiEnabled: true);
  for (final path in GameCapturePathCatalog.kcwiki) expect(script, contains(path));
});
```

- [ ] **步骤 2：运行测试确认失败并实现目录/脚本 API**

将 `all` 保持为原功能路径，新增 `kcwiki` 和 `allFor(kcwikiEnabled:)`；公开脚本构建函数。GameWebView 监听 controller，开关变化只调用现有 `prepareCapture()`，使用新脚本重新配置目标集合。

- [ ] **步骤 3：在 main 中装配**

启动时加载 Store/Controller，创建 dispatcher、collector、consumer；consumer 放在 `GameStateController` 后面；销毁时依次关闭 controller/consumer/dispatcher。基础 URL使用 `String.fromEnvironment('KCWIKI_REPORT_BASE_URL', defaultValue: 'http://report2.kcwiki.org:17027')`。

- [ ] **步骤 4：运行相关测试、格式化并提交**

运行：`dart format lib/main.dart lib/src/bridge/native_game_capture_script.dart lib/src/capture/game_capture_path_catalog.dart lib/src/game_webview.dart test/game_capture_path_catalog_test.dart test/native_game_capture_script_test.dart && flutter test test/game_capture_path_catalog_test.dart test/native_game_capture_script_test.dart test/game_capture_controller_test.dart test/game_api_event_pipeline_test.dart`

提交：`git commit -m "feat: 按 KCWiki 开关配置捕获路径（任务 5/7）"`

### 任务 6：数据设置页面开关和说明

**文件：**
- 创建：`lib/src/kcwiki_report/kcwiki_report_section.dart`
- 修改：`lib/src/settings/data_settings_page.dart`
- 修改：`lib/src/settings/settings_page.dart`
- 修改：`lib/main.dart`
- 修改：`lib/l10n/app_zh.arb`
- 修改：`lib/l10n/app_zh_Hant.arb`
- 修改：`lib/l10n/app_ja.arb`
- 测试：`test/kcwiki_report_section_test.dart`
- 修改：`test/data_settings_page_test.dart`

- [ ] **步骤 1：写 UI 红灯测试**

```dart
testWidgets('KCWiki contribution switch is off by default in data settings', (tester) async {
  await tester.pumpWidget(dataSettingsWith(KcwikiReportController.disabled()));
  final tile = tester.widget<SwitchListTile>(find.byKey(const Key('kcwiki-report-switch')));
  expect(tile.value, isFalse);
});

testWidgets('turning the switch off clears pending reports', (tester) async {
  await tester.tap(find.byKey(const Key('kcwiki-report-switch')));
  await tester.pump();
  expect(controller.enabled, isFalse);
  expect(dispatcher.pendingCount, 0);
});
```

- [ ] **步骤 2：运行测试确认失败并实现 Section**

区域标题“KCWiki 数据贡献”；说明六类数据、少量流量/电量、关闭后不上传。首次开启显示确认对话框，确认后持久化；关闭无需二次确认并立即停止 dispatcher。状态行只显示最近模块、时间和成功/失败。

- [ ] **步骤 3：生成本地化、运行 UI 回归并提交**

运行：`flutter gen-l10n && dart format lib/src/kcwiki_report/kcwiki_report_section.dart lib/src/settings/data_settings_page.dart lib/src/settings/settings_page.dart lib/main.dart test/kcwiki_report_section_test.dart test/data_settings_page_test.dart && flutter test test/kcwiki_report_section_test.dart test/data_settings_page_test.dart test/localization_contract_test.dart test/localization_resource_audit_test.dart`

提交：`git commit -m "feat: 在数据设置加入 KCWiki 贡献开关（任务 6/7）"`

### 任务 7：完整回归、静态检查和构建验证

**文件：**
- 修改：`docs/superpowers/plans/2026-08-25-kcwiki-data-reporting.md`（勾选完成项）

- [ ] **步骤 1：运行 KCWiki 专项测试**

运行：`flutter test test/kcwiki_report_settings_test.dart test/kcwiki_report_transport_test.dart test/kcwiki_report_dispatcher_test.dart test/kcwiki_report_collector_test.dart test/kcwiki_report_consumer_test.dart test/kcwiki_report_section_test.dart`

- [ ] **步骤 2：运行静态分析**

运行：`flutter analyze`

预期：`No issues found!`

- [ ] **步骤 3：运行全部 Flutter 测试**

运行：`flutter test`

预期：`All tests passed!`

- [ ] **步骤 4：运行 Android 单元测试和 Debug 构建**

运行：`flutter build apk --debug`

预期：exit code 0，并生成 `build/app/outputs/flutter-apk/app-debug.apk`。

- [ ] **步骤 5：检查差异和隐私字段**

运行：`git diff --check && rg -n "api_token|api_starttime|Cookie|headers" lib/src/kcwiki_report test/kcwiki_report_*`

预期：只有拒绝/过滤敏感字段的测试和实现引用；没有日志打印或上传映射。

- [ ] **步骤 6：提交最终验证记录**

提交：`git commit -m "test: 完成 KCWiki 上报回归验证（任务 7/7）"`
