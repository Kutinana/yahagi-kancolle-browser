import 'package:flutter/services.dart';

import '../audio/game_audio_controller.dart';
import '../audio/game_audio_port.dart';

/// iOS owns background suspension natively, even while Flutter is suspended.
/// Keep its user mute separate from the shared controller's lifecycle mute.
final class IOSGameAudioPort implements GameAudioPort {
  IOSGameAudioPort(this.controller);

  final GameAudioController controller;
  static const _channel = MethodChannel(
    'app.yahagi.kancollebrowser/game_audio',
  );

  @override
  Future<bool> isSupported() async =>
      await _channel.invokeMethod<bool>('isSupported') ?? false;

  @override
  Future<void> setMuted(bool muted) => _channel.invokeMethod<void>(
    'setMuted',
    <String, Object>{'muted': controller.requestedMuted},
  );
}
