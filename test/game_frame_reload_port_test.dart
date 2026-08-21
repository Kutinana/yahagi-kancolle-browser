import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_browser_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_frame_reload_port.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('test/game_frame_reload');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('configures the native frame bridge', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });

    await MethodChannelGameFrameReloadPort(channel: channel).configure();

    expect(calls, hasLength(1));
    expect(calls.single.method, 'configure');
    expect(calls.single.arguments, isNull);
  });

  test('maps every supported wire result', () async {
    final responses = <String>[
      'reloaded',
      'game_frame_not_found',
      'html_wrap_not_found',
      'blocked',
      'unsupported',
    ];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => responses.removeAt(0),
        );
    final port = MethodChannelGameFrameReloadPort(channel: channel);

    expect(await port.reload(), GameFrameReloadResult.reloaded);
    expect(await port.reload(), GameFrameReloadResult.gameFrameNotFound);
    expect(await port.reload(), GameFrameReloadResult.htmlWrapNotFound);
    expect(await port.reload(), GameFrameReloadResult.blocked);
    expect(await port.reload(), GameFrameReloadResult.unsupported);
  });

  test('rejects an unknown wire result', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => 'unknown');

    expect(
      MethodChannelGameFrameReloadPort(channel: channel).reload(),
      throwsA(isA<StateError>()),
    );
  });
}
