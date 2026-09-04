import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/fleet/resource_trend_chart.dart';
import 'package:yahagi_kancolle_browser/src/fleet/resource_trend_data.dart';

void main() {
  test('equal timestamps resolve to the last recorded value', () {
    final time = DateTime.utc(2026);
    final points = [
      ResourceTrendPoint(time, 100),
      ResourceTrendPoint(time, 200),
      ResourceTrendPoint(time.add(const Duration(hours: 1)), 300),
    ];
    expect(nearestResourceTrendPoint(points, time), 1);
    expect(
      nearestResourceTrendPoint(points, time.add(const Duration(seconds: 1))),
      1,
    );
  });
  test(
    'scale includes all values and baseline with distinct integer ticks',
    () {
      for (final values in [
        [0],
        [1, 2],
        [3000, 3001],
        [85000, 92000],
        [9999999],
      ]) {
        final scale = ResourceTrendScale.forValues(
          values,
          baseline: values.first,
        );
        expect(
          scale.min,
          lessThanOrEqualTo(values.reduce((a, b) => a < b ? a : b)),
        );
        expect(
          scale.max,
          greaterThanOrEqualTo(values.reduce((a, b) => a > b ? a : b)),
        );
        expect(scale.max, greaterThan(scale.min));
        expect(scale.ticks.toSet().length, scale.ticks.length);
        expect(scale.min, greaterThanOrEqualTo(0));
      }
    },
  );
  test('inspection uses nearest real time, not evenly spaced record index', () {
    final start = DateTime.utc(2026);
    final points = [
      ResourceTrendPoint(start, 1),
      ResourceTrendPoint(start.add(const Duration(minutes: 1)), 2),
      ResourceTrendPoint(start.add(const Duration(hours: 10)), 3),
    ];
    expect(
      nearestResourceTrendPoint(points, start.add(const Duration(minutes: 2))),
      1,
    );
    expect(
      nearestResourceTrendPoint(points, start.add(const Duration(hours: 9))),
      2,
    );
    expect(
      nearestResourceTrendPoint(
        points,
        start.subtract(const Duration(days: 1)),
      ),
      0,
    );
  });
}
