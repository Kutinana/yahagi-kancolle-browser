import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/diagnostics/diagnostic_event.dart';
import 'package:yahagi_kancolle_browser/src/diagnostics/diagnostic_export_service.dart';
import 'package:yahagi_kancolle_browser/src/diagnostics/diagnostic_platform_port.dart';
import 'package:yahagi_kancolle_browser/src/diagnostics/diagnostic_storage.dart';

void main() {
  late Directory root;
  late Directory segments;
  late Directory exports;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('yahagi-export-');
    segments = Directory('${root.path}/segments');
    exports = Directory('${root.path}/exports');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('exports and shares one parseable json file', () async {
    final storage = DiagnosticStorage(directory: segments);
    await storage.appendAll(<DiagnosticEvent>[
      DiagnosticEvent.lifecycle(
        occurredAt: DateTime.utc(2026, 8, 13),
        state: DiagnosticLifecycleState.started,
        uptimeMs: 0,
      ),
    ]);
    final platform = FakeDiagnosticPlatformPort();
    final service = DiagnosticExportService(
      storage: storage,
      exportDirectory: exports,
      platform: platform,
      appVersion: '1.0.3+4',
      now: () => DateTime.utc(2026, 8, 13, 11, 30, 15),
    );

    final file = await service.exportAndShare();
    final decoded = jsonDecode(await file.readAsString()) as Map;

    expect(platform.sharedPaths, <String>[file.path]);
    expect(file.path, endsWith('.json'));
    expect(decoded['formatVersion'], 1);
    expect(decoded['records'], hasLength(1));
    expect(await file.length(), lessThanOrEqualTo(10 * 1024 * 1024));
  });

  test('exports more than 64 valid diagnostic records', () async {
    final storage = DiagnosticStorage(directory: segments);
    await storage.appendAll(
      List<DiagnosticEvent>.generate(
        70,
        (index) => DiagnosticEvent.lifecycle(
          occurredAt: DateTime.utc(2026, 8, 13).add(Duration(seconds: index)),
          state: DiagnosticLifecycleState.resumed,
          uptimeMs: index * 1000,
        ),
      ),
    );
    final platform = FakeDiagnosticPlatformPort();
    final service = DiagnosticExportService(
      storage: storage,
      exportDirectory: exports,
      platform: platform,
      appVersion: '1.0.3+4',
      now: () => DateTime.utc(2026, 8, 13, 11, 30, 15),
    );

    final file = await service.exportAndShare();
    final decoded = jsonDecode(await file.readAsString()) as Map;

    expect(decoded['records'], hasLength(70));
    expect(platform.sharedPaths, <String>[file.path]);
  });

  test('saves one audited json file through the platform port', () async {
    final storage = DiagnosticStorage(directory: segments);
    await storage.appendAll(<DiagnosticEvent>[
      DiagnosticEvent.lifecycle(
        occurredAt: DateTime.utc(2026, 8, 13),
        state: DiagnosticLifecycleState.started,
        uptimeMs: 0,
      ),
    ]);
    final platform = FakeDiagnosticPlatformPort(
      savedName: 'Yahagi-Diagnostics-20260813-091445.json',
    );
    final service = DiagnosticExportService(
      storage: storage,
      exportDirectory: exports,
      platform: platform,
      appVersion: '1.0.3+4',
      now: () => DateTime.utc(2026, 8, 13, 9, 14, 45),
    );

    final savedName = await service.save();

    expect(savedName, 'Yahagi-Diagnostics-20260813-091445.json');
    expect(platform.savedPaths, hasLength(1));
    expect(
      jsonDecode(await File(platform.savedPaths.single).readAsString()),
      isA<Map>(),
    );
    expect(platform.sharedPaths, isEmpty);
  });

  test('save cancellation returns null without sharing', () async {
    final platform = FakeDiagnosticPlatformPort();
    final service = DiagnosticExportService(
      storage: DiagnosticStorage(directory: segments),
      exportDirectory: exports,
      platform: platform,
      appVersion: '1.0.3+4',
    );

    expect(await service.save(), isNull);
    expect(platform.savedPaths, hasLength(1));
    expect(platform.sharedPaths, isEmpty);
  });

  test('privacy audit deletes an unsafe export and refuses sharing', () async {
    await segments.create(recursive: true);
    await File('${segments.path}/diagnostic-1-0.jsonl').writeAsString(
      '${jsonEncode(<String, Object?>{
        'occurredAt': '2026-08-13T00:00:00.000Z',
        'type': 'fixedError',
        'fields': <String, Object?>{'password': 'TEST_ONLY_SECRET_DO_NOT_USE'},
      })}\n',
    );
    final platform = FakeDiagnosticPlatformPort();
    final service = DiagnosticExportService(
      storage: DiagnosticStorage(directory: segments),
      exportDirectory: exports,
      platform: platform,
      appVersion: '1.0.3+4',
    );

    await expectLater(
      service.exportAndShare(),
      throwsA(isA<DiagnosticExportPrivacyException>()),
    );
    expect(platform.sharedPaths, isEmpty);
    expect(await exports.list().toList(), isEmpty);
  });
}

final class FakeDiagnosticPlatformPort implements DiagnosticPlatformPort {
  FakeDiagnosticPlatformPort({this.savedName});

  final String? savedName;
  final List<String> sharedPaths = <String>[];
  final List<String> savedPaths = <String>[];

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
      );

  @override
  Future<DiagnosticRuntimeSnapshot> runtimeSnapshot() async =>
      const DiagnosticRuntimeSnapshot(
        pssKb: 1,
        javaHeapKb: 1,
        nativeHeapKb: 1,
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
