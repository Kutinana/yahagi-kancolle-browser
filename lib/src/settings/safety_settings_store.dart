import 'package:shared_preferences/shared_preferences.dart';

import 'battle_status_effect_settings.dart';

enum BattleWarningMode { off, confirm }

abstract class SafetySettingsStore {
  Future<BattleWarningMode> loadWarningMode();
  Future<void> saveWarningMode(BattleWarningMode mode);
  Future<BattleStatusEffectSettings> loadBattleStatusEffects();
  Future<void> saveBattleStatusEffects(BattleStatusEffectSettings settings);
  Future<bool> loadBattleDamageVibrationEnabled();
  Future<void> saveBattleDamageVibrationEnabled(bool enabled);
}

class SharedPreferencesSafetySettingsStore implements SafetySettingsStore {
  static const String _modeKey = 'safety.battleWarningMode';
  static const String _damageVibrationKey = 'battle.damageVibrationEnabled';
  static const String _statusEffectsEnabledKey = 'battle.statusEffects.enabled';
  static const String _displayScopeKey = 'battle.statusEffects.displayScope';
  static const String _damagePulseFilterKey =
      'battle.statusEffects.damagePulseFilter';
  static const String _damageVibrationFilterKey =
      'battle.statusEffects.damageVibrationFilter';
  static const String _moraleSparkleEnabledKey =
      'battle.statusEffects.moraleSparkleEnabled';

  @override
  Future<BattleWarningMode> loadWarningMode() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_modeKey);
    return BattleWarningMode.values.firstWhere(
      (e) => e.name == value,
      orElse: () => BattleWarningMode.confirm,
    );
  }

  @override
  Future<void> saveWarningMode(BattleWarningMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, mode.name);
  }

  @override
  Future<BattleStatusEffectSettings> loadBattleStatusEffects() async {
    final prefs = await SharedPreferences.getInstance();
    final legacyVibrationEnabled = prefs.getBool(_damageVibrationKey) ?? true;
    return BattleStatusEffectSettings(
      enabled: prefs.getBool(_statusEffectsEnabledKey) ?? true,
      displayScope: _enumByName(
        BattleEffectDisplayScope.values,
        prefs.getString(_displayScopeKey),
        BattleEffectDisplayScope.all,
      ),
      damagePulseFilter: _enumByName(
        DamagePulseFilter.values,
        prefs.getString(_damagePulseFilterKey),
        DamagePulseFilter.all,
      ),
      damageVibrationFilter: _enumByName(
        DamageVibrationFilter.values,
        prefs.getString(_damageVibrationFilterKey),
        legacyVibrationEnabled
            ? DamageVibrationFilter.all
            : DamageVibrationFilter.off,
      ),
      moraleSparkleEnabled: prefs.getBool(_moraleSparkleEnabledKey) ?? true,
    );
  }

  @override
  Future<void> saveBattleStatusEffects(
    BattleStatusEffectSettings settings,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait(<Future<bool>>[
      prefs.setBool(_statusEffectsEnabledKey, settings.enabled),
      prefs.setString(_displayScopeKey, settings.displayScope.name),
      prefs.setString(_damagePulseFilterKey, settings.damagePulseFilter.name),
      prefs.setString(
        _damageVibrationFilterKey,
        settings.damageVibrationFilter.name,
      ),
      prefs.setBool(_moraleSparkleEnabledKey, settings.moraleSparkleEnabled),
    ]);
  }

  @override
  Future<bool> loadBattleDamageVibrationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_damageVibrationKey) ?? true;
  }

  @override
  Future<void> saveBattleDamageVibrationEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_damageVibrationKey, enabled);
  }
}

class MemorySafetySettingsStore implements SafetySettingsStore {
  MemorySafetySettingsStore({
    BattleStatusEffectSettings battleStatusEffects =
        const BattleStatusEffectSettings(),
  }) : _battleStatusEffects = battleStatusEffects;

  BattleWarningMode _mode = BattleWarningMode.confirm;
  bool _damageVibrationEnabled = true;
  BattleStatusEffectSettings _battleStatusEffects;

  @override
  Future<BattleWarningMode> loadWarningMode() async => _mode;

  @override
  Future<void> saveWarningMode(BattleWarningMode mode) async {
    _mode = mode;
  }

  @override
  Future<BattleStatusEffectSettings> loadBattleStatusEffects() async =>
      _battleStatusEffects;

  @override
  Future<void> saveBattleStatusEffects(
    BattleStatusEffectSettings settings,
  ) async {
    _battleStatusEffects = settings;
    _damageVibrationEnabled =
        settings.damageVibrationFilter != DamageVibrationFilter.off;
  }

  @override
  Future<bool> loadBattleDamageVibrationEnabled() async =>
      _damageVibrationEnabled;

  @override
  Future<void> saveBattleDamageVibrationEnabled(bool enabled) async {
    _damageVibrationEnabled = enabled;
    _battleStatusEffects = _battleStatusEffects.copyWith(
      damageVibrationFilter: enabled
          ? DamageVibrationFilter.all
          : DamageVibrationFilter.off,
    );
  }
}

T _enumByName<T extends Enum>(List<T> values, String? name, T fallback) {
  for (final value in values) {
    if (value.name == name) {
      return value;
    }
  }
  return fallback;
}
