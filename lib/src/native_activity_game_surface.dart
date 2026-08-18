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
  NativeActivityGameSurface({
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
    this.cleanupTimeout,
    super.key,
  }) {
    if (startupOrchestrator == null &&
        (networkSettingsController == null ||
            captureModeController == null ||
            audioController == null ||
            gameCaptureController == null)) {
      throw ArgumentError(
        'Provide startupOrchestrator or all default orchestrator dependencies.',
      );
    }
  }

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
  final Duration? cleanupTimeout;

  @override
  State<NativeActivityGameSurface> createState() =>
      _NativeActivityGameSurfaceState();
}

final class _NativeActivityGameSurfaceState
    extends State<NativeActivityGameSurface> {
  NativeActivityGameWebViewPort? _port;
  StreamSubscription<NativeGameWebViewEvent>? _eventSubscription;
  late GameSurfaceStartupOrchestrator _startupOrchestrator;
  late Duration _cleanupTimeout;
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
  bool _awaitingNewPageStart = false;
  bool _networkRetryAvailable = false;
  Future<void>? _networkRetryFuture;
  Future<void>? _visibilitySyncFuture;
  Future<void>? _captureReconfigureFuture;
  int _captureRevision = 0;
  int _visibilityRevision = 0;
  int _processedVisibilityRevision = 0;
  bool _actualVisible = false;
  bool _forceVisibilityWrite = false;
  bool _navigationSucceeded = false;
  bool _pageReady = false;
  Future<void>? _navigationFuture;
  Future<void>? _bootstrapTail;
  bool _visibilityFatalCleanupStarted = false;
  int _processedCaptureRevision = 0;
  CaptureMode? _activeCaptureMode;
  GameStartupState _startupState = GameStartupState.loadingSettings;
  String _startupErrorMessage = '';

  @override
  void initState() {
    super.initState();
    _boundsSink = _onBoundsChanged;
    _visibilitySink = _onVisibilityChanged;
    _cleanupTimeout = widget.cleanupTimeout ?? const Duration(seconds: 2);
    _startupOrchestrator = _createStartupOrchestrator(widget);
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
    _eventSubscription = port.events.listen(
      _onEvent,
      onError: _onEventError,
      onDone: _onEventDone,
    );
    unawaited(_start(port));
  }

  GameSurfaceStartupOrchestrator _createStartupOrchestrator(
    NativeActivityGameSurface configuration,
  ) {
    return configuration.startupOrchestrator ??
        DefaultGameSurfaceStartupOrchestrator(
          networkSettingsController: configuration.networkSettingsController!,
          captureModeController: configuration.captureModeController!,
          audioController: configuration.audioController!,
          gameCaptureController: configuration.gameCaptureController!,
          frameRateSettingsController:
              configuration.frameRateSettingsController,
        );
  }

  @override
  void didUpdateWidget(covariant NativeActivityGameSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    _cleanupTimeout = widget.cleanupTimeout ?? const Duration(seconds: 2);

    if (!identical(
      oldWidget.networkSettingsController,
      widget.networkSettingsController,
    )) {
      oldWidget.networkSettingsController?.removeListener(
        _onNetworkSettingsChanged,
      );
      widget.networkSettingsController?.addListener(_onNetworkSettingsChanged);
    }
    if (!identical(
      oldWidget.captureModeController,
      widget.captureModeController,
    )) {
      oldWidget.captureModeController?.removeListener(_onCaptureModeChanged);
      widget.captureModeController?.addListener(_onCaptureModeChanged);
      _activeCaptureMode = widget.captureModeController?.mode;
    }

    final port = _port;
    if (!identical(oldWidget.browserController, widget.browserController) &&
        port != null &&
        _generationId != null) {
      oldWidget.browserController.detachPort(port);
      widget.browserController.attachPort(port);
    }

    if (_startupDependenciesChanged(oldWidget, widget)) {
      final previous = _startupOrchestrator;
      _invalidateOperations(fatal: false);
      _startupOrchestrator = _createStartupOrchestrator(widget);
      unawaited(
        _disposeStartupOrchestrator(previous, timeout: _cleanupTimeout),
      );
      final generationId = _generationId;
      if (port != null && generationId != null) {
        unawaited(
          _schedulePostCreateBootstrap(port, generationId, _operationEpoch),
        );
      }
    }
  }

  bool _startupDependenciesChanged(
    NativeActivityGameSurface previous,
    NativeActivityGameSurface next,
  ) {
    if (!identical(previous.startupOrchestrator, next.startupOrchestrator)) {
      return true;
    }
    if (next.startupOrchestrator != null) return false;
    return !identical(
          previous.networkSettingsController,
          next.networkSettingsController,
        ) ||
        !identical(
          previous.captureModeController,
          next.captureModeController,
        ) ||
        !identical(previous.audioController, next.audioController) ||
        !identical(
          previous.gameCaptureController,
          next.gameCaptureController,
        ) ||
        !identical(
          previous.frameRateSettingsController,
          next.frameRateSettingsController,
        );
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
      final generationId = await port.create().timeout(_cleanupTimeout);
      if (!_matchesAttempt(port, operationEpoch)) return;
      _generationId = generationId;
      widget.browserController.attachPort(port);
      _replayPendingEvents(port, generationId);
      if (!_matchesGeneration(port, generationId, operationEpoch)) return;

      await _schedulePostCreateBootstrap(port, generationId, operationEpoch);
    } catch (error, stackTrace) {
      debugPrint('Native game surface startup failed: $error\n$stackTrace');
      if (_matchesAttempt(port, operationEpoch)) {
        _setFatalError('原生 WebView 启动失败：${error.runtimeType}');
      }
    }
  }

  Future<void> _schedulePostCreateBootstrap(
    NativeActivityGameWebViewPort port,
    int generationId,
    int operationEpoch,
  ) {
    final previous = _bootstrapTail ?? Future<void>.value();
    final operation = previous
        .catchError((Object _, StackTrace _) {})
        .then<void>((_) {
          if (!_matchesGeneration(port, generationId, operationEpoch)) {
            return Future<void>.value();
          }
          return _runPostCreateBootstrap(port, generationId, operationEpoch);
        });
    _bootstrapTail = operation;
    return operation;
  }

  Future<void> _runPostCreateBootstrap(
    NativeActivityGameWebViewPort port,
    int generationId,
    int operationEpoch,
  ) async {
    final orchestrator = _startupOrchestrator;
    try {
      if (!_matchesGeneration(port, generationId, operationEpoch)) return;
      _setStartupState(GameStartupState.applyingNetwork);
      final bounds = _latestBounds;
      if (bounds != null) {
        await port.setBounds(bounds).timeout(_cleanupTimeout);
      }
      if (!_matchesGeneration(port, generationId, operationEpoch)) return;
      await _requestVisibility(force: true);
      if (!_matchesGeneration(port, generationId, operationEpoch)) return;

      await WidgetsBinding.instance.endOfFrame;
      if (!_matchesGeneration(port, generationId, operationEpoch)) return;
      try {
        await orchestrator.attachFrameRatePlatformPort().timeout(
          _cleanupTimeout,
        );
      } catch (error, stackTrace) {
        debugPrint('Frame-rate platform port unavailable: $error\n$stackTrace');
      }
      if (!_matchesGeneration(port, generationId, operationEpoch)) return;

      final result = await orchestrator.applyNetworkSettings().timeout(
        _cleanupTimeout,
      );
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
      await orchestrator
          .runCaptureStartup(
            waitForSurface: () async {
              await WidgetsBinding.instance.endOfFrame;
            },
            isActive: () =>
                _matchesGeneration(port, generationId, operationEpoch),
            navigate: () async {
              if (_matchesGeneration(port, generationId, operationEpoch)) {
                await _navigateInitialPage(port, initialAddress);
              }
            },
          )
          .timeout(_cleanupTimeout);
      if (!_matchesGeneration(port, generationId, operationEpoch)) return;
      if (_pageReady) {
        await orchestrator.attachAudioPortOnce().timeout(_cleanupTimeout);
        if (_matchesGeneration(port, generationId, operationEpoch)) {
          _setStartupState(GameStartupState.ready);
        }
      }
    } catch (error, stackTrace) {
      debugPrint('Native game surface startup failed: $error\n$stackTrace');
      if (_matchesAttempt(port, operationEpoch)) {
        _setFatalError('原生 WebView 启动失败：${error.runtimeType}');
      }
    }
  }

  Future<void> _navigateInitialPage(
    NativeActivityGameWebViewPort port,
    Uri address,
  ) {
    if (_navigationSucceeded) return Future<void>.value();
    final existing = _navigationFuture;
    if (existing != null) return existing;
    late final Future<void> operation;
    operation = port
        .loadUri(address)
        .timeout(_cleanupTimeout)
        .then<void>((_) {
          _navigationSucceeded = true;
        })
        .whenComplete(() {
          if (identical(_navigationFuture, operation)) {
            _navigationFuture = null;
          }
        });
    _navigationFuture = operation;
    return operation;
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
        _pageReady = false;
        _awaitingNewPageStart = false;
        _pageEpoch += 1;
        final url = event.url!;
        widget.statusController.onPageStarted(url);
        widget.browserController.onPageStarted(url);
        widget.toolbarController.onStageChanged(GameSurfaceStage.login);
        if (_startupState == GameStartupState.networkReady ||
            _startupState == GameStartupState.ready ||
            _startupState == GameStartupState.error) {
          _setStartupState(GameStartupState.loadingGame);
        }
        return;
      case NativeGameWebViewEventType.pageFinished:
        if (_awaitingNewPageStart) return;
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
    try {
      await _startupOrchestrator.prepareCapture().timeout(_cleanupTimeout);
      if (!_matchesPage(port, generationId, operationEpoch, pageEpoch)) {
        return;
      }
      await _startupOrchestrator.attachAudioPortOnce().timeout(_cleanupTimeout);
      if (!_matchesPage(port, generationId, operationEpoch, pageEpoch)) {
        return;
      }
      _pageReady = true;
      _setStartupState(GameStartupState.ready);
    } catch (error, stackTrace) {
      debugPrint('Native game surface page finish failed: $error\n$stackTrace');
      if (_matchesPage(port, generationId, operationEpoch, pageEpoch)) {
        _reportPageError('游戏页面初始化失败：${error.runtimeType}');
      }
    }
  }

  void _onEventError(Object error, StackTrace stackTrace) {
    if (!_active || _fatal) return;
    debugPrint('Native game WebView event failed: $error\n$stackTrace');
    _setFatalError('原生 WebView 事件通道异常。');
  }

  void _onEventDone() {
    if (!_active || _fatal) return;
    _setFatalError('原生 WebView 事件通道已关闭。');
  }

  void _reportPageError(String message) {
    _invalidateOperations(fatal: false);
    _pageReady = false;
    _awaitingNewPageStart = true;
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
    _pageReady = false;
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
    if (fatal) {
      _fatal = true;
      _awaitingNewPageStart = false;
    }
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
    _observeVisibilityUpdate(_requestVisibility());
  }

  void _observeVisibilityUpdate(Future<void> operation) {
    unawaited(
      operation.catchError((Object error, StackTrace stackTrace) {
        debugPrint(
          'Native game surface visibility update failed: '
          '$error\n$stackTrace',
        );
      }),
    );
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
    await port.setBounds(bounds).timeout(_cleanupTimeout);
    await _requestVisibility();
  }

  Future<void> _onVisibilityChanged(bool visible) async {
    _desiredVisible = visible;
    await _requestVisibility();
  }

  Future<void> _requestVisibility({bool force = false}) {
    _visibilityRevision += 1;
    _forceVisibilityWrite = _forceVisibilityWrite || force;
    final inFlight = _visibilitySyncFuture;
    if (inFlight != null) return inFlight;
    final operation = _drainVisibility();
    _visibilitySyncFuture = operation;
    unawaited(
      operation.then<void>(
        (_) => _finishVisibilityDrain(operation),
        onError: (Object _, StackTrace _) => _finishVisibilityDrain(operation),
      ),
    );
    return operation;
  }

  void _finishVisibilityDrain(Future<void> operation) {
    if (identical(_visibilitySyncFuture, operation)) {
      _visibilitySyncFuture = null;
    }
    if (!_visibilityFatalCleanupStarted &&
        (_forceVisibilityWrite ||
            _processedVisibilityRevision < _visibilityRevision)) {
      _observeVisibilityUpdate(_requestVisibility());
    }
  }

  Future<void> _drainVisibility() async {
    Object? pendingError;
    StackTrace? pendingStackTrace;
    while (true) {
      final revision = _visibilityRevision;
      final force = _forceVisibilityWrite;
      _forceVisibilityWrite = false;
      final port = _port;
      if (port == null || _generationId == null) {
        _processedVisibilityRevision = revision;
        return;
      }
      final target =
          _active &&
          !_fatal &&
          _desiredVisible &&
          _latestBounds != null &&
          _startupState == GameStartupState.ready;
      if (force || target != _actualVisible) {
        Object? lastError;
        StackTrace? lastStackTrace;
        for (var attempt = 0; attempt < 3; attempt++) {
          try {
            await port.setVisible(target).timeout(_cleanupTimeout);
            if (!identical(_port, port)) return;
            _actualVisible = target;
            lastError = null;
            break;
          } catch (error, stackTrace) {
            lastError = error;
            lastStackTrace = stackTrace;
            if (revision != _visibilityRevision || !identical(_port, port)) {
              break;
            }
          }
        }
        if (lastError != null && revision == _visibilityRevision) {
          if (!target) {
            await _terminateUnsafeNativeOverlay(
              port,
              lastError,
              lastStackTrace!,
            );
            Error.throwWithStackTrace(lastError, lastStackTrace);
          }
          pendingError = lastError;
          pendingStackTrace = lastStackTrace;
          _reportPageError('原生 WebView 显示失败：${lastError.runtimeType}');
          _forceVisibilityWrite = true;
          continue;
        }
      }
      if (revision == _visibilityRevision) {
        _processedVisibilityRevision = revision;
        if (pendingError != null) {
          Error.throwWithStackTrace(pendingError, pendingStackTrace!);
        }
        return;
      }
    }
  }

  Future<void> _terminateUnsafeNativeOverlay(
    NativeActivityGameWebViewPort port,
    Object error,
    StackTrace stackTrace,
  ) async {
    if (_visibilityFatalCleanupStarted || !identical(_port, port)) return;
    _visibilityFatalCleanupStarted = true;
    debugPrint('Native game surface could not be hidden: $error\n$stackTrace');
    _setFatalError('原生 WebView 无法安全隐藏，已终止该模式。');
    _generationId = null;
    _port = null;
    try {
      widget.browserController.detachPort(port);
    } catch (detachError, detachStackTrace) {
      debugPrint(
        'Native game surface controller detach failed: '
        '$detachError\n$detachStackTrace',
      );
    }
    final subscription = _eventSubscription;
    _eventSubscription = null;
    await _disposeNativeResources(subscription, port);
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
      result = await _startupOrchestrator.applyNetworkSettings().timeout(
        _cleanupTimeout,
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Native game surface network retry failed: $error\n$stackTrace',
      );
      return;
    }
    if (!_matchesGeneration(port, generationId, operationEpoch)) return;
    if (result.success) {
      try {
        await port.reload().timeout(_cleanupTimeout);
      } catch (error, stackTrace) {
        debugPrint(
          'Native game surface network reload failed: $error\n$stackTrace',
        );
        if (_matchesGeneration(port, generationId, operationEpoch)) {
          _setNetworkStartupError('网络重载失败：${error.runtimeType}');
        }
        return;
      }
      if (!_matchesGeneration(port, generationId, operationEpoch)) return;
      _networkRetryAvailable = false;
      _setStartupState(GameStartupState.networkReady);
    }
  }

  void _onCaptureModeChanged() {
    final controller = widget.captureModeController;
    if (controller == null || controller.mode == _activeCaptureMode) return;
    _activeCaptureMode = controller.mode;
    _captureRevision += 1;
    _ensureCaptureReconfiguration();
  }

  void _ensureCaptureReconfiguration() {
    if (_captureReconfigureFuture != null) return;
    final operation = _drainCaptureReconfiguration();
    _captureReconfigureFuture = operation;
    unawaited(
      operation.then<void>(
        (_) => _finishCaptureReconfiguration(operation),
        onError: (Object _, StackTrace _) =>
            _finishCaptureReconfiguration(operation),
      ),
    );
  }

  void _finishCaptureReconfiguration(Future<void> operation) {
    if (identical(_captureReconfigureFuture, operation)) {
      _captureReconfigureFuture = null;
    }
    if (_active && !_fatal && _processedCaptureRevision < _captureRevision) {
      _ensureCaptureReconfiguration();
    }
  }

  Future<void> _drainCaptureReconfiguration() async {
    while (_active && !_fatal) {
      final revision = _captureRevision;
      final generationId = _generationId;
      final port = _port;
      if (generationId == null || port == null) {
        _processedCaptureRevision = revision;
        return;
      }
      final operationEpoch = _operationEpoch;
      try {
        await _startupOrchestrator.prepareCapture().timeout(_cleanupTimeout);
        if (!_matchesGeneration(port, generationId, operationEpoch)) return;
        if (revision != _captureRevision) continue;
        await port.reload().timeout(_cleanupTimeout);
        if (!_matchesGeneration(port, generationId, operationEpoch)) return;
      } catch (error, stackTrace) {
        debugPrint(
          'Native game surface capture reconfiguration failed: '
          '$error\n$stackTrace',
        );
        if (_matchesGeneration(port, generationId, operationEpoch) &&
            revision == _captureRevision) {
          _reportPageError('捕获模式切换失败：${error.runtimeType}');
        }
        _processedCaptureRevision = revision;
        return;
      }
      if (revision == _captureRevision) {
        _processedCaptureRevision = revision;
        return;
      }
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
    _desiredVisible = false;
    widget.networkSettingsController?.removeListener(_onNetworkSettingsChanged);
    widget.captureModeController?.removeListener(_onCaptureModeChanged);
    _pendingEvents.clear();
    final port = _port;
    if (port == null) {
      if (!_visibilityFatalCleanupStarted) {
        unawaited(
          _disposeStartupOrchestrator(
            _startupOrchestrator,
            timeout: _cleanupTimeout,
          ),
        );
      }
    } else {
      final subscription = _eventSubscription;
      _eventSubscription = null;
      final orchestrator = _startupOrchestrator;
      final browserController = widget.browserController;
      final hide = _requestVisibility(force: true);
      try {
        browserController.detachPort(port);
      } catch (error, stackTrace) {
        debugPrint(
          'Native game surface controller detach failed: '
          '$error\n$stackTrace',
        );
      }
      unawaited(
        _disposeAfterVisibility(hide, subscription, port, orchestrator),
      );
    }
    super.dispose();
  }

  Future<void> _disposeAfterVisibility(
    Future<void> hide,
    StreamSubscription<NativeGameWebViewEvent>? subscription,
    NativeActivityGameWebViewPort port,
    GameSurfaceStartupOrchestrator orchestrator,
  ) async {
    await _runBoundedCleanup(
      () => hide,
      'final visibility',
      timeout: _cleanupTimeout,
    );
    if (_visibilityFatalCleanupStarted) return;
    _port = null;
    await _disposeNativeResources(
      subscription,
      port,
      orchestrator: orchestrator,
    );
  }

  Future<void> _disposeNativeResources(
    StreamSubscription<NativeGameWebViewEvent>? subscription,
    NativeActivityGameWebViewPort port, {
    GameSurfaceStartupOrchestrator? orchestrator,
  }) async {
    if (subscription != null) {
      await _runBoundedCleanup(
        subscription.cancel,
        'event cancellation',
        timeout: _cleanupTimeout,
      );
    }
    final startupCleanup = _disposeStartupOrchestrator(
      orchestrator ?? _startupOrchestrator,
      timeout: _cleanupTimeout,
    );
    final nativeCleanup = _runBoundedCleanup(
      port.dispose,
      'destroy',
      timeout: _cleanupTimeout,
    );
    await Future.wait(<Future<void>>[startupCleanup, nativeCleanup]);
  }

  Future<void> _disposeStartupOrchestrator(
    GameSurfaceStartupOrchestrator orchestrator, {
    Duration? timeout,
  }) {
    return _runBoundedCleanup(
      orchestrator.dispose,
      'orchestrator dispose',
      timeout: timeout,
    );
  }

  Future<void> _runBoundedCleanup(
    FutureOr<void> Function() action,
    String label, {
    Duration? timeout,
  }) async {
    try {
      final operation = Future<void>.sync(action);
      await (timeout == null ? operation : operation.timeout(timeout));
    } catch (error, stackTrace) {
      debugPrint(
        'Native game surface $label failed: '
        '$error\n$stackTrace',
      );
    }
  }
}
