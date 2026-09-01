import '../game_state/game_state.dart';
import 'equipment_compatibility.dart';

enum EquipmentCompatibilitySlotFilter { all, regular, expansion }

class EquipmentCompatibilityShipRow {
  const EquipmentCompatibilityShipRow({
    required this.shipMaster,
    required this.shipTypeName,
    required this.ownedShips,
    required this.fleetNumbers,
    required this.compatibility,
  });

  final MasterShip shipMaster;
  final String shipTypeName;
  final List<OwnedShip> ownedShips;
  final Set<int> fleetNumbers;
  final EquipmentCompatibility compatibility;
}

class EquipmentCompatibilityProjection {
  EquipmentCompatibilityProjection(this.state);

  final GameState state;
  final Map<int, List<EquipmentCompatibilityShipRow>> _baseRowsByEquipmentId =
      <int, List<EquipmentCompatibilityShipRow>>{};

  List<EquipmentCompatibilityShipRow> rows({
    required int equipmentMasterId,
    bool ownedOnly = false,
    int? shipTypeId,
    String query = '',
    EquipmentCompatibilitySlotFilter filter =
        EquipmentCompatibilitySlotFilter.all,
  }) {
    final baseRows = _baseRowsByEquipmentId.putIfAbsent(
      equipmentMasterId,
      () => _buildBaseRows(equipmentMasterId),
    );
    final normalizedQuery = query.trim().toLowerCase();
    return List<EquipmentCompatibilityShipRow>.unmodifiable(
      baseRows.where((row) {
        if (ownedOnly && row.ownedShips.isEmpty) return false;
        if (shipTypeId != null && row.shipMaster.shipTypeId != shipTypeId) {
          return false;
        }
        if (normalizedQuery.isNotEmpty &&
            !row.shipMaster.name.toLowerCase().contains(normalizedQuery)) {
          return false;
        }
        return _matchesFilter(row.compatibility, filter);
      }),
    );
  }

  List<EquipmentCompatibilityShipRow> _buildBaseRows(int equipmentMasterId) {
    final ownedByMasterId = <int, List<OwnedShip>>{};
    for (final ship in state.ships.values) {
      ownedByMasterId.putIfAbsent(ship.masterId, () => <OwnedShip>[]).add(ship);
    }
    for (final ships in ownedByMasterId.values) {
      ships.sort((left, right) {
        final byLevel = right.level.compareTo(left.level);
        return byLevel != 0 ? byLevel : left.id.compareTo(right.id);
      });
    }

    final service = EquipmentCompatibilityService(state);
    final result = <EquipmentCompatibilityShipRow>[];
    for (final master in state.masterShips.values) {
      if (master.id > 1500 || master.name.isEmpty) continue;
      final ownedShips = ownedByMasterId[master.id] ?? const <OwnedShip>[];
      final compatibility = service.resolve(
        shipMasterId: master.id,
        equipmentMasterId: equipmentMasterId,
      );
      if (compatibility == null || !compatibility.canEquip) continue;

      result.add(
        EquipmentCompatibilityShipRow(
          shipMaster: master,
          shipTypeName: state.masterShipTypes[master.shipTypeId]?.name ?? '',
          ownedShips: List<OwnedShip>.unmodifiable(ownedShips),
          fleetNumbers: _fleetNumbersFor(ownedShips),
          compatibility: compatibility,
        ),
      );
    }
    result.sort((left, right) {
      final byType = left.shipMaster.shipTypeId.compareTo(
        right.shipMaster.shipTypeId,
      );
      if (byType != 0) return byType;
      final leftSort = left.shipMaster.sortNo > 0
          ? left.shipMaster.sortNo
          : left.shipMaster.id;
      final rightSort = right.shipMaster.sortNo > 0
          ? right.shipMaster.sortNo
          : right.shipMaster.id;
      final bySort = leftSort.compareTo(rightSort);
      return bySort != 0
          ? bySort
          : left.shipMaster.id.compareTo(right.shipMaster.id);
    });
    return List<EquipmentCompatibilityShipRow>.unmodifiable(result);
  }

  Set<int> _fleetNumbersFor(List<OwnedShip> ships) {
    if (ships.isEmpty) return const <int>{};
    final ownedIds = ships.map((ship) => ship.id).toSet();
    return Set<int>.unmodifiable(<int>{
      for (final fleet in state.fleets)
        if (fleet.shipIds.any(ownedIds.contains)) fleet.id,
    });
  }

  static bool _matchesFilter(
    EquipmentCompatibility compatibility,
    EquipmentCompatibilitySlotFilter filter,
  ) => switch (filter) {
    EquipmentCompatibilitySlotFilter.all => true,
    EquipmentCompatibilitySlotFilter.regular =>
      compatibility.canEquipInRegularSlot,
    EquipmentCompatibilitySlotFilter.expansion =>
      compatibility.canEquipInExpansionSlot,
  };
}
