# KCWiki 上报管线恢复实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 让默认关闭的 KCWiki 数据贡献在开启后可靠上传，切换开关不刷新游戏，大响应解析异常不会阻塞后续事件，并让用户看到可跨重启保留的真实状态。

**架构：** 捕获脚本始终安装 KCWiki 所需路径，但关闭时由 `KcwikiReportConsumer.supportsPath` 在 Dart 管线入口拒绝事件，因此不解析、不组包、不联网。顺序事件管线对后台解析设置 5 秒上限，超时后在当前 isolate 同步解析并继续原有顺序；管线只暴露路径、深度和降级次数等标量诊断。KCWiki 控制器持久化最近一次活动、时间和累计计数，dispatcher 明确上报排队、成功及失败原因。

**技术栈：** Flutter/Dart、WebView JavaScript 捕获桥、`dart:isolate`、`SharedPreferences`、`package:http`、Flutter widget/unit tests、Android ADB、MongoDB Compass/mongosh。

---

## 文件结构

- 修改 `lib/src/bridge/native_game_capture_script.dart`：生成与 KCWiki 开关无关的固定捕获脚本。
- 修改 `lib/src/game_webview.dart`：移除 Flutter WebView 对 KCWiki 控制器的监听和 reload 耦合。
- 修改 `lib/src/native_activity_game_surface.dart`：移除原生 Activity WebView 对 KCWiki 控制器的监听和 reload 耦合。
- 修改 `lib/main.dart`：停止向游戏表面传递 KCWiki 控制器；连接解析降级、dispatcher 状态和诊断指标。
- 修改 `lib/src/game_state/game_api_event_pipeline.dart`：增加后台解析超时、同步降级、始终准确的队列状态和标量运行态。
- 修改 `lib/src/diagnostics/diagnostic_event.dart`：记录当前 API 路径和累计解析降级次数，不记录请求或响应正文。
- 修改 `lib/src/diagnostics/diagnostic_performance_monitor.dart`：采样管线标量运行态。
- 修改 `lib/src/diagnostics/diagnostic_game_api_observer.dart`：让解析降级进入慢 API 诊断结果。
- 修改 `lib/src/kcwiki_report/kcwiki_report_settings.dart`：定义并持久化 KCWiki 活动状态、失败原因和累计计数。
- 修改 `lib/src/kcwiki_report/kcwiki_report_dispatcher.dart`：回调排队开始和完整 transport 失败原因。
- 修改 `lib/src/kcwiki_report/kcwiki_report_collector.dart`：允许测试 APK 用编译期 version 标签做只读云端对账，正式默认值保持 `yahagi-1`。
- 修改 `lib/src/settings/data_settings_page.dart`：展示等待、处理中、成功、失败和解析已恢复五种真实状态。
- 修改 `lib/l10n/app_zh.arb`、`lib/l10n/app_zh_Hant.arb`、`lib/l10n/app_ja.arb`：补充状态文本与时间占位符。
- 由 `flutter gen-l10n` 更新 `lib/l10n/app_localizations*.dart`。
- 修改 `test/native_game_capture_script_test.dart`：证明脚本固定包含 KCWiki 路径。
- 修改 `test/native_activity_game_surface_test.dart`：证明启动配置不依赖 KCWiki 开关。
- 修改 `test/game_api_event_pipeline_test.dart`：覆盖永久挂起、同步降级、顺序恢复和运行态清零。
- 修改 `test/diagnostic_event_test.dart`、`test/diagnostic_performance_monitor_test.dart`：覆盖无正文的新增诊断字段。
- 修改 `test/kcwiki_report_settings_test.dart`：覆盖状态持久化、失败分类和解析恢复不计成功。
- 修改 `test/kcwiki_report_dispatcher_test.dart`：覆盖排队和失败原因回调。
- 修改 `test/kcwiki_report_collector_test.dart`：锁定正式构建的默认 version。
- 修改 `test/data_settings_page_test.dart`：覆盖五种用户可见状态和默认关闭。

### 任务 1：固定捕获脚本并解除开关与游戏刷新耦合

**文件：**
- 修改：`test/native_game_capture_script_test.dart:41-47`
- 修改：`test/native_activity_game_surface_test.dart:329-351,2159-2185`
- 修改：`lib/src/bridge/native_game_capture_script.dart:5-11`
- 修改：`lib/src/game_webview.dart:227-327,695-924,1424-1431`
- 修改：`lib/src/native_activity_game_surface.dart:189-231,290-380,470-490,1170-1235,1355-1365`
- 修改：`lib/main.dart:700-810,1715-1740`

- [ ] **步骤 1：先把捕获脚本测试改成固定路径契约**

```dart
test('always embeds KCWiki-only paths without a runtime variant', () {
  expect(nativeGameCaptureScript, buildNativeGameCaptureScript());
  for (final path in GameCapturePathCatalog.kcwikiOnly) {
    expect(nativeGameCaptureScript, contains('"$path"'));
  }
});
```

- [ ] **步骤 2：运行测试确认旧实现失败**

运行：`flutter test test/native_game_capture_script_test.dart --plain-name "always embeds KCWiki-only paths without a runtime variant"`

预期：FAIL，因为当前默认脚本排除了 `GameCapturePathCatalog.kcwikiOnly`。

- [ ] **步骤 3：把脚本构造器改成无开关固定版本**

