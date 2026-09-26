import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yahagi_kancolle_browser/src/fleet/ship_portrait_cache.dart';

List<int> _pngBytes([List<int> payload = const <int>[]]) => <int>[
  0x89,
  0x50,
  0x4e,
  0x47,
  0x0d,
  0x0a,
  0x1a,
  0x0a,
  ...payload,
];

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('ship_portrait_cache_test_');
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  test('downloads once and reuses the persisted portrait', () async {
    var requests = 0;
    final cache = ShipPortraitCache(
      directoryProvider: () async => root,
      client: MockClient((request) async {
        requests++;
        return http.Response.bytes(_pngBytes(<int>[1, 2, 3]), 200);
      }),
    );
    final uri = Uri.parse('https://example.test/1501.png?version=1');

    final first = await cache.resolve(cacheKey: '1501_banner', uri: uri);
    final second = await cache.resolve(cacheKey: '1501_banner', uri: uri);

    expect(first, isNotNull);
    expect(await first!.readAsBytes(), _pngBytes(<int>[1, 2, 3]));
    expect(second!.path, first.path);
    expect(requests, 1);
  });

  test(
    'new portrait URI replaces the previous version for the same ship',
    () async {
      var requests = 0;
      final cache = ShipPortraitCache(
        directoryProvider: () async => root,
        client: MockClient((request) async {
          requests++;
          return http.Response.bytes(
            _pngBytes(
              request.url.queryParameters['version'] == '2'
                  ? <int>[2]
                  : <int>[1],
            ),
            200,
          );
        }),
      );

      final oldFile = await cache.resolve(
        cacheKey: '1501_banner',
        uri: Uri.parse('https://example.test/1501.png?version=1'),
      );
      final newFile = await cache.resolve(
        cacheKey: '1501_banner',
        uri: Uri.parse('https://example.test/1501.png?version=2'),
      );

      expect(requests, 2);
      expect(await newFile!.readAsBytes(), _pngBytes(<int>[2]));
      expect(newFile.path, isNot(oldFile!.path));
      expect(oldFile.existsSync(), isFalse);
      final files = root.listSync(recursive: true).whereType<File>().toList();
      expect(files, hasLength(1));
    },
  );

  test(
    'concurrent requests for one portrait share a single download',
    () async {
      var requests = 0;
      final cache = ShipPortraitCache(
        directoryProvider: () async => root,
        client: MockClient((request) async {
          requests++;
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return http.Response.bytes(_pngBytes(<int>[7]), 200);
        }),
      );
      final uri = Uri.parse('https://example.test/1501.png');

      final files = await Future.wait([
        cache.resolve(cacheKey: '1501_banner', uri: uri),
        cache.resolve(cacheKey: '1501_banner', uri: uri),
      ]);

      expect(requests, 1);
      expect(files[0]!.path, files[1]!.path);
    },
  );

  test('failed downloads leave no cache file', () async {
    final cache = ShipPortraitCache(
      directoryProvider: () async => root,
      client: MockClient((request) async => http.Response('missing', 404)),
    );

    final file = await cache.resolve(
      cacheKey: '1501_banner',
      uri: Uri.parse('https://example.test/missing.png'),
    );

    expect(file, isNull);
    expect(root.listSync(recursive: true).whereType<File>(), isEmpty);
  });

  test(
    'different versions for one portrait commit in invocation order',
    () async {
      final oldRequestStarted = Completer<void>();
      final releaseOldRequest = Completer<void>();
      final requests = <String>[];
      final cache = ShipPortraitCache(
        directoryProvider: () async => root,
        client: MockClient((request) async {
          final version = request.url.queryParameters['version']!;
          requests.add(version);
          if (version == '1') {
            oldRequestStarted.complete();
            await releaseOldRequest.future;
          }
          return http.Response.bytes(_pngBytes(<int>[int.parse(version)]), 200);
        }),
      );
      final oldFuture = cache.resolve(
        cacheKey: '1501_banner',
        uri: Uri.parse('https://example.test/1501.png?version=1'),
      );
      await oldRequestStarted.future;
      final newFuture = cache.resolve(
        cacheKey: '1501_banner',
        uri: Uri.parse('https://example.test/1501.png?version=2'),
      );
      releaseOldRequest.complete();

      final results = await Future.wait(<Future<File?>>[oldFuture, newFuture]);

      expect(requests, <String>['1', '2']);
      expect(results[1], isNotNull);
      expect(await results[1]!.readAsBytes(), _pngBytes(<int>[2]));
      expect(results[1]!.existsSync(), isTrue);
      expect(results[0]!.existsSync(), isFalse);
      expect(root.listSync().whereType<File>(), hasLength(1));
    },
  );

  test('HTTP 200 non-PNG response never poisons the cache', () async {
    final cache = ShipPortraitCache(
      directoryProvider: () async => root,
      client: MockClient(
        (request) async =>
            http.Response('<html>temporary proxy page</html>', 200),
      ),
    );

    final file = await cache.resolve(
      cacheKey: '1501_banner',
      uri: Uri.parse('https://example.test/1501.png'),
    );

    expect(file, isNull);
    expect(root.listSync().whereType<File>(), isEmpty);
  });

  for (final corruptBytes in <List<int>>[
    <int>[],
    <int>[1, 2, 3],
  ]) {
    test(
      'repairs an existing ${corruptBytes.isEmpty ? 'zero-byte' : 'invalid'} file',
      () async {
        var requests = 0;
        final uri = Uri.parse('https://example.test/1501.png');
        final primingCache = ShipPortraitCache(
          directoryProvider: () async => root,
          client: MockClient(
            (request) async => http.Response.bytes(_pngBytes(<int>[1]), 200),
          ),
        );
        final poisoned = await primingCache.resolve(
          cacheKey: '1501_banner',
          uri: uri,
        );
        poisoned!.writeAsBytesSync(corruptBytes, flush: true);
        final repairingCache = ShipPortraitCache(
          directoryProvider: () async => root,
          client: MockClient((request) async {
            requests++;
            return http.Response.bytes(_pngBytes(<int>[2]), 200);
          }),
        );

        final repaired = await repairingCache.resolve(
          cacheKey: '1501_banner',
          uri: uri,
        );

        expect(requests, 1);
        expect(await repaired!.readAsBytes(), _pngBytes(<int>[2]));
      },
    );
  }
}
