import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_controller.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_detail_strings.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_models.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_pills.dart';
import 'package:yahagi_kancolle_browser/src/battle/land_base_raid_panel.dart';
import 'package:yahagi_kancolle_browser/src/battle/live_battle_card.dart';
import 'package:yahagi_kancolle_browser/src/battle/prediction/battle_prediction_engine.dart';
import 'package:yahagi_kancolle_browser/src/battle/prediction/battle_prediction_executor.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_reducer.dart';

import 'fixtures/kcsapi_fixtures.dart';

void main() {
  for (final locale in [
    const Locale('ja'),
    const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  ]) {
    final strings = BattleDetailStrings.forLocale(locale);
    testWidgets(
      'battle header, formation and raid use ${locale.toLanguageTag()}',
      (tester) async {
        await tester.pumpWidget(
          _app(
            locale,
            Column(
              children: [
                const AdaptiveBattleHeader(
                  nodeLabel: '节点 12',
                  enemyName: '敌方舰队',
                  enemyStyle: TextStyle(),
                ),
                MetaChip(label: formationLabel(1), color: Colors.white),
                MetaChip(label: engagementLabel(2), color: Colors.white),
                const NodeTypePill(label: '空袭战'),
                const LandBaseRaidPanel(
                  result: LandBaseRaidResult(
                    areaId: 1,
                    airSuperiority: '丧失',
                    bases: [],
                  ),
                ),
              ],
            ),
          ),
        );
        await tester.pump();
        expect(find.text(strings.localize('节点 12')), findsOneWidget);
        expect(find.text(strings.localize('敌方舰队')), findsOneWidget);
        expect(find.text(strings.localize('单纵阵')), findsOneWidget);
        expect(find.text(strings.localize('反航战')), findsOneWidget);
        expect(find.text(strings.localize('空袭战')), findsOneWidget);
        expect(find.text(strings.localize('基地空袭')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    for (final compact in [false, true]) {
      testWidgets(
        'live battle ${locale.toLanguageTag()} compact=$compact has no simplified UI residue',
        (tester) async {
          final reducer = GameStateReducer();
          var state = reducer.reduce(GameState.empty, start2Event);
          state = reducer.reduce(state, portEvent);
          final controller = BattleController(
            gameState: () => state,
            predictionExecutor: const _InlinePredictionExecutor(),
          );
          addTearDown(controller.dispose);
          controller.accept(mapStartEvent);
          await controller.idle;
          controller.accept(dayBattleEvent);
          await controller.idle;
          await tester.binding.setSurfaceSize(const Size(1000, 900));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(
            _app(
              locale,
              LiveBattleCard(
                controller: controller,
                collapsed: false,
                onToggleCollapse: () {},
                showEnemyPortraits: false,
              ),
            ),
          );
          await tester.pump();
          if (compact) {
            await tester.tap(find.byKey(const Key('battle-mode-compact')));
            await tester.pump();
          }
          final visible = tester
              .widgetList<Text>(find.byType(Text))
              .map((text) => text.data ?? text.textSpan?.toPlainText() ?? '')
              .join('\n');
          for (final source in [
            '我方舰队',
            '敌方舰队',
            '我方随伴',
            '敌方护卫',
            '单纵阵',
            '昼战',
            '预判',
            '空母机动部队',
          ]) {
            expect(visible, isNot(contains(source)), reason: source);
          }
          expect(visible, contains(strings.localize('单纵阵')));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

Widget _app(Locale locale, Widget child) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

final class _InlinePredictionExecutor implements BattlePredictionExecutor {
  const _InlinePredictionExecutor();

  @override
  Future<BattlePredictionAppendResult> append({
    required BattlePredictionEngine engine,
    required String path,
    required Map<String, Object?> data,
  }) async =>
      (engine: engine, prediction: engine.append(path: path, data: data));
}
