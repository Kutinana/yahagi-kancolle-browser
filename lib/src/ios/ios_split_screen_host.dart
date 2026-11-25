import 'dart:async';
import 'dart:ui' show DisplayFeature;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../settings/display_mode_controller.dart';
import '../settings/display_mode_store.dart';

/// Gives a landscape layout the long axis of a Duo split-screen window.
/// Keep the same subtree (including WKWebView) mounted across all rotations.
final class IOSSplitScreenHost extends StatefulWidget {
  const IOSSplitScreenHost({
    super.key,
    required this.displayModeController,
    required this.child,
  });

  final DisplayModeController displayModeController;
  final Widget child;

  @override
  State<IOSSplitScreenHost> createState() => _IOSSplitScreenHostState();
}

final class _IOSSplitScreenHostState extends State<IOSSplitScreenHost>
    with WidgetsBindingObserver {
  static const _channel = MethodChannel(
    'app.yahagi.kancollebrowser/split_screen',
  );
  Size? _windowSize;
  int _splitQuarterTurns = 0;
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
    WidgetsBinding.instance.scheduleFrame();
  }

  Future<void> _read() async {
    try {
      _accept(await _channel.invokeMethod<Object?>('getGeometry'));
    } on PlatformException {
      // Use the ordinary window layout when native geometry is unavailable.
    } on MissingPluginException {
      // Native registration can lag the first Flutter frame.
    }
  }

  void _accept(Object? value) {
    if (!mounted || value is! Map) return;
    final width = value['width'];
    final height = value['height'];
    if (width is! num ||
        height is! num ||
        !width.isFinite ||
        !height.isFinite ||
        width <= 0 ||
        height <= 0) {
      return;
    }
    final size = Size(width.toDouble(), height.toDouble());
    final turns = value['quarterTurns'];
    final nextTurns =
        value['isSplitScreen'] == true && (turns == 1 || turns == 3)
        ? turns as int
        : 0;
    if (size == _windowSize && nextTurns == _splitQuarterTurns) return;
    setState(() {
      _windowSize = size;
      _splitQuarterTurns = nextTurns;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _channel.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.displayModeController,
    builder: (context, _) {
      final media = MediaQuery.of(context);
      final size = _windowSize;
      final matches =
          size != null &&
          (size.width - media.size.width).abs() < .5 &&
          (size.height - media.size.height).abs() < .5;
      final turns =
          matches &&
              media.size.height > media.size.width &&
              widget.displayModeController.displayMode == DisplayMode.landscape
          ? _splitQuarterTurns
          : 0;
      return RotatedBox(
        quarterTurns: turns,
        child: MediaQuery(
          data: turns == 0 ? media : _rotateMedia(media, turns),
          child: widget.child,
        ),
      );
    },
  );
}

MediaQueryData _rotateMedia(MediaQueryData media, int turns) {
  EdgeInsets rotateInsets(EdgeInsets value) => turns == 1
      ? EdgeInsets.fromLTRB(value.top, value.right, value.bottom, value.left)
      : EdgeInsets.fromLTRB(value.bottom, value.left, value.top, value.right);

  Rect rotateRect(Rect rect) => turns == 1
      ? Rect.fromLTWH(
          rect.top,
          media.size.width - rect.right,
          rect.height,
          rect.width,
        )
      : Rect.fromLTWH(
          media.size.height - rect.bottom,
          rect.left,
          rect.height,
          rect.width,
        );

  return media.copyWith(
    size: Size(media.size.height, media.size.width),
    padding: rotateInsets(media.padding),
    viewPadding: rotateInsets(media.viewPadding),
    viewInsets: rotateInsets(media.viewInsets),
    systemGestureInsets: rotateInsets(media.systemGestureInsets),
    displayFeatures: [
      for (final feature in media.displayFeatures)
        DisplayFeature(
          bounds: rotateRect(feature.bounds),
          type: feature.type,
          state: feature.state,
        ),
    ],
  );
}
