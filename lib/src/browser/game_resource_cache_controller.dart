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
  bool _manifestError = false;
  bool _busy = false;
  int _busyCount = 0;
  Future<void> _modeChangeTail = Future<void>.value();
  bool _pageVisible = false;
  Future<void>? _refreshFuture;
  bool _refreshPending = false;
  Timer? _timer;

  GameResourceCacheMode get mode => _mode;
  GameResourceCacheStatus get status => _status;
  bool get initialized => _initialized;
  bool get manifestError => _manifestError;
  bool get busy => _busy;
  String get completenessLine =>
      formatCacheCompleteness(_status.cachedBytes, _status.targetBytes);

  Future<void> initialize() async {
    try {
      _mode = await _store.load();
      if (!await _port.configure(_mode)) {
        _mode = GameResourceCacheMode.temporary;
        if (!await _port.configure(_mode)) {
          throw StateError('Local cache configuration failed');
        }
        await _store.save(_mode);
      }
      _status = await _port.status();
      _initialized = true;
      _updatePolling();
    } catch (_) {
      // Cache I/O is optional and must not block the browser's startup.
      _mode = GameResourceCacheMode.temporary;
      _status = GameResourceCacheStatus.empty;
      _initialized = false;
    }
    notifyListeners();
  }

  Future<bool> setMode(GameResourceCacheMode value) {
    _beginBusy();
    final pending = _modeChangeTail.then((_) => _applyMode(value));
    _modeChangeTail = pending.then<void>((_) {});
    return pending.whenComplete(_endBusy);
  }

  Future<bool> _applyMode(GameResourceCacheMode value) async {
    if (_mode == value && _initialized) return true;
    final previous = _mode;
    try {
      if (!await _port.configure(value)) {
        await _restoreNativeMode(previous);
        return false;
      }
      await _store.save(value);
      _mode = value;
      try {
        await refresh();
      } catch (_) {
        notifyListeners();
      }
      return true;
    } catch (_) {
      if (_mode == previous) await _restoreNativeMode(previous);
      return false;
    }
  }

  Future<void> _restoreNativeMode(GameResourceCacheMode previous) async {
    try {
      if (!await _port.configure(previous)) {
        _initialized = false;
        notifyListeners();
      }
    } catch (_) {
      _initialized = false;
      notifyListeners();
    }
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
    if (_manifestError) {
      _manifestError = false;
      notifyListeners();
    }
    await refresh();
    return true;
  }

  void reportManifestFailure() {
    if (_manifestError) return;
    _manifestError = true;
    notifyListeners();
  }

  Future<bool> startDownload({bool allowMetered = false}) =>
      _action(() => _port.startDownload(allowMetered: allowMetered));
  Future<bool> pauseDownload() => _action(_port.pauseDownload);
  Future<bool> repair({bool allowMetered = false}) =>
      _action(() => _port.repair(allowMetered: allowMetered));
  Future<bool> clear() => _action(_port.clear);

  Future<GameResourceCacheStatus> checkIntegrity() async {
    _beginBusy();
    try {
      _status = await _port.checkIntegrity();
      return _status;
    } finally {
      _endBusy();
      _updatePolling();
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
    _beginBusy();
    try {
      final result = await action();
      await refresh();
      return result;
    } catch (_) {
      try {
        await refresh();
      } catch (_) {
        // The operation failed; keep the last usable status for the UI.
      }
      return false;
    } finally {
      _endBusy();
      _updatePolling();
    }
  }

  void _beginBusy() {
    _busyCount++;
    _busy = true;
    notifyListeners();
  }

  void _endBusy() {
    _busyCount--;
    _busy = _busyCount > 0;
    notifyListeners();
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
