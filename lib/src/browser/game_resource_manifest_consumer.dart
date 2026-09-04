import 'dart:isolate';
import 'dart:typed_data';

import '../bridge/captured_api_event.dart';
import 'game_resource_cache_channel.dart';
import '../game_state/game_api_event_pipeline.dart';
import 'game_resource_cache_controller.dart';
import 'game_resource_cache_store.dart';
import 'game_resource_baseline_catalog.dart';

final class GameResourceManifestConsumer implements GameApiEventConsumer {
  GameResourceManifestConsumer({
    required this.controller,
    required Set<int> Function() ownedShipMasterIds,
    required Set<int> Function() ownedSlotItemMasterIds,
    required Future<List<String>> Function() staticUrlsLoader,
    this.baselineLoader = GameResourceBaselineCatalog.loadCompressed,
    Future<void> Function()? waitForGameState,
  }) : _lastMode = controller.mode {
    controller.addListener(_onControllerChanged);
  }

  final GameResourceCacheController controller;
  final Future<Uint8List> Function() baselineLoader;
  Future<void> _queue = Future<void>.value();
  String? _resourceOrigin;
  GameResourceCacheMode _lastMode;
  bool _disposed = false;
  int _generation = 0;
  Isolate? _activeBuildIsolate;

  @override
  bool supportsPath(String path) => path == '/kcsapi/api_start2/getData';

  @override
  void accept(CapturedApiEvent event) {
    if (_disposed || !supportsPath(event.path)) return;
    final envelope = event.decodedEnvelope;
    if (envelope == null || _asInt(envelope['api_result']) != 1) return;
    final data = _map(envelope['api_data']);
    final normalized = _map(data?['start2']) ?? data;
    if (normalized == null || event.sourceOrigin.isEmpty) return;
    _resourceOrigin = event.sourceOrigin;
    _scheduleRebuild();
  }

  @override
  Future<void> get idle => _queue;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _activeBuildIsolate?.kill(priority: Isolate.immediate);
    _activeBuildIsolate = null;
    controller.removeListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (_lastMode == controller.mode) return;
    _lastMode = controller.mode;
    _scheduleRebuild();
  }

  void _scheduleRebuild() {
    _activeBuildIsolate?.kill(priority: Isolate.immediate);
    _activeBuildIsolate = null;
    final generation = ++_generation;
    _queue = _queue.then(
      (_) => _rebuild(generation),
      onError: (_) => _rebuild(generation),
    );
  }

  Future<void> _rebuild(int generation) async {
    if (_disposed || generation != _generation) return;
    final mode = controller.mode;
    if (mode != GameResourceCacheMode.full) return;
    final origin = _resourceOrigin;
    if (origin == null) return;
    final baselineCompressed = await baselineLoader();
    if (_disposed || generation != _generation || controller.mode != mode) {
      return;
    }
    final receivePort = ReceivePort();
    Isolate? isolate;
    Object? message;
    try {
      isolate = await Isolate.spawn(
        _manifestBuildWorker,
        (
          sendPort: receivePort.sendPort,
          origin: origin,
          baselineCompressed: baselineCompressed,
        ),
        onError: receivePort.sendPort,
        onExit: receivePort.sendPort,
      );
      if (_disposed || generation != _generation || controller.mode != mode) {
        return;
      }
      _activeBuildIsolate = isolate;
      message = await receivePort.first;
    } finally {
      if (identical(_activeBuildIsolate, isolate)) {
        _activeBuildIsolate = null;
      }
      isolate?.kill(priority: Isolate.immediate);
      receivePort.close();
    }
    if (message is List<Object?> && message.length >= 2) {
      throw StateError('Manifest worker failed: ${message.first}');
    }
    if (message is! GameResourceManifest) return;
    final manifest = message;
    if (_disposed || generation != _generation || controller.mode != mode) {
      return;
    }
    await controller.submitManifest(
      manifest,
      shouldContinue: () =>
          !_disposed && generation == _generation && controller.mode == mode,
    );
  }

  static Map<String, Object?>? _map(Object? value) =>
      value is Map ? Map<String, Object?>.from(value) : null;

  static int _asInt(Object? value) => switch (value) {
    num number => number.toInt(),
    String text => int.tryParse(text) ?? 0,
    _ => 0,
  };
}

typedef _ManifestBuildMessage = ({
  SendPort sendPort,
  String origin,
  Uint8List baselineCompressed,
});

void _manifestBuildWorker(_ManifestBuildMessage message) {
  Isolate.exit(
    message.sendPort,
    GameResourceBaselineCatalog.decode(
      compressed: message.baselineCompressed,
      resourceOrigin: message.origin,
    ),
  );
}
