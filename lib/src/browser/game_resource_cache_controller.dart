import 'dart:async';

import 'package:flutter/foundation.dart';

import 'game_resource_cache_channel.dart';
import 'game_resource_cache_store.dart';

String formatCacheCompleteness(int cachedBytes, [int? targetBytes]) {
  final cachedGb = cachedBytes / 1000000000;
  return '${cachedGb.toStringAsFixed(2)} GB';
}

final class GameResourceCacheController extends ChangeNotifier {
  GameResourceCacheController({
    GameResourceCacheStore? store,
    GameResourceCachePort? port,
  }) : _store = store ?? SharedPreferencesGameResourceCacheStore(),
       _port = port ?? const MethodChannelGameResourceCachePort();

  final GameResourceCacheStore _store;
  final GameResourceCachePort _port;
  GameResourceCacheMode _mode = GameResourceCacheMode.temporary;
  GameResourceCacheStatus _status = GameResourceCacheStatus.empty;
  bool _initialized = false;
  bool _busy = false;
  bool _pageVisible = false;
  Future<void>? _refreshFuture;
  bool _refreshPending = false;
  Timer? _timer;

  GameResourceCacheMode get mode => _mode;
  GameResourceCacheStatus get status => _status;
  bool get initialized => _initialized;
  bool get busy => _busy;
  String get completenessLine =>
      formatCacheCompleteness(_status.cachedBytes, _status.targetBytes);

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

  Future<bool> submitManifest(
    GameResourceManifest manifest, {
    bool Function()? shouldContinue,
  }) async {
    final submitted = await _port.setManifest(
      manifest,
      shouldContinue: shouldContinue,
    );
    if (!submitted) return false;
    await refresh();
    return true;
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

  Future<void> refresh() {
    final active = _refreshFuture;
    if (active != null) {
      _refreshPending = true;
      return active;
    }
    late final Future<void> future;
    future = _refreshLoop().whenComplete(() {
      if (identical(_refreshFuture, future)) _refreshFuture = null;
    });
    _refreshFuture = future;
    return future;
  }

  Future<void> _refreshLoop() async {
    do {
      _refreshPending = false;
      _status = await _port.status();
      _updatePolling();
      notifyListeners();
    } while (_refreshPending);
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