```diff
-String buildNativeGameCaptureScript({bool kcwikiEnabled = false}) {
-  final paths = GameCapturePathCatalog.allFor(
-    kcwikiEnabled: kcwikiEnabled,
-  ).toList(growable: false)..sort();
+String buildNativeGameCaptureScript() {
+  final paths = GameCapturePathCatalog.all.toList(growable: false)..sort();
```

该步骤对 JavaScript 正文不做任何行为修改；精确变更只有函数签名删除 `kcwikiEnabled`，以及 paths 初始化从 `GameCapturePathCatalog.allFor(...)` 改为 `GameCapturePathCatalog.all`。关闭时的短路仍由 `KcwikiReportConsumer.supportsPath` 保证。

- [ ] **步骤 4：写启动编排器的稳定脚本回归测试**

将原有 `default orchestrator changes only the opt-in KCWiki allowlist` 替换为：

```dart
test('default orchestrator reuses one capture allowlist', () async {
  final calls = <String>[];
  final capturePort = _RecordingCapturePort(calls);
  final fixture = await _DefaultOrchestratorFixture.create(
    calls,
    capturePortFactory: () => capturePort,
  );
  addTearDown(fixture.dispose);

  await fixture.orchestrator.prepareCapture();
  await fixture.orchestrator.prepareCapture();

  const kcwikiOnlyPath = '/kcsapi/api_req_kousyou/remodel_slotlist';
  expect(capturePort.scripts, hasLength(2));
  expect(capturePort.scripts.every((script) => script.contains(kcwikiOnlyPath)), isTrue);
  expect(capturePort.scripts.toSet(), hasLength(1));
});
```

- [ ] **步骤 5：运行测试确认编排器仍依赖旧参数**

运行：`flutter test test/native_activity_game_surface_test.dart --plain-name "default orchestrator reuses one capture allowlist"`

预期：FAIL，旧 `_DefaultOrchestratorFixture.create` 和 `DefaultGameSurfaceStartupOrchestrator` 仍允许按 KCWiki 开关构造不同脚本。

- [ ] **步骤 6：删除游戏表面对 KCWiki 设置的依赖**

在 `DefaultGameSurfaceStartupOrchestrator` 中删除 `kcwikiReportingEnabled` 字段和构造参数，并固定使用：

```dart
final script = nativeGameCaptureScript;
```

在 `GameWebView` 与 `NativeActivityGameSurface` 中删除：

```dart
final KcwikiReportController? kcwikiReportController;
late bool _kcwikiReportingEnabled;
```

同时完整删除 `_onKcwikiReportingChanged` 方法、对应 `addListener`、`removeListener`、`didUpdateWidget` 分支、startup dependency identity 比较，以及 `lib/main.dart` 中向两个游戏表面传递的 `kcwikiReportController:`。保留捕获模式变化触发 `prepareCapture + reload` 的既有逻辑，因为该逻辑仍服务于用户主动切换捕获模式。

- [ ] **步骤 7：运行相关测试确认开关不再能触发游戏刷新路径**

运行：`flutter test test/native_game_capture_script_test.dart test/native_activity_game_surface_test.dart test/game_environment_host_test.dart`

预期：PASS；原有捕获模式 reload 测试继续通过，KCWiki 只存在于设置页和 report consumer。

- [ ] **步骤 8：提交固定脚本与解耦改动**

```bash
git add lib/src/bridge/native_game_capture_script.dart lib/src/game_webview.dart lib/src/native_activity_game_surface.dart lib/main.dart test/native_game_capture_script_test.dart test/native_activity_game_surface_test.dart
git commit -m "fix(KCWiki): 切换贡献开关时不再刷新游戏"
```

### 任务 2：为顺序 API 管线增加后台解析超时与同步降级

**文件：**
- 修改：`test/game_api_event_pipeline_test.dart:137-186,228-255`
- 修改：`lib/src/game_state/game_api_event_pipeline.dart:8-146`

- [ ] **步骤 1：写永久挂起时仍恢复顺序的失败测试**

```dart
test('a hung background decode falls back synchronously and preserves order', () async {
  final consumer = _RecordingConsumer();
  final observer = _RecordingPipelineObserver();
  final never = Completer<Map<String, Object?>>();
  var syncCalls = 0;
  final pipeline = GameApiEventPipeline(
    consumers: <GameApiEventConsumer>[consumer],
    observer: observer,
    decodeEnvelope: (_) => never.future,
    decodeSmallEnvelope: (body) {
      syncCalls += 1;
      return GameApiDecoder.decodeEnvelope(body);
    },
    backgroundDecodeTimeout: const Duration(milliseconds: 10),
  );

  pipeline
    ..add(_event('/kcsapi/api_start2/getData', _body(1), sequence: 1))
    ..add(_event('/kcsapi/api_port/port', _body(2), sequence: 2));
  await pipeline.idle.timeout(const Duration(seconds: 1));

  expect(consumer.events.map((event) => event.sequence), <int>[1, 2]);
  expect(syncCalls, 2);
  expect(observer.timings.first.usedSynchronousFallback, isTrue);
  expect(pipeline.pendingEventCount, 0);
  expect(pipeline.activePath, isNull);
  expect(pipeline.backgroundFallbackCount, 1);
});
```

- [ ] **步骤 2：运行测试确认当前队列永久卡住**

运行：`flutter test test/game_api_event_pipeline_test.dart --plain-name "a hung background decode falls back synchronously and preserves order"`

预期：FAIL，构造器没有 `backgroundDecodeTimeout`，`GameApiTiming` 没有 `usedSynchronousFallback`。

