import '../bridge/captured_api_event.dart';
import '../game_state/game_state.dart';
import 'global_game_timer.dart';
import 'timer_mechanics_service.dart';

class AnchorageRepairTimerTracker {
  AnchorageRepairTimerTracker({TimerMechanicsService? service})
      : _service = service ?? TimerMechanicsService();

  final TimerMechanicsService _service;

  GlobalGameTimer get timer => _service.akashiTimer;
  DateTime? get startedAt => _service.akashiTimer.anchorAt;

  void observe({
    required GameState previousState,
    required GameState nextState,
    required CapturedApiEvent event,
  }) {
    _service.observe(
      previousState: previousState,
      nextState: nextState,
      event: event,
    );
  }
}

