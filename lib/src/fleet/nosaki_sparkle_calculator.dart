import '../game_state/game_state.dart';

enum NosakiType { none, base, kai }

enum NosakiSparkleShipStatus {
  sparkling,
  completed,
  nosakiSelf,
  docked,
  unable,
  unready,
}

class NosakiShipSparkleProjection {
  const NosakiShipSparkleProjection({
    required this.position,
    required this.ship,
    required this.master,
    required this.status,
    required this.currentCond,
    required this.gainCond,
    required this.neededTicks,
    this.estimatedTimeTo54,
    required this.fuelCost,
    this.statusReason,
  });

  final int position;
  final OwnedShip ship;
  final MasterShip? master;
  final NosakiSparkleShipStatus status;
  final int currentCond;
  final int gainCond;
  final int neededTicks;
  final Duration? estimatedTimeTo54;
  final int fuelCost;
  final String? statusReason;
}

class NosakiSparkleProjection {
  const NosakiSparkleProjection({
    required this.fleetId,
    required this.isReady,
    this.unreadyReason,
    this.nosakiShip,
    this.nosakiMaster,
    this.nosakiPosition,
    required this.nosakiType,
    required this.boostAmount,
    required this.eligibleShipCount,
    required this.fuelCostPerTick,
    required this.elapsed,
    required this.rows,
  });

  final int fleetId;
  final bool isReady;
  final String? unreadyReason;
  final OwnedShip? nosakiShip;
  final MasterShip? nosakiMaster;
  final int? nosakiPosition; // 1-indexed (1 or 2)
  final NosakiType nosakiType;
  final int boostAmount; // +2 or +3
  final int eligibleShipCount;
  final int fuelCostPerTick;
  final Duration elapsed;
  final List<NosakiShipSparkleProjection> rows;
}

abstract final class NosakiSparkleCalculator {
  static const int nosakiBaseMasterId = 596;
  static const int nosakiKaiMasterId = 602;
  static const Duration minimumCycleTime = Duration(minutes: 15);
  static const int targetCond = 54;
  static const int minimumNosakiCond = 30;
  static const int nosakiBaseCondThreshold = 49;

