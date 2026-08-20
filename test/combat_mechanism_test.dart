import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/fleet/combat_mechanism.dart';
import 'package:yahagi_kancolle_browser/src/fleet/equipment_display.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';

void main() {
  group('detectShipCombatMechanisms', () {
    test('detects generic opening ASW from ship ASW and sonar', () {
      final state = _state(
        shipTypeId: 2,
        antiSub: 100,
        equipment: const <MasterSlotItem>[
          MasterSlotItem(
            id: 1,
            name: 'Type 3 Sonar',
            type: <int>[0, 0, 0, 18, 0],
          ),
        ],
      );

      expect(
        detectShipCombatMechanisms(
          state,
          state.ships[1]!,
        ).map((item) => item.label),
        contains('先制对潜'),
      );
      expect(
        detectShipCombatMechanisms(
          state,
          state.ships[1]!,
        ).singleWhere((item) => item.label == '先制对潜').effectiveShortLabel,
        '先反',
      );
      expect(
        detectShipCombatMechanisms(
          state,
          state.ships[1]!,
        ).singleWhere((item) => item.label == '先制对潜').tone,
        MechanismTone.antiSubmarine,
      );
    });

    test('does not report opening ASW below the generic threshold', () {
      final state = _state(
        shipTypeId: 2,
        antiSub: 99,
        equipment: const <MasterSlotItem>[
          MasterSlotItem(
            id: 1,
            name: 'Type 3 Sonar',
            type: <int>[0, 0, 0, 18, 0],
          ),
        ],
      );

      expect(
        detectShipCombatMechanisms(
          state,
          state.ships[1]!,
        ).map((item) => item.label),
        isNot(contains('先制对潜')),
      );
    });

    test('detects common anti-air cut-in equipment pattern', () {
      final state = _state(
        shipTypeId: 2,
        equipment: const <MasterSlotItem>[
          MasterSlotItem(
            id: 1,
            name: 'High angle gun',
            type: <int>[0, 0, 1, 16, 0],
          ),
          MasterSlotItem(
            id: 2,
            name: 'AA fire director',
            type: <int>[0, 0, 36, 0, 0],
          ),
          MasterSlotItem(
            id: 3,
            name: 'AA radar',
            antiAir: 2,
            type: <int>[0, 0, 12, 11, 0],
          ),
        ],
      );

      expect(
        detectShipCombatMechanisms(
          state,
          state.ships[1]!,
        ).map((item) => item.label),
        contains('对空 CI'),
      );
      expect(
        detectShipCombatMechanisms(
          state,
          state.ships[1]!,
        ).singleWhere((item) => item.label == '对空 CI').effectiveShortLabel,
        '对空',
      );
      expect(
        detectShipCombatMechanisms(
          state,
          state.ships[1]!,
        ).singleWhere((item) => item.label == '对空 CI').tone,
        MechanismTone.antiAir,
      );
    });

    test('detects anti-air rocket barrage only on supported ship types', () {
      final carrier = _state(
        shipTypeId: 7,
        equipment: const <MasterSlotItem>[
          MasterSlotItem(id: 274, name: '12cm 30-tube rocket launcher Kai Ni'),
        ],
      );
      final destroyer = _state(
        shipTypeId: 2,
        equipment: const <MasterSlotItem>[
          MasterSlotItem(id: 274, name: '12cm 30-tube rocket launcher Kai Ni'),
        ],
      );

      expect(
        detectShipCombatMechanisms(
          carrier,
          carrier.ships[1]!,
        ).map((item) => item.label),
        contains('对空喷进弹幕'),
      );
      final rocketMech = detectShipCombatMechanisms(
        carrier,
        carrier.ships[1]!,
      ).singleWhere((item) => item.label == '对空喷进弹幕');
      expect(rocketMech.shortLabel, '喷2');
      expect(rocketMech.effectiveShortLabel, '喷2');
      expect(rocketMech.detailedShortLabel, startsWith('喷2 '));
      expect(rocketMech.rate, isNotNull);
      expect(
        detectShipCombatMechanisms(
          destroyer,
          destroyer.ships[1]!,
        ).map((item) => item.label),
        isNot(contains('对空喷进弹幕')),
      );
    });

    test('detects multiple mechanisms simultaneously on a single ship', () {
      final multiMechShip = _state(
        masterId: 646, // Hyuuga Kai Ni
        shipTypeId: 10, // Aviation battleship
        equipment: const <MasterSlotItem>[
          MasterSlotItem(
            id: 1,
            name: 'Zuiun Model 12',
            antiSub: 6,
            type: <int>[0, 0, 11, 0, 0],
          ),
          MasterSlotItem(
            id: 2,
            name: 'High angle gun with AAFD',
            antiAir: 8,
            type: <int>[0, 0, 1, 16, 0],
          ),
          MasterSlotItem(
            id: 3,
            name: 'AA Radar',
            antiAir: 4,
            type: <int>[0, 0, 12, 11, 0],
          ),
          MasterSlotItem(
            id: 274,
            name: '12cm 30-tube rocket launcher Kai Ni',
          ),
        ],
      );

      final mechanisms = detectShipCombatMechanisms(
        multiMechShip,
        multiMechShip.ships[1]!,
      );

      final labels = mechanisms.map((m) => m.label).toList();
      final shortLabels = mechanisms.map((m) => m.effectiveShortLabel).toList();
      expect(labels, containsAll(<String>['先制对潜', '对空 CI', '对空喷进弹幕']));
      expect(shortLabels, containsAll(<String>['先反', '对空', '喷2']));
      final detailedLabels = mechanisms.map((m) => m.detailedShortLabel).toList();
      expect(detailedLabels.any((s) => s.startsWith('喷2 ')), isTrue);
    });

    test('detects night carrier air attack when equipped with night personnel and night aircraft', () {
      final nightCarrierState = _state(
        masterId: 432, // Kaga Kai (Standard Carrier)
        shipTypeId: 11,
        equipment: const <MasterSlotItem>[
          MasterSlotItem(
            id: 258,
            name: 'Night Operation Aviation Personnel',
            type: <int>[0, 0, 45, 46, 0],
          ),
          MasterSlotItem(
            id: 254,
            name: 'F6F-3N',
            type: <int>[0, 0, 6, 45, 0],
          ),
        ],
      );

      final mechanisms = detectShipCombatMechanisms(
        nightCarrierState,
        nightCarrierState.ships[1]!,
      );

      expect(mechanisms.any((m) => m.label == '空母夜间航空攻击'), isTrue);
      expect(mechanisms.firstWhere((m) => m.label == '空母夜间航空攻击').effectiveShortLabel, '夜袭');
    });

    test('detects night carrier air attack on native night carriers like Saratoga Mk.II', () {
      final saratogaState = _state(
        masterId: 545, // Saratoga Mk.II
        shipTypeId: 11,
        equipment: const <MasterSlotItem>[
          MasterSlotItem(
            id: 254,
            name: 'F6F-3N',
            type: <int>[0, 0, 6, 45, 0],
          ),
        ],
      );

      final mechanisms = detectShipCombatMechanisms(
        saratogaState,
        saratogaState.ships[1]!,
      );

      expect(mechanisms.any((m) => m.label == '空母夜间航空攻击'), isTrue);
      expect(mechanisms.firstWhere((m) => m.label == '空母夜间航空攻击').effectiveShortLabel, '夜袭');
    });
  });

  test('detects Nelson Touch as a named fleet special attack', () {
    final masters = <int, MasterShip>{
      100: const MasterShip(
        id: 100,
        name: 'Nelson改',
        shipTypeId: 9,
        classTypeId: 88,
      ),
      for (var id = 101; id <= 105; id++)
        id: MasterShip(id: id, name: 'Ship $id', shipTypeId: 2),
    };
    final ships = <int, OwnedShip>{
      for (var id = 1; id <= 6; id++)
        id: OwnedShip(
          id: id,
          masterId: id == 1 ? 100 : 99 + id,
          level: 80,
          currentHp: 40,
          maxHp: 50,
        ),
    };
    final state = GameState(
      masterShips: masters,
      ships: ships,
      fleets: const <Fleet>[
        Fleet(id: 1, name: 'First Fleet', shipIds: <int>[1, 2, 3, 4, 5, 6]),
      ],
    );

    final result = detectFleetSpecialAttack(state, state.fleets.first);

    expect(result?.label, 'Nelson Touch');
    expect(result?.shortLabel, '特攻');
    expect(result?.effectiveShortLabel, '特攻');
    expect(result?.detailedShortLabel, startsWith('特攻 '));
    expect(result?.rate, isNotNull);
    expect(result?.label, isNot(contains('可发动')));
  });

  test('detects submarine fleet attack from submarine tender and submarines', () {
    final masters = <int, MasterShip>{
      100: const MasterShip(
        id: 100,
        name: 'Taigei',
        shipTypeId: 20, // Submarine Tender
      ),
      101: const MasterShip(id: 101, name: 'I-19', shipTypeId: 13), // SS
      102: const MasterShip(id: 102, name: 'I-58', shipTypeId: 14), // SSV
      103: const MasterShip(id: 103, name: 'Yukikaze', shipTypeId: 2), // DD
    };
    final ships = <int, OwnedShip>{
      1: const OwnedShip(
        id: 1,
        masterId: 100,
        level: 50,
        currentHp: 40,
        maxHp: 45,
      ),
      2: const OwnedShip(
        id: 2,
        masterId: 101,
        level: 70,
        currentHp: 18,
        maxHp: 20,
      ),
      3: const OwnedShip(
        id: 3,
        masterId: 102,
        level: 70,
        currentHp: 18,
        maxHp: 20,
      ),
      4: const OwnedShip(
        id: 4,
        masterId: 103,
        level: 80,
        currentHp: 30,
        maxHp: 30,
      ),
    };
    final state = GameState(
      masterShips: masters,
      ships: ships,
      fleets: const <Fleet>[
        Fleet(id: 1, name: 'Submarine Fleet', shipIds: <int>[1, 2, 3, 4]),
      ],
    );

    final result = detectFleetSpecialAttack(state, state.fleets.first);

    expect(result?.label, '潜水舰队攻击');
    expect(result?.effectiveShortLabel, '特攻');
  });
}

GameState _state({
  int masterId = 100,
  required int shipTypeId,
  int antiSub = 0,
  required List<MasterSlotItem> equipment,
}) {
  final slotItems = <int, OwnedSlotItem>{};
  final masterSlotItems = <int, MasterSlotItem>{};
  final slotIds = <int>[];
  for (var index = 0; index < equipment.length; index++) {
    final ownedId = index + 10;
    slotIds.add(ownedId);
    slotItems[ownedId] = OwnedSlotItem(
      id: ownedId,
      masterId: equipment[index].id,
    );
    masterSlotItems[equipment[index].id] = equipment[index];
  }
  return GameState(
    masterShips: <int, MasterShip>{
      masterId: MasterShip(
        id: masterId,
        name: 'Test ship',
        shipTypeId: shipTypeId,
      ),
    },
    ships: <int, OwnedShip>{
      1: OwnedShip(
        id: 1,
        masterId: masterId,
        level: 80,
        antiSub: antiSub,
        currentHp: 30,
        maxHp: 30,
        slotIds: slotIds,
      ),
    },
    masterSlotItems: masterSlotItems,
    slotItems: slotItems,
  );
}
