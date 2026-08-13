import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/diagnostics/diagnostic_controller.dart';
import 'package:yahagi_kancolle_browser/src/diagnostics/diagnostic_event.dart';
import 'package:yahagi_kancolle_browser/src/diagnostics/diagnostic_export_service.dart';
import 'package:yahagi_kancolle_browser/src/diagnostics/diagnostic_platform_port.dart';
import 'package:yahagi_kancolle_browser/src/diagnostics/diagnostic_recorder.dart';
import 'package:yahagi_kancolle_browser/src/diagnostics/diagnostic_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/diagnostics/diagnostic_storage.dart';

void main() {
  test('disabled startup keeps recorder and observers inactive', () async {
    final root = Directory.systemTemp.createTempSync('diagnostic-controller-');
    addTearDown(() => root.deleteSync(recursive: true));
    final storage = DiagnosticStorage(directory: Directory('${root.path}/log'));
    final recorder = DiagnosticRecorder(sink: storage, enabled: false);
    var attached = 0;
    var detached = 0;
    final controller = DiagnosticController(
      settings: MemoryDiagnosticSettingsStore(false),
      storage: storage,
      recorder: recorder,
      exporter: DiagnosticExportService(
        storage: storage,
        exportDirectory: Directory('${root.path}/export'),
        platform: _FakePlatform(),
        appVersion: 'test',
      ),
      onAttachObservers: () => attached += 1,
      onDetachObservers: () => detached += 1,
      manageGlobalErrors: false,
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    recorder.record(
      DiagnosticEvent.lifecycle(
        occurredAt: DateTime.utc(2026),
        state: DiagnosticLifecycleState.started,
        uptimeMs: 0,
      ),
    );
    await recorder.flush();

    expect(controller.enabled, isFalse);
    expect(recorder.enabled, isFalse);
    expect(attached, 0);
    expect(detached, 0);
    expect((await storage.inspect()).totalBytes, 0);
  });
}

final class _FakePlatform implements DiagnosticPlatformPort {
  @override
  Future<DiagnosticDeviceSnapshot> deviceSnapshot() =>
      throw UnimplementedError();

  @override
  Future<DiagnosticRuntimeSnapshot> runtimeSnapshot() =>
      throw UnimplementedError();

  @override
  Future<String?> saveJson(String path) => throw UnimplementedError();

  @override
  Future<void> shareJson(String path) => throw UnimplementedError();
}
