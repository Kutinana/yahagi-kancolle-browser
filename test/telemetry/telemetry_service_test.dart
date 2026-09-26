import 'dart:async';
import 'dart:ui';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telemetrydecksdk/telemetrydecksdk.dart';
import 'package:yahagi_kancolle_browser/src/diagnostics/diagnostic_platform_port.dart';
import 'package:yahagi_kancolle_browser/src/telemetry/telemetry_controller.dart';
import 'package:yahagi_kancolle_browser/src/telemetry/telemetry_service.dart';
import 'package:yahagi_kancolle_browser/src/telemetry/telemetry_settings_store.dart';

final class MockDiagnosticPlatformPort implements DiagnosticPlatformPort {
  MockDiagnosticPlatformPort({this.webViewVersion = 'Chrome 124.0.0.0'});

  final String webViewVersion;

  @override
  Future<DiagnosticDeviceSnapshot> deviceSnapshot() async {
    return DiagnosticDeviceSnapshot(
      manufacturer: 'Google',
      model: 'Pixel 8',
      androidSdk: 34,
      androidRelease: '14',
      supportedAbi: 'arm64-v8a',
      memoryClassMb: 512,
      screenWidthPx: 1080,
      screenHeightPx: 2400,
      webViewVersion: webViewVersion,
      previousExitReason: 'unknown',
      previousExitStatus: 0,
      previousExitImportance: 0,
      previousExitPssKb: 0,
      previousExitRssKb: 0,
      previousExitTimestampMs: 0,
    );
  }

  @override
  Future<DiagnosticRuntimeSnapshot> runtimeSnapshot() async {
    return const DiagnosticRuntimeSnapshot(
      pssKb: 0,
      javaHeapKb: 0,
      nativeHeapKb: 0,
      graphicsKb: 0,
      privateOtherKb: 0,
      systemAvailableKb: 0,
      lowMemory: false,
    );
  }

  @override
  Future<String?> saveJson(String json) async => null;

  @override
  Future<void> shareJson(String path) async {}
}

class FakeAndroidDeviceInfo {
  static AndroidDeviceInfo create({
    String manufacturer = 'Xiaomi',
    String model = '23049RAD8C',
    String brand = 'Xiaomi',
    String hardware = 'qcom',
    String fingerprint =
        'xiaomi/redmi/redmi:14/UKQ1.230917.001/V816.0.4.0.UNCCNXM:user/release-keys',
    String product = 'corot',
    bool isPhysicalDevice = true,
  }) {
    final map = <String, dynamic>{
      'id': 'UKQ1.230917.001',
      'host': 'build-host',
      'tags': 'release-keys',
      'type': 'user',
      'board': 'corot',
      'brand': brand,
      'device': 'corot',
      'fingerprint': fingerprint,
      'hardware': hardware,
      'manufacturer': manufacturer,
      'model': model,
      'product': product,
      'bootloader': 'unknown',
      'display': 'UKQ1.230917.001',
      'isPhysicalDevice': isPhysicalDevice,
      'supportedAbis': <String>['arm64-v8a'],
      'supported32BitAbis': <String>[],
      'supported64BitAbis': <String>['arm64-v8a'],
      'systemFeatures': <String>[],
      'version': <String, dynamic>{
        'baseOS': '',
        'codename': 'REL',
        'incremental': 'V816.0.4.0.UNCCNXM',
        'previewSdkInt': 0,
        'release': '14',
        'sdkInt': 34,
        'securityPatch': '2024-01-01',
      },
    };
    return AndroidDeviceInfo.fromMap(map);
  }
}

class TestWidgetsBinding extends AutomatedTestWidgetsFlutterBinding {
  AppLifecycleState? testLifecycleState = AppLifecycleState.resumed;

  @override
  AppLifecycleState? get lifecycleState => testLifecycleState;
}

