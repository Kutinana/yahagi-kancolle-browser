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

  test(
    'startup records the previous exit reason without delaying start',
    () async {
      final root = Directory.systemTemp.createTempSync(
        'diagnostic-controller-',
      );
      addTearDown(() => root.deleteSync(recursive: true));
      final storage = DiagnosticStorage(
        directory: Directory('${root.path}/log'),
      );
      final recorder = DiagnosticRecorder(sink: storage, enabled: false);
      final platform = _FakePlatform();
      final controller = DiagnosticController(
        settings: MemoryDiagnosticSettingsStore(true),
        storage: storage,
        recorder: recorder,
        exporter: DiagnosticExportService(
          storage: storage,
          exportDirectory: Directory('${root.path}/export'),
          platform: platform,
          appVersion: 'test',
        ),
        platform: platform,
        manageGlobalErrors: false,
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      await Future<void>.delayed(Duration.zero);
      await recorder.flush();

      final records = await storage.readRecords().toList();
      expect(
        records.any(
          (record) =>
              record['type'] == 'startupSnapshot' &&
              (record['fields']
                      as Map<Object?, Object?>)['previousExitReason'] ==
                  'unavailable',
        ),
        isTrue,
      );
    },
  );

  test('save and share flush records and always reset busy state', () async {
    final root = Directory.systemTemp.createTempSync('diagnostic-controller-');
    addTearDown(() => root.deleteSync(recursive: true));
    final storage = DiagnosticStorage(directory: Directory('${root.path}/log'));
    final recorder = DiagnosticRecorder(sink: storage, enabled: false);
    final platform = _FakePlatform(
      savedName: 'Yahagi-Diagnostics-20260813-091445.json',
    );
    final controller = DiagnosticController(
      settings: MemoryDiagnosticSettingsStore(true),
      storage: storage,
      recorder: recorder,
      exporter: DiagnosticExportService(
        storage: storage,
        exportDirectory: Directory('${root.path}/export'),
        platform: platform,
        appVersion: 'test',
      ),
      manageGlobalErrors: false,
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    recorder.record(
      DiagnosticEvent.lifecycle(
        occurredAt: DateTime.utc(2026, 8, 13),
        state: DiagnosticLifecycleState.resumed,
        uptimeMs: 1,
      ),
    );

    expect(await controller.save(), 'Yahagi-Diagnostics-20260813-091445.json');
    await controller.share();

    expect(controller.exporting, isFalse);
    expect(platform.savedPaths, hasLength(1));
    expect(platform.sharedPaths, hasLength(1));
    expect(await storage.readRecords().length, greaterThanOrEqualTo(2));
  });
}

final class _FakePlatform implements DiagnosticPlatformPort {
  _FakePlatform({this.savedName});

  final String? savedName;
  final List<String> savedPaths = <String>[];
  final List<String> sharedPaths = <String>[];

  @override
  Future<DiagnosticDeviceSnapshot> deviceSnapshot() async =>
      const DiagnosticDeviceSnapshot(
        manufacturer: 'Google',
        model: 'Pixel',
        androidSdk: 35,
        androidRelease: '15',
        supportedAbi: 'arm64-v8a',
        memoryClassMb: 8192,
        screenWidthPx: 2400,
        screenHeightPx: 1080,
        webViewVersion: '139',
        previousExitReason: 'unavailable',
        previousExitStatus: 0,
        previousExitImportance: 0,
        previousExitPssKb: 0,
        previousExitRssKb: 0,
        previousExitTimestampMs: 0,
      );

  @override
  Future<DiagnosticRuntimeSnapshot> runtimeSnapshot() async =>
      const DiagnosticRuntimeSnapshot(
        pssKb: 1,
        javaHeapKb: 1,
        nativeHeapKb: 1,
        graphicsKb: 1,
        privateOtherKb: 1,
        systemAvailableKb: 1,
        lowMemory: false,
      );

  @override
  Future<String?> saveJson(String path) async {
    savedPaths.add(path);
    return savedName;
  }

  @override
  Future<void> shareJson(String path) async => sharedPaths.add(path);
}
