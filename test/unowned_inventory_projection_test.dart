import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/inventory/owned_inventory_projection.dart';
import 'package:yahagi_kancolle_browser/src/inventory/unowned_inventory_projection.dart';

void main() {
  test('projects unowned ship families and equipment master data', () {
    const state = GameState(
      masterShipTypes: <int, MasterShipType>{
        2: MasterShipType(id: 2, name: '驱逐舰'),
        8: MasterShipType(id: 8, name: '战舰'),
      },
      masterShips: <int, MasterShip>{
        1: MasterShip(
          id: 1,
          name: '一号',
          shipTypeId: 2,
          sortNo: 1,
          afterShipId: 2,
        ),
        2: MasterShip(
          id: 2,
          name: '一号改',
          shipTypeId: 2,
          sortNo: 2,
          afterShipId: 3,
        ),
        3: MasterShip(id: 3, name: '一号改二', shipTypeId: 2, sortNo: 3),
        4: MasterShip(id: 4, name: '四号', shipTypeId: 2, sortNo: 4),
        8: MasterShip(id: 8, name: '八号', shipTypeId: 8, sortNo: 8),
        999: MasterShip(id: 999, name: '内部舰', shipTypeId: 2),
      },
      ships: <int, OwnedShip>{30: OwnedShip(id: 30, masterId: 3, level: 80)},
      masterSlotItemTypes: <int, String>{1: '小口径主炮', 6: '舰上战斗机'},
      masterSlotItems: <int, MasterSlotItem>{
        101: MasterSlotItem(
          id: 101,
          name: '已持有炮',
          sortNo: 1,
          type: <int>[1, 0, 1, 1],
        ),
        102: MasterSlotItem(
          id: 102,
          name: '未持有炮',
          sortNo: 2,
          type: <int>[1, 0, 1, 1],
        ),
        103: MasterSlotItem(
          id: 103,
          name: '未持有战斗机',
          sortNo: 3,
          type: <int>[3, 0, 6, 6],
        ),
        999: MasterSlotItem(id: 999, name: '内部装备', type: <int>[0, 0, 1]),
      },
      slotItems: <int, OwnedSlotItem>{
        1: OwnedSlotItem(instanceId: 1, masterSlotItemId: 101),
      },
    );

    final projection = UnownedInventoryProjection(state);

    expect(projection.familyRootOf(3), 1);
    expect(projection.unownedShipFamilies.map((row) => row.master.id), <int>[
      4,
      8,
    ]);
    expect(projection.unownedShipFamilies.first.typeName, '驱逐舰');
    expect(projection.unownedEquipment.map((row) => row.master.id), <int>[
      102,
      103,
    ]);
    expect(projection.unownedEquipment.first.typeName, '小口径主炮');

    expect(
      projection
          .unownedShipFamiliesFor(category: ShipInventoryCategory.dd)
          .map((row) => row.master.id),
      <int>[4],
    );
    expect(
      projection
          .unownedShipFamiliesFor(category: ShipInventoryCategory.bbBc)
          .map((row) => row.master.id),
      <int>[8],
    );
    expect(
      projection
          .unownedEquipmentFor(category: EquipmentInventoryCategory.mainGun)
          .map((row) => row.master.id),
      <int>[102],
    );
    expect(
      projection
          .unownedEquipmentFor(
            category: EquipmentInventoryCategory.carrierAircraft,
          )
          .map((row) => row.master.id),
      <int>[103],
    );
  });

  test('broken and cyclic remodel links safely keep their own roots', () {
    const state = GameState(
      masterShips: <int, MasterShip>{
        5: MasterShip(id: 5, name: '缺失后继', shipTypeId: 2, afterShipId: 50),
        6: MasterShip(id: 6, name: '循环甲', shipTypeId: 2, afterShipId: 7),
        7: MasterShip(id: 7, name: '循环乙', shipTypeId: 2, afterShipId: 6),
      },
    );

    final projection = UnownedInventoryProjection(state);

    expect(projection.familyRootOf(5), 5);
    expect(projection.familyRootOf(6), 6);
    expect(projection.familyRootOf(7), 7);
  });
}
