import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/senka/senka_calendar_view.dart';
import 'package:yahagi_kancolle_browser/src/senka/senka_controller.dart';
import 'package:yahagi_kancolle_browser/src/senka/senka_page.dart';
import 'package:yahagi_kancolle_browser/src/senka/senka_state.dart';
import 'package:yahagi_kancolle_browser/src/senka/senka_store.dart';
import 'package:yahagi_kancolle_browser/src/senka/senka_ui.dart';

void main() {
  late SenkaController controller;

  setUp(() async {
    controller = SenkaController(
      store: MemorySenkaStore(sampleState()),
      now: () => DateTime.utc(2026, 8, 10),
    );
    await controller.initialize();
  });
  tearDown(() => controller.dispose());

  for (final size in const [
    Size(1280, 680),
    Size(800, 1100),
    Size(720, 720),
    Size(844, 390),
    Size(390, 844),
  ]) {
    testWidgets('${size.width.toInt()}×${size.height.toInt()} 三页均无溢出', (
      tester,
    ) async {
      await pumpSenka(tester, controller, size);
      expect(find.byKey(const Key('senka-tab-info')), findsOneWidget);
      expect(find.byKey(const Key('senka-tab-calendar')), findsOneWidget);
      expect(find.byKey(const Key('senka-tab-calculator')), findsOneWidget);
      expect(find.text('服务器概况'), findsOneWidget);
      expect(find.text('2026年8月战果日历'), findsNothing);
      expect(find.text('目标战果'), findsNothing);
      expect(tester.takeException(), isNull);
      final horizontal =
          size == const Size(1280, 680) || size == const Size(844, 390);
      expect(
        find.byKey(Key('senka-info-${horizontal ? 'horizontal' : 'vertical'}')),
        findsOneWidget,
      );
      await tester.ensureVisible(find.byKey(const Key('senka-sortie-row-3-2')));

      await tester.tap(find.byKey(const Key('senka-tab-calendar')));
      await tester.pump();
      expect(find.text('2026年8月战果日历'), findsOneWidget);
      expect(find.text('服务器概况'), findsNothing);
      await tester.ensureVisible(find.byKey(const Key('senka-day-detail')));
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('senka-tab-calculator')));
      await tester.pump();
      expect(find.text('目标战果'), findsOneWidget);
      expect(find.text('2026年8月战果日历'), findsNothing);
      expect(
        find.byKey(
          Key('senka-calculator-${horizontal ? 'horizontal' : 'vertical'}'),
        ),
        findsOneWidget,
      );
      await tester.ensureVisible(
        find.byKey(const Key('senka-calculator-footer')),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('顶部三按钮等宽且选中态为金色', (tester) async {
    await pumpSenka(tester, controller, const Size(1280, 680));
    final rects = [
      for (final key in ['info', 'calendar', 'calculator'])
        tester.getRect(find.byKey(Key('senka-tab-$key'))),
    ];
    expect(rects[0].width, closeTo(rects[1].width, .01));
    expect(rects[1].width, closeTo(rects[2].width, .01));
    expect(rects.every((rect) => rect.height >= 40), isTrue);
    expect(tabColor(tester, 'info'), const Color(0xffd7a957));
    expect(tabColor(tester, 'calendar'), isNot(const Color(0xffd7a957)));
    await tester.tap(find.byKey(const Key('senka-tab-calendar')));
    await tester.pump();
    expect(tabColor(tester, 'calendar'), senkaGold);
    expect(tabColor(tester, 'info'), isNot(senkaGold));
    await tester.tap(find.byKey(const Key('senka-tab-calculator')));
    await tester.pump();
    expect(tabColor(tester, 'calculator'), senkaGold);
    expect(tabColor(tester, 'calendar'), isNot(senkaGold));
  });

  testWidgets('tabs 提供 button、selected 与可读标签语义', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpSenka(tester, controller, const Size(844, 390));
    final info = tester.getSemantics(find.bySemanticsLabel('战果信息'));
    expect(info.flagsCollection.isButton, isTrue);
    expect(info.flagsCollection.isSelected, Tristate.isTrue);
    await tester.tap(find.byKey(const Key('senka-tab-calendar')));
    await tester.pump();
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('战果信息'))
          .flagsCollection
          .isSelected,
      Tristate.isFalse,
    );
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('战果日历'))
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
    semantics.dispose();
  });

  testWidgets('信息页横屏左右等宽，方形与竖屏顺序滚动', (tester) async {
    await pumpSenka(tester, controller, const Size(1280, 680));
    final left = tester.getRect(find.byKey(const Key('senka-info-left')));
    final right = tester.getRect(find.byKey(const Key('senka-info-right')));
    expect(left.width, closeTo(right.width, 1));
    expect(left.left, lessThan(right.left));
    final server = tester.getRect(find.byKey(const Key('senka-info-server')));
    final ranking = tester.getRect(find.byKey(const Key('senka-info-ranking')));
    expect(server.height / (server.height + ranking.height), closeTo(.30, .02));

    await pumpSenka(tester, controller, const Size(720, 720));
    final verticalColumn = tester.widget<Column>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Column &&
            widget.children.any(
              (child) => child.key == const Key('senka-info-server'),
            ),
      ),
    );
    expect(
      verticalColumn.children
          .map((child) => child.key)
          .whereType<ValueKey<String>>(),
      const [
        Key('senka-info-server'),
        Key('senka-info-ranking'),
        Key('senka-info-sorties'),
      ],
    );
    await tester.ensureVisible(find.text('出击海域统计'));
    expect(find.text('出击海域统计'), findsOneWidget);
    expect(find.byType(Scrollable), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('服务器概况、排名与统计遵守文案和两位小数', (tester) async {
    await pumpSenka(tester, controller, const Size(1280, 680));
    expect(find.text('横須賀鎮守府（横须贺）'), findsOneWidget);
    expect(find.text('108.00'), findsWidgets);
    expect(find.text('3874'), findsWidgets);
    for (final label in ['海域', 'Boss', '出击', 'S', 'A', '操作']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('海域明细'), findsNothing);
    expect(find.textContaining('到达率'), findsNothing);
    expect(find.textContaining('撤退'), findsNothing);
  });

  testWidgets('统计数据行同字号同中线且操作按钮完整位于行内', (tester) async {
    await pumpSenka(tester, controller, const Size(1280, 680));
    final row = find.byKey(const Key('senka-sortie-row-1-1'));
    final texts = tester
        .widgetList<Text>(find.descendant(of: row, matching: find.byType(Text)))
        .toList();
    expect(texts.map((text) => text.style?.fontSize).toSet(), hasLength(1));
    final centers = [
      for (final text in texts) tester.getCenter(find.byWidget(text)).dy,
    ];
    expect(
      centers.every((center) => (center - centers.first).abs() <= 1),
      isTrue,
    );
    expect(texts[3].maxLines, 1);
    expect(texts[4].maxLines, 1);
    final rowRect = tester.getRect(row);
    for (final key in const ['senka-favorite-1-1', 'senka-hide-1-1']) {
      final rect = tester.getRect(find.byKey(Key(key)));
      expect(rect.width, greaterThanOrEqualTo(36));
      expect(rect.height, greaterThanOrEqualTo(36));
      expect(rect.left, greaterThanOrEqualTo(rowRect.left));
      expect(rect.top, greaterThanOrEqualTo(rowRect.top));
      expect(rect.right, lessThanOrEqualTo(rowRect.right));
      expect(rect.bottom, lessThanOrEqualTo(rowRect.bottom));
    }
  });

  testWidgets('统计操作提供 Tooltip、button 与 toggled 语义', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpSenka(tester, controller, const Size(1280, 680));
    final favorite = find.bySemanticsLabel('收藏海域 1-1');
    final hidden = find.bySemanticsLabel('隐藏海域 1-1');
    expect(tester.getSemantics(favorite).flagsCollection.isButton, isTrue);
    expect(
      tester.getSemantics(favorite).flagsCollection.isToggled,
      Tristate.isFalse,
    );
    expect(tester.getSemantics(hidden).flagsCollection.isButton, isTrue);
    expect(
      find.ancestor(
        of: find.byKey(const Key('senka-favorite-1-1')),
        matching: find.byType(Tooltip),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('senka-favorite-1-1')));
    await tester.pump();
    expect(
      tester.getSemantics(favorite).flagsCollection.isToggled,
      Tristate.isTrue,
    );
    semantics.dispose();
  });

  testWidgets('统计默认隐藏隐藏项，收藏实际置顶且关闭开关恢复已取消隐藏项', (tester) async {
    await pumpSenka(tester, controller, const Size(1280, 680));
    expect(find.text('2-1'), findsNothing);
    expect(
      tester.getTopLeft(find.byKey(const Key('senka-sortie-row-1-1'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const Key('senka-sortie-row-3-2'))).dy,
      ),
    );
    await tester.tap(find.byKey(const Key('senka-favorite-3-2')));
    await tester.pump();
    expect(
      tester.getTopLeft(find.byKey(const Key('senka-sortie-row-3-2'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const Key('senka-sortie-row-1-1'))).dy,
      ),
    );
    await tester.tap(find.byKey(const Key('senka-show-hidden')));
    await tester.pump();
    expect(find.text('2-1'), findsOneWidget);
    await tester.tap(find.byKey(const Key('senka-hide-2-1')));
    await tester.pump();
    expect(controller.state.hiddenSortieMapKeys, isNot(contains('2-1')));
    await tester.tap(find.byKey(const Key('senka-show-hidden')));
    await tester.pump();
    expect(find.text('2-1'), findsOneWidget);
  });

  testWidgets('排名保留固定线和当前行变化行为', (tester) async {
    await pumpSenka(tester, controller, const Size(1280, 680));
    for (final rank in [5, 20, 100, 501]) {
      expect(find.byKey(Key('ranking-row-$rank')), findsOneWidget);
    }
    expect(find.byKey(const Key('player-rank-subcolumns')), findsOneWidget);
    expect(find.text('↑42'), findsOneWidget);
    expect(find.byKey(const Key('player-senka-delta')), findsOneWidget);
  });

  testWidgets('日历保留六乘七、周一开始、日期选择和两位小数详情', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpSenka(tester, controller, const Size(1280, 680));
    await tester.tap(find.byKey(const Key('senka-tab-calendar')));
    await tester.pump();
    expect(find.byKey(const Key('calendar-weekday-row')), findsOneWidget);
    expect(find.text('一'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'calendar-cell-',
            ),
      ),
      findsNWidgets(42),
    );
    await tester.tap(find.byKey(const Key('calendar-cell-10')));
    await tester.pump();
    expect(find.text('+3.80'), findsOneWidget);
    expect(find.text('经验'), findsOneWidget);
    expect(find.text('EO'), findsOneWidget);
    expect(find.text('任务'), findsOneWidget);
    expect(find.textContaining('本月已记录 3.80'), findsOneWidget);
    final selectedDay = tester.getSemantics(
      find.bySemanticsLabel('2026年8月10日，战果3.80'),
    );
    expect(selectedDay.flagsCollection.isButton, isTrue);
    expect(selectedDay.flagsCollection.isSelected, Tristate.isTrue);
    semantics.dispose();
  });

  testWidgets('日历跨月时按 now 或新月首日重置选择与详情', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpCalendar(
      tester,
      sampleState(),
      DateTime(2026, 8, 10),
      const Size(800, 700),
    );
    await tester.tap(find.byKey(const Key('calendar-cell-15')));
    await tester.pump();
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('2026年8月15日，战果0.00'))
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
    final september = SenkaState.forMonth(
      '2026-09',
    ).copyWith(days: {'2026-09-08': const SenkaDayRecord(experience: 5.5)});
    await pumpCalendar(
      tester,
      september,
      DateTime(2026, 9, 8),
      const Size(800, 700),
    );
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('2026年9月8日，战果5.50'))
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
    expect(find.text('+5.50'), findsOneWidget);
    await pumpCalendar(
      tester,
      SenkaState.forMonth('2026-10'),
      DateTime(2026, 9, 30),
      const Size(800, 700),
    );
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('2026年10月1日，战果0.00'))
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
    semantics.dispose();
  });

  testWidgets('计算页横屏始终三七双栏，方形为概况后任务矩阵', (tester) async {
    for (final size in const [Size(1280, 680), Size(844, 390)]) {
      await pumpCalculator(tester, controller, size);
      final left = tester.getRect(
        find.byKey(const Key('senka-calculator-left')),
      );
      final right = tester.getRect(
        find.byKey(const Key('senka-calculator-right')),
      );
      expect(left.width / (left.width + right.width), closeTo(.30, .02));
      expect(left.left, lessThan(right.left));
      expect(tester.takeException(), isNull);
    }
    await pumpCalculator(tester, controller, const Size(720, 720));
    final overviewY = tester
        .getTopLeft(find.byKey(const Key('senka-calculator-left')))
        .dy;
    await tester.ensureVisible(find.text('年度战果任务'));
    expect(tester.getTopLeft(find.text('年度战果任务')).dy, greaterThan(overviewY));
    expect(tester.takeException(), isNull);
  });

  testWidgets('计算输入实时更新，无效值保留且负数归零', (tester) async {
    await pumpCalculator(tester, controller, const Size(1280, 680));
    await tester.enterText(
      find.byKey(const Key('senka-current-input')),
      '123.45',
    );
    await tester.pump();
    expect(controller.state.calculatorCurrentSenka, 123.45);
    await tester.enterText(find.byKey(const Key('senka-current-input')), 'abc');
    await tester.pump();
    expect(controller.state.calculatorCurrentSenka, 123.45);
    await tester.enterText(find.byKey(const Key('senka-target-input')), '-20');
    await tester.pump();
    expect(controller.state.targetSenka, 0);
    expect(textFieldValue(tester, const Key('senka-target-input')), '0.00');
  });

  testWidgets('计算输入同步外部状态且不打断等值尾随小数点', (tester) async {
    await pumpCalculator(tester, controller, const Size(1280, 680));
    await tester.enterText(find.byKey(const Key('senka-current-input')), '1.');
    await tester.pump();
    expect(textFieldValue(tester, const Key('senka-current-input')), '1.');
    controller.setCurrentSenka(222.2);
    controller.setTargetSenka(4567.8);
    await tester.pump();
    expect(textFieldValue(tester, const Key('senka-current-input')), '222.20');
    expect(textFieldValue(tester, const Key('senka-target-input')), '4567.80');
  });

  testWidgets('计算概况指标固定三乘二且文案两位小数', (tester) async {
    await pumpCalculator(tester, controller, const Size(1280, 680));
    expect(find.textContaining('EO·战果炮 CLEAR 后共计'), findsOneWidget);
    expect(find.textContaining('距离目标还差'), findsOneWidget);
    final expected = [
      ['已勾选 EO', '已勾选战果任务'],
      ['剩余日数', '素战果'],
      ['每日所需', '今日剩余'],
    ];
    for (var row = 0; row < expected.length; row++) {
      final first = tester.getRect(find.text(expected[row][0]));
      final second = tester.getRect(find.text(expected[row][1]));
      expect(first.top, closeTo(second.top, 1));
      if (row > 0) {
        expect(
          first.top,
          greaterThan(tester.getRect(find.text(expected[row - 1][0])).top),
        );
      }
    }
  });

  testWidgets('四组任务完整、胶囊三态和整宽中线可辨识', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpCalculator(tester, controller, const Size(1280, 680));
    for (final title in ['EO 战果奖励', '季度战果任务', '年度战果任务', '单次战果任务']) {
      expect(find.text(title), findsOneWidget);
    }
    expect(find.text('AL作戦'), findsOneWidget);
    expect(find.text('機動部隊決戦'), findsOneWidget);
    expect(find.text('火球炮'), findsOneWidget);
    final toggle = find.byKey(const Key('senka-toggle-quest-854'));
    expect(tester.getRect(toggle).height, greaterThanOrEqualTo(36));
    expect(rewardColor(tester, toggle), senkaYellow.withValues(alpha: .13));
    expect(rewardTooltip(tester, toggle), contains('计划放置'));
    expect(find.bySemanticsLabel(RegExp('前段作战，计划放置')), findsOneWidget);
    expect(
      tester
          .getSemantics(find.bySemanticsLabel(RegExp('前段作战，计划放置')))
          .flagsCollection
          .isToggled,
      Tristate.isFalse,
    );
    expect(
      find.descendant(of: toggle, matching: find.text('✕')),
      findsOneWidget,
    );
    await tester.tap(toggle);
    await tester.pump();
    expect(controller.state.questStatuses[854], SenkaRewardStatus.planned);
    expect(rewardColor(tester, toggle), senkaGreen.withValues(alpha: .13));
    expect(rewardTooltip(tester, toggle), contains('计划完成（计预计）'));
    expect(find.bySemanticsLabel(RegExp('前段作战，计划完成（计预计）')), findsOneWidget);
    expect(
      tester
          .getSemantics(find.bySemanticsLabel(RegExp('前段作战，计划完成（计预计）')))
          .flagsCollection
          .isToggled,
      Tristate.isTrue,
    );
    expect(
      find.descendant(of: toggle, matching: find.text('✓')),
      findsOneWidget,
    );
    await tester.tap(toggle);
    await tester.pump();
    expect(controller.state.questStatuses[854], SenkaRewardStatus.completed);
    expect(rewardColor(tester, toggle), senkaMuted.withValues(alpha: .13));
    expect(rewardTooltip(tester, toggle), contains('已完成'));
    expect(find.bySemanticsLabel(RegExp('前段作战，已完成')), findsOneWidget);
    expect(find.byKey(const Key('senka-strike-quest-854')), findsOneWidget);
    final chipRect = tester.getRect(toggle);
    final strikeRect = tester.getRect(
      find.byKey(const Key('senka-strike-quest-854')),
    );
    expect((chipRect.left - strikeRect.left).abs(), lessThanOrEqualTo(1));
    expect((chipRect.right - strikeRect.right).abs(), lessThanOrEqualTo(1));
    expect(find.descendant(of: toggle, matching: find.text('✓')), findsNothing);
    semantics.dispose();
  });

  testWidgets('当前战果不计入无计划奖励时的 footer 合计', (tester) async {
    await pumpCalculator(tester, controller, const Size(1280, 680));
    expect(find.text('计划 EO 战果奖励 +0.00'), findsOneWidget);
    expect(find.text('计划任务战果奖励 +0.00'), findsOneWidget);
    expect(find.text('合计：0.00 战果'), findsOneWidget);
  });

  testWidgets('概况与 footer 只汇总 planned 奖励金额并使用两位小数', (tester) async {
    final mixedController = SenkaController(
      store: MemorySenkaStore(
        sampleState().copyWith(
          eoStatuses: const {
            15: SenkaRewardStatus.planned,
            25: SenkaRewardStatus.completed,
            35: SenkaRewardStatus.deferred,
          },
          questStatuses: const {
            854: SenkaRewardStatus.planned,
            888: SenkaRewardStatus.completed,
            893: SenkaRewardStatus.deferred,
          },
        ),
      ),
      now: () => DateTime.utc(2026, 8, 10),
    );
    addTearDown(mixedController.dispose);
    await mixedController.initialize();
    await pumpCalculator(tester, mixedController, const Size(1280, 680));

    expect(
      find.descendant(
        of: find.byKey(const Key('senka-metric-planned-eo')),
        matching: find.text('+75.00'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('senka-metric-planned-quest')),
        matching: find.text('+350.00'),
      ),
      findsOneWidget,
    );
    expect(find.text('计划 EO 战果奖励 +75.00'), findsOneWidget);
    expect(find.text('计划任务战果奖励 +350.00'), findsOneWidget);
    expect(find.text('合计：425.00 战果'), findsOneWidget);
  });

  testWidgets('390×844 可连续拖动到信息末行与计算单次任务和 footer', (tester) async {
    await pumpSenka(tester, controller, const Size(390, 844));
    await dragUntilVisible(
      tester,
      find.byKey(const Key('senka-sortie-row-3-2')),
    );
    await tester.tap(find.byKey(const Key('senka-tab-calculator')));
    await tester.pump();
    await dragUntilVisible(tester, find.text('单次战果任务'));
    await dragUntilVisible(
      tester,
      find.byKey(const Key('senka-calculator-footer')),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('390×844 在 1.3 倍文字下三页无溢出且关键内容可滚动', (tester) async {
    await pumpSenka(tester, controller, const Size(390, 844), textScale: 1.3);
    await dragUntilVisible(tester, find.text('出击海域统计'));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('senka-tab-calendar')));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('senka-tab-calculator')));
    await tester.pump();
    await dragUntilVisible(
      tester,
      find.byKey(const Key('senka-calculator-footer')),
    );
    expect(tester.takeException(), isNull);
  });
}

