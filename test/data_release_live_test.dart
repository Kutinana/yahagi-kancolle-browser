import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/enemy_catalog.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/enemy_catalog_store.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/enemy_catalog_update_service.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/sortie_map_catalog_store.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/sortie_map_catalog_manifest.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/sortie_map_catalog_update_service.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/sortie_map_models.dart';

void main() {
  final enabled = Platform.environment['YAHAGI_LIVE_DATA_TEST'] == '1';
  test(
    'three data releases download and install from the dedicated repository',
    () async {
      // Dart exposes a global setter but no global getter; Flutter test installs
      // its HTTP 400 override as the current global override.
      final previousOverrides = HttpOverrides.current;
      late final HttpClient realHttpClient;
      try {
        HttpOverrides.global = null; // Flutter tests otherwise return HTTP 400.
        realHttpClient = HttpClient();
      } finally {
        HttpOverrides.global = previousOverrides;
      }
      http.Client? clientToClose;
      Directory? rootToDelete;
      try {
        final client = IOClient(realHttpClient);
        clientToClose = client;
        final root = await Directory.systemTemp.createTemp('yahagi-live-data-');
        rootToDelete = root;
        final bundledSortie =
            jsonDecode(
                  await File(
                    'assets/data/sortie_map_catalog.json',
                  ).readAsString(),
                )
                as Map<String, dynamic>;
        bundledSortie['revision'] = 1; // Force the actual online update path.
        final expectedSortie = SortieMapCatalogManifest.fromJsonString(
          await File('data/sortie/manifest.json').readAsString(),
        );
        final sortieStore = FileSortieMapCatalogStore(
          root: Directory('${root.path}/sortie-current'),
          currentAppVersion: '1.0.8',
        );
        final sortieResult = await SortieMapCatalogUpdateService(
          client: client,
          installer: sortieStore,
          appVersion: '1.0.8',
        ).checkAndUpdate(current: SortieMapCatalogData.fromJson(bundledSortie));
        if (sortieResult case SortieMapCatalogUpdateFailed(:final error)) {
          fail('Current sortie release failed: $error');
        }
        expect(sortieResult, isA<SortieMapCatalogUpdated>());
        expect(
          (await sortieStore.loadCached())?.data.revision,
          expectedSortie.version.revision,
        );
        expect(
          (await sortieStore.loadCached())?.data.maps.length,
          expectedSortie.mapCount,
        );

        final bundledEnemy =
            jsonDecode(
                  await File('assets/data/enemy_catalog.json').readAsString(),
                )
                as Map<String, dynamic>;
        bundledEnemy['revision'] = 1;
        final expectedEnemy =
            jsonDecode(await File('data/enemy/manifest.json').readAsString())
                as Map<String, dynamic>;
        final enemyStore = FileEnemyCatalogStore(
          cacheFile: File('${root.path}/enemy-catalog.json'),
          bundledReader: () =>
              File('assets/data/enemy_catalog.json').readAsString(),
        );
        final enemyResult =
            await EnemyCatalogUpdateService(
              client: client,
              store: enemyStore,
              appVersion: '1.0.8',
            ).checkAndUpdate(
              current: EnemyCatalogData.fromJsonString(
                jsonEncode(bundledEnemy),
              ),
            );
        if (enemyResult case EnemyCatalogUpdateFailed(:final error)) {
          fail('Enemy release failed: $error');
        }
        expect(enemyResult, isA<EnemyCatalogUpdated>());
        expect(
          (await enemyStore.loadBestAvailable()).revision,
          expectedEnemy['revision'],
        );
        expect(
          (await enemyStore.loadBestAvailable()).ships.length,
          expectedEnemy['shipCount'],
        );

        final previousUri = Uri.parse(
          'https://github.com/yamatosaki/yahagi-kancolle-data/releases/download/'
          'sortie-data-2026.09.20/sortie-data-2026.09.20.zip',
        );
        final previousResponse = await client.get(previousUri);
        expect(previousResponse.statusCode, 200);
        expect(previousResponse.bodyBytes.length, 29937153);
        expect(
          sha256.convert(previousResponse.bodyBytes).toString(),
          '560a9de2bfa70429ddb45f34bfe6f4ca87eac3b34d336f477c4832db13eb6981',
        );
        final previousStore = FileSortieMapCatalogStore(
          root: Directory('${root.path}/sortie-previous'),
          currentAppVersion: '1.0.8',
        );
        final installedPrevious = await previousStore.installArchive(
          previousResponse.bodyBytes,
        );
        expect(installedPrevious.data.revision, 2026092001);
        expect(installedPrevious.data.maps.length, 37);
        expect((await previousStore.loadCached())?.data.revision, 2026092001);
      } finally {
        clientToClose?.close();
        if (rootToDelete case final directory?) {
          await directory.delete(recursive: true);
        }
      }
    },
    skip: enabled
        ? false
        : 'Set YAHAGI_LIVE_DATA_TEST=1 to run network release audit.',
    timeout: const Timeout(Duration(minutes: 20)),
  );
}
