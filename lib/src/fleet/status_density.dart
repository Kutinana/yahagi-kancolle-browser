import 'package:flutter/widgets.dart';

import '../layout/adaptive_layout.dart';
import '../settings/display_mode_store.dart';

/// 手机紧凑密度：以屏幕短边判断，竖屏/横屏手机都会命中；
/// 平板与展开的折叠屏短边足够大（>=600dp），保持完整布局不变。
bool isPhoneDensity(BuildContext context) {
  return classifyAdaptiveWindow(MediaQuery.sizeOf(context)) ==
      AdaptiveWindowClass.compact;
}

bool isNearSquareLargeDisplay(BuildContext context) {
  return classifyAdaptiveWindow(MediaQuery.sizeOf(context)) ==
      AdaptiveWindowClass.nearSquareLarge;
}

bool usesCompactFleetLayout(BuildContext context, [DisplayMode? mode]) {
  final size = MediaQuery.sizeOf(context);
  final orientation = MediaQuery.orientationOf(context);
  final effectiveMode = mode ??
      (orientation == Orientation.portrait
          ? DisplayMode.portrait
          : (orientation == Orientation.landscape
              ? DisplayMode.landscape
              : DisplayMode.auto));
  return classifyAdaptiveWindow(size) == AdaptiveWindowClass.compact ||
      usesVerticalWorkspace(size, effectiveMode);
}
