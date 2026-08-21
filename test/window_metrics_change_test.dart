import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/layout/window_metrics_change.dart';

void main() {
  const original = WindowMetricsSnapshot(
    physicalSize: Size(1080, 2400),
    devicePixelRatio: 3,
    imeBottom: 0,
  );

  test('classifies equal metrics as unchanged', () {
    expect(
      classifyWindowMetricsChange(original, original),
      WindowMetricsChange.unchanged,
    );
  });

  test('classifies an IME inset-only transition without geometry recovery', () {
    const keyboardOpen = WindowMetricsSnapshot(
      physicalSize: Size(1080, 2400),
      devicePixelRatio: 3,
      imeBottom: 900,
    );

    expect(
      classifyWindowMetricsChange(original, keyboardOpen),
      WindowMetricsChange.imeOnly,
    );
    expect(
      classifyWindowMetricsChange(keyboardOpen, original),
      WindowMetricsChange.imeOnly,
    );
  });

  test(
    'IME transitions take precedence over simultaneous geometry changes',
    () {
      const foldableKeyboardOpen = WindowMetricsSnapshot(
        physicalSize: Size(1768, 2208),
        devicePixelRatio: 2.625,
        imeBottom: 840,
      );

      expect(
        classifyWindowMetricsChange(original, foldableKeyboardOpen),
        WindowMetricsChange.imeOnly,
      );
      expect(
        classifyWindowMetricsChange(foldableKeyboardOpen, original),
        WindowMetricsChange.imeOnly,
      );
    },
  );

  test('classifies physical size and DPR transitions as geometry changes', () {
    expect(
      classifyWindowMetricsChange(
        original,
        const WindowMetricsSnapshot(
          physicalSize: Size(2400, 1080),
          devicePixelRatio: 3,
          imeBottom: 0,
        ),
      ),
      WindowMetricsChange.geometry,
    );
    expect(
      classifyWindowMetricsChange(
        original,
        const WindowMetricsSnapshot(
          physicalSize: Size(1080, 2400),
          devicePixelRatio: 2.75,
          imeBottom: 0,
        ),
      ),
      WindowMetricsChange.geometry,
    );
  });

  test(
    'suppresses foldable geometry fluctuations for the whole IME session',
    () {
      const unfolded = WindowMetricsSnapshot(
        physicalSize: Size(1768, 2208),
        devicePixelRatio: 2.625,
        imeBottom: 0,
      );
      final tracker = WindowMetricsChangeTracker(unfolded);

      expect(
        tracker.update(
          const WindowMetricsSnapshot(
            physicalSize: Size(1768, 2176),
            devicePixelRatio: 2.625,
            imeBottom: 840,
          ),
        ),
        WindowMetricsChange.imeOnly,
      );
      expect(
        tracker.update(
          const WindowMetricsSnapshot(
            physicalSize: Size(1768, 2144),
            devicePixelRatio: 2.625,
            imeBottom: 840,
          ),
        ),
        WindowMetricsChange.imeOnly,
      );
      expect(tracker.update(unfolded), WindowMetricsChange.imeOnly);
    },
  );

  test('recovers a real geometry change after the IME closes', () {
    const unfolded = WindowMetricsSnapshot(
      physicalSize: Size(1768, 2208),
      devicePixelRatio: 2.625,
      imeBottom: 0,
    );
    final tracker = WindowMetricsChangeTracker(unfolded);

    tracker.update(
      const WindowMetricsSnapshot(
        physicalSize: Size(1768, 2176),
        devicePixelRatio: 2.625,
        imeBottom: 840,
      ),
    );
    tracker.update(
      const WindowMetricsSnapshot(
        physicalSize: Size(2208, 1768),
        devicePixelRatio: 2.625,
        imeBottom: 840,
      ),
    );

    expect(
      tracker.update(
        const WindowMetricsSnapshot(
          physicalSize: Size(2208, 1768),
          devicePixelRatio: 2.625,
          imeBottom: 0,
        ),
      ),
      WindowMetricsChange.geometry,
    );
  });

  test(
    'uses stable geometry when a size event arrives just before the IME',
    () {
      const unfolded = WindowMetricsSnapshot(
        physicalSize: Size(1768, 2208),
        devicePixelRatio: 2.625,
        imeBottom: 0,
      );
      final tracker = WindowMetricsChangeTracker(unfolded);

      expect(
        tracker.update(
          const WindowMetricsSnapshot(
            physicalSize: Size(1768, 2176),
            devicePixelRatio: 2.625,
            imeBottom: 0,
          ),
        ),
        WindowMetricsChange.geometry,
      );
      expect(
        tracker.update(
          const WindowMetricsSnapshot(
            physicalSize: Size(1768, 2176),
            devicePixelRatio: 2.625,
            imeBottom: 840,
          ),
        ),
        WindowMetricsChange.imeOnly,
      );

      expect(tracker.update(unfolded), WindowMetricsChange.imeOnly);
    },
  );
}
