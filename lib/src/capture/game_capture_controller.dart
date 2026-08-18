import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../bridge/captured_api_event.dart';
import 'game_capture_port.dart';

final class GameCaptureController extends ChangeNotifier {
  GameCaptureController({
    this.maxResponseBytes = 8 * 1024 * 1024,
    this.onAcceptedEvent,
  }) : assert(maxResponseBytes > 0);

  final int maxResponseBytes;
  final ValueChanged<CapturedApiEvent>? onAcceptedEvent;
  final ValueNotifier<int> _eventActivity = ValueNotifier<int>(0);

  GameCapturePort? _port;
  GameCapturePort? _desiredPort;
  StreamSubscription<CapturedApiEvent>? _subscription;
  Future<void>? _configurationDrain;
  int _configurationRevision = 0;
  int _processedRevision = 0;
  final Map<int, Completer<void>> _configurationWaiters =
      <int, Completer<void>>{};
  bool _desiredEnabled = false;
  bool _disposed = false;

  GameCaptureState _state = GameCaptureState.disabled;
  bool? _configuredEnabled;
  String? _configuredScript;
  String _script = '';
  int _responseBytes = 0;
  int _capturedCount = 0;
  CapturedApiEvent? _latestEvent;
  String? _errorMessage;

  GameCaptureState get state => _state;
  CapturedApiEvent? get latestEvent => _latestEvent;
  int get capturedCount => _capturedCount;
  Listenable get eventActivity => _eventActivity;
  int get responseBytes => _responseBytes;
  String? get errorMessage => _errorMessage;

  Future<void> attach(
    GameCapturePort port, {
    required bool enabled,
    String script = '',
  }) async {
    if (_disposed) return;
    _script = script;
    _desiredPort = port;
    _desiredEnabled = enabled;
    await _enqueueConfiguration();
  }

  Future<void> configure({required bool enabled, String? script}) async {
    if (_disposed) return;
    if (script != null) {
      _script = script;
    }
    _desiredEnabled = enabled;
    if (!enabled) {
      _state = GameCaptureState.disabled;
      _errorMessage = null;
      notifyListeners();
    }
    await _enqueueConfiguration();
  }

  Future<void> _enqueueConfiguration() {
    if (_disposed) return Future<void>.value();
    final revision = ++_configurationRevision;
    final waiter = Completer<void>();
    _configurationWaiters[revision] = waiter;
    _ensureConfigurationDrain();
    return waiter.future;
  }

  void _ensureConfigurationDrain() {
    if (_configurationDrain != null || _disposed) return;
    final operation = _drainConfigurations();
    _configurationDrain = operation;
    unawaited(
      operation.whenComplete(() {
        if (identical(_configurationDrain, operation)) {
          _configurationDrain = null;
        }
        if (!_disposed && _processedRevision < _configurationRevision) {
          _ensureConfigurationDrain();
        }
      }),
    );
  }

  Future<void> _drainConfigurations() async {
    while (!_disposed && _processedRevision < _configurationRevision) {
      final revision = _configurationRevision;
      final port = _desiredPort;
      final enabled = _desiredEnabled;
      final script = _script;

      if (!identical(_port, port)) {
        try {
          await _subscription?.cancel();
        } catch (error, stackTrace) {
          debugPrint(
            'Capture subscription cancellation failed: $error\n$stackTrace',
          );
        }
        if (!_isCurrentConfiguration(revision, port)) {
          _completeConfigurationThrough(revision);
          continue;
        }
        _port = port;
        _subscription = port?.events.listen((event) {
          if (identical(_port, port)) _onEvent(event);
        });
        _configuredEnabled = null;
        _configuredScript = null;
      }

      await _applyConfiguration(revision, port, enabled, script);
      _processedRevision = revision;
      _completeConfigurationThrough(revision);
    }
  }

  Future<void> _applyConfiguration(
    int revision,
    GameCapturePort? port,
    bool enabled,
    String script,
  ) async {
    if (port == null) {
      if (enabled && _isCurrentConfiguration(revision, port)) {
        _state = GameCaptureState.checking;
        notifyListeners();
      }
      return;
    }

    try {
      if (!enabled) {
        if (_configuredEnabled != false) {
          await port.configure(enabled: false, script: '');
        }
        if (!_isCurrentConfiguration(revision, port)) return;
        _configuredEnabled = false;
        _configuredScript = '';
        _state = GameCaptureState.disabled;
        _errorMessage = null;
        notifyListeners();
        return;
      }

      if (_isCurrentConfiguration(revision, port)) {
        _state = GameCaptureState.checking;
        _errorMessage = null;
        notifyListeners();
      }
      if (!await port.isSupported()) {
        if (!_isCurrentConfiguration(revision, port)) return;
        _state = GameCaptureState.unsupported;
        notifyListeners();
        return;
      }
      if (!_isCurrentConfiguration(revision, port)) return;
      if (_configuredEnabled != true || _configuredScript != script) {
        await port.configure(enabled: true, script: script);
      }
      if (!_isCurrentConfiguration(revision, port)) return;
      _configuredEnabled = true;
      _configuredScript = script;
      _state = _latestEvent == null
          ? GameCaptureState.ready
          : GameCaptureState.capturing;
    } catch (error) {
      if (!_isCurrentConfiguration(revision, port)) return;
      _state = GameCaptureState.error;
      _errorMessage = _safeError(error);
    }
    notifyListeners();
  }

  bool _isCurrentConfiguration(int revision, GameCapturePort? port) {
    return !_disposed &&
        revision == _configurationRevision &&
        identical(port, _desiredPort);
  }

  void _completeConfigurationThrough(int revision) {
    final completed = _configurationWaiters.keys
        .where((key) => key <= revision)
        .toList(growable: false);
    for (final key in completed) {
      _configurationWaiters.remove(key)?.complete();
    }
  }

  void _onEvent(CapturedApiEvent event) {
    if (_disposed ||
        _configuredEnabled != true ||
        _state == GameCaptureState.disabled ||
        _state == GameCaptureState.unsupported) {
      return;
    }

    final eventBytes =
        event.responseByteLength ?? utf8.encode(event.responseBody).length;
    if (eventBytes > maxResponseBytes) {
      return;
    }
    final statusChanged =
        _state != GameCaptureState.capturing || _errorMessage != null;
    _latestEvent = event;
    _responseBytes = eventBytes;
    _capturedCount += 1;
    _state = GameCaptureState.capturing;
    _errorMessage = null;
    onAcceptedEvent?.call(event);
    _eventActivity.value = _capturedCount;
    if (statusChanged) notifyListeners();
  }

  String _safeError(Object error) {
    final type = error.runtimeType.toString();
    return '捕获配置失败（$type）';
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _configurationRevision += 1;
    _desiredPort = null;
    _port = null;
    _configuredEnabled = null;
    for (final waiter in _configurationWaiters.values) {
      waiter.complete();
    }
    _configurationWaiters.clear();
    final cancellation = _subscription?.cancel();
    if (cancellation != null) {
      unawaited(cancellation.catchError((Object _) {}));
    }
    _eventActivity.dispose();
    super.dispose();
  }
}
