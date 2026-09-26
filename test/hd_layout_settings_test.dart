import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/hd_layout_settings.dart';
import 'package:yahagi_kancolle_browser/src/layout/hd_workspace_geometry.dart';
import 'package:flutter/widgets.dart';

void main() {
  test(
    'extension defaults below and preserves position across HD toggles and storage',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = SharedPreferencesLayoutSettingsStore();
      final c = await LayoutSettingsController.load(store);
      addTearDown(c.dispose);
      expect(c.hdSettings.extensionAboveGame, isFalse);
      expect(
        HdLayoutSettings.decode('{"enabled":true}').extensionAboveGame,
        isFalse,
      );
      await c.setHdExtensionPosition('top');
      await c.setHdEnabled(true);
      await c.setHdEnabled(false);
      final restored = await LayoutSettingsController.load(store);
      addTearDown(restored.dispose);
      expect(restored.hdSettings.extensionAboveGame, isTrue);
      await restored.setHdExtensionPosition('invalid');
      expect(restored.hdSettings.extensionAboveGame, isTrue);
    },
  );
  test(
    'home drag inserts modules, reorders sidebar and saves separately',
    () async {
      SharedPreferences.setMockInitialValues({});
      var controller = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      final ordinaryOrder = controller.dashboardCardOrder.toList();
      await controller.moveHdModuleToSlot('fleet', 'left');
      expect(controller.hdSettings.activeModules, [
        'fleet',
        'expedition',
        'repair',
      ]);
      await controller.moveHdModuleToBottom(
        'fleet',
        before: 'expedition',
        after: true,
      );
      expect(controller.hdSettings.activeModules, [
        'expedition',
        'fleet',
        'repair',
      ]);
      await controller.moveHdModuleBefore('fleet', 'battle');
      expect(controller.hdSettings.activeModules, ['expedition', 'repair']);
      expect(controller.hdSettings.orderedModules.first, 'fleet');
      await controller.moveHdModuleBefore('quests', 'fleet');
      expect(controller.hdSettings.orderedModules.first, 'quests');
      await controller.toggleHdModuleHidden('construction');
      await controller.moveHdModuleToSidebar('expedition');
      await controller.resizeHdModule('repair', fullWidth: true);
      expect(controller.hdSettings.activeModules, ['repair']);
      await controller.resizeHdModule('repair', fullWidth: false);
      expect(controller.hdSettings.activeModules.toSet().length, 1);
      controller = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      expect(controller.hdSettings.orderedModules.first, 'quests');
      expect(controller.hdSettings.hidden, contains('construction'));
      expect(controller.dashboardCardOrder, ordinaryOrder);
      expect(controller.dashboardCardHidden, isEmpty);
      await controller.resetHdLayout();
      expect(controller.hdSettings.activeModules, isEmpty);
      expect(
        controller.hdSettings.orderedModules,
        LayoutSettingsStore.defaultDashboardCardOrder,
      );
      expect(controller.hdSettings.hidden, isEmpty);
      final restored = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      expect(restored.hdSettings.activeModules, isEmpty);
      expect(
        restored.hdSettings.orderedModules,
        LayoutSettingsStore.defaultDashboardCardOrder,
      );
      expect(restored.dashboardCardOrder, ordinaryOrder);
      restored.dispose();
    },
  );
  test('invalid saved settings recover safe defaults', () {
    for (final raw in ['{', '[]', 'null']) {
      expect(HdLayoutSettings.decode(raw).enabled, isFalse);
    }
    final recovered = HdLayoutSettings.decode(
      '{"enabled":true,"left":"missing","right":12}',
    );
    expect(recovered.activeModules, ['expedition', 'repair']);
    expect(recovered.enabled, isTrue);
  });

  test(
    'HD explicitly enables landscape on all device sizes and reserves the bottom row on wide windows',
    () {
      expect(usesHdLandscape(const Size(1024, 768), enabled: true), isTrue);
      expect(usesHdLandscape(const Size(1280, 800), enabled: false), isFalse);
      expect(usesHdLandscape(const Size(800, 1280), enabled: true), isFalse);
      expect(usesHdLandscape(const Size(915, 412), enabled: true), isTrue);
      for (final size in [
        const Size(1222, 756),
        const Size(966, 724),
        const Size(1862, 556),
        const Size(867, 368),
        const Size(592, 276),
      ]) {
        final geometry = HdWorkspaceGeometry.forSize(size);
        expect(geometry.gameWidth / geometry.gameHeight, closeTo(5 / 3, .001));
        expect(geometry.bottomHeight, greaterThanOrEqualTo(119.99));
        expect(
          geometry.gameWidth + geometry.panelWidth + 1,
          closeTo(size.width, .001),
        );
      }
    },
  );
  test(
    'HD defaults off and persists without changing ordinary layout',
    () async {
      SharedPreferences.setMockInitialValues({});
      var controller = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      expect(controller.hdSettings.enabled, isFalse);
      await controller.setAutoZoom(false);
      await controller.setGameAreaRatio(.72);
      await controller.toggleDashboardCardCollapsed('expedition');
      await controller.toggleDashboardCardHidden('repair');
      await controller.setHdEnabled(true);
      await controller.setHdSplit(false);
      await controller.setHdModule('wide', 'quests');
      controller = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      expect(controller.hdSettings.enabled, isTrue);
      expect(controller.hdSettings.split, isFalse);
      expect(controller.hdSettings.wideModule, 'quests');
      await controller.setHdEnabled(false);
      expect(controller.gameAreaRatio, .72);
      expect(controller.autoZoom, isFalse);
      expect(controller.dashboardCardCollapsed, contains('expedition'));
      expect(controller.dashboardCardHidden, contains('repair'));
      controller = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      expect(controller.hdSettings.enabled, isFalse);
      expect(controller.hdSettings.wideModule, 'quests');
    },
  );
}
