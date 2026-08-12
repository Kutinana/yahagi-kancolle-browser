import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

import 'diagnostic_event.dart';
import 'diagnostic_export_service.dart';
import 'diagnostic_performance_monitor.dart';
import 'diagnostic_recorder.dart';
import 'diagnostic_settings_store.dart';
import 'diagnostic_storage.dart';

final class DiagnosticController extends ChangeNotifier {
  DiagnosticController({
    required this.settings,
    required this.storage,
    required this.recorder,
    required this.exporter,
    this.performanceMonitor,
    this.onAttachObservers,
    this.onDetachObservers,
    this.manageGlobalErrors = true,
  });

  final DiagnosticSettingsStore settings;
  final DiagnosticStorage storage;
  final DiagnosticRecorder recorder;
  final DiagnosticExportService exporter;
  final DiagnosticPerformanceMonitor? performanceMonitor;
  final VoidCallback? onAttachObservers;
  final VoidCallback? onDetachObservers;
  final bool manageGlobalErrors;

  bool _enabled = true;
  bool _exporting = false;
  int _storageBytes = 0;
  DateTime? _oldestRecordAt;
  FlutterExceptionHandler? _previousFlutterHandler;
  bool Function(Object, StackTrace)? _previousPlatformHandler;
  bool _errorsAttached = false;

  bool get enabled => _enabled;
  bool get exporting => _exporting;
  int get storageBytes => _storageBytes;
  DateTime? get oldestRecordAt => _oldestRecordAt;

  Future<void> initialize() async {
    _enabled = await settings.loadEnabled();
    await recorder.setEnabled(_enabled);
    if (_enabled) {
      _attach();
      recorder.record(
        DiagnosticEvent.lifecycle(
          occurredAt: DateTime.now(),
          state: DiagnosticLifecycleState.started,
          uptimeMs: 0,
        ),
      );
    }
    await refreshStorageState();
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    if (value == _enabled) return;
    _enabled = value;
    notifyListeners();
    await settings.saveEnabled(value);
    if (value) {
      await recorder.setEnabled(true);
      _attach();
      recorder.record(
        DiagnosticEvent.lifecycle(
          occurredAt: DateTime.now(),
          state: DiagnosticLifecycleState.resumed,
          uptimeMs: 0,
        ),
      );
    } else {
      _detach();
      await recorder.setEnabled(false);
      await refreshStorageState();
    }
  }

  Future<File> export() async {
    _exporting = true;
    notifyListeners();
    try {
      await recorder.flush();
      return await exporter.exportAndShare();
    } finally {
      _exporting = false;
      await refreshStorageState();
      notifyListeners();
    }
  }

  Future<void> clear() async {
    await recorder.flush();
    await storage.clear();
    await refreshStorageState();
    notifyListeners();
  }

  Future<void> refreshStorageState() async {
    final state = await storage.inspect();
    _storageBytes = state.totalBytes;
    _oldestRecordAt = state.oldestRecordAt;
  }

  void _attach() {
    performanceMonitor?.attach();
    onAttachObservers?.call();
    if (manageGlobalErrors) _attachErrorHandlers();
  }

  void _detach() {
    performanceMonitor?.detach();
    onDetachObservers?.call();
    _detachErrorHandlers();
  }

  void _attachErrorHandlers() {
    if (_errorsAttached) return;
    _errorsAttached = true;
    _previousFlutterHandler = FlutterError.onError;
    _previousPlatformHandler = PlatformDispatcher.instance.onError;
    FlutterError.onError = (details) {
      _recordError(
        details.exception,
        details.stack,
        DiagnosticComponent.application,
      );
      _previousFlutterHandler?.call(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      _recordError(error, stack, DiagnosticComponent.application);
      return _previousPlatformHandler?.call(error, stack) ?? false;
    };
  }

  void _recordError(
    Object error,
    StackTrace? stack,
    DiagnosticComponent component,
  ) {
    if (!_enabled) return;
    recorder.record(
      DiagnosticEvent.fixedError(
        occurredAt: DateTime.now(),
        component: component,
        errorType: error.runtimeType.toString(),
        code: DiagnosticErrorCode.operationFailed,
        stack: stack,
      ),
    );
  }

  void _detachErrorHandlers() {
    if (!_errorsAttached) return;
    FlutterError.onError = _previousFlutterHandler;
    PlatformDispatcher.instance.onError = _previousPlatformHandler;
    _previousFlutterHandler = null;
    _previousPlatformHandler = null;
    _errorsAttached = false;
  }

  @override
  void dispose() {
    _detach();
    unawaited(recorder.dispose());
    super.dispose();
  }
}
