import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/fleet/land_base_air_power.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';

void main() {
  const localFighter = MasterSlotItem(
    id: 101,
    name: '雷電',
    antiAir: 10,
    interception: 4,
    antiBomber: 6,
    type: <int>[0, 0, 48],
  );

  test('sortie uses POI local-fighter interception bonus', () {
    final result = LandBaseAirPower.calculate(
      state: const GameState(
        masterSlotItems: <int, MasterSlotItem>{101: localFighter},
        slotItems: <int, OwnedSlotItem>{
          1001: OwnedSlotItem(id: 1001, masterId: 101),
        },
      ),
      base: const LandBaseState(
        areaId: 62,
        baseId: 1,
        name: '第一基地航空队',
        actionKind: 1,
        squadrons: <LandBaseSquadronState>[
          LandBaseSquadronState(
            squadronId: 1,
            state: 1,
            slotItemId: 1001,
            currentCount: 18,
            maxCount: 18,
          ),
        ],
      ),
    );

    expect(result.minimum, 67);
    expect(result.maximum, 68);
    expect(result.displayValue, '67+');
  });

  test(
    'defense applies local-fighter defense and highest recon multiplier',
    () {
      final result = LandBaseAirPower.calculate(
        state: const GameState(
          masterSlotItems: <int, MasterSlotItem>{
            101: localFighter,
            102: MasterSlotItem(
              id: 102,
              name: '彩雲',
              lineOfSight: 9,
              type: <int>[0, 0, 9],
            ),
            103: MasterSlotItem(
              id: 103,
              name: '水上偵察機',
              lineOfSight: 9,
              type: <int>[0, 0, 10],
            ),
          },
          slotItems: <int, OwnedSlotItem>{
            1001: OwnedSlotItem(id: 1001, masterId: 101),
            1002: OwnedSlotItem(id: 1002, masterId: 102),
            1003: OwnedSlotItem(id: 1003, masterId: 103),
          },
        ),
        base: const LandBaseState(
          areaId: 62,
          baseId: 2,
          name: '第二基地航空队',
          actionKind: 2,
          squadrons: <LandBaseSquadronState>[
            LandBaseSquadronState(
              squadronId: 1,
              state: 1,
              slotItemId: 1001,
              currentCount: 18,
            ),
            LandBaseSquadronState(
              squadronId: 2,
              state: 1,
              slotItemId: 1002,
              currentCount: 4,
            ),
            LandBaseSquadronState(
              squadronId: 3,
              state: 1,
              slotItemId: 1003,
              currentCount: 4,
            ),
          ],
        ),
      );

      expect(result.minimum, 143);
      expect(result.maximum, 144);
    },
  );

  test('improvement and proficiency match POI range bounds', () {
    final result = LandBaseAirPower.calculate(
      state: const GameState(
        masterSlotItems: <int, MasterSlotItem>{101: localFighter},
        slotItems: <int, OwnedSlotItem>{
          1001: OwnedSlotItem(
            id: 1001,
            masterId: 101,
            level: 10,
            proficiency: 7,
          ),
        },
      ),
      base: const LandBaseState(
        areaId: 62,
        baseId: 1,
        name: '第一基地航空队',
        actionKind: 1,
        squadrons: <LandBaseSquadronState>[
          LandBaseSquadronState(
            squadronId: 1,
            state: 1,
            slotItemId: 1001,
            currentCount: 18,
          ),
        ],
      ),
    );

    expect(result.minimum, 101);
    expect(result.maximum, 101);
    expect(result.displayValue, '101');
  });

  test('empty, relocating and unknown squadrons do not contribute', () {
    final result = LandBaseAirPower.calculate(
      state: const GameState(
        masterSlotItems: <int, MasterSlotItem>{101: localFighter},
        slotItems: <int, OwnedSlotItem>{
          1001: OwnedSlotItem(id: 1001, masterId: 101),
        },
      ),
      base: const LandBaseState(
        areaId: 62,
        baseId: 1,
        name: '第一基地航空队',
        actionKind: 1,
        squadrons: <LandBaseSquadronState>[
          LandBaseSquadronState(
            squadronId: 1,
            state: 2,
            slotItemId: 1001,
            currentCount: 18,
          ),
          LandBaseSquadronState(
            squadronId: 2,
            state: 1,
            slotItemId: 9999,
            currentCount: 18,
          ),
          LandBaseSquadronState(
            squadronId: 3,
            state: 1,
            slotItemId: 1001,
            currentCount: 0,
          ),
        ],
      ),
    );

    expect(result.minimum, 0);
    expect(result.maximum, 0);
    expect(result.displayValue, '0');
  });
}
