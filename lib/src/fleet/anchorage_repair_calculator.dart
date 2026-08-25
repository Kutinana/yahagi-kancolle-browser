import 'dart:math' as math;

import '../game_state/game_state.dart';

enum AnchorageRepairShipStatus { completed, repairing, outOfRange, unable }

class AnchorageRepairShipProjection {
  const AnchorageRepairShipProjection({
    required this.position,
    required this.ship,
    required this.master,
    required this.status,
    required this.lostHp,
    required this.estimatedRecoveredHp,
    this.remaining,
    this.unitDuration,
  });

  final int position;
  final OwnedShip ship;
  final MasterShip? master;
  final AnchorageRepairShipStatus status;
  final int lostHp;
  final int estimatedRecoveredHp;
  final Duration? remaining;
  final Duration? unitDuration;
}

class AnchorageRepairProjection {
  const AnchorageRepairProjection({
    required this.fleetId,
    required this.isReady,
    required this.isAkashiFlagship,
    required this.isRepairShipFlagship,
    required this.pairedRepairBonus,
    required this.facilityCount,
    required this.repairableCount,
    required this.elapsed,
    required this.rows,
  });

  final int fleetId;
  final bool isReady;
  final bool isAkashiFlagship;
  final bool isRepairShipFlagship;
  final bool pairedRepairBonus;
  final int facilityCount;
  final int repairableCount;
  final Duration elapsed;
  final List<AnchorageRepairShipProjection> rows;
}

abstract final class AnchorageRepairCalculator {
  static const int shipRepairFacilityMasterId = 86;
  static const Duration minimumRepairTime = Duration(minutes: 20);
  static const double pairedRepairTimeMultiplier = 5 / 6;
  static const Map<int, double> _repairTimeFactors = <int, double>{
    1: 0.5,
    2: 1,
    3: 1,
    4: 1,
    5: 1.5,
    6: 1.5,
    7: 1.5,
    8: 1.5,
    9: 2,
    10: 2,
    11: 2,
    12: 0,
    13: 0.5,
    14: 1,
    15: 1,
    16: 1,
    17: 1,
    18: 2,
    19: 2,
    20: 1.5,
    21: 1,
    22: 1,
  };

  static AnchorageRepairProjection project({
    required GameState state,
    required int fleetId,
    required Duration elapsed,
  }) {
    final fleet = state.fleets.where((item) => item.id == fleetId).firstOrNull;
    if (fleet == null) {
      return AnchorageRepairProjection(
        fleetId: fleetId,
        isReady: false,
        isAkashiFlagship: false,
        isRepairShipFlagship: false,
        pairedRepairBonus: false,
        facilityCount: 0,
        repairableCount: 0,
        elapsed: elapsed,
        rows: const <AnchorageRepairShipProjection>[],
      );
    }

    final ships = <OwnedShip>[for (final id in fleet.shipIds) ?state.ships[id]];
    final flagship = ships.firstOrNull;
    final flagshipMaster = flagship == null
        ? null
        : state.masterForShip(flagship);
    final secondShip = ships.length > 1 ? ships[1] : null;
    final secondMaster = secondShip == null
        ? null
        : state.masterForShip(secondShip);
    final isAkashiFlagship = _isAkashi(flagshipMaster);
    final isAsahiKaiFlagship = _isAsahiKai(flagshipMaster);
    final isRepairShipFlagship = isAkashiFlagship || isAsahiKaiFlagship;
    final flagshipFacilityCount = flagship == null
        ? 0
        : _facilityCount(state, flagship);
    final secondFacilityCount = secondShip == null
        ? 0
        : _facilityCount(state, secondShip);
    final flagshipHealthy = flagship != null && _isRepairableDamage(flagship);
    final flagshipDocked = flagship != null && _isDocked(state, flagship.id);
    final isReady =
        isRepairShipFlagship &&
        flagshipHealthy &&
        !flagshipDocked &&
        !fleet.mission.isActive &&
        (!isAsahiKaiFlagship || flagshipFacilityCount > 0);
    final validRepairPair =
        (isAkashiFlagship && _isAsahiKai(secondMaster)) ||
        (isAsahiKaiFlagship && _isAkashi(secondMaster));
    final pairedRepairBonus =
        isReady &&
        validRepairPair &&
        secondShip != null &&
        _isBelowMinorDamage(secondShip) &&
        secondFacilityCount > 0;
    final facilityCount =
        flagshipFacilityCount + (pairedRepairBonus ? secondFacilityCount : 0);
    final baseRepairCount = isAkashiFlagship || pairedRepairBonus ? 2 : 0;
    final repairableCount = isReady
        ? math.min(fleet.slotCount, baseRepairCount + facilityCount)
        : 0;
    final coverage = math.min(ships.length, repairableCount);
    final timeMultiplier = pairedRepairBonus ? pairedRepairTimeMultiplier : 1.0;

    return AnchorageRepairProjection(
      fleetId: fleetId,
      isReady: isReady,
      isAkashiFlagship: isAkashiFlagship,
      isRepairShipFlagship: isRepairShipFlagship,
      pairedRepairBonus: pairedRepairBonus,
      facilityCount: facilityCount,
      repairableCount: repairableCount,
      elapsed: elapsed,
      rows: <AnchorageRepairShipProjection>[
        for (var index = 0; index < ships.length; index++)
          _projectShip(
            state: state,
            ship: ships[index],
            position: index,
            coverage: coverage,
            elapsed: elapsed,
            isReady: isReady,
            isRepairShipFlagship: isRepairShipFlagship,
            timeMultiplier: timeMultiplier,
          ),
      ],
    );
  }

