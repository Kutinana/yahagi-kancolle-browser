import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/diagnostics/diagnostic_performance_monitor.dart';

void main() {
  test('frame window aggregates without retaining frames', () {
    final window = DiagnosticFrameWindow();
    window
      ..add(const Duration(milliseconds: 12))
      ..add(const Duration(milliseconds: 40))
      ..add(const Duration(milliseconds: 140));

    final snapshot = window.takeSnapshot();

    expect(snapshot.totalFrames, 3);
    expect(snapshot.over16Ms, 2);
    expect(snapshot.over33Ms, 2);
    expect(snapshot.over100Ms, 1);
    expect(snapshot.maxFrameMicros, 140000);
    expect(window.takeSnapshot().totalFrames, 0);
  });
}
