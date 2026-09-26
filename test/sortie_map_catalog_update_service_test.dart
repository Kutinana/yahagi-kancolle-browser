import 'dart:async';
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
      expect(
        request.url.path,
        startsWith('/yamatosaki/yahagi-kancolle-data/releases/download/'),
      );
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

  test('falls back to CDN when the primary manifest is unavailable', () async {
    final archive = <int>[1, 2, 3];
    final installer = _Installer();
    final client = MockClient((request) async {
      if (request.url.host == 'raw.githubusercontent.com') {
        return http.Response('unavailable', 503);
      }
      if (request.url.host == 'cdn.jsdelivr.net') {
        return http.Response(_manifest(archive, revision: 8), 200);
      }
      return http.Response.bytes(archive, 200);
    });
    final result = await SortieMapCatalogUpdateService(
      client: client,
      installer: installer,
      appVersion: '1.0.8',
    ).checkAndUpdate(current: _catalog(7));

    expect(result, isA<SortieMapCatalogUpdated>());
    expect(result.sourceHost, 'cdn.jsdelivr.net');
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

  test('rejects release redirects to an untrusted host', () async {
    final archive = <int>[1, 2, 3];
    final installer = _Installer();
    final client = MockClient((request) async {
      if (request.url.host == 'raw.githubusercontent.com') {
        return http.Response(_manifest(archive, revision: 8), 200);
      }
      return http.Response(
        '',
        302,
        headers: <String, String>{'location': 'https://example.test/steal.zip'},
      );
    });

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

  test('follows the HTTPS GitHub release asset redirect', () async {
    final archive = <int>[4, 5, 6];
    final installer = _Installer();
    final client = MockClient((request) async {
      if (request.url.host == 'raw.githubusercontent.com') {
        return http.Response(_manifest(archive, revision: 8), 200);
      }
      if (request.url.host == 'github.com') {
        return http.Response(
          '',
          302,
          headers: <String, String>{
            'location':
                'https://release-assets.githubusercontent.com/signed.zip',
          },
        );
      }
      expect(request.url.host, 'release-assets.githubusercontent.com');
      return http.Response.bytes(archive, 200);
    });

    final result = await SortieMapCatalogUpdateService(
      client: client,
      installer: installer,
      appVersion: '1.0.8',
    ).checkAndUpdate(current: _catalog(7));

    expect(result, isA<SortieMapCatalogUpdated>());
    expect(installer.installed, archive);
  });

  test('applies one deadline to the complete streamed download', () async {
    final archive = <int>[1, 2, 3, 4];
    final installer = _Installer();
    final client = _SlowArchiveClient(_manifest(archive, revision: 8));

    final result = await SortieMapCatalogUpdateService(
      client: client,
      installer: installer,
      appVersion: '1.0.8',
      timeout: const Duration(milliseconds: 35),
    ).checkAndUpdate(current: _catalog(7));

    expect(result, isA<SortieMapCatalogUpdateFailed>());
    expect(
      (result as SortieMapCatalogUpdateFailed).kind,
      SortieMapCatalogUpdateFailure.network,
    );
    expect(installer.installed, isNull);
    await expectLater(client.abortObserved.future, completes);
    await expectLater(client.cancelObserved.future, completes);
  });

  test(
    'keeps downloading while a large archive continues making progress',
    () async {
      final archive = <int>[1, 2, 3, 4, 5, 6];
      final installer = _Installer();
      final client = _ProgressiveArchiveClient(
        _manifest(archive, revision: 8),
        archive,
      );

      final result = await SortieMapCatalogUpdateService(
        client: client,
        installer: installer,
        appVersion: '1.0.8',
        timeout: const Duration(milliseconds: 100),
      ).checkAndUpdate(current: _catalog(7));

      expect(result, isA<SortieMapCatalogUpdated>());
      expect(installer.installed, archive);
    },
  );

  test(
    'a synchronous oversized first chunk is rejected as validation',
    () async {
      final installer = _Installer();
      final client = _SynchronousOversizeClient(
        _manifest(<int>[1], revision: 8),
      );
      final result = await SortieMapCatalogUpdateService(
        client: client,
        installer: installer,
        appVersion: '1.0.8',
        maximumArchiveBytes: 3,
      ).checkAndUpdate(current: _catalog(7));

      expect(result, isA<SortieMapCatalogUpdateFailed>());
      expect(
        (result as SortieMapCatalogUpdateFailed).kind,
        SortieMapCatalogUpdateFailure.validation,
      );
      expect(installer.installed, isNull);
    },
  );

  test(
    'synchronous progress after slow headers resets the idle timeout',
    () async {
      const archive = <int>[1, 2];
      final installer = _Installer();
      final result = await SortieMapCatalogUpdateService(
        client: _SynchronousProgressClient(_manifest(archive, revision: 8)),
        installer: installer,
        appVersion: '1.0.8',
        timeout: const Duration(milliseconds: 300),
      ).checkAndUpdate(current: _catalog(7));

      expect(result, isA<SortieMapCatalogUpdated>());
      expect(installer.installed, archive);
    },
  );

  for (final mode in _CleanupMode.values) {
    test('cancels an unconsumed ${mode.name} response body', () async {
      const archive = <int>[1];
      final installer = _Installer();
      final client = _UnconsumedResponseClient(
        _manifest(archive, revision: 8),
        mode,
      );

      final result = await SortieMapCatalogUpdateService(
        client: client,
        installer: installer,
        appVersion: '1.0.8',
        maximumArchiveBytes: 8,
      ).checkAndUpdate(current: _catalog(7));

      if (mode == _CleanupMode.redirect) {
        expect(result, isA<SortieMapCatalogUpdated>());
      } else {
        expect(result, isA<SortieMapCatalogUpdateFailed>());
      }
      await expectLater(client.abortObserved.future, completes);
      await expectLater(client.cancelObserved.future, completes);
    });
  }

  test('cancels the body when the deadline expires after headers', () async {
    const archive = <int>[1];
    final installer = _Installer();
    final client = _UnconsumedResponseClient(
      _manifest(archive, revision: 8),
      _CleanupMode.oversized,
      archiveContentLength: 1,
    );

    final result = await SortieMapCatalogUpdateService(
      client: client,
      installer: installer,
      appVersion: '1.0.8',
      timeout: const Duration(milliseconds: 10),
      beforeBodyRead: (uri) async {
        if (uri.host == 'github.com') {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      },
    ).checkAndUpdate(current: _catalog(7));

    expect(result, isA<SortieMapCatalogUpdateFailed>());
    await expectLater(client.abortObserved.future, completes);
    await expectLater(client.cancelObserved.future, completes);
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
  Future<InstalledSortieMapCatalog> installArchive(
    List<int> bytes, {
    SortieMapCatalogInstallExpectation? expected,
  }) async {
    installed = bytes;
    return InstalledSortieMapCatalog(
      data: _catalog(8),
      root: Directory.systemTemp,
    );
  }
}

final class _SlowArchiveClient extends http.BaseClient {
  _SlowArchiveClient(this.manifest);

  final String manifest;
  final Completer<void> abortObserved = Completer<void>();
  final Completer<void> cancelObserved = Completer<void>();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.host == 'raw.githubusercontent.com') {
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
    late StreamController<List<int>> controller;
    controller = StreamController<List<int>>(
      onCancel: () {
        if (!cancelObserved.isCompleted) cancelObserved.complete();
      },
    );
    return http.StreamedResponse(controller.stream, 200);
  }
}

final class _ProgressiveArchiveClient extends http.BaseClient {
  _ProgressiveArchiveClient(this.manifest, this.archive);

  final String manifest;
  final List<int> archive;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.host == 'raw.githubusercontent.com') {
      return http.StreamedResponse(
        Stream<List<int>>.value(utf8.encode(manifest)),
        200,
      );
    }
    return http.StreamedResponse(
      Stream<List<int>>.periodic(
        const Duration(milliseconds: 35),
        (index) => <int>[archive[index]],
      ).take(archive.length),
      200,
    );
  }
}

final class _SynchronousOversizeClient extends http.BaseClient {
  _SynchronousOversizeClient(this.manifest);

  final String manifest;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.host == 'raw.githubusercontent.com') {
      return http.StreamedResponse(
        Stream<List<int>>.value(utf8.encode(manifest)),
        200,
      );
    }
    return http.StreamedResponse(
      _ImmediateThenDelayedStream(const <int>[1, 2, 3, 4], const <int>[]),
      200,
    );
  }
}

final class _SynchronousProgressClient extends http.BaseClient {
  _SynchronousProgressClient(this.manifest);

  final String manifest;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.host == 'raw.githubusercontent.com') {
      return http.StreamedResponse(
        Stream<List<int>>.value(utf8.encode(manifest)),
        200,
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 220));
    return http.StreamedResponse(
      _ImmediateThenDelayedStream(const <int>[1], const <int>[2]),
      200,
    );
  }
}

