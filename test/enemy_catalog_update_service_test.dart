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
  test('uses CDN when the primary enemy manifest is unavailable', () async {
    final directory = await Directory.systemTemp.createTemp('enemy-update-');
    addTearDown(() => directory.delete(recursive: true));
    final next = enemyCatalogFixture.replaceFirst(
      '"revision": 7',
      '"revision": 8',
    );
    final bytes = utf8.encode(next);
    final client = MockClient((request) async {
      if (request.url.host == 'raw.githubusercontent.com') {
        return http.Response('unavailable', 503);
      }
      if (request.url.host == 'cdn.jsdelivr.net') {
        return http.Response(
          jsonEncode({
            'schemaVersion': 1,
            'dataVersion': '2026.09.20',
            'revision': 8,
            'publishedAt': '2026-09-20T00:00:00Z',
            'minimumAppVersion': '1.0.0',
            'dataUrl':
                'https://github.com/yamatosaki/yahagi-kancolle-data/releases/download/enemy-data-test/enemy_catalog.json',
            'dataBytes': bytes.length,
            'dataSha256': sha256.convert(bytes).toString(),
            'shipCount': 1,
            'aliasCount': 1,
          }),
          200,
        );
      }
      return http.Response.bytes(bytes, 200);
    });
    final store = FileEnemyCatalogStore(
      cacheFile: File('${directory.path}/catalog.json'),
      bundledReader: () async => enemyCatalogFixture,
    );
    final result =
        await EnemyCatalogUpdateService(
          client: client,
          store: store,
          appVersion: '1.0.8',
        ).checkAndUpdate(
          current: EnemyCatalogData.fromJsonString(enemyCatalogFixture),
        );

    expect(result, isA<EnemyCatalogUpdated>());
    expect(result.sourceHost, 'cdn.jsdelivr.net');
    expect((await store.loadBestAvailable()).revision, 8);
  });

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

  test(
    'keeps downloading while the enemy catalog continues making progress',
    () async {
      final directory = await Directory.systemTemp.createTemp('enemy-update-');
      addTearDown(() => directory.delete(recursive: true));
      final next = enemyCatalogFixture.replaceFirst(
        '"revision": 7',
        '"revision": 8',
      );
      final bytes = utf8.encode(next);
      final client = _ProgressiveEnemyClient(bytes);
      final store = FileEnemyCatalogStore(
        cacheFile: File('${directory.path}/catalog.json'),
        bundledReader: () async => enemyCatalogFixture,
      );

      final result =
          await EnemyCatalogUpdateService(
            client: client,
            store: store,
            appVersion: '1.0.8',
            timeout: const Duration(milliseconds: 100),
          ).checkAndUpdate(
            current: EnemyCatalogData.fromJsonString(enemyCatalogFixture),
          );

      expect(result, isA<EnemyCatalogUpdated>());
      expect((await store.loadBestAvailable()).revision, 8);
    },
  );

  test(
    'synchronous enemy progress after slow headers resets idle timeout',
    () async {
      final directory = await Directory.systemTemp.createTemp('enemy-update-');
      addTearDown(() => directory.delete(recursive: true));
      final next = enemyCatalogFixture.replaceFirst(
        '"revision": 7',
        '"revision": 8',
      );
      final bytes = utf8.encode(next);
      final store = FileEnemyCatalogStore(
        cacheFile: File('${directory.path}/catalog.json'),
        bundledReader: () async => enemyCatalogFixture,
      );
      final result =
          await EnemyCatalogUpdateService(
            client: _SynchronousEnemyProgressClient(bytes),
            store: store,
            appVersion: '1.0.8',
            timeout: const Duration(milliseconds: 300),
          ).checkAndUpdate(
            current: EnemyCatalogData.fromJsonString(enemyCatalogFixture),
          );

      expect(result, isA<EnemyCatalogUpdated>());
      expect((await store.loadBestAvailable()).revision, 8);
    },
  );
}

final class _SynchronousEnemyProgressClient extends http.BaseClient {
  _SynchronousEnemyProgressClient(this.catalogBytes);

  final List<int> catalogBytes;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.host == 'raw.githubusercontent.com') {
      return http.StreamedResponse(
        Stream<List<int>>.value(
          utf8.encode(
            jsonEncode({
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
            }),
          ),
        ),
        200,
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 220));
    final midpoint = catalogBytes.length ~/ 2;
    return http.StreamedResponse(
      _ImmediateEnemyStream(
        catalogBytes.sublist(0, midpoint),
        catalogBytes.sublist(midpoint),
      ),
      200,
    );
  }
}

final class _ImmediateEnemyStream extends Stream<List<int>> {
  _ImmediateEnemyStream(this.firstChunk, this.secondChunk);

  final List<int> firstChunk;
  final List<int> secondChunk;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    onData?.call(firstChunk);
    return Stream<List<int>>.value(secondChunk)
        .asyncMap((chunk) async {
          await Future<void>.delayed(const Duration(milliseconds: 130));
          return chunk;
        })
        .listen(
          onData,
          onError: onError,
          onDone: onDone,
          cancelOnError: cancelOnError,
        );
  }
}

final class _ProgressiveEnemyClient extends http.BaseClient {
  _ProgressiveEnemyClient(this.catalogBytes);

  final List<int> catalogBytes;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.host == 'raw.githubusercontent.com') {
      return http.StreamedResponse(
        Stream<List<int>>.value(
          utf8.encode(
            jsonEncode({
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
            }),
          ),
        ),
        200,
      );
    }
    final partSize = (catalogBytes.length / 6).ceil();
    return http.StreamedResponse(
      Stream<List<int>>.periodic(
        const Duration(milliseconds: 35),
        (index) => catalogBytes.skip(index * partSize).take(partSize).toList(),
      ).take(6),
      200,
    );
  }
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