- [ ] **步骤 3：给 timing 和 pipeline 增加明确运行态**

```dart
final class GameApiTiming {
  const GameApiTiming({
    required this.path,
    required this.responseBytes,
    required this.queueDepth,
    required this.queueWaitMicros,
    required this.decodeMicros,
    required this.dispatchMicros,
    required this.success,
    required this.usedSynchronousFallback,
  });
  // 保留既有字段
  final bool usedSynchronousFallback;
}

final class GameApiEventPipeline {
  GameApiEventPipeline({
    required List<GameApiEventConsumer> consumers,
    GameApiEnvelopeDecoder? decodeEnvelope,
    GameApiSyncEnvelopeDecoder? decodeSmallEnvelope,
    this.observer,
    this.backgroundThresholdBytes = 64 * 1024,
    this.backgroundDecodeTimeout = const Duration(seconds: 5),
    this.onBackgroundDecodeFallback,
  }) : assert(backgroundThresholdBytes > 0),
       assert(backgroundDecodeTimeout > Duration.zero),
       _consumers = List<GameApiEventConsumer>.unmodifiable(consumers),
       _decodeEnvelope = decodeEnvelope ?? _decodeInBackground,
       _decodeSmallEnvelope =
           decodeSmallEnvelope ?? GameApiDecoder.decodeEnvelope;

  final Duration backgroundDecodeTimeout;
  final void Function(String path)? onBackgroundDecodeFallback;
  String? _activePath;
  int _backgroundFallbackCount = 0;

  String? get activePath => _activePath;
  int get backgroundFallbackCount => _backgroundFallbackCount;
}
```

- [ ] **步骤 4：让 pending count 与 observer 是否启用无关**

把 `add` 统一为一条队列路径：每次先增加 `_pendingEventCount`，记录 `queueDepth` 和 stopwatch；在 `_prepareDispatchAndObserve` 的 `finally` 中总是减一，仅当 observer 非空时调用 `onCompleted`。方法参数使用 `GameApiPipelineObserver? target`，不能再在 observer 为 null 时绕过计数。

```dart
void add(CapturedApiEvent event) {
  _pendingEventCount += 1;
  final queueDepth = _pendingEventCount;
  final queued = Stopwatch()..start();
  _queue = _queue.then(
    (_) => _prepareDispatchAndObserve(event, observer, queued, queueDepth),
    onError: (_) => _prepareDispatchAndObserve(event, observer, queued, queueDepth),
  );
}
```

- [ ] **步骤 5：实现 5 秒超时后的同步解析降级**

在 `_prepareAndDispatch` 中只对后台解析分支使用 timeout，并把降级事实带回 timing：

```dart
var usedSynchronousFallback = false;
_activePath = event.path;
try {
  if (!event.hasDecodedEnvelope) {
    try {
      Map<String, Object?> envelope;
      if (_shouldDecodeInBackground(event)) {
        try {
          envelope = await _decodeEnvelope(event.responseBody)
              .timeout(backgroundDecodeTimeout);
        } on TimeoutException {
          usedSynchronousFallback = true;
          _backgroundFallbackCount += 1;
          onBackgroundDecodeFallback?.call(event.path);
          envelope = _decodeSmallEnvelope(event.responseBody);
        }
      } else {
        envelope = _decodeSmallEnvelope(event.responseBody);
      }
      prepared = event.withDecodedEnvelope(envelope);
    } catch (_) {
      success = false;
    }
  }
  // 保留按顺序 dispatch
} finally {
  _activePath = null;
}
```

文件顶部增加 `import 'dart:async';`。返回 record 增加 `usedSynchronousFallback`，并传入 `GameApiTiming`。后台 isolate 将来即使迟到也不再接触队列状态。

- [ ] **步骤 6：覆盖后台异常与同步降级异常边界**

新增两个测试：

```dart
test('a fast background exception keeps the original event path', () async {
  final consumer = _RecordingConsumer();
  final pipeline = GameApiEventPipeline(
    consumers: <GameApiEventConsumer>[consumer],
    decodeEnvelope: (_) async => throw const FormatException('broken'),
  );
  pipeline.add(_event('/kcsapi/api_start2/getData', 'broken'));
  await pipeline.idle;
  expect(consumer.events.single.hasDecodedEnvelope, isFalse);
  expect(pipeline.pendingEventCount, 0);
});

test('a failed synchronous fallback releases the following event', () async {
  final consumer = _RecordingConsumer();
  final pipeline = GameApiEventPipeline(
    consumers: <GameApiEventConsumer>[consumer],
    decodeEnvelope: (_) => Completer<Map<String, Object?>>().future,
    decodeSmallEnvelope: (body) {
      if (body == 'broken') throw const FormatException('broken');
      return GameApiDecoder.decodeEnvelope(body);
    },
    backgroundDecodeTimeout: const Duration(milliseconds: 10),
  );
  pipeline
    ..add(_event('/kcsapi/api_start2/getData', 'broken', sequence: 1))
    ..add(_event('/kcsapi/api_port/port', _body(2), sequence: 2));
  await pipeline.idle.timeout(const Duration(seconds: 1));
  expect(consumer.events.map((event) => event.sequence), <int>[1, 2]);
  expect(pipeline.pendingEventCount, 0);
});
```

- [ ] **步骤 7：运行整个管线测试**

运行：`flutter test test/game_api_event_pipeline_test.dart`

预期：PASS，且测试进程不因未完成的 fake future 挂住。

- [ ] **步骤 8：提交解析恢复改动**

