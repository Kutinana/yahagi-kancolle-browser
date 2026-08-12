import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/fleet/anchorage_repair_calculator.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';

void main() {
  group('AnchorageRepairCalculator', () {
    test('maps repair facilities to repairable fleet positions', () {
      for (var facilities = 0; facilities <= 4; facilities++) {
        final projection = AnchorageRepairCalculator.project(
          state: buildAnchorageTestState(facilities: facilities),
          fleetId: 1,
          elapsed: const Duration(minutes: 26),
        );

        expect(projection.isReady, isTrue);
        expect(projection.facilityCount, facilities);
        expect(projection.repairableCount, facilities + 2);
      }
    });

    test('requires a repair facility for an Asahi Kai flagship', () {
      final withoutFacility = AnchorageRepairCalculator.project(
        state: buildAnchorageTestState(facilities: 0, flagshipMasterId: 958),
        fleetId: 1,
        elapsed: const Duration(minutes: 26),
      );
      final withFacilities = AnchorageRepairCalculator.project(
        state: buildAnchorageTestState(facilities: 2, flagshipMasterId: 958),
        fleetId: 1,
        elapsed: const Duration(minutes: 26),
      );

      expect(withoutFacility.isReady, isFalse);
      expect(withoutFacility.repairableCount, 0);
      expect(withFacilities.isReady, isTrue);
      expect(withFacilities.facilityCount, 2);
      expect(withFacilities.repairableCount, 2);
    });

    test('combines facilities and accelerates Akashi plus Asahi Kai', () {
      final projection = AnchorageRepairCalculator.project(
        state: buildAnchorageTestState(
          facilities: 2,
          secondMasterId: 958,
          secondFacilities: 2,
          escortHp: 24,
        ),
        fleetId: 1,
        elapsed: const Duration(minutes: 20),
      );

      expect(projection.facilityCount, 4);
      expect(projection.repairableCount, 6);
      expect(
        projection.rows[4].unitDuration,
        const Duration(minutes: 4, seconds: 10),
      );
      expect(projection.rows[4].remaining, const Duration(minutes: 5));
    });

    test('supports the reverse Asahi Kai plus Akashi pairing order', () {
      final projection = AnchorageRepairCalculator.project(
        state: buildAnchorageTestState(
          facilities: 2,
          flagshipMasterId: 958,
          secondMasterId: 182,
          secondFacilities: 2,
          escortHp: 24,
        ),
        fleetId: 1,
        elapsed: const Duration(minutes: 20),
      );

      expect(projection.isReady, isTrue);
      expect(projection.facilityCount, 4);
      expect(projection.repairableCount, 6);
      expect(
        projection.rows[4].unitDuration,
        const Duration(minutes: 4, seconds: 10),
      );
    });

    test('caps paired repair capacity at the fleet slot count', () {
      final normalFleet = AnchorageRepairCalculator.project(
        state: buildAnchorageTestState(
          facilities: 4,
          secondMasterId: 958,
          secondFacilities: 3,
          escortHp: 24,
        ),
        fleetId: 1,
        elapsed: const Duration(minutes: 20),
      );
      final strikingForce = AnchorageRepairCalculator.project(
        state: buildAnchorageTestState(
          facilities: 4,
          secondMasterId: 958,
          secondFacilities: 3,
          escortHp: 24,
          fleetSlotCount: 7,
        ),
        fleetId: 1,
        elapsed: const Duration(minutes: 20),
      );

      expect(normalFleet.repairableCount, 6);
      expect(strikingForce.repairableCount, 7);
    });

    test(
      'does not pair when the second repair ship is at exactly 75 percent',
      () {
        final projection = AnchorageRepairCalculator.project(
          state: buildAnchorageTestState(
            facilities: 2,
            secondMasterId: 958,
            secondFacilities: 2,
            escortHp: 30,
            escortMaxHp: 40,
          ),
          fleetId: 1,
          elapsed: const Duration(minutes: 20),
        );

        expect(projection.facilityCount, 2);
        expect(projection.repairableCount, 4);
        expect(
          projection.rows[1].unitDuration,
          const Duration(minutes: 15, seconds: 40),
        );
        expect(projection.rows[1].remaining, const Duration(minutes: 40));
      },
    );

    test('projects completed repairing and out-of-range statuses', () {
      final projection = AnchorageRepairCalculator.project(
        state: buildAnchorageTestState(facilities: 3),
        fleetId: 1,
        elapsed: const Duration(minutes: 26),
      );

      expect(projection.rows[0].status, AnchorageRepairShipStatus.completed);
      expect(projection.rows[1].status, AnchorageRepairShipStatus.repairing);
      expect(
        projection.rows[1].unitDuration,
        const Duration(minutes: 7, seconds: 50),
      );
      expect(projection.rows[1].remaining, const Duration(minutes: 34));
      expect(projection.rows[1].estimatedRecoveredHp, 3);
      expect(projection.rows[3].status, AnchorageRepairShipStatus.outOfRange);
      expect(projection.rows[4].status, AnchorageRepairShipStatus.repairing);
    });

    test('does not estimate recovered HP before twenty minutes', () {
      final projection = AnchorageRepairCalculator.project(
        state: buildAnchorageTestState(facilities: 3),
        fleetId: 1,
        elapsed: const Duration(minutes: 19, seconds: 59),
      );

      expect(projection.rows[1].status, AnchorageRepairShipStatus.repairing);
      expect(projection.rows[1].estimatedRecoveredHp, 0);
    });

    test('uses the Poi level and ship-type formula for time per HP', () {
      final projection = AnchorageRepairCalculator.project(
        state: buildAnchorageTestState(
          facilities: 3,
          escortLevel: 70,
          escortShipTypeId: 5,
        ),
        fleetId: 1,
        elapsed: const Duration(minutes: 26),
      );

      expect(
        projection.rows[1].unitDuration,
        const Duration(minutes: 11, seconds: 45),
      );
      expect(projection.rows[1].estimatedRecoveredHp, 2);
    });

    test('keeps a damaged ship repairing until refreshed HP is full', () {
      final projection = AnchorageRepairCalculator.project(
        state: buildAnchorageTestState(
          facilities: 3,
          escortHp: 40,
          escortMaxHp: 41,
          escortRepairDurationMilliseconds: 660000,
        ),
        fleetId: 1,
        elapsed: const Duration(minutes: 20),
      );

      expect(projection.rows[1].ship.currentHp, 40);
      expect(projection.rows[1].ship.maxHp, 41);
      expect(projection.rows[1].remaining, Duration.zero);
      expect(projection.rows[1].estimatedRecoveredHp, 1);
      expect(projection.rows[1].status, AnchorageRepairShipStatus.repairing);
    });

    test('marks a non-Akashi flagship as unable to repair', () {
      final projection = AnchorageRepairCalculator.project(
        state: buildAnchorageTestState(facilities: 3, flagshipMasterId: 501),
        fleetId: 1,
        elapsed: const Duration(minutes: 26),
      );

      expect(projection.isReady, isFalse);
      expect(projection.repairableCount, 0);
      expect(
        projection.rows.map((row) => row.status),
        everyElement(AnchorageRepairShipStatus.unable),
      );
    });

    test('marks a damaged Akashi flagship and expedition fleet not ready', () {
      final damaged = AnchorageRepairCalculator.project(
        state: buildAnchorageTestState(facilities: 3, flagshipHp: 19),
        fleetId: 1,
        elapsed: const Duration(minutes: 26),
      );
      final expedition = AnchorageRepairCalculator.project(
        state: buildAnchorageTestState(facilities: 3, onExpedition: true),
        fleetId: 1,
        elapsed: const Duration(minutes: 26),
      );

      expect(damaged.isReady, isFalse);
      expect(damaged.rows.first.status, AnchorageRepairShipStatus.outOfRange);
      expect(expedition.isReady, isFalse);
      expect(
        expedition.rows.first.status,
        AnchorageRepairShipStatus.outOfRange,
      );
    });
  });
}

