import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/layout/window_metrics_recovery_scheduler.dart';

void main() {
  testWidgets('rapid resizing cancels all superseded recovery generations', (
    tester,
  ) async {
    final scheduler = WindowMetricsRecoveryScheduler();
    addTearDown(scheduler.dispose);
    var current = 0;
    final applied = <int>[];
    for (var i = 0; i < 250; i++) {
      current = i;
      scheduler.schedule(() {
        expectSync(
          i,
          current,
          reason: 'Old dimensions must not restore over the latest window',
        );
        applied.add(i);
      });
      await tester.pump(const Duration(milliseconds: 5));
    }
    expect(applied, isEmpty);
    await tester.pump(const Duration(seconds: 2));
    expect(applied, [249, 249, 249, 249]);
    scheduler.schedule(() => applied.add(-1));
    scheduler.cancel();
    await tester.pump(const Duration(seconds: 2));
    expect(applied, [249, 249, 249, 249]);
  });
  testWidgets('rechecks the latest foldable window metrics until stable', (
    tester,
  ) async {
    final scheduler = WindowMetricsRecoveryScheduler();
    addTearDown(scheduler.dispose);
    var firstGenerationRuns = 0;
    var latestGenerationRuns = 0;

    scheduler.schedule(() => firstGenerationRuns += 1);
    await tester.pump(const Duration(milliseconds: 50));
    expect(firstGenerationRuns, 1);
    scheduler.schedule(() => latestGenerationRuns += 1);

    await tester.pump(const Duration(milliseconds: 1));
    expect(firstGenerationRuns, 1);
    expect(
      latestGenerationRuns,
      0,
      reason: 'surface recovery must not run in the scheduling frame',
    );

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 450));

    expect(firstGenerationRuns, 1);
    expect(latestGenerationRuns, 4);
  });

  testWidgets('does not run delayed recovery after disposal', (tester) async {
    final scheduler = WindowMetricsRecoveryScheduler();
    var runs = 0;

    scheduler.schedule(() => runs += 1);
    await tester.pump(const Duration(milliseconds: 1));
    expect(runs, 0);

    scheduler.dispose();
    await tester.pump(const Duration(seconds: 1));
    expect(runs, 0);
  });

  testWidgets('cancels pending recovery when an IME transition starts', (
    tester,
  ) async {
    final scheduler = WindowMetricsRecoveryScheduler();
    addTearDown(scheduler.dispose);
    var runs = 0;

    scheduler.schedule(() => runs += 1);
    scheduler.cancel();
    await tester.pump(const Duration(seconds: 1));

    expect(runs, 0);
  });
}
