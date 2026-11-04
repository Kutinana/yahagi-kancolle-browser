/// iOS-specific [GameWebView] implementation.
///
/// This is a standalone widget that provides the same functionality as the
/// upstream [GameWebView] but adds iOS-specific enhancements:
/// - AppLifecycleListener for background audio control
/// - WebAudio AudioContext tracking & MediaSession clearing
/// - Generic WebView compatibility port (non-Android)
/// - Early capture preparation on page start
///
/// This file is intentionally independent from `game_webview.dart` to avoid
/// modifying upstream code. It re-uses shared utilities (alignment script,
/// capture script, compatibility, browser port) but owns its own State.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import 'audio/game_audio_controller.dart';
import 'audio/game_audio_port.dart';
import 'bridge/native_game_capture_script.dart';
import 'browser/game_browser_controller.dart';
import 'browser/game_frame_rate_port.dart';
import 'browser/game_frame_rate_runtime_controller.dart';
import 'browser/game_frame_reload_port.dart';
import 'browser/game_navigation_watchdog.dart';

import 'browser/game_page_alignment_script.dart';
import 'browser/game_presentation_state.dart';
import 'browser/game_toolbar_controller.dart';
import 'browser/game_webview_compatibility.dart';
import 'browser/safe_page_address.dart';
import 'capture/capture_mode.dart';
import 'capture/capture_mode_controller.dart';
import 'capture/android_game_capture_port.dart';
import 'capture/game_capture_controller.dart';
import 'capture/game_capture_port.dart';
import 'diagnostics/diagnostic_event.dart';
import 'diagnostics/diagnostic_recorder.dart';
import 'game_webview.dart' show GameStartupState, WebViewGameBrowserPort;
import 'prototype_status_controller.dart';
import 'settings/network_settings_controller.dart';
import 'settings/network_settings_store.dart';
import 'settings/network_settings_validator.dart';

import 'settings/safety_settings_controller.dart';
import 'settings/game_frame_rate_settings.dart';

class IOSGameWebView extends StatefulWidget {
  const IOSGameWebView({
    super.key,
    required this.networkSettingsController,
    required this.safetySettingsController,
    required this.controller,
    required this.browserController,
    required this.captureModeController,
    required this.audioController,
    required this.toolbarController,
    required this.gameCaptureController,
    this.frameRateSettingsController,
    this.diagnosticRecorder,
  });

  final NetworkSettingsController networkSettingsController;
  final SafetySettingsController safetySettingsController;
  final PrototypeStatusController controller;
  final GameBrowserController browserController;
  final CaptureModeController captureModeController;
  final GameAudioController audioController;
  final GameToolbarController toolbarController;
  final GameCaptureController gameCaptureController;
  final GameFrameRateSettingsController? frameRateSettingsController;
  final DiagnosticRecorder? diagnosticRecorder;

  @override
  State<IOSGameWebView> createState() => _IOSGameWebViewState();
}

