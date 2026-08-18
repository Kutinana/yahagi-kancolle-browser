import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/diagnostics/diagnostic_controller.dart';
import 'package:yahagi_kancolle_browser/src/diagnostics/diagnostic_export_service.dart';
import 'package:yahagi_kancolle_browser/src/diagnostics/diagnostic_platform_port.dart';
import 'package:yahagi_kancolle_browser/src/diagnostics/diagnostic_recorder.dart';
import 'package:yahagi_kancolle_browser/src/diagnostics/diagnostic_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/diagnostics/diagnostic_storage.dart';
import 'package:yahagi_kancolle_browser/src/settings/diagnostic_user_section.dart';

void main() {
  testWidgets('offers local save sharing and clear as separate actions', (
    tester,
  ) async {
    final fixture = _Fixture.create();
    await tester.pumpWidget(fixture.app());

    expect(find.byKey(const Key('saveDiagnosticFileButton')), findsOneWidget);
    expect(find.byKey(const Key('shareDiagnosticFileButton')), findsOneWidget);
    expect(find.byKey(const Key('clearDiagnosticDataButton')), findsOneWidget);
    expect(find.text('保存到本地'), findsOneWidget);
    expect(find.text('分享诊断文件'), findsOneWidget);
  });
}

final class _Fixture {
  _Fixture({required this.root, required this.controller});

  final Directory root;
  final DiagnosticController controller;

  static _Fixture create() {
    final root = Directory.systemTemp.createTempSync('diagnostic-section-');
    final storage = DiagnosticStorage(directory: Directory('${root.path}/log'));
    final recorder = DiagnosticRecorder(sink: storage, enabled: false);
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
      manageGlobalErrors: false,
    );
    return _Fixture(root: root, controller: controller);
  }

  Widget app() => MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: DiagnosticUserSection(controller: controller)),
  );
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
