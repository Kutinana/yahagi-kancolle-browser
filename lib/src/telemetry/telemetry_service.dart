import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:telemetrydecksdk/telemetrydecksdk.dart';

import '../diagnostics/diagnostic_platform_port.dart';

/// Contract for application telemetry and usage reporting.
abstract interface class TelemetryService {
  Future<void> start();
  void stop();
  void onLifecycleChanged(AppLifecycleState state);
  void dispose();
}

typedef TelemetryDeckStartFn =
    Future<void> Function(TelemetryManagerConfiguration configuration);

typedef TelemetryDeckSendFn =
    Future<void> Function(
      String signalType, {
      Map<String, dynamic>? additionalPayload,
    });

typedef TelemetryDeckStopFn = Future<void> Function();

/// Production implementation of [TelemetryService] powered by TelemetryDeck
/// with complete fail-silent guarantees.
final class AppTelemetryService
    with WidgetsBindingObserver
    implements TelemetryService {
  AppTelemetryService({
    this.telemetryDeckAppID = '685D5F38-DD7D-48CB-896D-88642F96F92D',
    required this.appVersion,
    required this.diagnosticPlatformPort,
    this.heartbeatInterval = const Duration(minutes: 15),
    this.initTimeout = const Duration(seconds: 4),
    this.eventTimeout = const Duration(seconds: 4),
    TelemetryDeckStartFn? telemetryDeckStartFn,
    TelemetryDeckSendFn? telemetryDeckSendFn,
    TelemetryDeckStopFn? telemetryDeckStopFn,
    DeviceInfoPlugin? deviceInfoPlugin,
    WidgetsBinding? widgetsBinding,
    Locale Function()? localeResolver,
    DateTime Function()? now,
    this.isAndroidOverride,
    this.isIOSOverride,
  }) : _telemetryDeckStartFn = telemetryDeckStartFn ?? Telemetrydecksdk.start,
       _telemetryDeckSendFn =
           telemetryDeckSendFn ??
           ((signal, {additionalPayload}) => Telemetrydecksdk.send(
             signal,
             additionalPayload: additionalPayload,
           )),
       _telemetryDeckStopFn = telemetryDeckStopFn ?? Telemetrydecksdk.stop,
       _deviceInfoPlugin = deviceInfoPlugin ?? DeviceInfoPlugin(),
       _widgetsBinding = widgetsBinding ?? WidgetsBinding.instance,
       _localeResolver =
           localeResolver ?? (() => PlatformDispatcher.instance.locale),
       _now = now ?? DateTime.now;

  final String? telemetryDeckAppID;
  final String appVersion;
  final DiagnosticPlatformPort diagnosticPlatformPort;
  final Duration heartbeatInterval;
  final Duration initTimeout;
  final Duration eventTimeout;
  final bool? isAndroidOverride;
  final bool? isIOSOverride;

  final TelemetryDeckStartFn _telemetryDeckStartFn;
  final TelemetryDeckSendFn _telemetryDeckSendFn;
  final TelemetryDeckStopFn _telemetryDeckStopFn;
  final DeviceInfoPlugin _deviceInfoPlugin;
  final WidgetsBinding _widgetsBinding;
  final Locale Function() _localeResolver;
  final DateTime Function() _now;

  bool _telemetryDeckInitialized = false;
  bool _running = false;
  bool _starting = false;
  bool _disposed = false;
  bool _observerRegistered = false;
  int _operationVersion = 0;
  Future<void>? _backendOperation;
  Timer? _heartbeatTimer;
  DateTime? _lastHeartbeatTime;
  Map<String, dynamic>? _cachedProperties;

  bool get isRunning => _running && !_disposed;
  bool get isDisposed => _disposed;
  bool get hasHeartbeatTimer =>
      _heartbeatTimer != null && _heartbeatTimer!.isActive;
  DateTime? get lastHeartbeatTime => _lastHeartbeatTime;

  bool get _isConfigured => telemetryDeckAppID?.isNotEmpty ?? false;

  bool get _isAndroid => isAndroidOverride ?? Platform.isAndroid;
  bool get _isIOS => isIOSOverride ?? Platform.isIOS;

  @override
  Future<void> start() async {
    if (_disposed || _running) return;
    final version = ++_operationVersion;
    _starting = true;
    _running = true;

    if (!_observerRegistered) {
      _widgetsBinding.addObserver(this);
      _observerRegistered = true;
    }

    try {
      if (!_telemetryDeckInitialized) {
        await _initializeBackend(version).timeout(initTimeout);
        if (!_isCurrent(version)) return;
      }

      final props = await _collectDeviceProperties().timeout(eventTimeout);
      if (!_isCurrent(version)) return;
      _cachedProperties = props;

      await _sendEvent('app_open', props);
      if (!_isCurrent(version)) return;

      _lastHeartbeatTime = _now();

      // Guard against background startup: only activate timer if in foreground
      final currentLifecycle = _widgetsBinding.lifecycleState;
      if (currentLifecycle == null ||
          currentLifecycle == AppLifecycleState.resumed) {
        _startHeartbeatTimer();
      }
    } catch (_) {
      // Timeout does not cancel the native Future. Queue cleanup after it,
      // so a late completion cannot leave the backend active.
      if (_isCurrent(version)) stop();
    } finally {
      if (version == _operationVersion) _starting = false;
    }
  }

  bool _isCurrent(int version) =>
      version == _operationVersion && _running && !_disposed;

  Future<void> _queueBackend(Future<void> Function() operation) {
    final previous = _backendOperation;
    Future<void> run() async {
      if (previous != null) await previous;
      await operation();
    }

    final result = run();
    // Keep the queue usable after errors while propagating them to the caller.
    final tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _backendOperation = tail;
    unawaited(
      tail.then((_) {
        if (identical(_backendOperation, tail)) _backendOperation = null;
      }),
    );
    return result;
  }

  Future<void> _initializeBackend(int version) async {
    if (telemetryDeckAppID case final appId? when appId.isNotEmpty) {
      await _queueBackend(() async {
        if (_isCurrent(version)) {
          await _telemetryDeckStartFn(
            TelemetryManagerConfiguration(appID: appId),
          );
          if (_isCurrent(version)) _telemetryDeckInitialized = true;
        }
      });
    }

    if (_isCurrent(version) && _isConfigured && !_telemetryDeckInitialized) {
      throw StateError('TelemetryDeck failed to initialize');
    }
  }

  @override
  void stop() {
    ++_operationVersion;
    _running = false;
    _starting = false;
    _telemetryDeckInitialized = false;
    _cachedProperties = null;
    _lastHeartbeatTime = null;
    _stopHeartbeatTimer();
    try {
      unawaited(_queueBackend(_telemetryDeckStopFn).catchError((_) {}));
    } catch (_) {}
  }

  @override
  void onLifecycleChanged(AppLifecycleState state) {
    if (!_running || _disposed || _starting) return;

    switch (state) {
      case AppLifecycleState.resumed:
        final now = _now();
        if (_lastHeartbeatTime != null &&
            now.difference(_lastHeartbeatTime!) >= heartbeatInterval) {
          _sendHeartbeat();
        }
        _startHeartbeatTimer();
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _stopHeartbeatTimer();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    onLifecycleChanged(state);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    stop();
    if (_observerRegistered) {
      _widgetsBinding.removeObserver(this);
      _observerRegistered = false;
    }
  }

  void _startHeartbeatTimer() {
    _stopHeartbeatTimer();
    if (!_running || _disposed) return;

    _heartbeatTimer = Timer.periodic(heartbeatInterval, (_) {
      _sendHeartbeat();
    });
  }

  void _stopHeartbeatTimer() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void _sendHeartbeat() {
    if (!_running || _disposed) {
      _stopHeartbeatTimer();
      return;
    }
    _lastHeartbeatTime = _now();
    unawaited(_sendEvent('heartbeat', _cachedProperties).catchError((_) {}));
  }

  Future<void> _sendEvent(String eventName, Map<String, dynamic>? props) async {
    if (!_telemetryDeckInitialized || !_running || _disposed) return;
    try {
      await _telemetryDeckSendFn(
        eventName,
        additionalPayload: props,
      ).timeout(eventTimeout);
    } catch (_) {}
  }

  Future<Map<String, dynamic>> _collectDeviceProperties() async {
    String device = 'Unknown';
    bool isEmulator = false;
    String osVersion = Platform.operatingSystem;

    if (_isAndroid) {
      try {
        final androidInfo = await _deviceInfoPlugin.androidInfo;
        final manufacturer = androidInfo.manufacturer.trim();
        final model = androidInfo.model.trim();
        device = manufacturer.isEmpty ? model : '$manufacturer $model';
        isEmulator = _detectAndroidEmulator(androidInfo);
        osVersion =
            'Android ${androidInfo.version.release} (API ${androidInfo.version.sdkInt})';
      } catch (_) {
        // Fallback to basic platform values
      }
    } else if (_isIOS) {
      try {
        final iosInfo = await _deviceInfoPlugin.iosInfo;
        device = iosInfo.utsname.machine;
        isEmulator = !iosInfo.isPhysicalDevice;
        osVersion = '${iosInfo.systemName} ${iosInfo.systemVersion}';
      } catch (_) {
        // Fallback
      }
    }

    String webViewVersion = 'unknown';
    String resolution = 'unknown';
    try {
      final snapshot = await diagnosticPlatformPort.deviceSnapshot();
      final wv = snapshot.webViewVersion.trim();
      if (wv.isNotEmpty) {
        webViewVersion = wv;
      }
      final width = snapshot.screenWidthPx;
      final height = snapshot.screenHeightPx;
      if (width > 0 && height > 0) {
        final maxSide = width >= height ? width : height;
        final minSide = width >= height ? height : width;
        resolution = '${maxSide}x$minSide';
      }
    } catch (_) {
      // Platform channel might not be supported or error out
    }

    if (resolution == 'unknown') {
      try {
        final view = _widgetsBinding.platformDispatcher.views.firstOrNull;
        if (view != null &&
            view.physicalSize.width > 0 &&
            view.physicalSize.height > 0) {
          final w = view.physicalSize.width.round();
          final h = view.physicalSize.height.round();
          final maxSide = w >= h ? w : h;
          final minSide = w >= h ? h : w;
          resolution = '${maxSide}x$minSide';
        }
      } catch (_) {}
    }

    String language = 'unknown';
    try {
      final locale = _localeResolver();
      language = locale.toLanguageTag();
    } catch (_) {
      // Fallback
    }

    return <String, dynamic>{
      'device': device,
      'is_emulator': isEmulator,
      'os_version': osVersion,
      'resolution': resolution,
      'webview_version': webViewVersion,
      'language': language,
      'app_version': appVersion,
    };
  }

  bool _detectAndroidEmulator(AndroidDeviceInfo info) {
    if (!info.isPhysicalDevice) return true;

    final brand = info.brand.toLowerCase();
    final model = info.model.toLowerCase();
    final hardware = info.hardware.toLowerCase();
    final fingerprint = info.fingerprint.toLowerCase();
    final manufacturer = info.manufacturer.toLowerCase();
    final product = info.product.toLowerCase();

    if (brand.contains('generic') ||
        model.contains('google_sdk') ||
        model.contains('emulator') ||
        model.contains('android sdk built for') ||
        model.contains('mumu') ||
        model.contains('nox') ||
        model.contains('ldmnq') ||
        model.contains('bluestacks') ||
        hardware.contains('goldfish') ||
        hardware.contains('ranchu') ||
        hardware.contains('microvirt') ||
        fingerprint.contains('generic') ||
        fingerprint.contains('vbox') ||
        product.contains('vbox86') ||
        manufacturer.contains('genymotion') ||
        manufacturer.contains('netease') ||
        manufacturer.contains('microvirt')) {
      return true;
    }

    return false;
  }
}

/// Optional alias for [AppTelemetryService].
typedef TelemetryDeckService = AppTelemetryService;