```bash
git add lib/src/game_state/game_api_event_pipeline.dart test/game_api_event_pipeline_test.dart
git commit -m "fix(数据管线): 大响应解析超时后同步恢复"
```

### 任务 3：补充不含用户数据的管线诊断

**文件：**
- 修改：`test/diagnostic_event_test.dart:43-75`
- 修改：`test/diagnostic_performance_monitor_test.dart:1-24`
- 修改：`lib/src/diagnostics/diagnostic_event.dart:42-72,112-155`
- 修改：`lib/src/diagnostics/diagnostic_game_api_observer.dart:18-40`
- 修改：`lib/src/diagnostics/diagnostic_performance_monitor.dart:55-145`
- 修改：`lib/main.dart:385-435`

- [ ] **步骤 1：写诊断标量与隐私边界测试**

```dart
test('performance sample records pipeline state without payloads', () {
  final event = DiagnosticEvent.performanceSample(
    occurredAt: DateTime.utc(2026, 8, 26),
    uptimeMs: 1000,
    pssKb: 1,
    javaHeapKb: 1,
    nativeHeapKb: 1,
    graphicsKb: 1,
    privateOtherKb: 1,
    systemAvailableKb: 1,
    webViewHost: DiagnosticWebViewHost.activityDirect,
    renderer: DiagnosticGameRenderer.webgl,
    generationId: 1,
    totalFrames: 1,
    over16Ms: 0,
    over33Ms: 0,
    over100Ms: 0,
    maxFrameMicros: 1000,
    pendingApiEvents: 3,
    activeApiPath: '/kcsapi/api_start2/getData',
    backgroundDecodeFallbacks: 2,
    databaseBytes: 1,
  );
  final encoded = jsonEncode(event.toJson());
  expect(encoded, contains('"backgroundDecodeFallbacks":2'));
  expect(encoded, contains('/kcsapi/api_start2/getData'));
  expect(encoded, isNot(contains('responseBody')));
  expect(encoded, isNot(contains('requestParams')));
});
```

- [ ] **步骤 2：运行测试确认签名尚未支持新增字段**

运行：`flutter test test/diagnostic_event_test.dart`

预期：FAIL，`performanceSample` 不接受 `activeApiPath` 和 `backgroundDecodeFallbacks`。

- [ ] **步骤 3：扩展事件与 slow API 标记**

给 `DiagnosticEvent.performanceSample` 增加：

```dart
required String? activeApiPath,
required int backgroundDecodeFallbacks,
```

字段映射使用：

```dart
'activeApiPath': activeApiPath == null ? null : _policy.safeApiPath(activeApiPath),
'backgroundDecodeFallbacks': backgroundDecodeFallbacks,
```

给 `DiagnosticEvent.slowApi` 增加必填 `bool usedSynchronousFallback` 并存为同名布尔字段。更新全部调用和测试；绝不添加 response body、request params、decoded envelope 或完整 URL。

- [ ] **步骤 4：让 observer 记录发生过降级的事件**

```dart
if (timing.success &&
    !timing.usedSynchronousFallback &&
    totalMicros < slowThreshold.inMicroseconds) {
  return;
}
```

随后把 `timing.usedSynchronousFallback` 传给 `DiagnosticEvent.slowApi`。

- [ ] **步骤 5：让性能 monitor 接收两个只读 getter**

构造器增加：

```dart
required this.activeApiPath,
required this.backgroundDecodeFallbacks,
```

字段类型分别是 `String? Function()` 和 `int Function()`；采样时传入 `activeApiPath()` 与 `backgroundDecodeFallbacks()`。

- [ ] **步骤 6：在 main 中连接 pipeline getter**

```dart
activeApiPath: () => gameApiEventPipeline.activePath,
backgroundDecodeFallbacks: () =>
    gameApiEventPipeline.backgroundFallbackCount,
```

- [ ] **步骤 7：运行诊断和管线测试**

运行：`flutter test test/diagnostic_event_test.dart test/diagnostic_performance_monitor_test.dart test/game_api_event_pipeline_test.dart`

预期：PASS，诊断 JSON 仅出现安全 API path 和数字/布尔标量。

- [ ] **步骤 8：提交诊断改动**

```bash
git add lib/src/diagnostics/diagnostic_event.dart lib/src/diagnostics/diagnostic_game_api_observer.dart lib/src/diagnostics/diagnostic_performance_monitor.dart lib/main.dart test/diagnostic_event_test.dart test/diagnostic_performance_monitor_test.dart test/game_api_event_pipeline_test.dart
git commit -m "feat(诊断): 记录 API 解析降级运行态"
```

### 任务 4：持久化 KCWiki 真实上传状态

**文件：**
- 修改：`test/kcwiki_report_settings_test.dart:1-82`
- 修改：`test/kcwiki_report_dispatcher_test.dart`
- 修改：`lib/src/kcwiki_report/kcwiki_report_settings.dart:1-130`
- 修改：`lib/src/kcwiki_report/kcwiki_report_dispatcher.dart:1-135`
- 修改：`lib/main.dart:305-330,350-365`

- [ ] **步骤 1：定义状态与失败分类的测试契约**