class _IOSGameWebViewState extends State<IOSGameWebView>
    with WidgetsBindingObserver {
  late final WebViewController _webViewController;
  late final Future<void> _compatibilityReady;
  late final Future<void> _webViewReady;
  late final GameCapturePort _gameCapturePort;
  late final WebViewGameBrowserPort _browserPort;
  late final GameNavigationWatchdog _navigationWatchdog;
  GameFrameRateRuntimeController? _frameRateRuntimeController;
  int _frameRateBindingGeneration = 0;
  Timer? _readinessTimer;
  int? _readinessProbeEpoch;
  int _navigationEpoch = 0;
  int _startupEpoch = 0;
  int _loadingEpoch = 0;
  int? _failedNavigationEpoch;
  bool _loadingFlowActive = false;
  bool _awaitingNavigationStart = false;

  late CaptureMode _activeCaptureMode;
  static const _scaleChannel = MethodChannel(
    'app.webview/fixed_canvas_scaling',
  );
  static const _audioChannel = MethodChannel(
    'app.yahagi.kancollebrowser/game_audio',
  );
  static const _runtimeChannel = MethodChannel(
    'app.yahagi.kancollebrowser/webview_runtime',
  );

  bool _runtimeInstalled = false;
  bool _audioPortAttached = false;
  bool _capturePortAttached = false;
  bool? _lastNativeBackgroundPlaybackEnabled;
  int _presentationSyncEpoch = 0;

  GameStartupState _startupState = GameStartupState.loadingSettings;
  String _startupErrorMessage = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _navigationWatchdog = GameNavigationWatchdog(
      timeout: const Duration(seconds: 15),
      onTimeout: (epoch) {
        if (mounted && _loadingFlowActive && epoch == _loadingEpoch) {
          _failNavigation('加载超过 15 秒，请检查网络后重新加载。', timedOut: true);
        }
      },
    );
    _navigationWatchdog.setForeground(_isForeground);
    _activeCaptureMode = widget.captureModeController.mode;
    _gameCapturePort = MethodChannelGameCapturePort();
    widget.captureModeController.addListener(_onCaptureModeChanged);
    widget.audioController.addListener(_onAudioControllerChanged);
    _webViewController = WebViewController();
    _compatibilityReady = _configureCompatibility();
    _runtimeChannel.setMethodCallHandler(_onRuntimeEvent);
    _webViewReady = _configureWebView();
    _browserPort = WebViewGameBrowserPort(
      _webViewController,
      _prototypePage,
      gameFrameReloadPort: MethodChannelGameFrameReloadPort(),
      compatibilityReady: Future.wait<void>([
        _compatibilityReady,
        _webViewReady,
      ]),
      isActive: () => mounted,
      prepareForRealNavigation: _prepareForRealNavigation,
      beforeNavigation: _beforeUserNavigation,
      synchronizeGamePresentation: () async {
        await _synchronizeGamePresentation();
      },
    );
    widget.browserController.attachPort(_browserPort);

    _executeStartupSequence();
  }

  Future<void> _configureWebView() async {
    await _webViewController.setJavaScriptMode(JavaScriptMode.unrestricted);
    await _webViewController.setBackgroundColor(const Color(0xff000000));
    await _webViewController.addJavaScriptChannel(
      'YahagiBridge',
      onMessageReceived: (message) {
        if (mounted &&
            widget.browserController.mode == GameBrowserMode.localPrototype) {
          widget.controller.onJavaScriptMessage(message.message);
        }
      },
    );
    await _webViewController.addJavaScriptChannel(
      'YahagiPresentation',
      onMessageReceived: (message) {
        final state = decodeGamePresentationState(message.message);
        if (!mounted ||
            state == null ||
            state == GamePresentationState.pending) {
          return;
        }
        if (_loadingFlowActive) {
          unawaited(_probePageReadiness(_navigationEpoch));
        } else {
          unawaited(_synchronizeGamePresentation(readOnly: true));
        }
      },
    );
    await _webViewController.setNavigationDelegate(
      NavigationDelegate(
        onNavigationRequest: _onNavigationRequest,
        onPageStarted: _onPageStarted,
        onPageFinished: (url) => unawaited(_onPageFinished(url)),
        onWebResourceError: (error) {
          if (!mounted) return;
          final isForMainFrame = error.isForMainFrame ?? true;
          // WebKit cancels the previous request during redirects and reloads.
          if (!isForMainFrame || error.errorCode == -999) return;
          unawaited(
            _onDocumentError(
              error.url,
              '页面加载失败 [${error.errorCode}]，请检查网络后重新加载。',
              error.errorCode,
            ),
          );
        },
      ),
    );
  }

  bool get _isForeground =>
      WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  bool _isCurrentNavigation(int epoch) =>
      mounted &&
      epoch > 0 &&
      epoch == _navigationEpoch &&
      _failedNavigationEpoch != epoch;

  void _startLoadingFlow({bool restartDeadline = false}) {
    if (!_loadingFlowActive || restartDeadline) {
      _loadingFlowActive = true;
      _navigationWatchdog.start(++_loadingEpoch);
    }
  }

  void _beforeUserNavigation(Uri? _) {
    if (!mounted) return;
    _startupEpoch++;
    _navigationEpoch++;
    _presentationSyncEpoch++;
    _failedNavigationEpoch = null;
    _awaitingNavigationStart = true;
    _readinessTimer?.cancel();
    _startLoadingFlow(restartDeadline: true);
    setState(() {
      _startupState = GameStartupState.loadingGame;
      _startupErrorMessage = '';
    });
  }

  void _onPageStarted(String url) {
    if (!mounted ||
        (_startupState == GameStartupState.error &&
            !_awaitingNavigationStart)) {
      return;
    }
    // Update state synchronously. Plugin page callbacks do not await each other.
    _navigationEpoch++;
    _presentationSyncEpoch++;
    _failedNavigationEpoch = null;
    _awaitingNavigationStart = false;
    _readinessTimer?.cancel();
    // Redirects share the current deadline, so a redirect loop cannot reset it.
    _startLoadingFlow();
    setState(() => _startupState = GameStartupState.loadingGame);
    _frameRateRuntimeController?.onPageStarted();
    widget.controller.onPageStarted(url);
    widget.browserController.onPageStarted(url);
    widget.toolbarController.onStageChanged(
      widget.browserController.mode == GameBrowserMode.localPrototype
          ? GameSurfaceStage.localPrototype
          : GameSurfaceStage.login,
    );
    _scheduleReadinessProbe(_navigationEpoch, Duration.zero);
  }

  Future<void> _onPageFinished(String url) async {
    final epoch = _navigationEpoch;
    if (!_isCurrentNavigation(epoch) || _awaitingNavigationStart) return;
    try {
      final current = await _webViewController.currentUrl().timeout(
        const Duration(seconds: 3),
      );
      if (!_isCurrentNavigation(epoch) || (current != null && current != url)) {
        return;
      }
      widget.controller.onPageFinished(url);
      widget.browserController.onPageFinished(url);
      unawaited(_probePageReadiness(epoch));
      unawaited(_prepareOptionalPageFeatures(epoch));
    } catch (_) {
      // Readiness probing and its foreground deadline remain active.
    }
  }

  void _scheduleReadinessProbe(
    int epoch, [
    Duration delay = const Duration(milliseconds: 500),
  ]) {
    if (!_isCurrentNavigation(epoch) || !_loadingFlowActive || !_isForeground) {
      return;
    }
    _readinessTimer?.cancel();
    _readinessTimer = Timer(delay, () => unawaited(_probePageReadiness(epoch)));
  }

  Future<void> _probePageReadiness(int epoch) async {
    if (!_isCurrentNavigation(epoch) ||
        !_loadingFlowActive ||
        _awaitingNavigationStart ||
        !_isForeground ||
        _readinessProbeEpoch == epoch) {
      return;
    }
    _readinessProbeEpoch = epoch;
    try {
      final state = await _synchronizeGamePresentation();
      if (!_isCurrentNavigation(epoch) ||
          state == null ||
          state == GamePresentationState.pending) {
        return;
      }
      final current = await _webViewController.currentUrl().timeout(
        const Duration(seconds: 3),
      );
      if (current == null || !_isCurrentNavigation(epoch)) return;
      final ready = await _webViewController
          .runJavaScriptReturningResult('''
        (() => {
          if (location.href !== ${jsonEncode(current)} ||
              document.readyState === 'loading' || !document.body) return false;
          const body = document.body;
          const visible = element => {
            const rect = element.getBoundingClientRect();
            const style = getComputedStyle(element);
            return rect.width > 0 && rect.height > 0 &&
              style.display !== 'none' && style.visibility !== 'hidden';
          };
          const bodyStyle = getComputedStyle(body);
          if (bodyStyle.display === 'none' || bodyStyle.visibility === 'hidden') return false;
          if (window.__yahagiMobileReadPresentation?.() === 'game') return true;
          return body.innerText.trim().length > 0 ||
            Array.from(body.querySelectorAll('input:not([type="hidden"]),button,a,iframe,dialog'))
              .some(visible);
        })();
      ''')
          .timeout(const Duration(seconds: 3));
      if (!_isCurrentNavigation(epoch) ||
          !_loadingFlowActive ||
          ready != true) {
        return;
      }
      _loadingFlowActive = false;
      _navigationWatchdog.cancel();
      _readinessTimer?.cancel();
      setState(() => _startupState = GameStartupState.ready);
      _recordPageState('pageUsable');
    } catch (_) {
      // A redirect can replace the JS context. Retry only the current document.
    } finally {
      if (_readinessProbeEpoch == epoch) _readinessProbeEpoch = null;
      _scheduleReadinessProbe(epoch);
    }
  }

  Future<void> _prepareOptionalPageFeatures(int epoch) async {
    for (final operation in <Future<void> Function()>[
      _injectAudioContextTracker,
      _attachAudioPortOnce,
      () async {
        await _configureFrameRate();
        await _frameRateRuntimeController?.onPageReady();
      },
    ]) {
      if (!_isCurrentNavigation(epoch)) return;
      try {
        await operation().timeout(const Duration(seconds: 3));
      } catch (_) {
        if (_isCurrentNavigation(epoch)) {
          _recordPageState('optionalPageFeatureFailed');
        }
      }
    }
  }

  Future<void> _onDocumentError(String? url, String message, int code) async {
    final epoch = _navigationEpoch;
    if (!_isCurrentNavigation(epoch)) return;
    if (url != null && url.isNotEmpty) {
      try {
        final current = await _webViewController.currentUrl().timeout(
          const Duration(seconds: 3),
        );
        if (current != null && current != url) return;
      } catch (_) {}
    }
    if (_isCurrentNavigation(epoch)) _failNavigation(message, errorCode: code);
  }

  void _failNavigation(
    String message, {
    int? errorCode,
    bool timedOut = false,
  }) {
    if (!mounted) return;
    _startupEpoch++;
    _presentationSyncEpoch++;
    _failedNavigationEpoch = _navigationEpoch;
    _awaitingNavigationStart = false;
    _loadingFlowActive = false;
    _navigationWatchdog.cancel();
    _readinessTimer?.cancel();
    widget.controller.onWebResourceError(message);
    widget.browserController.onWebResourceError(
      description: message,
      isForMainFrame: true,
    );
    setState(() {
      _startupState = GameStartupState.error;
      _startupErrorMessage = message;
    });
    _recordPageState(
      timedOut ? 'pageLoadTimedOut' : 'pageLoadFailed',
      errorCode: errorCode,
    );
    unawaited(
      const MethodChannel('app.yahagi.kancollebrowser/game_capture')
          .invokeMethod<void>('notifyCaptureInterrupted')
          .catchError((Object _) {}),
    );
    unawaited(
      _runtimeChannel
          .invokeMethod<void>('stopLoading')
          .catchError((Object _) {}),
    );
  }

  void _recordPageState(String state, {int? errorCode}) {
    final recorder = widget.diagnosticRecorder;
    recorder?.record(
      DiagnosticEvent.webViewState(
        occurredAt: DateTime.now(),
        state: state,
        durationMs: 0,
        errorCode: errorCode,
      ),
    );
    if (recorder != null) unawaited(recorder.flush());
  }

  Future<void> _onRuntimeEvent(MethodCall call) async {
    if (!mounted) return;
    final arguments = call.arguments;
    if (arguments is! Map) return;
    if (call.method == 'onMainFrameHttpError') {
      final code = arguments['statusCode'];
      final url = arguments['url'];
      if (code is int && code >= 400 && code <= 599 && url is String) {
        await _onDocumentError(url, '页面加载失败 [HTTP $code]，请重新加载或检查网络。', code);
      }
      return;
    }
    if (call.method != 'onRuntimeEvent') return;
    final state = arguments['state'];
    if (state is! String ||
        !const <String>{
          'pixiIOSCompatibilityV1',
          'pixiCompatibilityHookUnavailable',
          'webglContextLost',
          'webglContextRestored',
          'webglContextCreationFailed',
          'webContentProcessTerminated',
        }.contains(state)) {
      return;
    }
    final recorder = widget.diagnosticRecorder;
    recorder?.record(
      DiagnosticEvent.webViewState(
        occurredAt: DateTime.now(),
        state: state,
        durationMs: 0,
      ),
    );
    await recorder?.flush();
  }

  Future<void> _prepareForRealNavigation() async {
    await _webViewReady;
    if (!mounted) return;
    if (!_runtimeInstalled) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      await _runtimeChannel.invokeMethod<void>('prepare');
      if (!mounted) return;
      _runtimeInstalled = true;
    }
    await _prepareCapture();
    if (mounted &&
        widget.captureModeController.mode.installsGameBridge &&
        !const {
          GameCaptureState.ready,
          GameCaptureState.capturing,
        }.contains(widget.gameCaptureController.state)) {
      throw StateError('Game capture preparation failed');
    }
    // The native runtime preparation has acknowledged a mounted WKWebView.
    // Install the document-start FPS hook now, rather than probing on the first
    // Flutter frame when native channels or the platform view may still lag.
    try {
      await _configureFrameRate().timeout(const Duration(seconds: 3));
    } catch (_) {
      _recordPageState('frameRatePreparationFailed');
    }
  }

  /// iOS-specific: inject WebAudio AudioContext tracking and MediaSession clearing.
  Future<void> _injectAudioContextTracker() async {
    if (!mounted) return;
    await _webViewController.runJavaScript('''
      (function() {
        if (window.__yahagiAudioTrackerInjected) return;
        window.__yahagiAudioTrackerInjected = true;
        window.__yahagiAudioContexts = window.__yahagiAudioContexts || [];
        var OrigAC = window.AudioContext || window.webkitAudioContext;
        if (OrigAC) {
          var WrappedAC = function(a, b, c) {
            var instance;
            if (arguments.length === 0) {
              instance = new OrigAC();
            } else if (arguments.length === 1) {
              instance = new OrigAC(a);
            } else if (arguments.length === 2) {
              instance = new OrigAC(a, b);
            } else {
              instance = new OrigAC(a, b, c);
            }
            window.__yahagiAudioContexts.push(instance);
            return instance;
          };
          WrappedAC.prototype = OrigAC.prototype;
          if (window.AudioContext) window.AudioContext = WrappedAC;
          if (window.webkitAudioContext) window.webkitAudioContext = WrappedAC;
        }
        try {
          if (navigator.mediaSession) {
            navigator.mediaSession.metadata = null;
            ['play', 'pause', 'stop', 'previoustrack', 'nexttrack', 'seekto', 'seekbackward', 'seekforward'].forEach(function(act) {
              try { navigator.mediaSession.setActionHandler(act, null); } catch(e){}
            });
          }
        } catch(e){}
      })();
    ''');
  }

  Future<GamePresentationState?> _synchronizeGamePresentation({
    bool readOnly = false,
  }) async {
    if (!mounted) return null;
    final epoch = ++_presentationSyncEpoch;
    final navigation = _navigationEpoch;
    try {
      final gameSurfaceResult = await _webViewController
          .runJavaScriptReturningResult(
            readOnly
                ? "window.__yahagiMobileReadPresentation?.() || 'pending'"
                : gamePageAlignmentScript,
          )
          .timeout(const Duration(seconds: 3));
      if (epoch != _presentationSyncEpoch ||
          !_isCurrentNavigation(navigation)) {
        return null;
      }
      final state = decodeGamePresentationState(gameSurfaceResult);
      await _applyGamePresentation(
        state,
        epoch,
      ).timeout(const Duration(seconds: 3));
      return state;
    } catch (_) {
      // Ignore presentation synchronization errors on transient page transitions.
      return null;
    }
  }

  Future<void> _applyGamePresentation(
    GamePresentationState? state,
    int epoch,
  ) async {
    if (epoch != _presentationSyncEpoch || !mounted) return;
    final action = state?.platformAction ?? GamePresentationPlatformAction.none;
    if (action == GamePresentationPlatformAction.none) return;

    switch (action) {
      case GamePresentationPlatformAction.bind:
        await _scaleChannel.invokeMethod<void>(
          'bindFixedCanvas',
          <String, Object>{'contentWidth': 1200, 'contentHeight': 720},
        );
      case GamePresentationPlatformAction.release:
        await _scaleChannel.invokeMethod<void>('releaseFixedCanvas');
      case GamePresentationPlatformAction.none:
        return;
    }

    if (epoch != _presentationSyncEpoch || !mounted) return;
    if (state == GamePresentationState.game) {
      await _webViewController.runJavaScript('''
        if (window.__yahagiMobileAlignGame) window.__yahagiMobileAlignGame();
      ''');
    }
  }

  Future<void> _executeStartupSequence() async {
    if (!mounted) return;
    final startup = ++_startupEpoch;
    _navigationEpoch++;
    _failedNavigationEpoch = null;
    _awaitingNavigationStart = true;
    _readinessTimer?.cancel();
    _startLoadingFlow(restartDeadline: true);
    setState(() {
      _startupState = GameStartupState.applyingNetwork;
      _startupErrorMessage = '';
    });
    try {
      await _compatibilityReady;
      if (!mounted || startup != _startupEpoch) return;
      final network = widget.networkSettingsController;
      if (!network.isProxyOverrideSupported &&
          network.settings.mode != NetworkMode.system) {
        await network.applySettings(NetworkMode.system, '', 8099);
      }
      if (!mounted || startup != _startupEpoch) return;
      final settings = network.settings;
      final result = await network.applySettings(
        settings.mode,
        NetworkSettingsValidator.formatProxyHost(settings.host),
        settings.port,
      );
      if (!mounted || startup != _startupEpoch) return;
      if (!result.success) {
        _failNavigation('网络设置应用失败，请检查代理后重新加载。');
        return;
      }
      setState(() => _startupState = GameStartupState.networkReady);
      await _prepareForRealNavigation();
      if (!mounted || startup != _startupEpoch) return;
      // Re-enter through the stable connector entry, preserving all login data.
      // displayAddress is sanitized for display and may omit authentication args.
      setState(() => _startupState = GameStartupState.loadingGame);
      await _webViewController.loadRequest(widget.browserController.homeUri);
    } catch (error) {
      if (!mounted || startup != _startupEpoch) return;
      debugPrint('iOS WebView preparation failed: $error');
      _failNavigation('游戏浏览器初始化失败，请重新加载。');
    }
  }

  Future<void> _attachAudioPortOnce() async {
    if (!mounted) return;
    if (_audioPortAttached) {
      return;
    }
    _audioPortAttached = true;
    await widget.audioController.attachPort(MethodChannelGameAudioPort());
    await _syncNativeBackgroundPlaybackSetting();
  }

  void _onAudioControllerChanged() {
    _syncNativeBackgroundPlaybackSetting();
  }

  Future<void> _syncNativeBackgroundPlaybackSetting() async {
    if (!_audioPortAttached) return;
    final enabled = widget.audioController.backgroundPlaybackEnabled;
    if (_lastNativeBackgroundPlaybackEnabled == enabled) return;
    try {
      await _audioChannel.invokeMethod<void>(
        'setBackgroundPlaybackEnabled',
        <String, Object>{'enabled': enabled},
      );
      _lastNativeBackgroundPlaybackEnabled = enabled;
    } on PlatformException catch (error) {
      debugPrint('同步 iOS 后台声音设置失败：$error');
    }
  }

  Future<void> _onCaptureModeChanged() async {
    final nextMode = widget.captureModeController.mode;
    if (nextMode == _activeCaptureMode) {
      return;
    }
    _activeCaptureMode = nextMode;
    await _prepareCapture();
    if (mounted) await widget.browserController.reload();
  }

  /// iOS-enhanced: wrap capture preparation in try-catch for resilience.
  Future<void> _prepareCapture() async {
    if (!mounted) return;
    try {
      if (!_capturePortAttached) {
        await widget.gameCaptureController.attach(
          _gameCapturePort,
          enabled: widget.captureModeController.mode.installsGameBridge,
          script: nativeGameCaptureScript,
        );
        _capturePortAttached = true;
        return;
      }
      await widget.gameCaptureController.configure(
        enabled: widget.captureModeController.mode.installsGameBridge,
        script: nativeGameCaptureScript,
      );
    } catch (_) {
      // Ignore capture preparation errors on iOS.
    }
  }

  /// iOS-enhanced: supports both Android and generic (WKWebView) compatibility.
  Future<void> _configureCompatibility() async {
    final platformController = _webViewController.platform;
    if (platformController is AndroidWebViewController) {
      await platformController.setUseWideViewPort(false);

      final currentUserAgent = await platformController.getUserAgent();
      if (currentUserAgent != null && currentUserAgent.isNotEmpty) {
        final cookieManager = WebViewCookieManager().platform;
        if (cookieManager is AndroidWebViewCookieManager) {
          await GameWebViewCompatibility.configure(
            _AndroidWebViewCompatibilityPort(
              controller: platformController,
              cookieManager: cookieManager,
            ),
            currentUserAgent: currentUserAgent,
          );
        }
      }
    } else {
      await _webViewController.setUserAgent(_iosDesktopUserAgent);
    }
  }

  NavigationDecision _onNavigationRequest(NavigationRequest request) {
    if (!mounted) return NavigationDecision.prevent;
    final uri = Uri.tryParse(request.url);
    final isLocalDocument =
        widget.browserController.mode == GameBrowserMode.localPrototype &&
        (uri?.scheme == 'about' || uri?.scheme == 'data');
    if (isLocalDocument ||
        (uri != null && SafePageAddress.canNavigateInGameWebView(uri))) {
      return NavigationDecision.navigate;
    }

    widget.browserController.onBlockedNavigation(uri ?? Uri(scheme: 'invalid'));
    return NavigationDecision.prevent;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(
          key: const Key('game-webview'),
          controller: _webViewController,
        ),
        if (_startupState != GameStartupState.ready)
          Container(
            color: const Color(0xff102431),
            child: Center(child: _buildStartupOverlay()),
          ),
      ],
    );
  }

  Widget _buildStartupOverlay() {
    if (_startupState == GameStartupState.error) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              _startupErrorMessage,
              style: const TextStyle(color: Colors.redAccent, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _executeStartupSequence,
            icon: const Icon(Icons.refresh),
            label: Text(
              (AppLocalizations.of(context) ??
                      lookupAppLocalizations(const Locale('zh')))
                  .reloadGame,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff183631),
              foregroundColor: const Color(0xff80c8bd),
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(color: Color(0xffd4a85f)),
        const SizedBox(height: 24),
        Text(
          _getStartupStatusText(),
          style: const TextStyle(color: Color(0xff8197a5), fontSize: 14),
        ),
      ],
    );
  }

  String _getStartupStatusText() {
    switch (_startupState) {
      case GameStartupState.loadingSettings:
        return '正在读取配置...';
      case GameStartupState.applyingNetwork:
        return '正在应用网络设置...';
      case GameStartupState.networkReady:
        return '网络配置完毕，准备加载游戏...';
      case GameStartupState.loadingGame:
        return '正在加载游戏页面...';
      default:
        return '准备就绪...';
    }
  }

  @override
  void didUpdateWidget(covariant IOSGameWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.frameRateSettingsController !=
        widget.frameRateSettingsController) {
      _frameRateBindingGeneration++;
      _frameRateRuntimeController?.dispose();
      _frameRateRuntimeController = null;
      unawaited(_configureFrameRate());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    _navigationWatchdog.setForeground(foreground);
    if (foreground) {
      _scheduleReadinessProbe(_navigationEpoch, Duration.zero);
    } else {
      _readinessTimer?.cancel();
    }
    _frameRateRuntimeController?.onLifecycleChanged(state);
  }

  Future<void> _configureFrameRate() async {
    final controller = widget.frameRateSettingsController;
    if (controller == null || !mounted || !_runtimeInstalled) return;
    if (_frameRateRuntimeController != null && controller.supported == true) {
      return;
    }
    final generation = ++_frameRateBindingGeneration;
    bool isActive() =>
        mounted &&
        generation == _frameRateBindingGeneration &&
        identical(controller, widget.frameRateSettingsController);
    try {
      final supported = await controller.attachPortForStartup(
        MethodChannelGameFrameRatePort(isActive: isActive),
        isActive: isActive,
      );
      if (!isActive() || !supported) return;
      _frameRateRuntimeController?.dispose();
      final runtimeController = GameFrameRateRuntimeController(
        settings: controller,
        port: createGameFrameRateRuntimePort(_webViewController),
      );
      _frameRateRuntimeController = runtimeController;
      final lifecycleState = WidgetsBinding.instance.lifecycleState;
      if (lifecycleState != null) {
        runtimeController.onLifecycleChanged(lifecycleState);
      }
    } catch (_) {
      // A temporary native binding failure can recover on the next navigation.
      if (isActive()) _recordPageState('frameRatePreparationFailed');
    }
  }

  @override
  void dispose() {
    _frameRateBindingGeneration++;
    _startupEpoch++;
    _navigationEpoch++;
    _readinessTimer?.cancel();
    _navigationWatchdog.dispose();
    widget.browserController.detachPort(_browserPort);
    WidgetsBinding.instance.removeObserver(this);
    _frameRateRuntimeController?.dispose();
    widget.audioController.removeListener(_onAudioControllerChanged);
    widget.captureModeController.removeListener(_onCaptureModeChanged);
    _runtimeChannel.setMethodCallHandler(null);
    unawaited(
      _runtimeChannel.invokeMethod<void>('dispose').catchError((Object _) {}),
    );
    _gameCapturePort.dispose();
    super.dispose();
  }
}

