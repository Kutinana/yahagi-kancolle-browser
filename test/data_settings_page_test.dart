import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_browser_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode_store.dart';
import 'package:yahagi_kancolle_browser/src/capture/game_capture_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_resource_cache_channel.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_resource_cache_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_resource_cache_store.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/kcwiki_report/kcwiki_report_settings.dart';
import 'package:yahagi_kancolle_browser/src/prototype_status_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/data_settings_page.dart';
import 'package:yahagi_kancolle_browser/src/widgets/top_notice.dart';

Widget withTopNotice(Widget child) => MaterialApp(
  home: TopNoticeHost(child: Scaffold(body: child)),
);

void main() {
  testWidgets('data settings contain capture mode and local data actions', (
    tester,
  ) async {
    final capture = await CaptureModeController.load(_MemoryCaptureModeStore());
    final browser = GameBrowserController();
    final gameCapture = GameCaptureController();
    final prototype = PrototypeStatusController();
    final gameState = GameStateController();
    addTearDown(capture.dispose);
    addTearDown(browser.dispose);
    addTearDown(gameCapture.dispose);
    addTearDown(prototype.dispose);
    addTearDown(gameState.dispose);

    await tester.pumpWidget(
      withTopNotice(
        DataSettingsPage(
          captureModeController: capture,
          browserController: browser,
          gameCaptureController: gameCapture,
          prototypeStatusController: prototype,
          gameStateController: gameState,
          showDeveloperDiagnostics: true,
        ),
      ),
    );

    final logout = find.byKey(const Key('settings-logout-label'));
    final captureMode = find.byKey(const Key('capture-mode-selector'));
    expect(logout, findsOneWidget);
    expect(captureMode, findsOneWidget);
    expect(
      tester.getTopLeft(logout).dy,
      lessThan(tester.getTopLeft(captureMode).dy),
    );
    expect(find.byKey(const Key('settings-clear-quest-cache')), findsOneWidget);
    expect(find.byKey(const Key('settings-clear-logbook')), findsOneWidget);
    expect(find.byKey(const Key('settings-clear-web-cache')), findsOneWidget);
    expect(find.byKey(const Key('settings-reset-base-senka')), findsNothing);
    expect(find.byKey(const Key('settings-set-base-senka')), findsNothing);
    expect(find.text('安全边界'), findsOneWidget);
  });

  testWidgets('KCWiki reporting is opt-in and disabling is immediate', (
    tester,
  ) async {
    final capture = await CaptureModeController.load(_MemoryCaptureModeStore());
    final browser = GameBrowserController();
    final gameCapture = GameCaptureController();
    final prototype = PrototypeStatusController();
    final gameState = GameStateController();
    final store = MemoryKcwikiReportSettingsStore();
    final kcwiki = await KcwikiReportController.load(store);
    addTearDown(capture.dispose);
    addTearDown(browser.dispose);
    addTearDown(gameCapture.dispose);
    addTearDown(prototype.dispose);
    addTearDown(gameState.dispose);
    addTearDown(kcwiki.dispose);

    await tester.pumpWidget(
      withTopNotice(
        DataSettingsPage(
          captureModeController: capture,
          browserController: browser,
          gameCaptureController: gameCapture,
          prototypeStatusController: prototype,
          gameStateController: gameState,
          kcwikiReportController: kcwiki,
        ),
      ),
    );

    final toggle = find.byKey(const Key('kcwiki-report-switch'));
    expect(toggle, findsOneWidget);
    expect(kcwiki.enabled, isFalse);

    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.text('开启 KCWiki 数据贡献？'), findsOneWidget);
    expect(kcwiki.enabled, isFalse);

    await tester.tap(find.byKey(const Key('kcwiki-report-confirm')));
    await tester.pumpAndSettle();
    expect(kcwiki.enabled, isTrue);
    expect(store.enabled, isTrue);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(kcwiki.enabled, isFalse);
    expect(store.enabled, isFalse);
    expect(find.text('开启 KCWiki 数据贡献？'), findsNothing);
  });

  testWidgets(
    'checks alignment inside GameResourceCacheSection in DataSettingsPage',
    (tester) async {
      final capture = await CaptureModeController.load(
        _MemoryCaptureModeStore(),
      );
      final browser = GameBrowserController();
      final gameCapture = GameCaptureController();
      final prototype = PrototypeStatusController();
      final gameState = GameStateController();
      final cacheController = GameResourceCacheController(
        store: _MemoryCacheStore(GameResourceCacheMode.full),
        port: _FakePort(),
      );
      await cacheController.initialize();
      addTearDown(capture.dispose);
      addTearDown(browser.dispose);
      addTearDown(gameCapture.dispose);
      addTearDown(prototype.dispose);
      addTearDown(gameState.dispose);
      addTearDown(cacheController.dispose);

      await tester.pumpWidget(
        withTopNotice(
          DataSettingsPage(
            captureModeController: capture,
            browserController: browser,
            gameCaptureController: gameCapture,
            prototypeStatusController: prototype,
            gameStateController: gameState,
            gameResourceCacheController: cacheController,
          ),
        ),
      );

      final titleDx = tester.getTopLeft(find.text('游戏资源本地缓存')).dx;
      final noneDx = tester.getTopLeft(find.text('无本地缓存')).dx;
      final fullDx = tester.getTopLeft(find.text('本地缓存')).dx;
      final completenessDx = tester
          .getTopLeft(find.byKey(const Key('cache-completeness-line')))
          .dx;
      final questDx = tester.getTopLeft(find.text('清理任务数据缓存')).dx;
      final logbookDx = tester.getTopLeft(find.text('清理航海日志数据')).dx;
      final webDx = tester.getTopLeft(find.text('清理浏览器网页缓存')).dx;

      expect(titleDx, 20.0);
      expect(noneDx, 32.0);
      expect(fullDx, 32.0);
      expect(completenessDx, 32.0);
      expect(questDx, 32.0);
      expect(logbookDx, 32.0);
      expect(webDx, 32.0);
    },
  );

  testWidgets('clearing quest cache reports success in a top notice', (
    tester,
  ) async {
    final capture = await CaptureModeController.load(_MemoryCaptureModeStore());
    final browser = GameBrowserController();
    final gameCapture = GameCaptureController();
    final prototype = PrototypeStatusController();
    final gameState = GameStateController();
    addTearDown(capture.dispose);
    addTearDown(browser.dispose);
    addTearDown(gameCapture.dispose);
    addTearDown(prototype.dispose);
    addTearDown(gameState.dispose);

    await tester.pumpWidget(
      withTopNotice(
        DataSettingsPage(
          captureModeController: capture,
          browserController: browser,
          gameCaptureController: gameCapture,
          prototypeStatusController: prototype,
          gameStateController: gameState,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('settings-clear-quest-cache')));
    await tester.pump();

    expect(find.text('已清除任务数据本地缓存'), findsOneWidget);
    expect(find.byKey(topNoticeKey), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(topNoticeKey),
        matching: find.byIcon(Icons.check_circle_outline_rounded),
      ),
      findsOneWidget,
    );
  });
}

