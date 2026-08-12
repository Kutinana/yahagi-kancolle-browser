import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_store.dart';

void main() {
  test('battle damage vibration defaults on and persists changes', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    var controller = await SafetySettingsController.load(
      SharedPreferencesSafetySettingsStore(),
    );

    expect(controller.battleDamageVibrationEnabled, isTrue);

    await controller.setBattleDamageVibrationEnabled(false);
    controller = await SafetySettingsController.load(
      SharedPreferencesSafetySettingsStore(),
    );

    expect(controller.battleDamageVibrationEnabled, isFalse);
  });
}
