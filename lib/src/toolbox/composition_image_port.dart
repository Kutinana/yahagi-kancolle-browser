import 'package:flutter/services.dart';

abstract interface class CompositionImagePort {
  Future<String> savePng(Uint8List bytes);
}

final class MethodChannelCompositionImagePort implements CompositionImagePort {
  const MethodChannelCompositionImagePort([
    this.channel = const MethodChannel(
      'app.yahagi.kancollebrowser/composition_image',
    ),
  ]);

  final MethodChannel channel;

  @override
  Future<String> savePng(Uint8List bytes) async {
    final location = await channel.invokeMethod<String>('savePng', {
      'bytes': bytes,
    });
    if (location == null || location.trim().isEmpty) {
      throw PlatformException(
        code: 'composition_save_failed',
        message: 'The saved composition image location was empty.',
      );
    }
    return location;
  }
}
