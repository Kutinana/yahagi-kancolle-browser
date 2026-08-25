import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_serializer.dart';

void main() {
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
