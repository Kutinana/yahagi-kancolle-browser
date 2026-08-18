import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'audio/game_audio_controller.dart';
import 'browser/game_browser_controller.dart';
import 'browser/game_launch_config.dart';
import 'browser/game_toolbar_controller.dart';
import 'browser/native_game_surface_slot.dart';
import 'browser/native_game_webview_contract.dart';
import 'browser/native_game_webview_port.dart';
import 'browser/safe_page_address.dart';
import 'capture/capture_mode.dart';
import 'capture/capture_mode_controller.dart';
import 'capture/game_capture_controller.dart';
import 'game_webview.dart';
import 'prototype_status_controller.dart';
import 'settings/game_frame_rate_settings.dart';
import 'settings/network_settings_controller.dart';
import 'settings/network_settings_store.dart';

abstract interface class NativeActivityGameWebViewPort
    implements GameBrowserPort {
  Stream<NativeGameWebViewEvent> get events;

  Future<int> create();

  Future<void> setBounds(NativeGameWebViewBounds bounds);

  Future<void> setVisible(bool visible);

  Future<void> dispose();
}

final class MethodChannelNativeActivityGameWebViewPort
    implements NativeActivityGameWebViewPort {
  MethodChannelNativeActivityGameWebViewPort({
    MethodChannelNativeGameWebViewPort? delegate,
  }) : _delegate = delegate ?? MethodChannelNativeGameWebViewPort();

  final MethodChannelNativeGameWebViewPort _delegate;

  @override
  Stream<NativeGameWebViewEvent> get events => _delegate.events;

  @override
  Future<int> create() => _delegate.create();

  @override
  Future<void> setBounds(NativeGameWebViewBounds bounds) =>
      _delegate.setBounds(bounds);

  @override
  Future<void> setVisible(bool visible) => _delegate.setVisible(visible);

  @override
  Future<void> loadUri(Uri uri) => _delegate.loadUri(uri);

  @override
  Future<void> showLocalHome() => _delegate.showLocalHome();

  @override
  Future<void> reload() => _delegate.reload();

  @override
  Future<bool> canGoBack() => _delegate.canGoBack();

  @override
  Future<void> goBack() => _delegate.goBack();

  @override
  Future<void> runJavaScript(String javascript) =>
      _delegate.runJavaScript(javascript);

  @override
  Future<void> fitGameScreen() => _delegate.fitGameScreen();

  @override
  Future<void> clearCache() => _delegate.clearCache();

  @override
  Future<void> clearSession() => _delegate.clearSession();

  @override
  Future<void> dispose() => _delegate.dispose();
}

typedef NativeActivityGameWebViewPortFactory =
    NativeActivityGameWebViewPort Function();

final class NativeActivityGameSurface extends StatefulWidget {
  const NativeActivityGameSurface({
    required this.statusController,
    required this.browserController,
    required this.toolbarController,
    required this.routeObserver,
    this.networkSettingsController,
    this.captureModeController,
    this.audioController,
    this.gameCaptureController,
    this.frameRateSettingsController,
    this.portFactory,
    this.startupOrchestrator,
    super.key,
  }) : assert(
         startupOrchestrator != null ||
             (networkSettingsController != null &&
                 captureModeController != null &&
                 audioController != null &&
                 gameCaptureController != null),
       );

  final PrototypeStatusController statusController;
  final GameBrowserController browserController;
  final GameToolbarController toolbarController;
  final RouteObserver<ModalRoute<dynamic>> routeObserver;
  final NetworkSettingsController? networkSettingsController;
  final CaptureModeController? captureModeController;
  final GameAudioController? audioController;
  final GameCaptureController? gameCaptureController;
  final GameFrameRateSettingsController? frameRateSettingsController;
  final NativeActivityGameWebViewPortFactory? portFactory;
  final GameSurfaceStartupOrchestrator? startupOrchestrator;

  @override
  State<NativeActivityGameSurface> createState() =>
      _NativeActivityGameSurfaceState();
}