  static NosakiSparkleProjection project({
    required GameState state,
    required int fleetId,
    required Duration elapsed,
  }) {
    final fleet = state.fleets.where((item) => item.id == fleetId).firstOrNull;
    if (fleet == null) {
      return NosakiSparkleProjection(
        fleetId: fleetId,
        isReady: false,
        unreadyReason: '舰队不存在',
        nosakiType: NosakiType.none,
        boostAmount: 0,
        eligibleShipCount: 0,
        fuelCostPerTick: 0,
        elapsed: elapsed,
        rows: const <NosakiShipSparkleProjection>[],
      );
    }

    final ships = <OwnedShip>[for (final id in fleet.shipIds) ?state.ships[id]];
    if (ships.isEmpty) {
      return NosakiSparkleProjection(
        fleetId: fleetId,
        isReady: false,
        unreadyReason: '舰队为空',
        nosakiType: NosakiType.none,
        boostAmount: 0,
        eligibleShipCount: 0,
        fuelCostPerTick: 0,
        elapsed: elapsed,
        rows: const <NosakiShipSparkleProjection>[],
      );
    }

    final flagship = ships.firstOrNull;
    final flagshipMaster = flagship == null
        ? null
        : state.masterForShip(flagship);
    final secondShip = ships.length > 1 ? ships[1] : null;
    final secondMaster = secondShip == null
        ? null
        : state.masterForShip(secondShip);

    OwnedShip? nosakiShip;
    MasterShip? nosakiMaster;
    int? nosakiPosition; // 1 or 2
    NosakiType nosakiType = NosakiType.none;

    if (_isNosaki(flagshipMaster)) {
      nosakiShip = flagship;
      nosakiMaster = flagshipMaster;
      nosakiPosition = 1;
      nosakiType = _isNosakiKai(flagshipMaster)
          ? NosakiType.kai
          : NosakiType.base;
    } else if (_isNosaki(secondMaster)) {
      nosakiShip = secondShip;
      nosakiMaster = secondMaster;
      nosakiPosition = 2;
      nosakiType = _isNosakiKai(secondMaster)
          ? NosakiType.kai
          : NosakiType.base;
    }

    if (nosakiShip == null || nosakiPosition == null) {
      return NosakiSparkleProjection(
        fleetId: fleetId,
        isReady: false,
        unreadyReason: '未配置野埼（需在第1或第2位）',
        nosakiType: NosakiType.none,
        boostAmount: 0,
        eligibleShipCount: 0,
        fuelCostPerTick: 0,
        elapsed: elapsed,
        rows: <NosakiShipSparkleProjection>[
          for (var index = 0; index < ships.length; index++)
            _projectShipUnready(
              state: state,
              ship: ships[index],
              position: index,
              reason: '未配置野埼',
            ),
        ],
      );
    }

    // Check Nosaki qualification
    String? unreadyReason;
    final isDocked = _isDocked(state, nosakiShip.id);
    final isSupplied = _isFullySupplied(nosakiShip, nosakiMaster);
    final isUndamaged = _isUndamaged(nosakiShip);
    final isCondAdequate = nosakiShip.condition >= minimumNosakiCond;
    final isExpedition = fleet.mission.isActive;

    if (isExpedition) {
      unreadyReason = '舰队处于远征中';
    } else if (isDocked) {
      unreadyReason = '野埼正在入渠修理中';
    } else if (!isSupplied) {
      unreadyReason = '野埼未满补给（需满油弹）';
    } else if (!isUndamaged) {
      unreadyReason = '野埼有破损（需完全无伤）';
    } else if (!isCondAdequate) {
      unreadyReason = '野埼自身疲劳过低（需Cond≥30）';
    }

    final isReady = unreadyReason == null;
    final boostAmount = nosakiType == NosakiType.kai ? 3 : 2;

    var eligibleShipCount = 0;
    final rows = <NosakiShipSparkleProjection>[];

    for (var index = 0; index < ships.length; index++) {
      final ship = ships[index];
      final master = state.masterForShip(ship);
      final isSelf = ship.id == nosakiShip.id;
      final shipDocked = _isDocked(state, ship.id);

      if (isSelf) {
        rows.add(
          NosakiShipSparkleProjection(
            position: index,
            ship: ship,
            master: master,
            status: NosakiSparkleShipStatus.nosakiSelf,
            currentCond: ship.condition,
            gainCond: 0,
            neededTicks: 0,
            estimatedTimeTo54: Duration.zero,
            fuelCost: 0,
            statusReason: '给粮舰主体',
          ),
        );
        continue;
      }

      if (!isReady) {
        rows.add(
          NosakiShipSparkleProjection(
            position: index,
            ship: ship,
            master: master,
            status: NosakiSparkleShipStatus.unready,
            currentCond: ship.condition,
            gainCond: 0,
            neededTicks: 0,
            estimatedTimeTo54: null,
            fuelCost: 0,
            statusReason: unreadyReason,
          ),
        );
        continue;
      }

      if (shipDocked) {
        rows.add(
          NosakiShipSparkleProjection(
            position: index,
            ship: ship,
            master: master,
            status: NosakiSparkleShipStatus.docked,
            currentCond: ship.condition,
            gainCond: 0,
            neededTicks: 0,
            estimatedTimeTo54: null,
            fuelCost: 0,
            statusReason: '伴随舰入渠中',
          ),
        );
        continue;
      }

      if (ship.condition >= targetCond) {
        rows.add(
          NosakiShipSparkleProjection(
            position: index,
            ship: ship,
            master: master,
            status: NosakiSparkleShipStatus.completed,
            currentCond: ship.condition,
            gainCond: 0,
            neededTicks: 0,
            estimatedTimeTo54: Duration.zero,
            fuelCost: 0,
            statusReason: '已达成 54 薄闪',
          ),
        );
        continue;
      }

      // If unremodeled Nosaki, only ships with condition >= 49 can receive morale boost
      if (nosakiType == NosakiType.base &&
          ship.condition < nosakiBaseCondThreshold) {
        final diff = targetCond - ship.condition;
        final ticks = (diff / boostAmount).ceil();
        rows.add(
          NosakiShipSparkleProjection(
            position: index,
            ship: ship,
            master: master,
            status: NosakiSparkleShipStatus.unable,
            currentCond: ship.condition,
            gainCond: 0,
            neededTicks: ticks,
            estimatedTimeTo54: Duration(
              minutes: ticks * minimumCycleTime.inMinutes,
            ),
            fuelCost: 0,
            statusReason: '未改野埼需疲劳≥49',
          ),
        );
        continue;
      }

      eligibleShipCount++;
      final diff = targetCond - ship.condition;
      final ticks = (diff / boostAmount).ceil();
      final estimatedTime = Duration(
        minutes: ticks * minimumCycleTime.inMinutes,
      );

      rows.add(
        NosakiShipSparkleProjection(
          position: index,
          ship: ship,
          master: master,
          status: NosakiSparkleShipStatus.sparkling,
          currentCond: ship.condition,
          gainCond: boostAmount,
          neededTicks: ticks,
          estimatedTimeTo54: estimatedTime,
          fuelCost: 1,
          statusReason: '母港刷闪中',
        ),
      );
    }

    return NosakiSparkleProjection(
      fleetId: fleetId,
      isReady: isReady,
      unreadyReason: unreadyReason,
      nosakiShip: nosakiShip,
      nosakiMaster: nosakiMaster,
      nosakiPosition: nosakiPosition,
      nosakiType: nosakiType,
      boostAmount: isReady ? boostAmount : 0,
      eligibleShipCount: eligibleShipCount,
      fuelCostPerTick: eligibleShipCount,
      elapsed: elapsed,
      rows: rows,
    );
  }