void main() {
  final binding = TestWidgetsBinding();

  group('AppTelemetryService', () {
    test('restart waits for a slow native stop', () async {
      final stopped = Completer<void>();
      var active = false;
      var starts = 0;
      final service = AppTelemetryService(
        appVersion: 'test',
        diagnosticPlatformPort: MockDiagnosticPlatformPort(),
        telemetryDeckStartFn: (_) async {
          starts++;
          active = true;
        },
        telemetryDeckStopFn: () async {
          await stopped.future;
          active = false;
        },
        telemetryDeckSendFn: (_, {additionalPayload}) async {},
      );
      addTearDown(service.dispose);
      await service.start();
      service.stop();
      final restarting = service.start();
      await Future<void>.delayed(Duration.zero);
      expect(starts, 1);
      stopped.complete();
      await restarting;
      expect(starts, 2);
      expect(active, isTrue);
    });

    test('re-enabling restarts the stopped backend before sending', () async {
      var active = false;
      var delivered = 0;
      final service = AppTelemetryService(
        appVersion: 'test',
        diagnosticPlatformPort: MockDiagnosticPlatformPort(),
        telemetryDeckStartFn: (_) async => active = true,
        telemetryDeckStopFn: () async => active = false,
        telemetryDeckSendFn: (_, {additionalPayload}) async {
          if (active) delivered++;
        },
      );
      addTearDown(service.dispose);
      await service.start();
      service.stop();
      await service.start();
      expect(delivered, 2);
    });

    test(
      'off then on during initialization preserves the latest request',
      () async {
        final initialized = Completer<void>();
        var active = false;
        var delivered = 0;
        final service = AppTelemetryService(
          appVersion: 'test',
          diagnosticPlatformPort: MockDiagnosticPlatformPort(),
          telemetryDeckStartFn: (_) async {
            await initialized.future;
            active = true;
          },
          telemetryDeckStopFn: () async => active = false,
          telemetryDeckSendFn: (_, {additionalPayload}) async {
            if (active) delivered++;
          },
        );
        addTearDown(service.dispose);
        final first = service.start();
        service.stop();
        final second = service.start();
        initialized.complete();
        await Future.wait([first, second]);
        expect(service.isRunning, isTrue);
        expect(active, isTrue);
        expect(delivered, 1);
      },
    );

    test('late initialization is stopped after cancellation', () async {
      final initialized = Completer<void>();
      var active = false;
      final service = AppTelemetryService(
        appVersion: 'test',
        diagnosticPlatformPort: MockDiagnosticPlatformPort(),
        telemetryDeckStartFn: (_) async {
          await initialized.future;
          active = true;
        },
        telemetryDeckStopFn: () async => active = false,
        telemetryDeckSendFn: (_, {additionalPayload}) async {},
      );
      addTearDown(service.dispose);
      final first = service.start();
      service.stop();
      initialized.complete();
      await first;
      await Future<void>.delayed(Duration.zero);
      expect(active, isFalse);
    });

    test('late initialization is stopped after timeout', () async {
      final initialized = Completer<void>();
      var active = false;
      final service = AppTelemetryService(
        appVersion: 'test',
        diagnosticPlatformPort: MockDiagnosticPlatformPort(),
        initTimeout: const Duration(milliseconds: 5),
        telemetryDeckStartFn: (_) async {
          await initialized.future;
          active = true;
        },
        telemetryDeckStopFn: () async => active = false,
        telemetryDeckSendFn: (_, {additionalPayload}) async {},
      );
      addTearDown(service.dispose);
      await service.start();
      initialized.complete();
      await Future<void>.delayed(Duration.zero);
      expect(service.isRunning, isFalse);
      expect(active, isFalse);
    });

    test('start() initializes TelemetryDeck and sends app_open', () async {
      TelemetryManagerConfiguration? initializedDeckConfig;
      final List<(String, Map<String, dynamic>?)> deckEvents = [];

      final service = AppTelemetryService(
        telemetryDeckAppID: '685D5F38-DD7D-48CB-896D-88642F96F92D',
        appVersion: '1.0.8-beta.1',
        diagnosticPlatformPort: MockDiagnosticPlatformPort(
          webViewVersion: 'Chrome 124.0.6367.82',
        ),
        heartbeatInterval: const Duration(minutes: 15),
        widgetsBinding: binding,
        telemetryDeckStartFn: (config) async {
          initializedDeckConfig = config;
        },
        telemetryDeckSendFn: (signal, {additionalPayload}) async {
          deckEvents.add((signal, additionalPayload));
        },
        telemetryDeckStopFn: () async {},
        localeResolver: () => const Locale('zh', 'CN'),
      );

      expect(service.isRunning, isFalse);
      expect(service.hasHeartbeatTimer, isFalse);

      await service.start();

      expect(service.isRunning, isTrue);
      expect(
        initializedDeckConfig?.appID,
        equals('685D5F38-DD7D-48CB-896D-88642F96F92D'),
      );

      expect(deckEvents.length, equals(1));
      expect(deckEvents.first.$1, equals('app_open'));

      final props = deckEvents.first.$2!;
      expect(
        props.keys,
        unorderedEquals([
          'device',
          'is_emulator',
          'os_version',
          'resolution',
          'webview_version',
          'language',
          'app_version',
        ]),
      );
      expect(initializedDeckConfig?.defaultUser, isNull);
      expect(props['app_version'], equals('1.0.8-beta.1'));
      expect(props['webview_version'], equals('Chrome 124.0.6367.82'));
      expect(props['language'], equals('zh-CN'));
      expect(props['resolution'], equals('2400x1080'));

      expect(service.hasHeartbeatTimer, isTrue);

      service.dispose();
      expect(service.isRunning, isFalse);
      expect(service.isDisposed, isTrue);
      expect(service.hasHeartbeatTimer, isFalse);
    });

    test(
      'stop() calls telemetryDeckStopFn and cancels heartbeat timer',
      () async {
        var deckStopped = false;

        final service = AppTelemetryService(
          telemetryDeckAppID: '685D5F38-DD7D-48CB-896D-88642F96F92D',
          appVersion: '1.0.8',
          diagnosticPlatformPort: MockDiagnosticPlatformPort(),
          widgetsBinding: binding,
          telemetryDeckStartFn: (_) async {},
          telemetryDeckSendFn: (_, {additionalPayload}) async {},
          telemetryDeckStopFn: () async {
            deckStopped = true;
          },
        );

        await service.start();
        expect(service.hasHeartbeatTimer, isTrue);

        service.stop();
        expect(service.hasHeartbeatTimer, isFalse);
        expect(service.isRunning, isFalse);
        expect(deckStopped, isTrue);

        service.dispose();
      },
    );

    test(
      'cancellation race: stop() during start() halts execution and cancels timer',
      () async {
        final completer = Completer<void>();
        final List<String> sentEvents = [];

        late final AppTelemetryService service;
        service = AppTelemetryService(
          telemetryDeckAppID: '685D5F38-DD7D-48CB-896D-88642F96F92D',
          appVersion: '1.0.8',
          diagnosticPlatformPort: MockDiagnosticPlatformPort(),
          widgetsBinding: binding,
          telemetryDeckStartFn: (_) => completer.future,
          telemetryDeckSendFn: (signal, {additionalPayload}) async {
            sentEvents.add(signal);
          },
          telemetryDeckStopFn: () async {},
        );

        // Start asynchronous initiation
        final startFuture = service.start();
        expect(service.isRunning, isTrue);

        // User calls stop() while init is hanging
        service.stop();
        expect(service.isRunning, isFalse);

        // Complete the network call
        completer.complete();
        await startFuture;

        // Verify that no events were sent and no heartbeat timer was scheduled
        expect(sentEvents, isEmpty);
        expect(service.hasHeartbeatTimer, isFalse);
        expect(service.isRunning, isFalse);

        service.dispose();
      },
    );

    test(
      'cancellation race: dispose() during start() halts and marks disposed',
      () async {
        final completer = Completer<void>();
        final List<String> sentEvents = [];

        late final AppTelemetryService service;
        service = AppTelemetryService(
          telemetryDeckAppID: '685D5F38-DD7D-48CB-896D-88642F96F92D',
          appVersion: '1.0.8',
          diagnosticPlatformPort: MockDiagnosticPlatformPort(),
          widgetsBinding: binding,
          telemetryDeckStartFn: (_) => completer.future,
          telemetryDeckSendFn: (signal, {additionalPayload}) async {
            sentEvents.add(signal);
          },
          telemetryDeckStopFn: () async {},
        );

        final startFuture = service.start();
        service.dispose();
        expect(service.isDisposed, isTrue);

        completer.complete();
        await startFuture;

        expect(sentEvents, isEmpty);
        expect(service.hasHeartbeatTimer, isFalse);
      },
    );

    test(
      'background startup does not activate heartbeat timer until resumed',
      () async {
        binding.testLifecycleState = AppLifecycleState.paused;

        final service = AppTelemetryService(
          telemetryDeckAppID: '685D5F38-DD7D-48CB-896D-88642F96F92D',
          appVersion: '1.0.8',
          diagnosticPlatformPort: MockDiagnosticPlatformPort(),
          widgetsBinding: binding,
          telemetryDeckStartFn: (_) async {},
          telemetryDeckSendFn: (_, {additionalPayload}) async {},
          telemetryDeckStopFn: () async {},
        );

        await service.start();
        // App is paused, so timer must NOT be running
        expect(service.hasHeartbeatTimer, isFalse);

        // When app resumes, timer must activate
        service.onLifecycleChanged(AppLifecycleState.resumed);
        expect(service.hasHeartbeatTimer, isTrue);

        binding.testLifecycleState = AppLifecycleState.resumed;
        service.dispose();
      },
    );

    test(
      'heartbeat compensation on resumed after interval lapse dispatches heartbeat',
      () async {
        var currentTime = DateTime(2026, 9, 17, 10, 0);
        final List<String> deckSignals = [];

        final service = AppTelemetryService(
          telemetryDeckAppID: '685D5F38-DD7D-48CB-896D-88642F96F92D',
          appVersion: '1.0.8',
          diagnosticPlatformPort: MockDiagnosticPlatformPort(),
          heartbeatInterval: const Duration(minutes: 15),
          widgetsBinding: binding,
          now: () => currentTime,
          telemetryDeckStartFn: (_) async {},
          telemetryDeckSendFn: (signal, {additionalPayload}) async {
            deckSignals.add(signal);
          },
          telemetryDeckStopFn: () async {},
        );

        await service.start();
        expect(deckSignals, equals(['app_open']));

        // Put app in background
        service.onLifecycleChanged(AppLifecycleState.paused);
        expect(service.hasHeartbeatTimer, isFalse);

        // Advance time by 20 minutes (exceeds 15 min interval)
        currentTime = currentTime.add(const Duration(minutes: 20));

        // Resume app -> should immediately send a compensated heartbeat
        service.onLifecycleChanged(AppLifecycleState.resumed);
        expect(deckSignals, equals(['app_open', 'heartbeat']));
        expect(service.hasHeartbeatTimer, isTrue);

        service.dispose();
      },
    );

    test(
      'fail-silent: errors during init reset running state to allow recovery',
      () async {
        var shouldFail = true;

        final service = AppTelemetryService(
          telemetryDeckAppID: 'INVALID',
          appVersion: '1.0.8',
          diagnosticPlatformPort: MockDiagnosticPlatformPort(),
          widgetsBinding: binding,
          telemetryDeckStartFn: (_) async {
            if (shouldFail) {
              throw Exception('Network timeout during init');
            }
          },
          telemetryDeckSendFn: (_, {additionalPayload}) async {},
          telemetryDeckStopFn: () async {},
        );

        // First run fails silently
        await expectLater(service.start(), completes);
        expect(service.isRunning, isFalse); // Running is cleanly reset to false
        expect(service.hasHeartbeatTimer, isFalse);

        // Second run succeeds
        shouldFail = false;
        await expectLater(service.start(), completes);
        expect(service.isRunning, isTrue);
        expect(service.hasHeartbeatTimer, isTrue);

        service.dispose();
      },
    );
  });

  group('TelemetryController', () {
    test(
      'persisted opt-out does not initialize telemetry after restart',
      () async {
        SharedPreferences.setMockInitialValues({});
        const store = SharedPreferencesTelemetrySettingsStore();
        await store.saveEnabled(false);
        var starts = 0;
        final controller = await TelemetryController.create(
          store: const SharedPreferencesTelemetrySettingsStore(),
          service: _TestTelemetryService(onStart: () => starts++),
        );
        addTearDown(controller.dispose);
        await controller.startIfEnabled();
        expect(controller.enabled, isFalse);
        expect(starts, 0);
      },
    );

    test(
      'disabling stops reporting before the preference write completes',
      () async {
        final store = _DelayedTelemetryStore();
        var stopped = false;
        final controller = TelemetryController(
          store: store,
          service: _TestTelemetryService(onStop: () => stopped = true),
        );
        addTearDown(controller.dispose);
        final saving = controller.setEnabled(false);
        final stoppedBeforeSave = stopped;
        store.release.complete();
        await saving;
        expect(stoppedBeforeSave, isTrue);
      },
    );

    test('rapid writes preserve the last preference across restart', () async {
      final store = _DelayedTelemetryStore();
      final controller = TelemetryController(
        store: store,
        service: _TestTelemetryService(),
      );
      addTearDown(controller.dispose);
      final first = controller.setEnabled(false);
      final second = controller.setEnabled(true);
      await Future<void>.delayed(Duration.zero);
      store.release.complete();
      await Future.wait([first, second]);
      expect(await store.loadEnabled(), isTrue);
    });

    test('toggling enabled updates store and starts/stops service', () async {
      final store = MemoryTelemetrySettingsStore(true);
      var started = false;
      var stopped = false;

      final service = _TestTelemetryService(
        onStart: () => started = true,
        onStop: () => stopped = true,
      );

      final controller = await TelemetryController.create(
        store: store,
        service: service,
      );

      expect(controller.enabled, isTrue);

      await controller.setEnabled(false);
      expect(controller.enabled, isFalse);
      expect(await store.loadEnabled(), isFalse);
      expect(stopped, isTrue);

      await controller.setEnabled(true);
      expect(controller.enabled, isTrue);
      expect(await store.loadEnabled(), isTrue);
      expect(started, isTrue);

      controller.dispose();
    });

    test('rapid toggles are guarded by operation versioning', () async {
      final store = MemoryTelemetrySettingsStore(true);
      var startCount = 0;
      var stopCount = 0;

      final service = _TestTelemetryService(
        onStart: () => startCount++,
        onStop: () => stopCount++,
      );

      final controller = await TelemetryController.create(
        store: store,
        service: service,
      );

      // Rapid flip: false then immediately true
      final f1 = controller.setEnabled(false);
      final f2 = controller.setEnabled(true);
      await Future.wait([f1, f2]);

      expect(controller.enabled, isTrue);
      expect(startCount, equals(1));

      controller.dispose();
    });
  });
}

class _DelayedTelemetryStore implements TelemetrySettingsStore {
  final release = Completer<void>();
  bool value = true;

  @override
  Future<bool> loadEnabled() async => value;

  @override
  Future<void> saveEnabled(bool enabled) async {
    if (!enabled) await release.future;
    value = enabled;
  }
}

class _TestTelemetryService implements TelemetryService {
  _TestTelemetryService({this.onStart, this.onStop});

  final VoidCallback? onStart;
  final VoidCallback? onStop;

  @override
  void dispose() {}

  @override
  void onLifecycleChanged(AppLifecycleState state) {}

  @override
  Future<void> start() async {
    onStart?.call();
  }

  @override
  void stop() {
    onStop?.call();
  }
}
