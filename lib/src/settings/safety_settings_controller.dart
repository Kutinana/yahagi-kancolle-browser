import 'package:flutter/foundation.dart';

import 'battle_status_effect_settings.dart';
import 'safety_settings_store.dart';

class SafetySettingsController extends ChangeNotifier {
  SafetySettingsController._(this._store);

  final SafetySettingsStore _store;
  late BattleWarningMode _battleWarningMode;
  late BattleStatusEffectSettings _battleStatusEffects;

  BattleWarningMode get battleWarningMode => _battleWarningMode;
  BattleStatusEffectSettings get battleStatusEffects => _battleStatusEffects;
  bool get battleDamageVibrationEnabled =>
      _battleStatusEffects.damageVibrationFilter != DamageVibrationFilter.off;

  static Future<SafetySettingsController> load(
    SafetySettingsStore store,
  ) async {
    final controller = SafetySettingsController._(store);
    await controller.loadSettings();
    return controller;
  }

  Future<void> loadSettings() async {
    _battleWarningMode = await _store.loadWarningMode();
    _battleStatusEffects = await _store.loadBattleStatusEffects();
    notifyListeners();
  }

  Future<void> setBattleWarningMode(BattleWarningMode mode) async {
    if (_battleWarningMode == mode) return;
    _battleWarningMode = mode;
    notifyListeners();
    await _store.saveWarningMode(mode);
  }

  Future<void> setBattleDamageVibrationEnabled(bool enabled) async {
    await setDamageVibrationFilter(
      enabled ? DamageVibrationFilter.all : DamageVibrationFilter.off,
    );
  }

  Future<void> setBattleStatusEffects(
    BattleStatusEffectSettings settings,
  ) async {
    if (_battleStatusEffects == settings) return;
    _battleStatusEffects = settings;
    notifyListeners();
    await _store.saveBattleStatusEffects(settings);
  }

  Future<void> setBattleStatusEffectsEnabled(bool enabled) =>
      setBattleStatusEffects(_battleStatusEffects.copyWith(enabled: enabled));

  Future<void> setBattleEffectDisplayScope(BattleEffectDisplayScope scope) =>
      setBattleStatusEffects(
        _battleStatusEffects.copyWith(displayScope: scope),
      );

  Future<void> setDamagePulseFilter(DamagePulseFilter filter) =>
      setBattleStatusEffects(
        _battleStatusEffects.copyWith(damagePulseFilter: filter),
      );

  Future<void> setDamageVibrationFilter(DamageVibrationFilter filter) =>
      setBattleStatusEffects(
        _battleStatusEffects.copyWith(damageVibrationFilter: filter),
      );

  Future<void> setMoraleSparkleEnabled(bool enabled) => setBattleStatusEffects(
    _battleStatusEffects.copyWith(moraleSparkleEnabled: enabled),
  );
}
