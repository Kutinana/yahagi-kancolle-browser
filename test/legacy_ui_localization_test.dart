import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/expedition/expedition_models.dart';
import 'package:yahagi_kancolle_browser/src/expedition/expedition_strings.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/improvement/improvement_dataset.dart';
import 'package:yahagi_kancolle_browser/src/improvement/improvement_planner_controller.dart';
import 'package:yahagi_kancolle_browser/src/improvement/improvement_planner_view.dart';
import 'package:yahagi_kancolle_browser/src/logbook/logbook_filter_panel.dart';
import 'package:yahagi_kancolle_browser/src/localization/ui_text.dart';

void main() {
  for (final scenario in <(Locale, String, String, String, String)>[
    (const Locale('zh'), '周一', '搜索装备', '全部日期', '应用'),
    (
      const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      '週一',
      '搜尋裝備',
      '全部日期',
      '套用',
    ),
    (const Locale('ja'), '月曜', '装備を検索', 'すべての日付', '適用'),
  ]) {
    testWidgets('improvement search and filters use ${scenario.$1}', (
      tester,
    ) async {
      final controller = ImprovementPlannerController(
        dataset: const ImprovementDataset(
          version: ImprovementDatasetVersion(
            dataVersion: 'test',
            commitSha: '',
          ),
          entries: [],
        ),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(
          scenario.$1,
          ImprovementPlannerView(
            controller: controller,
            state: const GameState(),
          ),
        ),
      );
      expect(find.text(scenario.$2), findsOneWidget);
      await tester.tap(find.byKey(const Key('improvement-search-button')));
      await tester.pumpAndSettle();
      expect(find.text(scenario.$3), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('improvement-search-field')),
        '瑞雲',
      );
      expect(controller.query, '瑞雲');
      await tester.tap(find.byKey(const Key('improvement-search-close')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('improvement-filter-button')));
      await tester.pumpAndSettle();
      expect(find.text(uiTextForLocale(scenario.$1, '进化状态')), findsOneWidget);
      await tester.tap(
        find.byKey(const Key('improvement-filter-evolution-evolvable')),
      );
      await tester.pumpAndSettle();
      expect(controller.hasFilters, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'logbook translated filters retain stored values ${scenario.$1}',
      (tester) async {
        Map<String, String>? result;
        await tester.pumpWidget(
          _app(
            scenario.$1,
            Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showLogbookFilterPanel(
                    context: context,
                    anchor: const Rect.fromLTWH(300, 20, 30, 30),
                    title: '筛选出击记录',
                    fields: const [
                      LogbookFilterField(
                        keyName: 'date',
                        label: '日期',
                        options: ['全部日期', '最近 7 天'],
                      ),
                    ],
                    values: const {'date': '最近 7 天'},
                    defaults: const {'date': '全部日期'},
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(
          find.text(uiTextForLocale(scenario.$1, '筛选出击记录')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('logbook-filter-reset')));
        await tester.pumpAndSettle();
        expect(
          find.text(scenario.$3 == '搜索装备' ? '全部日期' : scenario.$4),
          findsWidgets,
        );
        await tester.tap(find.text(scenario.$5));
        await tester.pumpAndSettle();
        expect(result, const {'date': '全部日期'});
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('expedition traditional controls and shortage use the locale', (
    tester,
  ) async {
    const hant = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');
    late ExpeditionStrings strings;
    Widget content() => Builder(
      builder: (context) {
        strings = ExpeditionStrings.of(context);
        return Text(strings.compact);
      },
    );
    await tester.pumpWidget(_app(hant, content()));
    expect(strings.compact, '簡潔');
    expect(strings.detailed, '詳細');
    expect(strings.expeditionAreaName(1), '鎮守府海域');
    const shortage = ExpeditionConditionResult(
      kind: ExpeditionConditionKind.resupply,
      label: '舰队完成补给',
      actual: '缺少 2 艘',
      passed: false,
    );
    expect(strings.conditionActual(shortage), '缺少 2 艘');
    await tester.pumpWidget(_app(const Locale('ja'), content()));
    await tester.pumpAndSettle();
    expect(strings.conditionActual(shortage), '2隻不足');
    expect(uiTextForLocale(const Locale('ja'), '瑞雲改二(六三四空)'), '瑞雲改二(六三四空)');
  });
}

Widget _app(Locale locale, Widget child) => MaterialApp(
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: Scaffold(body: child),
);
