import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum BattlePredictionMethod { poi, yahagi }

abstract interface class BattlePredictionSettingsStore {
  Future<BattlePredictionMethod> load();

  Future<void> save(BattlePredictionMethod method);

  Future<bool> loadEnemyPortraitsEnabled();

  Future<void> saveEnemyPortraitsEnabled(bool enabled);
}

final class SharedPreferencesBattlePredictionSettingsStore
    implements BattlePredictionSettingsStore {
  static const String _key = 'battle.predictionMethod';
  static const String _enemyPortraitsKey =
      'battle.enemyPreviewPortraitsEnabled';

  @override
  Future<BattlePredictionMethod> load() async {
    final value = (await SharedPreferences.getInstance()).getString(_key);
    return BattlePredictionMethod.values.firstWhere(
      (method) => method.name == value,
      orElse: () => BattlePredictionMethod.poi,
    );
  }

  @override
  Future<void> save(BattlePredictionMethod method) async {
    final saved = await (await SharedPreferences.getInstance()).setString(
      _key,
      method.name,
    );
    if (!saved) throw StateError('battle prediction setting was not saved');
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
}

final class MemoryBattlePredictionSettingsStore
    implements BattlePredictionSettingsStore {
  MemoryBattlePredictionSettingsStore([
    this._method = BattlePredictionMethod.poi,
    this._enemyPortraitsEnabled = true,
  ]);

  BattlePredictionMethod _method;
  bool _enemyPortraitsEnabled;

  @override
  Future<BattlePredictionMethod> load() async => _method;

  @override
  Future<void> save(BattlePredictionMethod method) async {
    _method = method;
  }

  @override
  Future<bool> loadEnemyPortraitsEnabled() async => _enemyPortraitsEnabled;

  @override
  Future<void> saveEnemyPortraitsEnabled(bool enabled) async {
    _enemyPortraitsEnabled = enabled;
  }
}

final class BattlePredictionSettingsController extends ChangeNotifier {
  BattlePredictionSettingsController._(this._store);

  final BattlePredictionSettingsStore _store;
  BattlePredictionMethod _method = BattlePredictionMethod.poi;
  bool _enemyPortraitsEnabled = true;

  BattlePredictionMethod get method => _method;
  bool get enemyPortraitsEnabled => _enemyPortraitsEnabled;

  static Future<BattlePredictionSettingsController> load(
    BattlePredictionSettingsStore store,
  ) async {
    final controller = BattlePredictionSettingsController._(store);
    controller._method = await store.load();
    controller._enemyPortraitsEnabled = await store.loadEnemyPortraitsEnabled();
    return controller;
  }

  Future<void> setMethod(BattlePredictionMethod method) async {
    if (_method == method) return;
    await _store.save(method);
    _method = method;
    notifyListeners();
  }

  Future<void> setEnemyPortraitsEnabled(bool enabled) async {
    if (_enemyPortraitsEnabled == enabled) return;
    await _store.saveEnemyPortraitsEnabled(enabled);
    _enemyPortraitsEnabled = enabled;
    notifyListeners();
  }
}
