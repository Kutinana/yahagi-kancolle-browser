import '../game_state/game_state.dart';
import 'equipment_compatibility.dart';
import 'equipment_compatibility_projection.dart';
import 'owned_inventory_projection.dart';

class ShipEquipmentCompatibilityRow {
  const ShipEquipmentCompatibilityRow({
    required this.master,
    required this.ownedCount,
    required this.compatibility,
  });

  final MasterSlotItem master;
  final int ownedCount;
  final EquipmentCompatibility compatibility;
}

class ShipEquipmentCompatibilityGroup {
  const ShipEquipmentCompatibilityGroup({
    required this.typeId,
    required this.typeName,
    required this.rows,
  });

  final int typeId;
  final String typeName;
  final List<ShipEquipmentCompatibilityRow> rows;
}

class ShipEquipmentCompatibilityProjection {
  const ShipEquipmentCompatibilityProjection(this.state);

  final GameState state;

  List<ShipEquipmentCompatibilityGroup> groups({
    required int shipMasterId,
    bool ownedOnly = false,
    EquipmentInventoryCategory category = EquipmentInventoryCategory.all,
    String query = '',
    EquipmentCompatibilitySlotFilter filter =
        EquipmentCompatibilitySlotFilter.all,
  }) {
    final ownedCounts = <int, int>{};
    for (final item in state.slotItems.values) {
      ownedCounts[item.masterSlotItemId] =
          (ownedCounts[item.masterSlotItemId] ?? 0) + 1;
    }

    final service = EquipmentCompatibilityService(state);
    final normalizedQuery = query.trim().toLowerCase();
    final rowsByType = <int, List<ShipEquipmentCompatibilityRow>>{};
    for (final master in state.masterSlotItems.values) {
      if (master.sortNo <= 0 || master.name.isEmpty || master.type.length < 3) {
        continue;
      }
      final typeId = master.type[2];
      final typeName = state.masterSlotItemTypes[typeId];
      if (typeId <= 0 || typeName == null || typeName.isEmpty) continue;

      final compatibility = service.resolve(
        shipMasterId: shipMasterId,
        equipmentMasterId: master.id,
      );
      if (compatibility == null || !compatibility.canEquip) continue;

      final ownedCount = ownedCounts[master.id] ?? 0;
      if (ownedOnly && ownedCount == 0) continue;
      if (category != EquipmentInventoryCategory.all &&
          equipmentInventoryCategoryFor(master) != category) {
        continue;
      }
      if (normalizedQuery.isNotEmpty &&
          !master.name.toLowerCase().contains(normalizedQuery)) {
        continue;
      }
      if (!_matchesFilter(compatibility, filter)) continue;

      rowsByType
          .putIfAbsent(typeId, () => <ShipEquipmentCompatibilityRow>[])
          .add(
            ShipEquipmentCompatibilityRow(
              master: master,
              ownedCount: ownedCount,
              compatibility: compatibility,
            ),
          );
    }

    final typeIds = rowsByType.keys.toList()..sort();
    return List<ShipEquipmentCompatibilityGroup>.unmodifiable(
      typeIds.map((typeId) {
        final rows = rowsByType[typeId]!
          ..sort((left, right) {
            final bySort = left.master.sortNo.compareTo(right.master.sortNo);
            return bySort != 0
                ? bySort
                : left.master.id.compareTo(right.master.id);
          });
        return ShipEquipmentCompatibilityGroup(
          typeId: typeId,
          typeName: state.masterSlotItemTypes[typeId]!,
          rows: List<ShipEquipmentCompatibilityRow>.unmodifiable(rows),
        );
      }),
    );
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