final class _MemoryCacheStore implements GameResourceCacheStore {
  _MemoryCacheStore([this.mode = GameResourceCacheMode.full]);
  GameResourceCacheMode mode;

  @override
  Future<GameResourceCacheMode> load() async => mode;

  @override
  Future<void> save(GameResourceCacheMode value) async => mode = value;
}

final class _FakePort implements GameResourceCachePort {
  GameResourceCacheMode mode = GameResourceCacheMode.full;

  GameResourceCacheStatus get value => GameResourceCacheStatus(
    mode: mode,
    state: GameResourceCacheState.idle,
    cachedBytes: 6840000000,
    maxBytes: 10000000000,
    targetBytes: 8120000000,
    downloadedBytes: 0,
    bytesPerSecond: 0,
    remainingSeconds: null,
    missingCount: 0,
    damagedCount: 0,
    fileCount: 1284,
    capacityBlocked: false,
    isMetered: false,
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
  }) async => true;

  @override
  Future<bool> startDownload({bool allowMetered = false}) async => true;

  @override
  Future<bool> pauseDownload() async => true;

  @override
  Future<GameResourceCacheStatus> checkIntegrity() async => value;

  @override
  Future<bool> repair({bool allowMetered = false}) async => true;

  @override
  Future<bool> clear() async => true;
}

final class _MemoryCaptureModeStore implements CaptureModeStore {
  @override
  Future<CaptureMode?> read() async => CaptureMode.game;

  @override
  Future<void> write(CaptureMode mode) async {}
}
