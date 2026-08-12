import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/display_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/display_mode_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/screen_settings_page.dart';

void main() {
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
    final captureController = await CaptureModeController.load(
      _MemoryCaptureModeStore(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ScreenSettingsPage(
          layoutSettingsController: layoutController,
          displayModeController: displayController,
          captureModeController: captureController,
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

  testWidgets(
    'damage pulse enhancement switch defaults on and updates setting',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final layoutController = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      final displayController = await DisplayModeController.load(
        MemoryDisplayModeStore(),
      );
      final captureController = await CaptureModeController.load(
        _MemoryCaptureModeStore(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ScreenSettingsPage(
            layoutSettingsController: layoutController,
            displayModeController: displayController,
            captureModeController: captureController,
          ),
        ),
      );

      final label = find.byKey(const Key('settings-enhanced-damage-pulse'));
      expect(label, findsOneWidget);
      expect(layoutController.enhancedDamagePulse, isTrue);

      final row = find.ancestor(of: label, matching: find.byType(Row)).first;
      await tester.tap(find.descendant(of: row, matching: find.byType(Switch)));
      await tester.pump();

      expect(layoutController.enhancedDamagePulse, isFalse);
    },
  );

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
      final captureController = await CaptureModeController.load(
        _MemoryCaptureModeStore(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ScreenSettingsPage(
            layoutSettingsController: layoutController,
            displayModeController: displayController,
            captureModeController: captureController,
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

final class _MemoryCaptureModeStore implements CaptureModeStore {
  CaptureMode mode = CaptureMode.game;

  @override
  Future<CaptureMode?> read() async => mode;

  @override
  Future<void> write(CaptureMode mode) async {
    this.mode = mode;
  }
}
