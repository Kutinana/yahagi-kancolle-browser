import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/senka/senka_controller.dart';
import 'package:yahagi_kancolle_browser/src/senka/senka_page.dart';
import 'package:yahagi_kancolle_browser/src/senka/senka_state.dart';
import 'package:yahagi_kancolle_browser/src/senka/senka_store.dart';

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
    Size(1024, 600),
    Size(800, 1100),
    Size(844, 390),
    Size(740, 360),
  ]) {
    testWidgets('${size.width.toInt()}×${size.height.toInt()} 无溢出且信息完整', (
      tester,
    ) async {
      await pumpSenka(tester, controller, size);

      expect(find.text('战果信息'), findsOneWidget);
      expect(find.text('EO 与战果任务'), findsOneWidget);
      expect(find.text('2026年8月战果日历'), findsOneWidget);
      expect(find.byType(Scrollable), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>).value.startsWith('senka-cell-'),
        ),
        findsNWidgets(16),
      );
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
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(
          Key(
            size.width < size.height
                ? 'senka-portrait-layout'
                : 'senka-landscape-layout',
          ),
        ),
        findsOneWidget,
      );
    });
  }

  testWidgets('当前行四个数值字号一致且顺位变化使用独立子列', (tester) async {
    await pumpSenka(tester, controller, const Size(1024, 600));

    final texts = [
      tester.widget<Text>(find.byKey(const Key('player-rank'))),
      tester.widget<Text>(find.byKey(const Key('player-rank-delta'))),
      tester.widget<Text>(find.byKey(const Key('player-senka'))),
      tester.widget<Text>(find.byKey(const Key('player-senka-delta'))),
    ];
    expect(texts.map((text) => text.style?.fontSize).toSet(), hasLength(1));
    expect(find.byKey(const Key('player-rank-subcolumns')), findsOneWidget);
  });

  testWidgets('当前顺位不变时显示上升箭头而不是右箭头', (tester) async {
    final state = sampleState();
    final sameRankController = SenkaController(
      store: MemorySenkaStore(
        state.copyWith(
          rankingHistory: {
            ...state.rankingHistory,
            'player': [snapshot(3832, 100), snapshot(3832, 108)],
          },
        ),
      ),
      now: () => DateTime.utc(2026, 8, 10),
    );
    addTearDown(sameRankController.dispose);
    await sameRankController.initialize();
    await pumpSenka(tester, sameRankController, const Size(1024, 600));

    expect(find.text('↑0'), findsOneWidget);
    expect(find.text('→0'), findsNothing);
  });

  testWidgets('固定顺位线战果变化按正负映射颜色', (tester) async {
    final state = sampleState();
    final deltaController = SenkaController(
      store: MemorySenkaStore(
        state.copyWith(
          rankingHistory: {
            ...state.rankingHistory,
            '5': [snapshot(5, 100), snapshot(5, 125)],
            '20': [snapshot(20, 100), snapshot(20, 80)],
            '100': [snapshot(100, 100), snapshot(100, 100)],
            '501': [snapshot(501, 100)],
          },
        ),
      ),
      now: () => DateTime.utc(2026, 8, 10),
    );
    addTearDown(deltaController.dispose);
    await deltaController.initialize();
    await pumpSenka(tester, deltaController, const Size(1024, 600));

    Color? deltaColor(int rank) => tester
        .widget<Text>(find.byKey(Key('ranking-delta-$rank')))
        .style
        ?.color;

    expect(deltaColor(5), const Color(0xff5dc9a5));
    expect(deltaColor(20), const Color(0xffec7777));
    expect(deltaColor(100), const Color(0xffe7eef2));
    expect(deltaColor(501), const Color(0xffe7eef2));
  });

  testWidgets('竖屏按战果信息、EO 任务、战果日历单列排列', (tester) async {
    await pumpSenka(tester, controller, const Size(800, 1100));

    final rankingY = tester.getTopLeft(find.text('战果信息')).dy;
    final matrixY = tester.getTopLeft(find.text('EO 与战果任务')).dy;
    final calendarY = tester.getTopLeft(find.text('2026年8月战果日历')).dy;
    expect(rankingY, lessThan(matrixY));
    expect(matrixY, lessThan(calendarY));
    expect(find.byKey(const Key('senka-portrait-layout')), findsOneWidget);
  });

  testWidgets('横向近方形折叠屏也使用单列 1×3 布局', (tester) async {
    await pumpSenka(tester, controller, const Size(841, 673));

    expect(find.byKey(const Key('senka-portrait-layout')), findsOneWidget);
    expect(find.byKey(const Key('senka-landscape-layout')), findsNothing);
    final rankingY = tester.getTopLeft(find.text('战果信息')).dy;
    final matrixY = tester.getTopLeft(find.text('EO 与战果任务')).dy;
    final calendarY = tester.getTopLeft(find.text('2026年8月战果日历')).dy;
    expect(rankingY, lessThan(matrixY));
    expect(matrixY, lessThan(calendarY));
    expect(tester.takeException(), isNull);
  });

  testWidgets('战果标题与顺位列全部共用同一条左对齐线', (tester) async {
    await pumpSenka(tester, controller, const Size(1024, 600));

    final expectedLeft = tester.getTopLeft(find.text('战果信息')).dx;
    for (final finder in [
      find.text('顺位'),
      find.text('501'),
      find.text('当前'),
      find.byKey(const Key('player-rank')),
    ]) {
      expect(tester.getTopLeft(finder).dx, closeTo(expectedLeft, 0.1));
    }
  });

  testWidgets('排名表头与排名行等高，星期表头与日期行等高', (tester) async {
    await pumpSenka(tester, controller, const Size(1024, 600));

    expect(
      tester.getSize(find.byKey(const Key('ranking-header-row'))).height,
      tester.getSize(find.byKey(const Key('ranking-row-5'))).height,
    );
    expect(
      tester.getSize(find.byKey(const Key('calendar-weekday-row'))).height,
      tester.getSize(find.byKey(const Key('calendar-week-row-0'))).height,
    );
  });

  testWidgets('日历中每日战果数字统一使用黄色', (tester) async {
    await pumpSenka(tester, controller, const Size(1024, 600));

    final calendarTexts = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byKey(const Key('calendar-cell-14')),
            matching: find.byType(Text),
          ),
        )
        .toList();
    expect(calendarTexts[1].style?.color, const Color(0xffd7a957));
  });

  testWidgets('月度战果与当日战果底栏整行加粗', (tester) async {
    await pumpSenka(tester, controller, const Size(1024, 600));

    for (final label in ['已选择战果奖励', '经验', 'EO', '任务']) {
      expect(
        tester.widget<Text>(find.text(label)).style?.fontWeight,
        FontWeight.w800,
      );
    }
  });

  testWidgets('星期表头使用白色粗体和独立深色背景', (tester) async {
    await pumpSenka(tester, controller, const Size(1024, 600));

    final weekday = tester.widget<Text>(find.text('一'));
    expect(weekday.style?.color, const Color(0xffe7eef2));
    expect(weekday.style?.fontWeight, FontWeight.w800);
    expect(
      tester
          .widget<ColoredBox>(
            find.byKey(const Key('calendar-weekday-background')),
          )
          .color,
      const Color(0xff071923),
    );
  });

  testWidgets('当日底栏删除日期与合计并只保留三项来源', (tester) async {
    await pumpSenka(tester, controller, const Size(1024, 600));

    expect(find.text('8月10日'), findsNothing);
    expect(find.text('经验'), findsOneWidget);
    expect(find.text('EO'), findsOneWidget);
    expect(find.text('任务'), findsOneWidget);
  });

  testWidgets('战果标题后显示最近一次排名刷新的 JST 时间', (tester) async {
    await pumpSenka(tester, controller, const Size(1024, 600));

    expect(find.text('更新：2026-08-10 15:00:00'), findsOneWidget);
  });

  testWidgets('EO 与任务胶囊的首个状态符与面板标题左对齐', (tester) async {
    await pumpSenka(tester, controller, const Size(1024, 600));

    final titleLeft = tester.getTopLeft(find.text('EO 与战果任务')).dx;
    final markLeft = tester
        .getTopLeft(
          find.descendant(
            of: find.byKey(const Key('senka-cell-eo-15')),
            matching: find.text('✓'),
          ),
        )
        .dx;
    expect(markLeft, closeTo(titleLeft, 0.1));
  });

  testWidgets('本月已记录与战果面板标题同字号并加粗', (tester) async {
    await pumpSenka(tester, controller, const Size(1024, 600));

    final recorded = tester.widget<Text>(find.text('本月已记录 '));
    expect(recorded.style?.fontSize, textSize(tester, find.text('战果信息')));
    expect(recorded.style?.fontWeight, FontWeight.w800);
  });

  testWidgets('页面内部普通尺寸字号按确认值整体增加 2', (tester) async {
    await pumpSenka(tester, controller, const Size(1024, 600));

    expect(textSize(tester, find.text('战果信息')), 15);
    expect(textSize(tester, find.text('顺位')), 14);
    expect(textSize(tester, find.byKey(const Key('player-rank'))), 14);
    expect(textSize(tester, find.text('1-5')), 13);
    expect(find.text('›'), findsNothing);
    expect(textSize(tester, find.text('已选择战果奖励')), 14);
    expect(textSize(tester, find.text('一')), 13);

    final calendarTexts = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byKey(const Key('calendar-cell-14')),
            matching: find.byType(Text),
          ),
        )
        .toList();
    expect(calendarTexts[0].style?.fontSize, 18);
    expect(calendarTexts[1].style?.fontSize, 14);
    expect(textSize(tester, find.text('经验')), 14);
  });

  testWidgets('页面内部紧凑尺寸字号按确认值整体增加 2', (tester) async {
    await pumpSenka(tester, controller, const Size(844, 390));

    expect(textSize(tester, find.text('战果信息')), 12);
    expect(textSize(tester, find.text('顺位')), 10);
    expect(textSize(tester, find.byKey(const Key('player-rank'))), 10);
    expect(textSize(tester, find.text('1-5')), 10);
    expect(find.text('›'), findsNothing);
    expect(textSize(tester, find.text('已选择战果奖励')), 10);
    expect(textSize(tester, find.text('一')), 10);

    final calendarTexts = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byKey(const Key('calendar-cell-14')),
            matching: find.byType(Text),
          ),
        )
        .toList();
    expect(calendarTexts[0].style?.fontSize, 16);
    expect(calendarTexts[1].style?.fontSize, 12);
    expect(textSize(tester, find.text('经验')), 10);
  });

  testWidgets('矩阵任务胶囊按三态循环且不提供详情跳转', (tester) async {
    await pumpSenka(tester, controller, const Size(1024, 600));

    expect(controller.state.completedQuestIds, isNot(contains(854)));
    await tester.tap(find.byKey(const Key('senka-toggle-quest-854')));
    await tester.pump();
    expect(controller.state.questStatuses[854], SenkaRewardStatus.planned);
    await tester.tap(find.byKey(const Key('senka-toggle-quest-854')));
    await tester.pump();
    expect(controller.state.completedQuestIds, contains(854));
    expect(find.byKey(const Key('senka-detail-quest-854')), findsNothing);
    expect(find.text('›'), findsNothing);
  });

  testWidgets('矩阵胶囊纵向撑满行高且只保留设计间距', (tester) async {
    await pumpSenka(tester, controller, const Size(1024, 600));

    final firstRow = tester.getRect(find.byKey(const Key('senka-cell-eo-15')));
    final secondRow = tester.getRect(find.byKey(const Key('senka-cell-eo-45')));
    expect(secondRow.top - firstRow.bottom, closeTo(4, 0.1));
    expect(firstRow.height, greaterThan(30));
  });

  testWidgets('日期详情和左右底栏使用同一高度', (tester) async {
    await pumpSenka(tester, controller, const Size(1024, 600));

    final summary = tester.getSize(
      find.byKey(const Key('senka-month-summary')),
    );
    final detail = tester.getSize(find.byKey(const Key('senka-day-detail')));
    expect(summary.height, detail.height);
    expect(find.text('8月10日'), findsNothing);
    expect(find.text('+3.8'), findsWidgets);
    expect(find.text('经验'), findsOneWidget);
    expect(find.text('EO'), findsOneWidget);
    expect(find.text('任务'), findsOneWidget);
  });
}

double? textSize(WidgetTester tester, Finder finder) =>
    tester.widget<Text>(finder).style?.fontSize ??
    (tester
                .widget<RichText>(
                  find.descendant(of: finder, matching: find.byType(RichText)),
                )
                .text
            as TextSpan?)
        ?.style
        ?.fontSize;

Future<void> pumpSenka(
  WidgetTester tester,
  SenkaController controller,
  Size size,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: SenkaPage(controller: controller, now: DateTime(2026, 8, 10)),
    ),
  );
  await tester.pump();
}

SenkaState sampleState() => SenkaState.forMonth('2026-08').copyWith(
  memberId: 123,
  nickname: '矢矧',
  completedEoIds: {15, 25, 55},
  days: {'2026-08-10': const SenkaDayRecord(experience: 3.8)},
  rankingHistory: {
    '5': [snapshot(5, 4755)],
    '20': [snapshot(20, 0)],
    '100': [snapshot(100, 0)],
    '501': [snapshot(501, 1144)],
    'player': [snapshot(3832, 100), snapshot(3874, 108)],
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
