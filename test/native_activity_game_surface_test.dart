import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:yahagi_kancolle_browser/src/audio/game_audio_controller.dart';
import 'package:yahagi_kancolle_browser/src/audio/game_audio_port.dart';
import 'package:yahagi_kancolle_browser/src/audio/game_audio_store.dart';
import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_browser_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/network_proxy_channel.dart';
import 'package:yahagi_kancolle_browser/src/browser/native_game_surface_slot.dart';
import 'package:yahagi_kancolle_browser/src/browser/native_game_webview_contract.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode_store.dart';
import 'package:yahagi_kancolle_browser/src/capture/game_capture_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/game_capture_port.dart';
import 'package:yahagi_kancolle_browser/src/game_webview.dart';
import 'package:yahagi_kancolle_browser/src/native_activity_game_surface.dart';
import 'package:yahagi_kancolle_browser/src/prototype_status_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_toolbar_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_frame_rate_settings.dart';
import 'package:yahagi_kancolle_browser/src/settings/network_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/network_settings_store.dart';

void main() {
  test(
    'default startup orchestrator delegates network capture audio and frame rate in order',
    () async {
      final calls = <String>[];
      final fixture = await _DefaultOrchestratorFixture.create(calls);
      addTearDown(fixture.dispose);

      final networkResult = await fixture.orchestrator.applyNetworkSettings();
      await fixture.orchestrator.runCaptureStartup(
        waitForSurface: () async => calls.add('surface'),
        isActive: () => true,
        navigate: () async => calls.add('navigate'),
      );
      await fixture.orchestrator.attachAudioPortOnce();
      final frameRateSupported = await fixture.orchestrator
          .attachFrameRatePlatformPort();

      expect(networkResult.success, isTrue);
      expect(frameRateSupported, isTrue);
      expect(calls, <String>[
        'network',
        'surface',
        'capture.supported',
        'capture.configure:true',
        'navigate',
        'audio.supported',
        'audio.muted:false',
        'frame.supported',
        'frame.configure:auto',
      ]);
    },
  );

  test(
    'default startup orchestrator exposes failure then reapplies on retry',
    () async {
      final calls = <String>[];
      final fixture = await _DefaultOrchestratorFixture.create(calls);
      addTearDown(fixture.dispose);
      fixture.networkController.results.addAll(<ProxyResult>[
        const ProxyResult(
          success: false,
          code: 'offline',
          message: 'offline',
          elapsedMs: 0,
        ),
        const ProxyResult(success: true, code: 'ok', message: '', elapsedMs: 0),
      ]);

      final failed = await fixture.orchestrator.applyNetworkSettings();
      final retried = await fixture.orchestrator.applyNetworkSettings();

      expect(failed.success, isFalse);
      expect(retried.success, isTrue);
      expect(calls, <String>['network', 'network']);
    },
  );

  test(
    'default orchestrator shares audio attach and retries unavailable ports',
    () async {
      final calls = <String>[];
      final support = Completer<bool>();
      var audioPortNumber = 0;
      final fixture = await _DefaultOrchestratorFixture.create(
        calls,
        audioPortFactory: () {
          audioPortNumber += 1;
          if (audioPortNumber == 1) return _BlockingAudioPort(support.future);
          return _RecordingAudioPort(calls);
        },
      );
      addTearDown(fixture.dispose);

      final first = fixture.orchestrator.attachAudioPortOnce();
      var secondCompleted = false;
      final second = fixture.orchestrator.attachAudioPortOnce().whenComplete(
        () => secondCompleted = true,
      );
      await Future<void>.delayed(Duration.zero);
      expect(secondCompleted, isFalse);

      support.complete(false);
      await Future.wait(<Future<void>>[first, second]);
      await fixture.orchestrator.attachAudioPortOnce();
      expect(audioPortNumber, 2);
    },
  );

  test(
    'default orchestrator serializes capture changes with latest mode last',
    () async {
      final calls = <String>[];
      final firstConfigure = Completer<void>();
      final capturePort = _BlockingCapturePort(firstConfigure);
      final fixture = await _DefaultOrchestratorFixture.create(
        calls,
        capturePortFactory: () => capturePort,
      );
      addTearDown(fixture.dispose);

      final first = fixture.orchestrator.prepareCapture();
      await Future<void>.delayed(Duration.zero);
      await fixture.captureModeController.setMode(CaptureMode.browserOnly);
      final second = fixture.orchestrator.prepareCapture();
      await fixture.captureModeController.setMode(CaptureMode.game);
      final third = fixture.orchestrator.prepareCapture();
      await Future<void>.delayed(Duration.zero);

      expect(capturePort.enabledCalls, <bool>[true]);
      firstConfigure.complete();
      await Future.wait(<Future<void>>[first, second, third]);
      expect(capturePort.enabledCalls.last, isTrue);
    },
  );

  testWidgets(
    'subscribes before create and builds a slot without any platform view',
    (tester) async {
      final fixture = _SurfaceFixture();
      addTearDown(fixture.dispose);
      fixture.port.eventsDuringCreate.addAll(<NativeGameWebViewEvent>[
        _event('created', generationId: 7),
        _event(
          'pageStarted',
          generationId: 7,
          url: 'https://www.dmm.com/early',
        ),
      ]);

      await fixture.pump(tester);
      await tester.pump();

      expect(fixture.port.calls.take(2), <String>['listen', 'create']);
      expect(find.byType(NativeGameSurfaceSlot), findsOneWidget);
      expect(find.byType(WebViewWidget), findsNothing);
      expect(find.byType(PlatformViewLink), findsNothing);
      expect(find.byType(AndroidView), findsNothing);
      expect(find.byType(UiKitView), findsNothing);
      expect(fixture.statusController.loadState, WebViewLoadState.loading);
      fixture.toolbarController.collapse();
    },
  );

  testWidgets('native visibility follows readiness instead of slot desire', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
    await tester.pump();

    expect(fixture.port.calls, contains('visible:false'));
    expect(fixture.port.calls, isNot(contains('visible:true')));

    fixture.port.addEvent(
      _event('pageStarted', generationId: 7, url: 'https://game.example/'),
    );
    fixture.port.addEvent(
      _event('pageFinished', generationId: 7, url: 'https://game.example/'),
    );
    await tester.pump();
    await tester.pump();
    expect(
      fixture.port.calls.lastWhere((call) => call.startsWith('visible:')),
      'visible:true',
    );

    fixture.port.addEvent(
      _event('pageStarted', generationId: 7, url: 'https://game.example/next'),
    );
    await tester.pump();
    expect(
      fixture.port.calls.lastWhere((call) => call.startsWith('visible:')),
      'visible:false',
    );
    fixture.toolbarController.collapse();

    fixture.port.addEvent(
      _event(
        'mainFrameError',
        generationId: 7,
        errorCode: -2,
        description: 'failed',
      ),
    );
    await tester.pump();
    expect(
      fixture.port.calls.lastWhere((call) => call.startsWith('visible:')),
      'visible:false',
    );
  });

  testWidgets('route desire stays authoritative when a page becomes ready', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
    await tester.pump();
    fixture.navigatorKey.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const SizedBox()),
    );
    await tester.pump();
    await tester.pump();
    fixture.port.calls.clear();

    fixture.port.addEvent(
      _event('pageStarted', generationId: 7, url: 'https://game.example/'),
    );
    fixture.port.addEvent(
      _event('pageFinished', generationId: 7, url: 'https://game.example/'),
    );
    await tester.pump();
    await tester.pump();
    expect(fixture.port.calls, isNot(contains('visible:true')));

    fixture.navigatorKey.currentState!.pop();
    await tester.pump();
    await tester.pump();
    expect(fixture.port.calls, contains('visible:true'));
    fixture.toolbarController.collapse();
  });

  testWidgets('visibility writes are serialized and latest desire wins', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
    await tester.pump();
    final show = Completer<void>();
    fixture.port.visibilityCompleters.add(show);

    fixture.port.addEvent(
      _event('pageStarted', generationId: 7, url: 'https://game.example/'),
    );
    fixture.port.addEvent(
      _event('pageFinished', generationId: 7, url: 'https://game.example/'),
    );
    await tester.pump();
    await tester.pump();
    expect(
      fixture.port.calls.lastWhere((call) => call.startsWith('visible:')),
      'visible:true',
    );

    fixture.navigatorKey.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const SizedBox()),
    );
    await tester.pump();
    expect(
      fixture.port.calls.where((call) => call == 'visible:false'),
      hasLength(1),
    );

    show.complete();
    await tester.pump();
    await tester.pump();
    expect(fixture.port.calls.last, 'visible:false');
    fixture.toolbarController.collapse();
  });

  testWidgets('show failure retries, keeps an error overlay, and can recover', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
    await tester.pump();
    fixture.port.visibilityFailuresRemaining = 3;

    fixture.port.addEvent(
      _event('pageStarted', generationId: 7, url: 'https://game.example/'),
    );
    fixture.port.addEvent(
      _event('pageFinished', generationId: 7, url: 'https://game.example/'),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(
      fixture.port.calls.where((call) => call == 'visible:true'),
      hasLength(3),
    );
    expect(find.byKey(const Key('native-game-surface-error')), findsOneWidget);
    expect(fixture.port.calls, isNot(contains('destroy')));

    fixture.port.addEvent(
      _event('pageStarted', generationId: 7, url: 'https://game.example/retry'),
    );
    fixture.port.addEvent(
      _event(
        'pageFinished',
        generationId: 7,
        url: 'https://game.example/retry',
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(fixture.port.calls.last, 'visible:true');
    expect(find.byKey(const Key('native-game-surface-error')), findsNothing);
    fixture.toolbarController.collapse();
  });

  testWidgets('exhausted hide retries destroy the native overlay host', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
    await tester.pump();
    fixture.port.addEvent(
      _event('pageStarted', generationId: 7, url: 'https://game.example/'),
    );
    fixture.port.addEvent(
      _event('pageFinished', generationId: 7, url: 'https://game.example/'),
    );
    await tester.pump();
    await tester.pump();
    fixture.port.visibilityFailuresRemaining = 3;

    fixture.port.addEvent(
      _event(
        'mainFrameError',
        generationId: 7,
        errorCode: -2,
        description: 'failed',
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      fixture.port.calls.where((call) => call == 'visible:false'),
      hasLength(greaterThanOrEqualTo(3)),
    );
    expect(fixture.port.calls, contains('destroy'));
    expect(find.byKey(const Key('native-game-surface-error')), findsOneWidget);
    fixture.toolbarController.collapse();
  });

  testWidgets('an unexpected event-stream close fails and hides the surface', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
    await tester.pump();
    fixture.port.addEvent(
      _event('pageStarted', generationId: 7, url: 'https://game.example/'),
    );
    fixture.port.addEvent(
      _event('pageFinished', generationId: 7, url: 'https://game.example/'),
    );
    await tester.pump();
    await tester.pump();
    fixture.port.calls.clear();

    await fixture.port.close();
    await tester.pump();

    expect(fixture.statusController.loadState, WebViewLoadState.failed);
    expect(fixture.port.calls, contains('visible:false'));
    expect(tester.takeException(), isNull);
    fixture.toolbarController.collapse();
  });

  testWidgets('does not touch the Android channel without an injected port', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    fixture.orchestrator.disposeFailure = StateError('orchestrator failed');

    final previousDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {};
    try {
      await fixture.pump(tester, injectPort: false);
      await tester.pump();

      expect(fixture.port.calls, isEmpty);
      expect(find.byType(NativeGameSurfaceSlot), findsOneWidget);
      expect(
        find.byKey(const Key('native-game-surface-error')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
    } finally {
      debugPrint = previousDebugPrint;
      debugDefaultTargetPlatformOverride = null;
    }
  });

  test('rejects incomplete default-orchestrator dependencies at runtime', () {
    expect(
      () => NativeActivityGameSurface(
        statusController: PrototypeStatusController(),
        browserController: GameBrowserController(),
        toolbarController: GameToolbarController(),
        routeObserver: RouteObserver<ModalRoute<dynamic>>(),
      ),
      throwsArgumentError,
    );
  });

  testWidgets('hot update migrates the attached browser controller', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
    await tester.pump();
    final nextBrowserController = GameBrowserController();
    addTearDown(nextBrowserController.dispose);

    await fixture.pump(tester, browserController: nextBrowserController);
    fixture.port.calls.clear();
    await nextBrowserController.reload();
    expect(fixture.port.calls, contains('reload'));

    fixture.port.calls.clear();
    await fixture.browserController.reload();
    expect(fixture.port.calls, isNot(contains('reload')));
    expect(fixture.browserController.errorMessage, 'WebView 尚未就绪');
  });

  testWidgets('hot update replaces the orchestrator and invalidates old work', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
    await _pumpUntil(
      tester,
      () => fixture.port.calls.any((call) => call.startsWith('load:')),
    );
    final loadCallsBeforeUpdate = fixture.port.calls
        .where((call) => call.startsWith('load:'))
        .length;
    final oldFinish = Completer<void>();
    fixture.orchestrator.prepareCaptureCompleter = oldFinish;
    fixture.port.addEvent(
      _event('pageFinished', generationId: 7, url: 'https://game.example/old'),
    );
    await tester.pump();
    final nextOrchestrator = _FakeStartupOrchestrator();

    await fixture.pump(tester, startupOrchestrator: nextOrchestrator);
    oldFinish.complete();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(fixture.orchestrator.disposeCalls, 1);

    fixture.port.addEvent(
      _event('pageStarted', generationId: 7, url: 'https://game.example/new'),
    );
    fixture.port.addEvent(
      _event('pageFinished', generationId: 7, url: 'https://game.example/new'),
    );
    await tester.pump();
    await tester.pump();
    expect(nextOrchestrator.prepareCaptureCalls, 2);
    expect(
      fixture.port.calls.where((call) => call.startsWith('load:')),
      hasLength(loadCallsBeforeUpdate),
    );
    expect(fixture.statusController.loadState, WebViewLoadState.ready);
    fixture.toolbarController.collapse();
  });

  testWidgets(
    'hot update restarts bootstrap when old network work is pending',
    (tester) async {
      final fixture = _SurfaceFixture();
      addTearDown(fixture.dispose);
      final oldNetwork = Completer<GameSurfaceNetworkResult>();
      fixture.orchestrator.networkCompleter = oldNetwork;
      await fixture.pump(tester);
      await _pumpUntil(
        tester,
        () => fixture.orchestrator.applyNetworkCalls == 1,
      );
      final nextOrchestrator = _FakeStartupOrchestrator();

      await fixture.pump(tester, startupOrchestrator: nextOrchestrator);
      oldNetwork.complete(const GameSurfaceNetworkResult.success());
      await _pumpUntil(tester, () => nextOrchestrator.applyNetworkCalls == 1);
      await _pumpUntil(
        tester,
        () => fixture.port.calls.any((call) => call.startsWith('load:')),
      );

      expect(nextOrchestrator.prepareCaptureCalls, 1);
      expect(fixture.orchestrator.disposeCalls, 1);
    },
  );

  testWidgets('hot update replays a pending capture revision', (tester) async {
    final captureModeController = await CaptureModeController.load(
      const _GameCaptureModeStore(),
    );
    addTearDown(captureModeController.dispose);
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    await fixture.pump(tester, captureModeController: captureModeController);
    await _pumpUntil(
      tester,
      () => fixture.port.calls.any((call) => call.startsWith('load:')),
    );
    fixture.port.calls.clear();
    final oldCapture = Completer<void>();
    fixture.orchestrator.prepareCaptureCompleter = oldCapture;
    await captureModeController.setMode(CaptureMode.browserOnly);
    await tester.pump();
    final nextOrchestrator = _FakeStartupOrchestrator();

    await fixture.pump(
      tester,
      captureModeController: captureModeController,
      startupOrchestrator: nextOrchestrator,
    );
    await captureModeController.setMode(CaptureMode.game);
    oldCapture.complete();
    await tester.pump();
    await tester.pump();

    expect(nextOrchestrator.prepareCaptureCalls, greaterThanOrEqualTo(2));
    expect(fixture.port.calls.where((call) => call == 'reload'), hasLength(1));
  });

  testWidgets(
    'forwards current-generation page events and ignores stale ones',
    (tester) async {
      final fixture = _SurfaceFixture();
      addTearDown(fixture.dispose);
      await fixture.pump(tester);
      await tester.pump();

      fixture.port.addEvent(
        _event(
          'pageStarted',
          generationId: 7,
          url: 'https://www.dmm.com/start',
        ),
      );
      await tester.pump();
      expect(fixture.statusController.loadState, WebViewLoadState.loading);
      expect(fixture.browserController.loadState, GamePageLoadState.loading);

      fixture.port.addEvent(
        _event('pageFinished', generationId: 6, url: 'https://stale.example/'),
      );
      await tester.pump();
      expect(fixture.statusController.loadState, WebViewLoadState.loading);

      fixture.port.addEvent(
        _event(
          'pageFinished',
          generationId: 7,
          url: 'https://www.dmm.com/ready?token=secret',
        ),
      );
      await tester.pump();
      expect(fixture.statusController.loadState, WebViewLoadState.ready);
      expect(fixture.browserController.loadState, GamePageLoadState.ready);
      expect(
        fixture.browserController.displayAddress,
        'https://www.dmm.com/ready',
      );

      fixture.port.addEvent(
        _event(
          'mainFrameError',
          generationId: 7,
          errorCode: -2,
          description: 'network failed',
        ),
      );
      await tester.pump();
      expect(fixture.statusController.loadState, WebViewLoadState.failed);
      expect(fixture.browserController.loadState, GamePageLoadState.failed);

      fixture.port.addEvent(
        _event('navigationBlocked', generationId: 7, scheme: 'intent'),
      );
      await tester.pump();
      expect(fixture.browserController.errorMessage, contains('intent'));

      final finishCalls = fixture.orchestrator.prepareCaptureCalls;
      fixture.port.addEvent(
        _event(
          'pageFinished',
          generationId: 7,
          url: 'https://game.example/late',
        ),
      );
      await tester.pump();
      expect(fixture.statusController.loadState, WebViewLoadState.failed);
      expect(fixture.browserController.loadState, GamePageLoadState.failed);
      expect(fixture.browserController.errorMessage, contains('intent'));
      expect(fixture.orchestrator.prepareCaptureCalls, finishCalls);
      fixture.toolbarController.collapse();
    },
  );

  testWidgets(
    'consecutive errors ignore stale-generation and late page finishes',
    (tester) async {
      final fixture = _SurfaceFixture();
      addTearDown(fixture.dispose);
      await fixture.pump(tester);
      await tester.pump();
      final finishCalls = fixture.orchestrator.prepareCaptureCalls;
      final address = fixture.browserController.displayAddress;

      fixture.port.addEvent(
        _event(
          'mainFrameError',
          generationId: 7,
          errorCode: -2,
          description: 'first failure',
        ),
      );
      fixture.port.addEvent(
        _event(
          'mainFrameError',
          generationId: 7,
          errorCode: -3,
          description: 'second failure',
        ),
      );
      fixture.port.addEvent(
        _event(
          'pageStarted',
          generationId: 6,
          url: 'https://stale.example/start',
        ),
      );
      fixture.port.addEvent(
        _event(
          'pageFinished',
          generationId: 6,
          url: 'https://stale.example/finish',
        ),
      );
      fixture.port.addEvent(
        _event(
          'pageFinished',
          generationId: 7,
          url: 'https://game.example/late',
        ),
      );
      await tester.pump();

      expect(fixture.statusController.loadState, WebViewLoadState.failed);
      expect(fixture.browserController.loadState, GamePageLoadState.failed);
      expect(fixture.browserController.errorMessage, 'second failure');
      expect(fixture.browserController.displayAddress, address);
      expect(fixture.orchestrator.prepareCaptureCalls, finishCalls);
      fixture.toolbarController.collapse();
    },
  );

  testWidgets('a new page can recover after a main-frame error', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
    await tester.pump();

    fixture.port.addEvent(
      _event(
        'mainFrameError',
        generationId: 7,
        errorCode: -2,
        description: 'network failed',
      ),
    );
    fixture.port.addEvent(
      _event('pageStarted', generationId: 7, url: 'https://game.example/new'),
    );
    await tester.pump();

    expect(fixture.statusController.loadState, WebViewLoadState.loading);
    expect(fixture.browserController.loadState, GamePageLoadState.loading);

    fixture.port.addEvent(
      _event('pageFinished', generationId: 7, url: 'https://game.example/new'),
    );
    await tester.pump();
    await tester.pump();

    expect(fixture.statusController.loadState, WebViewLoadState.ready);
    expect(fixture.browserController.loadState, GamePageLoadState.ready);
    expect(find.byKey(const Key('native-game-surface-error')), findsNothing);
    fixture.toolbarController.collapse();
  });

  testWidgets('uses the app route observer to hide and restore the surface', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
    await tester.pump();
    fixture.port.addEvent(
      _event('pageStarted', generationId: 7, url: 'https://game.example/'),
    );
    fixture.port.addEvent(
      _event('pageFinished', generationId: 7, url: 'https://game.example/'),
    );
    await tester.pump();
    await tester.pump();
    fixture.port.calls.clear();

    unawaited(
      fixture.navigatorKey.currentState!.push<void>(
        PageRouteBuilder<void>(
          pageBuilder: (_, _, _) => const Text('cover'),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(fixture.port.calls, contains('visible:false'));

    fixture.port.calls.clear();
    fixture.navigatorKey.currentState!.pop();
    await tester.pump();
    await tester.pump();
    expect(fixture.port.calls, contains('visible:true'));
    fixture.toolbarController.collapse();
  });

  testWidgets(
    'render-process exit reports failure without an automatic recreate',
    (tester) async {
      final fixture = _SurfaceFixture();
      addTearDown(fixture.dispose);
      await fixture.pump(tester);
      await tester.pump();

      fixture.port.addEvent(
        _event('renderProcessGone', generationId: 7, didCrash: true),
      );
      await tester.pump();

      expect(fixture.statusController.loadState, WebViewLoadState.failed);
      expect(fixture.browserController.loadState, GamePageLoadState.failed);
      expect(
        fixture.port.calls.where((call) => call == 'create'),
        hasLength(1),
      );
      final networkCalls = fixture.orchestrator.applyNetworkCalls;
      fixture.networkSettingsController.emitChange();
      await tester.pump();
      expect(fixture.orchestrator.applyNetworkCalls, networkCalls);
      expect(fixture.port.calls.where((call) => call == 'reload'), isEmpty);
    },
  );

  testWidgets('every error boundary invalidates a pending startup', (
    tester,
  ) async {
    final boundaries = <({String name, void Function(_FakeNativePort) emit})>[
      (
        name: 'main-frame error',
        emit: (port) => port.addEvent(
          _event(
            'mainFrameError',
            generationId: 7,
            errorCode: -2,
            description: 'network failed',
          ),
        ),
      ),
      (
        name: 'render gone',
        emit: (port) => port.addEvent(
          _event('renderProcessGone', generationId: 7, didCrash: true),
        ),
      ),
      (
        name: 'destroyed',
        emit: (port) => port.addEvent(_event('destroyed', generationId: 7)),
      ),
      (
        name: 'event-channel error',
        emit: (port) => port.addError(StateError('channel failed')),
      ),
    ];

    final previousDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {};
    try {
      for (final boundary in boundaries) {
        final fixture = _SurfaceFixture();
        final network = Completer<GameSurfaceNetworkResult>();
        fixture.orchestrator.networkCompleter = network;
        await fixture.pump(tester);
        await _pumpUntil(
          tester,
          () => fixture.orchestrator.applyNetworkCalls == 1,
        );

        boundary.emit(fixture.port);
        await tester.pump();
        network.complete(const GameSurfaceNetworkResult.success());
        await tester.pump();
        await tester.pump();

        expect(
          fixture.port.calls.where((call) => call.startsWith('load:')),
          isEmpty,
          reason: boundary.name,
        );
        expect(
          fixture.statusController.loadState,
          WebViewLoadState.failed,
          reason: boundary.name,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await fixture.dispose();
      }
    } finally {
      debugPrint = previousDebugPrint;
    }
  });

  testWidgets('a terminal event invalidates a pending page finish', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
    await tester.pump();
    final audioCalls = fixture.orchestrator.attachAudioCalls;
    final capture = Completer<void>();
    fixture.orchestrator.prepareCaptureCompleter = capture;

    fixture.port.addEvent(
      _event('pageFinished', generationId: 7, url: 'https://game.example/'),
    );
    await tester.pump();
    fixture.port.addEvent(
      _event('renderProcessGone', generationId: 7, didCrash: true),
    );
    await tester.pump();
    capture.complete();
    await tester.pump();

    expect(fixture.orchestrator.attachAudioCalls, audioCalls);
    expect(fixture.statusController.loadState, WebViewLoadState.failed);
    expect(find.byKey(const Key('native-game-surface-error')), findsOneWidget);
  });

  testWidgets('a new page invalidates the previous pending page finish', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
    await tester.pump();
    final audioCalls = fixture.orchestrator.attachAudioCalls;
    final capture = Completer<void>();
    fixture.orchestrator.prepareCaptureCompleter = capture;

    fixture.port.addEvent(
      _event('pageFinished', generationId: 7, url: 'https://game.example/a'),
    );
    await tester.pump();
    fixture.port.addEvent(
      _event('pageStarted', generationId: 7, url: 'https://game.example/b'),
    );
    await tester.pump();
    fixture.toolbarController.collapse();
    capture.complete();
    await tester.pump();

    expect(fixture.orchestrator.attachAudioCalls, audioCalls);
    expect(fixture.statusController.loadState, WebViewLoadState.loading);
  });

  testWidgets('network retry is single-flight and reloads once after success', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    fixture.networkSettingsController.settingsValue = const NetworkSettings(
      mode: NetworkMode.httpProxy,
      host: '127.0.0.1',
      port: 8080,
    );
    fixture.orchestrator.networkResult = const GameSurfaceNetworkResult(
      success: false,
      code: 'failed',
      message: 'failed',
    );
    await fixture.pump(tester);
    await _pumpUntil(
      tester,
      () => find
          .byKey(const Key('native-game-surface-error'))
          .evaluate()
          .isNotEmpty,
    );
    expect(find.byKey(const Key('native-game-surface-error')), findsOneWidget);

    final retry = Completer<GameSurfaceNetworkResult>();
    fixture.orchestrator.networkCompleter = retry;
    fixture.networkSettingsController.emitChange();
    fixture.networkSettingsController.emitChange();
    await tester.pump();
    expect(fixture.orchestrator.applyNetworkCalls, 2);

    retry.complete(const GameSurfaceNetworkResult.success());
    await tester.pump();
    expect(fixture.port.calls.where((call) => call == 'reload'), hasLength(1));
    fixture.networkSettingsController.emitChange();
    await tester.pump();
    expect(fixture.orchestrator.applyNetworkCalls, 2);
  });

  testWidgets('a failed retry reload remains retryable until one success', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    fixture.networkSettingsController.settingsValue = const NetworkSettings(
      mode: NetworkMode.httpProxy,
      host: '127.0.0.1',
      port: 8080,
    );
    fixture.orchestrator.networkResult = const GameSurfaceNetworkResult(
      success: false,
      code: 'failed',
      message: 'failed',
    );
    await fixture.pump(tester);
    await _pumpUntil(
      tester,
      () => find
          .byKey(const Key('native-game-surface-error'))
          .evaluate()
          .isNotEmpty,
    );
    fixture.orchestrator.networkResult =
        const GameSurfaceNetworkResult.success();
    fixture.port.reloadFailure = StateError('reload failed');

    final previousDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {};
    try {
      fixture.networkSettingsController.emitChange();
      await tester.pump();
      await tester.pump();
      expect(
        find.byKey(const Key('native-game-surface-error')),
        findsOneWidget,
      );
      expect(fixture.orchestrator.applyNetworkCalls, 2);

      fixture.port.reloadFailure = null;
      fixture.networkSettingsController.emitChange();
      await tester.pump();
      await tester.pump();
    } finally {
      debugPrint = previousDebugPrint;
    }

    expect(fixture.orchestrator.applyNetworkCalls, 3);
    expect(fixture.port.successfulReloadCalls, 1);
  });

  for (final failureStage in <String>['capture', 'audio']) {
    testWidgets('$failureStage finish failure is contained and hides', (
      tester,
    ) async {
      final fixture = _SurfaceFixture();
      addTearDown(fixture.dispose);
      await fixture.pump(tester);
      await _pumpUntil(
        tester,
        () => fixture.port.calls.any((call) => call.startsWith('load:')),
      );
      if (failureStage == 'capture') {
        fixture.orchestrator.prepareCaptureFailure = StateError(
          'capture failed',
        );
      } else {
        fixture.orchestrator.attachAudioFailure = StateError('audio failed');
      }

      final previousDebugPrint = debugPrint;
      debugPrint = (message, {wrapWidth}) {};
      try {
        fixture.port.addEvent(
          _event('pageStarted', generationId: 7, url: 'https://game.example/'),
        );
        fixture.port.addEvent(
          _event('pageFinished', generationId: 7, url: 'https://game.example/'),
        );
        await tester.pump();
        await tester.pump();
      } finally {
        debugPrint = previousDebugPrint;
      }

      expect(fixture.statusController.loadState, WebViewLoadState.failed);
      expect(
        find.byKey(const Key('native-game-surface-error')),
        findsOneWidget,
      );
      expect(
        fixture.port.calls.lastWhere((call) => call.startsWith('visible:')),
        'visible:false',
      );
      expect(tester.takeException(), isNull);
      fixture.toolbarController.collapse();
    });
  }

  testWidgets('rapid capture changes reload only the final mode', (
    tester,
  ) async {
    final captureModeController = await CaptureModeController.load(
      const _GameCaptureModeStore(),
    );
    addTearDown(captureModeController.dispose);
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    await fixture.pump(tester, captureModeController: captureModeController);
    await _pumpUntil(
      tester,
      () => fixture.port.calls.any((call) => call.startsWith('load:')),
    );
    fixture.port.calls.clear();
    final capture = Completer<void>();
    fixture.orchestrator.prepareCaptureCompleter = capture;

    await captureModeController.setMode(CaptureMode.browserOnly);
    await tester.pump();
    await captureModeController.setMode(CaptureMode.game);
    await tester.pump();
    capture.complete();
    await tester.pump();
    await tester.pump();

    expect(fixture.port.calls.where((call) => call == 'reload'), hasLength(1));
  });

  for (final terminalType in <String>['renderProcessGone', 'destroyed']) {
    testWidgets(
      '$terminalType prevents a pending network retry from reloading',
      (tester) async {
        final fixture = _SurfaceFixture();
        addTearDown(fixture.dispose);
        fixture.networkSettingsController.settingsValue = const NetworkSettings(
          mode: NetworkMode.httpProxy,
          host: '127.0.0.1',
          port: 8080,
        );
        fixture.orchestrator.networkResult = const GameSurfaceNetworkResult(
          success: false,
          code: 'failed',
          message: 'failed',
        );
        await fixture.pump(tester);
        await _pumpUntil(
          tester,
          () => find
              .byKey(const Key('native-game-surface-error'))
              .evaluate()
              .isNotEmpty,
        );

        final retry = Completer<GameSurfaceNetworkResult>();
        fixture.orchestrator.networkCompleter = retry;
        fixture.networkSettingsController.emitChange();
        await tester.pump();
        fixture.port.addEvent(
          terminalType == 'destroyed'
              ? _event('destroyed', generationId: 7)
              : _event('renderProcessGone', generationId: 7, didCrash: true),
        );
        await tester.pump();
        retry.complete(const GameSurfaceNetworkResult.success());
        await tester.pump();

        expect(fixture.port.calls.where((call) => call == 'reload'), isEmpty);
        expect(fixture.statusController.loadState, WebViewLoadState.failed);
      },
    );
  }

  testWidgets('dispose invalidates a pending startup before destruction', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    final network = Completer<GameSurfaceNetworkResult>();
    fixture.orchestrator.networkCompleter = network;
    await fixture.pump(tester);
    await _pumpUntil(tester, () => fixture.orchestrator.applyNetworkCalls == 1);

    await tester.pumpWidget(const SizedBox.shrink());
    network.complete(const GameSurfaceNetworkResult.success());
    await tester.pump();
    await _pumpUntilDestroyed(tester, fixture.port);

    expect(
      fixture.port.calls.where((call) => call.startsWith('load:')),
      isEmpty,
    );
  });

  testWidgets(
    'hide failure cannot block detach-cancel-destroy disposal order',
    (tester) async {
      final fixture = _SurfaceFixture();
      addTearDown(fixture.dispose);
      await fixture.pump(tester);
      await tester.pump();
      fixture.port.calls.clear();
      fixture.port.failHide = true;
      fixture.port.beforeCancel = () {
        unawaited(fixture.browserController.reload());
        fixture.port.calls.add(
          fixture.browserController.errorMessage == 'WebView 尚未就绪'
              ? 'detach'
              : 'detach:missing',
        );
      };

      final previousDebugPrint = debugPrint;
      debugPrint = (message, {wrapWidth}) {};
      try {
        await tester.pumpWidget(const SizedBox());
        await _pumpUntilDestroyed(tester, fixture.port);
      } finally {
        debugPrint = previousDebugPrint;
      }

      final hideIndex = fixture.port.calls.indexOf('visible:false');
      final detachIndex = fixture.port.calls.indexOf('detach');
      final cancelIndex = fixture.port.calls.indexOf('cancel');
      final destroyIndex = fixture.port.calls.indexOf('destroy');
      expect(hideIndex, greaterThanOrEqualTo(0));
      expect(detachIndex, greaterThan(hideIndex));
      expect(cancelIndex, greaterThan(detachIndex));
      expect(destroyIndex, greaterThan(cancelIndex));
    },
  );

  testWidgets('destroy waits for asynchronous event cancellation', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
    await tester.pump();
    final cancellation = Completer<void>();
    fixture.port.cancelCompleter = cancellation;

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(fixture.port.calls, contains('cancel'));
    expect(fixture.port.calls, isNot(contains('destroy')));

    cancellation.complete();
    await _pumpUntilDestroyed(tester, fixture.port);
    expect(
      fixture.port.calls.indexOf('destroy'),
      greaterThan(fixture.port.calls.indexOf('cancel')),
    );
  });

  testWidgets('cancel timeout still destroys and contains a late error', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    fixture.port.cancelCompleter = Completer<void>();
    await fixture.pump(tester, cleanupTimeout: const Duration(milliseconds: 1));
    await tester.pump();

    final previousDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {};
    try {
      await tester.pumpWidget(const SizedBox.shrink());
      for (var pumpCount = 0; pumpCount < 4; pumpCount++) {
        await tester.pump(const Duration(milliseconds: 2));
      }
      await _pumpUntilDestroyed(tester, fixture.port);
      fixture.port.cancelFailure = StateError('late cancel failure');
      fixture.port.cancelCompleter!.complete();
      await tester.pump();
    } finally {
      debugPrint = previousDebugPrint;
    }

    expect(fixture.port.calls, contains('destroy'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('orchestrator timeout still destroys and contains a late error', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    fixture.orchestrator.disposeCompleter = Completer<void>();
    await fixture.pump(tester, cleanupTimeout: const Duration(milliseconds: 1));
    await tester.pump();

    final previousDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {};
    try {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 2));
      await tester.pump(const Duration(milliseconds: 2));
      await _pumpUntilDestroyed(tester, fixture.port);
      fixture.orchestrator.disposeAsyncFailure = StateError(
        'late orchestrator failure',
      );
      fixture.orchestrator.disposeCompleter!.complete();
      await tester.pump();
    } finally {
      debugPrint = previousDebugPrint;
    }

    expect(fixture.port.calls, contains('destroy'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a cancellation error still allows native destruction', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
    await tester.pump();
    final cancellation = Completer<void>();
    fixture.port.cancelCompleter = cancellation;

    final previousDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {};
    try {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(fixture.port.calls, isNot(contains('destroy')));
      fixture.port.cancelFailure = StateError('cancel failed');
      cancellation.complete();
      await _pumpUntilDestroyed(tester, fixture.port);
    } finally {
      debugPrint = previousDebugPrint;
    }
    expect(fixture.port.calls, contains('destroy'));
  });

  testWidgets('cleanup isolates orchestrator and native destroy failures', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
    await tester.pump();
    fixture.orchestrator.disposeFailure = StateError('orchestrator failed');
    fixture.port.disposeFailure = StateError('destroy failed');

    final previousDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {};
    try {
      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpUntilDestroyed(tester, fixture.port);
      await tester.pump();
    } finally {
      debugPrint = previousDebugPrint;
    }

    expect(fixture.port.calls, contains('destroy'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('an asynchronous orchestrator dispose failure still destroys', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
    await tester.pump();
    fixture.orchestrator.disposeAsyncFailure = StateError(
      'async orchestrator failed',
    );

    final previousDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {};
    try {
      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpUntilDestroyed(tester, fixture.port);
      await tester.pump();
    } finally {
      debugPrint = previousDebugPrint;
    }

    expect(fixture.port.calls, contains('destroy'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('fatal render exit still accepts destroyed and detaches port', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
    await tester.pump();

    fixture.port.addEvent(
      _event('renderProcessGone', generationId: 7, didCrash: true),
    );
    fixture.port.addEvent(
      _event(
        'pageStarted',
        generationId: 7,
        url: 'https://game.example/ignored',
      ),
    );
    fixture.port.addEvent(
      _event(
        'pageFinished',
        generationId: 7,
        url: 'https://game.example/ignored',
      ),
    );
    fixture.port.addEvent(
      _event('navigationBlocked', generationId: 7, scheme: 'ignored'),
    );
    await tester.pump();

    expect(fixture.browserController.errorMessage, '游戏渲染进程已退出。');
    expect(fixture.statusController.loadState, WebViewLoadState.failed);

    fixture.port.addEvent(_event('destroyed', generationId: 7));
    await tester.pump();
    fixture.port.calls.clear();
    await fixture.browserController.reload();

    expect(fixture.port.calls, isNot(contains('reload')));
    expect(fixture.browserController.errorMessage, 'WebView 尚未就绪');
    expect(fixture.statusController.loadState, WebViewLoadState.failed);
  });

  testWidgets('disposing an old surface does not detach a newer port', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
    await tester.pump();

    final newerPort = _RecordingBrowserPort();
    fixture.browserController.attachPort(newerPort);
    await tester.pumpWidget(const SizedBox());
    await _pumpUntilDestroyed(tester, fixture.port);

    await fixture.browserController.reload();
    expect(newerPort.reloadCalls, 1);
  });

  testWidgets(
    'a current destroyed event detaches once and stale callbacks stay inert',
    (tester) async {
      final fixture = _SurfaceFixture();
      addTearDown(fixture.dispose);
      await fixture.pump(tester);
      await tester.pump();

      fixture.port.addEvent(_event('destroyed', generationId: 7));
      await tester.pump();
      final messageAfterDestroy = fixture.browserController.errorMessage;

      fixture.port.addEvent(
        _event('pageFinished', generationId: 7, url: 'https://late.example/'),
      );
      await tester.pump();
      expect(fixture.browserController.errorMessage, messageAfterDestroy);
      expect(
        fixture.browserController.loadState,
        isNot(GamePageLoadState.ready),
      );
    },
  );
}

NativeGameWebViewEvent _event(
  String type, {
  required int generationId,
  String? url,
  int? errorCode,
  String? description,
  String? scheme,
  bool? didCrash,
}) {
  return NativeGameWebViewEvent.decode(<String, Object?>{
    'type': type,
    'generationId': generationId,
    'url': ?url,
    'errorCode': ?errorCode,
    'description': ?description,
    'scheme': ?scheme,
    'didCrash': ?didCrash,
  });
}

Future<void> _pumpUntilDestroyed(
  WidgetTester tester,
  _FakeNativePort port,
) async {
  for (
    var pumpCount = 0;
    pumpCount < 20 && !port.destroyed.isCompleted;
    pumpCount++
  ) {
    await tester.pump();
  }
  expect(port.destroyed.isCompleted, isTrue, reason: port.calls.toString());
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var pumpCount = 0; pumpCount < 8 && !condition(); pumpCount++) {
    await tester.pump();
  }
  expect(condition(), isTrue);
}

final class _DefaultOrchestratorFixture {
  _DefaultOrchestratorFixture._({
    required this.orchestrator,
    required this.networkController,
    required this.captureModeController,
    required this.audioController,
    required this.frameRateController,
    required this.captureController,
  });

  final DefaultGameSurfaceStartupOrchestrator orchestrator;
  final _RecordingNetworkController networkController;
  final CaptureModeController captureModeController;
  final GameAudioController audioController;
  final GameFrameRateSettingsController frameRateController;
  final GameCaptureController captureController;

  static Future<_DefaultOrchestratorFixture> create(
    List<String> calls, {
    GameCapturePort Function()? capturePortFactory,
    GameAudioPort Function()? audioPortFactory,
  }) async {
    final networkController = _RecordingNetworkController(calls);
    final captureModeController = await CaptureModeController.load(
      const _GameCaptureModeStore(),
    );
    final audioController = await GameAudioController.load(
      const _GameAudioMemoryStore(),
    );
    final frameRateController = await GameFrameRateSettingsController.load(
      MemoryGameFrameRateSettingsStore(),
    );
    final captureController = GameCaptureController();
    final orchestrator = DefaultGameSurfaceStartupOrchestrator(
      networkSettingsController: networkController,
      captureModeController: captureModeController,
      audioController: audioController,
      gameCaptureController: captureController,
      frameRateSettingsController: frameRateController,
      capturePortFactory:
          capturePortFactory ?? () => _RecordingCapturePort(calls),
      audioPortFactory: audioPortFactory ?? () => _RecordingAudioPort(calls),
      frameRatePortFactory: () => _RecordingFrameRatePort(calls),
    );
    return _DefaultOrchestratorFixture._(
      orchestrator: orchestrator,
      networkController: networkController,
      captureModeController: captureModeController,
      audioController: audioController,
      frameRateController: frameRateController,
      captureController: captureController,
    );
  }

  void dispose() {
    orchestrator.dispose();
    captureController.dispose();
    frameRateController.dispose();
    audioController.dispose();
    captureModeController.dispose();
    networkController.dispose();
  }
}

final class _RecordingNetworkController extends NetworkSettingsController {
  _RecordingNetworkController(this.calls)
    : super(store: _MemoryNetworkSettingsStore());

  final List<String> calls;
  final List<ProxyResult> results = <ProxyResult>[];

  @override
  Future<ProxyResult> applySettings(
    NetworkMode mode,
    String host,
    int port,
  ) async {
    calls.add('network');
    if (results.isNotEmpty) return results.removeAt(0);
    return const ProxyResult(
      success: true,
      code: 'ok',
      message: '',
      elapsedMs: 0,
    );
  }
}

final class _RecordingCapturePort implements GameCapturePort {
  _RecordingCapturePort(this.calls);

  final List<String> calls;

  @override
  Stream<CapturedApiEvent> get events => const Stream<CapturedApiEvent>.empty();

  @override
  Future<bool> isSupported() async {
    calls.add('capture.supported');
    return true;
  }

  @override
  Future<void> configure({
    required bool enabled,
    required String script,
  }) async => calls.add('capture.configure:$enabled');

  @override
  void dispose() {}
}

final class _BlockingCapturePort implements GameCapturePort {
  _BlockingCapturePort(this.firstConfigure);

  final Completer<void> firstConfigure;
  final List<bool> enabledCalls = <bool>[];

  @override
  Stream<CapturedApiEvent> get events => const Stream<CapturedApiEvent>.empty();

  @override
  Future<bool> isSupported() async => true;

  @override
  Future<void> configure({
    required bool enabled,
    required String script,
  }) async {
    enabledCalls.add(enabled);
    if (enabledCalls.length == 1) await firstConfigure.future;
  }

  @override
  void dispose() {}
}

final class _RecordingAudioPort implements GameAudioPort {
  _RecordingAudioPort(this.calls);

  final List<String> calls;

  @override
  Future<bool> isSupported() async {
    calls.add('audio.supported');
    return true;
  }

  @override
  Future<void> setMuted(bool muted) async => calls.add('audio.muted:$muted');
}

final class _BlockingAudioPort implements GameAudioPort {
  _BlockingAudioPort(this.supported);

  final Future<bool> supported;

  @override
  Future<bool> isSupported() => supported;

  @override
  Future<void> setMuted(bool muted) async {}
}

final class _RecordingFrameRatePort implements GameFrameRatePort {
  _RecordingFrameRatePort(this.calls);

  final List<String> calls;

  @override
  Future<bool> isSupported() async {
    calls.add('frame.supported');
    return true;
  }

  @override
  Future<void> configure(GameFrameRateMode mode) async =>
      calls.add('frame.configure:${mode.wireName}');
}

final class _GameCaptureModeStore implements CaptureModeStore {
  const _GameCaptureModeStore();

  @override
  Future<CaptureMode?> read() async => CaptureMode.game;

  @override
  Future<void> write(CaptureMode mode) async {}
}

final class _GameAudioMemoryStore implements GameAudioStore {
  const _GameAudioMemoryStore();

  @override
  Future<bool?> readBackgroundPlaybackEnabled() async => false;

  @override
  Future<bool?> readMuted() async => false;

  @override
  Future<void> writeBackgroundPlaybackEnabled(bool enabled) async {}

  @override
  Future<void> writeMuted(bool muted) async {}
}

final class _SurfaceFixture {
  _SurfaceFixture()
    : statusController = PrototypeStatusController(),
      browserController = GameBrowserController() {
    toolbarController = GameToolbarController()..collapse();
  }

  final PrototypeStatusController statusController;
  final GameBrowserController browserController;
  late final GameToolbarController toolbarController;
  final networkSettingsController = _TestNetworkSettingsController();
  final port = _FakeNativePort();
  final orchestrator = _FakeStartupOrchestrator();
  final observer = RouteObserver<ModalRoute<dynamic>>();
  final navigatorKey = GlobalKey<NavigatorState>();

  Future<void> pump(
    WidgetTester tester, {
    bool injectPort = true,
    Duration? cleanupTimeout,
    CaptureModeController? captureModeController,
    GameBrowserController? browserController,
    GameSurfaceStartupOrchestrator? startupOrchestrator,
  }) {
    if (tester.binding.lifecycleState != AppLifecycleState.resumed) {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    }
    return tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        navigatorObservers: <NavigatorObserver>[observer],
        home: SizedBox(
          width: 800,
          height: 480,
          child: NativeActivityGameSurface(
            statusController: statusController,
            browserController: browserController ?? this.browserController,
            toolbarController: toolbarController,
            routeObserver: observer,
            networkSettingsController: networkSettingsController,
            captureModeController: captureModeController,
            portFactory: injectPort ? () => port : null,
            startupOrchestrator: startupOrchestrator ?? orchestrator,
            cleanupTimeout: cleanupTimeout,
          ),
        ),
      ),
    );
  }

  Future<void> dispose() async {
    statusController.dispose();
    browserController.dispose();
    toolbarController.dispose();
    networkSettingsController.dispose();
  }
}

final class _FakeNativePort implements NativeActivityGameWebViewPort {
  _FakeNativePort() {
    _events = StreamController<NativeGameWebViewEvent>(
      sync: true,
      onListen: () => calls.add('listen'),
      onCancel: () async {
        beforeCancel?.call();
        calls.add('cancel');
        await cancelCompleter?.future;
        if (cancelFailure case final failure?) throw failure;
      },
    );
  }

  late final StreamController<NativeGameWebViewEvent> _events;
  final List<String> calls = <String>[];
  final Completer<void> destroyed = Completer<void>();
  VoidCallback? beforeCancel;
  Completer<void>? cancelCompleter;
  Object? cancelFailure;
  Object? disposeFailure;
  Object? reloadFailure;
  int successfulReloadCalls = 0;
  final List<Completer<void>> visibilityCompleters = <Completer<void>>[];
  int visibilityFailuresRemaining = 0;
  bool failHide = false;
  final List<NativeGameWebViewEvent> eventsDuringCreate =
      <NativeGameWebViewEvent>[];

  @override
  Stream<NativeGameWebViewEvent> get events => _events.stream;

  void addEvent(NativeGameWebViewEvent event) => _events.add(event);

  void addError(Object error) => _events.addError(error, StackTrace.current);

  @override
  Future<int> create() async {
    calls.add('create');
    for (final event in eventsDuringCreate) {
      _events.add(event);
    }
    return 7;
  }

  @override
  Future<void> setBounds(NativeGameWebViewBounds bounds) async {
    calls.add('bounds');
  }

  @override
  Future<void> setVisible(bool visible) async {
    calls.add('visible:$visible');
    if (visibilityCompleters.isNotEmpty) {
      await visibilityCompleters.removeAt(0).future;
    }
    if (visibilityFailuresRemaining > 0) {
      visibilityFailuresRemaining -= 1;
      throw StateError('visibility failed');
    }
    if (!visible && failHide) throw StateError('hide failed');
  }

  @override
  Future<void> dispose() async {
    calls.add('destroy');
    if (!destroyed.isCompleted) destroyed.complete();
    if (disposeFailure case final failure?) throw failure;
  }

  Future<void> close() async {
    if (!_events.isClosed) unawaited(_events.close());
  }

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
  Future<void> loadUri(Uri uri) async => calls.add('load:${uri.host}');

  @override
  Future<void> reload() async {
    calls.add('reload');
    if (reloadFailure case final failure?) throw failure;
    successfulReloadCalls += 1;
  }

  @override
  Future<void> runJavaScript(String javascript) async {}

  @override
  Future<void> showLocalHome() async {}
}

final class _FakeStartupOrchestrator implements GameSurfaceStartupOrchestrator {
  int applyNetworkCalls = 0;
  int prepareCaptureCalls = 0;
  int attachAudioCalls = 0;
  GameSurfaceNetworkResult networkResult =
      const GameSurfaceNetworkResult.success();
  Completer<GameSurfaceNetworkResult>? networkCompleter;
  Completer<void>? prepareCaptureCompleter;
  Completer<void>? disposeCompleter;
  Object? disposeFailure;
  Object? disposeAsyncFailure;
  Object? prepareCaptureFailure;
  Object? attachAudioFailure;
  int disposeCalls = 0;

  @override
  Future<bool> attachFrameRatePlatformPort() async => true;

  @override
  Future<void> attachAudioPortOnce() async {
    attachAudioCalls += 1;
    if (attachAudioFailure case final failure?) throw failure;
  }

  @override
  Future<GameSurfaceNetworkResult> applyNetworkSettings() async {
    applyNetworkCalls++;
    return networkCompleter?.future ?? networkResult;
  }

  @override
  FutureOr<void> dispose() {
    disposeCalls += 1;
    if (disposeFailure case final failure?) throw failure;
    if (disposeCompleter case final completer?) {
      return completer.future.then((_) {
        if (disposeAsyncFailure case final failure?) throw failure;
      });
    }
    if (disposeAsyncFailure case final failure?) {
      return Future<void>.microtask(() => throw failure);
    }
  }

  @override
  Future<void> prepareCapture() async {
    prepareCaptureCalls += 1;
    await prepareCaptureCompleter?.future;
    if (prepareCaptureFailure case final failure?) throw failure;
  }

  @override
  Future<void> runCaptureStartup({
    required Future<void> Function() waitForSurface,
    required bool Function() isActive,
    required Future<void> Function() navigate,
  }) async {
    await waitForSurface();
    if (isActive()) await prepareCapture();
    if (isActive()) await navigate();
  }
}

final class _TestNetworkSettingsController extends NetworkSettingsController {
  _TestNetworkSettingsController()
    : super(store: _MemoryNetworkSettingsStore());

  NetworkSettings settingsValue = const NetworkSettings();

  @override
  NetworkSettings get settings => settingsValue;

  void emitChange() => notifyListeners();
}

final class _MemoryNetworkSettingsStore implements NetworkSettingsStore {
  @override
  Future<NetworkSettings> loadSettings() async => const NetworkSettings();

  @override
  Future<void> saveSettings(NetworkSettings settings) async {}
}

final class _RecordingBrowserPort implements GameBrowserPort {
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
