import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/fleet/nosaki_sparkle_calculator.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';

void main() {
  group('NosakiSparkleCalculator', () {
    test(
      'recognizes Nosaki Kai flagship and projects +3 cond for all companion ships',
      () {
        final state = buildNosakiTestState(
          flagshipMasterId: 602, // 野埼改
          companionConds: [48, 51, 45, 54, 28],
        );

        final projection = NosakiSparkleCalculator.project(
          state: state,
          fleetId: 1,
          elapsed: const Duration(minutes: 8),
        );

        expect(projection.isReady, isTrue);
        expect(projection.nosakiType, NosakiType.kai);
        expect(projection.boostAmount, 3);
        expect(projection.nosakiPosition, 1);
        expect(
          projection.eligibleShipCount,
          4,
        ); // 48, 51, 45, 28 are < 54; 54 is completed
        expect(projection.fuelCostPerTick, 4);

        // Ship 1: Nosaki self
        expect(projection.rows[0].status, NosakiSparkleShipStatus.nosakiSelf);
        expect(projection.rows[0].fuelCost, 0);

        // Ship 2: Cond 48 -> neededTicks = ceil((54 - 48)/3) = 2 -> 30 mins
        expect(projection.rows[1].status, NosakiSparkleShipStatus.sparkling);
        expect(projection.rows[1].gainCond, 3);
        expect(projection.rows[1].neededTicks, 2);
        expect(
          projection.rows[1].estimatedTimeTo54,
          const Duration(minutes: 30),
        );
        expect(projection.rows[1].fuelCost, 1);

        // Ship 3: Cond 51 -> neededTicks = ceil((54 - 51)/3) = 1 -> 15 mins
        expect(projection.rows[2].status, NosakiSparkleShipStatus.sparkling);
        expect(projection.rows[2].neededTicks, 1);
        expect(
          projection.rows[2].estimatedTimeTo54,
          const Duration(minutes: 15),
        );

        // Ship 5: Cond 54 -> completed
        expect(projection.rows[4].status, NosakiSparkleShipStatus.completed);
        expect(projection.rows[4].gainCond, 0);
        expect(projection.rows[4].fuelCost, 0);
        expect(projection.rows[4].estimatedTimeTo54, Duration.zero);

        // Ship 6: Cond 28 -> neededTicks = ceil((54 - 28)/3) = 9 -> 135 mins
        expect(projection.rows[5].status, NosakiSparkleShipStatus.sparkling);
        expect(projection.rows[5].neededTicks, 9);
        expect(
          projection.rows[5].estimatedTimeTo54,
          const Duration(minutes: 135),
        );
      },
    );

    test(
      'recognizes unremodeled Nosaki (base) and restricts to cond >= 49 with +2',
      () {
        final state = buildNosakiTestState(
          flagshipMasterId: 596, // 野埼
          companionConds: [49, 51, 46, 53, 30],
        );

        final projection = NosakiSparkleCalculator.project(
          state: state,
          fleetId: 1,
          elapsed: const Duration(minutes: 15),
        );

        expect(projection.isReady, isTrue);
        expect(projection.nosakiType, NosakiType.base);
        expect(projection.boostAmount, 2);

        // Ship 2 (cond 49 >= 49) -> sparkling +2, neededTicks = ceil((54-49)/2) = 3
        expect(projection.rows[1].status, NosakiSparkleShipStatus.sparkling);
        expect(projection.rows[1].gainCond, 2);
        expect(projection.rows[1].neededTicks, 3);
        expect(
          projection.rows[1].estimatedTimeTo54,
          const Duration(minutes: 45),
        );

        // Ship 4 (cond 46 < 49) -> unable (needs cond >= 49 for base Nosaki)
        expect(projection.rows[3].status, NosakiSparkleShipStatus.unable);
        expect(projection.rows[3].gainCond, 0);
        expect(projection.rows[3].fuelCost, 0);

        // Ship 6 (cond 30 < 49) -> unable
        expect(projection.rows[5].status, NosakiSparkleShipStatus.unable);
      },
    );

    test(
      'recognizes Nosaki at position 2 (second ship) with Akashi as flagship',
      () {
        final state = buildNosakiTestState(
          flagshipMasterId: 182, // 明石
          secondMasterId: 602, // 野埼改
          companionConds: [49, 49, 49, 49],
        );

        final projection = NosakiSparkleCalculator.project(
          state: state,
          fleetId: 1,
          elapsed: const Duration(minutes: 10),
        );

        expect(projection.isReady, isTrue);
        expect(projection.nosakiPosition, 2);
        expect(projection.nosakiType, NosakiType.kai);
        expect(
          projection.rows[0].status,
          NosakiSparkleShipStatus.sparkling,
        ); // Flagship Akashi gets sparkle
        expect(
          projection.rows[1].status,
          NosakiSparkleShipStatus.nosakiSelf,
        ); // Nosaki self
      },
    );

    test('fails eligibility if Nosaki is placed at position 3 or below', () {
      final state = buildNosakiTestState(
        flagshipMasterId: 501,
        secondMasterId: 502,
        thirdMasterId: 602, // Nosaki at position 3
      );

      final projection = NosakiSparkleCalculator.project(
        state: state,
        fleetId: 1,
        elapsed: Duration.zero,
      );

      expect(projection.isReady, isFalse);
      expect(projection.nosakiType, NosakiType.none);
      expect(projection.unreadyReason, contains('需在第1或第2位'));
    });

    test('fails eligibility if Nosaki is not fully supplied', () {
      final state = buildNosakiTestState(
        flagshipMasterId: 602,
        nosakiFuel: 80, // Not 100
        nosakiAmmo: 100,
      );

      final projection = NosakiSparkleCalculator.project(
        state: state,
        fleetId: 1,
        elapsed: Duration.zero,
      );

      expect(projection.isReady, isFalse);
      expect(projection.unreadyReason, contains('未满补给'));
    });

    test('fails eligibility if Nosaki has any damage (must be undamaged)', () {
      final state = buildNosakiTestState(
        flagshipMasterId: 602,
        nosakiHp: 41, // 41 / 42 (even 1 HP lost)
        nosakiMaxHp: 42,
      );

      final projection = NosakiSparkleCalculator.project(
        state: state,
        fleetId: 1,
        elapsed: Duration.zero,
      );

      expect(projection.isReady, isFalse);
      expect(projection.unreadyReason, contains('有破损'));
    });

    test('fails eligibility if Nosaki condition is below 30', () {
      final state = buildNosakiTestState(flagshipMasterId: 602, nosakiCond: 25);

      final projection = NosakiSparkleCalculator.project(
        state: state,
        fleetId: 1,
        elapsed: Duration.zero,
      );

      expect(projection.isReady, isFalse);
      expect(projection.unreadyReason, contains('疲劳过低'));
    });

    test('fails eligibility if fleet is on expedition', () {
      final state = buildNosakiTestState(
        flagshipMasterId: 602,
        onExpedition: true,
      );

      final projection = NosakiSparkleCalculator.project(
        state: state,
        fleetId: 1,
        elapsed: Duration.zero,
      );

      expect(projection.isReady, isFalse);
      expect(projection.unreadyReason, contains('远征中'));
    });

    test('marks docked companion ship as docked with 0 fuel cost', () {
      final state = buildNosakiTestState(
        flagshipMasterId: 602,
        companionConds: [48, 48],
        dockedShipIds: [2],
      );

      final projection = NosakiSparkleCalculator.project(
        state: state,
        fleetId: 1,
        elapsed: Duration.zero,
      );

      expect(projection.isReady, isTrue);
      expect(projection.rows[1].status, NosakiSparkleShipStatus.docked);
      expect(projection.rows[1].fuelCost, 0);
      expect(projection.rows[2].status, NosakiSparkleShipStatus.sparkling);
      expect(projection.fuelCostPerTick, 1);
    });

    test('hasReadyFleet returns true if any fleet has a ready Nosaki', () {
      final state = buildNosakiTestState(flagshipMasterId: 602);
      expect(NosakiSparkleCalculator.hasReadyFleet(state), isTrue);

      final noNosakiState = buildNosakiTestState(flagshipMasterId: 501);
      expect(NosakiSparkleCalculator.hasReadyFleet(noNosakiState), isFalse);
    });
  });
}

