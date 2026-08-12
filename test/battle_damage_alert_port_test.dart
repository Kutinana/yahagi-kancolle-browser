import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_damage_alert.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('method channel sends the selected damage severity', () async {
    const channel = MethodChannel('test/battle_damage_alert');
    MethodCall? received;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          received = call;
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    await const MethodChannelBattleDamageAlertPort(
      channel,
    ).alert(BattleDamageAlertSeverity.heavy);

    expect(received?.method, 'alert');
    expect(received?.arguments, <String, Object?>{'severity': 'heavy'});
  });
}
