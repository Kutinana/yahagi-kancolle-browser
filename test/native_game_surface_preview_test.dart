import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/native_game_surface_preview.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'requests an in-memory WebView preview without saving to gallery',
    () async {
      const channel = MethodChannel('test/native-game-surface-preview');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      MethodCall? received;
      messenger.setMockMethodCallHandler(channel, (call) async {
        received = call;
        return Uint8List.fromList(<int>[137, 80, 78, 71]);
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      final bytes = await const MethodChannelNativeGameSurfacePreviewPort(
        channel,
      ).capturePreview();

      expect(received?.method, 'captureWebViewPreview');
      expect(bytes, <int>[137, 80, 78, 71]);
    },
  );

  test('rejects an empty native preview', () async {
    const channel = MethodChannel('test/empty-native-game-surface-preview');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => Uint8List.fromList(<int>[]),
    );
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    expect(
      const MethodChannelNativeGameSurfacePreviewPort(channel).capturePreview(),
      throwsStateError,
    );
  });
}
