import '../bridge/captured_api_event.dart';
import '../game_state/game_state.dart';
import 'anchorage_repair_calculator.dart';

class AnchorageRepairTimerTracker {
  DateTime? _startedAt;

  DateTime? get startedAt => _startedAt;

  void observe({
    required GameState previousState,
    required GameState nextState,
    required CapturedApiEvent event,
  }) {
    final active = AnchorageRepairCalculator.hasReadyFleet(nextState);
    if (!active) {
      _startedAt = null;
      return;
    }

    final capturedAt = event.capturedAt.toUtc();
    if (_startedAt == null) {
      _startedAt = capturedAt;
      return;
    }

    if (event.path == '/kcsapi/api_req_hensei/change' &&
        !_isBatchUnequip(event)) {
      _startedAt = capturedAt;
      return;
    }

    if (event.path == '/kcsapi/api_req_mission/start') {
      _startedAt = capturedAt;
      return;
    }

    if (event.path == '/kcsapi/api_port/port' &&
        capturedAt.difference(_startedAt!) >=
            AnchorageRepairCalculator.minimumRepairTime) {
      _startedAt = capturedAt;
    }
  }

  bool _isBatchUnequip(CapturedApiEvent event) {
    final shipIdx = _asInt(event.requestParams['api_ship_idx']);
    final shipId = _asInt(event.requestParams['api_ship_id']);
    return shipIdx == -1 || shipId == -2;
  }

  int _asInt(Object? value) =>
      value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;
}
