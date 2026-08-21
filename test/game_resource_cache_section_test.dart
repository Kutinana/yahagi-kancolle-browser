import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_resource_cache_channel.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_resource_cache_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_resource_cache_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_resource_cache_section.dart';
import 'package:yahagi_kancolle_browser/src/widgets/top_notice.dart';

void main() {
  Widget app(GameResourceCacheController controller) => MaterialApp(
    home: TopNoticeHost(
      child: Scaffold(body: GameResourceCacheSection(controller: controller)),
    ),
  );

  testWidgets('shows two modes and the single GB completeness line', (
    tester,
  ) async {
    final port = _FakePort();
    final controller = GameResourceCacheController(
      store: _MemoryStore(GameResourceCacheMode.full),
      port: port,
    );
    await controller.initialize();
    addTearDown(controller.dispose);

    await tester.pumpWidget(app(controller));

    expect(find.byKey(const Key('cache-mode-none')), findsOneWidget);
    expect(find.byKey(const Key('cache-mode-light')), findsNothing);
    expect(find.byKey(const Key('cache-mode-full')), findsOneWidget);
    expect(find.text('本地缓存'), findsOneWidget);
    expect(find.textContaining('固定基础资源清单（约 5.49 GB）'), findsOneWidget);
    expect(find.textContaining('游玩时自动缓存'), findsOneWidget);
    expect(find.text('6.84 GB'), findsOneWidget);
    expect(find.textContaining('/ 8.12 GB'), findsNothing);
    expect(find.textContaining('1,284'), findsNothing);

    final textCenterY = tester
        .getCenter(find.byKey(const Key('cache-completeness-line')))
        .dy;
    final buttonCenterY = tester
        .getCenter(find.byKey(const Key('cache-check-integrity')))
        .dy;
    expect((textCenterY - buttonCenterY).abs(), lessThan(4.0));

    final noneLeft = tester.getTopLeft(find.text('无本地缓存')).dx;
    final fullLeft = tester.getTopLeft(find.text('本地缓存')).dx;
    final completenessLeft = tester
        .getTopLeft(find.byKey(const Key('cache-completeness-line')))
        .dx;
    expect(fullLeft, noneLeft);
    expect(completenessLeft, noneLeft);
  });

  testWidgets('integrity check hides diagnostics but keeps repair action', (
    tester,
  ) async {
    final port = _FakePort();
    final controller = GameResourceCacheController(
      store: _MemoryStore(GameResourceCacheMode.light),
      port: port,
    );
    await controller.initialize();
    addTearDown(controller.dispose);

    await tester.pumpWidget(app(controller));
    await tester.tap(find.byKey(const Key('cache-check-integrity')));
    await tester.pump();

    expect(port.integrityCalls, 1);
    expect(find.byKey(const Key('cache-integrity-result')), findsNothing);
    expect(find.textContaining('缺失 3'), findsNothing);
    expect(find.textContaining('损坏 1'), findsNothing);
    expect(find.textContaining('过期 0'), findsNothing);
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

    await tester.pumpWidget(app(controller));
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

    await tester.pumpWidget(app(controller));
    await tester.tap(find.byKey(const Key('cache-download-toggle')));
    await tester.pumpAndSettle();

    expect(find.textContaining('移动网络'), findsOneWidget);
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(port.allowedMetered, isTrue);
  });

  testWidgets('failed cache action shows an error notice', (tester) async {
    final port = _FakePort()..failStartDownload = true;
    final controller = GameResourceCacheController(
      store: _MemoryStore(GameResourceCacheMode.full),
      port: port,
    );
    await controller.initialize();
    addTearDown(controller.dispose);
    await tester.pumpWidget(app(controller));

    await tester.tap(find.byKey(const Key('cache-download-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final notice = find.byKey(topNoticeKey);
    expect(
      find.descendant(of: notice, matching: find.text('缓存操作未完成，请稍后重试。')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: notice,
        matching: find.byIcon(Icons.error_outline_rounded),
      ),
      findsOneWidget,
    );
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
  bool failStartDownload = false;

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
    return !failStartDownload;
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
