import 'dart:ui';

enum WindowMetricsChange { unchanged, imeOnly, geometry }

final class WindowMetricsSnapshot {
  const WindowMetricsSnapshot({
    required this.physicalSize,
    required this.devicePixelRatio,
    required this.imeBottom,
  });

  factory WindowMetricsSnapshot.fromView(FlutterView view) {
    return WindowMetricsSnapshot(
      physicalSize: view.physicalSize,
      devicePixelRatio: view.devicePixelRatio,
      imeBottom: view.viewInsets.bottom,
    );
  }

  final Size physicalSize;
  final double devicePixelRatio;
  final double imeBottom;
}

WindowMetricsChange classifyWindowMetricsChange(
  WindowMetricsSnapshot previous,
  WindowMetricsSnapshot current,
) {
  if (previous.physicalSize != current.physicalSize ||
      previous.devicePixelRatio != current.devicePixelRatio) {
    return WindowMetricsChange.geometry;
  }
  if (previous.imeBottom != current.imeBottom) {
    return WindowMetricsChange.imeOnly;
  }
  return WindowMetricsChange.unchanged;
}
