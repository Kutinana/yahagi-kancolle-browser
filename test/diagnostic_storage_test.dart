import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/diagnostics/diagnostic_event.dart';
import 'package:yahagi_kancolle_browser/src/diagnostics/diagnostic_storage.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('yahagi-diagnostics-');
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('rotates segments and keeps total bytes bounded', () async {
    final storage = DiagnosticStorage(
      directory: directory,
      maxTotalBytes: 1400,
      maxSegmentBytes: 400,
      retention: const Duration(days: 7),
      now: () => DateTime.utc(2026, 8, 13),
    );

    for (var index = 0; index < 80; index++) {
      await storage.appendAll(<DiagnosticEvent>[
        DiagnosticEvent.webViewState(
          occurredAt: DateTime.utc(2026, 8, 13, 0, 0, index),
          state: 'pageReady',
          durationMs: index,
        ),
      ]);
    }

    final state = await storage.inspect();
    expect(state.totalBytes, lessThanOrEqualTo(1400));
    expect(state.segmentCount, greaterThan(1));
  });

  test('removes segments older than retention', () async {
    var now = DateTime.utc(2026, 8, 1);
    final storage = DiagnosticStorage(
      directory: directory,
      maxTotalBytes: 4096,
      maxSegmentBytes: 128,
      retention: const Duration(days: 7),
      now: () => now,
    );
    await storage.appendAll(<DiagnosticEvent>[
      DiagnosticEvent.lifecycle(
        occurredAt: now,
        state: DiagnosticLifecycleState.started,
        uptimeMs: 0,
      ),
    ]);
    for (final file in directory.listSync().whereType<File>()) {
      await file.setLastModified(now);
    }
    now = DateTime.utc(2026, 8, 13);

    await storage.prune();

    expect((await storage.inspect()).segmentCount, 0);
  });

  test('reads valid lines before a corrupt tail', () async {
    final storage = DiagnosticStorage(
      directory: directory,
      maxTotalBytes: 4096,
      maxSegmentBytes: 4096,
      now: () => DateTime.utc(2026, 8, 13),
    );
    await storage.appendAll(<DiagnosticEvent>[
      DiagnosticEvent.lifecycle(
        occurredAt: DateTime.utc(2026, 8, 13),
        state: DiagnosticLifecycleState.started,
        uptimeMs: 0,
      ),
    ]);
    final segment = directory.listSync().whereType<File>().single;
    await segment.writeAsString('{broken', mode: FileMode.append, flush: true);

    final records = await storage.readRecords().toList();

    expect(records, hasLength(1));
    expect(records.single['type'], 'lifecycle');
  });
}
