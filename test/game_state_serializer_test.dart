import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_serializer.dart';

void main() {
  test(
    'ship experience and expansion-slot state survive cache serialization',
    () {
      const state = GameState(
        ships: <int, OwnedShip>{
          7: OwnedShip(
            id: 7,
            masterId: 101,
            level: 51,
            experience: 45000,
            nextExperience: 1200,
            extraSlotId: 503,
          ),
        },
      );

      final restored = GameStateSerializer.deserialize(
        GameStateSerializer.serialize(state),
      );

      expect(restored.ships[7]?.experience, 45000);
      expect(restored.ships[7]?.nextExperience, 1200);
      expect(restored.ships[7]?.extraSlotId, 503);
    },
  );

  test('new-ship identity metadata survives cache serialization', () {
    const state = GameState(
      memberId: 90001,
      masterShips: <int, MasterShip>{
        1: MasterShip(id: 1, name: '夕立', shipTypeId: 2, afterShipId: 2),
      },
      masterSlotItemTypes: <int, String>{1: '小口径主炮'},
    );

    final restored = GameStateSerializer.deserialize(
      GameStateSerializer.serialize(state),
    );

    expect(restored.memberId, 90001);
    expect(restored.masterShips[1]?.afterShipId, 2);
    expect(restored.masterSlotItemTypes[1], '小口径主炮');
  });

  test('fleet summary data survives cache serialization', () {
    const state = GameState(
      serverOrigin: 'https://w01y.kancolle-server.com',
      hasMasterData: true,
      hasPortData: true,
      masterShipTypes: <int, MasterShipType>{
        2: MasterShipType(id: 2, name: '駆逐艦', equipTypeIds: <int>{1, 2, 3}),
      },
      masterShips: <int, MasterShip>{
        1: MasterShip(
          id: 1,
          name: '夕立',
          shipTypeId: 2,
          sortNo: 101,
          classTypeId: 12,
          speed: 10,
          range: 2,
          maxFuel: 15,
          maxAmmo: 20,
          slotCount: 2,
          slotCapacities: <int>[12, 12],
          buildTimeMinutes: 22,
          baseAntiSub: 30,
          equipTypeIds: <int>{1, 2, 3},
          portraitFileName: '0001',
          portraitVersion: '7',
        ),
      },
      ships: <int, OwnedShip>{
        101: OwnedShip(
          id: 101,
          masterId: 1,
          level: 98,
          currentHp: 29,
          maxHp: 31,
          condition: 85,
          currentFuel: 13,
          currentAmmo: 17,
          nextExperience: 1234,
          firepower: 59,
          firepowerMax: 63,
          torpedo: 88,
          torpedoMax: 93,
          antiAir: 62,
          antiAirMax: 67,
          antiSub: 71,
          lineOfSight: 42,
          armor: 49,
          armorMax: 52,
          evasion: 81,
          luck: 25,
          luckMax: 59,
          speed: 15,
          range: 3,
          slotIds: <int>[1001, -1],
          onSlot: <int>[12, 0],
          extraSlotId: 1002,
          repairDurationMilliseconds: 120000,
          repairFuelCost: 3,
          repairSteelCost: 4,
          locked: true,
        ),
      },
      masterSlotItems: <int, MasterSlotItem>{
        201: MasterSlotItem(
          id: 201,
          name: '局地戦闘機',
          antiAir: 12,
          type: <int>[0, 0, 48, 44],
          interception: 3,
          antiBomber: 2,
          distance: 4,
          resourceVersion: '5',
        ),
      },
      slotItems: <int, OwnedSlotItem>{
        1001: OwnedSlotItem(
          instanceId: 1001,
          masterSlotItemId: 201,
          level: 6,
          proficiency: 7,
          locked: true,
        ),
      },
    );

    final restored = GameStateSerializer.deserialize(
      GameStateSerializer.serialize(state),
    );

    expect(restored.serverOrigin, state.serverOrigin);
    expect(restored.hasMasterData, isTrue);
    expect(restored.hasPortData, isTrue);
    expect(restored.masterShipTypes[2]?.name, '駆逐艦');
    expect(restored.masterShipTypes[2]?.equipTypeIds, <int>{1, 2, 3});
    expect(restored.masterShips[1]?.speed, 10);
    expect(restored.masterShips[1]?.maxFuel, 15);
    expect(restored.masterShips[1]?.maxAmmo, 20);
    expect(restored.masterShips[1]?.slotCapacities, <int>[12, 12]);
    expect(restored.masterShips[1]?.equipTypeIds, <int>{1, 2, 3});
    expect(restored.masterShips[1]?.portraitFileName, '0001');
    expect(restored.masterShips[1]?.portraitVersion, '7');
    expect(restored.ships[101]?.level, 98);
    expect(restored.ships[101]?.currentFuel, 13);
    expect(restored.ships[101]?.currentAmmo, 17);
    expect(restored.ships[101]?.speed, 15);
    expect(restored.ships[101]?.range, 3);
    expect(restored.ships[101]?.slotIds, <int>[1001, -1]);
    expect(restored.ships[101]?.onSlot, <int>[12, 0]);
    expect(restored.ships[101]?.extraSlotId, 1002);
    expect(restored.ships[101]?.locked, isTrue);
    expect(restored.masterSlotItems[201]?.type, <int>[0, 0, 48, 44]);
    expect(restored.masterSlotItems[201]?.antiAir, 12);
    expect(restored.masterSlotItems[201]?.interception, 3);
    expect(restored.masterSlotItems[201]?.antiBomber, 2);
    expect(restored.masterSlotItems[201]?.distance, 4);
    expect(restored.masterSlotItems[201]?.resourceVersion, '5');
    expect(restored.slotItems[1001]?.masterSlotItemId, 201);
    expect(restored.slotItems[1001]?.level, 6);
    expect(restored.slotItems[1001]?.proficiency, 7);
    expect(restored.slotItems[1001]?.locked, isTrue);
  });

  test('equipment compatibility master data survives cache serialization', () {
    const state = GameState(
      masterShipTypes: <int, MasterShipType>{
        2: MasterShipType(id: 2, name: '驱逐舰', equipTypeIds: <int>{1, 27}),
      },
      masterShips: <int, MasterShip>{
        100: MasterShip(
          id: 100,
          name: '测试舰改',
          shipTypeId: 2,
          classTypeId: 47,
          equipTypeIds: <int>{1, 27},
          limitedEquipmentIdsByType: <int, Set<int>>{
            27: <int>{268},
          },
        ),
      },
      masterSlotItems: <int, MasterSlotItem>{
        268: MasterSlotItem(
          id: 268,
          name: '北方迷彩（＋北方装备）',
          sortNo: 268,
          type: <int>[3, 5, 27, 23, 0],
        ),
      },
      expansionSlotEquipmentTypeIds: <int>{21, 27},
      expansionSlotLimitsByShipId: <int, Set<int>>{
        100: <int>{27},
      },
      expansionSlotSpecialRules: <int, ExpansionSlotSpecialRule>{
        268: ExpansionSlotSpecialRule(
          equipmentMasterId: 268,
          shipMasterIds: <int>{100},
          classTypeIds: <int>{47},
          shipTypeIds: <int>{2},
          minimumImprovement: 7,
        ),
      },
      hasEquipmentCompatibilityData: true,
    );

    final restored = GameStateSerializer.deserialize(
      GameStateSerializer.serialize(state),
    );

    expect(restored.masterShipTypes[2]?.equipTypeIds, <int>{1, 27});
    expect(restored.masterShips[100]?.classTypeId, 47);
    expect(restored.masterShips[100]?.equipTypeIds, <int>{1, 27});
    expect(restored.masterShips[100]?.limitedEquipmentIdsByType[27], <int>{
      268,
    });
    expect(restored.masterSlotItems[268]?.type, <int>[3, 5, 27, 23, 0]);
    expect(restored.expansionSlotEquipmentTypeIds, <int>{21, 27});
    expect(restored.expansionSlotLimitsByShipId[100], <int>{27});
    expect(restored.expansionSlotSpecialRules[268]?.shipMasterIds, <int>{100});
    expect(restored.expansionSlotSpecialRules[268]?.minimumImprovement, 7);
    expect(restored.hasEquipmentCompatibilityData, isTrue);
  });

  test('old cache defaults equipment compatibility rules to empty', () {
    final restored = GameStateSerializer.deserialize('{"admiralLevel":120}');

    expect(restored.expansionSlotEquipmentTypeIds, isEmpty);
    expect(restored.expansionSlotLimitsByShipId, isEmpty);
    expect(restored.expansionSlotSpecialRules, isEmpty);
    expect(restored.hasEquipmentCompatibilityData, isFalse);
  });

  test('land-base cache keeps identity but drops sortie-only hp', () {
    const state = GameState(
      landBases: <LandBaseState>[
        LandBaseState(
          areaId: 47,
          baseId: 1,
          name: '第一基地航空队',
          actionKind: 1,
          maxHp: 200,
          currentHp: 152,
          lastRaidDamage: 48,
        ),
      ],
    );

    final restored = GameStateSerializer.deserialize(
      GameStateSerializer.serialize(state),
    );

    expect(restored.landBases, hasLength(1));
    expect(restored.landBases.single.areaId, 47);
    expect(restored.landBases.single.baseId, 1);
    expect(restored.landBases.single.name, '第一基地航空队');
    expect(restored.landBases.single.actionKind, 1);
    expect(restored.landBases.single.maxHp, isNull);
    expect(restored.landBases.single.currentHp, isNull);
    expect(restored.landBases.single.lastRaidDamage, 0);
  });

  test('land-base cache keeps distance and squadron state', () {
    const state = GameState(
      landBases: <LandBaseState>[
        LandBaseState(
          areaId: 62,
          baseId: 1,
          name: '第一基地航空队',
          actionKind: 1,
          distanceBase: 7,
          distanceBonus: 1,
          squadrons: <LandBaseSquadronState>[
            LandBaseSquadronState(
              squadronId: 1,
              state: 1,
              slotItemId: 101,
              currentCount: 12,
              maxCount: 18,
              condition: 3,
            ),
          ],
        ),
      ],
      masterMapAreas: <int, String>{62: '反击！第三十一战队的战斗'},
    );

    final restored = GameStateSerializer.deserialize(
      GameStateSerializer.serialize(state),
    );

    expect(restored.landBases.single.effectiveDistance, 8);
    expect(restored.landBases.single.squadrons.single.currentCount, 12);
    expect(restored.landBases.single.squadrons.single.condition, 3);
    expect(restored.masterMapAreas[62], '反击！第三十一战队的战斗');
  });

  test('old cache without land bases remains compatible', () {
    final restored = GameStateSerializer.deserialize('{"admiralLevel":120}');

    expect(restored.admiralLevel, 120);
    expect(restored.landBases, isEmpty);
  });

  test('special item counts survive cache serialization', () {
    const state = GameState(
      useItems: <int, int>{54: 3, 68: 17},
      hasUseItemData: true,
    );

    final restored = GameStateSerializer.deserialize(
      GameStateSerializer.serialize(state),
    );

    expect(restored.hasUseItemData, isTrue);
    expect(restored.useItemCount(54), 3);
    expect(restored.useItemCount(68), 17);
  });

  test('selected map difficulties survive cache serialization', () {
    const state = GameState(mapDifficulties: <int, int>{6202: 3});

    final restored = GameStateSerializer.deserialize(
      GameStateSerializer.serialize(state),
    );

    expect(restored.mapDifficulty(62, 2), 3);
  });

  test('F96 completion prerequisites survive cache serialization', () {
    const state = GameState(
      furnitureCoins: 4000,
      hasFurnitureCoinData: true,
      quests: <int, GameQuest>{
        1101: GameQuest(
          id: 1101,
          title: 'F96',
          detail: '',
          category: 6,
          type: 4,
          state: 2,
          progressFlag: 2,
          progressCurrent: 8,
          progressRequired: 8,
          localCompletionVerified: false,
        ),
      },
    );

    final restored = GameStateSerializer.deserialize(
      GameStateSerializer.serialize(state),
    );

    expect(restored.furnitureCoins, 4000);
    expect(restored.hasFurnitureCoinData, isTrue);
    expect(restored.quests[1101]?.progressCurrent, 8);
    expect(restored.quests[1101]?.progressRequired, 8);
    expect(restored.quests[1101]?.localCompletionVerified, isFalse);
    expect(restored.quests[1101]?.isCompleted, isFalse);
  });

  test('old F96 cache without new fields restores safely', () {
    final restored = GameStateSerializer.deserialize(
      '{"quests":{"1101":{"title":"F96","detail":"",'
      '"category":6,"type":4,"state":2,"progressFlag":2,'
      '"progressCurrent":8,"progressRequired":8}}}',
    );

    expect(restored.furnitureCoins, 0);
    expect(restored.hasFurnitureCoinData, isFalse);
    expect(restored.quests[1101]?.localCompletionVerified, isFalse);
    expect(restored.quests[1101]?.isCompleted, isFalse);
  });

  test('legacy ordinary quest keeps exact-progress completion semantics', () {
    final restored = GameStateSerializer.deserialize(
      '{"quests":{"503":{"title":"repair quest","detail":"",'
      '"category":5,"type":1,"state":2,"progressFlag":2,'
      '"progressCurrent":5,"progressRequired":5}}}',
    );

    expect(restored.quests[503]?.progressCurrent, 5);
    expect(restored.quests[503]?.progressRequired, 5);
    expect(restored.quests[503]?.localCompletionVerified, isNull);
    expect(restored.quests[503]?.isCompleted, isTrue);
  });

  for (final entry in <String, String>{
    'null': 'null',
    'wrong type': '"not-a-bool"',
  }.entries) {
    test('corrupt F96 verification (${entry.key}) restores safely', () {
      final restored = GameStateSerializer.deserialize(
        '{"quests":{"1101":{"title":"F96","detail":"",'
        '"category":6,"type":4,"state":2,"progressFlag":2,'
        '"progressCurrent":8,"progressRequired":8,'
        '"localCompletionVerified":${entry.value}}}}',
      );

      expect(restored.quests[1101]?.localCompletionVerified, isFalse);
      expect(restored.quests[1101]?.isCompleted, isFalse);
    });

    test('corrupt ordinary verification (${entry.key}) keeps semantics', () {
      final restored = GameStateSerializer.deserialize(
        '{"quests":{"503":{"title":"repair quest","detail":"",'
        '"category":5,"type":1,"state":2,"progressFlag":2,'
        '"progressCurrent":5,"progressRequired":5,'
        '"localCompletionVerified":${entry.value}}}}',
      );

      expect(restored.quests[503]?.localCompletionVerified, isNull);
      expect(restored.quests[503]?.isCompleted, isTrue);
    });
  }
}
