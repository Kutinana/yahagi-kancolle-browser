import 'package:flutter/foundation.dart';

import '../bridge/captured_api_event.dart';
import '../game_state/game_state.dart';
import 'anchorage_repair_calculator.dart';
import 'global_game_timer.dart';
import 'nosaki_sparkle_calculator.dart';

class TimerMechanicsService {
  TimerMechanicsService({
    GlobalGameTimer? akashiTimer,
    GlobalGameTimer? nozakiTimer,
  })  : akashiTimer = akashiTimer ?? GlobalGameTimer(),
        nozakiTimer = nozakiTimer ?? GlobalGameTimer();

  final GlobalGameTimer akashiTimer;
  final GlobalGameTimer nozakiTimer;

  void observe({
    required GameState previousState,
    required GameState nextState,
    required CapturedApiEvent event,
    DateTime? now,
  }) {
    final capturedAt = (now ?? event.capturedAt).toUtc();

    switch (event.path) {
      case '/kcsapi/api_port/port':
        onPortRefresh(nextState, capturedAt);
        break;

      case '/kcsapi/api_req_hensei/change':
        if (_isBatchUnequip(event)) {
          // 随伴舰一括解除 explicitly does not reset either timer.
          return;
        }
        onManualFleetChange(
          previousState: previousState,
          nextState: nextState,
          event: event,
          now: capturedAt,
        );
        break;

      case '/kcsapi/api_req_hensei/preset_select':
        onPresetSelect(
          previousState: previousState,
          nextState: nextState,
          event: event,
          now: capturedAt,
        );
        break;

      case '/kcsapi/api_get_member/ship_deck':
      case '/kcsapi/api_get_member/deck':
        _onDeckSnapshot(nextState, capturedAt);
        break;

      default:
        // Other events (sortie, battle, expedition start, remodel, scrap)
        // do not reset timers.
        break;
    }
  }

  void onManualFleetChange({
    required GameState previousState,
    required GameState nextState,
    required CapturedApiEvent event,
    required DateTime now,
  }) {
    final targetDeckId = _asInt(event.requestParams['api_id']);
    final changedFleetIds = _findActuallyChangedFleetIds(
      previousState,
      nextState,
    );
    if (targetDeckId > 0) {
      changedFleetIds.add(targetDeckId);
    }

    var resetAkashi = false;
    var resetNozaki = false;

    for (final fleetId in changedFleetIds) {
      final fleet = nextState.fleets.where((f) => f.id == fleetId).firstOrNull;
      if (fleet == null || fleet.shipIds.isEmpty) continue;

      final flagship = nextState.ships[fleet.shipIds.first];
      final flagshipMaster =
          flagship == null ? null : nextState.masterForShip(flagship);

      // Akashi Reset condition: Flagship of the changed fleet is a repair ship (Akashi / Asahi Kai)
      if (AnchorageRepairCalculator.isRepairShip(flagshipMaster)) {
        resetAkashi = true;
      }

      // Nozaki Reset condition: Slot 0 or Slot 1 of the changed fleet is Nozaki / Nozaki Kai
      final secondShip = fleet.shipIds.length > 1
          ? nextState.ships[fleet.shipIds[1]]
          : null;
      final secondMaster =
          secondShip == null ? null : nextState.masterForShip(secondShip);

      if (NosakiSparkleCalculator.isNosaki(flagshipMaster) ||
          NosakiSparkleCalculator.isNosaki(secondMaster)) {
        resetNozaki = true;
      }
    }

    if (resetAkashi) {
      akashiTimer.reset(
        now,
        reason: AkashiResetReason.manualFleetChange.name,
      );
    }

    if (resetNozaki) {
      nozakiTimer.reset(
        now,
        reason: NozakiResetReason.manualFleetChange.name,
      );
    }
  }

  void onPresetSelect({
    required GameState previousState,
    required GameState nextState,
    required CapturedApiEvent event,
    required DateTime now,
  }) {
    // Preset selection never resets active timers.
    // If a timer was uninitialized and fleet is ready, initialize.
    if (akashiTimer.anchorAt == null &&
        AnchorageRepairCalculator.hasReadyFleet(nextState)) {
      akashiTimer.reset(
        now,
        reason: AkashiResetReason.initialization.name,
        knowledge: TimerKnowledge.estimated,
      );
    }
    if (nozakiTimer.anchorAt == null) {
      nozakiTimer.reset(
        now,
        reason: NozakiResetReason.initialization.name,
        knowledge: TimerKnowledge.estimated,
      );
    }
  }

