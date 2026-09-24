import 'package:flutter/material.dart';

import '../game_state/game_state.dart';
import 'anchorage_repair_calculator.dart';
import 'nosaki_sparkle_calculator.dart';
import 'operation_progress.dart';
import 'ship_status_style.dart';

enum FleetOperationalStatus {
  standby,
  sortie,
  expedition,
  returned,
  anchorageRepair,
  nosakiSparkle,
  anchorageRepairAndSparkle,
  empty,
}

class FleetStatusVisual {
  const FleetStatusVisual(this.status, this.label, this.color);

  final FleetOperationalStatus status;
  final String label;
  final Color color;
}

FleetStatusVisual fleetStatusVisual(
  Fleet fleet, {
  DateTime? now,
  bool isSortie = false,
  GameState? state,
  DateTime? anchorageRepairStartedAt,
  DateTime? nosakiSparkleStartedAt,
}) {
  if (isSortie) {
    return const FleetStatusVisual(
      FleetOperationalStatus.sortie,
      '出击中',
      Color(0xffffc940),
    );
  }
  if (fleet.mission.isActive) {
    if (operationIsCompleted(fleet.mission.completionTime, now: now)) {
      return const FleetStatusVisual(
        FleetOperationalStatus.returned,
        '已返母港',
        Color(0xff03a9f4),
      );
    }
    return const FleetStatusVisual(
      FleetOperationalStatus.expedition,
      '远征中',
      Color(0xffffc940),
    );
  }
  final currentTime = now ?? DateTime.now().toUtc();
  var isRepairing = false;
  var isSparkling = false;
  if (state != null && anchorageRepairStartedAt != null) {
    final elapsed = currentTime.isAfter(anchorageRepairStartedAt)
        ? currentTime.difference(anchorageRepairStartedAt)
        : Duration.zero;
    final repair = AnchorageRepairCalculator.project(
      state: state,
      fleetId: fleet.id,
      elapsed: elapsed,
    );
    isRepairing = repair.rows.any(
      (row) => row.status == AnchorageRepairShipStatus.repairing,
    );
  }
  if (state != null && nosakiSparkleStartedAt != null) {
    final elapsed = currentTime.isAfter(nosakiSparkleStartedAt)
        ? currentTime.difference(nosakiSparkleStartedAt)
        : Duration.zero;
    final sparkle = NosakiSparkleCalculator.project(
      state: state,
      fleetId: fleet.id,
      elapsed: elapsed,
    );
    isSparkling = sparkle.rows.any(
      (row) => row.status == NosakiSparkleShipStatus.sparkling,
    );
  }
  if (isRepairing && isSparkling) {
    return const FleetStatusVisual(
      FleetOperationalStatus.anchorageRepairAndSparkle,
      '泊地修理·刷闪中',
      yahagiStatusGreen,
    );
  }
  if (isRepairing) {
    return const FleetStatusVisual(
      FleetOperationalStatus.anchorageRepair,
      '泊地修理中',
      yahagiStatusGreen,
    );
  }
  if (isSparkling) {
    return const FleetStatusVisual(
      FleetOperationalStatus.nosakiSparkle,
      '野崎刷闪中',
      Color(0xffffc940),
    );
  }
  if (fleet.shipIds.isEmpty) {
    return const FleetStatusVisual(
      FleetOperationalStatus.empty,
      '未编成',
      Color(0xff8197a5),
    );
  }
  return const FleetStatusVisual(
    FleetOperationalStatus.standby,
    '母港待命',
    yahagiStatusGreen,
  );
}
