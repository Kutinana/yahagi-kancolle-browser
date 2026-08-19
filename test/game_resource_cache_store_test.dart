import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_resource_cache_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('defaults to no local cache', () async {
    final store = SharedPreferencesGameResourceCacheStore();

    expect(await store.load(), GameResourceCacheMode.none);
  });

  test('persists all cache modes by stable wire name', () async {
    final store = SharedPreferencesGameResourceCacheStore();

    for (final mode in const <GameResourceCacheMode>[
      GameResourceCacheMode.none,
      GameResourceCacheMode.full,
    ]) {
      await store.save(mode);
      expect(await store.load(), mode);
      expect(GameResourceCacheModeWire.fromWireName(mode.wireName), mode);
    }
    expect(
      GameResourceCacheModeWire.fromWireName('light'),
      GameResourceCacheMode.full,
    );
  });
}
