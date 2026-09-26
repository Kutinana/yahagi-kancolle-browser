import 'dart:math' as math;
import 'package:flutter/widgets.dart';

bool usesHdLandscape(Size window, {required bool enabled}) =>
    enabled && window.width > window.height;

/// Workspace excludes the app header and navigation. Reserve a useful bottom
/// row even on wide windows; never crop or distort the game surface.
class HdWorkspaceGeometry {
  const HdWorkspaceGeometry(
    this.gameWidth,
    this.gameHeight,
    this.panelWidth,
    this.bottomHeight,
  );
  final double gameWidth;
  final double gameHeight;
  final double panelWidth;
  final double bottomHeight;

  static HdWorkspaceGeometry forSize(Size size, {double? gameAreaRatio}) {
    final minBottom = math.min(120.0, math.max(0.0, size.height) * .45);
    final divider = math.min(1.0, math.max(0.0, size.width));
    final availableWidth = math.max(0.0, size.width - divider);
    final width = gameAreaRatio == null
        ? math.min(
            math.max(availableWidth * .5, availableWidth - 300),
            (size.height - minBottom) * 5 / 3,
          )
        : availableWidth * gameAreaRatio.clamp(.5, .75);
    // Manual ratios control the panel exactly. The game itself remains fitted
    // at 5:3 inside this viewport when the bottom row limits available height.
    final height = math.min(width * 3 / 5, size.height - minBottom);
    return HdWorkspaceGeometry(
      width,
      height,
      size.width - divider - width,
      size.height - height,
    );
  }
}
