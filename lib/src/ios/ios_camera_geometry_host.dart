import 'dart:async';
import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Supplies the iPhone's camera-side safe area to the shared avoidance viewport.
/// UIKit does not expose the physical notch/island rectangle as a display feature.
final class IOSCameraGeometryHost extends StatefulWidget {
  const IOSCameraGeometryHost({super.key, required this.child});

  final Widget child;

  @override
  State<IOSCameraGeometryHost> createState() => _IOSCameraGeometryHostState();
}

final class _IOSCameraGeometryHostState extends State<IOSCameraGeometryHost>
    with WidgetsBindingObserver {
  static const _channel = MethodChannel(
    'app.yahagi.kancollebrowser/camera_geometry',
  );
  Size? _windowSize;
  Rect? _cameraBand;
  bool _refreshPending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'geometryChanged') _accept(call.arguments);
    });
    _refresh();
  }

  @override
  void didChangeMetrics() => _refresh();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  void _refresh() {
    if (_refreshPending) return;
    _refreshPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshPending = false;
      if (mounted) unawaited(_read());
    });
  }

  Future<void> _read() async {
    try {
      _accept(await _channel.invokeMethod<Object?>('getGeometry'));
    } on PlatformException {
      // Preserve Flutter's own display features if native metrics are unavailable.
    } on MissingPluginException {
      // Native registration can lag the first Flutter frame during startup.
    }
  }

  void _accept(Object? value) {
    if (!mounted || value is! Map) return;
    double? number(String key) {
      final raw = value[key];
      return raw is num && raw.isFinite ? raw.toDouble() : null;
    }

    final width = number('width');
    final height = number('height');
    if (width == null || height == null || width <= 0 || height <= 0) return;
    final size = Size(width, height);
    final x = number('x');
    final y = number('y');
    final bandWidth = number('bandWidth');
    final bandHeight = number('bandHeight');
    final band =
        x != null &&
            y != null &&
            bandWidth != null &&
            bandHeight != null &&
            x >= 0 &&
            y >= 0 &&
            bandWidth > 0 &&
            bandHeight > 0 &&
            x + bandWidth <= width + .5 &&
            y + bandHeight <= height + .5
        ? Rect.fromLTWH(x, y, bandWidth, bandHeight)
        : null;
    if (_windowSize == size && _cameraBand == band) return;
    setState(() {
      _windowSize = size;
      _cameraBand = band;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _channel.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = _windowSize;
    final band = _cameraBand;
    // Rotation notifications and Flutter's metrics arrive independently. Never
    // apply a stale landscape edge to the next portrait/landscape viewport.
    final matches =
        size != null &&
        (size.width - media.size.width).abs() < .5 &&
        (size.height - media.size.height).abs() < .5;
    final features = [
      ...media.displayFeatures,
      if (matches &&
          band != null &&
          !media.displayFeatures.any(
            (f) => f.type == DisplayFeatureType.cutout,
          ))
        DisplayFeature(
          bounds: band,
          type: DisplayFeatureType.cutout,
          state: DisplayFeatureState.unknown,
        ),
    ];
    return MediaQuery(
      data: media.copyWith(displayFeatures: features),
      child: widget.child,
    );
  }
}
