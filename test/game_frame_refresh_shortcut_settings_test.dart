import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_frame_refresh_shortcut_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('frame refresh shortcuts default off and persist independently', () async {
    final settings = await GameFrameRefreshShortcutSettings.load();
    addTearDown(settings.dispose);
    expect(settings.skipHeaderConfirmation, isFalse);
    expect(settings.rightClickEnabled, isFalse);

    await settings.setSkipHeaderConfirmation(true);
    expect(settings.skipHeaderConfirmation, isTrue);
    expect(settings.rightClickEnabled, isFalse);

    await settings.setRightClickEnabled(true);
    final reloaded = await GameFrameRefreshShortcutSettings.load();
    addTearDown(reloaded.dispose);
    expect(reloaded.skipHeaderConfirmation, isTrue);
    expect(reloaded.rightClickEnabled, isTrue);
  });

  test('uses the Android-compatible preference names', () async {
    final settings = await GameFrameRefreshShortcutSettings.load();
    addTearDown(settings.dispose);
    await settings.setSkipHeaderConfirmation(true);
    await settings.setRightClickEnabled(true);
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getBool('game.frameRefreshSkipConfirmation'),
      isTrue,
    );
    expect(preferences.getBool('game.mouseRightClickFrameRefresh'), isTrue);
  });
}
