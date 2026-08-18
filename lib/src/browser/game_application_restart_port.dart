import 'package:flutter/services.dart';

abstract interface class GameApplicationRestartPort {
  Future<void> restartApplication();
}

final class MethodChannelGameApplicationRestartPort
    implements GameApplicationRestartPort {
  const MethodChannelGameApplicationRestartPort();

  static const _channel = MethodChannel(
    'app.yahagi.kancollebrowser/game_environment',
  );

  @override
  Future<void> restartApplication() =>
      _channel.invokeMethod<void>('restartActivity');
}
