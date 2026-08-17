import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_resource_cache_channel.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_resource_cache_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_resource_cache_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_resource_cache_section.dart';

void main() {
  testWidgets('shows three modes and the single GB completeness line', (
    tester,
  ) async {
    final port = _FakePort();
    final controller = GameResourceCacheController(
      store: _MemoryStore(GameResourceCacheMode.light),
      port: port,
    );
    await controller.initialize();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: GameResourceCacheSection(controller: controller)),
      ),
    );

    expect(find.byKey(const Key('cache-mode-none')), findsOneWidget);
    expect(find.byKey(const Key('cache-mode-light')), findsOneWidget);
    expect(find.byKey(const Key('cache-mode-full')), findsOneWidget);
    expect(find.text('6.84 GB / 8.12 GB（84.2%）'), findsOneWidget);
    expect(find.textContaining('1,284'), findsNothing);
  });

  testWidgets('integrity check reports missing and damaged resources', (
    tester,
  ) async {
    final port = _FakePort();
    final controller = GameResourceCacheController(
      store: _MemoryStore(GameResourceCacheMode.light),
      port: port,
    );
    await controller.initialize();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: GameResourceCacheSection(controller: controller)),
      ),
    );
    await tester.tap(find.byKey(const Key('cache-check-integrity')));
    await tester.pump();

    expect(port.integrityCalls, 1);
    expect(find.byKey(const Key('cache-integrity-result')), findsOneWidget);
    expect(find.textContaining('缺失 3'), findsOneWidget);
    expect(find.textContaining('损坏 1'), findsOneWidget);
    expect(find.byKey(const Key('cache-repair')), findsOneWidget);
  });

  testWidgets('changing mode keeps existing files', (tester) async {
    final port = _FakePort();
    final controller = GameResourceCacheController(
      store: _MemoryStore(GameResourceCacheMode.light),
      port: port,
    );
    await controller.initialize();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: GameResourceCacheSection(controller: controller)),
      ),
    );
    await tester.tap(find.byKey(const Key('cache-mode-full')));
    await tester.pumpAndSettle();

    expect(controller.mode, GameResourceCacheMode.full);
    expect(port.clearCalls, 0);
  });

  testWidgets('mobile data requires confirmation for the current download', (
    tester,
  ) async {
    final port = _FakePort()..metered = true;
    final controller = GameResourceCacheController(
      store: _MemoryStore(GameResourceCacheMode.light),
      port: port,
    );
    await controller.initialize();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: GameResourceCacheSection(controller: controller)),
      ),
    );
    await tester.tap(find.byKey(const Key('cache-download-toggle')));
    await tester.pumpAndSettle();

    expect(find.textContaining('移动网络'), findsOneWidget);
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(port.allowedMetered, isTrue);
  });
}

final class _MemoryStore implements GameResourceCacheStore {
  _MemoryStore(this.mode);
  GameResourceCacheMode mode;

  @override
  Future<GameResourceCacheMode> load() async => mode;

  @override
  Future<void> save(GameResourceCacheMode value) async => mode = value;
}

final class _FakePort implements GameResourceCachePort {
  int integrityCalls = 0;
  int clearCalls = 0;
  GameResourceCacheMode mode = GameResourceCacheMode.light;
  bool metered = false;
  bool allowedMetered = false;

  GameResourceCacheStatus get value => GameResourceCacheStatus(
    mode: mode,
    state: GameResourceCacheState.idle,
    cachedBytes: 6840000000,
    maxBytes: 10000000000,
    targetBytes: 8120000000,
    downloadedBytes: 0,
    bytesPerSecond: 0,
    remainingSeconds: null,
    missingCount: 3,
    damagedCount: 1,
    fileCount: 1284,
    capacityBlocked: false,
    isMetered: metered,
  );

  @override
  Future<bool> configure(GameResourceCacheMode value) async {
    mode = value;
    return true;
  }

  @override
  Future<GameResourceCacheStatus> status() async => value;

  @override
  Future<bool> setManifest(
    GameResourceManifest manifest, {
    bool Function()? shouldContinue,
  }) async => shouldContinue?.call() ?? true;

  @override
  Future<bool> startDownload({bool allowMetered = false}) async {
    allowedMetered = allowMetered;
    return true;
  }

  @override
  Future<bool> pauseDownload() async => true;

  @override
  Future<GameResourceCacheStatus> checkIntegrity() async {
    integrityCalls++;
    return value;
  }

  @override
  Future<bool> repair({bool allowMetered = false}) async => true;

  @override
  Future<bool> clear() async {
    clearCalls++;
    return true;
  }
}
