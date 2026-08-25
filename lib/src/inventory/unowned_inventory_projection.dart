import '../game_state/game_state.dart';
import 'owned_inventory_projection.dart';

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
    : _familyRoots = _buildFamilyRoots(state);

  final GameState state;
  final Map<int, int> _familyRoots;

  int familyRootOf(int masterId) => _familyRoots[masterId] ?? masterId;

  List<UnownedShipFamilyRow> get unownedShipFamilies {
    final ownedRoots = state.ships.values
        .map((ship) => familyRootOf(ship.masterId))
        .toSet();
    final roots = _familyRoots.values.toSet();

    final rows = <UnownedShipFamilyRow>[];
    for (final root in roots) {
      final master = state.masterShips[root];
      if (root > 1500 || master == null || ownedRoots.contains(root)) continue;
      rows.add(
        UnownedShipFamilyRow(
          familyRootId: root,
          master: master,
          typeId: master.shipTypeId,
          typeName: state.masterShipTypes[master.shipTypeId]?.name ?? '',
        ),
      );
    }
    rows.sort((a, b) => _compareShipMaster(a.master, b.master));
    return List<UnownedShipFamilyRow>.unmodifiable(rows);
  }

  List<UnownedShipFamilyRow> unownedShipFamiliesFor({
    ShipInventoryCategory category = ShipInventoryCategory.all,
  }) => List<UnownedShipFamilyRow>.unmodifiable(
    unownedShipFamilies.where(
      (row) => shipTypeMatchesInventoryCategory(row.typeId, category),
    ),
  );

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

  List<UnownedEquipmentRow> unownedEquipmentFor({
    EquipmentInventoryCategory category = EquipmentInventoryCategory.all,
  }) => List<UnownedEquipmentRow>.unmodifiable(
    unownedEquipment.where(
      (row) =>
          category == EquipmentInventoryCategory.all ||
          equipmentInventoryCategoryFor(row.master) == category,
    ),
  );

  static Map<int, int> _buildFamilyRoots(GameState state) {
    final validIds = state.masterShips.keys.where((id) => id <= 1500).toList()
      ..sort();
    final afterIds = <int>{
      for (final id in validIds)
        if (state.masterShips[id]!.afterShipId > 0)
          state.masterShips[id]!.afterShipId,
    };
    final originIds = validIds.where((id) => !afterIds.contains(id));
    final chains = <int, List<int>>{};

    List<int> trace(int root) {
      final chain = <int>[];
      final visited = <int>{};
      var current = root;
      while (visited.add(current)) {
        chain.add(current);
        final next = state.masterShips[current]?.afterShipId ?? 0;
        if (next <= 0) break;
        current = next;
      }
      return chain;
    }

    for (final root in originIds) {
      chains[root] = trace(root);
    }

    final covered = chains.values.expand((chain) => chain).toSet();
    final missing = validIds.where((id) => !covered.contains(id)).toList();
    while (missing.isNotEmpty) {
      final root = missing.first;
      final chain = trace(root);
      chains[root] = chain;
      final chainIds = chain.toSet();
      missing.removeWhere(chainIds.contains);
    }

    final result = <int, int>{};
    for (final entry in chains.entries) {
      for (final id in entry.value) {
        result[id] = entry.key;
      }
    }
    return result;
  }

  static int _compareShipMaster(MasterShip a, MasterShip b) {
    final sort = a.sortNo.compareTo(b.sortNo);
    return sort != 0 ? sort : a.id.compareTo(b.id);
  }
}
