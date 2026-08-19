import '../game_state/game_state.dart';
import 'anchorage_repair_calculator.dart';
import 'nosaki_sparkle_calculator.dart';

enum ShipRepairStatus { dock, anchorage, retreat, nosakiSparkle }

extension ShipRepairStatusLabel on ShipRepairStatus {
  String get label => switch (this) {
    ShipRepairStatus.dock => '入渠',
    ShipRepairStatus.anchorage => '泊地',
    ShipRepairStatus.retreat => '退避',
    ShipRepairStatus.nosakiSparkle => '刷闪',
  };
}

ShipRepairStatus? shipRepairStatusFor({
  required GameState state,
  required int shipId,
  required DateTime? anchorageRepairStartedAt,
  DateTime? nosakiSparkleStartedAt,
  required DateTime now,
}) {
  if (state.combatState.escapedShipIds.contains(shipId)) {
    return ShipRepairStatus.retreat;
  }
  if (state.repairDocks.any(
    (dock) => dock.isRepairing && dock.shipId == shipId,
  )) {
    return ShipRepairStatus.dock;
  }

  final startedAt = anchorageRepairStartedAt;
  if (startedAt != null) {
    final elapsed = now.isAfter(startedAt)
        ? now.difference(startedAt)
        : Duration.zero;
    for (final fleet in state.fleets) {
      final projection = AnchorageRepairCalculator.project(
        state: state,
        fleetId: fleet.id,
        elapsed: elapsed,
      );
      if (projection.rows.any(
        (row) =>
            row.ship.id == shipId &&
            row.status == AnchorageRepairShipStatus.repairing,
      )) {
        return ShipRepairStatus.anchorage;
      }
    }
  }

  final sparkleStartedAt = nosakiSparkleStartedAt;
  if (sparkleStartedAt != null) {
    final elapsed = now.isAfter(sparkleStartedAt)
        ? now.difference(sparkleStartedAt)
        : Duration.zero;
    for (final fleet in state.fleets) {
      final projection = NosakiSparkleCalculator.project(
        state: state,
        fleetId: fleet.id,
        elapsed: elapsed,
      );
      if (projection.rows.any(
        (row) =>
            row.ship.id == shipId &&
            row.status == NosakiSparkleShipStatus.sparkling,
      )) {
        return ShipRepairStatus.nosakiSparkle;
      }
    }
  }

  return null;
}
