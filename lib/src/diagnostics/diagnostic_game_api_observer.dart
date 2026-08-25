import '../game_state/game_api_event_pipeline.dart';
import 'diagnostic_event.dart';
import 'diagnostic_recorder.dart';

final class DiagnosticGameApiObserver implements GameApiPipelineObserver {
  DiagnosticGameApiObserver({
    required this.recorder,
    this.slowThreshold = const Duration(milliseconds: 500),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final DiagnosticRecorder recorder;
  final Duration slowThreshold;
  final DateTime Function() _now;

  @override
  void onCompleted(GameApiTiming timing) {
    final totalMicros =
        timing.queueWaitMicros + timing.decodeMicros + timing.dispatchMicros;
    if (timing.success &&
        !timing.usedSynchronousFallback &&
        totalMicros < slowThreshold.inMicroseconds) {
      return;
    }
    recorder.record(
      DiagnosticEvent.slowApi(
        occurredAt: _now(),
        path: timing.path,
        responseBytes: timing.responseBytes,
        queueWaitMicros: timing.queueWaitMicros,
        decodeMicros: timing.decodeMicros,
        dispatchMicros: timing.dispatchMicros,
        outcome: timing.success
            ? DiagnosticOutcome.success
            : DiagnosticOutcome.failure,
        usedSynchronousFallback: timing.usedSynchronousFallback,
      ),
    );
  }
}
