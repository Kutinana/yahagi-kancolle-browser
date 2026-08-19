import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_resource_cache_channel.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_resource_cache_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_resource_cache_store.dart';

void main() {
  test('formats completeness as one capacity line', () {
    expect(
      formatCacheCompleteness(6840000000, 8120000000),
      '6.84 GB',
    );
  });

  test(
    'does not show the cache capacity as an unknown manifest size',
    () async {
      final port = FakePort()
        ..nextStatus = const GameResourceCacheStatus(
          mode: GameResourceCacheMode.full,
          state: GameResourceCacheState.idle,
          cachedBytes: 0,
          maxBytes: 10000000000,
          targetBytes: 0,
          downloadedBytes: 0,
          bytesPerSecond: 0,
          remainingSeconds: null,
          missingCount: 0,
          damagedCount: 0,
          fileCount: 0,
          capacityBlocked: false,
        );
      final controller = GameResourceCacheController(
        store: MemoryStore(),
        port: port,
      );
      await controller.initialize();

      expect(controller.completenessLine, '0.00 GB');
      controller.dispose();
    },
  );

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
          mode: GameResourceCacheMode.full,
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
        store: MemoryStore(GameResourceCacheMode.full),
        port: port,
      );

      await controller.initialize();

      expect(controller.status.state, GameResourceCacheState.downloading);
      expect(controller.completenessLine, '6.84 GB');
      controller.dispose();
    },
  );

  test('overlapping status refreshes are coalesced', () async {
    final port = FakePort();
    final controller = GameResourceCacheController(
      store: MemoryStore(),
      port: port,
    );
    await controller.initialize();
    port.statusGate = Completer<void>();
    port.statusEntered = Completer<void>();

    final first = controller.refresh();
    await port.statusEntered!.future;
    final second = controller.refresh();
    await Future<void>.delayed(Duration.zero);

    expect(port.statusCalls, 2);
    port.statusGate!.complete();
    await Future.wait(<Future<void>>[first, second]);
    expect(port.statusCalls, 3);
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

final class FakePort implements GameResourceCachePort {
  final List<GameResourceCacheMode> configured = <GameResourceCacheMode>[];
  int clearCalls = 0;
  int statusCalls = 0;
  Completer<void>? statusGate;
  Completer<void>? statusEntered;
  GameResourceCacheStatus nextStatus = GameResourceCacheStatus.empty;

  @override
  Future<bool> configure(GameResourceCacheMode mode) async {
    configured.add(mode);
    return true;
  }

  @override
  Future<GameResourceCacheStatus> status() async {
    statusCalls++;
    final gate = statusGate;
    if (gate != null) {
      final entered = statusEntered;
      if (entered != null && !entered.isCompleted) entered.complete();
      await gate.future;
    }
    return nextStatus;
  }

  @override
  Future<bool> setManifest(
    GameResourceManifest manifest, {
    bool Function()? shouldContinue,
  }) async => shouldContinue?.call() ?? true;

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