  void onPortRefresh(GameState portState, DateTime now) {
    evaluateNozaki(portState, now);
    evaluateAkashi(portState, now);
  }

  void evaluateNozaki(GameState portState, DateTime now) {
    if (nozakiTimer.anchorAt == null) {
      nozakiTimer.reset(
        now,
        reason: NozakiResetReason.initialization.name,
        knowledge: TimerKnowledge.estimated,
      );
      return;
    }

    final elapsed = nozakiTimer.elapsed(now);
    if (elapsed == null || elapsed < NosakiSparkleCalculator.minimumCycleTime) {
      nozakiTimer.observe(now);
      return;
    }

    // Refresh node reached (elapsed >= 15 min)!
    // Special rule (NGA V1.1): Fatigue-blocked failure retains READY without resetting.
    if (NosakiSparkleCalculator.isBlockedOnlyByFatigue(portState)) {
      nozakiTimer.observe(now);
      return;
    }

    // All other refresh node cases (success, no Nozaki, or unsupplied/damaged Nozaki)
    // reset to now, starting the next 15-minute cycle.
    final String reason;
    if (!NosakiSparkleCalculator.hasNosakiInWorkPosition(portState)) {
      reason = NozakiResetReason.portRefreshNoNozaki.name;
    } else if (NosakiSparkleCalculator.hasEligibleSparkleTarget(portState)) {
      reason = NozakiResetReason.portRefreshSuccess.name;
    } else {
      reason = NozakiResetReason.portRefreshOtherFailure.name;
    }

    nozakiTimer.reset(now, reason: reason);
  }

  void evaluateAkashi(GameState portState, DateTime now) {
    if (akashiTimer.anchorAt == null) {
      if (AnchorageRepairCalculator.hasReadyFleet(portState)) {
        akashiTimer.reset(
          now,
          reason: AkashiResetReason.initialization.name,
          knowledge: TimerKnowledge.estimated,
        );
      }
      return;
    }

    final elapsed = akashiTimer.elapsed(now);
    if (elapsed == null ||
        elapsed < AnchorageRepairCalculator.minimumRepairTime) {
      akashiTimer.observe(now);
      return;
    }

    // >= 20 min on port refresh: repair settlement occurs and restarts new cycle.
    akashiTimer.reset(now, reason: AkashiResetReason.portRepairCheck.name);
  }

  void _onDeckSnapshot(GameState nextState, DateTime now) {
    if (akashiTimer.anchorAt == null &&
        AnchorageRepairCalculator.hasReadyFleet(nextState)) {
      akashiTimer.reset(
        now,
        reason: AkashiResetReason.initialization.name,
        knowledge: TimerKnowledge.estimated,
      );
    }

    if (nozakiTimer.anchorAt == null) {
      nozakiTimer.reset(
        now,
        reason: NozakiResetReason.initialization.name,
        knowledge: TimerKnowledge.estimated,
      );
    }
  }

  Set<int> _findActuallyChangedFleetIds(
    GameState previousState,
    GameState nextState,
  ) {
    final changed = <int>{};
    for (final nextFleet in nextState.fleets) {
      final prevFleet = previousState.fleets
          .where((f) => f.id == nextFleet.id)
          .firstOrNull;
      if (prevFleet == null ||
          !listEquals(prevFleet.shipIds, nextFleet.shipIds)) {
        changed.add(nextFleet.id);
      }
    }
    for (final prevFleet in previousState.fleets) {
      if (!nextState.fleets.any((f) => f.id == prevFleet.id)) {
        changed.add(prevFleet.id);
      }
    }
    return changed;
  }

  bool _isBatchUnequip(CapturedApiEvent event) {
    final shipIdx = _asInt(event.requestParams['api_ship_idx']);
    final shipId = _asInt(event.requestParams['api_ship_id']);
    return shipIdx == -1 || shipId == -2;
  }

  int _asInt(Object? value) =>
      value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;
}
