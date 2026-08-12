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
        _formationAffectsRepairFleet(previousState, nextState, event)) {
      _startedAt = capturedAt;
      return;
    }

    if (event.path == '/kcsapi/api_req_mission/start' &&
        _missionAffectsRepairFleet(previousState, event)) {
      _startedAt = capturedAt;
      return;
    }

    if (event.path == '/kcsapi/api_port/port' &&
        capturedAt.difference(_startedAt!) >=
            AnchorageRepairCalculator.minimumRepairTime) {
      _startedAt = capturedAt;
    }
  }

  bool _formationAffectsRepairFleet(
    GameState previousState,
    GameState nextState,
    CapturedApiEvent event,
  ) {
    final affectedFleetIds = <int>{_asInt(event.requestParams['api_id'])}
      ..removeWhere((id) => id <= 0);
    final movedShipId = _asInt(event.requestParams['api_ship_id']);
    if (movedShipId > 0) {
      for (final fleet in previousState.fleets) {
        if (fleet.shipIds.contains(movedShipId)) {
          affectedFleetIds.add(fleet.id);
        }
      }
    }
    return affectedFleetIds.any(
      (fleetId) =>
          _hasRepairShipFlagship(previousState, fleetId) ||
          _hasRepairShipFlagship(nextState, fleetId),
    );
  }

  bool _missionAffectsRepairFleet(
    GameState previousState,
    CapturedApiEvent event,
  ) {
    final fleetId = _asInt(event.requestParams['api_deck_id']);
    return fleetId > 0 && _hasRepairShipFlagship(previousState, fleetId);
  }

  bool _hasRepairShipFlagship(GameState state, int fleetId) =>
      AnchorageRepairCalculator.project(
        state: state,
        fleetId: fleetId,
        elapsed: Duration.zero,
      ).isRepairShipFlagship;

  int _asInt(Object? value) =>
      value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;
}
