import 'package:flutter/foundation.dart';

import '../fleet/ship_damage_level.dart';

enum BattleEffectDisplayScope { predictionOnly, fleetOnly, all }

enum BattleEffectSurface { prediction, fleet }

enum DamagePulseFilter { off, minorOnly, moderateOnly, heavyOnly, all }

enum DamageVibrationFilter { off, moderateOnly, heavyOnly, all }

extension BattleEffectDisplayScopeBehavior on BattleEffectDisplayScope {
  bool includes(BattleEffectSurface surface) => switch (this) {
    BattleEffectDisplayScope.predictionOnly =>
      surface == BattleEffectSurface.prediction,
    BattleEffectDisplayScope.fleetOnly => surface == BattleEffectSurface.fleet,
    BattleEffectDisplayScope.all => true,
  };
}

extension DamagePulseFilterBehavior on DamagePulseFilter {
  bool matches(ShipDamageLevel level) => switch (this) {
    DamagePulseFilter.off => false,
    DamagePulseFilter.minorOnly => level == ShipDamageLevel.minor,
    DamagePulseFilter.moderateOnly => level == ShipDamageLevel.moderate,
    DamagePulseFilter.heavyOnly => level == ShipDamageLevel.heavy,
    DamagePulseFilter.all =>
      level == ShipDamageLevel.minor ||
          level == ShipDamageLevel.moderate ||
          level == ShipDamageLevel.heavy,
  };
}

extension DamageVibrationFilterBehavior on DamageVibrationFilter {
  bool matches(ShipDamageLevel level) => switch (this) {
    DamageVibrationFilter.off => false,
    DamageVibrationFilter.moderateOnly => level == ShipDamageLevel.moderate,
    DamageVibrationFilter.heavyOnly => level == ShipDamageLevel.heavy,
    DamageVibrationFilter.all =>
      level == ShipDamageLevel.moderate || level == ShipDamageLevel.heavy,
  };
}

@immutable
class BattleStatusEffectSettings {
  const BattleStatusEffectSettings({
    this.enabled = true,
    this.displayScope = BattleEffectDisplayScope.all,
    this.damagePulseFilter = DamagePulseFilter.all,
    this.damageVibrationFilter = DamageVibrationFilter.all,
    this.moraleSparkleEnabled = true,
  });

  final bool enabled;
  final BattleEffectDisplayScope displayScope;
  final DamagePulseFilter damagePulseFilter;
  final DamageVibrationFilter damageVibrationFilter;
  final bool moraleSparkleEnabled;

  DamagePulseFilter pulseFilterFor(BattleEffectSurface surface) {
    if (!enabled || !displayScope.includes(surface)) {
      return DamagePulseFilter.off;
    }
    return damagePulseFilter;
  }

  bool sparkleEnabledFor(BattleEffectSurface surface) =>
      enabled && moraleSparkleEnabled && displayScope.includes(surface);

  bool vibrates(ShipDamageLevel level) =>
      enabled && damageVibrationFilter.matches(level);

  BattleStatusEffectSettings copyWith({
    bool? enabled,
    BattleEffectDisplayScope? displayScope,
    DamagePulseFilter? damagePulseFilter,
    DamageVibrationFilter? damageVibrationFilter,
    bool? moraleSparkleEnabled,
  }) {
    return BattleStatusEffectSettings(
      enabled: enabled ?? this.enabled,
      displayScope: displayScope ?? this.displayScope,
      damagePulseFilter: damagePulseFilter ?? this.damagePulseFilter,
      damageVibrationFilter:
          damageVibrationFilter ?? this.damageVibrationFilter,
      moraleSparkleEnabled: moraleSparkleEnabled ?? this.moraleSparkleEnabled,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BattleStatusEffectSettings &&
          enabled == other.enabled &&
          displayScope == other.displayScope &&
          damagePulseFilter == other.damagePulseFilter &&
          damageVibrationFilter == other.damageVibrationFilter &&
          moraleSparkleEnabled == other.moraleSparkleEnabled;

  @override
  int get hashCode => Object.hash(
    enabled,
    displayScope,
    damagePulseFilter,
    damageVibrationFilter,
    moraleSparkleEnabled,
  );
}
