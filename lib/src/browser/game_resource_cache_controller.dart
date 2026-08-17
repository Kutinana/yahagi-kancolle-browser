import 'dart:async';

import 'package:flutter/foundation.dart';

import 'game_resource_cache_channel.dart';
import 'game_resource_cache_store.dart';

String formatCacheCompleteness(int cachedBytes, int targetBytes) {
  final cachedGb = cachedBytes / 1000000000;
  final targetGb = targetBytes / 1000000000;
  final percent = targetBytes <= 0
      ? 0.0
      : (cachedBytes / targetBytes * 100).clamp(0.0, 100.0);
  return '${cachedGb.toStringAsFixed(2)} GB / '
      '${targetGb.toStringAsFixed(2)} GB（${percent.toStringAsFixed(1)}%）';
}

final class GameResourceCacheController extends ChangeNotifier {
  GameResourceCacheController({
    GameResourceCacheStore? store,
    GameResourceCachePort? port,
  }) : _store = store ?? SharedPreferencesGameResourceCacheStore(),
       _port = port ?? const MethodChannelGameResourceCachePort();

  final GameResourceCacheStore _store;
  final GameResourceCachePort _port;
  GameResourceCacheMode _mode = GameResourceCacheMode.none;
  GameResourceCacheStatus _status = GameResourceCacheStatus.empty;
  bool _initialized = false;
  bool _busy = false;
  bool _pageVisible = false;
  Timer? _timer;

  GameResourceCacheMode get mode => _mode;
  GameResourceCacheStatus get status => _status;
  bool get initialized => _initialized;
  bool get busy => _busy;
  String get completenessLine => formatCacheCompleteness(
    _status.cachedBytes,
    _status.targetBytes > 0 ? _status.targetBytes : _status.maxBytes,
  );

  Future<void> initialize() async {
    _mode = await _store.load();
    await _port.configure(_mode);
    _status = await _port.status();
    _initialized = true;
    _updatePolling();
    notifyListeners();
  }

  Future<void> setMode(GameResourceCacheMode value) async {
    if (_mode == value && _initialized) return;
    _mode = value;
    await _store.save(value);
    await _port.configure(value);
    await refresh();
  }

  Future<void> submitManifest(GameResourceManifest manifest) async {
    await _port.setManifest(manifest);
    await refresh();
  }

  Future<bool> startDownload({bool allowMetered = false}) =>
      _action(() => _port.startDownload(allowMetered: allowMetered));
  Future<bool> pauseDownload() => _action(_port.pauseDownload);
  Future<bool> repair({bool allowMetered = false}) =>
      _action(() => _port.repair(allowMetered: allowMetered));
  Future<bool> clear() => _action(_port.clear);

  Future<GameResourceCacheStatus> checkIntegrity() async {
    _busy = true;
    notifyListeners();
    try {
      _status = await _port.checkIntegrity();
      return _status;
    } finally {
      _busy = false;
      _updatePolling();
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    _status = await _port.status();
    _updatePolling();
    notifyListeners();
  }

  void setPageVisible(bool visible) {
    _pageVisible = visible;
    _updatePolling();
  }

  Future<bool> _action(Future<bool> Function() action) async {
    _busy = true;
    notifyListeners();
    try {
      final result = await action();
      await refresh();
      return result;
    } finally {
      _busy = false;
      _updatePolling();
      notifyListeners();
    }
  }

  void _updatePolling() {
    final shouldPoll = _pageVisible || _status.isRunning;
    if (shouldPoll && _timer == null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => refresh());
    } else if (!shouldPoll) {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}
