import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/src/audio/game_audio_controller.dart';
import 'package:yahagi_kancolle_browser/src/audio/game_audio_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/display_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/display_mode_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/screen_settings_page.dart';

void main() {
  testWidgets('information panel switch and reset affect panel preferences', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final controller = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    await controller.setDashboardCardOrder(
      LayoutSettingsStore.defaultDashboardCardOrder.reversed.toList(),
    );
    await controller.toggleDashboardCardCollapsed('fleet');
    final display = await DisplayModeController.load(MemoryDisplayModeStore());
    await tester.pumpWidget(
      MaterialApp(
        home: ScreenSettingsPage(
          layoutSettingsController: controller,
          displayModeController: display,
        ),
      ),
    );
    final label = find.byKey(const Key('settings-information-panel-left'));
    await tester.ensureVisible(label);
    final row = find.ancestor(of: label, matching: find.byType(Row)).first;
    await tester.tap(find.descendant(of: row, matching: find.byType(Switch)));
    await tester.pump();
    expect(controller.informationPanelOnLeft, isTrue);
    expect(controller.workspaceMenuOnRight, isFalse);
    await tester.tap(
      find.byKey(const Key('settings-reset-dashboard-card-order')),
    );
    await tester.pump();
    expect(
      controller.dashboardCardOrder,
      LayoutSettingsStore.defaultDashboardCardOrder,
    );
    expect(controller.dashboardCardCollapsed, contains('fleet'));
    expect(controller.informationPanelOnLeft, isTrue);
    final reloaded = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    expect(
      reloaded.dashboardCardOrder,
      LayoutSettingsStore.defaultDashboardCardOrder,
    );
    expect(reloaded.informationPanelOnLeft, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('screen settings expose background audio playback switch', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final layoutController = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    final displayController = await DisplayModeController.load(
      MemoryDisplayModeStore(),
    );
    final audioController = await GameAudioController.load(
      SharedPreferencesGameAudioStore(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ScreenSettingsPage(
          layoutSettingsController: layoutController,
          displayModeController: displayController,
          audioController: audioController,
        ),
      ),
    );

    final label = find.byKey(const Key('settings-background-audio'));
    await tester.ensureVisible(label);
    expect(label, findsOneWidget);
    expect(find.text('开启后，应用进入后台时游戏声音仍会继续播放。'), findsOneWidget);
    expect(audioController.backgroundPlaybackEnabled, isFalse);

    final row = find.ancestor(of: label, matching: find.byType(Row)).first;
    await tester.tap(find.descendant(of: row, matching: find.byType(Switch)));
    await tester.pumpAndSettle();

    expect(audioController.backgroundPlaybackEnabled, isTrue);
  });

  testWidgets('workspace menu side switch moves preference to the right', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final layoutController = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    final displayController = await DisplayModeController.load(
      MemoryDisplayModeStore(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ScreenSettingsPage(
          layoutSettingsController: layoutController,
          displayModeController: displayController,
        ),
      ),
    );

    final label = find.byKey(const Key('settings-workspace-menu-right'));
    expect(label, findsOneWidget);
    expect(layoutController.workspaceMenuOnRight, isFalse);

    final row = find.ancestor(of: label, matching: find.byType(Row)).first;
    await tester.tap(find.descendant(of: row, matching: find.byType(Switch)));
    await tester.pump();

    expect(layoutController.workspaceMenuOnRight, isTrue);
  });

  testWidgets('damage pulse switch is consolidated into battle settings', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final layoutController = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    final displayController = await DisplayModeController.load(
      MemoryDisplayModeStore(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ScreenSettingsPage(
          layoutSettingsController: layoutController,
          displayModeController: displayController,
        ),
      ),
    );

    final label = find.byKey(const Key('settings-enhanced-damage-pulse'));
    expect(label, findsNothing);
  });

  testWidgets(
    'workspace menu reset button restores the current default order',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final layoutController = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      await layoutController.setWorkspaceMenuOrder(<String>[
        'settings',
        ...LayoutSettingsStore.defaultWorkspaceMenuOrder.where(
          (id) => id != 'settings',
        ),
      ]);
      final displayController = await DisplayModeController.load(
        MemoryDisplayModeStore(),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ScreenSettingsPage(
            layoutSettingsController: layoutController,
            displayModeController: displayController,
          ),
        ),
      );

      final reset = find.byKey(
        const Key('settings-reset-workspace-menu-order'),
      );
      expect(reset, findsOneWidget);
      final menuLabel = find.byKey(const Key('settings-workspace-menu-right'));
      final menuRow = find
          .ancestor(of: menuLabel, matching: find.byType(Row))
          .first;
      final menuSwitch = find.descendant(
        of: menuRow,
        matching: find.byType(Switch),
      );
      expect(find.descendant(of: menuRow, matching: reset), findsOneWidget);
      expect(menuSwitch, findsOneWidget);
      expect(
        tester.getCenter(reset).dy,
        closeTo(tester.getCenter(menuSwitch).dy, 0.1),
      );
      expect(
        tester.getCenter(reset).dx,
        lessThan(tester.getCenter(menuSwitch).dx),
      );
      await tester.tap(reset);
      await tester.pump();

      expect(
        layoutController.workspaceMenuOrder,
        LayoutSettingsStore.defaultWorkspaceMenuOrder,
      );
    },
  );
}
