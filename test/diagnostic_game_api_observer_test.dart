import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/diagnostics/diagnostic_event.dart';
import 'package:yahagi_kancolle_browser/src/diagnostics/diagnostic_game_api_observer.dart';
import 'package:yahagi_kancolle_browser/src/diagnostics/diagnostic_recorder.dart';
import 'package:yahagi_kancolle_browser/src/diagnostics/diagnostic_storage.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_api_event_pipeline.dart';

void main() {
  test(
    'a synchronous decode fallback is recorded even when it is fast',
    () async {
      final sink = _RecordingDiagnosticSink();
      final recorder = DiagnosticRecorder(sink: sink, flushEventCount: 1);
      final observer = DiagnosticGameApiObserver(
        recorder: recorder,
        slowThreshold: const Duration(seconds: 1),
        now: () => DateTime.utc(2026, 8, 26),
      );
      addTearDown(recorder.dispose);

      observer.onCompleted(
        const GameApiTiming(
          path: '/kcsapi/api_start2/getData',
          responseBytes: 128,
          queueDepth: 1,
          queueWaitMicros: 1,
          decodeMicros: 1,
          dispatchMicros: 1,
          success: true,
          usedSynchronousFallback: true,
        ),
      );
      await recorder.idle;

      expect(sink.events, hasLength(1));
      expect(sink.events.single.fields['usedSynchronousFallback'], isTrue);
    },
  );
}

final class _RecordingDiagnosticSink implements DiagnosticSink {
  final List<DiagnosticEvent> events = <DiagnosticEvent>[];

  @override
  Future<void> appendAll(List<DiagnosticEvent> values) async {
    events.addAll(values);
  }
}
