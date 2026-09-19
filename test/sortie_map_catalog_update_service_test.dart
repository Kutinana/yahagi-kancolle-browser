import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/sortie_map_catalog_store.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/sortie_map_catalog_update_service.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/sortie_map_models.dart';

void main() {
  test('downloads, verifies, and installs a newer release', () async {
    final archive = <int>[1, 2, 3, 4];
    final installer = _Installer();
    final client = MockClient((request) async {
      if (request.url.host == 'raw.githubusercontent.com') {
        return http.Response(_manifest(archive, revision: 8), 200);
      }
      expect(request.url.host, 'github.com');
      return http.Response.bytes(archive, 200);
    });
    final service = SortieMapCatalogUpdateService(
      client: client,
      installer: installer,
      appVersion: '1.0.8',
    );

    final result = await service.checkAndUpdate(current: _catalog(7));

    expect(result, isA<SortieMapCatalogUpdated>());
    expect(installer.installed, archive);
  });

  test('does not install an archive with a mismatched digest', () async {
    final archive = <int>[1, 2, 3];
    final installer = _Installer();
    final client = MockClient(
      (request) async => request.url.host == 'raw.githubusercontent.com'
          ? http.Response(_manifest(<int>[9], revision: 8), 200)
          : http.Response.bytes(archive, 200),
    );
    final result = await SortieMapCatalogUpdateService(
      client: client,
      installer: installer,
      appVersion: '1.0.8',
    ).checkAndUpdate(current: _catalog(7));

    expect(result, isA<SortieMapCatalogUpdateFailed>());
    expect(
      (result as SortieMapCatalogUpdateFailed).kind,
      SortieMapCatalogUpdateFailure.validation,
    );
    expect(installer.installed, isNull);
  });
}

String _manifest(List<int> bytes, {required int revision}) => jsonEncode({
  'schemaVersion': 1,
  'dataVersion': 'test',
  'revision': revision,
  'publishedAt': '2026-09-20T00:00:00Z',
  'minimumAppVersion': '1.0.8',
  'archive': {
    'tag': 'sortie-data-test',
    'fileName': 'sortie-data-test.zip',
    'bytes': bytes.length,
    'sha256': sha256.convert(bytes).toString(),
  },
  'counts': {'maps': 1, 'nodes': 1, 'formations': 1},
});

SortieMapCatalogData _catalog(int revision) => SortieMapCatalogData(
  version: 1,
  dataVersion: 'old',
  revision: revision,
  source: 'test',
  maps: const <SortieMapInfo>[
    SortieMapInfo(
      id: '1-1',
      nameJa: 'test',
      difficulty: 1,
      coverAsset: 'covers/1-1.png',
      mapAsset: 'maps/1-1.png',
      source: null,
      nodes: <SortieMapNode>[
        SortieMapNode(
          point: 'A',
          kind: 'battle',
          typeLabel: 'battle',
          battleTypeLabel: 'battle',
          nameJa: null,
          reward: null,
          formations: <EnemyFormation>[
            EnemyFormation(
              variant: 1,
              isFinal: false,
              formation: null,
              experience: null,
              airPower: null,
              fleetGroups: <List<EnemyShipEntry>>[],
              note: null,
            ),
          ],
        ),
      ],
    ),
  ],
);

final class _Installer implements SortieMapCatalogInstaller {
  List<int>? installed;

  @override
  Future<InstalledSortieMapCatalog> installArchive(List<int> bytes) async {
    installed = bytes;
    return InstalledSortieMapCatalog(
      data: _catalog(8),
      root: Directory.systemTemp,
    );
  }
}
