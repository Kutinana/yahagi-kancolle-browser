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

/// Classifies a sequence of window metric updates without treating temporary
/// foldable IME geometry as a real layout change.
final class WindowMetricsChangeTracker {
  WindowMetricsChangeTracker(WindowMetricsSnapshot initial)
    : _previous = initial,
      _stableGeometry = initial;

  WindowMetricsSnapshot _previous;
  WindowMetricsSnapshot _stableGeometry;
  WindowMetricsSnapshot? _preImeGeometry;

  bool get isImeVisible => _previous.imeBottom > 0;

  WindowMetricsChange update(WindowMetricsSnapshot current) {
    final previous = _previous;
    _previous = current;

    final wasImeVisible = previous.imeBottom > 0;
    final isImeVisible = current.imeBottom > 0;
    if (isImeVisible) {
      _preImeGeometry ??= _stableGeometry;
      return WindowMetricsChange.imeOnly;
    }

    final preImeGeometry = _preImeGeometry;
    if (wasImeVisible || preImeGeometry != null) {
      _preImeGeometry = null;
      if (preImeGeometry != null &&
          _hasGeometryChanged(preImeGeometry, current)) {
        return WindowMetricsChange.geometry;
      }
      return WindowMetricsChange.imeOnly;
    }

    return classifyWindowMetricsChange(previous, current);
  }

  /// Confirms that the latest non-IME geometry has reached the recovery pass.
  void markCurrentGeometryStable() {
    if (_previous.imeBottom == 0) {
      _stableGeometry = _previous;
    }
  }
}

WindowMetricsChange classifyWindowMetricsChange(
  WindowMetricsSnapshot previous,
  WindowMetricsSnapshot current,
) {
  if (previous.imeBottom != current.imeBottom) {
    return WindowMetricsChange.imeOnly;
  }
  if (previous.physicalSize != current.physicalSize ||
      previous.devicePixelRatio != current.devicePixelRatio) {
    return WindowMetricsChange.geometry;
  }
  return WindowMetricsChange.unchanged;
}

bool _hasGeometryChanged(
  WindowMetricsSnapshot previous,
  WindowMetricsSnapshot current,
) {
  return previous.physicalSize != current.physicalSize ||
      previous.devicePixelRatio != current.devicePixelRatio;
}
