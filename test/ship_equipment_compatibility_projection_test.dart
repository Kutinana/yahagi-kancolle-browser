import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/inventory/equipment_compatibility.dart';
import 'package:yahagi_kancolle_browser/src/inventory/equipment_compatibility_projection.dart';
import 'package:yahagi_kancolle_browser/src/inventory/owned_inventory_projection.dart';
import 'package:yahagi_kancolle_browser/src/inventory/ship_equipment_compatibility_projection.dart';

void main() {
  const state = GameState(
    masterShips: <int, MasterShip>{
      100: MasterShip(
        id: 100,
        name: '矢矧改二乙',
        shipTypeId: 3,
        classTypeId: 42,
        equipTypeIds: <int>{0, 1, 6, 15, 29, 31},
        limitedEquipmentIdsByType: <int, Set<int>>{
          29: <int>{999},
        },
      ),
    },
    masterSlotItemTypes: <int, String>{
      0: '无效类型',
      1: '小口径主炮',
      6: '舰上战斗机',
      15: '对空机枪',
      29: '探照灯',
      31: '',
    },
    masterSlotItems: <int, MasterSlotItem>{
      10: MasterSlotItem(
        id: 10,
        name: 'Alpha Gun',
        sortNo: 20,
        type: <int>[1, 0, 1, 1],
      ),
      11: MasterSlotItem(
        id: 11,
        name: 'Beta Gun',
        sortNo: 10,
        type: <int>[1, 0, 1, 1],
      ),
      12: MasterSlotItem(
        id: 12,
        name: 'Same Sort Gun',
        sortNo: 10,
        type: <int>[1, 0, 1, 1],
      ),
      20: MasterSlotItem(
        id: 20,
        name: '零式舰战',
        sortNo: 15,
        type: <int>[3, 0, 6, 6],
      ),
      30: MasterSlotItem(
        id: 30,
        name: '特殊探照灯',
        sortNo: 5,
        type: <int>[8, 0, 29, 24],
      ),
      40: MasterSlotItem(
        id: 40,
        name: '集中配备机枪',
        sortNo: 30,
        type: <int>[1, 0, 15, 15],
      ),
      90: MasterSlotItem(id: 90, name: '无排序装备', type: <int>[1, 0, 1, 1]),
      91: MasterSlotItem(id: 91, name: '', sortNo: 1, type: <int>[1, 0, 1, 1]),
      92: MasterSlotItem(
        id: 92,
        name: '无具体类型',
        sortNo: 2,
        type: <int>[1, 0, 0, 1],
      ),
      93: MasterSlotItem(
        id: 93,
        name: '无类型名',
        sortNo: 3,
        type: <int>[1, 0, 31, 1],
      ),
    },
    slotItems: <int, OwnedSlotItem>{
      1001: OwnedSlotItem(instanceId: 1001, masterSlotItemId: 10),
      1002: OwnedSlotItem(instanceId: 1002, masterSlotItemId: 10),
      2001: OwnedSlotItem(instanceId: 2001, masterSlotItemId: 20),
      4001: OwnedSlotItem(instanceId: 4001, masterSlotItemId: 40),
    },
    expansionSlotEquipmentTypeIds: <int>{15},
    expansionSlotSpecialRules: <int, ExpansionSlotSpecialRule>{
      30: ExpansionSlotSpecialRule(
        equipmentMasterId: 30,
        shipMasterIds: <int>{100},
        minimumImprovement: 4,
      ),
    },
  );

  final projection = ShipEquipmentCompatibilityProjection(state);

  test(
    'groups all compatible equipment by concrete type with stable sorting',
    () {
      final groups = projection.groups(shipMasterId: 100);

      expect(groups.map((group) => group.typeId), <int>[1, 6, 15, 29]);
      expect(groups.map((group) => group.typeName), <String>[
        '小口径主炮',
        '舰上战斗机',
        '对空机枪',
        '探照灯',
      ]);
      expect(groups.first.rows.map((row) => row.master.id), <int>[11, 12, 10]);
      expect(() => groups.add(groups.first), throwsUnsupportedError);
      expect(
        () => groups.first.rows.add(groups.first.rows.first),
        throwsUnsupportedError,
      );
    },
  );

  test('owned-only keeps owned masters and reports instance counts', () {
    final groups = projection.groups(shipMasterId: 100, ownedOnly: true);
    final rows = groups.expand((group) => group.rows).toList();

    expect(rows.map((row) => row.master.id), <int>[10, 20, 40]);
    expect(rows.singleWhere((row) => row.master.id == 10).ownedCount, 2);
    expect(rows.every((row) => row.ownedCount > 0), isTrue);
  });

  test('equipment category reuses inventory category classification', () {
    final groups = projection.groups(
      shipMasterId: 100,
      category: EquipmentInventoryCategory.carrierAircraft,
    );

    expect(groups, hasLength(1));
    expect(groups.single.rows.single.master.id, 20);
  });

  test('name search is trimmed and case-insensitive', () {
    final groups = projection.groups(shipMasterId: 100, query: '  ALPHA  ');

    expect(groups, hasLength(1));
    expect(groups.single.rows.single.master.id, 10);
  });

  test('regular and expansion filters use resolved compatibility', () {
    final regular = projection
        .groups(
          shipMasterId: 100,
          filter: EquipmentCompatibilitySlotFilter.regular,
        )
        .expand((group) => group.rows)
        .map((row) => row.master.id);
    final expansion = projection
        .groups(
          shipMasterId: 100,
          filter: EquipmentCompatibilitySlotFilter.expansion,
        )
        .expand((group) => group.rows)
        .map((row) => row.master.id);

    expect(regular, <int>[11, 12, 10, 20, 40]);
    expect(expansion, <int>[40, 30]);
    expect(
      projection
          .groups(shipMasterId: 100)
          .expand((group) => group.rows)
          .singleWhere((row) => row.master.id == 30)
          .compatibility
          .expansionSlotMinimumImprovement,
      4,
    );
  });

  test('invalid master equipment is excluded', () {
    const service = EquipmentCompatibilityService(state);
    for (final id in <int>[90, 91, 92, 93]) {
      expect(
        service.resolve(shipMasterId: 100, equipmentMasterId: id)?.canEquip,
        isTrue,
        reason: 'fixture equipment $id must otherwise be compatible',
      );
    }
    final ids = projection
        .groups(shipMasterId: 100)
        .expand((group) => group.rows)
        .map((row) => row.master.id);

    expect(ids, isNot(contains(90)));
    expect(ids, isNot(contains(91)));
    expect(ids, isNot(contains(92)));
    expect(ids, isNot(contains(93)));
  });

  test('unknown ship produces no groups', () {
    expect(projection.groups(shipMasterId: 999), isEmpty);
  });
}
