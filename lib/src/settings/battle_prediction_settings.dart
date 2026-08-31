import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class BattlePredictionSettingsStore {
  Future<void> initialize();

  Future<bool> loadEnemyPortraitsEnabled();

  Future<void> saveEnemyPortraitsEnabled(bool enabled);

  Future<bool> loadLastFormationHintEnabled();

  Future<void> saveLastFormationHintEnabled(bool enabled);
}

final class SharedPreferencesBattlePredictionSettingsStore
    implements BattlePredictionSettingsStore {
  static const String _legacyPredictionMethodKey = 'battle.predictionMethod';
  static const String _enemyPortraitsKey =
      'battle.enemyPreviewPortraitsEnabled';
  static const String _lastFormationHintKey = 'battle.lastFormationHintEnabled';

  @override
  Future<void> initialize() async {
    await (await SharedPreferences.getInstance()).remove(
      _legacyPredictionMethodKey,
    );
  }

  @override
  Future<bool> loadEnemyPortraitsEnabled() async {
    return (await SharedPreferences.getInstance()).getBool(
          _enemyPortraitsKey,
        ) ??
        true;
  }

  @override
  Future<void> saveEnemyPortraitsEnabled(bool enabled) async {
    final saved = await (await SharedPreferences.getInstance()).setBool(
      _enemyPortraitsKey,
      enabled,
    );
    if (!saved) throw StateError('enemy portrait setting was not saved');
  }

  @override
  Future<bool> loadLastFormationHintEnabled() async {
    return (await SharedPreferences.getInstance()).getBool(
          _lastFormationHintKey,
        ) ??
        true;
  }

  @override
  Future<void> saveLastFormationHintEnabled(bool enabled) async {
    final saved = await (await SharedPreferences.getInstance()).setBool(
      _lastFormationHintKey,
      enabled,
    );
    if (!saved) throw StateError('last formation hint setting was not saved');
  }
}

final class MemoryBattlePredictionSettingsStore
    implements BattlePredictionSettingsStore {
  MemoryBattlePredictionSettingsStore([
    this._enemyPortraitsEnabled = true,
    this._lastFormationHintEnabled = true,
  ]);

  bool _enemyPortraitsEnabled;
  bool _lastFormationHintEnabled;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> loadEnemyPortraitsEnabled() async => _enemyPortraitsEnabled;

  @override
  Future<void> saveEnemyPortraitsEnabled(bool enabled) async {
    _enemyPortraitsEnabled = enabled;
  }

  @override
  Future<bool> loadLastFormationHintEnabled() async =>
      _lastFormationHintEnabled;

  @override
  Future<void> saveLastFormationHintEnabled(bool enabled) async {
    _lastFormationHintEnabled = enabled;
  }
}

final class BattlePredictionSettingsController extends ChangeNotifier {
  BattlePredictionSettingsController._(this._store);

  final BattlePredictionSettingsStore _store;
  bool _enemyPortraitsEnabled = true;
  bool _lastFormationHintEnabled = true;

  bool get enemyPortraitsEnabled => _enemyPortraitsEnabled;
  bool get lastFormationHintEnabled => _lastFormationHintEnabled;

  static Future<BattlePredictionSettingsController> load(
    BattlePredictionSettingsStore store,
  ) async {
    final controller = BattlePredictionSettingsController._(store);
    try {
      await store.initialize();
    } catch (_) {
      // A stale engine preference must never block the remaining settings.
    }
    controller._enemyPortraitsEnabled = await store.loadEnemyPortraitsEnabled();
    controller._lastFormationHintEnabled = await store
        .loadLastFormationHintEnabled();
    return controller;
  }

  Future<void> setEnemyPortraitsEnabled(bool enabled) async {
    if (_enemyPortraitsEnabled == enabled) return;
    await _store.saveEnemyPortraitsEnabled(enabled);
    _enemyPortraitsEnabled = enabled;
    notifyListeners();
  }

  Future<void> setLastFormationHintEnabled(bool enabled) async {
    if (_lastFormationHintEnabled == enabled) return;
    await _store.saveLastFormationHintEnabled(enabled);
    _lastFormationHintEnabled = enabled;
    notifyListeners();
  }
}