final class _ImmediateThenDelayedStream extends Stream<List<int>> {
  _ImmediateThenDelayedStream(this.firstChunk, this.secondChunk);

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

enum _CleanupMode { redirect, errorStatus, oversized }

final class _UnconsumedResponseClient extends http.BaseClient {
  _UnconsumedResponseClient(
    this.manifest,
    this.mode, {
    this.archiveContentLength = 9,
  });

  final String manifest;
  final _CleanupMode mode;
  final int archiveContentLength;
  final Completer<void> abortObserved = Completer<void>();
  final Completer<void> cancelObserved = Completer<void>();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.host == 'raw.githubusercontent.com') {
      return http.StreamedResponse(
        Stream<List<int>>.value(utf8.encode(manifest)),
        200,
      );
    }
    if (mode == _CleanupMode.redirect &&
        request.url.host == 'release-assets.githubusercontent.com') {
      return http.StreamedResponse(
        Stream<List<int>>.value(const <int>[1]),
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
    return switch (mode) {
      _CleanupMode.redirect => http.StreamedResponse(
        controller.stream,
        302,
        headers: const <String, String>{
          'location': 'https://release-assets.githubusercontent.com/data.zip',
        },
      ),
      _CleanupMode.errorStatus => http.StreamedResponse(controller.stream, 503),
      _CleanupMode.oversized => http.StreamedResponse(
        controller.stream,
        200,
        contentLength: archiveContentLength,
      ),
    };
  }
}