```dart
test('upload status and counters survive controller reload', () async {
  final store = MemoryKcwikiReportSettingsStore(true);
  final first = await KcwikiReportController.load(store);
  first.recordQueued(module: 'battle', occurredAt: DateTime.utc(2026, 8, 26));
  first.recordResult(
    module: 'battle',
    succeeded: true,
    occurredAt: DateTime.utc(2026, 8, 26, 1),
    statusCode: 200,
  );
  await first.settled;
  first.dispose();

  final restored = await KcwikiReportController.load(store);
  addTearDown(restored.dispose);
  expect(restored.status.activity, KcwikiReportActivity.succeeded);
  expect(restored.status.module, 'battle');
  expect(restored.status.succeededCount, 1);
  expect(restored.status.occurredAt, DateTime.utc(2026, 8, 26, 1));
});

test('parse recovery is visible but does not increment upload success', () async {
  final controller = await KcwikiReportController.load(
    MemoryKcwikiReportSettingsStore(true),
  );
  addTearDown(controller.dispose);
  controller.recordParseRecovered(
    path: '/kcsapi/api_start2/getData',
    occurredAt: DateTime.utc(2026, 8, 26),
  );
  expect(controller.status.activity, KcwikiReportActivity.parseRecovered);
  expect(controller.status.succeededCount, 0);
  expect(controller.status.failedCount, 0);
});
```

- [ ] **步骤 2：运行测试确认状态目前只在内存中**

运行：`flutter test test/kcwiki_report_settings_test.dart`

预期：FAIL，没有 `activity`、`recordQueued`、`recordParseRecovered`、`settled` 或状态存储接口。

- [ ] **步骤 3：定义可序列化状态模型**

```dart
enum KcwikiReportActivity { waiting, processing, succeeded, failed, parseRecovered }

enum KcwikiReportFailure {
  httpRejected,
  bodyTooLarge,
  timeout,
  network,
  queueFull,
  local,
}

final class KcwikiReportStatus {
  const KcwikiReportStatus({
    this.activity = KcwikiReportActivity.waiting,
    this.module,
    this.path,
    this.occurredAt,
    this.statusCode,
    this.failure,
    this.succeededCount = 0,
    this.failedCount = 0,
    this.droppedCount = 0,
  });
  final KcwikiReportActivity activity;
  final String? module;
  final String? path;
  final DateTime? occurredAt;
  final int? statusCode;
  final KcwikiReportFailure? failure;
  final int succeededCount;
  final int failedCount;
  final int droppedCount;

  Map<String, Object?> toJson() => <String, Object?>{
    'activity': activity.name,
    'module': module,
    'path': path,
    'occurredAt': occurredAt?.toUtc().toIso8601String(),
    'statusCode': statusCode,
    'failure': failure?.name,
    'succeededCount': succeededCount,
    'failedCount': failedCount,
    'droppedCount': droppedCount,
  };

  factory KcwikiReportStatus.fromJson(Map<String, Object?> json) {
    T enumValue<T extends Enum>(List<T> values, Object? raw, T fallback) {
      if (raw is! String) return fallback;
      for (final value in values) {
        if (value.name == raw) return value;
      }
      return fallback;
    }

    int nonNegative(Object? raw) => raw is int && raw >= 0 ? raw : 0;
    final occurredAtRaw = json['occurredAt'];
    return KcwikiReportStatus(
      activity: enumValue(
        KcwikiReportActivity.values,
        json['activity'],
        KcwikiReportActivity.waiting,
      ),
      module: json['module'] is String ? json['module']! as String : null,
      path: json['path'] is String ? json['path']! as String : null,
      occurredAt: occurredAtRaw is String
          ? DateTime.tryParse(occurredAtRaw)?.toUtc()
          : null,
      statusCode: json['statusCode'] is int
          ? json['statusCode']! as int
          : null,
      failure: json['failure'] == null
          ? null
          : enumValue(
              KcwikiReportFailure.values,
              json['failure'],
              KcwikiReportFailure.local,
            ),
      succeededCount: nonNegative(json['succeededCount']),
      failedCount: nonNegative(json['failedCount']),
      droppedCount: nonNegative(json['droppedCount']),
    );
  }
}
```

不得存储请求体或响应体。

- [ ] **步骤 4：扩展 store 并用 JSON 保存状态**

```dart
abstract interface class KcwikiReportSettingsStore {
  Future<bool> loadEnabled();
  Future<void> saveEnabled(bool enabled);
  Future<KcwikiReportStatus> loadStatus();
  Future<void> saveStatus(KcwikiReportStatus status);
}
```

`SharedPreferencesKcwikiReportSettingsStore` 使用新 key `kcwiki.report.status.v1` 存取 `jsonEncode(status.toJson())`；读取损坏 JSON 时返回 `const KcwikiReportStatus()`。`MemoryKcwikiReportSettingsStore` 增加 `KcwikiReportStatus status` 字段并实现相同接口。

- [ ] **步骤 5：让 controller 串行、容错地持久化状态**

`load` 同时读取 enabled 和 status；新增：

```dart
Future<void> _statusQueue = Future<void>.value();
Future<void> get settled async {
  await _changeQueue;
  await _statusQueue;
}
```

每次状态变化先同步更新内存并 `notifyListeners()`，再把不可变 snapshot 排入 `_statusQueue`；`saveStatus` 失败只吞掉该次状态持久化错误，不反抛到游戏或上报管线。

新增 `recordQueued`、`recordResult`、`recordParseRecovered`、`recordDropped`。其中：成功仅增加 `succeededCount`；失败仅增加 `failedCount`；解析恢复两个计数都不增加；丢弃增加 `droppedCount` 并设置 `failure: queueFull`。

- [ ] **步骤 6：先写 dispatcher 排队和失败原因测试**

