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

      await tester.tap(find.byKey(const Key('senka-tab-calendar')));
      await tester.pump();
      expect(find.text('2026年8月战果日历'), findsOneWidget);
      expect(find.text('服务器概况'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('senka-tab-calculator')));
      await tester.pump();
      expect(find.text('目标战果'), findsOneWidget);
      expect(find.text('2026年8月战果日历'), findsNothing);
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
    expect(rects.every((rect) => rect.height >= 36), isTrue);
    expect(tabColor(tester, 'info'), const Color(0xffd7a957));
    expect(tabColor(tester, 'calendar'), isNot(const Color(0xffd7a957)));
  });

  testWidgets('信息页横屏左右等宽，方形与竖屏顺序滚动', (tester) async {
    await pumpSenka(tester, controller, const Size(1280, 680));
    final left = tester.getRect(find.byKey(const Key('senka-info-left')));
    final right = tester.getRect(find.byKey(const Key('senka-info-right')));
    expect(left.width, closeTo(right.width, 1));
    expect(left.left, lessThan(right.left));

    await pumpSenka(tester, controller, const Size(720, 720));
    final serverY = tester.getTopLeft(find.text('服务器概况')).dy;
    final rankingY = tester.getTopLeft(find.text('战果排名')).dy;
    expect(serverY, lessThan(rankingY));
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

  testWidgets('统计默认隐藏隐藏项，显示后可取消并支持收藏置顶', (tester) async {
    await pumpSenka(tester, controller, const Size(1280, 680));
    expect(find.text('2-1'), findsNothing);
    await tester.tap(find.byKey(const Key('senka-show-hidden')));
    await tester.pump();
    expect(find.text('2-1'), findsOneWidget);
    await tester.tap(find.byKey(const Key('senka-hide-2-1')));
    await tester.pump();
    expect(controller.state.hiddenSortieMapKeys, isNot(contains('2-1')));
    await tester.tap(find.byKey(const Key('senka-favorite-1-1')));
    await tester.pump();
    expect(controller.state.favoriteSortieMapKeys, contains('1-1'));
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
    await pumpCalculator(tester, controller, const Size(1280, 680));
    for (final title in ['EO 战果奖励', '季度战果任务', '年度战果任务', '单次战果任务']) {
      expect(find.text(title), findsOneWidget);
    }
    expect(find.text('AL作戦'), findsOneWidget);
    expect(find.text('機動部隊決戦'), findsOneWidget);
    expect(find.text('火球炮'), findsOneWidget);
    final toggle = find.byKey(const Key('senka-toggle-quest-854'));
    expect(
      find.descendant(of: toggle, matching: find.text('✕')),
      findsOneWidget,
    );
    await tester.tap(toggle);
    await tester.pump();
    expect(controller.state.questStatuses[854], SenkaRewardStatus.planned);
    expect(
      find.descendant(of: toggle, matching: find.text('✓')),
      findsOneWidget,
    );
    await tester.tap(toggle);
    await tester.pump();
    expect(controller.state.questStatuses[854], SenkaRewardStatus.completed);
    expect(find.byKey(const Key('senka-strike-quest-854')), findsOneWidget);
    expect(find.descendant(of: toggle, matching: find.text('✓')), findsNothing);
  });

  testWidgets('计算页 footer 分列计划奖励并给出合计', (tester) async {
    await pumpCalculator(tester, controller, const Size(1280, 680));
    expect(find.textContaining('计划 EO 战果奖励 +'), findsOneWidget);
    expect(find.textContaining('计划任务战果奖励 +'), findsOneWidget);
    expect(find.textContaining('合计：'), findsOneWidget);
  });
}

Color? tabColor(WidgetTester tester, String name) =>
    tester.widget<Material>(find.byKey(Key('senka-tab-$name'))).color;

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
