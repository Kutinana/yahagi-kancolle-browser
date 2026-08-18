import 'dart:async';

import 'package:flutter/material.dart';

import 'native_game_surface_visibility.dart';
import 'native_game_webview_contract.dart';

NativeGameWebViewBounds? readNativeGameSurfaceBounds(
  RenderObject? renderObject, {
  required double devicePixelRatio,
}) {
  if (renderObject is! RenderBox || !renderObject.attached) {
    return null;
  }
  return nativeGameSurfaceBoundsFromMetrics(
    size: renderObject.size,
    offset: renderObject.localToGlobal(Offset.zero),
    devicePixelRatio: devicePixelRatio,
  );
}

NativeGameWebViewBounds? nativeGameSurfaceBoundsFromMetrics({
  required Size size,
  required Offset offset,
  required double devicePixelRatio,
}) {
  if (!size.width.isFinite ||
      !size.height.isFinite ||
      size.width <= 0 ||
      size.height <= 0 ||
      !offset.dx.isFinite ||
      !offset.dy.isFinite ||
      !devicePixelRatio.isFinite ||
      devicePixelRatio <= 0) {
    return null;
  }
  return NativeGameWebViewBounds(
    left: offset.dx,
    top: offset.dy,
    width: size.width,
    height: size.height,
    devicePixelRatio: devicePixelRatio,
  );
}

/// A transparent Flutter layout slot whose bounds are mirrored to a native
/// game WebView owned outside of Flutter's widget tree.
final class NativeGameSurfaceSlot extends StatefulWidget {
  const NativeGameSurfaceSlot({
    required this.onBoundsChanged,
    required this.onVisibilityChanged,
    this.routeObserver,
    this.visibilityCallbackTimeout = const Duration(seconds: 2),
    this.boundsCallbackTimeout = const Duration(seconds: 2),
    this.boundsRetryLimit = 3,
    super.key,
  }) : assert(boundsRetryLimit > 0),
       assert(visibilityCallbackTimeout != Duration.zero),
       assert(boundsCallbackTimeout != Duration.zero);

  final Future<void> Function(NativeGameWebViewBounds bounds) onBoundsChanged;
  final Future<void> Function(bool visible) onVisibilityChanged;
  final RouteObserver<ModalRoute<dynamic>>? routeObserver;
  final Duration visibilityCallbackTimeout;
  final Duration boundsCallbackTimeout;
  final int boundsRetryLimit;

  @override
  State<NativeGameSurfaceSlot> createState() => _NativeGameSurfaceSlotState();
}

