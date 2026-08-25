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

  test('POI jet fighter type contributes with fighter proficiency', () {
    final result = _oneSlot(
      master: const MasterSlotItem(
        id: 548,
        name: '震電改三',
        antiAir: 17,
        type: <int>[0, 0, 56],
      ),
      count: 18,
      proficiency: 7,
    );

    expect((result.minimum, result.maximum), (97, 97));
  });

  test('POI heavy bomber improvement uses half square root stars', () {
    final result = _oneSlot(
      master: const MasterSlotItem(
        id: 396,
        name: '深山改',
        antiAir: 2,
        type: <int>[0, 0, 53],
      ),
      count: 18,
      level: 10,
      actionKind: 1,
    );

    expect((result.minimum, result.maximum), (15, 16));
  });

  test('POI land attacker improvement uses half square root stars', () {
    final result = _oneSlot(
      master: const MasterSlotItem(
        id: 186,
        name: '一式陸攻 三四型',
        antiAir: 4,
        bombing: 11,
        type: <int>[0, 0, 47],
      ),
      count: 18,
      level: 10,
      proficiency: 7,
      actionKind: 1,
    );

    expect((result.minimum, result.maximum), (26, 27));
  });

  test('POI interceptor improvement applies below four anti-air', () {
    final result = _oneSlot(
      master: const MasterSlotItem(
        id: 352,
        name: '秋水',
        antiAir: 3,
        antiBomber: 9,
        type: <int>[0, 0, 48],
      ),
      count: 18,
      level: 10,
      actionKind: 1,
    );

    expect((result.minimum, result.maximum), (21, 22));
  });

  test('POI land recon contributes its own air power on defense', () {
    final result = _oneSlot(
      master: const MasterSlotItem(
        id: 311,
        name: '二式陸上偵察機',
        antiAir: 3,
        lineOfSight: 8,
        type: <int>[0, 0, 49],
      ),
      count: 4,
      actionKind: 2,
    );

    expect((result.minimum, result.maximum), (7, 7));
  });

  test('POI skilled land recon uses 1.24 defense multiplier', () {
    final result = _slots(
      masters: const <MasterSlotItem>[
        MasterSlotItem(
          id: 352,
          name: '秋水',
          antiAir: 3,
          antiBomber: 9,
          type: <int>[0, 0, 48],
        ),
        MasterSlotItem(
          id: 312,
          name: '二式陸上偵察機(熟練)',
          antiAir: 3,
          lineOfSight: 9,
          type: <int>[0, 0, 49],
        ),
      ],
      counts: const <int>[18, 4],
      actionKind: 2,
    );

    expect((result.minimum, result.maximum), (117, 119));
  });

  test('POI special fighter improvement uses 0.3 per star', () {
    final result = _oneSlot(
      master: const MasterSlotItem(
        id: 486,
        name: '零式艦戦64型(制空戦闘機仕様)',
        antiAir: 9,
        type: <int>[0, 0, 6],
      ),
      count: 18,
      level: 10,
    );

    expect((result.minimum, result.maximum), (50, 51));
  });

  test('POI plain dive bomber improvement adds no air power', () {
    final plain = _oneSlot(
      master: const MasterSlotItem(
        id: 319,
        name: '普通舰爆',
        antiAir: 4,
        bombing: 12,
        type: <int>[0, 0, 7],
      ),
      count: 18,
    );
    final improved = _oneSlot(
      master: const MasterSlotItem(
        id: 319,
        name: '普通舰爆',
        antiAir: 4,
        bombing: 12,
        type: <int>[0, 0, 7],
      ),
      count: 18,
      level: 10,
    );

    expect(
      (improved.minimum, improved.maximum),
      (plain.minimum, plain.maximum),
    );
  });

  test('POI carrier recon at sight eight uses 1.25 defense multiplier', () {
    final result = _slots(
      masters: const <MasterSlotItem>[
        MasterSlotItem(
          id: 20,
          name: '零式艦戦52型',
          antiAir: 10,
          type: <int>[0, 0, 6],
        ),
        MasterSlotItem(
          id: 102,
          name: '彩雲',
          lineOfSight: 8,
          type: <int>[0, 0, 9],
        ),
      ],
      counts: const <int>[18, 4],
      actionKind: 2,
    );

    expect((result.minimum, result.maximum), (52, 53));
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

LandBaseAirPowerResult _oneSlot({
  required MasterSlotItem master,
  required int count,
  int level = 0,
  int proficiency = 0,
  int actionKind = 0,
}) => _slots(
  masters: <MasterSlotItem>[master],
  counts: <int>[count],
  levels: <int>[level],
  proficiencies: <int>[proficiency],
  actionKind: actionKind,
);

LandBaseAirPowerResult _slots({
  required List<MasterSlotItem> masters,
  required List<int> counts,
  List<int>? levels,
  List<int>? proficiencies,
  required int actionKind,
}) {
  final owned = <int, OwnedSlotItem>{};
  final squadrons = <LandBaseSquadronState>[];
  for (var index = 0; index < masters.length; index++) {
    final instanceId = 1001 + index;
    owned[instanceId] = OwnedSlotItem(
      instanceId: instanceId,
      masterSlotItemId: masters[index].id,
      level: levels?[index] ?? 0,
      proficiency: proficiencies?[index] ?? 0,
    );
    squadrons.add(
      LandBaseSquadronState(
        squadronId: index + 1,
        state: 1,
        slotItemId: instanceId,
        currentCount: counts[index],
      ),
    );
  }
  return LandBaseAirPower.calculate(
    state: GameState(
      masterSlotItems: <int, MasterSlotItem>{
        for (final master in masters) master.id: master,
      },
      slotItems: owned,
    ),
    base: LandBaseState(
      areaId: 62,
      baseId: 1,
      name: '测试基地',
      actionKind: actionKind,
      squadrons: squadrons,
    ),
  );
}
