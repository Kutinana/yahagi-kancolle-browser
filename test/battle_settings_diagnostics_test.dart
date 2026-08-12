import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/diagnostics/diagnostic_controller.dart';
import 'package:yahagi_kancolle_browser/src/diagnostics/diagnostic_export_service.dart';
import 'package:yahagi_kancolle_browser/src/diagnostics/diagnostic_platform_port.dart';
import 'package:yahagi_kancolle_browser/src/diagnostics/diagnostic_recorder.dart';
import 'package:yahagi_kancolle_browser/src/diagnostics/diagnostic_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/diagnostics/diagnostic_storage.dart';
import 'package:yahagi_kancolle_browser/src/settings/battle_settings_page.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_store.dart';

void main() {
  testWidgets('diagnostic logging defaults on and can be disabled', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync('diag-ui-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final settings = MemoryDiagnosticSettingsStore();
    final storage = DiagnosticStorage(directory: directory);
    final controller = DiagnosticController(
      settings: settings,
      storage: storage,
      recorder: DiagnosticRecorder(sink: storage, enabled: false),
      exporter: DiagnosticExportService(
        storage: storage,
        exportDirectory: Directory('${directory.path}/export'),
        platform: _NoopPlatform(),
        appVersion: 'test',
      ),
      manageGlobalErrors: false,
    );
    addTearDown(controller.dispose);
    final safety = await SafetySettingsController.load(
      MemorySafetySettingsStore(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BattleSettingsPage(
          safetySettingsController: safety,
          diagnosticController: controller,
        ),
      ),
    );

    expect(find.text('客户端诊断日志'), findsOneWidget);
    expect(controller.enabled, isTrue);
    expect(find.byKey(const Key('diagnosticLoggingSwitch')), findsOneWidget);
    await tester.runAsync(() => controller.setEnabled(false));
    await tester.pump();
    expect(controller.enabled, isFalse);
    expect(settings.value, isFalse);
  });
}

final class _NoopPlatform implements DiagnosticPlatformPort {
  @override
  Future<DiagnosticDeviceSnapshot> deviceSnapshot() =>
      throw UnimplementedError();

  @override
  Future<DiagnosticRuntimeSnapshot> runtimeSnapshot() =>
      throw UnimplementedError();

  @override
  Future<void> shareJson(String path) async {}
}
