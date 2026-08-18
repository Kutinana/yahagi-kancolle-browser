import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:yahagi_kancolle_browser/main.dart';
import 'package:yahagi_kancolle_browser/src/audio/game_audio_controller.dart';
import 'package:yahagi_kancolle_browser/src/audio/game_audio_store.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_controller.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_damage_alert.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_browser_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_application_restart_port.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_environment_host.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_toolbar_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/battle_result_warning_overlay.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode_store.dart';
import 'package:yahagi_kancolle_browser/src/capture/game_capture_controller.dart';
import 'package:yahagi_kancolle_browser/src/game_webview.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/native_activity_game_surface.dart';
import 'package:yahagi_kancolle_browser/src/prototype_status_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_rendering_mode.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_rendering_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/network_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/network_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_store.dart';

void main() {
  test(
    'GameWebView startup serializes hot updates and keeps a successful load',
    () async {
      final firstStage = Completer<void>();
      final coordinator = GameWebViewStartupCoordinator();
      final calls = <String>[];

      final first = coordinator.schedule(() async {
        calls.add('old-network');
        await firstStage.future;
        await coordinator.navigateOnce(() async => calls.add('old-load'));
      });
      final second = coordinator.schedule(() async {
        calls.add('new-network');
        await coordinator.navigateOnce(() async => calls.add('new-load'));
      });

      await Future<void>.delayed(Duration.zero);
      expect(calls, <String>['old-network']);
      firstStage.complete();
      await Future.wait(<Future<void>>[first, second]);

      expect(calls, <String>['old-network', 'old-load', 'new-network']);
    },
  );

  test(
    'GameWebView startup retries navigation after an old load fails',
    () async {
      final firstLoad = Completer<void>();
      final coordinator = GameWebViewStartupCoordinator();
      var loadCalls = 0;

      final first = coordinator.schedule(() async {
        await coordinator.navigateOnce(() async {
          loadCalls += 1;
          await firstLoad.future;
          throw StateError('old load failed');
        });
      });
      final second = coordinator.schedule(() async {
        await coordinator.navigateOnce(() async => loadCalls += 1);
      });

      firstLoad.complete();
      await expectLater(first, throwsStateError);
      await second;

      expect(loadCalls, 2);
    },
  );

  test('GameWebView capture updates reload only the final revision', () async {
    final configuration = Completer<void>();
    var configureCalls = 0;
    var reloadCalls = 0;
    final coordinator = GameWebViewCaptureUpdateCoordinator();

    final first = coordinator.request(
      configure: () {
        configureCalls += 1;
        return configuration.future;
      },
      reload: () async => reloadCalls += 1,
      isActive: () => true,
      onError: (_, _) {},
    );
    final second = coordinator.request(
      configure: () {
        configureCalls += 1;
        return configuration.future;
      },
      reload: () async => reloadCalls += 1,
      isActive: () => true,
      onError: (_, _) {},
    );
    configuration.complete();
    await Future.wait(<Future<void>>[first, second]);

    expect(configureCalls, 2);
    expect(reloadCalls, 1);
  });

  test('GameWebView capture updates ignore an inactive old binding', () async {
    final oldConfiguration = Completer<void>();
    final newConfiguration = Completer<void>();
    var oldActive = true;
    var oldReloads = 0;
    var newReloads = 0;
    final coordinator = GameWebViewCaptureUpdateCoordinator();

    final old = coordinator.request(
      configure: () => oldConfiguration.future,
      reload: () async => oldReloads += 1,
      isActive: () => oldActive,
      onError: (_, _) {},
    );
    oldActive = false;
    final current = coordinator.request(
      configure: () => newConfiguration.future,
      reload: () async => newReloads += 1,
      isActive: () => true,
      onError: (_, _) {},
    );
    newConfiguration.complete();
    oldConfiguration.complete();
    await Future.wait(<Future<void>>[old, current]);

    expect(oldReloads, 0);
    expect(newReloads, 1);
  });

  test('GameWebView hot-update bindings migrate identities safely', () async {
    final oldBrowser = GameBrowserController();
    final nextBrowser = GameBrowserController();
    final oldNetwork = _HotNetworkController();
    final nextNetwork = _HotNetworkController();
    final oldCapture = await CaptureModeController.load(
      const _MemoryCaptureModeStore(),
    );
    final nextCapture = await CaptureModeController.load(
      const _MemoryCaptureModeStore(),
    );
    final port = _HotBrowserPort();
    final newerPort = _HotBrowserPort();
    final oldOrchestrator = _HotStartupOrchestrator();
    final nextOrchestrator = _HotStartupOrchestrator();
    var networkChanges = 0;
    var captureChanges = 0;
    final bindings = GameWebViewBindingCoordinator(
      browserController: oldBrowser,
      browserPort: port,
      networkSettingsController: oldNetwork,
      captureModeController: oldCapture,
      startupOrchestrator: oldOrchestrator,
      onNetworkSettingsChanged: () => networkChanges += 1,
      onCaptureModeChanged: () => captureChanges += 1,
    );

    bindings.update(
      browserController: nextBrowser,
      networkSettingsController: nextNetwork,
      captureModeController: nextCapture,
      startupOrchestrator: nextOrchestrator,
    );
    oldNetwork.emitChange();
    await oldCapture.setMode(CaptureMode.browserOnly);
    expect(networkChanges, 0);
    expect(captureChanges, 0);
    nextNetwork.emitChange();
    await nextCapture.setMode(CaptureMode.browserOnly);
    expect(networkChanges, 1);
    expect(captureChanges, 1);
    expect(oldOrchestrator.disposeCalls, 1);
    expect(identical(bindings.startupOrchestrator, nextOrchestrator), isTrue);

    await nextBrowser.reload();
    expect(port.reloadCalls, 1);
    await oldBrowser.reload();
    expect(port.reloadCalls, 1);

    nextBrowser.attachPort(newerPort);
    await bindings.dispose();
    await nextBrowser.reload();
    expect(newerPort.reloadCalls, 1);

    oldBrowser.dispose();
    nextBrowser.dispose();
    oldNetwork.dispose();
    nextNetwork.dispose();
    oldCapture.dispose();
    nextCapture.dispose();
  });

  testWidgets('selects the native surface only for the activity mode', (
    tester,
  ) async {
    final gameCaptureController = GameCaptureController();
    final battleController = BattleController(gameState: () => GameState.empty);
    final safetySettingsController = await SafetySettingsController.load(
      MemorySafetySettingsStore(),
    );
    addTearDown(gameCaptureController.dispose);
    addTearDown(battleController.dispose);
    addTearDown(safetySettingsController.dispose);

    for (final mode in GameRenderingMode.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: buildGameSurfaceForRenderingMode(
            mode: mode,
            key: ValueKey<String>(mode.storageName),
            buildNativeActivityGameSurface: (key) => SizedBox(
              key: const Key('native-surface'),
              child: Text('native-${key.toString()}'),
            ),
            buildGameWebView: (key, renderingMode) => SizedBox(
              key: const Key('flutter-webview'),
              child: Text('webview-${renderingMode.storageName}'),
            ),
            withBattleWarning: (child) => BattleResultWarningOverlay(
              gameCaptureController: gameCaptureController,
              battleController: battleController,
              safetySettingsController: safetySettingsController,
              damageAlertPort: const _NoopDamageAlertPort(),
              child: child,
            ),
          ),
        ),
      );

      expect(find.byType(BattleResultWarningOverlay), findsOneWidget);
      if (mode == GameRenderingMode.nativeActivityExperimental) {
        expect(find.byKey(const Key('native-surface')), findsOneWidget);
        expect(find.byKey(const Key('flutter-webview')), findsNothing);
        expect(find.byType(WebViewWidget), findsNothing);
        expect(find.byType(PlatformViewLink), findsNothing);
        expect(find.byType(AndroidView), findsNothing);
        expect(find.byType(UiKitView), findsNothing);
      } else {
        expect(find.byKey(const Key('native-surface')), findsNothing);
        expect(find.byKey(const Key('flutter-webview')), findsOneWidget);
      }
    }
  });

  test('wraps the actual surface type for every rendering mode', () async {
    final networkController = NetworkSettingsController(
      store: _MemoryNetworkStore(),
    );
    final safetyController = await SafetySettingsController.load(
      MemorySafetySettingsStore(),
    );
    final captureModeController = await CaptureModeController.load(
      const _MemoryCaptureModeStore(),
    );
    final audioController = await GameAudioController.load(
      const _MemoryAudioStore(),
    );
    final statusController = PrototypeStatusController();
    final browserController = GameBrowserController();
    final toolbarController = GameToolbarController()..collapse();
    final gameCaptureController = GameCaptureController();
    final battleController = BattleController(gameState: () => GameState.empty);
    addTearDown(networkController.dispose);
    addTearDown(safetyController.dispose);
    addTearDown(captureModeController.dispose);
    addTearDown(audioController.dispose);
    addTearDown(statusController.dispose);
    addTearDown(browserController.dispose);
    addTearDown(toolbarController.dispose);
    addTearDown(gameCaptureController.dispose);
    addTearDown(battleController.dispose);

    for (final mode in GameRenderingMode.values) {
      final selected = buildGameSurfaceForRenderingMode(
        mode: mode,
        key: ValueKey<String>(mode.storageName),
        buildNativeActivityGameSurface: (key) => NativeActivityGameSurface(
          key: key,
          statusController: statusController,
          browserController: browserController,
          toolbarController: toolbarController,
          routeObserver: RouteObserver<ModalRoute<dynamic>>(),
          networkSettingsController: networkController,
          captureModeController: captureModeController,
          audioController: audioController,
          gameCaptureController: gameCaptureController,
        ),
        buildGameWebView: (key, renderingMode) => GameWebView(
          key: key,
          networkSettingsController: networkController,
          safetySettingsController: safetyController,
          controller: statusController,
          browserController: browserController,
          captureModeController: captureModeController,
          audioController: audioController,
          toolbarController: toolbarController,
          gameCaptureController: gameCaptureController,
          renderingMode: renderingMode,
        ),
        withBattleWarning: (child) => BattleResultWarningOverlay(
          gameCaptureController: gameCaptureController,
          battleController: battleController,
          safetySettingsController: safetyController,
          damageAlertPort: const _NoopDamageAlertPort(),
          child: child,
        ),
      );

      expect(selected, isA<BattleResultWarningOverlay>());
      final child = (selected as BattleResultWarningOverlay).child;
      expect(
        child,
        mode == GameRenderingMode.nativeActivityExperimental
            ? isA<NativeActivityGameSurface>()
            : isA<GameWebView>(),
      );
    }
  });

  testWidgets('restart removes the game before requesting an app restart', (
    tester,
  ) async {
    final controller = await GameRenderingModeController.load(
      MemoryGameRenderingModeStore(),
    );
    addTearDown(controller.dispose);
    var beforeRestartCalls = 0;
    final applicationRestartPort = _RecordingApplicationRestartPort();

    await tester.pumpWidget(
      MaterialApp(
        home: GameEnvironmentHost(
          controller: controller,
          beforeRestart: () async => beforeRestartCalls += 1,
          applicationRestartPort: applicationRestartPort,
          gameBuilder: (context, mode, key) => ColoredBox(
            key: key,
            color: Colors.black,
            child: Text('game-${mode.storageName}'),
          ),
        ),
      ),
    );

    expect(find.text('game-compatibility'), findsOneWidget);

    final changing = controller.changeMode(GameRenderingMode.standard);
    await tester.pump();

    expect(find.text('game-standard'), findsNothing);
    expect(find.text('game-compatibility'), findsNothing);
    expect(
      find.byKey(const Key('game-environment-restarting')),
      findsOneWidget,
    );

    await tester.pump();
    expect((await changing).status, GameRenderingModeChangeStatus.applied);
    expect(beforeRestartCalls, 1);
    expect(applicationRestartPort.calls, 1);
    expect(find.textContaining('game-'), findsNothing);
  });

  testWidgets('host keeps exactly one game after repeated sequential changes', (
    tester,
  ) async {
    final controller = await GameRenderingModeController.load(
      MemoryGameRenderingModeStore(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: GameEnvironmentHost(
          controller: controller,
          gameBuilder: (context, mode, key) =>
              SizedBox(key: key, child: Text('game-${mode.storageName}')),
        ),
      ),
    );

    for (final mode in <GameRenderingMode>[
      GameRenderingMode.standard,
      GameRenderingMode.canvasCompatibility,
      GameRenderingMode.nativeActivityExperimental,
      GameRenderingMode.compatibility,
    ]) {
      final changing = controller.changeMode(mode);
      await tester.pump();
      expect(find.textContaining('game-'), findsNothing);
      await tester.pump();
      await changing;
      expect(find.text('game-${mode.storageName}'), findsOneWidget);
    }
  });

  testWidgets('disposing the host detaches its restart port', (tester) async {
    final controller = await GameRenderingModeController.load(
      MemoryGameRenderingModeStore(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: GameEnvironmentHost(
          controller: controller,
          gameBuilder: (context, mode, key) => SizedBox(key: key),
        ),
      ),
    );
    await tester.pumpWidget(const SizedBox());

    final result = await controller.changeMode(GameRenderingMode.standard);
    expect(result.status, GameRenderingModeChangeStatus.unavailable);
  });
}