```dart
test('accepted submit announces processing before its result', () async {
  final events = <String>[];
  final dispatcher = KcwikiReportDispatcher(
    transportFactory: () => _CompletingTransport(
      const KcwikiTransportResult.accepted(statusCode: 200),
    ),
    onQueued: (module) => events.add('queued:${module.wireName}'),
    onResult: (result) => events.add('result:${result.module.wireName}'),
  )..start();
  dispatcher.submit(_request(KcwikiReportModule.battle));
  await dispatcher.idle;
  expect(events, <String>['queued:battle', 'result:battle']);
});

test('transport failure is preserved in dispatch result', () async {
  KcwikiDispatchResult? observed;
  final dispatcher = KcwikiReportDispatcher(
    transportFactory: () => _CompletingTransport(
      const KcwikiTransportResult.failed(
        failure: KcwikiTransportFailure.timeout,
      ),
    ),
    onResult: (result) => observed = result,
  )..start();
  dispatcher.submit(_request(KcwikiReportModule.battle));
  await dispatcher.idle;
  expect(observed?.failure, KcwikiTransportFailure.timeout);
});
```

- [ ] **步骤 7：把 dispatcher 状态完整传出**

`KcwikiDispatchResult` 增加 `KcwikiTransportFailure? failure`；`KcwikiReportDispatcher` 增加 `void Function(KcwikiReportModule module)? onQueued`。只有 `submit` 真正入队后才调用 `onQueued(request.module)`；结果回调传入 `result.failure`。队列/字节上限拒绝继续调用 `onDropped`，不做自动重试。

- [ ] **步骤 8：在 main 中连接状态和解析恢复**

```dart
onQueued: (module) => kcwikiReportController.recordQueued(
  module: module.wireName,
  occurredAt: DateTime.now(),
),
onResult: (result) => kcwikiReportController.recordResult(
  module: result.module.wireName,
  succeeded: result.accepted,
  occurredAt: DateTime.now(),
  statusCode: result.statusCode,
  failure: switch (result.failure) {
    KcwikiTransportFailure.bodyTooLarge => KcwikiReportFailure.bodyTooLarge,
    KcwikiTransportFailure.timeout => KcwikiReportFailure.timeout,
    KcwikiTransportFailure.network => KcwikiReportFailure.network,
    KcwikiTransportFailure.rejected => KcwikiReportFailure.httpRejected,
    null => null,
  },
),
```

创建 `GameApiEventPipeline` 时连接：

```dart
onBackgroundDecodeFallback: (path) {
  if (!kcwikiReportController.enabled) return;
  kcwikiReportController.recordParseRecovered(
    path: path,
    occurredAt: DateTime.now(),
  );
},
```

- [ ] **步骤 9：运行设置、dispatcher、consumer 和 transport 测试**

运行：`flutter test test/kcwiki_report_settings_test.dart test/kcwiki_report_dispatcher_test.dart test/kcwiki_report_consumer_test.dart test/kcwiki_report_transport_test.dart`

预期：PASS；网络失败不重试、不抛出，controller 重建后仍保留最近状态与计数。

- [ ] **步骤 10：提交持久化状态改动**

```bash
git add lib/src/kcwiki_report/kcwiki_report_settings.dart lib/src/kcwiki_report/kcwiki_report_dispatcher.dart lib/main.dart test/kcwiki_report_settings_test.dart test/kcwiki_report_dispatcher_test.dart
git commit -m "feat(KCWiki): 持久化贡献状态与累计计数"
```

### 任务 5：在数据设置页显示准确状态

**文件：**
- 修改：`test/data_settings_page_test.dart:65-125`
- 修改：`lib/src/settings/data_settings_page.dart:265-295`
- 修改：`lib/l10n/app_zh.arb:724-736`
- 修改：`lib/l10n/app_zh_Hant.arb:724-736`
- 修改：`lib/l10n/app_ja.arb:724-736`
- 生成：`lib/l10n/app_localizations.dart`
- 生成：`lib/l10n/app_localizations_zh.dart`
- 生成：`lib/l10n/app_localizations_ja.dart`

- [ ] **步骤 1：写五种状态的 widget 测试**

给测试 fixture 保留同一个 `MemoryKcwikiReportSettingsStore(true)`，依次调用 controller 方法并 `pump()`：

```dart
expect(find.textContaining('正在等待可贡献的数据'), findsOneWidget);

kcwiki.recordQueued(module: 'battle', occurredAt: DateTime.utc(2026, 8, 26));
await tester.pump();
expect(find.textContaining('正在上传：battle'), findsOneWidget);

kcwiki.recordResult(
  module: 'battle',
  succeeded: true,
  occurredAt: DateTime.utc(2026, 8, 26, 1, 2, 3),
  statusCode: 200,
);
await tester.pump();
expect(find.textContaining('最近上传成功：battle'), findsOneWidget);
expect(find.textContaining('成功 1'), findsOneWidget);

kcwiki.recordResult(
  module: 'quest',
  succeeded: false,
  occurredAt: DateTime.utc(2026, 8, 26, 1, 3, 4),
  failure: KcwikiReportFailure.network,
);
await tester.pump();
expect(find.textContaining('网络失败'), findsOneWidget);

kcwiki.recordParseRecovered(
  path: '/kcsapi/api_start2/getData',
  occurredAt: DateTime.utc(2026, 8, 26, 1, 4, 5),
);
await tester.pump();
expect(find.textContaining('解析超时已恢复'), findsOneWidget);
expect(find.textContaining('成功 1'), findsOneWidget);
```

