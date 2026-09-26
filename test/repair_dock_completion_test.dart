import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/fleet/operation_status_views.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/performance/second_tick_scope.dart';

GameState repairState(DateTime end) => GameState(
  masterShips: const {101: MasterShip(id: 101, name: '测试舰', shipTypeId: 2)},
  ships: const {
    1001: OwnedShip(
      id: 1001,
      masterId: 101,
      level: 50,
      currentHp: 4,
      maxHp: 39,
      repairDurationMilliseconds: 60000,
    ),
  },
  repairDocks: [
    RepairDock(id: 1, state: 1, shipId: 1001, completionTime: end),
    RepairDock(
      id: 2,
      state: 1,
      shipId: 1001,
      completionTime: end.add(const Duration(hours: 1)),
    ),
    const RepairDock(id: 3, state: -1),
    const RepairDock(id: 4),
  ],
);

Finder portrait(int dock) => find.byKey(Key('repair-portrait-$dock'));

void main() {
  testWidgets('repair card clears at deadline without a server update', (
    tester,
  ) async {
    var now = DateTime.utc(2030);
    final end = now.add(const Duration(seconds: 2));
    final state = repairState(end);
    await tester.pumpWidget(
      MaterialApp(
        home: SecondTickScope(
          now: () => now,
          child: Scaffold(body: RepairDockStatusView(state: state)),
        ),
      ),
    );
    expect(portrait(1), findsOneWidget);
    now = end.subtract(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(portrait(1), findsOneWidget);

    now = end;
    await tester.pump(const Duration(seconds: 1));
    expect(portrait(1), findsNothing);
    expect(portrait(2), findsOneWidget);
    expect(find.text('未入渠'), findsNWidgets(2));
    expect(find.text('未解锁'), findsOneWidget);
    expect(state.repairDocks.first.isRepairing, isTrue);
    expect(state.ships[1001]!.currentHp, 4);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('expired card is empty on opening and accepts a new repair', (
    tester,
  ) async {
    var now = DateTime.utc(2030);
    final state = ValueNotifier(
      repairState(now.subtract(const Duration(seconds: 1))),
    );
    addTearDown(state.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: SecondTickScope(
          now: () => now,
          child: Scaffold(
            body: ValueListenableBuilder<GameState>(
              valueListenable: state,
              builder: (_, value, _) => RepairDockStatusView(state: value),
            ),
          ),
        ),
      ),
    );
    expect(portrait(1), findsNothing);

    final end = now.add(const Duration(seconds: 2));
    state.value = repairState(end);
    await tester.pump();
    expect(portrait(1), findsOneWidget);
    now = end;
    await tester.pump(const Duration(seconds: 2));
    expect(portrait(1), findsNothing);

    state.value = repairState(
      end,
    ).copyWith(repairDocks: const [RepairDock(id: 1)]);
    await tester.pump();
    expect(find.text('未入渠'), findsNWidgets(4));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('repair without a known deadline stays visible', (tester) async {
    final state = repairState(
      DateTime.utc(2030),
    ).copyWith(repairDocks: const [RepairDock(id: 1, state: 1, shipId: 1001)]);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: RepairDockStatusView(state: state)),
      ),
    );
    await tester.pump(const Duration(seconds: 3));
    expect(portrait(1), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
