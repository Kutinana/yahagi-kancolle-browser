import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/composition_image_port.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/composition_image');
  const defaultChannel = MethodChannel(
    'app.yahagi.kancollebrowser/composition_image',
  );
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(defaultChannel, null);
  });

  test('sends the PNG bytes and returns the native saved location', () async {
    final bytes = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
    MethodCall? received;
    messenger.setMockMethodCallHandler(channel, (call) async {
      received = call;
      return 'Pictures/Yahagi/Compositions/Yahagi-composition-test.png';
    });

    final location = await const MethodChannelCompositionImagePort(
      channel,
    ).savePng(bytes);

    expect(received!.method, 'savePng');
    expect((received!.arguments as Map)['bytes'], bytes);
    expect(location, endsWith('Yahagi-composition-test.png'));
  });

  test('the default port uses the composition image channel', () async {
    messenger.setMockMethodCallHandler(
      defaultChannel,
      (_) async => 'saved.png',
    );

    expect(
      await const MethodChannelCompositionImagePort().savePng(Uint8List(1)),
      'saved.png',
    );
  });

  test('propagates native failures including permission denial', () async {
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'storage_permission_denied');
    });

    await expectLater(
      const MethodChannelCompositionImagePort(channel).savePng(Uint8List(1)),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'storage_permission_denied',
        ),
      ),
    );
  });

  for (final invalidLocation in <String?>[null, '', '   ']) {
    test('rejects an empty saved location: $invalidLocation', () async {
      messenger.setMockMethodCallHandler(channel, (_) async => invalidLocation);

      await expectLater(
        const MethodChannelCompositionImagePort(channel).savePng(Uint8List(1)),
        throwsA(
          isA<PlatformException>().having(
            (error) => error.code,
            'code',
            'composition_save_failed',
          ),
        ),
      );
    });
  }
}
