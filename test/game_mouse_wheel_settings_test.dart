import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_mouse_wheel_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('wheel compatibility defaults off and persists both choices', () async {
    final settings = await GameMouseWheelSettingsController.load();
    addTearDown(settings.dispose);
    expect(settings.enabled, isFalse);
    await settings.setEnabled(true);
    final reloaded = await GameMouseWheelSettingsController.load();
    addTearDown(reloaded.dispose);
    expect(reloaded.enabled, isTrue);
    await reloaded.setEnabled(false);
    final disabled = await GameMouseWheelSettingsController.load();
    addTearDown(disabled.dispose);
    expect(disabled.enabled, isFalse);
  });
}
