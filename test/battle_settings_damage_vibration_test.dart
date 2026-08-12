import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/settings/battle_settings_page.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_store.dart';

void main() {
  testWidgets('battle settings can disable damage vibration alerts', (
    tester,
  ) async {
    final controller = await SafetySettingsController.load(
      MemorySafetySettingsStore(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BattleSettingsPage(safetySettingsController: controller),
      ),
    );

    expect(find.text('战斗受损震动提醒'), findsOneWidget);
    expect(controller.battleDamageVibrationEnabled, isTrue);

    await tester.tap(find.byType(Switch).first);
    await tester.pump();

    expect(controller.battleDamageVibrationEnabled, isFalse);
  });
}
