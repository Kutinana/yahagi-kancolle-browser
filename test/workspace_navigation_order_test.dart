import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/main.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';

void main() {
  testWidgets(
    'long press drag reorders workspace menu without changing route IDs',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final controller = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      var selectedPage = -1;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: WorkspaceNavigation(
              controller: controller,
              selectedIndex: 0,
              onRight: false,
              onSelected: (page) => selectedPage = page,
            ),
          ),
        ),
      );

      final game = find.byKey(const Key('workspace-nav-game'));
      final fleet = find.byKey(const Key('workspace-nav-fleet'));
      expect(tester.getTopLeft(game).dy, lessThan(tester.getTopLeft(fleet).dy));

      final gesture = await tester.startGesture(tester.getCenter(game));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
      await gesture.moveBy(const Offset(0, 120));
      await tester.pump(const Duration(milliseconds: 500));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(controller.workspaceMenuOrder.take(2), <String>['fleet', 'game']);
      expect(tester.getTopLeft(fleet).dy, lessThan(tester.getTopLeft(game).dy));
      expect(selectedPage, -1);
      final restored = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      expect(restored.workspaceMenuOrder.take(2), <String>['fleet', 'game']);

      await tester.tap(game);
      await tester.pump();
      expect(selectedPage, 0);
    },
  );
}