GameState buildAnchorageTestState({
  required int facilities,
  int flagshipMasterId = 182,
  int flagshipHp = 39,
  bool onExpedition = false,
  bool allShipsFull = false,
  int escortHp = 20,
  int escortMaxHp = 30,
  int escortRepairDurationMilliseconds = 3630000,
  int escortLevel = 70,
  int escortShipTypeId = 2,
  int secondMasterId = 502,
  int secondFacilities = 0,
  int fleetSlotCount = 6,
}) {
  final slotItems = <int, OwnedSlotItem>{
    for (var index = 0; index < facilities; index++)
      100 + index: OwnedSlotItem(id: 100 + index, masterId: 86),
    for (var index = 0; index < secondFacilities; index++)
      200 + index: OwnedSlotItem(id: 200 + index, masterId: 86),
  };
  final facilitySlots = <int>[
    for (var index = 0; index < facilities; index++) 100 + index,
  ];
  final secondFacilitySlots = <int>[
    for (var index = 0; index < secondFacilities; index++) 200 + index,
  ];
  final ships = <int, OwnedShip>{
    1: OwnedShip(
      id: 1,
      masterId: flagshipMasterId,
      level: 80,
      currentHp: flagshipHp,
      maxHp: 39,
      slotIds: facilitySlots,
      repairDurationMilliseconds: 30 * 1000,
    ),
    2: OwnedShip(
      id: 2,
      masterId: secondMasterId,
      level: escortLevel,
      currentHp: allShipsFull ? escortMaxHp : escortHp,
      maxHp: escortMaxHp,
      slotIds: secondFacilitySlots,
      repairDurationMilliseconds: escortRepairDurationMilliseconds,
    ),
    3: const OwnedShip(
      id: 3,
      masterId: 503,
      level: 60,
      currentHp: 28,
      maxHp: 28,
      repairDurationMilliseconds: 0,
    ),
    4: OwnedShip(
      id: 4,
      masterId: 504,
      level: 50,
      currentHp: allShipsFull ? 30 : 15,
      maxHp: 30,
      repairDurationMilliseconds: 1800000,
    ),
    5: OwnedShip(
      id: 5,
      masterId: 505,
      level: 40,
      currentHp: allShipsFull ? 30 : 24,
      maxHp: 30,
      repairDurationMilliseconds: 1830000,
    ),
  };
  return GameState(
    hasMasterData: true,
    hasPortData: true,
    masterShips: <int, MasterShip>{
      182: const MasterShip(id: 182, name: '明石', shipTypeId: 19),
      187: const MasterShip(id: 187, name: '明石改', shipTypeId: 19),
      958: const MasterShip(id: 958, name: '朝日改', shipTypeId: 19),
      501: const MasterShip(id: 501, name: '长门', shipTypeId: 9),
      502: MasterShip(id: 502, name: '测试舰502', shipTypeId: escortShipTypeId),
      for (var id = 503; id <= 505; id++)
        id: MasterShip(id: id, name: '测试舰$id', shipTypeId: 2),
    },
    masterSlotItems: const <int, MasterSlotItem>{
      86: MasterSlotItem(id: 86, name: '艦艇修理施設'),
    },
    ships: ships,
    slotItems: slotItems,
    fleets: <Fleet>[
      Fleet(
        id: 1,
        name: '第一舰队',
        shipIds: ships.keys.toList(growable: false),
        slotCount: fleetSlotCount,
        mission: onExpedition
            ? FleetMission(
                state: 1,
                missionId: 5,
                completionTime: DateTime.utc(2026, 8, 6, 12),
              )
            : const FleetMission(),
      ),
    ],
  );
}
