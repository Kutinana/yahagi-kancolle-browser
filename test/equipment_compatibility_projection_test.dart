import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/inventory/equipment_compatibility_projection.dart';

void main() {
  const state = GameState(
    masterShipTypes: <int, MasterShipType>{
      2: MasterShipType(id: 2, name: '驱逐舰', equipTypeIds: <int>{1}),
      3: MasterShipType(id: 3, name: '轻巡洋舰', equipTypeIds: <int>{1}),
    },
    masterShips: <int, MasterShip>{
      1: MasterShip(
        id: 1,
        name: '矢矧',
        shipTypeId: 3,
        sortNo: 101,
        equipTypeIds: <int>{1},
      ),
      2: MasterShip(
        id: 2,
        name: '矢矧改',
        shipTypeId: 3,
        sortNo: 102,
        equipTypeIds: <int>{1},
      ),
      3: MasterShip(
        id: 3,
        name: '矢矧改二乙',
        shipTypeId: 3,
        sortNo: 103,
        equipTypeIds: <int>{1},
      ),
      4: MasterShip(
        id: 4,
        name: '吹雪改二',
        shipTypeId: 2,
        sortNo: 20,
        equipTypeIds: <int>{1},
      ),
      5: MasterShip(id: 5, name: '不兼容舰', shipTypeId: 2, sortNo: 21),
      1501: MasterShip(
        id: 1501,
        name: '深海舰',
        shipTypeId: 2,
        sortNo: 1,
        equipTypeIds: <int>{1},
      ),
    },
    masterSlotItems: <int, MasterSlotItem>{
      10: MasterSlotItem(id: 10, name: '测试炮', type: <int>[0, 0, 1]),
      11: MasterSlotItem(id: 11, name: '交集测试炮', type: <int>[0, 0, 1]),
    },
    expansionSlotSpecialRules: <int, ExpansionSlotSpecialRule>{
      10: ExpansionSlotSpecialRule(
        equipmentMasterId: 10,
        shipTypeIds: <int>{3},
      ),
      11: ExpansionSlotSpecialRule(
        equipmentMasterId: 11,
        shipMasterIds: <int>{3},
      ),
    },
    ships: <int, OwnedShip>{
      101: OwnedShip(id: 101, masterId: 3, level: 99),
      102: OwnedShip(id: 102, masterId: 3, level: 80),
      103: OwnedShip(id: 103, masterId: 4, level: 70),
    },
    fleets: <Fleet>[
      Fleet(id: 1, name: '第一舰队', shipIds: <int>[101, 103]),
      Fleet(id: 2, name: '第二舰队', shipIds: <int>[102]),
    ],
  );

  final projection = EquipmentCompatibilityProjection(state);

  test('all rows keep remodel forms separate and exclude abyssal ships', () {
    final rows = projection.rows(equipmentMasterId: 10);

    expect(rows.map((row) => row.shipMaster.id), <int>[4, 1, 2, 3]);
    expect(rows.map((row) => row.shipMaster.id), isNot(contains(1501)));
    expect(rows.map((row) => row.shipMaster.id), isNot(contains(5)));
  });

  test('owned rows combine duplicate instances and fleet membership', () {
    final rows = projection.rows(equipmentMasterId: 10, ownedOnly: true);
    final yahagi = rows.singleWhere((row) => row.shipMaster.id == 3);

    expect(rows, hasLength(2));
    expect(yahagi.ownedShips, hasLength(2));
    expect(yahagi.ownedShips.map((ship) => ship.level), <int>[99, 80]);
    expect(yahagi.fleetNumbers, <int>{1, 2});
  });

  test('search and slot filters apply to compatible rows', () {
    final searched = projection.rows(equipmentMasterId: 10, query: '改二乙');
    final expansion = projection.rows(
      equipmentMasterId: 10,
      filter: EquipmentCompatibilitySlotFilter.expansion,
    );
    final regular = projection.rows(
      equipmentMasterId: 10,
      filter: EquipmentCompatibilitySlotFilter.regular,
    );

    expect(searched.map((row) => row.shipMaster.id), <int>[3]);
    expect(expansion.map((row) => row.shipMaster.id), <int>[1, 2, 3]);
    expect(regular.map((row) => row.shipMaster.id), <int>[4, 1, 2, 3]);
  });

  test('ship type filter keeps only rows of the selected type', () {
    final rows = projection.rows(equipmentMasterId: 10, shipTypeId: 3);

    expect(rows.map((row) => row.shipMaster.id), <int>[1, 2, 3]);
  });

  test('null ship type filter keeps all rows', () {
    final rows = projection.rows(equipmentMasterId: 10, shipTypeId: null);

    expect(rows.map((row) => row.shipMaster.id), <int>[4, 1, 2, 3]);
  });

  test('ship type filter combines with owned-only filter', () {
    final rows = projection.rows(
      equipmentMasterId: 10,
      shipTypeId: 3,
      ownedOnly: true,
    );

    expect(rows.map((row) => row.shipMaster.id), <int>[3]);
  });

  test('ship type, query, and slot filters return their intersection', () {
    final queryRows = projection.rows(equipmentMasterId: 11, query: '改');
    final queryAndTypeRows = projection.rows(
      equipmentMasterId: 11,
      shipTypeId: 3,
      query: '改',
    );
    final rows = projection.rows(
      equipmentMasterId: 11,
      shipTypeId: 3,
      query: '改',
      filter: EquipmentCompatibilitySlotFilter.expansion,
    );

    expect(queryRows.map((row) => row.shipMaster.id), <int>[4, 2, 3]);
    expect(queryAndTypeRows.map((row) => row.shipMaster.id), <int>[2, 3]);
    expect(rows.map((row) => row.shipMaster.id), <int>[3]);
  });
}
