import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/fleet/ship_damage_level.dart';
import 'package:yahagi_kancolle_browser/src/settings/battle_status_effect_settings.dart';

void main() {
  test('defaults preserve all existing status effects on both surfaces', () {
    const settings = BattleStatusEffectSettings();

    expect(settings.enabled, isTrue);
    expect(settings.displayScope, BattleEffectDisplayScope.all);
    expect(
      settings.pulseFilterFor(BattleEffectSurface.prediction),
      DamagePulseFilter.all,
    );
    expect(
      settings.pulseFilterFor(BattleEffectSurface.fleet),
      DamagePulseFilter.all,
    );
    expect(settings.sparkleEnabledFor(BattleEffectSurface.prediction), isTrue);
    expect(settings.sparkleEnabledFor(BattleEffectSurface.fleet), isTrue);
    expect(settings.vibrates(ShipDamageLevel.moderate), isTrue);
    expect(settings.vibrates(ShipDamageLevel.heavy), isTrue);
  });

  test('display scope controls pulse and sparkle but never vibration', () {
    const settings = BattleStatusEffectSettings(
      displayScope: BattleEffectDisplayScope.predictionOnly,
      damageVibrationFilter: DamageVibrationFilter.heavyOnly,
    );

    expect(
      settings.pulseFilterFor(BattleEffectSurface.prediction),
      DamagePulseFilter.all,
    );
    expect(
      settings.pulseFilterFor(BattleEffectSurface.fleet),
      DamagePulseFilter.off,
    );
    expect(settings.sparkleEnabledFor(BattleEffectSurface.prediction), isTrue);
    expect(settings.sparkleEnabledFor(BattleEffectSurface.fleet), isFalse);
    expect(settings.vibrates(ShipDamageLevel.heavy), isTrue);
  });

  test('master switch disables pulse sparkle and vibration together', () {
    const settings = BattleStatusEffectSettings(enabled: false);

    expect(
      settings.pulseFilterFor(BattleEffectSurface.prediction),
      DamagePulseFilter.off,
    );
    expect(
      settings.pulseFilterFor(BattleEffectSurface.fleet),
      DamagePulseFilter.off,
    );
    expect(settings.sparkleEnabledFor(BattleEffectSurface.prediction), isFalse);
    expect(settings.vibrates(ShipDamageLevel.heavy), isFalse);
  });

  test('only filters match the selected final damage band exactly', () {
    expect(DamagePulseFilter.minorOnly.matches(ShipDamageLevel.minor), isTrue);
    expect(
      DamagePulseFilter.minorOnly.matches(ShipDamageLevel.moderate),
      isFalse,
    );
    expect(
      DamagePulseFilter.moderateOnly.matches(ShipDamageLevel.moderate),
      isTrue,
    );
    expect(
      DamagePulseFilter.moderateOnly.matches(ShipDamageLevel.heavy),
      isFalse,
    );
    expect(DamagePulseFilter.heavyOnly.matches(ShipDamageLevel.heavy), isTrue);
    expect(DamagePulseFilter.all.matches(ShipDamageLevel.healthy), isFalse);

    expect(
      DamageVibrationFilter.moderateOnly.matches(ShipDamageLevel.moderate),
      isTrue,
    );
    expect(
      DamageVibrationFilter.moderateOnly.matches(ShipDamageLevel.heavy),
      isFalse,
    );
    expect(
      DamageVibrationFilter.heavyOnly.matches(ShipDamageLevel.heavy),
      isTrue,
    );
    expect(DamageVibrationFilter.all.matches(ShipDamageLevel.minor), isFalse);
  });

  test('morale sparkle switch does not change damage effects', () {
    const settings = BattleStatusEffectSettings(moraleSparkleEnabled: false);

    expect(settings.sparkleEnabledFor(BattleEffectSurface.fleet), isFalse);
    expect(
      settings.pulseFilterFor(BattleEffectSurface.fleet),
      DamagePulseFilter.all,
    );
    expect(settings.vibrates(ShipDamageLevel.heavy), isTrue);
  });

  test('copyWith produces an independent immutable value', () {
    const settings = BattleStatusEffectSettings();
    final updated = settings.copyWith(
      displayScope: BattleEffectDisplayScope.fleetOnly,
      damagePulseFilter: DamagePulseFilter.moderateOnly,
      damageVibrationFilter: DamageVibrationFilter.off,
      moraleSparkleEnabled: false,
    );

    expect(updated.displayScope, BattleEffectDisplayScope.fleetOnly);
    expect(updated.damagePulseFilter, DamagePulseFilter.moderateOnly);
    expect(updated.damageVibrationFilter, DamageVibrationFilter.off);
    expect(updated.moraleSparkleEnabled, isFalse);
    expect(settings, const BattleStatusEffectSettings());
  });
}
