import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_resource_cache_channel.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_resource_cache_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_resource_cache_store.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_resource_manifest_consumer.dart';

void main() {
  test(
    'consumes decoded start2 once and submits manifest for current mode',
    () async {
      final port = RecordingPort();
      final controller = GameResourceCacheController(
        store: MemoryStore(GameResourceCacheMode.light),
        port: port,
      );
      await controller.initialize();
      final consumer = GameResourceManifestConsumer(
        controller: controller,
        ownedShipMasterIds: () => const <int>{1},
        ownedSlotItemMasterIds: () => const <int>{100},
        staticUrlsLoader: () async => const <String>['/kcs2/js/main.js'],
      );
      final start2 = <String, Object?>{
        'api_mst_shipgraph': <Object?>[
          <String, Object?>{
            'api_id': 1,
            'api_filename': 'ship_a',
            'api_version': <Object?>['2', '3', '4'],
          },
        ],
        'api_mst_ship': <Object?>[
          <String, Object?>{'api_id': 1, 'api_name': 'A'},
        ],
        'api_mst_slotitem': <Object?>[
          <String, Object?>{'api_id': 100, 'api_version': '5'},
        ],
      };
      final event = CapturedApiEvent(
        path: '/kcsapi/api_start2/getData',
        responseBody: jsonEncode(<String, Object?>{
          'api_result': 1,
          'api_data': start2,
        }),
        decodedEnvelope: <String, Object?>{'api_result': 1, 'api_data': start2},
        source: CaptureSource.xhr,
        sourceOrigin: 'https://w01y.kancolle-server.com',
        capturedAt: DateTime.utc(2026),
      );

      consumer.accept(event);
      await consumer.idle;

      expect(port.manifests, hasLength(1));
      expect(port.manifests.single.profile, 'light');
      expect(
        port.manifests.single.urls.any(
          (url) => url.contains('_ship_a.png?version=2'),
        ),
        isTrue,
      );
      consumer.dispose();
      controller.dispose();
    },
  );

  test('ignores paths other than start2', () {
    final controller = GameResourceCacheController(
      store: MemoryStore(),
      port: RecordingPort(),
    );
    final consumer = GameResourceManifestConsumer(
      controller: controller,
      ownedShipMasterIds: () => const <int>{},
      ownedSlotItemMasterIds: () => const <int>{},
      staticUrlsLoader: () async => const <String>[],
    );

    expect(consumer.supportsPath('/kcsapi/api_start2/getData'), isTrue);
    expect(consumer.supportsPath('/kcsapi/api_port/port'), isFalse);
    consumer.dispose();
    controller.dispose();
  });
}

final class MemoryStore implements GameResourceCacheStore {
  MemoryStore([this.mode = GameResourceCacheMode.none]);
  GameResourceCacheMode mode;
  @override
  Future<GameResourceCacheMode> load() async => mode;
  @override
  Future<void> save(GameResourceCacheMode value) async => mode = value;
}

final class RecordingPort implements GameResourceCachePort {
  final manifests = <GameResourceManifest>[];
  @override
  Future<bool> configure(GameResourceCacheMode mode) async => true;
  @override
  Future<GameResourceCacheStatus> status() async =>
      GameResourceCacheStatus.empty;
  @override
  Future<bool> setManifest(GameResourceManifest manifest) async {
    manifests.add(manifest);
    return true;
  }

  @override
  Future<bool> startDownload({bool allowMetered = false}) async => true;
  @override
  Future<bool> pauseDownload() async => true;
  @override
  Future<GameResourceCacheStatus> checkIntegrity() async =>
      GameResourceCacheStatus.empty;
  @override
  Future<bool> repair({bool allowMetered = false}) async => true;
  @override
  Future<bool> clear() async => true;
}