  static bool hasReadyFleet(GameState state) => state.fleets.any(
    (fleet) => project(
      state: state,
      fleetId: fleet.id,
      elapsed: Duration.zero,
    ).isReady,
  );

  static AnchorageRepairShipProjection _projectShip({
    required GameState state,
    required OwnedShip ship,
    required int position,
    required int coverage,
    required Duration elapsed,
    required bool isReady,
    required bool isRepairShipFlagship,
    required double timeMultiplier,
  }) {
    final lostHp = math.max(0, ship.maxHp - ship.currentHp);
    final master = state.masterForShip(ship);
    final unitDuration = lostHp == 0
        ? null
        : _unitDuration(ship, master, timeMultiplier);
    if (!isReady) {
      return AnchorageRepairShipProjection(
        position: position,
        ship: ship,
        master: master,
        status: isRepairShipFlagship
            ? AnchorageRepairShipStatus.outOfRange
            : AnchorageRepairShipStatus.unable,
        lostHp: lostHp,
        estimatedRecoveredHp: 0,
        unitDuration: unitDuration,
      );
    }
    if (position >= coverage ||
        !_isRepairableDamage(ship) ||
        _isDocked(state, ship.id)) {
      return AnchorageRepairShipProjection(
        position: position,
        ship: ship,
        master: master,
        status: AnchorageRepairShipStatus.outOfRange,
        lostHp: lostHp,
        estimatedRecoveredHp: 0,
        unitDuration: unitDuration,
      );
    }
    if (lostHp == 0) {
      return AnchorageRepairShipProjection(
        position: position,
        ship: ship,
        master: master,
        status: AnchorageRepairShipStatus.completed,
        lostHp: 0,
        estimatedRecoveredHp: 0,
        remaining: Duration.zero,
      );
    }

    final totalDuration = _totalDuration(ship, lostHp, timeMultiplier);
    final remaining = totalDuration > elapsed
        ? totalDuration - elapsed
        : Duration.zero;
    final recovered = elapsed < minimumRepairTime || unitDuration == null
        ? 0
        : math.min(
            lostHp,
            math.max(1, elapsed.inMilliseconds ~/ unitDuration.inMilliseconds),
          );
    return AnchorageRepairShipProjection(
      position: position,
      ship: ship,
      master: master,
      status: AnchorageRepairShipStatus.repairing,
      lostHp: lostHp,
      estimatedRecoveredHp: recovered,
      remaining: remaining,
      unitDuration: unitDuration,
    );
  }

  static Duration? _unitDuration(
    OwnedShip ship,
    MasterShip? master,
    double timeMultiplier,
  ) {
    final factor = _repairTimeFactors[master?.shipTypeId];
    if (factor == null || factor == 0) return null;

    final baseSeconds = ship.level < 12
        ? ship.level * 10
        : ship.level * 5 + math.sqrt(ship.level - 11).floor() * 10 + 50;
    final milliseconds = (baseSeconds * factor * timeMultiplier * 1000).round();
    return milliseconds > 0 ? Duration(milliseconds: milliseconds) : null;
  }

  static Duration _totalDuration(
    OwnedShip ship,
    int lostHp,
    double timeMultiplier,
  ) {
    if (lostHp == 1) {
      return minimumRepairTime;
    }
    final adjustedMilliseconds = math.max(
      0,
      ship.repairDurationMilliseconds -
          const Duration(seconds: 30).inMilliseconds,
    );
    final roundedMinutes =
        (adjustedMilliseconds *
                timeMultiplier /
                const Duration(minutes: 1).inMilliseconds)
            .ceil();
    return Duration(
      minutes: math.max(minimumRepairTime.inMinutes, roundedMinutes),
    );
  }

  static int _facilityCount(GameState state, OwnedShip flagship) {
    final equipmentIds = <int>[
      ...flagship.slotIds.where((id) => id > 0),
      if (flagship.extraSlotId > 0) flagship.extraSlotId,
    ];
    return equipmentIds.where((id) {
      final owned = state.slotItems[id];
      return owned?.masterSlotItemId == shipRepairFacilityMasterId;
    }).length;
  }

  static bool isRepairShip(MasterShip? master) =>
      _isAkashi(master) || _isAsahiKai(master);

  static bool isAkashi(MasterShip? master) => _isAkashi(master);

  static bool isAsahiKai(MasterShip? master) => _isAsahiKai(master);

  static bool _isAkashi(MasterShip? master) =>
      master != null &&
      (master.id == 182 || master.id == 187 || master.name.startsWith('明石'));

  static bool _isAsahiKai(MasterShip? master) =>
      master != null && (master.id == 958 || master.name.startsWith('朝日改'));

  static bool _isRepairableDamage(OwnedShip ship) =>
      ship.maxHp > 0 && ship.currentHp * 2 > ship.maxHp;

  static bool _isBelowMinorDamage(OwnedShip ship) =>
      ship.maxHp > 0 && ship.currentHp * 4 > ship.maxHp * 3;

  static bool _isDocked(GameState state, int shipId) => state.repairDocks.any(
    (dock) => dock.isRepairing && dock.shipId == shipId,
  );

  static bool hasBaseEligibleFleet(GameState state) => hasReadyFleet(state);

  static bool hasEligibleRepairTarget(GameState state) {
    for (final fleet in state.fleets) {
      final projection = project(
        state: state,
        fleetId: fleet.id,
        elapsed: Duration.zero,
      );
      if (projection.rows.any(
        (row) => row.status == AnchorageRepairShipStatus.repairing,
      )) {
        return true;
      }
    }
    return false;
  }
}
