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

    test('accepts both small and large sonar icons for generic ship types', () {
      for (final shipTypeId in const <int>[2, 3, 4, 21, 22]) {
        for (final sonarIcon in const <int>[17, 18]) {
          final state = _state(
            shipTypeId: shipTypeId,
            antiSub: 100,
            equipment: <MasterSlotItem>[_sonar(icon: sonarIcon)],
          );

          expect(
            _hasOpeningAsw(state),
            isTrue,
            reason: 'ship type $shipTypeId should accept sonar icon $sonarIcon',
          );
        }
      }
    });

    test('applies both coastal defense ship thresholds', () {
      final sonarThreshold = _state(
        shipTypeId: 1,
        antiSub: 60,
        equipment: <MasterSlotItem>[_sonar(icon: 17)],
      );
      final equipmentThreshold = _state(
        shipTypeId: 1,
        antiSub: 75,
        equipment: const <MasterSlotItem>[
          MasterSlotItem(id: 2, name: 'ASW radar', antiSub: 4),
        ],
      );
      final belowThreshold = _state(
        shipTypeId: 1,
        antiSub: 75,
        equipment: const <MasterSlotItem>[
          MasterSlotItem(id: 2, name: 'ASW radar', antiSub: 3),
        ],
      );

      expect(_hasOpeningAsw(sonarThreshold), isTrue);
      expect(_hasOpeningAsw(equipmentThreshold), isTrue);
      expect(_hasOpeningAsw(belowThreshold), isFalse);
    });

    test('excludes Norge and Eidsvold from generic coastal defense rules', () {
      for (final name in const <String>['Norge', 'Eidsvold']) {
        final state = _state(
          masterName: name,
          shipTypeId: 1,
          antiSub: 100,
          equipment: <MasterSlotItem>[_sonar(icon: 17)],
        );

        expect(_hasOpeningAsw(state), isFalse, reason: name);
      }
    });

    test('keeps unconditional opening ASW ships unconditional', () {
      final state = _state(
        masterId: 141, // Isuzu Kai Ni
        shipTypeId: 3,
        equipment: const <MasterSlotItem>[],
      );

      expect(_hasOpeningAsw(state), isTrue);
    });

    test('applies ordinary light carrier 50 and 65 ASW rules', () {
      final aswAircraft = const MasterSlotItem(
        id: 10,
        name: 'ASW torpedo bomber',
        antiSub: 7,
        type: <int>[0, 0, 8, 0, 0],
      );
      final at50 = _state(
        shipTypeId: 7,
        antiSub: 50,
        equipment: <MasterSlotItem>[_sonar(icon: 17), aswAircraft],
      );
      final at65 = _state(
        shipTypeId: 7,
        antiSub: 65,
        equipment: <MasterSlotItem>[aswAircraft],
      );
      final below65WithoutSonar = _state(
        shipTypeId: 7,
        antiSub: 64,
        equipment: <MasterSlotItem>[aswAircraft],
      );

      expect(_hasOpeningAsw(at50), isTrue);
      expect(_hasOpeningAsw(at65), isTrue);
      expect(_hasOpeningAsw(below65WithoutSonar), isFalse);
    });

    test('applies ordinary light carrier 100 ASW sonar rule', () {
      for (final aircraftType in const <int>[7, 8]) {
        final state = _state(
          shipTypeId: 7,
          antiSub: 100,
          equipment: <MasterSlotItem>[
            _sonar(icon: 18),
            MasterSlotItem(
              id: 20 + aircraftType,
              name: 'ASW carrier aircraft',
              antiSub: 1,
              type: <int>[0, 0, aircraftType, 0, 0],
            ),
          ],
        );

        expect(_hasOpeningAsw(state), isTrue, reason: 'type $aircraftType');
      }
    });

    test(
      'requires original aircraft capacity but ignores current plane count',
      () {
        final equipment = <MasterSlotItem>[
          _sonar(icon: 17),
          const MasterSlotItem(
            id: 10,
            name: 'ASW torpedo bomber',
            antiSub: 7,
            type: <int>[0, 0, 8, 0, 0],
          ),
        ];
        final zeroOriginalCapacity = _state(
          shipTypeId: 7,
          antiSub: 50,
          equipment: equipment,
          slotCapacities: const <int>[0, 0],
        );
        final planesCurrentlyDepleted = _state(
          shipTypeId: 7,
          antiSub: 50,
          equipment: equipment,
          slotCapacities: const <int>[0, 8],
          onSlot: const <int>[0, 0],
        );

        expect(_hasOpeningAsw(zeroOriginalCapacity), isFalse);
        expect(_hasOpeningAsw(planesCurrentlyDepleted), isTrue);
      },
    );

    test('excludes attack carriers from ordinary CVL rules', () {
      for (final masterId in const <int>[508, 509]) {
        final state = _state(
          masterId: masterId,
          shipTypeId: 7,
          antiSub: 65,
          equipment: const <MasterSlotItem>[
            MasterSlotItem(
              id: 10,
              name: 'ASW torpedo bomber',
              antiSub: 7,
              type: <int>[0, 0, 8, 0, 0],
            ),
          ],
        );

        expect(_hasOpeningAsw(state), isFalse, reason: 'ship $masterId');
      }
    });

    test('detects escort carrier rule for Taiyou Kai and Kaga Kai Ni Go', () {
      for (final ship in const <(int, int)>[(380, 7), (646, 11)]) {
        final state = _state(
          masterId: ship.$1,
          shipTypeId: ship.$2,
          equipment: const <MasterSlotItem>[
            MasterSlotItem(
              id: 11,
              name: 'ASW patrol aircraft',
              antiSub: 1,
              type: <int>[0, 0, 26, 0, 0],
            ),
          ],
          slotCapacities: const <int>[1],
        );

        expect(_hasOpeningAsw(state), isTrue, reason: 'ship ${ship.$1}');
      }
    });

    test('applies Fusou-class Kai Ni special rule', () {
      for (final masterId in const <int>[411, 412]) {
        final state = _state(
          masterId: masterId,
          shipTypeId: 10,
          antiSub: 100,
          equipment: const <MasterSlotItem>[
            MasterSlotItem(
              id: 132,
              name: 'Type 0 Sonar',
              type: <int>[0, 0, 14, 18, 0],
            ),
            MasterSlotItem(
              id: 30,
              name: 'Depth charge projector',
              type: <int>[0, 0, 15, 0, 0],
            ),
          ],
        );

        expect(_hasOpeningAsw(state), isTrue, reason: 'ship $masterId');
      }
    });

    test('applies Kumano Maru special rule', () {
      for (final masterId in const <int>[943, 948]) {
        final state = _state(
          masterId: masterId,
          shipTypeId: 17,
          antiSub: 100,
          equipment: <MasterSlotItem>[
            _sonar(icon: 17),
            const MasterSlotItem(
              id: 31,
              name: 'ASW dive bomber',
              antiSub: 1,
              type: <int>[0, 0, 7, 0, 0],
            ),
          ],
        );

        expect(_hasOpeningAsw(state), isTrue, reason: 'ship $masterId');
      }
    });

    test('applies Yamato Kai Ni Juu and Shinshuu Maru Kai special rule', () {
      for (final ship in const <(int, int)>[(916, 10), (626, 17)]) {
        final state = _state(
          masterId: ship.$1,
          shipTypeId: ship.$2,
          antiSub: 100,
          equipment: <MasterSlotItem>[
            _sonar(icon: 18),
            const MasterSlotItem(
              id: 32,
              name: 'Autogyro',
              antiSub: 1,
              type: <int>[0, 0, 25, 0, 0],
            ),
          ],
        );

        expect(_hasOpeningAsw(state), isTrue, reason: 'ship ${ship.$1}');
      }
    });

    test('detects Hyuuga Kai Ni with one S-51J series aircraft', () {
      for (final equipmentId in const <int>[326, 327]) {
        final state = _state(
          masterId: 554,
          shipTypeId: 10,
          equipment: <MasterSlotItem>[
            MasterSlotItem(
              id: equipmentId,
              name: 'S-51J series',
              antiSub: 12,
              type: const <int>[0, 0, 25, 0, 0],
            ),
          ],
        );

        expect(_hasOpeningAsw(state), isTrue, reason: 'equipment $equipmentId');
      }
    });

    test('requires two ordinary autogyros for Hyuuga Kai Ni', () {
      const autogyro1 = MasterSlotItem(
        id: 40,
        name: 'Ka Type Observation Autogyro',
        type: <int>[0, 0, 25, 0, 0],
      );
      const autogyro2 = MasterSlotItem(
        id: 41,
        name: 'O Type Observation Autogyro Kai',
        type: <int>[0, 0, 25, 0, 0],
      );
      final one = _state(
        masterId: 554,
        shipTypeId: 10,
        equipment: const <MasterSlotItem>[autogyro1],
      );
      final two = _state(
        masterId: 554,
        shipTypeId: 10,
        equipment: const <MasterSlotItem>[autogyro1, autogyro2],
      );

      expect(_hasOpeningAsw(one), isFalse);
      expect(_hasOpeningAsw(two), isTrue);
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
        masterId: 554, // Hyuuga Kai Ni
        shipTypeId: 10, // Aviation battleship
        equipment: const <MasterSlotItem>[
          MasterSlotItem(
            id: 326,
            name: 'S-51J',
            antiSub: 12,
            type: <int>[0, 0, 25, 0, 0],
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
          MasterSlotItem(id: 274, name: '12cm 30-tube rocket launcher Kai Ni'),
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
      final detailedLabels = mechanisms
          .map((m) => m.detailedShortLabel)
          .toList();
      expect(detailedLabels.any((s) => s.startsWith('喷2 ')), isTrue);
    });

    test(
      'detects night carrier air attack when equipped with night personnel and night aircraft',
      () {
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
        expect(
          mechanisms
              .firstWhere((m) => m.label == '空母夜间航空攻击')
              .effectiveShortLabel,
          '夜袭',
        );
      },
    );

    test(
      'detects night carrier air attack on native night carriers like Saratoga Mk.II',
      () {
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
        expect(
          mechanisms
              .firstWhere((m) => m.label == '空母夜间航空攻击')
              .effectiveShortLabel,
          '夜袭',
        );
      },
    );
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

  test(
    'detects submarine fleet attack from submarine tender and submarines',
    () {
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
    },
  );
}

GameState _state({
  int masterId = 100,
  String masterName = 'Test ship',
  required int shipTypeId,
  int antiSub = 0,
  required List<MasterSlotItem> equipment,
  List<int>? slotCapacities,
  List<int>? onSlot,
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
        name: masterName,
        shipTypeId: shipTypeId,
        slotCapacities: slotCapacities ?? List<int>.filled(equipment.length, 1),
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
        onSlot: onSlot ?? List<int>.filled(equipment.length, 1),
      ),
    },
    masterSlotItems: masterSlotItems,
    slotItems: slotItems,
  );
}

MasterSlotItem _sonar({required int icon}) => MasterSlotItem(
  id: 1000 + icon,
  name: 'Sonar',
  type: <int>[0, 0, 14, icon, 0],
);

bool _hasOpeningAsw(GameState state) => detectShipCombatMechanisms(
  state,
  state.ships[1]!,
).any((item) => item.label == '先制对潜');
