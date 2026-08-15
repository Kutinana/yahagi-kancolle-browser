import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/inventory/owned_inventory_projection.dart';
import 'package:yahagi_kancolle_browser/src/inventory/owned_inventory_sort_state.dart';

void main() {
  const levelDescending = ShipInventorySortCriterion(
    field: ShipInventorySortField.level,
    descending: true,
  );

  void expectCriterion(
    ShipInventorySortCriterion criterion,
    ShipInventorySortField field,
    bool descending,
  ) {
    expect(criterion.field, field);
    expect(criterion.descending, descending);
  }

  test('initial state has an unlocked descending level criterion', () {
    const state = ShipInventorySortState.initial();

    expect(state.lockedCriteria, isEmpty);
    expectCriterion(state.activeCriterion!, ShipInventorySortField.level, true);
    expect(state.effectiveCriteria, hasLength(1));
    expectCriterion(
      state.effectiveCriteria.single,
      ShipInventorySortField.level,
      true,
    );
  });

  test('tapping a new field replaces active and tapping it again toggles', () {
    const state = ShipInventorySortState.initial();

    final replaced = state.tap(ShipInventorySortField.name);
    final toggled = replaced.tap(ShipInventorySortField.name);

    expect(replaced.lockedCriteria, isEmpty);
    expectCriterion(
      replaced.activeCriterion!,
      ShipInventorySortField.name,
      true,
    );
    expectCriterion(
      toggled.activeCriterion!,
      ShipInventorySortField.name,
      false,
    );
  });

  test('long-pressing active preserves direction and clears active', () {
    final state = const ShipInventorySortState.initial()
        .tap(ShipInventorySortField.name)
        .tap(ShipInventorySortField.name);

    final locked = state.longPress(ShipInventorySortField.name);

    expect(locked.activeCriterion, isNull);
    expect(locked.lockedCriteria, hasLength(1));
    expectCriterion(
      locked.lockedCriteria.single,
      ShipInventorySortField.name,
      false,
    );
  });

  test('a new tap after locking active becomes the final key', () {
    const state = ShipInventorySortState.initial();

    final locked = state.longPress(ShipInventorySortField.level);
    final withActive = locked.tap(ShipInventorySortField.name);

    expect(withActive.effectiveCriteria, hasLength(2));
    expectCriterion(
      withActive.effectiveCriteria.first,
      ShipInventorySortField.level,
      true,
    );
    expectCriterion(
      withActive.effectiveCriteria.last,
      ShipInventorySortField.name,
      true,
    );
  });

  test('long-pressing another field locks it descending and clears active', () {
    const state = ShipInventorySortState.initial();

    final result = state.longPress(ShipInventorySortField.condition);

    expect(result.activeCriterion, isNull);
    expect(result.lockedCriteria, hasLength(1));
    expectCriterion(
      result.lockedCriteria.single,
      ShipInventorySortField.condition,
      true,
    );
  });

  test('tapping a locked field only toggles its direction', () {
    final state = const ShipInventorySortState.initial()
        .longPress(ShipInventorySortField.level)
        .tap(ShipInventorySortField.name);

    final result = state.tap(ShipInventorySortField.level);

    expectCriterion(
      result.lockedCriteria.single,
      ShipInventorySortField.level,
      false,
    );
    expectCriterion(result.activeCriterion!, ShipInventorySortField.name, true);
  });

  test('long-pressing a locked field leaves state unchanged', () {
    final state = const ShipInventorySortState.initial()
        .longPress(ShipInventorySortField.level)
        .longPress(ShipInventorySortField.name);

    final result = state.longPress(ShipInventorySortField.level);

    expect(identical(result, state), isTrue);
    expect(result.lockedCriteria, hasLength(2));
    expectCriterion(
      result.lockedCriteria[0],
      ShipInventorySortField.level,
      true,
    );
    expectCriterion(
      result.lockedCriteria[1],
      ShipInventorySortField.name,
      true,
    );
  });

  test(
    'tapping other unlocked fields only replaces the temporary final key',
    () {
      final state = const ShipInventorySortState.initial()
          .longPress(ShipInventorySortField.level)
          .tap(ShipInventorySortField.name);

      final result = state.tap(ShipInventorySortField.condition);

      expect(result.lockedCriteria, hasLength(1));
      expectCriterion(
        result.lockedCriteria.single,
        ShipInventorySortField.level,
        true,
      );
      expectCriterion(
        result.activeCriterion!,
        ShipInventorySortField.condition,
        true,
      );
      expect(result.effectiveCriteria, hasLength(2));
    },
  );

  test('restoreDefault returns the initial state', () {
    final state = const ShipInventorySortState.initial()
        .longPress(ShipInventorySortField.name)
        .tap(ShipInventorySortField.condition);

    final result = state.restoreDefault();

    expect(result.lockedCriteria, isEmpty);
    expectCriterion(
      result.activeCriterion!,
      ShipInventorySortField.level,
      true,
    );
    expect(result.effectiveCriteria, hasLength(1));
  });

  test('criterion lists cannot be modified by callers', () {
    final state = const ShipInventorySortState.initial()
        .longPress(ShipInventorySortField.level)
        .tap(ShipInventorySortField.name);

    expect(
      () => state.lockedCriteria.add(levelDescending),
      throwsUnsupportedError,
    );
    expect(
      () => state.effectiveCriteria.add(levelDescending),
      throwsUnsupportedError,
    );
  });
}
