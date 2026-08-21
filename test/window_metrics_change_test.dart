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
}