Color? tabColor(WidgetTester tester, String name) =>
    tester.widget<Material>(find.byKey(Key('senka-tab-$name'))).color;

Color? rewardColor(WidgetTester tester, Finder toggle) =>
    tester.widget<Material>(toggle).color;

String rewardTooltip(WidgetTester tester, Finder toggle) => tester
    .widget<Tooltip>(find.ancestor(of: toggle, matching: find.byType(Tooltip)))
    .message!;

Future<void> pumpCalculator(
  WidgetTester tester,
  SenkaController controller,
  Size size,
) async {
  await pumpSenka(tester, controller, size);
  await tester.tap(find.byKey(const Key('senka-tab-calculator')));
  await tester.pump();
}

Future<void> pumpSenka(
  WidgetTester tester,
  SenkaController controller,
  Size size, {
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Row(
        children: [
          const SizedBox(width: 58),
          Expanded(
            child: SenkaPage(
              controller: controller,
              now: DateTime(2026, 8, 10),
            ),
          ),
        ],
      ),
    ),
  );
  await tester.pump();
}

Future<void> pumpCalendar(
  WidgetTester tester,
  SenkaState state,
  DateTime now,
  Size size,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: SenkaCalendarView(state: state, now: now, compact: false),
    ),
  );
  await tester.pump();
}

