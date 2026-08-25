import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../browser/game_toolbar_controller.dart';

abstract interface class BackgroundGameRetentionStore {
  Future<bool?> readEnabled();

  Future<void> writeEnabled(bool enabled);
}

final class SharedPreferencesBackgroundGameRetentionStore
    implements BackgroundGameRetentionStore {
  static const _key = 'background_game_retention_enabled';

  @override
  Future<bool?> readEnabled() async {
    return (await SharedPreferences.getInstance()).getBool(_key);
  }

  @override
  Future<void> writeEnabled(bool enabled) async {
    final saved = await (await SharedPreferences.getInstance()).setBool(
      _key,
      enabled,
    );
    if (!saved) {
      throw StateError('background game retention preference was not saved');
    }
  }
}

abstract interface class BackgroundGameRetentionPort {
  Future<void> setRetaining(bool retaining);
}

final class MethodChannelBackgroundGameRetentionPort
    implements BackgroundGameRetentionPort {
  const MethodChannelBackgroundGameRetentionPort([
    this.channel = const MethodChannel(
      'app.yahagi.kancollebrowser/background_game_retention',
    ),
  ]);

  final MethodChannel channel;

  @override
  Future<void> setRetaining(bool retaining) {
    return channel.invokeMethod<void>('setRetaining', <String, Object?>{
      'retaining': retaining,
    });
  }
}

final class BackgroundGameRetentionController extends ChangeNotifier {
  BackgroundGameRetentionController._(this._store, this._enabled);

  static Future<BackgroundGameRetentionController> load(
    BackgroundGameRetentionStore store,
  ) async {
    return BackgroundGameRetentionController._(
      store,
      await store.readEnabled() ?? true,
    );
  }

  final BackgroundGameRetentionStore _store;
  bool _enabled;
  String? _errorMessage;

  bool get enabled => _enabled;
  String? get errorMessage => _errorMessage;

  Future<void> setEnabled(bool enabled) async {
    if (_enabled == enabled) return;
    final previous = _enabled;
    _enabled = enabled;
    _errorMessage = null;
    notifyListeners();
    try {
      await _store.writeEnabled(enabled);
    } catch (error) {
      _enabled = previous;
      _errorMessage = '后台保持游戏设置失败：$error';
      notifyListeners();
    }
  }
}

final class BackgroundGameRetentionCoordinator {
  BackgroundGameRetentionCoordinator({
    required this.controller,
    required this.toolbarController,
    required this.port,
  }) {
    controller.addListener(_handleInputChanged);
    toolbarController.addListener(_handleInputChanged);
    _enqueueCurrentTarget();
  }

  final BackgroundGameRetentionController controller;
  final GameToolbarController toolbarController;
  final BackgroundGameRetentionPort port;

  bool _foreground = true;
  bool _detached = false;
  bool _disposed = false;
  bool? _pendingTarget;
  bool? _lastApplied;
  Future<void>? _drainFuture;
  String? _errorMessage;

  String? get errorMessage => _errorMessage;

  Future<void> handleLifecycleState(AppLifecycleState state) async {
    if (_disposed) return;
    switch (state) {
      case AppLifecycleState.resumed:
        _foreground = true;
        _detached = false;
      case AppLifecycleState.hidden || AppLifecycleState.paused:
        _foreground = false;
      case AppLifecycleState.detached:
        _detached = true;
      case AppLifecycleState.inactive:
        return;
    }
    _enqueueCurrentTarget();
  }

  Future<void> settle() => _drainFuture ?? Future<void>.value();

  void dispose() {
    if (_disposed) return;
    controller.removeListener(_handleInputChanged);
    toolbarController.removeListener(_handleInputChanged);
    _detached = true;
    _enqueueCurrentTarget();
    _disposed = true;
  }

  void _handleInputChanged() {
    if (_disposed) return;
    _enqueueCurrentTarget();
  }

  bool get _target =>
      !_detached &&
      !_foreground &&
      controller.enabled &&
      toolbarController.stage == GameSurfaceStage.game;

  void _enqueueCurrentTarget() {
    _pendingTarget = _target;
    if (_drainFuture != null) return;
    final drain = _drain();
    _drainFuture = drain.whenComplete(() {
      _drainFuture = null;
      if (_pendingTarget != null) _enqueueCurrentTarget();
    });
  }

  Future<void> _drain() async {
    while (true) {
      final target = _pendingTarget;
      if (target == null) return;
      _pendingTarget = null;
      if (_lastApplied == target) continue;
      try {
        await port.setRetaining(target);
        _lastApplied = target;
        _errorMessage = null;
      } catch (error) {
        _lastApplied = null;
        _errorMessage = '后台游戏会话同步失败：$error';
      }
    }
  }
}
