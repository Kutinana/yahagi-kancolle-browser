import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game_connector.dart';

abstract interface class GameConnectorStore {
  Future<GameConnector> load();

  Future<void> save(GameConnector connector);
}

final class SharedPreferencesGameConnectorStore implements GameConnectorStore {
  static const _key = 'game.connector';

  @override
  Future<GameConnector> load() async {
    final preferences = await SharedPreferences.getInstance();
    return GameConnectorCodec.decode(preferences.getString(_key));
  }

  @override
  Future<void> save(GameConnector connector) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(_key, connector.storageName);
    if (!saved) throw StateError('Unable to save game connector');
  }
}

final class MemoryGameConnectorStore implements GameConnectorStore {
  MemoryGameConnectorStore([this.value = GameConnector.yahagi]);

  GameConnector value;

  @override
  Future<GameConnector> load() async => value;

  @override
  Future<void> save(GameConnector connector) async => value = connector;
}

enum GameConnectorChangeResult { unchanged, applied, busy, saveFailed }

final class GameConnectorController extends ChangeNotifier {
  GameConnectorController._(this._store, this._connector);

  final GameConnectorStore _store;
  GameConnector _connector;
  bool _busy = false;
  bool _disposed = false;

  GameConnector get connector => _connector;
  bool get isBusy => _busy;

  static Future<GameConnectorController> load(GameConnectorStore store) async {
    return GameConnectorController._(store, await store.load());
  }

  Future<GameConnectorChangeResult> change(GameConnector target) async {
    if (_busy) return GameConnectorChangeResult.busy;
    if (target == _connector) return GameConnectorChangeResult.unchanged;
    _busy = true;
    _notify();
    try {
      await _store.save(target);
      _connector = target;
      return GameConnectorChangeResult.applied;
    } catch (_) {
      return GameConnectorChangeResult.saveFailed;
    } finally {
      _busy = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
