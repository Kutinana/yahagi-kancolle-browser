import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/enemy_catalog.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/enemy_catalog_store.dart';

import 'enemy_catalog_test.dart' show enemyCatalogFixture;

void main() {
  test('loads newer cached catalog and rejects a corrupt cache', () async {
    final directory = await Directory.systemTemp.createTemp('enemy-store-');
    addTearDown(() => directory.delete(recursive: true));
    final cache = File(
      '${directory.path}${Platform.pathSeparator}catalog.json',
    );
    final bundled = enemyCatalogFixture.replaceFirst(
      '"revision": 7',
      '"revision": 6',
    );
    final store = FileEnemyCatalogStore(
      cacheFile: cache,
      bundledReader: () async => bundled,
    );

    await store.save(EnemyCatalogData.fromJsonString(enemyCatalogFixture));
    expect((await store.loadBestAvailable()).revision, 7);

    await cache.writeAsString('{broken');
    expect((await store.loadBestAvailable()).revision, 6);
  });

  test('recovers the valid backup after a torn cache commit', () async {
    final directory = await Directory.systemTemp.createTemp('enemy-store-');
    addTearDown(() => directory.delete(recursive: true));
    final cache = File(
      '${directory.path}${Platform.pathSeparator}catalog.json',
    );
    final backup = File('${cache.path}.bak');
    final bundled = enemyCatalogFixture.replaceFirst(
      '"revision": 7',
      '"revision": 6',
    );
    await cache.writeAsString('{torn');
    await backup.writeAsString(enemyCatalogFixture);
    final store = FileEnemyCatalogStore(
      cacheFile: cache,
      bundledReader: () async => bundled,
    );

    final loaded = await store.loadBestAvailable();

    expect(loaded.revision, 7);
    expect(
      EnemyCatalogData.fromJsonString(await cache.readAsString()).revision,
      7,
    );
    expect(await backup.exists(), isFalse);
  });
}
