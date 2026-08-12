import 'package:shared_preferences/shared_preferences.dart';

abstract interface class DiagnosticSettingsStore {
  Future<bool> loadEnabled();

  Future<void> saveEnabled(bool value);
}

final class SharedPreferencesDiagnosticSettingsStore
    implements DiagnosticSettingsStore {
  static const String _enabledKey = 'diagnostics.enabled';

  @override
  Future<bool> loadEnabled() async =>
      (await SharedPreferences.getInstance()).getBool(_enabledKey) ?? true;

  @override
  Future<void> saveEnabled(bool value) async {
    await (await SharedPreferences.getInstance()).setBool(_enabledKey, value);
  }
}

final class MemoryDiagnosticSettingsStore implements DiagnosticSettingsStore {
  MemoryDiagnosticSettingsStore([this.value = true]);

  bool value;

  @override
  Future<bool> loadEnabled() async => value;

  @override
  Future<void> saveEnabled(bool value) async => this.value = value;
}
