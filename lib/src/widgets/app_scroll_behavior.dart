import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Lets a connected mouse drag UI lists like touch input on a tablet.
/// WebView input and mouse-wheel routing are handled separately.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    ...super.dragDevices,
    PointerDeviceKind.mouse,
  };
}
