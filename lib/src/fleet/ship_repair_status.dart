import '../game_state/game_state.dart';
import 'anchorage_repair_calculator.dart';

enum ShipRepairStatus { dock, anchorage }

extension ShipRepairStatusLabel on ShipRepairStatus {
  String get label => switch (this) {
    ShipRepairStatus.dock => '入渠',
    ShipRepairStatus.anchorage => '泊地',
  };
}

ShipRepairStatus? shipRepairStatusFor({
  required GameState state,
  required int shipId,
  required DateTime? anchorageRepairStartedAt,
  required DateTime now,
}) {
  if (state.repairDocks.any(
    (dock) => dock.isRepairing && dock.shipId == shipId,
  )) {
    return ShipRepairStatus.dock;
  }

  final startedAt = anchorageRepairStartedAt;
  if (startedAt == null) return null;
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
  return null;
}
