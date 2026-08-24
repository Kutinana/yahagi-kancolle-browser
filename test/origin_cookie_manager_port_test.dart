import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_launch_config.dart';
import 'package:yahagi_kancolle_browser/src/browser/origin_cookie_manager_port.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(originCookieManagerMethodChannelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('sends the exact OOI origin through the platform channel', () async {
    MethodCall? recordedCall;
    messenger.setMockMethodCallHandler(channel, (call) async {
      recordedCall = call;
      return null;
    });

    const port = MethodChannelOriginCookieManagerPort();
    await port.clearCookiesForOrigin(GameLaunchConfig.ooiOrigin);

    expect(recordedCall?.method, 'clearCookiesForOrigin');
    expect(recordedCall?.arguments, <String, Object?>{
      'origin': 'https://ooi.moe',
    });
  });

  test('rejects any other origin before invoking the platform', () {
    var invocationCount = 0;
    messenger.setMockMethodCallHandler(channel, (_) async {
      invocationCount += 1;
      return null;
    });

    const port = MethodChannelOriginCookieManagerPort();
    expect(
      () => port.clearCookiesForOrigin(Uri.parse('https://sub.ooi.moe')),
      throwsArgumentError,
    );

    expect(invocationCount, 0);
  });
}