final class _NativeActivityGameSurfaceState
    extends State<NativeActivityGameSurface> {
  NativeActivityGameWebViewPort? _port;
  StreamSubscription<NativeGameWebViewEvent>? _eventSubscription;
  late final GameSurfaceStartupOrchestrator _startupOrchestrator;
  late final Future<void> Function(NativeGameWebViewBounds) _boundsSink;
  late final Future<void> Function(bool) _visibilitySink;
  final List<NativeGameWebViewEvent> _pendingEvents =
      <NativeGameWebViewEvent>[];

  int? _generationId;
  NativeGameWebViewBounds? _latestBounds;
  bool _desiredVisible = false;
  bool _active = true;
  bool _networkRetryAvailable = false;
  CaptureMode? _activeCaptureMode;
  GameStartupState _startupState = GameStartupState.loadingSettings;
  String _startupErrorMessage = '';

  @override
  void initState() {
    super.initState();
    _boundsSink = _onBoundsChanged;
    _visibilitySink = _onVisibilityChanged;
    _startupOrchestrator =
        widget.startupOrchestrator ??
        DefaultGameSurfaceStartupOrchestrator(
          networkSettingsController: widget.networkSettingsController!,
          captureModeController: widget.captureModeController!,
          audioController: widget.audioController!,
          gameCaptureController: widget.gameCaptureController!,
          frameRateSettingsController: widget.frameRateSettingsController,
        );
    _activeCaptureMode = widget.captureModeController?.mode;
    widget.networkSettingsController?.addListener(_onNetworkSettingsChanged);
    widget.captureModeController?.addListener(_onCaptureModeChanged);

    final port = widget.portFactory?.call() ?? _createDefaultPort();
    _port = port;
    if (port == null) {
      _startupState = GameStartupState.error;
      _startupErrorMessage = '原生 Activity WebView 仅支持 Android。';
      return;
    }
    _eventSubscription = port.events.listen(_onEvent, onError: _onEventError);
    unawaited(_start(port));
  }

  NativeActivityGameWebViewPort? _createDefaultPort() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }
    return MethodChannelNativeActivityGameWebViewPort();
  }

  Future<void> _start(NativeActivityGameWebViewPort port) async {
    _startupState = GameStartupState.applyingNetwork;
    try {
      final generationId = await port.create();
      if (!_active || !identical(_port, port)) return;
      _generationId = generationId;
      widget.browserController.attachPort(port);
      _replayPendingEvents(generationId);
      if (!_isCurrent(generationId)) return;

      final bounds = _latestBounds;
      if (bounds != null) await port.setBounds(bounds);
      if (!_isCurrent(generationId)) return;
      await port.setVisible(_desiredVisible && bounds != null);
      if (!_isCurrent(generationId)) return;

      await WidgetsBinding.instance.endOfFrame;
      if (!_isCurrent(generationId)) return;
      try {
        await _startupOrchestrator.attachFrameRatePlatformPort();
      } catch (error) {
        debugPrint('Frame-rate platform port unavailable: $error');
      }
      if (!_isCurrent(generationId)) return;

      final result = await _startupOrchestrator.applyNetworkSettings();
      if (!_isCurrent(generationId)) return;
      final settings = widget.networkSettingsController?.settings;
      if (!result.success && settings?.mode != NetworkMode.system) {
        _setStartupError(
          '网络设置应用失败 [${result.code}]: ${result.message}',
          notifyControllers: false,
          retryNetwork: true,
        );
        return;
      }
      _setStartupState(GameStartupState.networkReady);

      final displayAddress = widget.browserController.displayAddress;
      final address = Uri.tryParse(displayAddress);
      final initialAddress =
          address != null &&
              SafePageAddress.canNavigate(address) &&
              widget.browserController.mode != GameBrowserMode.localPrototype
          ? address
          : GameLaunchConfig.dmmGameEntry;
      await _startupOrchestrator.runCaptureStartup(
        waitForSurface: () async {
          await WidgetsBinding.instance.endOfFrame;
        },
        isActive: () => _isCurrent(generationId),
        navigate: () async {
          if (_isCurrent(generationId)) await port.loadUri(initialAddress);
        },
      );
    } catch (error) {
      if (_active && identical(_port, port)) {
        _setStartupError('原生 WebView 启动失败：${error.runtimeType}');
      }
    }
  }

  void _replayPendingEvents(int generationId) {
    final pending = List<NativeGameWebViewEvent>.of(_pendingEvents);
    _pendingEvents.clear();
    for (final event in pending) {
      if (!_isCurrent(generationId)) break;
      _dispatchCurrentEvent(event);
    }
  }

  void _onEvent(NativeGameWebViewEvent event) {
    if (!_active) return;
    final generationId = _generationId;
    if (generationId == null) {
      if (_pendingEvents.length == 64) _pendingEvents.removeAt(0);
      _pendingEvents.add(event);
      return;
    }
    if (event.generationId != generationId) return;
    _dispatchCurrentEvent(event);
  }

  void _dispatchCurrentEvent(NativeGameWebViewEvent event) {
    final generationId = _generationId;
    if (!_active ||
        generationId == null ||
        event.generationId != generationId) {
      return;
    }
    switch (event.type) {
      case NativeGameWebViewEventType.created:
        return;
      case NativeGameWebViewEventType.pageStarted:
        final url = event.url!;
        widget.statusController.onPageStarted(url);
        widget.browserController.onPageStarted(url);
        widget.toolbarController.onStageChanged(GameSurfaceStage.login);
        if (_startupState == GameStartupState.networkReady) {
          _setStartupState(GameStartupState.loadingGame);
        }
        return;
      case NativeGameWebViewEventType.pageFinished:
        final url = event.url!;
        widget.statusController.onPageFinished(url);
        widget.browserController.onPageFinished(url);
        unawaited(_finishPage(generationId));
        return;
      case NativeGameWebViewEventType.mainFrameError:
        _reportPageError(event.description!);
        return;
      case NativeGameWebViewEventType.navigationBlocked:
        widget.browserController.onBlockedNavigation(
          Uri(scheme: event.scheme!),
        );
        return;
      case NativeGameWebViewEventType.renderProcessGone:
        _setStartupError('游戏渲染进程已退出。');
        return;
      case NativeGameWebViewEventType.destroyed:
        _generationId = null;
        final port = _port;
        if (port != null) widget.browserController.detachPort(port);
        _setStartupError('原生 WebView 已销毁。');
        return;
    }
  }

  Future<void> _finishPage(int generationId) async {
    await _startupOrchestrator.prepareCapture();
    if (!_isCurrent(generationId)) return;
    await _startupOrchestrator.attachAudioPortOnce();
    if (!_isCurrent(generationId)) return;
    _setStartupState(GameStartupState.ready);
  }

  void _onEventError(Object error, StackTrace stackTrace) {
    if (!_active) return;
    debugPrint('Native game WebView event failed: $error\n$stackTrace');
    _setStartupError('原生 WebView 事件通道异常。');
  }

  void _reportPageError(String message) {
    _networkRetryAvailable = false;
    widget.statusController.onWebResourceError(message);
    widget.browserController.onWebResourceError(
      description: message,
      isForMainFrame: true,
    );
    _setStartupState(GameStartupState.error, errorMessage: message);
  }

  void _setStartupError(
    String message, {
    bool notifyControllers = true,
    bool retryNetwork = false,
  }) {
    _networkRetryAvailable = retryNetwork;
    if (notifyControllers) {
      widget.statusController.onWebResourceError(message);
      widget.browserController.onWebResourceError(
        description: message,
        isForMainFrame: true,
      );
    }
    _setStartupState(GameStartupState.error, errorMessage: message);
  }

  void _setStartupState(GameStartupState state, {String? errorMessage}) {
    if (!_active || !mounted) return;
    setState(() {
      _startupState = state;
      if (errorMessage != null) _startupErrorMessage = errorMessage;
    });
  }

  bool _isCurrent(int generationId) => _active && _generationId == generationId;

  Future<void> _onBoundsChanged(NativeGameWebViewBounds bounds) async {
    _latestBounds = bounds;
    final port = _port;
    if (!_active || port == null || _generationId == null) return;
    await port.setBounds(bounds);
  }

  Future<void> _onVisibilityChanged(bool visible) async {
    _desiredVisible = visible;
    final port = _port;
    if (!_active || port == null || _generationId == null) return;
    await port.setVisible(visible && _latestBounds != null);
  }

  void _onNetworkSettingsChanged() {
    if (_active &&
        _networkRetryAvailable &&
        _startupState == GameStartupState.error) {
      final port = _port;
      if (port != null) unawaited(_restartNetwork(port));
    }
  }

  Future<void> _restartNetwork(NativeActivityGameWebViewPort port) async {
    final result = await _startupOrchestrator.applyNetworkSettings();
    if (!_active || !identical(_port, port)) return;
    if (result.success) {
      _networkRetryAvailable = false;
      _setStartupState(GameStartupState.networkReady);
      await port.reload();
    }
  }

  void _onCaptureModeChanged() {
    final controller = widget.captureModeController;
    if (controller == null || controller.mode == _activeCaptureMode) return;
    _activeCaptureMode = controller.mode;
    unawaited(_reconfigureCapture());
  }

  Future<void> _reconfigureCapture() async {
    final generationId = _generationId;
    final port = _port;
    if (generationId == null || port == null) return;
    await _startupOrchestrator.prepareCapture();
    if (_isCurrent(generationId)) await port.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        NativeGameSurfaceSlot(
          onBoundsChanged: _boundsSink,
          onVisibilityChanged: _visibilitySink,
          routeObserver: widget.routeObserver,
          boundsSinkIdentity: _port ?? this,
        ),
        if (_startupState != GameStartupState.ready)
          Positioned.fill(
            child: ColoredBox(
              color: const Color(0xff102431),
              child: Center(child: _buildStartupOverlay()),
            ),
          ),
      ],
    );
  }

  Widget _buildStartupOverlay() {
    if (_startupState == GameStartupState.error) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          _startupErrorMessage,
          key: const Key('native-game-surface-error'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.redAccent),
        ),
      );
    }
    return const CircularProgressIndicator(color: Color(0xffd4a85f));
  }

  @override
  void dispose() {
    _active = false;
    widget.networkSettingsController?.removeListener(_onNetworkSettingsChanged);
    widget.captureModeController?.removeListener(_onCaptureModeChanged);
    _pendingEvents.clear();
    final port = _port;
    _port = null;
    if (port == null) {
      _startupOrchestrator.dispose();
    } else {
      _sendHideIntent(port);
      widget.browserController.detachPort(port);
      final subscription = _eventSubscription;
      _eventSubscription = null;
      unawaited(_disposeNativeResources(subscription, port));
    }
    super.dispose();
  }

  void _sendHideIntent(NativeActivityGameWebViewPort port) {
    try {
      unawaited(
        port.setVisible(false).catchError((
          Object error,
          StackTrace stackTrace,
        ) {
          debugPrint('Native game surface hide failed: $error\n$stackTrace');
        }),
      );
    } catch (error, stackTrace) {
      debugPrint('Native game surface hide failed: $error\n$stackTrace');
    }
  }

  Future<void> _disposeNativeResources(
    StreamSubscription<NativeGameWebViewEvent>? subscription,
    NativeActivityGameWebViewPort port,
  ) async {
    Future<void>? cancellation;
    try {
      cancellation = subscription?.cancel();
    } catch (error, stackTrace) {
      debugPrint(
        'Native game surface event cancellation failed: $error\n$stackTrace',
      );
    }
    if (cancellation != null) {
      unawaited(
        cancellation.catchError((Object error, StackTrace stackTrace) {
          debugPrint(
            'Native game surface event cancellation failed: $error\n$stackTrace',
          );
        }),
      );
    }
    _startupOrchestrator.dispose();
    try {
      await port.dispose();
    } catch (error, stackTrace) {
      debugPrint('Native game surface destroy failed: $error\n$stackTrace');
    }
  }
}