GameState buildNosakiTestState({
  int flagshipMasterId = 602,
  int secondMasterId = 502,
  int thirdMasterId = 503,
  int nosakiFuel = 100,
  int nosakiAmmo = 100,
  int nosakiHp = 42,
  int nosakiMaxHp = 42,
  int nosakiCond = 49,
  List<int> companionConds = const [49, 49, 49, 49, 49],
  List<int> dockedShipIds = const [],
  bool onExpedition = false,
}) {
  final ships = <int, OwnedShip>{
    1: OwnedShip(
      id: 1,
      masterId: flagshipMasterId,
      level: 80,
      currentHp: flagshipMasterId == 602 || flagshipMasterId == 596
          ? nosakiHp
          : 50,
      maxHp: flagshipMasterId == 602 || flagshipMasterId == 596
          ? nosakiMaxHp
          : 50,
      currentFuel: flagshipMasterId == 602 || flagshipMasterId == 596
          ? nosakiFuel
          : 100,
      currentAmmo: flagshipMasterId == 602 || flagshipMasterId == 596
          ? nosakiAmmo
          : 100,
      condition: flagshipMasterId == 602 || flagshipMasterId == 596
          ? nosakiCond
          : 49,
    ),
    2: OwnedShip(
      id: 2,
      masterId: secondMasterId,
      level: 70,
      currentHp: secondMasterId == 602 || secondMasterId == 596 ? nosakiHp : 40,
      maxHp: secondMasterId == 602 || secondMasterId == 596 ? nosakiMaxHp : 40,
      currentFuel: secondMasterId == 602 || secondMasterId == 596
          ? nosakiFuel
          : 100,
      currentAmmo: secondMasterId == 602 || secondMasterId == 596
          ? nosakiAmmo
          : 100,
      condition: secondMasterId == 602 || secondMasterId == 596
          ? nosakiCond
          : (companionConds.isNotEmpty ? companionConds[0] : 49),
    ),
    3: OwnedShip(
      id: 3,
      masterId: thirdMasterId,
      level: 60,
      currentHp: 30,
      maxHp: 30,
      currentFuel: 100,
      currentAmmo: 100,
      condition: companionConds.length > 1 ? companionConds[1] : 49,
    ),
  };

  for (var i = 3; i < companionConds.length + 1; i++) {
    final shipId = i + 1;
    if (shipId <= 6) {
      ships[shipId] = OwnedShip(
        id: shipId,
        masterId: 500 + shipId,
        level: 50,
        currentHp: 30,
        maxHp: 30,
        currentFuel: 100,
        currentAmmo: 100,
        condition: companionConds[i - 1],
      );
    }
  }

  final repairDocks = <RepairDock>[
    for (var i = 1; i <= 4; i++)
      RepairDock(
        id: i,
        state: dockedShipIds.contains(i) ? 1 : 0,
        shipId: dockedShipIds.contains(i) ? i : 0,
        completionTime: DateTime.utc(2026, 8, 20),
      ),
  ];

  return GameState(
    hasMasterData: true,
    hasPortData: true,
    masterShips: <int, MasterShip>{
      596: const MasterShip(
        id: 596,
        name: '野埼',
        shipTypeId: 22,
        maxFuel: 100,
        maxAmmo: 100,
      ),
      602: const MasterShip(
        id: 602,
        name: '野埼改',
        shipTypeId: 22,
        maxFuel: 100,
        maxAmmo: 100,
      ),
      182: const MasterShip(
        id: 182,
        name: '明石',
        shipTypeId: 19,
        maxFuel: 100,
        maxAmmo: 100,
      ),
      187: const MasterShip(
        id: 187,
        name: '明石改',
        shipTypeId: 19,
        maxFuel: 100,
        maxAmmo: 100,
      ),
      501: const MasterShip(
        id: 501,
        name: '长门',
        shipTypeId: 9,
        maxFuel: 100,
        maxAmmo: 100,
      ),
      502: const MasterShip(
        id: 502,
        name: '陆奥',
        shipTypeId: 9,
        maxFuel: 100,
        maxAmmo: 100,
      ),
      for (var id = 503; id <= 508; id++)
        id: MasterShip(
          id: id,
          name: '舰娘$id',
          shipTypeId: 2,
          maxFuel: 100,
          maxAmmo: 100,
        ),
    },
    ships: ships,
    repairDocks: repairDocks,
    fleets: <Fleet>[
      Fleet(
        id: 1,
        name: '第一舰队',
        shipIds: ships.keys.toList(growable: false),
        slotCount: 6,
        mission: onExpedition
            ? FleetMission(
                state: 1,
                missionId: 5,
                completionTime: DateTime.utc(2026, 8, 20),
              )
            : const FleetMission(),
      ),
    ],
  );
}
