import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_browser_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/native_game_surface_slot.dart';
import 'package:yahagi_kancolle_browser/src/browser/native_game_webview_contract.dart';
import 'package:yahagi_kancolle_browser/src/game_webview.dart';
import 'package:yahagi_kancolle_browser/src/native_activity_game_surface.dart';
import 'package:yahagi_kancolle_browser/src/prototype_status_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_toolbar_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/network_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/network_settings_store.dart';

void main() {
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
    pumpCount < 5 && !port.destroyed.isCompleted;
    pumpCount++
  ) {
    await tester.pump();
  }
  expect(port.destroyed.isCompleted, isTrue, reason: port.calls.toString());
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
    _events = StreamController<NativeGameWebViewEvent>.broadcast(
      sync: true,
      onListen: () => calls.add('listen'),
      onCancel: () {
        beforeCancel?.call();
        calls.add('cancel');
      },
    );
  }

  late final StreamController<NativeGameWebViewEvent> _events;
  final List<String> calls = <String>[];
  final Completer<void> destroyed = Completer<void>();
  VoidCallback? beforeCancel;
  bool failHide = false;
  final List<NativeGameWebViewEvent> eventsDuringCreate =
      <NativeGameWebViewEvent>[];

  @override
  Stream<NativeGameWebViewEvent> get events => _events.stream;

  void addEvent(NativeGameWebViewEvent event) => _events.add(event);

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
    if (!_events.isClosed) await _events.close();
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

  @override
  Future<bool> attachFrameRatePlatformPort() async => true;

  @override
  Future<void> attachAudioPortOnce() async {}

  @override
  Future<GameSurfaceNetworkResult> applyNetworkSettings() async {
    applyNetworkCalls++;
    return const GameSurfaceNetworkResult.success();
  }

  @override
  void dispose() {}

  @override
  Future<void> prepareCapture() async {}

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
