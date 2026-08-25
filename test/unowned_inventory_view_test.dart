import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/inventory/owned_inventory_page.dart';

void main() {
  const state = GameState(
    masterShipTypes: <int, MasterShipType>{
      1: MasterShipType(id: 1, name: '海防舰'),
    },
    masterShips: <int, MasterShip>{
      454: MasterShip(id: 454, name: '能美', shipTypeId: 1, sortNo: 454),
    },
    masterSlotItemTypes: <int, String>{6: '舰上战斗机'},
    masterSlotItems: <int, MasterSlotItem>{
      110: MasterSlotItem(
        id: 110,
        name: '烈风',
        sortNo: 110,
        firepower: 3,
        antiAir: 2,
        type: <int>[0, 0, 6, 6],
      ),
    },
  );

  testWidgets('shows unowned ship name and type on separate text rows', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 500,
            child: UnownedInventoryView(state: state, showShips: true),
          ),
        ),
      ),
    );

    expect(find.text('能美'), findsOneWidget);
    expect(find.text('海防舰'), findsAtLeastNWidgets(1));
    expect(find.textContaining('No.'), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('equipment collection view omits stats ids and exclusions', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 500,
            child: UnownedInventoryView(state: state, showShips: false),
          ),
        ),
      ),
    );

    expect(find.text('烈风'), findsOneWidget);
    expect(find.text('舰上战斗机'), findsAtLeastNWidgets(1));
    expect(find.textContaining('火力'), findsNothing);
    expect(find.textContaining('对空'), findsNothing);
    expect(find.textContaining('No.'), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
  });
}
