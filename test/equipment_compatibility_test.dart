import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/inventory/equipment_compatibility.dart';

void main() {
  const service = EquipmentCompatibilityService(
    GameState(
      masterShips: <int, MasterShip>{
        100: MasterShip(
          id: 100,
          name: '北方舰改',
          shipTypeId: 2,
          classTypeId: 47,
          equipTypeIds: <int>{1, 21, 27},
          limitedEquipmentIdsByType: <int, Set<int>>{
            27: <int>{268},
          },
        ),
        101: MasterShip(
          id: 101,
          name: '白名单试验舰',
          shipTypeId: 2,
          classTypeId: 47,
          equipTypeIds: <int>{27},
          limitedEquipmentIdsByType: <int, Set<int>>{
            27: <int>{268},
          },
        ),
        200: MasterShip(
          id: 200,
          name: '普通驱逐舰',
          shipTypeId: 2,
          classTypeId: 12,
          equipTypeIds: <int>{1, 21},
        ),
        300: MasterShip(
          id: 300,
          name: '特殊舰种',
          shipTypeId: 3,
          classTypeId: 8,
          equipTypeIds: <int>{1},
        ),
        400: MasterShip(
          id: 400,
          name: '大口径试验舰',
          shipTypeId: 9,
          classTypeId: 2,
          equipTypeIds: <int>{38},
        ),
      },
      masterSlotItems: <int, MasterSlotItem>{
        10: MasterSlotItem(id: 10, name: '小口径主炮', type: <int>[0, 0, 1]),
        128: MasterSlotItem(id: 128, name: '试制51cm炮', type: <int>[0, 0, 3]),
        268: MasterSlotItem(id: 268, name: '北方迷彩', type: <int>[0, 0, 27]),
        269: MasterSlotItem(id: 269, name: '普通中型装甲', type: <int>[0, 0, 27]),
        300: MasterSlotItem(id: 300, name: '对空机枪', type: <int>[0, 0, 21]),
        900: MasterSlotItem(id: 900, name: '舰级专用炮', type: <int>[0, 0, 1]),
        901: MasterSlotItem(id: 901, name: '全舰种专用炮', type: <int>[0, 0, 1]),
      },
      expansionSlotEquipmentTypeIds: <int>{21, 27},
      expansionSlotLimitsByShipId: <int, Set<int>>{
        100: <int>{27},
      },
      expansionSlotSpecialRules: <int, ExpansionSlotSpecialRule>{
        268: ExpansionSlotSpecialRule(
          equipmentMasterId: 268,
          shipMasterIds: <int>{100},
          minimumImprovement: 7,
        ),
        900: ExpansionSlotSpecialRule(
          equipmentMasterId: 900,
          classTypeIds: <int>{47},
          minimumImprovement: 4,
        ),
        901: ExpansionSlotSpecialRule(
          equipmentMasterId: 901,
          shipTypeIds: <int>{99},
        ),
      },
    ),
  );

  test('regular slot accepts a normal equipment category', () {
    final result = service.resolve(shipMasterId: 200, equipmentMasterId: 10);

    expect(result?.canEquipInRegularSlot, isTrue);
    expect(result?.canEquipInExpansionSlot, isFalse);
  });

  test('regular slot honors a per-type equipment whitelist', () {
    final accepted = service.resolve(shipMasterId: 100, equipmentMasterId: 268);
    final rejected = service.resolve(shipMasterId: 100, equipmentMasterId: 269);

    expect(accepted?.canEquipInRegularSlot, isTrue);
    expect(rejected?.canEquipInRegularSlot, isFalse);
  });

  test('general expansion category is available when not limited', () {
    final result = service.resolve(shipMasterId: 100, equipmentMasterId: 300);

    expect(result?.canEquipInRegularSlot, isTrue);
    expect(result?.canEquipInExpansionSlot, isTrue);
    expect(result?.expansionSlotMinimumImprovement, 0);
  });

  test('general expansion category still honors an equipment whitelist', () {
    final rejected = service.resolve(shipMasterId: 101, equipmentMasterId: 269);

    expect(rejected?.canEquipInRegularSlot, isFalse);
    expect(rejected?.canEquipInExpansionSlot, isFalse);
  });

  test('special expansion rule restores a limited category with stars', () {
    final accepted = service.resolve(shipMasterId: 100, equipmentMasterId: 268);
    final rejected = service.resolve(shipMasterId: 100, equipmentMasterId: 269);

    expect(accepted?.canEquipInExpansionSlot, isTrue);
    expect(accepted?.expansionSlotMinimumImprovement, 7);
    expect(rejected?.canEquipInExpansionSlot, isFalse);
  });

  test('special expansion rules match class and all-ship-type marker', () {
    final classMatch = service.resolve(
      shipMasterId: 100,
      equipmentMasterId: 900,
    );
    final classMiss = service.resolve(
      shipMasterId: 200,
      equipmentMasterId: 900,
    );
    final allTypes = service.resolve(shipMasterId: 300, equipmentMasterId: 901);

    expect(classMatch?.canEquipInExpansionSlot, isTrue);
    expect(classMatch?.expansionSlotMinimumImprovement, 4);
    expect(classMiss?.canEquipInExpansionSlot, isFalse);
    expect(allTypes?.canEquipInExpansionSlot, isTrue);
  });

  test('uses the client effective type override for special equipment', () {
    final result = service.resolve(shipMasterId: 400, equipmentMasterId: 128);

    expect(result?.canEquipInRegularSlot, isTrue);
  });

  test('unknown ship or equipment returns null instead of incompatible', () {
    expect(service.resolve(shipMasterId: 999, equipmentMasterId: 10), isNull);
    expect(service.resolve(shipMasterId: 100, equipmentMasterId: 999), isNull);
  });
}