  static bool hasReadyFleet(GameState state) => state.fleets.any(
    (fleet) => project(
      state: state,
      fleetId: fleet.id,
      elapsed: Duration.zero,
    ).isReady,
  );

  static NosakiShipSparkleProjection _projectShipUnready({
    required GameState state,
    required OwnedShip ship,
    required int position,
    required String reason,
  }) {
    final master = state.masterForShip(ship);
    return NosakiShipSparkleProjection(
      position: position,
      ship: ship,
      master: master,
      status: NosakiSparkleShipStatus.unready,
      currentCond: ship.condition,
      gainCond: 0,
      neededTicks: 0,
      estimatedTimeTo54: null,
      fuelCost: 0,
      statusReason: reason,
    );
  }

  static bool isNosaki(MasterShip? master) => _isNosaki(master);

  static bool isNosakiKai(MasterShip? master) => _isNosakiKai(master);

  static bool _isNosaki(MasterShip? master) =>
      master != null &&
      (master.id == nosakiBaseMasterId ||
          master.id == nosakiKaiMasterId ||
          master.name.startsWith('野埼') ||
          master.name.startsWith('野崎'));

  static bool _isNosakiKai(MasterShip? master) =>
      master != null &&
      (master.id == nosakiKaiMasterId ||
          master.name.startsWith('野埼改') ||
          master.name.startsWith('野崎改'));

  static bool _isFullySupplied(OwnedShip ship, MasterShip? master) {
    if (master == null) return true;
    final maxFuel = master.maxFuel > 0 ? master.maxFuel : 100;
    final maxAmmo = master.maxAmmo > 0 ? master.maxAmmo : 100;
    return ship.currentFuel >= maxFuel && ship.currentAmmo >= maxAmmo;
  }

  static bool _isUndamaged(OwnedShip ship) =>
      ship.maxHp > 0 && ship.currentHp >= ship.maxHp;

  static bool _isDocked(GameState state, int shipId) => state.repairDocks.any(
    (dock) => dock.isRepairing && dock.shipId == shipId,
  );

  static bool hasBaseEligibleFleet(GameState state) => hasReadyFleet(state);

  static bool hasEligibleSparkleTarget(GameState state) {
    for (final fleet in state.fleets) {
      final projection = project(
        state: state,
        fleetId: fleet.id,
        elapsed: Duration.zero,
      );
      if (projection.isReady && projection.eligibleShipCount > 0) {
        return true;
      }
    }
    return false;
  }

  static bool hasNosakiInWorkPosition(GameState state) {
    for (final fleet in state.fleets) {
      if (fleet.shipIds.isEmpty) continue;
      final flagship = state.ships[fleet.shipIds.first];
      final flagshipMaster =
          flagship == null ? null : state.masterForShip(flagship);
      if (isNosaki(flagshipMaster)) return true;

      if (fleet.shipIds.length > 1) {
        final second = state.ships[fleet.shipIds[1]];
        final secondMaster = second == null ? null : state.masterForShip(second);
        if (isNosaki(secondMaster)) return true;
      }
    }
    return false;
  }

  static bool isBlockedOnlyByFatigue(GameState state) {
    if (!hasBaseEligibleFleet(state)) {
      return false;
    }
    return !hasEligibleSparkleTarget(state);
  }

  static int preferredNosakiSparkleFleetId({
    required GameState state,
    Duration elapsed = Duration.zero,
  }) {
    final fleetIds = state.fleets.map((fleet) => fleet.id).toList()..sort();
    for (final fleetId in fleetIds) {
      final projection = project(
        state: state,
        fleetId: fleetId,
        elapsed: elapsed,
      );
      if (projection.isReady) {
        return fleetId;
      }
    }
    for (final fleetId in fleetIds) {
      final ships = state.shipsForFleet(fleetId);
      for (final ship in ships) {
        final master = state.masterForShip(ship);
        if (_isNosaki(master)) {
          return fleetId;
        }
      }
    }
    return 1;
  }
}
