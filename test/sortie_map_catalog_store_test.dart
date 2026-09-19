import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/sortie_map_catalog_store.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/sortie_map_catalog_manifest.dart';

void main() {
  late Directory temporary;

  setUp(
    () async =>
        temporary = await Directory.systemTemp.createTemp('sortie-store-'),
  );
  tearDown(() async => temporary.delete(recursive: true));

  test('installs a valid archive and keeps it as active catalog', () async {
    final store = FileSortieMapCatalogStore(root: temporary);
    final bytes = _archive(<String, List<int>>{
      'sortie_map_catalog.json': _catalog,
      'covers/1-1.png': _png,
      'maps/1-1.png': _png,
    });

    final installed = await store.installArchive(bytes);
    final active = await store.loadCached();

    expect(installed.data.versionInfo.revision, 7);
    expect(active?.data.maps.single.id, '1-1');
    expect(active?.resolve('covers/1-1.png').existsSync(), isTrue);
  });

  test('rejects path traversal without replacing the active catalog', () async {
    final store = FileSortieMapCatalogStore(root: temporary);
    await store.installArchive(
      _archive(<String, List<int>>{
        'sortie_map_catalog.json': _catalog,
        'covers/1-1.png': _png,
        'maps/1-1.png': _png,
      }),
    );

    expect(
      () => store.installArchive(
        _archive(<String, List<int>>{
          '../escape': <int>[1],
        }),
      ),
      throwsFormatException,
    );
    expect((await store.loadCached())?.data.versionInfo.revision, 7);
    expect(
      File(
        '${temporary.parent.path}${Platform.pathSeparator}escape',
      ).existsSync(),
      isFalse,
    );
  });

  test(
    'rejects manifest mismatch before changing the active pointer',
    () async {
      final store = FileSortieMapCatalogStore(root: temporary);
      final archive = _archive(<String, List<int>>{
        'sortie_map_catalog.json': _catalog,
        'covers/1-1.png': _png,
        'maps/1-1.png': _png,
      });
      await store.installArchive(archive);

      expect(
        () => store.installArchive(
          archive,
          expected: SortieMapCatalogInstallExpectation(
            version: const SortieMapCatalogVersion(
              label: 'different',
              revision: 8,
            ),
            mapCount: 1,
            nodeCount: 0,
            formationCount: 0,
          ),
        ),
        throwsFormatException,
      );
      expect((await store.loadCached())?.data.revision, 7);
    },
  );
}

List<int> _archive(Map<String, List<int>> files) {
  final archive = Archive();
  for (final entry in files.entries) {
    archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

final List<int> _catalog =
    '''
{"version":1,"schemaVersion":1,"dataVersion":"test","revision":7,
"publishedAt":"2026-09-20T00:00:00Z","source":"test","maps":[{
"id":"1-1","nameJa":"test","difficulty":1,"coverAsset":"covers/1-1.png",
"mapAsset":"maps/1-1.png","nodes":[]}]}
'''
        .codeUnits;

const List<int> _png = <int>[137, 80, 78, 71, 13, 10, 26, 10, 0];
