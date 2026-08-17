import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_resource_cache_channel.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_resource_cache_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_resource_cache_store.dart';

void main() {
  test('formats completeness as one capacity line', () {
    expect(
      formatCacheCompleteness(6840000000, 8120000000),
      '6.84 GB / 8.12 GB（84.2%）',
    );
  });

  test(
    'changing mode configures native cache without clearing files',
    () async {
      final store = MemoryStore();
      final port = FakePort();
      final controller = GameResourceCacheController(store: store, port: port);
      await controller.initialize();

      await controller.setMode(GameResourceCacheMode.full);
      await controller.setMode(GameResourceCacheMode.none);

      expect(store.mode, GameResourceCacheMode.none);
      expect(port.configured, <GameResourceCacheMode>[
        GameResourceCacheMode.none,
        GameResourceCacheMode.full,
        GameResourceCacheMode.none,
      ]);
      expect(port.clearCalls, 0);
      controller.dispose();
    },
  );

  test(
    'maps native progress and uses manifest target in capacity line',
    () async {
      final port = FakePort()
        ..nextStatus = const GameResourceCacheStatus(
          mode: GameResourceCacheMode.light,
          state: GameResourceCacheState.downloading,
          cachedBytes: 6840000000,
          maxBytes: 10000000000,
          targetBytes: 8120000000,
          downloadedBytes: 100,
          bytesPerSecond: 20,
          remainingSeconds: 50,
          missingCount: 3,
          damagedCount: 1,
          fileCount: 1284,
          capacityBlocked: false,
        );
      final controller = GameResourceCacheController(
        store: MemoryStore(GameResourceCacheMode.light),
        port: port,
      );

      await controller.initialize();

      expect(controller.status.state, GameResourceCacheState.downloading);
      expect(controller.completenessLine, '6.84 GB / 8.12 GB（84.2%）');
      controller.dispose();
    },
  );
}

final class MemoryStore implements GameResourceCacheStore {
  MemoryStore([this.mode = GameResourceCacheMode.none]);
  GameResourceCacheMode mode;

  @override
  Future<GameResourceCacheMode> load() async => mode;

  @override
  Future<void> save(GameResourceCacheMode value) async => mode = value;
}

final class FakePort implements GameResourceCachePort {
  final List<GameResourceCacheMode> configured = <GameResourceCacheMode>[];
  int clearCalls = 0;
  GameResourceCacheStatus nextStatus = GameResourceCacheStatus.empty;

  @override
  Future<bool> configure(GameResourceCacheMode mode) async {
    configured.add(mode);
    return true;
  }

  @override
  Future<GameResourceCacheStatus> status() async => nextStatus;

  @override
  Future<bool> setManifest(GameResourceManifest manifest) async => true;

  @override
  Future<bool> startDownload({bool allowMetered = false}) async => true;

  @override
  Future<bool> pauseDownload() async => true;

  @override
  Future<GameResourceCacheStatus> checkIntegrity() async => nextStatus;

  @override
  Future<bool> repair({bool allowMetered = false}) async => true;

  @override
  Future<bool> clear() async {
    clearCalls++;
    return true;
  }
}
