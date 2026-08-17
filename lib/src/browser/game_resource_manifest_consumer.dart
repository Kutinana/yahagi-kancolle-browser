import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import '../bridge/captured_api_event.dart';
import 'game_resource_cache_channel.dart';
import '../game_state/game_api_event_pipeline.dart';
import 'game_resource_cache_controller.dart';
import 'game_resource_cache_store.dart';
import 'game_resource_baseline_catalog.dart';
import 'game_resource_manifest_builder.dart';

final class GameResourceManifestConsumer implements GameApiEventConsumer {
  GameResourceManifestConsumer({
    required this.controller,
    required this.ownedShipMasterIds,
    required this.ownedSlotItemMasterIds,
    required this.staticUrlsLoader,
    this.baselineLoader = GameResourceBaselineCatalog.loadCompressed,
    this.waitForGameState,
  }) : _lastMode = controller.mode {
    controller.addListener(_onControllerChanged);
  }

  final GameResourceCacheController controller;
  final Set<int> Function() ownedShipMasterIds;
  final Set<int> Function() ownedSlotItemMasterIds;
  final Future<List<String>> Function() staticUrlsLoader;
  final Future<Uint8List> Function() baselineLoader;
  final Future<void> Function()? waitForGameState;
  Future<void> _queue = Future<void>.value();
  String? _start2Body;
  String? _resourceOrigin;
  List<String>? _staticUrls;
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
    _start2Body = event.responseBody.isNotEmpty
        ? event.responseBody
        : jsonEncode(envelope);
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
    if (mode == GameResourceCacheMode.none) return;
    final start2Body = _start2Body;
    final origin = _resourceOrigin;
    if (start2Body == null || origin == null) return;
    Uint8List? baselineCompressed;
    var staticUrls = const <String>[];
    var shipIds = const <int>{};
    var slotItemIds = const <int>{};
    if (mode == GameResourceCacheMode.full) {
      baselineCompressed = await baselineLoader();
    } else {
      await waitForGameState?.call();
      if (_disposed || generation != _generation || controller.mode != mode) {
        return;
      }
      staticUrls = _staticUrls ??= await staticUrlsLoader();
      shipIds = ownedShipMasterIds();
      slotItemIds = ownedSlotItemMasterIds();
    }
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
          mode: mode,
          origin: origin,
          start2Body: start2Body,
          shipIds: shipIds,
          slotItemIds: slotItemIds,
          staticUrls: staticUrls,
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
  GameResourceCacheMode mode,
  String origin,
  String start2Body,
  Set<int> shipIds,
  Set<int> slotItemIds,
  List<String> staticUrls,
  Uint8List? baselineCompressed,
});

void _manifestBuildWorker(_ManifestBuildMessage message) {
  if (message.mode == GameResourceCacheMode.full) {
    final compressed = message.baselineCompressed;
    if (compressed == null) {
      throw StateError('Full cache mode requires a baseline manifest');
    }
    Isolate.exit(
      message.sendPort,
      GameResourceBaselineCatalog.decode(
        compressed: compressed,
        resourceOrigin: message.origin,
      ),
    );
  }
  final decoded = jsonDecode(message.start2Body);
  final envelope = decoded is Map
      ? Map<String, Object?>.from(decoded)
      : const <String, Object?>{};
  final dataValue = envelope['api_data'];
  final data = dataValue is Map
      ? Map<String, Object?>.from(dataValue)
      : const <String, Object?>{};
  final nested = data['start2'];
  final start2 = nested is Map ? Map<String, Object?>.from(nested) : data;
  final builder = GameResourceManifestBuilder(resourceOrigin: message.origin);
  final manifest = switch (message.mode) {
    GameResourceCacheMode.light => builder.buildLight(
      start2: start2,
      ownedShipMasterIds: message.shipIds,
      ownedSlotItemMasterIds: message.slotItemIds,
      staticUrls: message.staticUrls,
    ),
    GameResourceCacheMode.full => throw StateError(
      'Full cache manifest should have exited before start2 decoding',
    ),
    GameResourceCacheMode.none => throw StateError(
      'Disabled cache mode cannot build a manifest',
    ),
  };
  Isolate.exit(message.sendPort, manifest);
}
