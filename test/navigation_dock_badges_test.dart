import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/main.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';
import 'fixtures/kcsapi_fixtures.dart';

void main() {
  testWidgets(
    'construction accumulates while repair and expedition count active timers',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final game = GameStateController();
      final layout = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      addTearDown(game.dispose);
      addTearDown(layout.dispose);
      await game.initialize();
      var now = DateTime.utc(2026, 9, 11, 12);
      final finish = now.add(const Duration(seconds: 3)).millisecondsSinceEpoch;
      Future<void> docks(String type, List<Map<String, dynamic>> values) async {
        game.accept(kcsapiEvent('/kcsapi/api_get_member/$type', values));
        await game.idle;
        await tester.pump();
      }

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: WorkspaceNavigation(
              controller: layout,
              gameStateController: game,
              clock: () => now,
              selectedIndex: 0,
              onRight: false,
              onSelected: (_) {},
            ),
          ),
        ),
      );
      await docks('kdock', [
        {
          'api_id': 1,
          'api_state': 3,
          'api_created_ship_id': 1,
          'api_complete_time': 0,
        },
        {
          'api_id': 2,
          'api_state': 2,
          'api_created_ship_id': 2,
          'api_complete_time': finish,
        },
      ]);
      await docks('ndock', [
        {
          'api_id': 1,
          'api_state': 1,
          'api_ship_id': 1,
          'api_complete_time': finish,
        },
        {
          'api_id': 2,
          'api_state': 1,
          'api_ship_id': 2,
          'api_complete_time': finish + 60000,
        },
        {
          'api_id': 3,
          'api_state': -1,
          'api_ship_id': 0,
          'api_complete_time': 0,
        },
      ]);
      Finder badge(String key, String text) =>
          find.descendant(of: find.byKey(Key(key)), matching: find.text(text));
      expect(find.byKey(const Key('expedition-active-count')), findsNothing);
      await docks('deck', [
        {
          'api_id': 1,
          'api_mission': [0, 0, 0],
        },
        {
          'api_id': 2,
          'api_mission': [1, 5, finish],
        },
        {
          'api_id': 3,
          'api_mission': [1, 21, finish + 60000],
        },
        {
          'api_id': 4,
          'api_mission': [1, 37, now.millisecondsSinceEpoch],
        },
      ]);
      expect(badge('expedition-active-count', '②'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('workspace-nav-expedition')),
          matching: find.byKey(const Key('expedition-active-count')),
        ),
        findsOneWidget,
      );
      expect(badge('construction-completion-count', '①'), findsOneWidget);
      expect(badge('repair-active-count', '②'), findsOneWidget);
      now = now.add(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 3));
      expect(badge('construction-completion-count', '②'), findsOneWidget);
      expect(badge('repair-active-count', '①'), findsOneWidget);
      expect(badge('expedition-active-count', '①'), findsOneWidget);
      now = now.add(const Duration(hours: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(badge('construction-completion-count', '②'), findsOneWidget);
      expect(find.byKey(const Key('repair-active-count')), findsNothing);
      expect(find.byKey(const Key('expedition-active-count')), findsNothing);
      await docks('deck', [
        {
          'api_id': 2,
          'api_mission': [
            1,
            5,
            now.add(const Duration(hours: 1)).millisecondsSinceEpoch,
          ],
        },
      ]);
      expect(badge('expedition-active-count', '①'), findsOneWidget);
      await docks('deck', [
        {
          'api_id': 2,
          'api_mission': [0, 0, 0],
        },
      ]);
      expect(find.byKey(const Key('expedition-active-count')), findsNothing);
      await docks('kdock', [
        {
          'api_id': 1,
          'api_state': 0,
          'api_created_ship_id': 0,
          'api_complete_time': 0,
        },
        {
          'api_id': 2,
          'api_state': 3,
          'api_created_ship_id': 2,
          'api_complete_time': finish,
        },
      ]);
      expect(badge('construction-completion-count', '①'), findsOneWidget);
      await docks('kdock', []);
      expect(
        find.byKey(const Key('construction-completion-count')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