- [ ] **步骤 2：运行 widget 测试确认旧页面只有等待/成功/失败**

运行：`flutter test test/data_settings_page_test.dart --plain-name "KCWiki reporting shows persistent activity states"`

预期：FAIL，处理中、解析恢复和失败分类文本尚不存在。

- [ ] **步骤 3：增加三语状态文本**

在三个 ARB 中定义同一组 key：

```json
"kcwikiReportProcessing": "正在上传：{module} · {time}",
"kcwikiReportParseRecovered": "大型数据解析超时已恢复，后续数据已继续处理 · {time}",
"kcwikiReportFailureHttp": "HTTP {status}",
"kcwikiReportFailureTimeout": "连接超时",
"kcwikiReportFailureNetwork": "网络失败",
"kcwikiReportFailureBodyTooLarge": "数据超过单次上限",
"kcwikiReportFailureQueueFull": "本地等待队列已满",
"kcwikiReportFailureLocal": "本地处理失败"
```

为带占位符条目添加 ARB metadata，`module/time/status` 类型均为 `String`。同步修改 `kcwikiReportLastSuccess` 和 `kcwikiReportLastFailure`，让文案包含 `{time}`；日语和繁体使用对应自然语言翻译，不混用简体文本。

- [ ] **步骤 4：生成本地化 Dart 文件**

运行：`flutter gen-l10n`

预期：命令成功，`app_localizations*.dart` 出现 `kcwikiReportProcessing`、`kcwikiReportParseRecovered`、`kcwikiReportFailure*` 和 `kcwikiReportCounters`。

- [ ] **步骤 5：按 activity 渲染状态而非推测 lastSucceeded**

```dart
final status = controller.status;
final time = status.occurredAt == null
    ? '—'
    : _formatKcwikiTime(status.occurredAt!.toLocal());
final detail = switch (status.activity) {
  KcwikiReportActivity.waiting => l10n.kcwikiReportWaiting,
  KcwikiReportActivity.processing =>
    l10n.kcwikiReportProcessing(status.module ?? '—', time),
  KcwikiReportActivity.succeeded => l10n.kcwikiReportLastSuccess(
    status.module ?? '—', time, status.succeededCount,
    status.failedCount, status.droppedCount,
  ),
  KcwikiReportActivity.failed => l10n.kcwikiReportLastFailure(
    status.module ?? '—', _kcwikiFailureText(l10n, status), time,
    status.succeededCount, status.failedCount, status.droppedCount,
  ),
  KcwikiReportActivity.parseRecovered =>
    '${l10n.kcwikiReportParseRecovered(time)} · '
    '${l10n.kcwikiReportCounters(status.succeededCount, status.failedCount, status.droppedCount)}',
};
return '${l10n.kcwikiReportEnabledDesc}\n$detail';
```

新增 `_formatKcwikiTime`，固定输出 `yyyy-MM-dd HH:mm:ss`；新增 `_kcwikiFailureText` 用 exhaustive switch 映射六种 `KcwikiReportFailure`。ARB 另加 `kcwikiReportCounters` 以避免拼接不可翻译的计数标签。

- [ ] **步骤 6：运行页面和本地化测试**

运行：`flutter test test/data_settings_page_test.dart test/kcwiki_report_settings_test.dart`

预期：PASS；默认仍关闭，开启确认框仍存在，关闭后只显示“不收集、不组包、不联网”。

- [ ] **步骤 7：提交状态 UI 改动**

```bash
git add lib/src/settings/data_settings_page.dart lib/l10n/app_zh.arb lib/l10n/app_zh_Hant.arb lib/l10n/app_ja.arb lib/l10n/app_localizations.dart lib/l10n/app_localizations_zh.dart lib/l10n/app_localizations_ja.dart test/data_settings_page_test.dart
git commit -m "feat(KCWiki): 展示真实贡献进度和失败原因"
```

### 任务 6：完整自动化验证、真机验证与云端对账

**文件：**
- 验证：`lib/**`
- 验证：`test/**`
- 修改：`lib/src/kcwiki_report/kcwiki_report_collector.dart`
- 修改：`test/kcwiki_report_collector_test.dart`
- 产物：`build/app/outputs/flutter-apk/app-release.apk`

- [ ] **步骤 1：格式化并确认没有静态错误**

运行：

```bash
dart format lib test
flutter analyze
```

预期：`flutter analyze` 退出码 0，没有 warning 或 error。若 formatter 改动文件，将相应改动补入其所属任务提交，不单独混入无关文件。

- [ ] **步骤 2：运行 KCWiki 与管线聚焦测试**

运行：

```bash
flutter test test/native_game_capture_script_test.dart test/game_api_event_pipeline_test.dart test/kcwiki_report_collector_test.dart test/kcwiki_report_transport_test.dart test/kcwiki_report_dispatcher_test.dart test/kcwiki_report_consumer_test.dart test/kcwiki_report_settings_test.dart test/data_settings_page_test.dart test/diagnostic_event_test.dart test/diagnostic_performance_monitor_test.dart
```

预期：全部 PASS，0 个失败。

- [ ] **步骤 3：运行完整测试套件**

运行：`flutter test --reporter compact`

预期：不少于基线的 1790 个测试通过，只有既有 7 个显式 skipped，0 个失败。

- [ ] **步骤 4：构建 release APK**

先把 collector 的常量改成正式默认不变、测试构建可覆盖的形式：

