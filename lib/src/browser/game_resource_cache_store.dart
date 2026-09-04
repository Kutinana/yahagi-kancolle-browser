import 'package:shared_preferences/shared_preferences.dart';

enum GameResourceCacheMode { temporary, full, light, none }

extension GameResourceCacheModeWire on GameResourceCacheMode {
  String get wireName => name;

  static GameResourceCacheMode fromWireName(String? value) {
    return switch (value) {
      'full' || 'light' => GameResourceCacheMode.full,
      'temporary' || 'none' || null => GameResourceCacheMode.temporary,
      _ => GameResourceCacheMode.temporary,
    };
  }
}

abstract interface class GameResourceCacheStore {
  Future<GameResourceCacheMode> load();
  Future<void> save(GameResourceCacheMode value);
}

final class SharedPreferencesGameResourceCacheStore
    implements GameResourceCacheStore {
  static const String preferenceKey = 'game_resource_cache_mode';

  @override
  Future<GameResourceCacheMode> load() async {
    final preferences = await SharedPreferences.getInstance();
    return GameResourceCacheModeWire.fromWireName(
      preferences.getString(preferenceKey),
    );
  }

  @override
  Future<void> save(GameResourceCacheMode value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(preferenceKey, value.wireName);
  }
}
