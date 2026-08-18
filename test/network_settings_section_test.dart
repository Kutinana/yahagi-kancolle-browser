import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/settings/network_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/network_settings_section.dart';
import 'package:yahagi_kancolle_browser/src/settings/network_settings_store.dart';

void main() {
  testWidgets('network settings omit VPN status row', (tester) async {
    final controller = NetworkSettingsController(store: _MemoryStore());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NetworkSettingsSection(
            controller: controller,
            onApplySuccess: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('VPN 状态'), findsNothing);
    expect(find.textContaining('已检测到活动 VPN'), findsNothing);
    expect(find.textContaining('未检测到活动 VPN'), findsNothing);
  });
}

final class _MemoryStore implements NetworkSettingsStore {
  @override
  Future<NetworkSettings> loadSettings() async => const NetworkSettings();

  @override
  Future<void> saveSettings(NetworkSettings settings) async {}
}
