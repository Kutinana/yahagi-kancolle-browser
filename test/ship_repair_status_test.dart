import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/fleet/ship_repair_status.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';

void main() {
  group('shipRepairStatusFor', () {
    final startedAt = DateTime.utc(2026, 8, 9, 12);

    test('returns dock for a ship in an active repair dock', () {
      final state = _anchorageState().copyWith(
        repairDocks: const <RepairDock>[RepairDock(id: 1, state: 1, shipId: 2)],
      );

      expect(
        shipRepairStatusFor(
          state: state,
          shipId: 2,
          anchorageRepairStartedAt: startedAt,
          now: startedAt.add(const Duration(minutes: 10)),
        ),
        ShipRepairStatus.dock,
      );
    });

    test('returns anchorage only while the projected ship is repairing', () {
      final state = _anchorageState();

      expect(
        shipRepairStatusFor(
          state: state,
          shipId: 2,
          anchorageRepairStartedAt: startedAt,
          now: startedAt.add(const Duration(minutes: 26)),
        ),
        ShipRepairStatus.anchorage,
      );
      expect(
        shipRepairStatusFor(
          state: state,
          shipId: 3,
          anchorageRepairStartedAt: startedAt,
          now: startedAt.add(const Duration(minutes: 26)),
        ),
        isNull,
      );
    });

    test('dock takes precedence when both statuses match', () {
      final state = _anchorageState().copyWith(
        repairDocks: const <RepairDock>[RepairDock(id: 1, state: 1, shipId: 2)],
      );

      expect(
        shipRepairStatusFor(
          state: state,
          shipId: 2,
          anchorageRepairStartedAt: startedAt,
          now: startedAt.add(const Duration(minutes: 26)),
        ),
        ShipRepairStatus.dock,
      );
    });

    test('keeps anchorage until HP refreshes and clears without a timer', () {
      final state = _anchorageState();

      expect(
        shipRepairStatusFor(
          state: state,
          shipId: 2,
          anchorageRepairStartedAt: startedAt,
          now: startedAt.add(const Duration(minutes: 61)),
        ),
        ShipRepairStatus.anchorage,
      );
      expect(
        shipRepairStatusFor(
          state: state,
          shipId: 2,
          anchorageRepairStartedAt: null,
          now: startedAt,
        ),
        isNull,
      );
    });

    test('returns nosakiSparkle for companion ship in ready Nosaki fleet', () {
      final state = GameState(
        hasMasterData: true,
        hasPortData: true,
        masterShips: const <int, MasterShip>{
          602: MasterShip(
            id: 602,
            name: '野埼改',
            shipTypeId: 1,
            maxFuel: 100,
            maxAmmo: 100,
          ),
          501: MasterShip(
            id: 501,
            name: '吹雪',
            shipTypeId: 1,
            maxFuel: 100,
            maxAmmo: 100,
          ),
        },
        ships: const <int, OwnedShip>{
          1: OwnedShip(
            id: 1,
            masterId: 602,
            level: 80,
            currentHp: 42,
            maxHp: 42,
            condition: 49,
            currentFuel: 100,
            currentAmmo: 100,
          ),
          2: OwnedShip(
            id: 2,
            masterId: 501,
            level: 80,
            currentHp: 50,
            maxHp: 50,
            condition: 49,
            currentFuel: 100,
            currentAmmo: 100,
          ),
        },
        fleets: const <Fleet>[
          Fleet(id: 1, name: '第一舰队', shipIds: <int>[1, 2]),
        ],
      );

      final status = shipRepairStatusFor(
        state: state,
        shipId: 2,
        anchorageRepairStartedAt: null,
        nosakiSparkleStartedAt: startedAt,
        now: startedAt.add(const Duration(minutes: 5)),
      );

      expect(status, ShipRepairStatus.nosakiSparkle);
      expect(status?.label, '刷闪');
    });
  });
}

GameState _anchorageState() => GameState(
  hasMasterData: true,
  hasPortData: true,
  masterShips: const <int, MasterShip>{
    182: MasterShip(id: 182, name: '明石', shipTypeId: 19),
    502: MasterShip(id: 502, name: '修理对象', shipTypeId: 2),
    503: MasterShip(id: 503, name: '满血舰', shipTypeId: 2),
  },
  masterSlotItems: const <int, MasterSlotItem>{
    86: MasterSlotItem(id: 86, name: '舰艇修理设施'),
  },
  slotItems: const <int, OwnedSlotItem>{
    100: OwnedSlotItem(id: 100, masterId: 86),
  },
  ships: const <int, OwnedShip>{
    1: OwnedShip(
      id: 1,
      masterId: 182,
      level: 80,
      currentHp: 39,
      maxHp: 39,
      slotIds: <int>[100],
      repairDurationMilliseconds: 30000,
    ),
    2: OwnedShip(
      id: 2,
      masterId: 502,
      level: 70,
      currentHp: 20,
      maxHp: 30,
      repairDurationMilliseconds: 3630000,
    ),
    3: OwnedShip(id: 3, masterId: 503, level: 60, currentHp: 28, maxHp: 28),
  },
  fleets: const <Fleet>[
    Fleet(id: 1, name: '第一舰队', shipIds: <int>[1, 2, 3]),
  ],
);
