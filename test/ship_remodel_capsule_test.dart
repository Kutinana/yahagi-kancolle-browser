import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/fleet/ship_remodel_capsule.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';

void main() {
  testWidgets('long remodel names wrap at narrow widths and large text sizes', (
    tester,
  ) async {
    final name = 'Very long ship name 改二特別仕様';
    final state = GameState(
      masterShips: {
        1: const MasterShip(
          id: 1,
          name: 'A',
          shipTypeId: 2,
          afterShipId: 2,
          afterLv: 75,
        ),
        2: MasterShip(id: 2, name: name, shipTypeId: 2),
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: SizedBox(
                width: 180,
                child: ShipRemodelCapsule(
                  state: state,
                  ship: const OwnedShip(id: 1, masterId: 1, level: 99),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('改造：$name · Lv.75'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('fleet-remodel-capsule'))).height,
      greaterThan(38),
    );
    expect(tester.takeException(), isNull);
    expect(find.textContaining('可改造'), findsNothing);
  });

  testWidgets(
    'same owned ship updates after remodel and missing master stays unknown',
    (tester) async {
      Future<void> show(GameState state, int masterId) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShipRemodelCapsule(
              state: state,
              ship: OwnedShip(id: 1, masterId: masterId, level: 99),
            ),
          ),
        ),
      );
      const state = GameState(
        masterShips: {
          1: MasterShip(
            id: 1,
            name: 'A',
            shipTypeId: 2,
            afterShipId: 2,
            afterLv: 75,
          ),
          2: MasterShip(id: 2, name: 'B', shipTypeId: 2),
        },
      );
      await show(state, 1);
      expect(find.text('改造：B · Lv.75'), findsOneWidget);
      await show(state, 2);
      expect(find.text('改造：无后续改造'), findsOneWidget);
      expect(find.textContaining('Lv.75'), findsNothing);
      await show(GameState.empty, 2);
      expect(find.text('改造：数据未齐'), findsOneWidget);
    },
  );
}
