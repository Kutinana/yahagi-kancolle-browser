import '../game_state/game_state.dart';

class UnownedShipFamilyRow {
  const UnownedShipFamilyRow({
    required this.familyRootId,
    required this.master,
    required this.typeId,
    required this.typeName,
  });

  final int familyRootId;
  final MasterShip master;
  final int typeId;
  final String typeName;
}

class UnownedEquipmentRow {
  const UnownedEquipmentRow({
    required this.master,
    required this.typeId,
    required this.typeName,
  });

  final MasterSlotItem master;
  final int typeId;
  final String typeName;
}

/// Produces collection-oriented rows from master data and the account's
/// current inventory. Remodel forms are treated as one ship family.
class UnownedInventoryProjection {
  UnownedInventoryProjection(this.state)
    : _predecessors = _buildPredecessors(state);

  final GameState state;
  final Map<int, int> _predecessors;
  final Map<int, int> _rootCache = <int, int>{};

  int familyRootOf(int masterId) {
    final cached = _rootCache[masterId];
    if (cached != null) return cached;
    if (!state.masterShips.containsKey(masterId)) return masterId;

    final visited = <int>{};
    var current = masterId;
    while (true) {
      if (!visited.add(current)) {
        _rootCache[masterId] = masterId;
        return masterId;
      }
      final predecessor = _predecessors[current];
      if (predecessor == null) {
        final currentMaster = state.masterShips[current];
        if (currentMaster != null &&
            currentMaster.afterShipId > 0 &&
            !state.masterShips.containsKey(currentMaster.afterShipId)) {
          _rootCache[masterId] = masterId;
          return masterId;
        }
        for (final id in visited) {
          _rootCache[id] = current;
        }
        return current;
      }
      current = predecessor;
    }
  }

  List<UnownedShipFamilyRow> get unownedShipFamilies {
    final ownedRoots = state.ships.values
        .map((ship) => familyRootOf(ship.masterId))
        .toSet();
    final representatives = <int, MasterShip>{};
    for (final master in state.masterShips.values) {
      if (master.sortNo <= 0) continue;
      final root = familyRootOf(master.id);
      final existing = representatives[root];
      if (existing == null || _compareShipMaster(master, existing) < 0) {
        representatives[root] = master;
      }
    }

    final rows = <UnownedShipFamilyRow>[
      for (final entry in representatives.entries)
        if (!ownedRoots.contains(entry.key))
          UnownedShipFamilyRow(
            familyRootId: entry.key,
            master: entry.value,
            typeId: entry.value.shipTypeId,
            typeName:
                state.masterShipTypes[entry.value.shipTypeId]?.name ?? '其他',
          ),
    ];
    rows.sort((a, b) => _compareShipMaster(a.master, b.master));
    return List<UnownedShipFamilyRow>.unmodifiable(rows);
  }

  List<UnownedEquipmentRow> get unownedEquipment {
    final ownedMasterIds = state.slotItems.values
        .map((item) => item.masterSlotItemId)
        .toSet();
    final rows = <UnownedEquipmentRow>[];
    for (final master in state.masterSlotItems.values) {
      if (master.sortNo <= 0 || ownedMasterIds.contains(master.id)) continue;
      final typeId = master.type.length > 2 ? master.type[2] : 0;
      final typeName = state.masterSlotItemTypes[typeId];
      if (typeId <= 0 || typeName == null || typeName.isEmpty) continue;
      rows.add(
        UnownedEquipmentRow(master: master, typeId: typeId, typeName: typeName),
      );
    }
    rows.sort((a, b) {
      final sort = a.master.sortNo.compareTo(b.master.sortNo);
      return sort != 0 ? sort : a.master.id.compareTo(b.master.id);
    });
    return List<UnownedEquipmentRow>.unmodifiable(rows);
  }

  static Map<int, int> _buildPredecessors(GameState state) {
    final result = <int, int>{};
    for (final master in state.masterShips.values) {
      final next = master.afterShipId;
      if (next > 0 && state.masterShips.containsKey(next)) {
        result.putIfAbsent(next, () => master.id);
      }
    }
    return result;
  }

  static int _compareShipMaster(MasterShip a, MasterShip b) {
    final sort = a.sortNo.compareTo(b.sortNo);
    return sort != 0 ? sort : a.id.compareTo(b.id);
  }
}
