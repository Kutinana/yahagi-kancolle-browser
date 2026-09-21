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
  return shipRepairStatusesFor(
    state: state,
    anchorageRepairStartedAt: anchorageRepairStartedAt,
    nosakiSparkleStartedAt: nosakiSparkleStartedAt,
    now: now,
  )[shipId];
}

/// Compute each fleet projection once per refresh, not once per displayed ship.
Map<int, ShipRepairStatus> shipRepairStatusesFor({
  required GameState state,
  required DateTime? anchorageRepairStartedAt,
  DateTime? nosakiSparkleStartedAt,
  required DateTime now,
}) {
  final statuses = <int, ShipRepairStatus>{
    for (final id in state.combatState.escapedShipIds)
      id: ShipRepairStatus.retreat,
  };
  for (final dock in state.repairDocks) {
    if (dock.isRepairing) {
      statuses.putIfAbsent(dock.shipId, () => ShipRepairStatus.dock);
    }
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
      for (final row in projection.rows) {
        if (row.status == AnchorageRepairShipStatus.repairing) {
          statuses.putIfAbsent(row.ship.id, () => ShipRepairStatus.anchorage);
        }
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
      for (final row in projection.rows) {
        if (row.status == NosakiSparkleShipStatus.sparkling) {
          statuses.putIfAbsent(
            row.ship.id,
            () => ShipRepairStatus.nosakiSparkle,
          );
        }
      }
    }
  }

  return statuses;
}
