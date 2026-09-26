import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';

void main() {
  test(
    'three-column insertion, return, reorder and spans never replace cards',
    () async {
      SharedPreferences.setMockInitialValues({});
      var c = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      expect(await c.moveHdModuleToBottom('construction'), isTrue);
      expect(c.hdSettings.activeModules, [
        'expedition',
        'repair',
        'construction',
      ]);
      expect(await c.moveHdModuleToBottom('fleet'), isFalse);
      expect(await c.setHdModuleSpan('expedition', 2), isFalse);
      await c.moveHdModuleToSidebar('repair', target: 'fleet');
      expect(c.hdSettings.activeModules, ['expedition', 'construction']);
      expect(await c.setHdModuleSpan('expedition', 2), isTrue);
      await c.moveHdModuleToBottom('construction', before: 'expedition');
      expect(c.hdSettings.activeModules, ['construction', 'expedition']);
      await c.moveHdModuleToSidebar('construction');
      expect(await c.setHdModuleSpan('expedition', 3), isTrue);
      expect(c.hdSettings.bottom.single.span, 3);
      await c.moveHdModuleToSidebar('expedition');
      expect(c.hdSettings.bottom, isEmpty);
      expect(await c.moveHdModuleToBottom('fleet'), isTrue);
      c = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      expect(c.hdSettings.activeModules, ['fleet']);
      expect(c.hdSettings.bottom.single.span, 1);
      expect(c.dashboardCardHidden, isEmpty);
      expect(
        c.dashboardCardOrder,
        LayoutSettingsStore.defaultDashboardCardOrder,
      );
    },
  );
}
