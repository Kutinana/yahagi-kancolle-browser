import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/src/settings/battle_status_effect_settings.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_store.dart';

void main() {
  test(
    'battle status effects default to the backwards-compatible all state',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});

      final controller = await SafetySettingsController.load(
        SharedPreferencesSafetySettingsStore(),
      );

      expect(
        controller.battleStatusEffects,
        const BattleStatusEffectSettings(),
      );
    },
  );

  test('battle status effect choices persist as enum names', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    var controller = await SafetySettingsController.load(
      SharedPreferencesSafetySettingsStore(),
    );

    await controller.setBattleStatusEffects(
      const BattleStatusEffectSettings(
        enabled: false,
        displayScope: BattleEffectDisplayScope.fleetOnly,
        damagePulseFilter: DamagePulseFilter.moderateOnly,
        damageVibrationFilter: DamageVibrationFilter.heavyOnly,
        moraleSparkleEnabled: false,
      ),
    );
    controller = await SafetySettingsController.load(
      SharedPreferencesSafetySettingsStore(),
    );

    expect(
      controller.battleStatusEffects,
      const BattleStatusEffectSettings(
        enabled: false,
        displayScope: BattleEffectDisplayScope.fleetOnly,
        damagePulseFilter: DamagePulseFilter.moderateOnly,
        damageVibrationFilter: DamageVibrationFilter.heavyOnly,
        moraleSparkleEnabled: false,
      ),
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('battle.statusEffects.displayScope'), 'fleetOnly');
    expect(
      prefs.getString('battle.statusEffects.damagePulseFilter'),
      'moderateOnly',
    );
  });

  test('legacy disabled vibration migrates to the off filter', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'battle.damageVibrationEnabled': false,
      'layout_enhanced_damage_pulse': false,
    });

    final controller = await SafetySettingsController.load(
      SharedPreferencesSafetySettingsStore(),
    );

    expect(
      controller.battleStatusEffects.damageVibrationFilter,
      DamageVibrationFilter.off,
    );
    expect(
      controller.battleStatusEffects.damagePulseFilter,
      DamagePulseFilter.all,
    );
  });

  test('new values take priority over legacy booleans', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'battle.damageVibrationEnabled': false,
      'battle.statusEffects.damageVibrationFilter': 'moderateOnly',
      'battle.statusEffects.damagePulseFilter': 'heavyOnly',
    });

    final controller = await SafetySettingsController.load(
      SharedPreferencesSafetySettingsStore(),
    );

    expect(
      controller.battleStatusEffects.damageVibrationFilter,
      DamageVibrationFilter.moderateOnly,
    );
    expect(
      controller.battleStatusEffects.damagePulseFilter,
      DamagePulseFilter.heavyOnly,
    );
  });

  test('controller field setters preserve unrelated choices', () async {
    final controller = await SafetySettingsController.load(
      MemorySafetySettingsStore(),
    );

    await controller.setBattleEffectDisplayScope(
      BattleEffectDisplayScope.predictionOnly,
    );
    await controller.setDamagePulseFilter(DamagePulseFilter.minorOnly);
    await controller.setDamageVibrationFilter(
      DamageVibrationFilter.moderateOnly,
    );
    await controller.setMoraleSparkleEnabled(false);
    await controller.setBattleStatusEffectsEnabled(false);

    expect(
      controller.battleStatusEffects,
      const BattleStatusEffectSettings(
        enabled: false,
        displayScope: BattleEffectDisplayScope.predictionOnly,
        damagePulseFilter: DamagePulseFilter.minorOnly,
        damageVibrationFilter: DamageVibrationFilter.moderateOnly,
        moraleSparkleEnabled: false,
      ),
    );
  });
}
