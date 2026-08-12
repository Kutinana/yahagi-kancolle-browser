import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum BattlePredictionMethod { poi, yahagi }

abstract interface class BattlePredictionSettingsStore {
  Future<BattlePredictionMethod> load();

  Future<void> save(BattlePredictionMethod method);
}

final class SharedPreferencesBattlePredictionSettingsStore
    implements BattlePredictionSettingsStore {
  static const String _key = 'battle.predictionMethod';

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
}

final class MemoryBattlePredictionSettingsStore
    implements BattlePredictionSettingsStore {
  MemoryBattlePredictionSettingsStore([
    this._method = BattlePredictionMethod.poi,
  ]);

  BattlePredictionMethod _method;

  @override
  Future<BattlePredictionMethod> load() async => _method;

  @override
  Future<void> save(BattlePredictionMethod method) async {
    _method = method;
  }
}

final class BattlePredictionSettingsController extends ChangeNotifier {
  BattlePredictionSettingsController._(this._store);

  final BattlePredictionSettingsStore _store;
  BattlePredictionMethod _method = BattlePredictionMethod.poi;

  BattlePredictionMethod get method => _method;

  static Future<BattlePredictionSettingsController> load(
    BattlePredictionSettingsStore store,
  ) async {
    final controller = BattlePredictionSettingsController._(store);
    controller._method = await store.load();
    return controller;
  }

  Future<void> setMethod(BattlePredictionMethod method) async {
    if (_method == method) return;
    await _store.save(method);
    _method = method;
    notifyListeners();
  }
}
