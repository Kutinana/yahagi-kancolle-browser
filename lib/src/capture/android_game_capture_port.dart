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
  MethodChannelGameCapturePort({this.channel = _defaultGameCaptureChannel}) {
    _handlerOwners[channel.name] = _handlerOwner;
    channel.setMethodCallHandler(_onMethodCall);
  }

  static final Map<String, Object> _handlerOwners = <String, Object>{};

  final MethodChannel channel;
  final Object _handlerOwner = Object();
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
    unawaited(_events.close());
  }
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
