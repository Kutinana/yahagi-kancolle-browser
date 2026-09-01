import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/settings/battle_settings_page.dart';
import 'package:yahagi_kancolle_browser/src/settings/battle_status_effect_settings.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_store.dart';

void main() {
  testWidgets('battle settings show the approved status effect controls', (
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

    expect(find.text('大破提醒'), findsOneWidget);
    expect(find.text('大破进击保护'), findsOneWidget);
    expect(find.text('战斗状态效果'), findsOneWidget);
    expect(find.text('启用状态效果'), findsOneWidget);
    expect(find.text('画面显示范围'), findsOneWidget);
    expect(find.text('受损闪烁'), findsOneWidget);
    expect(find.text('受损震动'), findsOneWidget);
    expect(find.text('士气闪光效果'), findsOneWidget);
    expect(find.text('战斗受损震动提醒'), findsNothing);

    expect(
      find.byKey(const Key('battleStatusEffectsMasterSwitch')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('damagePulseFilterDropdown')), findsOneWidget);
    expect(find.byKey(const Key('battleEffectScopeDropdown')), findsOneWidget);
    expect(
      find.byKey(const Key('damageVibrationFilterDropdown')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('moraleSparkleSwitch')), findsOneWidget);
  });

  testWidgets('master switch disables children without changing their values', (
    tester,
  ) async {
    final controller = await SafetySettingsController.load(
      MemorySafetySettingsStore(
        battleStatusEffects: const BattleStatusEffectSettings(
          displayScope: BattleEffectDisplayScope.fleetOnly,
          damagePulseFilter: DamagePulseFilter.minorOnly,
          damageVibrationFilter: DamageVibrationFilter.heavyOnly,
          moraleSparkleEnabled: false,
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BattleSettingsPage(safetySettingsController: controller),
      ),
    );

    await tester.tap(find.byKey(const Key('battleStatusEffectsMasterSwitch')));
    await tester.pump();

    expect(controller.battleStatusEffects.enabled, isFalse);
    expect(
      controller.battleStatusEffects.displayScope,
      BattleEffectDisplayScope.fleetOnly,
    );
    expect(
      controller.battleStatusEffects.damagePulseFilter,
      DamagePulseFilter.minorOnly,
    );
    expect(
      controller.battleStatusEffects.damageVibrationFilter,
      DamageVibrationFilter.heavyOnly,
    );
    expect(controller.battleStatusEffects.moraleSparkleEnabled, isFalse);

    final pulseDropdown = tester.widget<DropdownButton<DamagePulseFilter>>(
      find.byKey(const Key('damagePulseFilterDropdown')),
    );
    final vibrationDropdown = tester
        .widget<DropdownButton<DamageVibrationFilter>>(
          find.byKey(const Key('damageVibrationFilterDropdown')),
        );
    final moraleSwitch = tester.widget<Switch>(
      find.byKey(const Key('moraleSparkleSwitch')),
    );
    expect(pulseDropdown.onChanged, isNull);
    expect(vibrationDropdown.onChanged, isNull);
    expect(moraleSwitch.onChanged, isNull);
  });

  testWidgets('scope and filter controls update independent fields', (
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

    final scopeDropdown = tester
        .widget<DropdownButton<BattleEffectDisplayScope>>(
          find.byKey(const Key('battleEffectScopeDropdown')),
        );
    scopeDropdown.onChanged!(BattleEffectDisplayScope.predictionOnly);
    await tester.pump();
    expect(
      controller.battleStatusEffects.displayScope,
      BattleEffectDisplayScope.predictionOnly,
    );

    final pulseDropdown = tester.widget<DropdownButton<DamagePulseFilter>>(
      find.byKey(const Key('damagePulseFilterDropdown')),
    );
    pulseDropdown.onChanged!(DamagePulseFilter.moderateOnly);
    await tester.pump();
    final vibrationDropdown = tester
        .widget<DropdownButton<DamageVibrationFilter>>(
          find.byKey(const Key('damageVibrationFilterDropdown')),
        );
    vibrationDropdown.onChanged!(DamageVibrationFilter.heavyOnly);
    await tester.pump();

    expect(
      controller.battleStatusEffects.damagePulseFilter,
      DamagePulseFilter.moderateOnly,
    );
    expect(
      controller.battleStatusEffects.damageVibrationFilter,
      DamageVibrationFilter.heavyOnly,
    );
  });
}
