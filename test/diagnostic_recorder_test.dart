import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/diagnostics/diagnostic_event.dart';
import 'package:yahagi_kancolle_browser/src/diagnostics/diagnostic_recorder.dart';
import 'package:yahagi_kancolle_browser/src/diagnostics/diagnostic_storage.dart';

void main() {
  test('disabled recorder does no work', () {
    final storage = RecordingDiagnosticSink();
    final recorder = DiagnosticRecorder(sink: storage, enabled: false);

    recorder.record(_event(1));

    expect(recorder.bufferedEventCount, 0);
    expect(storage.calls, 0);
  });

  test('flushes in insertion order and waits for the sink', () async {
    final storage = RecordingDiagnosticSink();
    final recorder = DiagnosticRecorder(sink: storage, flushEventCount: 2);

    recorder
      ..record(_event(1))
      ..record(_event(2));
    await recorder.idle;

    expect(storage.events.map((event) => event.fields['durationMs']), <int>[
      1,
      2,
    ]);
  });

  test('disabling flushes existing events then ignores new events', () async {
    final storage = RecordingDiagnosticSink();
    final recorder = DiagnosticRecorder(sink: storage);
    recorder.record(_event(1));

    await recorder.setEnabled(false);
    recorder.record(_event(2));
    await recorder.idle;

    expect(storage.events, hasLength(1));
    expect(recorder.enabled, isFalse);
  });
}

DiagnosticEvent _event(int value) => DiagnosticEvent.webViewState(
  occurredAt: DateTime.utc(2026, 8, 13, 0, 0, value),
  state: 'pageReady',
  durationMs: value,
);

final class RecordingDiagnosticSink implements DiagnosticSink {
  final List<DiagnosticEvent> events = <DiagnosticEvent>[];
  int calls = 0;

  @override
  Future<void> appendAll(List<DiagnosticEvent> values) async {
    calls += 1;
    events.addAll(values);
  }
}
