import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/settings/battle_settings_page.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_store.dart';

void main() {
  testWidgets('battle settings put severe damage alert first', (tester) async {
    final safety = await SafetySettingsController.load(
      MemorySafetySettingsStore(),
    );

    await tester.pumpWidget(
      MaterialApp(home: BattleSettingsPage(safetySettingsController: safety)),
    );

    expect(find.byKey(const Key('diagnosticLoggingSwitch')), findsNothing);
    expect(find.text('大破提醒'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('大破提醒')).dy,
      lessThan(tester.getTopLeft(find.text('战斗状态效果')).dy),
    );
  });
}