final class _HotNetworkController extends NetworkSettingsController {
  _HotNetworkController() : super(store: _MemoryNetworkStore());

  void emitChange() => notifyListeners();
}

final class _HotBrowserPort implements GameBrowserPort {
  int reloadCalls = 0;

  @override
  Future<void> reload() async => reloadCalls += 1;

  @override
  Future<bool> canGoBack() async => false;

  @override
  Future<void> clearCache() async {}

  @override
  Future<void> clearSession() async {}

  @override
  Future<void> fitGameScreen() async {}

  @override
  Future<void> goBack() async {}

  @override
  Future<void> loadUri(Uri uri) async {}

  @override
  Future<void> runJavaScript(String javascript) async {}

  @override
  Future<void> showLocalHome() async {}
}

final class _HotStartupOrchestrator implements GameSurfaceStartupOrchestrator {
  int disposeCalls = 0;

  @override
  Future<void> attachAudioPortOnce() async {}

  @override
  Future<bool> attachFrameRatePlatformPort() async => false;

  @override
  Future<GameSurfaceNetworkResult> applyNetworkSettings() async =>
      const GameSurfaceNetworkResult.success();

  @override
  void dispose() => disposeCalls += 1;

  @override
  Future<void> prepareCapture() async {}

  @override
  Future<void> runCaptureStartup({
    required Future<void> Function() waitForSurface,
    required bool Function() isActive,
    required Future<void> Function() navigate,
  }) async {}
}

final class _NoopDamageAlertPort implements BattleDamageAlertPort {
  const _NoopDamageAlertPort();

  @override
  Future<void> alert(BattleDamageAlertSeverity severity) async {}
}

final class _MemoryNetworkStore implements NetworkSettingsStore {
  @override
  Future<NetworkSettings> loadSettings() async => const NetworkSettings();

  @override
  Future<void> saveSettings(NetworkSettings settings) async {}
}

final class _MemoryCaptureModeStore implements CaptureModeStore {
  const _MemoryCaptureModeStore();

  @override
  Future<CaptureMode?> read() async => CaptureMode.game;

  @override
  Future<void> write(CaptureMode mode) async {}
}

final class _MemoryAudioStore implements GameAudioStore {
  const _MemoryAudioStore();

  @override
  Future<bool?> readMuted() async => false;

  @override
  Future<void> writeMuted(bool muted) async {}

  @override
  Future<bool?> readBackgroundPlaybackEnabled() async => false;

  @override
  Future<void> writeBackgroundPlaybackEnabled(bool enabled) async {}
}

final class _RecordingApplicationRestartPort
    implements GameApplicationRestartPort {
  int calls = 0;

  @override
  Future<void> restartApplication() async => calls += 1;
}
