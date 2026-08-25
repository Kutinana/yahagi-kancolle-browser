import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/fleet/land_base_summary_card.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';

import 'fixtures/kcsapi_fixtures.dart';

void main() {
  testWidgets(
    'damage frames only the portrait and never creates a fatigue face',
    (tester) async {
      await tester.pumpWidget(
        _row(base: _base(currentHp: 48, conditions: const <int>[1, 1, 1, 1])),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        find.byKey(const Key('land-base-portrait-hp-frame-62-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('land-base-row-hp-frame-62-1')),
        findsNothing,
      );
      expect(find.byKey(const Key('land-base-hp-meter-62-1')), findsOneWidget);
      expect(
        find.byKey(const Key('land-base-fatigue-face-62-1')),
        findsNothing,
      );
    },
  );

  for (final entry in <int, String>{2: 'yellow', 3: 'red'}.entries) {
    testWidgets('${entry.value} fatigue face sits at portrait top-right', (
      tester,
    ) async {
      await tester.pumpWidget(
        _row(
          base: _base(currentHp: 200, conditions: <int>[1, entry.key, 1, 1]),
        ),
      );

      final portrait = tester.getRect(
        find.byKey(const Key('land-base-portrait-62-1')),
      );
      final face = tester.getRect(
        find.byKey(const Key('land-base-fatigue-face-62-1')),
      );
      expect(face.top, closeTo(portrait.top, 0.1));
      expect(face.right, closeTo(portrait.right, 0.1));
    });
  }

  testWidgets('renders four slots including missing planes and relocation', (
    tester,
  ) async {
    await tester.pumpWidget(
      _row(
        base: _base(
          currentHp: 152,
          conditions: const <int>[1, 2, 3, 1],
          states: const <int>[1, 1, 2, 0],
          counts: const <int>[18, 12, 0, 0],
        ),
      ),
    );

    for (var id = 1; id <= 4; id++) {
      expect(find.byKey(Key('land-base-slot-62-1-$id')), findsOneWidget);
    }
    expect(find.text('18'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(
      find.byKey(const Key('land-base-slot-relocating-62-1-3')),
      findsOneWidget,
    );
  });

  testWidgets('card switches areas and collapses without a details panel', (
    tester,
  ) async {
    final controller = await _controllerWithLandBases();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_card(controller));
    await tester.pump();

    expect(find.text('[6] 中部海域'), findsOneWidget);
    expect(find.text('其他海域基地'), findsOneWidget);
    expect(find.text('第一基地航空队'), findsNothing);

    await tester.tap(find.byKey(const Key('land-base-area-selector-62')));
    await tester.pump();
    expect(find.text('[62] 反击！第三十一战队的战斗'), findsOneWidget);
    expect(find.text('第一基地航空队'), findsOneWidget);
    expect(find.text('其他海域基地'), findsNothing);

    await tester.tap(find.byKey(const Key('land-base-collapse-button')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(LandBaseAirGroupRow), findsNothing);
    expect(find.text('点击航空队查看装备详情'), findsNothing);
  });
}

LandBaseState _base({
  required int currentHp,
  required List<int> conditions,
  List<int> states = const <int>[1, 1, 1, 1],
  List<int> counts = const <int>[18, 18, 18, 18],
}) => LandBaseState(
  areaId: 62,
  baseId: 1,
  name: '第一基地航空队',
  actionKind: 1,
  distanceBase: 7,
  maxHp: 200,
  currentHp: currentHp,
  squadrons: <LandBaseSquadronState>[
    for (var index = 0; index < 4; index++)
      LandBaseSquadronState(
        squadronId: index + 1,
        state: states[index],
        slotItemId: 1001 + index,
        currentCount: counts[index],
        maxCount: 18,
        condition: conditions[index],
      ),
  ],
);

Widget _row({required LandBaseState base}) => MaterialApp(
  home: Scaffold(
    body: SizedBox(
      width: 640,
      child: LandBaseAirGroupRow(state: _state(base), base: base),
    ),
  ),
);

GameState _state(LandBaseState base) => GameState(
  serverOrigin: 'https://example.test',
  landBases: <LandBaseState>[base],
  masterSlotItems: <int, MasterSlotItem>{
    for (var index = 0; index < 4; index++)
      201 + index: MasterSlotItem(
        id: 201 + index,
        name: '陆航装备${index + 1}',
        antiAir: 10,
        type: const <int>[0, 0, 6, 6],
      ),
  },
  slotItems: <int, OwnedSlotItem>{
    for (var index = 0; index < 4; index++)
      1001 + index: OwnedSlotItem(id: 1001 + index, masterId: 201 + index),
  },
);

Future<GameStateController> _controllerWithLandBases() async {
  final controller = GameStateController();
  controller
    ..accept(
      kcsapiEvent('/kcsapi/api_start2/getData', <String, Object?>{
        'api_mst_stype': const <Object?>[],
        'api_mst_ship': const <Object?>[],
        'api_mst_maparea': <Object?>[
          <String, Object?>{'api_id': 6, 'api_name': '中部海域'},
          <String, Object?>{'api_id': 62, 'api_name': '反击！第三十一战队的战斗'},
        ],
      }),
    )
    ..accept(
      kcsapiEvent('/kcsapi/api_get_member/mapinfo', <String, Object?>{
        'api_map_info': const <Object?>[],
        'api_air_base': <Object?>[
          <String, Object?>{
            'api_area_id': 6,
            'api_rid': 1,
            'api_name': '其他海域基地',
          },
          <String, Object?>{
            'api_area_id': 62,
            'api_rid': 1,
            'api_name': '第一基地航空队',
          },
        ],
      }),
    );
  await controller.idle;
  return controller;
}

Widget _card(GameStateController controller) => MaterialApp(
  home: Scaffold(body: _CardHarness(controller: controller)),
);

class _CardHarness extends StatefulWidget {
  const _CardHarness({required this.controller});

  final GameStateController controller;

  @override
  State<_CardHarness> createState() => _CardHarnessState();
}

class _CardHarnessState extends State<_CardHarness> {
  var _collapsed = false;

  @override
  Widget build(BuildContext context) => LandBaseSummaryCard(
    controller: widget.controller,
    collapsed: _collapsed,
    onToggleCollapse: () => setState(() => _collapsed = !_collapsed),
  );
}
