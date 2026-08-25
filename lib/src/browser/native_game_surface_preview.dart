import 'dart:typed_data';

import 'package:flutter/services.dart';

abstract interface class NativeGameSurfacePreviewPort {
  Future<Uint8List> capturePreview();
}

final class MethodChannelNativeGameSurfacePreviewPort
    implements NativeGameSurfacePreviewPort {
  const MethodChannelNativeGameSurfacePreviewPort([
    this.channel = const MethodChannel(
      'app.yahagi.kancollebrowser/game_screenshot',
    ),
  ]);

  final MethodChannel channel;

  @override
  Future<Uint8List> capturePreview() async {
    final bytes = await channel.invokeMethod<Uint8List>(
      'captureWebViewPreview',
    );
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Android returned an empty game surface preview');
    }
    return bytes;
  }
}
