import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/inventory/owned_inventory_projection.dart';

void main() {
  const destroyer = MasterShip(id: 101, name: '吹雪改二', shipTypeId: 2, speed: 10);
  const carrier = MasterShip(id: 102, name: '日进甲', shipTypeId: 11, speed: 10);

  GameState fixture() => const GameState(
    masterShipTypes: <int, MasterShipType>{
      2: MasterShipType(id: 2, name: '驱逐舰'),
      11: MasterShipType(id: 11, name: '水上机母舰'),
    },
    masterShips: <int, MasterShip>{101: destroyer, 102: carrier},
    masterSlotItems: <int, MasterSlotItem>{
      201: MasterSlotItem(
        id: 201,
        name: '12.7cm连装炮',
        type: <int>[1, 1, 1, 1, 0],
      ),
      202: MasterSlotItem(
        id: 202,
        name: '零式水上侦察机',
        type: <int>[5, 7, 10, 10, 0],
      ),
    },
    ships: <int, OwnedShip>{
      1: OwnedShip(
        id: 1,
        masterId: 101,
        level: 98,
        condition: 49,
        slotIds: <int>[301, 302],
        firepower: 55,
        firepowerMax: 59,
        locked: true,
      ),
      2: OwnedShip(id: 2, masterId: 102, level: 112, condition: 73),
    },
    slotItems: <int, OwnedSlotItem>{
      301: OwnedSlotItem(id: 301, masterId: 201, level: 0),
      302: OwnedSlotItem(id: 302, masterId: 201, level: 7),
      303: OwnedSlotItem(id: 303, masterId: 201, level: 7),
      304: OwnedSlotItem(id: 304, masterId: 202, proficiency: 7),
    },
    fleets: <Fleet>[
      Fleet(id: 1, name: '第一舰队', shipIds: <int>[2]),
      Fleet(id: 4, name: '第四舰队', shipIds: <int>[1]),
    ],
  );

  test(
    'filters ship categories and sorts numeric fields in both directions',
    () {
      final projection = OwnedInventoryProjection(fixture());

      expect(
        projection.shipRows(category: ShipInventoryCategory.dd),
        hasLength(1),
      );
      expect(
        projection
            .shipRows(sortField: ShipInventorySortField.level, descending: true)
            .map((row) => row.ship.id),
        <int>[2, 1],
      );
      expect(projection.fleetNumberForShip(1), 4);
    },
  );

  test(
    'groups equipment counts, remaining items, variants and wearing ships',
    () {
      final group = OwnedInventoryProjection(
        fixture(),
      ).equipmentGroups(category: EquipmentInventoryCategory.mainGun).single;

      expect(group.total, 3);
      expect(group.remaining, 1);
      expect(
        group.variants.map((variant) => (variant.level, variant.count)),
        <(int, int)>[(0, 1), (7, 2)],
      );
      expect(group.wearings.single.shipName, '吹雪改二');
      expect(group.wearings.single.level, 98);
      expect(group.wearings.single.count, 2);
    },
  );

  test(
    'summarizes all improvements before proficiencies in ascending order',
    () {
      const variants = <EquipmentInventoryVariant>[
        EquipmentInventoryVariant(level: 5, proficiency: 2, count: 1),
        EquipmentInventoryVariant(level: 0, proficiency: 3, count: 2),
        EquipmentInventoryVariant(level: 0, proficiency: 2, count: 1),
      ];

      final summaries = summarizeEquipmentVariants(variants);

      expect(
        summaries.map((entry) => (entry.kind, entry.level, entry.count)),
        <(EquipmentVariantSummaryKind, int, int)>[
          (EquipmentVariantSummaryKind.improvement, 0, 3),
          (EquipmentVariantSummaryKind.improvement, 5, 1),
          (EquipmentVariantSummaryKind.proficiency, 2, 2),
          (EquipmentVariantSummaryKind.proficiency, 3, 2),
        ],
      );
    },
  );

  test('uses the confirmed ten equipment category mapping', () {
    expect(
      equipmentInventoryCategoryFor(
        const MasterSlotItem(id: 1, name: '主炮', type: <int>[1, 1, 1, 1, 0]),
      ),
      EquipmentInventoryCategory.mainGun,
    );
    expect(
      equipmentInventoryCategoryFor(
        const MasterSlotItem(id: 2, name: '水上机', type: <int>[5, 7, 10, 10, 0]),
      ),
      EquipmentInventoryCategory.seaplane,
    );
    expect(
      equipmentInventoryCategoryFor(
        const MasterSlotItem(id: 3, name: '电探', type: <int>[5, 8, 12, 11, 0]),
      ),
      EquipmentInventoryCategory.radar,
    );
    expect(
      equipmentInventoryCategoryFor(
        const MasterSlotItem(
          id: 4,
          name: '25mm三连装机枪',
          type: <int>[4, 6, 15, 15, 0],
        ),
      ),
      EquipmentInventoryCategory.machineGun,
    );
    expect(
      equipmentInventoryCategoryFor(
        const MasterSlotItem(id: 5, name: '探照灯', type: <int>[9, 11, 29, 24, 0]),
      ),
      EquipmentInventoryCategory.support,
    );
    expect(
      equipmentInventoryCategoryFor(
        const MasterSlotItem(
          id: 6,
          name: '96式150cm探照灯',
          type: <int>[9, 11, 42, 24, 0],
        ),
      ),
      EquipmentInventoryCategory.support,
    );
    expect(
      equipmentInventoryCategoryFor(
        const MasterSlotItem(
          id: 7,
          name: 'ドラム缶(輸送用)',
          type: <int>[9, 14, 30, 25, 0],
        ),
      ),
      EquipmentInventoryCategory.landingTransport,
    );
  });
}
