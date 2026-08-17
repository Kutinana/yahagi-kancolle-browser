import '../bridge/captured_api_event.dart';
import '../game_state/game_api_event_pipeline.dart';
import 'game_resource_cache_controller.dart';
import 'game_resource_cache_store.dart';
import 'game_resource_manifest_builder.dart';

final class GameResourceManifestConsumer implements GameApiEventConsumer {
  GameResourceManifestConsumer({
    required this.controller,
    required this.ownedShipMasterIds,
    required this.ownedSlotItemMasterIds,
    required this.staticUrlsLoader,
    this.waitForGameState,
  }) : _lastMode = controller.mode {
    controller.addListener(_onControllerChanged);
  }

  final GameResourceCacheController controller;
  final Set<int> Function() ownedShipMasterIds;
  final Set<int> Function() ownedSlotItemMasterIds;
  final Future<List<String>> Function() staticUrlsLoader;
  final Future<void> Function()? waitForGameState;
  Future<void> _queue = Future<void>.value();
  Map<String, Object?>? _start2;
  String? _resourceOrigin;
  List<String>? _staticUrls;
  GameResourceCacheMode _lastMode;
  bool _disposed = false;

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
    _start2 = normalized;
    _resourceOrigin = event.sourceOrigin;
    _scheduleRebuild();
  }

  @override
  Future<void> get idle => _queue;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    controller.removeListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (_lastMode == controller.mode) return;
    _lastMode = controller.mode;
    _scheduleRebuild();
  }

  void _scheduleRebuild() {
    _queue = _queue.then((_) => _rebuild(), onError: (_) => _rebuild());
  }

  Future<void> _rebuild() async {
    if (_disposed || controller.mode == GameResourceCacheMode.none) return;
    final start2 = _start2;
    final origin = _resourceOrigin;
    if (start2 == null || origin == null) return;
    await waitForGameState?.call();
    final staticUrls = _staticUrls ??= await staticUrlsLoader();
    final builder = GameResourceManifestBuilder(resourceOrigin: origin);
    final manifest = switch (controller.mode) {
      GameResourceCacheMode.light => builder.buildLight(
        start2: start2,
        ownedShipMasterIds: ownedShipMasterIds(),
        ownedSlotItemMasterIds: ownedSlotItemMasterIds(),
        staticUrls: staticUrls,
      ),
      GameResourceCacheMode.full => builder.buildFull(
        start2: start2,
        staticUrls: staticUrls,
      ),
      GameResourceCacheMode.none => null,
    };
    if (manifest != null) await controller.submitManifest(manifest);
  }

  static Map<String, Object?>? _map(Object? value) =>
      value is Map ? Map<String, Object?>.from(value) : null;

  static int _asInt(Object? value) => switch (value) {
    num number => number.toInt(),
    String text => int.tryParse(text) ?? 0,
    _ => 0,
  };
}