```dart
static const String schemaVersion = String.fromEnvironment(
  'KCWIKI_REPORT_VERSION',
  defaultValue: 'yahagi-1',
);
```

在 `test/kcwiki_report_collector_test.dart` 增加：

```dart
test('KCWiki production schema version remains yahagi-1', () {
  expect(KcwikiReportCollector.schemaVersion, 'yahagi-1');
});
```

先运行：`flutter test test/kcwiki_report_collector_test.dart --plain-name "KCWiki production schema version remains yahagi-1"`

预期：PASS，普通测试环境没有传 dart-define，因而使用正式默认值。

再运行：`flutter build apk --release --dart-define=KCWIKI_REPORT_VERSION=yahagi-pipeline-recovery-20260826`

预期：退出码 0，生成 `build/app/outputs/flutter-apk/app-release.apk`。

- [ ] **步骤 5：确认 Wi-Fi ADB 设备并保留应用数据安装**

运行：

```bash
adb devices -l
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

预期：目标手机状态为 `device`，安装返回 `Success`。不使用 `-t -d`，不清除应用数据。

- [ ] **步骤 6：验证开关不会刷新游戏**

清空本次 logcat 后启动应用，在已进入游戏的情况下把“设置 → 数据 → KCWiki 数据贡献”连续开关 10 次；检查画面不重新载入、舰队状态不消失。随后运行：

```bash
adb logcat -d | Select-String -Pattern 'reload|capture reconfiguration|pageStarted|pageFinished|KCWiki'
```

预期：10 次开关没有对应的 WebView reload/pageStarted；关闭状态没有 `report2.kcwiki.org` 请求。

- [ ] **步骤 7：验证普通出击、状态与队列恢复**

保持开关开启，记录设置页当前成功计数。普通海域完成 4 个节点和 4 场战斗后返回母港，等待最多 15 秒，再查看设置页。

预期：显示最近上传成功，成功计数恰好增加 8；处理中状态会结束；诊断中的 `pendingApiEvents` 回到 0、`activeApiPath` 回到 null。若触发大响应超时，页面可短暂/最终显示“解析超时已恢复”，但成功计数只由真实 HTTP 2xx 增加。

- [ ] **步骤 8：验证断网不影响游戏且不重试**

在 KCWiki 开启时临时断开外网，产生一条可贡献记录并等待 transport 的 8 秒超时。

预期：游戏继续正常操作；页面显示连接超时或网络失败；失败计数增加 1；恢复网络后不会自动重发该失败记录。关闭 KCWiki 后不再产生上报连接。

- [ ] **步骤 9：用测试 version 对云端做精确对账**

使用步骤 4 构建的测试 APK，在只读 MongoDB `47.115.214.238:9018/kcwiki-development` 查询：

```javascript
db.nextwayv2records.countDocuments({version: 'yahagi-pipeline-recovery-20260826'})
db.battlerecords.countDocuments({'data.version': 'yahagi-pipeline-recovery-20260826'})
db.nextwayv2records.find({version: 'yahagi-pipeline-recovery-20260826'}, {_id: 1, version: 1}).sort({_id: -1}).limit(4)
db.battlerecords.find({'data.version': 'yahagi-pipeline-recovery-20260826'}, {_id: 1, 'data.version': 1}).sort({_id: -1}).limit(4)
```

预期：本轮 4 节点、4 战斗分别新增 4 条，总计 8 条，数据库 `_id` 均为本轮新记录；与应用成功计数增量一致。只执行查询，不写入、修改或删除数据库记录。

- [ ] **步骤 10：提交最终验证所需的小修正**

如果步骤 1-9 没有产生代码修正则跳过此提交；若产生，只加入 KCWiki 范围内文件：

```bash
git add lib/main.dart lib/src/bridge/native_game_capture_script.dart lib/src/game_state/game_api_event_pipeline.dart lib/src/diagnostics/diagnostic_event.dart lib/src/diagnostics/diagnostic_game_api_observer.dart lib/src/diagnostics/diagnostic_performance_monitor.dart lib/src/kcwiki_report/kcwiki_report_settings.dart lib/src/kcwiki_report/kcwiki_report_dispatcher.dart lib/src/kcwiki_report/kcwiki_report_collector.dart lib/src/settings/data_settings_page.dart lib/l10n/app_zh.arb lib/l10n/app_zh_Hant.arb lib/l10n/app_ja.arb lib/l10n/app_localizations.dart lib/l10n/app_localizations_zh.dart lib/l10n/app_localizations_ja.dart test/native_game_capture_script_test.dart test/game_api_event_pipeline_test.dart test/kcwiki_report_settings_test.dart test/kcwiki_report_dispatcher_test.dart test/kcwiki_report_collector_test.dart test/data_settings_page_test.dart test/diagnostic_event_test.dart test/diagnostic_performance_monitor_test.dart
git commit -m "test(KCWiki): 完成真机上传与云端对账"
```

- [ ] **步骤 11：检查分支边界并准备本地合并**

运行：

```bash
git status --short
git log --oneline master..HEAD
git diff --check master...HEAD
```

预期：工作树干净；提交只包含本计划文件；`git diff --check` 无输出。回到主工作区合并前，确认用户原有未跟踪文件 `android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameTouchFeedbackScript.kt` 仍未被添加、修改或删除。

计划执行完成后，使用 `finishing-a-development-branch` 技能把 `fix/kcwiki-report-pipeline` 合并回本地 `master`，在合并后的 `master` 再运行聚焦测试并构建最终 APK，供用户安装测试。