String textFieldValue(WidgetTester tester, Key key) =>
    tester.widget<TextField>(find.byKey(key)).controller!.text;

Future<void> dragUntilVisible(WidgetTester tester, Finder target) async {
  for (
    var attempt = 0;
    attempt < 6 && target.hitTestable().evaluate().isEmpty;
    attempt++
  ) {
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -350),
    );
    await tester.pump();
  }
  expect(target.hitTestable(), findsOneWidget);
}

SenkaState sampleState() => SenkaState.forMonth('2026-08').copyWith(
  serverOrigin: 'https://w01.kancolle-server.com',
  memberId: 123,
  nickname: '矢矧',
  calculatorCurrentSenka: 108,
  targetSenka: 3000,
  completedEoIds: {15, 25, 55},
  days: {'2026-08-10': const SenkaDayRecord(experience: 3.8)},
  sortieStats: const {
    '1-1': SenkaSortieStats(
      areaId: 1,
      mapNo: 1,
      sorties: 12,
      bossArrivals: 10,
      sWins: 8,
      aWins: 1,
    ),
    '2-1': SenkaSortieStats(
      areaId: 2,
      mapNo: 1,
      sorties: 5,
      bossArrivals: 4,
      sWins: 3,
      aWins: 1,
    ),
    '3-2': SenkaSortieStats(
      areaId: 3,
      mapNo: 2,
      sorties: 8,
      bossArrivals: 7,
      sWins: 6,
      aWins: 1,
    ),
  },
  hiddenSortieMapKeys: {'2-1'},
  rankingHistory: {
    '5': [snapshot(5, 4700), snapshot(5, 4755)],
    '20': [snapshot(20, 2200), snapshot(20, 2250)],
    '100': [snapshot(100, 1600), snapshot(100, 1610)],
    '501': [snapshot(501, 1100), snapshot(501, 1144)],
    'player': [snapshot(3916, 100), snapshot(3874, 108)],
  },
);

SenkaRankingSnapshot snapshot(int rank, double senka) => SenkaRankingSnapshot(
  rank: rank,
  senka: senka,
  capturedAt: DateTime.utc(2026, 8, 10, 6),
  localSenkaAtCapture: 0,
);

class MemorySenkaStore implements SenkaStore {
  MemorySenkaStore(this.state);
  SenkaState? state;
  @override
  Future<SenkaState?> load() async => state;
  @override
  Future<void> save(SenkaState state) async => this.state = state;
}
