import 'package:flutter/services.dart';

import 'game_browser_controller.dart';

const String gameFrameReloadMethodChannelName =
    'app.yahagi.kancollebrowser/game_frame_reload';

abstract interface class GameFrameReloadPort {
  Future<void> configure();

  Future<GameFrameReloadResult> reload();
}

final class MethodChannelGameFrameReloadPort implements GameFrameReloadPort {
  MethodChannelGameFrameReloadPort({MethodChannel? channel})
    : _channel =
          channel ?? const MethodChannel(gameFrameReloadMethodChannelName);

  final MethodChannel _channel;

  @override
  Future<void> configure() => _channel.invokeMethod<void>('configure');

  @override
  Future<GameFrameReloadResult> reload() async {
    final result = await _channel.invokeMethod<String>('reload');
    return switch (result) {
      'reloaded' => GameFrameReloadResult.reloaded,
      'game_frame_not_found' => GameFrameReloadResult.gameFrameNotFound,
      'html_wrap_not_found' => GameFrameReloadResult.htmlWrapNotFound,
      'blocked' => GameFrameReloadResult.blocked,
      'unsupported' => GameFrameReloadResult.unsupported,
      _ => throw StateError('Invalid game frame reload result: $result'),
    };
  }
}
