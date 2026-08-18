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

  testWidgets('does not touch the Android channel without an injected port', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);

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
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
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
        _event('navigationBlocked', generationId: 7, scheme: 'intent'),
      );
      await tester.pump();
      expect(fixture.browserController.errorMessage, contains('intent'));

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
      expect(fixture.browserController.errorMessage, 'network failed');
      fixture.toolbarController.collapse();
    },
  );

  testWidgets('uses the app route observer to hide and restore the surface', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
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

  testWidgets('every terminal signal invalidates a pending startup', (
    tester,
  ) async {
    final terminals = <({String name, void Function(_FakeNativePort) emit})>[
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
      for (final terminal in terminals) {
        final fixture = _SurfaceFixture();
        final network = Completer<GameSurfaceNetworkResult>();
        fixture.orchestrator.networkCompleter = network;
        await fixture.pump(tester);
        await _pumpUntil(
          tester,
          () => fixture.orchestrator.applyNetworkCalls == 1,
        );

        terminal.emit(fixture.port);
        await tester.pump();
        network.complete(const GameSurfaceNetworkResult.success());
        await tester.pump();
        await tester.pump();

        expect(
          fixture.port.calls.where((call) => call.startsWith('load:')),
          isEmpty,
          reason: terminal.name,
        );
        expect(
          fixture.statusController.loadState,
          WebViewLoadState.failed,
          reason: terminal.name,
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

  static Future<_DefaultOrchestratorFixture> create(List<String> calls) async {
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
      capturePortFactory: () => _RecordingCapturePort(calls),
      audioPortFactory: () => _RecordingAudioPort(calls),
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

  Future<void> pump(WidgetTester tester, {bool injectPort = true}) {
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
            browserController: browserController,
            toolbarController: toolbarController,
            routeObserver: observer,
            networkSettingsController: networkSettingsController,
            portFactory: injectPort ? () => port : null,
            startupOrchestrator: orchestrator,
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
    await port.close();
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
    if (!visible && failHide) throw StateError('hide failed');
  }

  @override
  Future<void> dispose() async {
    calls.add('destroy');
    if (!destroyed.isCompleted) destroyed.complete();
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
  Future<void> reload() async => calls.add('reload');

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

  @override
  Future<bool> attachFrameRatePlatformPort() async => true;

  @override
  Future<void> attachAudioPortOnce() async => attachAudioCalls += 1;

  @override
  Future<GameSurfaceNetworkResult> applyNetworkSettings() async {
    applyNetworkCalls++;
    return networkCompleter?.future ?? networkResult;
  }

  @override
  void dispose() {}

  @override
  Future<void> prepareCapture() async {
    prepareCaptureCalls += 1;
    await prepareCaptureCompleter?.future;
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
