import 'fixtures/kcsapi_fixtures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_store.dart';
import 'package:yahagi_kancolle_browser/src/fleet/expedition_summary_card.dart';
import 'package:yahagi_kancolle_browser/src/quest/pinned_quests_summary.dart';
import 'package:yahagi_kancolle_browser/src/layout/hd_bottom_strip.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';

class _Store extends GameStateStore {
  @override
  void save(GameState state) {}
  @override
  Future<GameState> load() async => GameState.empty.copyWith(
    hasPortData: true,
    hasQuestData: true,
    activeQuestCount: 7,
    quests: {
      for (var i = 1; i <= 7; i++)
        i: GameQuest(
          id: i,
          title: '任务 $i',
          detail: '',
          category: 2,
          type: 1,
          state: 2,
          progressFlag: 0,
        ),
    },
    fleets: [
      for (var i = 1; i <= 3; i++)
        Fleet(
          id: i,
          name: '第$i舰队',
          mission: FleetMission(
            state: 1,
            missionId: i,
            completionTime: DateTime.now().add(const Duration(hours: 1)),
          ),
        ),
    ],
  );
}

void main() {
  for (final module in ['quests', 'expedition']) {
    testWidgets('HD $module uses span columns with equal last-row widths', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final state = GameStateController(gameStateStore: _Store());
      await state.initialize();
      state.accept(
        kcsapiEvent('/kcsapi/api_get_member/questlist', {
          'api_count': 7,
          'api_exec_count': 7,
          'api_page_count': 1,
          'api_disp_page': 1,
          'api_list': [
            for (var i = 1; i <= 7; i++)
              {
                'api_no': i,
                'api_title': '任务 $i',
                'api_detail': '',
                'api_category': 2,
                'api_type': 1,
                'api_state': 2,
                'api_progress_flag': 0,
              },
          ],
        }),
      );
      await state.idle;
      final layout = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      addTearDown(state.dispose);
      addTearDown(layout.dispose);
      await layout.setHdSplit(false);
      await layout.setHdModule('wide', module);
      var opened = 0;
      for (final width in [665.0, 780.0]) {
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SizedBox(
                width: width,
                height: 350,
                child: HdBottomStrip(
                  controller: layout,
                  moduleBuilder: (_) => SingleChildScrollView(
                    child: module == 'quests'
                        ? PinnedQuestsSummary(
                            controller: state,
                            collapsed: false,
                            onToggleCollapse: () {},
                            onOpenQuest: (id) => opened = id,
                          )
                        : ExpeditionSummaryCard(
                            controller: state,
                            collapsed: false,
                            onToggleCollapse: () {},
                            onOpenExpedition: () => opened = 1,
                            onOpenExpeditionCheck: (_) {},
                          ),
                  ),
                ),
              ),
            ),
          ),
        );
        for (final columns in [1, 2, 3, 2]) {
          await layout.setHdModuleSpan(module, columns);
          await tester.pumpAndSettle();
          final count = module == 'quests' ? 7 : 3;
          final items = [
            for (var i = 1; i <= count; i++)
              find.byKey(
                Key(
                  module == 'quests'
                      ? 'quest-summary-item-$i'
                      : 'expedition-summary-row-$i',
                ),
              ),
          ];
          final rects = items.map(tester.getRect).toList();
          for (var i = 0; i < count; i++) {
            expect(
              rects[i].top,
              closeTo(rects[i ~/ columns * columns].top, .1),
            );
            expect(rects[i].width, closeTo(rects.first.width, .1));
            if (i >= columns) {
              expect(rects[i].top, greaterThan(rects[i - columns].top));
            }
            if (i % columns > 0) {
              expect(rects[i].left, greaterThan(rects[i - 1].right));
            }
          }
          await tester.ensureVisible(items.last);
          await tester.pumpAndSettle();
          opened = 0;
          final tapItem = module == 'expedition'
              ? find
                    .ancestor(of: items.last, matching: find.byType(InkWell))
                    .first
              : find
                    .descendant(of: items.last, matching: find.byType(InkWell))
                    .first;
          await tester.tap(tapItem);
          expect(opened, module == 'quests' ? 7 : 1);
          expect(tester.takeException(), isNull);
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
