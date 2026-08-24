import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_resource_cache_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_connector.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_connector_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('connector switches preserve the local cache mode', () async {
    final cacheStore = SharedPreferencesGameResourceCacheStore();
    final connectorStore = SharedPreferencesGameConnectorStore();
    await cacheStore.save(GameResourceCacheMode.full);
    final controller = await GameConnectorController.load(connectorStore);
    addTearDown(controller.dispose);

    expect(
      await controller.change(GameConnector.ooi),
      GameConnectorChangeResult.applied,
    );
    expect(await cacheStore.load(), GameResourceCacheMode.full);

    expect(
      await controller.change(GameConnector.yahagi),
      GameConnectorChangeResult.applied,
    );
    expect(await cacheStore.load(), GameResourceCacheMode.full);
  });

  test('changing the cache mode preserves the selected connector', () async {
    final cacheStore = SharedPreferencesGameResourceCacheStore();
    final connectorStore = SharedPreferencesGameConnectorStore();
    await connectorStore.save(GameConnector.ooi);

    await cacheStore.save(GameResourceCacheMode.none);
    expect(await connectorStore.load(), GameConnector.ooi);
    await cacheStore.save(GameResourceCacheMode.full);
    expect(await connectorStore.load(), GameConnector.ooi);
  });
}
