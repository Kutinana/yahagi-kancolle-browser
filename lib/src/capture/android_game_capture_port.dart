import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../bridge/captured_api_event.dart';
import 'game_capture_port.dart';
import 'game_capture_startup_sequence.dart';

const MethodChannel _defaultGameCaptureChannel = MethodChannel(
  'app.yahagi.kancollebrowser/game_capture',
);

GameCapturePort createPlatformGameCapturePort() {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return MethodChannelGameCapturePort();
  }
  return const UnsupportedGameCapturePort();
}

final class MethodChannelGameCapturePort implements GameCapturePort {
  MethodChannelGameCapturePort({
    this.channel = _defaultGameCaptureChannel,
    this.configurationTimeout = const Duration(seconds: 10),
  }) : _configurationArbiter = _configurationArbiters.putIfAbsent(
         channel.name,
         _CaptureConfigurationArbiter.new,
       ) {
    _configurationArbiter.claim(_handlerOwner);
    _handlerOwners[channel.name] = _handlerOwner;
    channel.setMethodCallHandler(_onMethodCall);
  }

  static final Map<String, Object> _handlerOwners = <String, Object>{};
  static final Map<String, _CaptureConfigurationArbiter>
  _configurationArbiters = <String, _CaptureConfigurationArbiter>{};

  @visibleForTesting
  static void resetArbitersForTesting() {
    _configurationArbiters.clear();
    _handlerOwners.clear();
  }

  @visibleForTesting
  static int get arbiterCountForTesting => _configurationArbiters.length;

  final MethodChannel channel;
  final Duration configurationTimeout;
  final Object _handlerOwner = Object();
  final _CaptureConfigurationArbiter _configurationArbiter;
  final StreamController<CapturedApiEvent> _events =
      StreamController<CapturedApiEvent>.broadcast();
  bool _disposed = false;

  @override
  Stream<CapturedApiEvent> get events => _events.stream;

  @override
  Future<bool> isSupported() async {
    try {
      return await channel.invokeMethod<bool>('isSupported') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<void> configure({required bool enabled, required String script}) {
    if (_disposed) return Future<void>.value();
    return _configurationArbiter.run(_handlerOwner, configurationTimeout, () {
      return GameCaptureStartupSequence.configureWithRetry(
        configure: () async {
          try {
            await channel.invokeMethod<void>('configure', <String, Object?>{
              'enabled': enabled,
              'script': script,
            });
          } on PlatformException catch (error) {
            if (error.code == 'webview_not_found') {
              throw const GameWebViewNotReadyException();
            }
            rethrow;
          }
        },
      );
    });
  }

  Future<void> _onMethodCall(MethodCall call) async {
    if (call.method != 'onCaptureEvent' || _events.isClosed) {
      return;
    }
    try {
      final decoded = AndroidCaptureEvent.decode(call.arguments);
      if (decoded is CapturedApiEvent) {
        _events.add(decoded);
      }
    } on FormatException {
      // Native validation is repeated in Dart. Invalid messages are ignored
      // without logging their potentially sensitive response body.
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (identical(_handlerOwners[channel.name], _handlerOwner)) {
      _handlerOwners.remove(channel.name);
      channel.setMethodCallHandler(null);
    }
    _configurationArbiter.release(
      _handlerOwner,
      onIdle: () {
        if (identical(
          _configurationArbiters[channel.name],
          _configurationArbiter,
        )) {
          _configurationArbiters.remove(channel.name);
        }
      },
    );
    unawaited(_events.close());
  }
}

final class _CaptureConfigurationArbiter {
  Object? _activeOwner;
  Future<void> _tail = Future<void>.value();
  int _pending = 0;
  int _revision = 0;
  _CaptureConfigurationCommand? _desired;
  void Function()? _onIdle;

  void claim(Object owner) {
    _activeOwner = owner;
    _revision += 1;
    _desired = null;
    _onIdle = null;
  }

  Future<void> run(
    Object owner,
    Duration timeout,
    Future<void> Function() operation,
  ) {
    if (!identical(_activeOwner, owner)) return Future<void>.value();
    final revision = ++_revision;
    final command = _CaptureConfigurationCommand(
      owner: owner,
      revision: revision,
      timeout: timeout,
      operation: operation,
    );
    _desired = command;
    return _enqueue(command);
  }

  Future<void> _enqueue(_CaptureConfigurationCommand command) {
    _pending += 1;
    final scheduled = _tail.then<void>((_) async {
      if (!_isCurrent(command)) return;
      var timedOut = false;
      final raw = Future<void>.sync(command.operation);
      unawaited(
        raw.then<void>(
          (_) {
            if (timedOut) _replayAfterLateCompletion(command);
          },
          onError: (Object _, StackTrace _) {
            if (timedOut) _replayAfterLateCompletion(command);
          },
        ),
      );
      try {
        await raw.timeout(
          command.timeout,
          onTimeout: () {
            timedOut = true;
            throw TimeoutException(
              'Capture configuration timed out',
              command.timeout,
            );
          },
        );
      } on TimeoutException {
        if (_isCurrent(command)) rethrow;
      } catch (_) {
        if (_isCurrent(command)) rethrow;
      }
    });
    _tail = scheduled.catchError((Object _, StackTrace _) {}).whenComplete(() {
      _pending -= 1;
      if (_pending == 0 && _activeOwner == null) {
        final onIdle = _onIdle;
        _onIdle = null;
        onIdle?.call();
      }
    });
    return scheduled;
  }

  bool _isCurrent(_CaptureConfigurationCommand command) {
    return identical(_activeOwner, command.owner) &&
        identical(_desired, command) &&
        _revision == command.revision;
  }

  void _replayAfterLateCompletion(_CaptureConfigurationCommand stale) {
    final current = _desired;
    if (current == null || identical(current, stale) || !_isCurrent(current)) {
      return;
    }
    _desired = _CaptureConfigurationCommand(
      owner: current.owner,
      revision: ++_revision,
      timeout: current.timeout,
      operation: current.operation,
    );
    unawaited(_enqueue(_desired!).catchError((Object _, StackTrace _) {}));
  }

  void release(Object owner, {required void Function() onIdle}) {
    if (!identical(_activeOwner, owner)) return;
    _activeOwner = null;
    _desired = null;
    _revision += 1;
    if (_pending == 0) {
      onIdle();
    } else {
      _onIdle = onIdle;
    }
  }
}

final class _CaptureConfigurationCommand {
  const _CaptureConfigurationCommand({
    required this.owner,
    required this.revision,
    required this.timeout,
    required this.operation,
  });

  final Object owner;
  final int revision;
  final Duration timeout;
  final Future<void> Function() operation;
}

final class UnsupportedGameCapturePort implements GameCapturePort {
  const UnsupportedGameCapturePort();

  @override
  Stream<CapturedApiEvent> get events => const Stream<CapturedApiEvent>.empty();

  @override
  Future<void> configure({
    required bool enabled,
    required String script,
  }) async {}

  @override
  Future<bool> isSupported() async => false;

  @override
  void dispose() {}
}
