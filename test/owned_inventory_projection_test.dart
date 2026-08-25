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

  test('keeps battleships combined and splits carrier categories', () {
    List<int> matches(ShipInventoryCategory category) => [
      for (var typeId = 1; typeId <= 22; typeId++)
        if (shipTypeMatchesInventoryCategory(typeId, category)) typeId,
    ];

    expect(matches(ShipInventoryCategory.bbBc), <int>[8, 9, 10, 12]);
    expect(matches(ShipInventoryCategory.cv), <int>[11, 18]);
    expect(matches(ShipInventoryCategory.cvl), <int>[7]);
    expect(
      <int>{
        ...matches(ShipInventoryCategory.cv),
        ...matches(ShipInventoryCategory.cvl),
      },
      <int>{7, 11, 18},
    );
  });

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
            .shipRows(
              sortCriteria: const <ShipInventorySortCriterion>[
                ShipInventorySortCriterion(
                  field: ShipInventorySortField.level,
                  descending: true,
                ),
              ],
            )
            .map((row) => row.ship.id),
        <int>[2, 1],
      );
      expect(projection.fleetNumberForShip(1), 4);
    },
  );

  test('sorts ships by each criterion in priority order', () {
    final projection = OwnedInventoryProjection(_multiSortFixture());

    expect(
      projection
          .shipRows(
            sortCriteria: const <ShipInventorySortCriterion>[
              ShipInventorySortCriterion(
                field: ShipInventorySortField.level,
                descending: true,
              ),
              ShipInventorySortCriterion(
                field: ShipInventorySortField.firepower,
                descending: true,
              ),
              ShipInventorySortCriterion(
                field: ShipInventorySortField.antiSub,
                descending: false,
              ),
            ],
          )
          .map((row) => row.ship.id),
      <int>[4, 3, 2, 1],
    );
  });

  test('uses level descending when the criterion list is empty', () {
    final projection = OwnedInventoryProjection(_multiSortFixture());

    expect(
      projection
          .shipRows(sortCriteria: const <ShipInventorySortCriterion>[])
          .map((row) => row.ship.id),
      <int>[4, 1, 2, 3],
    );
  });

  test('uses owned ship id ascending after every criterion ties', () {
    final projection = OwnedInventoryProjection(_multiSortFixture());

    expect(
      projection
          .shipRows(
            sortCriteria: const <ShipInventorySortCriterion>[
              ShipInventorySortCriterion(
                field: ShipInventorySortField.level,
                descending: true,
              ),
            ],
          )
          .where((row) => row.ship.level == 90)
          .map((row) => row.ship.id),
      <int>[1, 2, 3],
    );
  });

  test('sorts ships by official and instance ids', () {
    final projection = OwnedInventoryProjection(fixture());

    expect(
      projection
          .shipRows(
            sortCriteria: const <ShipInventorySortCriterion>[
              ShipInventorySortCriterion(
                field: ShipInventorySortField.officialId,
                descending: true,
              ),
            ],
          )
          .map((row) => row.ship.masterId),
      <int>[102, 101],
    );
    expect(
      projection
          .shipRows(
            sortCriteria: const <ShipInventorySortCriterion>[
              ShipInventorySortCriterion(
                field: ShipInventorySortField.instanceId,
                descending: false,
              ),
            ],
          )
          .map((row) => row.ship.id),
      <int>[1, 2],
    );
  });

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

  test('keeps matching equipment instances in one official-id group', () {
    const state = GameState(
      masterShips: <int, MasterShip>{
        101: MasterShip(id: 101, name: '大和改二', shipTypeId: 9),
      },
      masterSlotItems: <int, MasterSlotItem>{
        128: MasterSlotItem(
          id: 128,
          name: '46cm三連装砲',
          type: <int>[1, 1, 3, 3, 0],
        ),
      },
      ships: <int, OwnedShip>{
        1: OwnedShip(id: 1, masterId: 101, level: 99, slotIds: <int>[10521]),
      },
      slotItems: <int, OwnedSlotItem>{
        10521: OwnedSlotItem(
          instanceId: 10521,
          masterSlotItemId: 128,
          level: 10,
        ),
        16337: OwnedSlotItem(instanceId: 16337, masterSlotItemId: 128),
      },
    );

    final groups = OwnedInventoryProjection(state).equipmentGroups();

    expect(groups, hasLength(1));
    expect(groups.single.master.id, 128);
    expect(groups.single.total, 2);
    expect(groups.single.remaining, 1);
    expect(groups.single.wearings.single.shipName, '大和改二');
  });

  test('sorts equipment by total count rather than remaining count', () {
    const state = GameState(
      masterShips: <int, MasterShip>{
        101: MasterShip(id: 101, name: '测试舰', shipTypeId: 2),
      },
      masterSlotItems: <int, MasterSlotItem>{
        201: MasterSlotItem(id: 201, name: '多件全装备', type: <int>[1, 1, 1]),
        202: MasterSlotItem(id: 202, name: '少件未装备', type: <int>[1, 1, 1]),
      },
      ships: <int, OwnedShip>{
        1: OwnedShip(
          id: 1,
          masterId: 101,
          level: 1,
          slotIds: <int>[301, 302, 303],
        ),
      },
      slotItems: <int, OwnedSlotItem>{
        301: OwnedSlotItem(instanceId: 301, masterSlotItemId: 201),
        302: OwnedSlotItem(instanceId: 302, masterSlotItemId: 201),
        303: OwnedSlotItem(instanceId: 303, masterSlotItemId: 201),
        304: OwnedSlotItem(instanceId: 304, masterSlotItemId: 202),
      },
    );

    final groups = OwnedInventoryProjection(state).equipmentGroups(
      sortCriteria: const <EquipmentInventorySortCriterion>[
        EquipmentInventorySortCriterion(
          field: EquipmentInventorySortField.total,
          descending: true,
        ),
      ],
    );

    expect(groups.map((group) => group.master.id), <int>[201, 202]);
    expect(groups.map((group) => group.total), <int>[3, 1]);
    expect(groups.map((group) => group.remaining), <int>[0, 1]);
  });

  test('supports multi-column equipment sorting by name and official id', () {
    const state = GameState(
      masterSlotItems: <int, MasterSlotItem>{
        201: MasterSlotItem(id: 201, name: '同名', type: <int>[1]),
        202: MasterSlotItem(id: 202, name: '同名', type: <int>[1]),
        203: MasterSlotItem(id: 203, name: '另一名', type: <int>[1]),
      },
      slotItems: <int, OwnedSlotItem>{
        1: OwnedSlotItem(instanceId: 1, masterSlotItemId: 201),
        2: OwnedSlotItem(instanceId: 2, masterSlotItemId: 202),
        3: OwnedSlotItem(instanceId: 3, masterSlotItemId: 203),
      },
    );

    final groups = OwnedInventoryProjection(state).equipmentGroups(
      sortCriteria: const <EquipmentInventorySortCriterion>[
        EquipmentInventorySortCriterion(
          field: EquipmentInventorySortField.name,
          descending: true,
        ),
        EquipmentInventorySortCriterion(
          field: EquipmentInventorySortField.officialId,
          descending: false,
        ),
      ],
    );

    expect(groups.map((group) => group.master.id), <int>[201, 202, 203]);
  });

  test('sorts equipment groups by official equipment order', () {
    const masters = <int, MasterSlotItem>{
      900: MasterSlotItem(id: 900, name: 'z', type: <int>[]),
      110: MasterSlotItem(id: 110, name: 'y', sortNo: 999, type: <int>[1]),
      202: MasterSlotItem(id: 202, name: 'x', sortNo: 10, type: <int>[1, 0, 1]),
      201: MasterSlotItem(id: 201, name: 'w', sortNo: 20, type: <int>[1, 0, 1]),
      30: MasterSlotItem(id: 30, name: 'v', type: <int>[1, 0, 2]),
      40: MasterSlotItem(id: 40, name: 'u', type: <int>[1, 0, 2]),
      50: MasterSlotItem(id: 50, name: 't', sortNo: 70, type: <int>[1, 0, 3]),
      70: MasterSlotItem(id: 70, name: 's', type: <int>[1, 0, 3]),
      120: MasterSlotItem(id: 120, name: 'r', sortNo: 1, type: <int>[2, 0, 0]),
    };
    const state = GameState(
      masterSlotItems: masters,
      slotItems: <int, OwnedSlotItem>{
        1: OwnedSlotItem(id: 1, masterId: 201),
        2: OwnedSlotItem(id: 2, masterId: 120),
        3: OwnedSlotItem(id: 3, masterId: 40),
        4: OwnedSlotItem(id: 4, masterId: 900),
        5: OwnedSlotItem(id: 5, masterId: 70),
        6: OwnedSlotItem(id: 6, masterId: 202),
        7: OwnedSlotItem(id: 7, masterId: 30),
        8: OwnedSlotItem(id: 8, masterId: 110),
        9: OwnedSlotItem(id: 9, masterId: 50),
      },
    );

    expect(
      OwnedInventoryProjection(
        state,
      ).equipmentGroups().map((group) => group.master.id),
      <int>[900, 110, 202, 201, 30, 40, 50, 70, 120],
    );
  });

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

GameState _multiSortFixture() => const GameState(
  masterShipTypes: <int, MasterShipType>{2: MasterShipType(id: 2, name: '驱逐舰')},
  masterShips: <int, MasterShip>{
    101: MasterShip(id: 101, name: '测试舰', shipTypeId: 2),
  },
  ships: <int, OwnedShip>{
    4: OwnedShip(id: 4, masterId: 101, level: 100, firepower: 10, antiSub: 10),
    3: OwnedShip(id: 3, masterId: 101, level: 90, firepower: 60, antiSub: 30),
    2: OwnedShip(id: 2, masterId: 101, level: 90, firepower: 60, antiSub: 70),
    1: OwnedShip(id: 1, masterId: 101, level: 90, firepower: 50, antiSub: 40),
  },
);
