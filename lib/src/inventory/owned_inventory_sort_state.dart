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
    if (lockedCriteria.any((criterion) => criterion.field == field)) {
      return this;
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
