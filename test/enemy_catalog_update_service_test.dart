import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/enemy_catalog.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/enemy_catalog_store.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/enemy_catalog_update_service.dart';

import 'enemy_catalog_test.dart' show enemyCatalogFixture;

void main() {
  test('verifies manifest digest and installs a newer enemy catalog', () async {
    final directory = await Directory.systemTemp.createTemp('enemy-update-');
    addTearDown(() => directory.delete(recursive: true));
    final next = enemyCatalogFixture.replaceFirst(
      '"revision": 7',
      '"revision": 8',
    );
    final bytes = utf8.encode(next);
    final release = Uri.parse(
      'https://github.com/yamatosaki/yahagi-kancolle-data/releases/download/enemy-data-20260920/enemy_catalog.json',
    );
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/data/enemy/manifest.json')) {
        return http.Response(
          jsonEncode({
            'schemaVersion': 1,
            'dataVersion': '2026.09.20',
            'revision': 8,
            'publishedAt': '2026-09-20T00:00:00Z',
            'minimumAppVersion': '1.0.0',
            'dataUrl': release.toString(),
            'dataBytes': bytes.length,
            'dataSha256': sha256.convert(bytes).toString(),
            'shipCount': 1,
            'aliasCount': 1,
          }),
          200,
        );
      }
      if (request.url == release) return http.Response.bytes(bytes, 200);
      return http.Response('missing', 404);
    });
    final store = FileEnemyCatalogStore(
      cacheFile: File('${directory.path}/catalog.json'),
      bundledReader: () async => enemyCatalogFixture,
    );
    final service = EnemyCatalogUpdateService(
      client: client,
      store: store,
      appVersion: '1.0.8-beta.2',
    );

    final result = await service.checkAndUpdate(
      current: EnemyCatalogData.fromJsonString(enemyCatalogFixture),
    );
    if (result case EnemyCatalogUpdateFailed(:final error)) {
      fail('Unexpected update failure: $error');
    }

    expect(result, isA<EnemyCatalogUpdated>());
    expect((await store.loadBestAvailable()).revision, 8);
  });

  test('keeps current data when the downloaded digest is invalid', () async {
    final directory = await Directory.systemTemp.createTemp('enemy-update-');
    addTearDown(() => directory.delete(recursive: true));
    final client = MockClient(
      (request) async => http.Response(
        jsonEncode({
          'schemaVersion': 1,
          'dataVersion': 'bad',
          'revision': 8,
          'publishedAt': '2026-09-20T00:00:00Z',
          'minimumAppVersion': '1.0.0',
          'dataUrl':
              'https://github.com/yamatosaki/yahagi-kancolle-data/releases/download/enemy-data-20260920/enemy_catalog.json',
          'dataBytes': 3,
          'dataSha256': List.filled(64, '0').join(),
          'shipCount': 1,
          'aliasCount': 1,
        }),
        200,
      ),
    );
    final store = FileEnemyCatalogStore(
      cacheFile: File('${directory.path}/catalog.json'),
      bundledReader: () async => enemyCatalogFixture,
    );
    final result =
        await EnemyCatalogUpdateService(
          client: client,
          store: store,
          appVersion: '1.0.8-beta.2',
        ).checkAndUpdate(
          current: EnemyCatalogData.fromJsonString(enemyCatalogFixture),
        );

    expect(result, isA<EnemyCatalogUpdateFailed>());
    expect(await store.cacheFile.exists(), isFalse);
  });

  test('rejects a manifest with invalid version metadata', () async {
    final directory = await Directory.systemTemp.createTemp('enemy-update-');
    addTearDown(() => directory.delete(recursive: true));
    final store = FileEnemyCatalogStore(
      cacheFile: File('${directory.path}/catalog.json'),
      bundledReader: () async => enemyCatalogFixture,
    );
    final client = MockClient(
      (request) async => http.Response(
        jsonEncode({
          'schemaVersion': 1,
          'dataVersion': 'bad',
          'revision': 0,
          'publishedAt': 'not-a-timestamp',
          'minimumAppVersion': '1.0.0',
          'dataUrl':
              'https://github.com/yamatosaki/yahagi-kancolle-data/releases/download/enemy-data-test/enemy_catalog.json',
          'dataBytes': 1,
          'dataSha256': List.filled(64, '0').join(),
          'shipCount': 0,
          'aliasCount': 0,
        }),
        200,
      ),
    );

    final result =
        await EnemyCatalogUpdateService(
          client: client,
          store: store,
          appVersion: '1.0.8-beta.2',
        ).checkAndUpdate(
          current: EnemyCatalogData.fromJsonString(enemyCatalogFixture),
        );

    expect(result, isA<EnemyCatalogUpdateFailed>());
    expect(
      (result as EnemyCatalogUpdateFailed).kind,
      EnemyCatalogUpdateFailure.validation,
    );
  });

  test('applies one deadline and aborts a stalled catalog body', () async {
    final directory = await Directory.systemTemp.createTemp('enemy-update-');
    addTearDown(() => directory.delete(recursive: true));
    final next = enemyCatalogFixture.replaceFirst(
      '"revision": 7',
      '"revision": 8',
    );
    final client = _SlowEnemyCatalogClient(utf8.encode(next));
    final store = FileEnemyCatalogStore(
      cacheFile: File('${directory.path}/catalog.json'),
      bundledReader: () async => enemyCatalogFixture,
    );

    final result =
        await EnemyCatalogUpdateService(
          client: client,
          store: store,
          appVersion: '1.0.8-beta.2',
          timeout: const Duration(milliseconds: 35),
        ).checkAndUpdate(
          current: EnemyCatalogData.fromJsonString(enemyCatalogFixture),
        );

    expect(result, isA<EnemyCatalogUpdateFailed>());
    expect(
      (result as EnemyCatalogUpdateFailed).kind,
      EnemyCatalogUpdateFailure.network,
    );
    await expectLater(client.abortObserved.future, completes);
    await expectLater(client.cancelObserved.future, completes);
    expect(await store.cacheFile.exists(), isFalse);
  });
}

final class _SlowEnemyCatalogClient extends http.BaseClient {
  _SlowEnemyCatalogClient(this.catalogBytes);

  final List<int> catalogBytes;
  final Completer<void> abortObserved = Completer<void>();
  final Completer<void> cancelObserved = Completer<void>();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.host == 'raw.githubusercontent.com') {
      final manifest = jsonEncode({
        'schemaVersion': 1,
        'dataVersion': '2026.09.20',
        'revision': 8,
        'publishedAt': '2026-09-20T00:00:00Z',
        'minimumAppVersion': '1.0.0',
        'dataUrl':
            'https://github.com/yamatosaki/yahagi-kancolle-data/releases/download/enemy-data-test/enemy_catalog.json',
        'dataBytes': catalogBytes.length,
        'dataSha256': sha256.convert(catalogBytes).toString(),
        'shipCount': 1,
        'aliasCount': 1,
      });
      return http.StreamedResponse(
        Stream<List<int>>.value(utf8.encode(manifest)),
        200,
      );
    }
    expect(request, isA<http.AbortableRequest>());
    final abortable = request as http.AbortableRequest;
    abortable.abortTrigger?.then((_) {
      if (!abortObserved.isCompleted) abortObserved.complete();
    });
    final controller = StreamController<List<int>>(
      onCancel: () {
        if (!cancelObserved.isCompleted) cancelObserved.complete();
      },
    );
    return http.StreamedResponse(controller.stream, 200);
  }
}
