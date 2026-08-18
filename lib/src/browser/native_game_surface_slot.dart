import 'dart:async';

import 'package:flutter/material.dart';

import 'native_game_surface_visibility.dart';
import 'native_game_webview_contract.dart';

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
  bool _measureScheduled = false;

  @override
  void initState() {
    super.initState();
    _visibility = NativeGameSurfaceVisibility(widget.onVisibilityChanged);
    WidgetsBinding.instance.addObserver(this);
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
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached) {
      _ignoreErrors(_visibility.setSlotAttached(false));
      return;
    }

    final size = renderObject.size;
    final offset = renderObject.localToGlobal(Offset.zero);
    final devicePixelRatio = View.of(context).devicePixelRatio;
    if (!size.width.isFinite ||
        !size.height.isFinite ||
        size.width <= 0 ||
        size.height <= 0 ||
        !offset.dx.isFinite ||
        !offset.dy.isFinite ||
        !devicePixelRatio.isFinite ||
        devicePixelRatio <= 0) {
      _ignoreErrors(_visibility.setSlotAttached(false));
      return;
    }

    final bounds = NativeGameWebViewBounds(
      left: offset.dx,
      top: offset.dy,
      width: size.width,
      height: size.height,
      devicePixelRatio: devicePixelRatio,
    );
    if (_sameBounds(bounds, _lastBounds)) {
      _ignoreErrors(_visibility.setSlotAttached(true));
      return;
    }
    _lastBounds = bounds;
    _ignoreErrors(widget.onBoundsChanged(bounds));
    _ignoreErrors(_visibility.setSlotAttached(true));
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
