import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/src/diagnostics/diagnostic_settings_store.dart';

void main() {
  test('defaults to enabled when no preference exists', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = SharedPreferencesDiagnosticSettingsStore();

    expect(await store.loadEnabled(), isTrue);
  });

  test('persists an explicit disabled value', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = SharedPreferencesDiagnosticSettingsStore();

    await store.saveEnabled(false);

    expect(await store.loadEnabled(), isFalse);
  });
}
