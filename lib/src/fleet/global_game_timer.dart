enum TimerKnowledge { known, estimated, unknown }

typedef TimerConfidence = TimerKnowledge;

enum NozakiResetReason {
  manualFleetChange,
  portRefreshSuccess,
  portRefreshNoNozaki,
  portRefreshFuelAmmoFailure,
  portRefreshDamageFailure,
  portRefreshOtherFailure,
  initialization,
}

enum AkashiResetReason {
  manualFleetChange,
  portRepairCheck,
  expedition,
  workShipBecameFlagship,
  initialization,
}

class GlobalGameTimer {
  GlobalGameTimer({
    DateTime? anchorAt,
    TimerKnowledge knowledge = TimerKnowledge.unknown,
    String? lastResetReason,
    DateTime? lastObservedAt,
  }) : _anchorAt = anchorAt?.toUtc(),
       _knowledge = knowledge,
       _lastResetReason = lastResetReason,
       _lastObservedAt = lastObservedAt?.toUtc();

  DateTime? _anchorAt;
  TimerKnowledge _knowledge;
  String? _lastResetReason;
  DateTime? _lastObservedAt;

  DateTime? get anchorAt => _anchorAt;
  TimerKnowledge get knowledge => _knowledge;
  TimerConfidence get confidence => _knowledge;
  String? get lastResetReason => _lastResetReason;
  DateTime? get lastObservedAt => _lastObservedAt;

  bool get isRunning => _anchorAt != null;

  void reset(
    DateTime now, {
    String? reason,
    TimerKnowledge knowledge = TimerKnowledge.known,
  }) {
    final utc = now.toUtc();
    _anchorAt = utc;
    _knowledge = knowledge;
    _lastResetReason = reason;
    _lastObservedAt = utc;
  }

  void observe(DateTime now) {
    _lastObservedAt = now.toUtc();
  }

  void restore(
    DateTime anchorAt, {
    TimerKnowledge knowledge = TimerKnowledge.estimated,
    String? reason,
  }) {
    _anchorAt = anchorAt.toUtc();
    _knowledge = knowledge;
    _lastResetReason = reason;
    _lastObservedAt = anchorAt.toUtc();
  }

  void clear() {
    _anchorAt = null;
    _knowledge = TimerKnowledge.unknown;
    _lastResetReason = null;
    _lastObservedAt = null;
  }

  Duration? elapsed(DateTime now) {
    if (_anchorAt == null) return null;
    final utcNow = now.toUtc();
    if (utcNow.isBefore(_anchorAt!)) return Duration.zero;
    return utcNow.difference(_anchorAt!);
  }

  bool isReady(DateTime now, Duration threshold) {
    final diff = elapsed(now);
    return diff != null && diff >= threshold;
  }
}
