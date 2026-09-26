import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class TelemetrySettingsStore {
  Future<bool> loadEnabled();

  Future<void> saveEnabled(bool value);
}

final class SharedPreferencesTelemetrySettingsStore
    implements TelemetrySettingsStore {
  const SharedPreferencesTelemetrySettingsStore();

  static const String _enabledKey = 'telemetry.anonymous_stats_enabled';

  @override
  Future<bool> loadEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_enabledKey) ?? true;
    } catch (error, stackTrace) {
      debugPrint(
        'Failed to load telemetry settings, falling back to enabled: $error\n$stackTrace',
      );
      return true;
    }
  }

  @override
  Future<void> saveEnabled(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, value);
    } catch (error, stackTrace) {
      debugPrint('Failed to save telemetry settings: $error\n$stackTrace');
    }
  }
}

final class MemoryTelemetrySettingsStore implements TelemetrySettingsStore {
  MemoryTelemetrySettingsStore([this.value = true]);

  bool value;

  @override
  Future<bool> loadEnabled() async => value;

  @override
  Future<void> saveEnabled(bool value) async => this.value = value;
}