/// Compatibility port for non-Android WebViews (iOS WKWebView, macOS).
///
/// Third-party cookies are managed at the OS level on iOS/macOS,
/// so [allowThirdPartyCookies] is a no-op.
/// Android-specific compatibility port (same as upstream).
final class _AndroidWebViewCompatibilityPort
    implements GameWebViewCompatibilityPort {
  const _AndroidWebViewCompatibilityPort({
    required this.controller,
    required this.cookieManager,
  });

  final AndroidWebViewController controller;
  final AndroidWebViewCookieManager cookieManager;

  @override
  Future<void> allowThirdPartyCookies() {
    return cookieManager.setAcceptThirdPartyCookies(controller, true);
  }

  @override
  Future<void> setUserAgent(String userAgent) {
    return controller.setUserAgent(userAgent);
  }
}

const String _prototypePage = '''
<!doctype html>
<html lang="zh-CN">
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>
html,body{height:100%;margin:0;background:#102431;color:#c7d5dc;font-family:sans-serif}
body{display:flex;align-items:center;justify-content:center}
main{text-align:center;padding:28px}h2{color:#d4a85f}p{color:#8299a5;line-height:1.6}
button{border:1px solid #5d786f;border-radius:8px;background:#183631;color:#80c8bd;padding:10px 14px}
</style>
<main>
  <h2>游戏 WebView 测试首页</h2>
  <p>这里不会连接真实账号，<br>使用上方"DMM 登录测试"主动进入真实网页。</p>
  <button onclick="YahagiBridge.postMessage(JSON.stringify({
    kind:'kcsapi-response',
    path:'/kcsapi/api_port/port',
    body:'svdata={&quot;api_result&quot;:1}',
    source:'manual',
    capturedAt:new Date().toISOString()
  }))">发送模拟舰队数据</button>
</main>
</html>
''';

const String _iosDesktopUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
    'AppleWebKit/605.1.15 (KHTML, like Gecko) '
    'Chrome/128.0.0.0 Safari/605.1.15';
