import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/fleet/morale_recovery_timer_controller.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/notification/notification_timer_anchor_store.dart';

void main() {
  final observedAt = DateTime.utc(2026, 8, 23, 12);

  GameState state({
    int condition = 40,
    List<int> shipIds = const [1],
    Map<int, OwnedShip>? ships,
    DateTime? updatedAt,
  }) => GameState(
    hasPortData: true,
    updatedAt: updatedAt ?? observedAt,
    fleets: [Fleet(id: 1, name: '第一舰队', shipIds: shipIds)],
    ships:
        ships ??
        {
          1: OwnedShip(id: 1, masterId: 1, level: 1, condition: condition),
          2: const OwnedShip(id: 2, masterId: 2, level: 1, condition: 40),
        },
  );

  test('Cond 40 creates a target nine minutes after observation', () {
    final controller = MoraleRecoveryTimerController();

    controller.reconcile(state(), now: observedAt);

    expect(
      controller.targetForFleet(1),
      observedAt.add(const Duration(minutes: 9)),
    );
  });

  test('unrelated refresh with same fleet and Cond keeps target', () {
    final controller = MoraleRecoveryTimerController();
    controller.reconcile(state(), now: observedAt);

    controller.reconcile(
      state(updatedAt: observedAt.add(const Duration(minutes: 2))),
      now: observedAt.add(const Duration(minutes: 2)),
    );

    expect(
      controller.targetForFleet(1),
      observedAt.add(const Duration(minutes: 9)),
    );
  });

  test('condition or fleet signature change rebuilds target', () {
    final controller = MoraleRecoveryTimerController();
    controller.reconcile(state(), now: observedAt);
    final changedAt = observedAt.add(const Duration(minutes: 1));

    controller.reconcile(
      state(condition: 39, updatedAt: changedAt),
      now: changedAt,
    );
    expect(
      controller.targetForFleet(1),
      changedAt.add(const Duration(minutes: 12)),
    );

    final formationChangedAt = observedAt.add(const Duration(minutes: 2));
    controller.reconcile(
      state(shipIds: const [1, 2], updatedAt: formationChangedAt),
      now: formationChangedAt,
    );
    expect(
      controller.targetForFleet(1),
      formationChangedAt.add(const Duration(minutes: 9)),
    );
  });

  test('recovered, empty, and incomplete fleets clear target', () {
    for (final nextState in <GameState>[
      state(condition: 49),
      state(shipIds: const []),
      state(
        shipIds: const [1, 2],
        ships: const {
          1: OwnedShip(id: 1, masterId: 1, level: 1, condition: 40),
        },
      ),
    ]) {
      final controller = MoraleRecoveryTimerController();
      controller.reconcile(state(), now: observedAt);

      controller.reconcile(nextState, now: observedAt);

      expect(controller.targetForFleet(1), isNull);
    }
  });

  test('valid restored anchor is retained and mismatched one is replaced', () {
    final restoredTarget = observedAt.add(const Duration(minutes: 7));
    final valid = MoraleNotificationTimerAnchor(
      fleetSignature: 'morale:1:1',
      observedAt: observedAt.subtract(const Duration(minutes: 2)),
      observedCondition: 40,
      targetAt: restoredTarget,
    );
    final controller = MoraleRecoveryTimerController(
      initialAnchors: {1: valid},
    );

    controller.reconcile(state(), now: observedAt);
    expect(controller.targetForFleet(1), restoredTarget);

    final changedAt = observedAt.add(const Duration(minutes: 1));
    controller.replaceAnchors({
      1: MoraleNotificationTimerAnchor(
        fleetSignature: 'wrong',
        observedAt: observedAt,
        observedCondition: 40,
        targetAt: restoredTarget,
      ),
    });
    controller.reconcile(state(updatedAt: changedAt), now: changedAt);
    expect(
      controller.targetForFleet(1),
      changedAt.add(const Duration(minutes: 9)),
    );
  });
}
