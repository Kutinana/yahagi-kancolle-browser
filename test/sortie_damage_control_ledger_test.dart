import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_models.dart';
import 'package:yahagi_kancolle_browser/src/battle/sortie_damage_control_ledger.dart';

void main() {
  test('synchronizes duplicate damage controls by concrete instance', () {
    final ledger = SortieDamageControlLedger()..beginSortie();
    final ship = friendShip(
      equipment: const <int>[42, 42],
      used: const <int>[42, 42],
    );
    const equipment = <int, List<DamageControlEquipmentRef>>{
      1001: <DamageControlEquipmentRef>[
        DamageControlEquipmentRef(instanceId: 501, masterId: 42),
        DamageControlEquipmentRef(instanceId: 502, masterId: 42),
      ],
    };

    ledger.synchronize(
      ships: <BattleShipSnapshot>[ship],
      equipmentByShipId: equipment,
    );
    ledger.synchronize(
      ships: <BattleShipSnapshot>[ship],
      equipmentByShipId: equipment,
    );

    expect(
      ledger.consumptionsForShip(1001).map((item) => item.instanceId),
      <int>[501, 502],
    );
    expect(ledger.usedMasterIdsForShip(1001), <int>[42, 42]);
    expect(ledger.isTrusted, isTrue);
  });

  test('seeds consumption by ship id after fleet position changes', () {
    final ledger = SortieDamageControlLedger()..beginSortie();
    ledger.synchronize(
      ships: <BattleShipSnapshot>[
        friendShip(equipment: const <int>[42], used: const <int>[42]),
      ],
      equipmentByShipId: const <int, List<DamageControlEquipmentRef>>{
        1001: <DamageControlEquipmentRef>[
          DamageControlEquipmentRef(instanceId: 501, masterId: 42),
        ],
      },
    );

    final seeded = ledger.seedFleet(<BattleShipSnapshot>[
      friendShip(position: 6, equipment: const <int>[42]),
    ]);

    expect(seeded.single.position, 6);
    expect(seeded.single.ownedShipId, 1001);
    expect(seeded.single.usedDamageControlItemIds, <int>[42]);
  });

  test('marks the ledger untrusted when a consumed ship id is missing', () {
    final ledger = SortieDamageControlLedger()..beginSortie();

    expect(
      () => ledger.synchronize(
        ships: <BattleShipSnapshot>[
          friendShip(ownedShipId: null, used: const <int>[42]),
        ],
        equipmentByShipId: const <int, List<DamageControlEquipmentRef>>{},
      ),
      returnsNormally,
    );
    expect(ledger.isTrusted, isFalse);
  });

  test('rejects a consumption without a matching equipment instance', () {
    final ledger = SortieDamageControlLedger()..beginSortie();
    const equipment = <int, List<DamageControlEquipmentRef>>{
      1001: <DamageControlEquipmentRef>[
        DamageControlEquipmentRef(instanceId: 501, masterId: 42),
      ],
    };
    ledger.synchronize(
      ships: <BattleShipSnapshot>[
        friendShip(equipment: const <int>[42], used: const <int>[42]),
      ],
      equipmentByShipId: equipment,
    );

    ledger.synchronize(
      ships: <BattleShipSnapshot>[
        friendShip(equipment: const <int>[42, 43], used: const <int>[42, 43]),
      ],
      equipmentByShipId: equipment,
    );

    expect(ledger.isTrusted, isFalse);
    expect(
      ledger.consumptionsForShip(1001).map((item) => item.instanceId),
      <int>[501],
    );
  });

  test('rejects a prediction that rewrites the consumed item prefix', () {
    final ledger = SortieDamageControlLedger()..beginSortie();
    const equipment = <int, List<DamageControlEquipmentRef>>{
      1001: <DamageControlEquipmentRef>[
        DamageControlEquipmentRef(instanceId: 501, masterId: 42),
        DamageControlEquipmentRef(instanceId: 502, masterId: 43),
      ],
    };
    ledger.synchronize(
      ships: <BattleShipSnapshot>[
        friendShip(equipment: const <int>[42, 43], used: const <int>[42]),
      ],
      equipmentByShipId: equipment,
    );

    ledger.synchronize(
      ships: <BattleShipSnapshot>[
        friendShip(equipment: const <int>[42, 43], used: const <int>[43]),
      ],
      equipmentByShipId: equipment,
    );

    expect(ledger.isTrusted, isFalse);
    expect(ledger.usedMasterIdsForShip(1001), <int>[42]);
  });

  test('resets trust and consumptions when the sortie ends', () {
    final ledger = SortieDamageControlLedger()
      ..beginSortie(trusted: false, reason: 'missing previous node');

    expect(ledger.isActive, isTrue);
    expect(ledger.isTrusted, isFalse);
    expect(ledger.untrustedReason, 'missing previous node');

    ledger.endSortie();

    expect(ledger.isActive, isFalse);
    expect(ledger.isTrusted, isTrue);
    expect(ledger.untrustedReason, isNull);
    expect(ledger.usedMasterIdsForShip(1001), isEmpty);
  });

  test('rejects non-damage-control ids in the consumed sequence', () {
    final ledger = SortieDamageControlLedger()..beginSortie();

    ledger.synchronize(
      ships: <BattleShipSnapshot>[
        friendShip(equipment: const <int>[1], used: const <int>[1]),
      ],
      equipmentByShipId: const <int, List<DamageControlEquipmentRef>>{
        1001: <DamageControlEquipmentRef>[
          DamageControlEquipmentRef(instanceId: 9001, masterId: 1),
        ],
      },
    );

    expect(ledger.isTrusted, isFalse);
    expect(ledger.consumptionsForShip(1001), isEmpty);
  });

  test('preserves personnel then goddess equipment order', () {
    final ledger = SortieDamageControlLedger()..beginSortie();

    ledger.synchronize(
      ships: <BattleShipSnapshot>[
        friendShip(equipment: const <int>[42, 43], used: const <int>[42, 43]),
      ],
      equipmentByShipId: const <int, List<DamageControlEquipmentRef>>{
        1001: <DamageControlEquipmentRef>[
          DamageControlEquipmentRef(instanceId: 501, masterId: 42),
          DamageControlEquipmentRef(instanceId: 502, masterId: 43),
        ],
      },
    );

    expect(
      ledger.consumptionsForShip(1001).map((item) => item.instanceId),
      <int>[501, 502],
    );
    expect(ledger.usedMasterIdsForShip(1001), <int>[42, 43]);
  });
}

BattleShipSnapshot friendShip({
  int? ownedShipId = 1001,
  int position = 0,
  List<int> equipment = const <int>[],
  List<int> used = const <int>[],
}) => BattleShipSnapshot(
  masterId: 1,
  ownedShipId: ownedShipId,
  name: 'test',
  side: BattleSide.friend,
  fleetRole: BattleFleetRole.main,
  position: position,
  initialHp: 30,
  maxHp: 30,
  currentHp: 6,
  equipmentMasterIds: equipment,
  usedDamageControlItemIds: used,
);
