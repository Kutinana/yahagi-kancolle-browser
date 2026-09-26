import 'package:flutter/foundation.dart';

import 'telemetry_service.dart';
import 'telemetry_settings_store.dart';

final class TelemetryController extends ChangeNotifier {
  TelemetryController({
    required this.store,
    required this.service,
    bool initialEnabled = true,
  }) : _enabled = initialEnabled;

  final TelemetrySettingsStore store;
  final TelemetryService service;
  bool _enabled;
  bool _disposed = false;
  int _operationVersion = 0;
  Future<void> _pendingSave = Future<void>.value();

  bool get enabled => _enabled;
  bool get isDisposed => _disposed;

  /// Starts the telemetry service if the user has enabled telemetry and the controller is not disposed.
  Future<void> startIfEnabled() async {
    if (_disposed || !_enabled) return;
    await service.start();
  }

  Future<void> setEnabled(bool value) async {
    if (_disposed || _enabled == value) return;
    _enabled = value;
    final opVersion = ++_operationVersion;
    if (!value) service.stop();
    // Keep durable preferences in the same order as the user's toggles.
    final saving = _pendingSave = _pendingSave.then((_) async {
      try {
        await store.saveEnabled(value);
      } catch (_) {
        // A storage failure must not prevent later preference writes.
      }
    });
    notifyListeners();
    await saving;

    if (_disposed || opVersion != _operationVersion) {
      return;
    }

    if (_enabled) {
      await service.start();
    }
  }

  static Future<TelemetryController> create({
    required TelemetrySettingsStore store,
    required TelemetryService service,
  }) async {
    final enabled = await store.loadEnabled();
    return TelemetryController(
      store: store,
      service: service,
      initialEnabled: enabled,
    );
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    service.dispose();
    super.dispose();
  }
}
