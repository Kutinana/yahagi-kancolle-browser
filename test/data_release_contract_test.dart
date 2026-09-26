import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/enemy_catalog.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/enemy_catalog_store.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/sortie_map_catalog_manifest.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/sortie_map_catalog_store.dart';

void main() {
  final enabled = Platform.environment['YAHAGI_RELEASE_CONTRACT_TEST'] == '1';
  test(
    'Python release builders produce assets accepted by current Dart runtime',
    () async {
      final root = await Directory.systemTemp.createTemp('yahagi-contract-');
      try {
        final sortieManifestFile = File('${root.path}/sortie-manifest.json');
        final sortieDist = Directory('${root.path}/sortie-dist');
        await _runBuilder(<String>[
          'tool/build_sortie_release.py',
          '--manifest',
          sortieManifestFile.path,
          '--dist',
          sortieDist.path,
        ]);
        final sortieManifest = SortieMapCatalogManifest.fromJsonString(
          await sortieManifestFile.readAsString(),
        );
        final archive = await File(
          '${sortieDist.path}/${sortieManifest.archiveFileName}',
        ).readAsBytes();
        expect(archive.length, sortieManifest.archiveBytes);
        expect(
          sha256.convert(archive).toString(),
          sortieManifest.archiveSha256,
        );
        final sortieStore = FileSortieMapCatalogStore(
          root: Directory('${root.path}/sortie-store'),
          currentAppVersion: '1.0.8',
        );
        final installed = await sortieStore.installArchive(
          archive,
          expected: SortieMapCatalogInstallExpectation(
            version: sortieManifest.version,
            mapCount: sortieManifest.mapCount,
            nodeCount: sortieManifest.nodeCount,
            formationCount: sortieManifest.formationCount,
            minimumAppVersion: sortieManifest.minimumAppVersion,
          ),
        );
        expect(installed.data.revision, sortieManifest.version.revision);
        expect(
          (await sortieStore.loadCached())?.data.maps.length,
          sortieManifest.mapCount,
        );

        final enemyManifestFile = File('${root.path}/enemy-manifest.json');
        await _runBuilder(<String>[
          'tool/build_enemy_release.py',
          'assets/data/enemy_catalog.json',
          enemyManifestFile.path,
          '--tag',
          'enemy-data-20260920-r1',
        ]);
        final enemyManifest =
            jsonDecode(await enemyManifestFile.readAsString())
                as Map<String, dynamic>;
        final enemyBytes = await File(
          'assets/data/enemy_catalog.json',
        ).readAsBytes();
        expect(enemyBytes.length, enemyManifest['dataBytes']);
        expect(
          sha256.convert(enemyBytes).toString(),
          enemyManifest['dataSha256'],
        );
        final enemyData = EnemyCatalogData.fromJsonString(
          utf8.decode(enemyBytes),
        );
        expect(enemyData.ships.length, enemyManifest['shipCount']);
        expect(enemyData.aliasCount, enemyManifest['aliasCount']);
        final enemyStore = FileEnemyCatalogStore(
          cacheFile: File('${root.path}/enemy-cache.json'),
          bundledReader: () async => utf8.decode(enemyBytes),
        );
        await enemyStore.save(enemyData);
        expect(
          (await enemyStore.loadBestAvailable()).revision,
          enemyData.revision,
        );
      } finally {
        await root.delete(recursive: true);
      }
    },
    skip: enabled
        ? false
        : 'Set YAHAGI_RELEASE_CONTRACT_TEST=1 to run local release validation.',
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

Future<void> _runBuilder(List<String> arguments) async {
  final result = await Process.run('python', arguments);
  if (result.exitCode != 0) {
    fail('Release builder failed: ${result.stderr}');
  }
}
