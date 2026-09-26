import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/main.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/workspace_menu_settings.dart';
import 'fixtures/kcsapi_fixtures.dart';

void main() {
  testWidgets(
    'workspace navigation height is 41 and bottom-to-icon distance matches top-to-badge distance',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final game = GameStateController();
      final layout = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      addTearDown(game.dispose);
      addTearDown(layout.dispose);
      await game.initialize();
      final now = DateTime.utc(2026, 9, 11, 12);
      await layout.setWorkspaceMenuPosition('bottom');
      await layout.setWorkspaceMenuSize(WorkspaceMenuSize.compact);

      game.accept(
        kcsapiEvent('/kcsapi/api_get_member/kdock', [
          {
            'api_id': 1,
            'api_state': 3,
            'api_created_ship_id': 1,
            'api_complete_time': 0,
          },
        ]),
      );
      await game.idle;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: ListenableBuilder(
                listenable: layout,
                builder: (context, _) => WorkspaceNavigation(
                  controller: layout,
                  gameStateController: game,
                  clock: () => now,
                  selectedIndex: 0,
                  onRight: false,
                  onSelected: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final navRect = tester.getRect(find.byType(WorkspaceNavigation));
      final constBtnRect = tester.getRect(
        find.descendant(
          of: find.byKey(const Key('workspace-nav-construction')),
          matching: find.byType(IconButton),
        ),
      );
      final constIconRect = tester.getRect(
        find.descendant(
          of: find.byKey(const Key('workspace-nav-construction')),
          matching: find.byType(Icon),
        ),
      );
      final badgeRect = tester.getRect(
        find.descendant(
          of: find.byKey(const Key('workspace-nav-construction')),
          matching: find.byType(Text),
        ),
      );

      expect(navRect.height, 41.0);
      final topToBadge = badgeRect.top - navRect.top;
      final bottomToIcon = navRect.bottom - constIconRect.bottom;
      expect(topToBadge, 7.0);
      expect(bottomToIcon, 7.0);
      expect(bottomToIcon, topToBadge);

      final topToBtn = constBtnRect.top - navRect.top;
      final bottomToBtn = navRect.bottom - constBtnRect.bottom;
      expect(topToBtn, 3.0);
      expect(bottomToBtn, 3.0);

      // Verify vertical mode
      await layout.setWorkspaceMenuPosition('left');
      await tester.pumpAndSettle();

      final verticalNavRect = tester.getRect(find.byType(WorkspaceNavigation));
      expect(verticalNavRect.width, 41.0);

      // Verify normal mode (48px)
      await layout.setWorkspaceMenuSize(WorkspaceMenuSize.normal);
      await tester.pumpAndSettle();

      final normalVerticalNavRect = tester.getRect(
        find.byType(WorkspaceNavigation),
      );
      expect(normalVerticalNavRect.width, 48.0);

      await layout.setWorkspaceMenuPosition('bottom');
      await tester.pumpAndSettle();

      final normalNavRect = tester.getRect(find.byType(WorkspaceNavigation));
      expect(normalNavRect.height, 48.0);

      final normalConstBtnRect = tester.getRect(
        find.descendant(
          of: find.byKey(const Key('workspace-nav-construction')),
          matching: find.byType(IconButton),
        ),
      );
      expect(normalConstBtnRect.top - normalNavRect.top, 4.0);
      expect(normalNavRect.bottom - normalConstBtnRect.bottom, 4.0);
      expect(tester.takeException(), isNull);
    },
  );
}
