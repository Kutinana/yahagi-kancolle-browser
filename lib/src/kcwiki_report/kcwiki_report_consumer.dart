import '../bridge/captured_api_event.dart';
import '../game_state/game_api_event_pipeline.dart';
import '../game_state/game_state.dart';
import 'kcwiki_report_collector.dart';
import 'kcwiki_report_dispatcher.dart';
import 'kcwiki_report_settings.dart';

final class KcwikiReportConsumer implements GameApiEventConsumer {
  KcwikiReportConsumer({
    required this.controller,
    required this.collector,
    required this.dispatcher,
    required GameState Function() gameState,
    required Future<void> Function() waitForGameState,
  }) : _gameState = gameState,
       _waitForGameState = waitForGameState {
    controller.addListener(_onSettingsChanged);
    if (controller.enabled) dispatcher.start();
  }

  final KcwikiReportController controller;
  final KcwikiReportCollector collector;
  final KcwikiReportDispatcher dispatcher;
  final GameState Function() _gameState;
  final Future<void> Function() _waitForGameState;

  Future<void> _queue = Future<void>.value();
  int _session = 0;
  int _pendingEventCount = 0;
  bool _disposed = false;

  int get pendingEventCount => _pendingEventCount;

  @override
  bool supportsPath(String path) =>
      !_disposed &&
      controller.enabled &&
      KcwikiReportCollector.supportedPaths.contains(path);

  @override
  void accept(CapturedApiEvent event) {
    if (!supportsPath(event.path)) return;
    final session = _session;
    _pendingEventCount += 1;
    _queue = _queue.then(
      (_) => _process(event, session),
      onError: (_) => _process(event, session),
    );
  }

  Future<void> _process(CapturedApiEvent event, int session) async {
    try {
      await _waitForGameState();
      if (_disposed || session != _session || !controller.enabled) return;
      final reports = collector.accept(event, _gameState());
      if (_disposed || session != _session || !controller.enabled) return;
      for (final report in reports) {
        dispatcher.submit(report);
      }
    } catch (_) {
      if (!_disposed && session == _session) controller.recordDropped();
    } finally {
      _pendingEventCount -= 1;
    }
  }

  void _onSettingsChanged() {
    _session += 1;
    collector.reset();
    if (controller.enabled) {
      dispatcher.start();
    } else {
      dispatcher.stop();
    }
  }

  @override
  Future<void> get idle async {
    await _queue;
    await dispatcher.idle;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _session += 1;
    controller.removeListener(_onSettingsChanged);
    collector.reset();
    dispatcher.dispose();
  }
}
