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
  int _operationEpoch = 0;
  int _pageEpoch = 0;
  NativeGameWebViewBounds? _latestBounds;
  bool _desiredVisible = false;
  bool _active = true;
  bool _fatal = false;
  bool _networkRetryAvailable = false;
  Future<void>? _networkRetryFuture;
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
    final operationEpoch = _operationEpoch;
    _startupState = GameStartupState.applyingNetwork;
    try {
      final generationId = await port.create();
      if (!_matchesAttempt(port, operationEpoch)) return;
      _generationId = generationId;
      widget.browserController.attachPort(port);
      _replayPendingEvents(port, generationId);
      if (!_matchesGeneration(port, generationId, operationEpoch)) return;

      final bounds = _latestBounds;
      if (bounds != null) await port.setBounds(bounds);
      if (!_matchesGeneration(port, generationId, operationEpoch)) return;
      await port.setVisible(_desiredVisible && bounds != null);
      if (!_matchesGeneration(port, generationId, operationEpoch)) return;

      await WidgetsBinding.instance.endOfFrame;
      if (!_matchesGeneration(port, generationId, operationEpoch)) return;
      try {
        await _startupOrchestrator.attachFrameRatePlatformPort();
      } catch (error, stackTrace) {
        debugPrint('Frame-rate platform port unavailable: $error\n$stackTrace');
      }
      if (!_matchesGeneration(port, generationId, operationEpoch)) return;

      final result = await _startupOrchestrator.applyNetworkSettings();
      if (!_matchesGeneration(port, generationId, operationEpoch)) return;
      final settings = widget.networkSettingsController?.settings;
      if (!result.success && settings?.mode != NetworkMode.system) {
        _setNetworkStartupError('网络设置应用失败 [${result.code}]: ${result.message}');
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
        isActive: () => _matchesGeneration(port, generationId, operationEpoch),
        navigate: () async {
          if (_matchesGeneration(port, generationId, operationEpoch)) {
            await port.loadUri(initialAddress);
          }
        },
      );
      if (!_matchesGeneration(port, generationId, operationEpoch)) return;
    } catch (error, stackTrace) {
      debugPrint('Native game surface startup failed: $error\n$stackTrace');
      if (_matchesAttempt(port, operationEpoch)) {
        _setFatalError('原生 WebView 启动失败：${error.runtimeType}');
      }
    }
  }

  void _replayPendingEvents(
    NativeActivityGameWebViewPort port,
    int generationId,
  ) {
    final pending = List<NativeGameWebViewEvent>.of(_pendingEvents);
    _pendingEvents.clear();
    for (final event in pending) {
      if (!_active ||
          !identical(_port, port) ||
          _generationId != generationId) {
        break;
      }
      if (_fatal && event.type != NativeGameWebViewEventType.destroyed) {
        continue;
      }
      _dispatchCurrentEvent(event);
    }
  }

  void _onEvent(NativeGameWebViewEvent event) {
    if (!_active) return;
    final generationId = _generationId;
    if (generationId == null) {
      if (_fatal) return;
      if (_pendingEvents.length == 64) _pendingEvents.removeAt(0);
      _pendingEvents.add(event);
      return;
    }
    if (event.generationId != generationId) return;
    if (_fatal && event.type != NativeGameWebViewEventType.destroyed) return;
    _dispatchCurrentEvent(event);
  }

  void _dispatchCurrentEvent(NativeGameWebViewEvent event) {
    final generationId = _generationId;
    if (!_active ||
        generationId == null ||
        event.generationId != generationId) {
      return;
    }
    if (_fatal && event.type != NativeGameWebViewEventType.destroyed) return;
    switch (event.type) {
      case NativeGameWebViewEventType.created:
        return;
      case NativeGameWebViewEventType.pageStarted:
        _pageEpoch += 1;
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
        final port = _port;
        if (port != null) {
          unawaited(
            _finishPage(port, generationId, _operationEpoch, _pageEpoch),
          );
        }
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
        _setFatalError('游戏渲染进程已退出。');
        return;
      case NativeGameWebViewEventType.destroyed:
        _invalidateOperations(fatal: true);
        _generationId = null;
        final port = _port;
        if (port != null) {
          try {
            widget.browserController.detachPort(port);
          } catch (error, stackTrace) {
            debugPrint(
              'Native game surface controller detach failed: '
              '$error\n$stackTrace',
            );
          }
        }
        _notifyFatalError('原生 WebView 已销毁。');
        return;
    }
  }

  Future<void> _finishPage(
    NativeActivityGameWebViewPort port,
    int generationId,
    int operationEpoch,
    int pageEpoch,
  ) async {
    await _startupOrchestrator.prepareCapture();
    if (!_matchesPage(port, generationId, operationEpoch, pageEpoch)) {
      return;
    }
    await _startupOrchestrator.attachAudioPortOnce();
    if (!_matchesPage(port, generationId, operationEpoch, pageEpoch)) {
      return;
    }
    _setStartupState(GameStartupState.ready);
  }

  void _onEventError(Object error, StackTrace stackTrace) {
    if (!_active || _fatal) return;
    debugPrint('Native game WebView event failed: $error\n$stackTrace');
    _setFatalError('原生 WebView 事件通道异常。');
  }

  void _reportPageError(String message) {
    _invalidateOperations(fatal: false);
    widget.statusController.onWebResourceError(message);
    widget.browserController.onWebResourceError(
      description: message,
      isForMainFrame: true,
    );
    _setStartupState(GameStartupState.error, errorMessage: message);
  }

  void _setNetworkStartupError(String message) {
    _networkRetryAvailable = true;
    _setStartupState(GameStartupState.error, errorMessage: message);
  }

  void _setFatalError(String message) {
    _invalidateOperations(fatal: true);
    _notifyFatalError(message);
  }

  void _notifyFatalError(String message) {
    widget.statusController.onWebResourceError(message);
    widget.browserController.onWebResourceError(
      description: message,
      isForMainFrame: true,
    );
    _setStartupState(GameStartupState.error, errorMessage: message);
  }

  void _invalidateOperations({required bool fatal}) {
    if (fatal) _fatal = true;
    _operationEpoch += 1;
    _pageEpoch += 1;
    _networkRetryAvailable = false;
  }

  void _setStartupState(GameStartupState state, {String? errorMessage}) {
    if (!_active || !mounted) return;
    setState(() {
      _startupState = state;
      if (errorMessage != null) _startupErrorMessage = errorMessage;
    });
  }

  bool _matchesAttempt(NativeActivityGameWebViewPort port, int operationEpoch) {
    return _active &&
        mounted &&
        !_fatal &&
        identical(_port, port) &&
        _operationEpoch == operationEpoch;
  }

  bool _matchesGeneration(
    NativeActivityGameWebViewPort port,
    int generationId,
    int operationEpoch,
  ) {
    return _matchesAttempt(port, operationEpoch) &&
        _generationId == generationId;
  }

  bool _matchesPage(
    NativeActivityGameWebViewPort port,
    int generationId,
    int operationEpoch,
    int pageEpoch,
  ) {
    return _matchesGeneration(port, generationId, operationEpoch) &&
        _pageEpoch == pageEpoch;
  }

  Future<void> _onBoundsChanged(NativeGameWebViewBounds bounds) async {
    _latestBounds = bounds;
    final port = _port;
    if (!_active || _fatal || port == null || _generationId == null) return;
    await port.setBounds(bounds);
  }

  Future<void> _onVisibilityChanged(bool visible) async {
    _desiredVisible = visible;
    final port = _port;
    if (!_active || _fatal || port == null || _generationId == null) return;
    await port.setVisible(visible && _latestBounds != null);
  }

  void _onNetworkSettingsChanged() {
    if (_active &&
        !_fatal &&
        _networkRetryAvailable &&
        _startupState == GameStartupState.error &&
        _networkRetryFuture == null) {
      final port = _port;
      final generationId = _generationId;
      if (port != null && generationId != null) {
        final operation = _restartNetwork(port, generationId, _operationEpoch);
        _networkRetryFuture = operation;
        unawaited(
          operation
              .whenComplete(() {
                if (identical(_networkRetryFuture, operation)) {
                  _networkRetryFuture = null;
                }
              })
              .catchError((Object error, StackTrace stackTrace) {
                debugPrint(
                  'Native game surface network retry failed: '
                  '$error\n$stackTrace',
                );
              }),
        );
      }
    }
  }

  Future<void> _restartNetwork(
    NativeActivityGameWebViewPort port,
    int generationId,
    int operationEpoch,
  ) async {
    late final GameSurfaceNetworkResult result;
    try {
      result = await _startupOrchestrator.applyNetworkSettings();
    } catch (error, stackTrace) {
      debugPrint(
        'Native game surface network retry failed: $error\n$stackTrace',
      );
      return;
    }
    if (!_matchesGeneration(port, generationId, operationEpoch)) return;
    if (result.success) {
      _networkRetryAvailable = false;
      _setStartupState(GameStartupState.networkReady);
      if (!_matchesGeneration(port, generationId, operationEpoch)) return;
      await port.reload();
      if (!_matchesGeneration(port, generationId, operationEpoch)) return;
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
    final operationEpoch = _operationEpoch;
    await _startupOrchestrator.prepareCapture();
    if (_matchesGeneration(port, generationId, operationEpoch)) {
      await port.reload();
    }
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
    _invalidateOperations(fatal: true);
    widget.networkSettingsController?.removeListener(_onNetworkSettingsChanged);
    widget.captureModeController?.removeListener(_onCaptureModeChanged);
    _pendingEvents.clear();
    final port = _port;
    _port = null;
    if (port == null) {
      unawaited(_disposeStartupOrchestrator());
    } else {
      _sendHideIntent(port);
      try {
        widget.browserController.detachPort(port);
      } catch (error, stackTrace) {
        debugPrint(
          'Native game surface controller detach failed: '
          '$error\n$stackTrace',
        );
      }
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
    try {
      await subscription?.cancel();
    } catch (error, stackTrace) {
      debugPrint(
        'Native game surface event cancellation failed: $error\n$stackTrace',
      );
    }
    await _disposeStartupOrchestrator();
    try {
      await port.dispose();
    } catch (error, stackTrace) {
      debugPrint('Native game surface destroy failed: $error\n$stackTrace');
    }
  }

  Future<void> _disposeStartupOrchestrator() async {
    try {
      await _startupOrchestrator.dispose();
    } catch (error, stackTrace) {
      debugPrint(
        'Native game surface orchestrator dispose failed: '
        '$error\n$stackTrace',
      );
    }
  }
}