final class _NativeGameSurfaceSlotState extends State<NativeGameSurfaceSlot>
    with WidgetsBindingObserver, RouteAware {
  late final NativeGameSurfaceVisibility _visibility;
  RouteObserver<ModalRoute<dynamic>>? _subscribedObserver;
  ModalRoute<dynamic>? _subscribedRoute;
  NativeGameWebViewBounds? _lastBounds;
  NativeGameWebViewBounds? _currentBounds;
  NativeGameWebViewBounds? _queuedBounds;
  NativeGameWebViewBounds? _retryBounds;
  bool _boundsDrainRunning = false;
  bool _boundsRetryScheduled = false;
  bool _boundsRetryExhausted = false;
  int _boundsRetryAttempts = 0;
  int _boundsGeneration = 0;
  bool _measureScheduled = false;
  bool _synchronizingRouteSubscription = false;

  @override
  void initState() {
    super.initState();
    _visibility = NativeGameSurfaceVisibility(
      widget.onVisibilityChanged,
      callbackTimeout: widget.visibilityCallbackTimeout,
    );
    WidgetsBinding.instance.addObserver(this);
    _ignoreErrors(
      _visibility.setAppVisible(
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
      ),
    );
    _scheduleMeasurement();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _subscribeToCurrentRoute();
  }

  @override
  void didUpdateWidget(covariant NativeGameSurfaceSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onVisibilityChanged != widget.onVisibilityChanged) {
      _visibility.updateCallback(widget.onVisibilityChanged);
    }
    if (oldWidget.routeObserver != widget.routeObserver) {
      _subscribeToCurrentRoute();
    }
    if (_boundsRetryExhausted) {
      _restartBoundsRetries();
    }
    _scheduleMeasurement();
  }

  @override
  void didChangeMetrics() {
    _restartBoundsRetries();
    _scheduleMeasurement();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _ignoreErrors(
      _visibility.setAppVisible(state == AppLifecycleState.resumed),
    );
  }

  @override
  void didPush() {
    if (_synchronizingRouteSubscription) {
      return;
    }
    _ignoreErrors(_visibility.setRouteVisible(true));
  }

  @override
  void didPop() {
    _ignoreErrors(_visibility.setRouteVisible(false));
  }

  @override
  void didPushNext() {
    _ignoreErrors(_visibility.setRouteVisible(false));
  }

  @override
  void didPopNext() {
    _ignoreErrors(_visibility.setRouteVisible(true));
  }

  @override
  void dispose() {
    _boundsGeneration++;
    _currentBounds = null;
    _queuedBounds = null;
    WidgetsBinding.instance.removeObserver(this);
    _unsubscribeFromRoute();
    _ignoreErrors(_visibility.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();

  void _subscribeToCurrentRoute() {
    final observer = widget.routeObserver;
    final route = ModalRoute.of(context);
    if (identical(observer, _subscribedObserver) &&
        identical(route, _subscribedRoute)) {
      return;
    }
    _unsubscribeFromRoute();
    if (observer == null || route == null) {
      _ignoreErrors(_visibility.setRouteVisible(true));
      return;
    }
    _synchronizingRouteSubscription = true;
    try {
      observer.subscribe(this, route);
    } finally {
      _synchronizingRouteSubscription = false;
    }
    _subscribedObserver = observer;
    _subscribedRoute = route;
    _ignoreErrors(_visibility.setRouteVisible(route.isCurrent));
  }

  void _unsubscribeFromRoute() {
    _subscribedObserver?.unsubscribe(this);
    _subscribedObserver = null;
    _subscribedRoute = null;
  }

  void _scheduleMeasurement() {
    if (_measureScheduled) {
      return;
    }
    _measureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureScheduled = false;
      if (mounted) {
        _measureAndReport();
      }
    });
  }

  void _measureAndReport() {
    final bounds = readNativeGameSurfaceBounds(
      context.findRenderObject(),
      devicePixelRatio: View.of(context).devicePixelRatio,
    );
    if (bounds == null) {
      _invalidateBounds();
      return;
    }

    final changed = !_sameBounds(bounds, _currentBounds);
    if (changed) {
      _currentBounds = bounds;
      _boundsGeneration++;
      _restartBoundsRetries();
    }
    if (_sameBounds(bounds, _lastBounds) &&
        !_boundsDrainRunning &&
        _queuedBounds == null) {
      _ignoreErrors(_visibility.setSlotAttached(true));
      return;
    }
    if (_boundsRetryExhausted && !changed) {
      return;
    }
    _queuedBounds = bounds;
    _ignoreErrors(_visibility.setSlotAttached(false));
    _drainBounds();
  }

  void _drainBounds() {
    if (_boundsDrainRunning) {
      return;
    }
    _boundsDrainRunning = true;
    unawaited(_runBoundsDrain());
  }

  Future<void> _runBoundsDrain() async {
    try {
      while (mounted && _queuedBounds != null) {
        final bounds = _queuedBounds!;
        final generation = _boundsGeneration;
        _queuedBounds = null;
        try {
          await widget
              .onBoundsChanged(bounds)
              .timeout(widget.boundsCallbackTimeout);
        } catch (error, stackTrace) {
          debugPrint(
            'Native game surface bounds callback failed: $error\n$stackTrace',
          );
          if (!mounted ||
              generation != _boundsGeneration ||
              !_sameBounds(bounds, _currentBounds)) {
            continue;
          }
          if (!_sameBounds(bounds, _retryBounds)) {
            _retryBounds = bounds;
            _boundsRetryAttempts = 0;
          }
          _boundsRetryAttempts++;
          if (_boundsRetryAttempts < widget.boundsRetryLimit) {
            _scheduleBoundsRetry();
          } else {
            _boundsRetryExhausted = true;
            _ignoreErrors(_visibility.setSlotAttached(false));
          }
          return;
        }
        _lastBounds = bounds;
        _retryBounds = null;
        _boundsRetryAttempts = 0;
        if (generation == _boundsGeneration &&
            _sameBounds(bounds, _currentBounds)) {
          _ignoreErrors(_visibility.setSlotAttached(true));
        }
      }
    } finally {
      _boundsDrainRunning = false;
      if (mounted && _queuedBounds != null) {
        _drainBounds();
      }
    }
  }

  void _scheduleBoundsRetry() {
    if (_boundsRetryScheduled) {
      return;
    }
    _boundsRetryScheduled = true;
    WidgetsBinding.instance.scheduleFrame();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _boundsRetryScheduled = false;
      if (!mounted || _boundsRetryExhausted || _currentBounds == null) {
        return;
      }
      _queuedBounds = _currentBounds;
      _drainBounds();
    });
  }

  void _restartBoundsRetries() {
    _boundsRetryExhausted = false;
    _boundsRetryAttempts = 0;
    _retryBounds = null;
  }

  void _invalidateBounds() {
    _boundsGeneration++;
    _currentBounds = null;
    _queuedBounds = null;
    _restartBoundsRetries();
    _ignoreErrors(_visibility.setSlotAttached(false));
  }

  static bool _sameBounds(
    NativeGameWebViewBounds first,
    NativeGameWebViewBounds? second,
  ) {
    return second != null &&
        first.left == second.left &&
        first.top == second.top &&
        first.width == second.width &&
        first.height == second.height &&
        first.devicePixelRatio == second.devicePixelRatio;
  }

  void _ignoreErrors(Future<void> future) {
    unawaited(
      future.catchError((Object error, StackTrace stackTrace) {
        debugPrint('Native game surface callback failed: $error\n$stackTrace');
      }),
    );
  }
}
