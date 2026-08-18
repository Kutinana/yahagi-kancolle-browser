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
    super.key,
  });

  final Future<void> Function(NativeGameWebViewBounds bounds) onBoundsChanged;
  final Future<void> Function(bool visible) onVisibilityChanged;
  final RouteObserver<ModalRoute<dynamic>>? routeObserver;

  @override
  State<NativeGameSurfaceSlot> createState() => _NativeGameSurfaceSlotState();
}

final class _NativeGameSurfaceSlotState extends State<NativeGameSurfaceSlot>
    with WidgetsBindingObserver, RouteAware {
  late final NativeGameSurfaceVisibility _visibility;
  RouteObserver<ModalRoute<dynamic>>? _subscribedObserver;
  ModalRoute<dynamic>? _subscribedRoute;
  NativeGameWebViewBounds? _lastBounds;
  NativeGameWebViewBounds? _pendingBounds;
  int _boundsRequestId = 0;
  bool _measureScheduled = false;

  @override
  void initState() {
    super.initState();
    _visibility = NativeGameSurfaceVisibility(widget.onVisibilityChanged);
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
    if (oldWidget.routeObserver != widget.routeObserver) {
      _subscribeToCurrentRoute();
    }
    if (oldWidget.onVisibilityChanged != widget.onVisibilityChanged) {
      _visibility.updateCallback(widget.onVisibilityChanged);
    }
    _scheduleMeasurement();
  }

  @override
  void didChangeMetrics() {
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
    _boundsRequestId++;
    _pendingBounds = null;
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
      return;
    }
    observer.subscribe(this, route);
    _subscribedObserver = observer;
    _subscribedRoute = route;
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
      _invalidatePendingBounds();
      return;
    }

    if (_sameBounds(bounds, _lastBounds)) {
      if (_pendingBounds != null && !_sameBounds(bounds, _pendingBounds)) {
        _boundsRequestId++;
        _pendingBounds = null;
      }
      _ignoreErrors(_visibility.setSlotAttached(true));
      return;
    }
    if (_sameBounds(bounds, _pendingBounds)) {
      return;
    }

    final requestId = ++_boundsRequestId;
    _pendingBounds = bounds;
    _ignoreErrors(_visibility.setSlotAttached(false));
    _ignoreErrors(_reportBounds(bounds, requestId));
  }

  Future<void> _reportBounds(
    NativeGameWebViewBounds bounds,
    int requestId,
  ) async {
    try {
      await widget.onBoundsChanged(bounds);
    } catch (error) {
      debugPrint('Native game surface bounds callback failed: $error');
      if (mounted && requestId == _boundsRequestId) {
        _pendingBounds = null;
        _ignoreErrors(_visibility.setSlotAttached(false));
      }
      return;
    }
    if (!mounted || requestId != _boundsRequestId) {
      return;
    }
    _pendingBounds = null;
    _lastBounds = bounds;
    _ignoreErrors(_visibility.setSlotAttached(true));
  }

  void _invalidatePendingBounds() {
    _boundsRequestId++;
    _pendingBounds = null;
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
        debugPrint('Native game surface callback failed: $error');
      }),
    );
  }
}
