import 'owned_inventory_projection.dart';

class ShipInventorySortState {
  const ShipInventorySortState.initial()
    : lockedCriteria = const <ShipInventorySortCriterion>[],
      activeCriterion = const ShipInventorySortCriterion(
        field: ShipInventorySortField.level,
        descending: true,
      );

  ShipInventorySortState._(
    List<ShipInventorySortCriterion> lockedCriteria,
    this.activeCriterion,
  ) : lockedCriteria = List<ShipInventorySortCriterion>.unmodifiable(
        lockedCriteria,
      );

  final List<ShipInventorySortCriterion> lockedCriteria;
  final ShipInventorySortCriterion? activeCriterion;

  List<ShipInventorySortCriterion> get effectiveCriteria =>
      List<ShipInventorySortCriterion>.unmodifiable(
        <ShipInventorySortCriterion>[...lockedCriteria, ?activeCriterion],
      );

  ShipInventorySortState tap(ShipInventorySortField field) {
    final lockedIndex = lockedCriteria.indexWhere(
      (criterion) => criterion.field == field,
    );
    if (lockedIndex >= 0) {
      final nextLocked = List<ShipInventorySortCriterion>.of(lockedCriteria);
      final criterion = nextLocked[lockedIndex];
      nextLocked[lockedIndex] = criterion.copyWith(
        descending: !criterion.descending,
      );
      return ShipInventorySortState._(nextLocked, activeCriterion);
    }

    if (activeCriterion?.field == field) {
      return ShipInventorySortState._(
        lockedCriteria,
        activeCriterion!.copyWith(descending: !activeCriterion!.descending),
      );
    }

    return ShipInventorySortState._(
      lockedCriteria,
      ShipInventorySortCriterion(field: field, descending: true),
    );
  }

  ShipInventorySortState longPress(ShipInventorySortField field) {
    final lockedIndex = lockedCriteria.indexWhere(
      (criterion) => criterion.field == field,
    );
    if (lockedIndex >= 0) {
      final nextLocked = List<ShipInventorySortCriterion>.of(lockedCriteria)
        ..removeAt(lockedIndex);
      if (nextLocked.isEmpty && activeCriterion == null) {
        return const ShipInventorySortState.initial();
      }
      return ShipInventorySortState._(nextLocked, activeCriterion);
    }

    final criterion = activeCriterion?.field == field
        ? activeCriterion!
        : ShipInventorySortCriterion(field: field, descending: true);
    return ShipInventorySortState._(<ShipInventorySortCriterion>[
      ...lockedCriteria,
      criterion,
    ], null);
  }

  ShipInventorySortState restoreDefault() =>
      const ShipInventorySortState.initial();
}

class EquipmentInventorySortState {
  const EquipmentInventorySortState.initial()
    : lockedCriteria = const <EquipmentInventorySortCriterion>[],
      activeCriterion = null;

  EquipmentInventorySortState._(
    List<EquipmentInventorySortCriterion> lockedCriteria,
    this.activeCriterion,
  ) : lockedCriteria = List<EquipmentInventorySortCriterion>.unmodifiable(
        lockedCriteria,
      );

  final List<EquipmentInventorySortCriterion> lockedCriteria;
  final EquipmentInventorySortCriterion? activeCriterion;

  List<EquipmentInventorySortCriterion> get effectiveCriteria =>
      List<EquipmentInventorySortCriterion>.unmodifiable(
        <EquipmentInventorySortCriterion>[...lockedCriteria, ?activeCriterion],
      );

  EquipmentInventorySortState tap(EquipmentInventorySortField field) {
    final lockedIndex = lockedCriteria.indexWhere(
      (criterion) => criterion.field == field,
    );
    if (lockedIndex >= 0) {
      final nextLocked = List<EquipmentInventorySortCriterion>.of(
        lockedCriteria,
      );
      final criterion = nextLocked[lockedIndex];
      nextLocked[lockedIndex] = criterion.copyWith(
        descending: !criterion.descending,
      );
      return EquipmentInventorySortState._(nextLocked, activeCriterion);
    }
    if (activeCriterion?.field == field) {
      return EquipmentInventorySortState._(
        lockedCriteria,
        activeCriterion!.copyWith(descending: !activeCriterion!.descending),
      );
    }
    return EquipmentInventorySortState._(
      lockedCriteria,
      EquipmentInventorySortCriterion(field: field, descending: true),
    );
  }

  EquipmentInventorySortState longPress(EquipmentInventorySortField field) {
    final lockedIndex = lockedCriteria.indexWhere(
      (criterion) => criterion.field == field,
    );
    if (lockedIndex >= 0) {
      final nextLocked = List<EquipmentInventorySortCriterion>.of(
        lockedCriteria,
      )..removeAt(lockedIndex);
      return EquipmentInventorySortState._(nextLocked, activeCriterion);
    }
    final criterion = activeCriterion?.field == field
        ? activeCriterion!
        : EquipmentInventorySortCriterion(field: field, descending: true);
    return EquipmentInventorySortState._(<EquipmentInventorySortCriterion>[
      ...lockedCriteria,
      criterion,
    ], null);
  }

  EquipmentInventorySortState restoreDefault() =>
      const EquipmentInventorySortState.initial();
}
