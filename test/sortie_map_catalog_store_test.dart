import 'dart:convert';
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

  test('bounds actual inflated bytes when central size is forged', () async {
    final store = FileSortieMapCatalogStore(
      root: temporary,
      maximumUncompressedBytes: 2048,
    );
    final archive = _archive(<String, List<int>>{
      'sortie_map_catalog.json': _catalog,
      'covers/1-1.png': List<int>.filled(8192, 65),
      'maps/1-1.png': _png,
    });
    _patchCentralEntry(archive, 'covers/1-1.png', uncompressedSize: 1);
    expect(() => store.installArchive(archive), throwsFormatException);
  });

  test('rejects a symlink entry before reading its payload', () async {
    final store = FileSortieMapCatalogStore(root: temporary);
    final archive = _validArchive(7);
    _patchCentralEntry(
      archive,
      'covers/1-1.png',
      externalAttributes: 0xa000 << 16,
    );
    expect(() => store.installArchive(archive), throwsFormatException);
  });

  test('tampered persistent cache is ignored', () async {
    final store = FileSortieMapCatalogStore(root: temporary);
    await store.installArchive(_validArchive(7));
    final catalog = File(
      '${temporary.path}${Platform.pathSeparator}versions${Platform.pathSeparator}7${Platform.pathSeparator}sortie_map_catalog.json',
    );
    await catalog.writeAsString('{}', flush: true);
    expect(await store.loadCached(), isNull);
  });

  test('cache requiring a newer app is ignored after app downgrade', () async {
    final newer = FileSortieMapCatalogStore(
      root: temporary,
      currentAppVersion: '2.0.0',
    );
    await newer.installArchive(
      _validArchive(7),
      expected: const SortieMapCatalogInstallExpectation(
        version: SortieMapCatalogVersion(label: 'test', revision: 7),
        mapCount: 1,
        nodeCount: 0,
        formationCount: 0,
        minimumAppVersion: '2.0.0',
      ),
    );
    final downgraded = FileSortieMapCatalogStore(
      root: temporary,
      currentAppVersion: '1.0.8',
    );
    expect(await downgraded.loadCached(), isNull);
  });

  test('pre-commit failures preserve the active revision', () async {
    String? failingPhase;
    final store = FileSortieMapCatalogStore(
      root: temporary,
      phaseHook: (phase) async {
        if (phase == failingPhase) throw const FileSystemException('injected');
      },
    );
    await store.installArchive(_validArchive(7));
    for (final phase in <String>[
      'beforeVersionRename',
      'beforePointerCommit',
    ]) {
      failingPhase = phase;
      await expectLater(
        store.installArchive(_validArchive(8)),
        throwsA(isA<FileSystemException>()),
      );
      expect((await store.loadCached())?.data.revision, 7);
    }
  });

  test('post-commit cleanup failures still report success', () async {
    var failCleanup = false;
    final store = FileSortieMapCatalogStore(
      root: temporary,
      phaseHook: (phase) async {
        if (phase == 'beforeCleanup' && failCleanup) {
          throw const FileSystemException('injected');
        }
      },
    );
    await store.installArchive(_validArchive(7));
    failCleanup = true;
    final installed = await store.installArchive(_validArchive(8));
    expect(installed.data.revision, 8);
    expect((await store.loadCached())?.data.revision, 8);
  });
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

List<int> _catalogForRevision(int revision) => utf8.encode('''
{"version":1,"schemaVersion":1,"dataVersion":"test","revision":$revision,
"publishedAt":"2026-09-20T00:00:00Z","source":"test","maps":[{
"id":"1-1","nameJa":"test","difficulty":1,"coverAsset":"covers/1-1.png",
"mapAsset":"maps/1-1.png","nodes":[]}]}
''');

List<int> _validArchive(int revision) => _archive(<String, List<int>>{
  'sortie_map_catalog.json': _catalogForRevision(revision),
  'covers/1-1.png': _png,
  'maps/1-1.png': _png,
});

void _patchCentralEntry(
  List<int> bytes,
  String target, {
  int? uncompressedSize,
  int? externalAttributes,
}) {
  int uint16(int offset) => bytes[offset] | (bytes[offset + 1] << 8);
  void uint32(int offset, int value) {
    for (var index = 0; index < 4; index++) {
      bytes[offset + index] = (value >> (8 * index)) & 0xff;
    }
  }

  for (var offset = 0; offset + 46 <= bytes.length; offset++) {
    if (bytes[offset] != 0x50 ||
        bytes[offset + 1] != 0x4b ||
        bytes[offset + 2] != 0x01 ||
        bytes[offset + 3] != 0x02) {
      continue;
    }
    final nameLength = uint16(offset + 28);
    final name = utf8.decode(
      bytes.sublist(offset + 46, offset + 46 + nameLength),
    );
    if (name != target) continue;
    if (uncompressedSize != null) uint32(offset + 24, uncompressedSize);
    if (externalAttributes != null) uint32(offset + 38, externalAttributes);
    return;
  }
  throw StateError('central entry not found: $target');
}

final List<int> _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);
