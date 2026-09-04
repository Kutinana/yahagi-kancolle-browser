import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/fleet/resource_trend_data.dart';
import 'package:yahagi_kancolle_browser/src/fleet/resource_trend_sampler.dart';
import 'package:yahagi_kancolle_browser/src/logbook/logbook_database.dart';

Map<String, dynamic> row(DateTime at, int fuel, {int bucket = 100}) => {
  'timestamp': at.millisecondsSinceEpoch,
  for (final key in resourceTrendKeys)
    key: key == 'fuel'
        ? fuel
        : key == 'bucket'
        ? bucket
        : 200,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.parse('2026-09-05T18:30:00+09:00');
  test('small recent series retains every turn across a 90-day window', () {
    const values = [1000, 1200, 1050, 1190, 1000];
    final rows = List.generate(
      values.length,
      (i) => row(now.subtract(Duration(minutes: 4 - i)), values[i]),
    );
    final data = ResourceTrendData.fromRows(
      ResourceTrendWindow.at(now, 90),
      rows,
    );
    expect(data.points('fuel').map((p) => p.value).toList(), values);
  });
  test('flat observations remain inspectable below the sampling budget', () {
    final rows = List.generate(
      10,
      (i) => row(now.subtract(Duration(minutes: 9 - i)), 1000),
    );
    final data = ResourceTrendData.fromRows(
      ResourceTrendWindow.at(now, 90),
      rows,
    );
    expect(data.points('fuel').length, 10);
  });
  test(
    'sampling switches only after exceeding the budget and stays bounded',
    () {
      final window = ResourceTrendWindow.at(now, 90);
      final rows = List.generate(
        501,
        (i) => row(
          now.subtract(Duration(seconds: 500 - i)),
          i == 250 ? 90000 : 1000 + i,
          bucket: i == 251 ? 1 : 100,
        ),
      );
      expect(
        ResourceTrendData.fromRows(
          window,
          rows.take(500).toList(),
        ).points('fuel').length,
        500,
      );
      final sampled = ResourceTrendData.fromRows(window, rows);
      for (final key in resourceTrendKeys) {
        expect(sampled.points(key).length, lessThanOrEqualTo(500));
      }
      expect(sampled.points('fuel').map((p) => p.value), contains(90000));
      expect(sampled.points('bucket').map((p) => p.value), contains(1));
      expect(sampled.current('fuel'), 1500);
      expect(sampled.delta('fuel'), 500);
    },
  );
  test(
    'JST natural days are independent of machine timezone and cross years',
    () {
      expect(
        ResourceTrendWindow.at(now, 1).start,
        DateTime.utc(2026, 9, 4, 15),
      );
      expect(
        ResourceTrendWindow.at(now, 7).start,
        DateTime.utc(2026, 8, 29, 15),
      );
      expect(
        ResourceTrendWindow.at(DateTime.utc(2026, 1, 1), 30).start,
        DateTime.utc(2025, 12, 2, 15),
      );
    },
  );
  test('range totals use unsampled endpoints and real predecessor', () {
    final w = ResourceTrendWindow.at(now, 1);
    final data = ResourceTrendData.fromRows(w, [
      row(now, 1200),
      row(w.start.subtract(const Duration(minutes: 10)), 900),
      row(w.start.add(const Duration(hours: 9)), 1000),
      row(now.add(const Duration(minutes: 1)), 99999),
    ]);
    expect(data.current('fuel'), 1200);
    expect(data.delta('fuel'), 300);
    expect(data.baseline!.time, w.start.subtract(const Duration(minutes: 10)));
    expect(
      data.points('fuel').first.time,
      w.start.add(const Duration(hours: 9)),
    );
    expect(data.points('fuel').last.time, now);
  });
  test(
    'missing boundary and empty intervals never fabricate a zero change',
    () {
      final w = ResourceTrendWindow.at(now, 1);
      final single = ResourceTrendData.fromRows(w, [row(now, 1200)]);
      expect(single.delta('fuel'), isNull);
      expect(single.points('fuel'), hasLength(1));
      final stale = ResourceTrendData.fromRows(w, [
        row(w.start.subtract(const Duration(days: 2)), 900),
      ]);
      expect(stale.current('fuel'), 900);
      expect(stale.delta('fuel'), isNull);
      expect(stale.points('fuel'), isEmpty);
      final partial = ResourceTrendData.fromRows(w, [
        row(w.start.add(const Duration(hours: 2)), 1000),
        row(now, 1200),
      ]);
      expect(partial.delta('fuel'), 200);
      expect(partial.baseline!.time.isAfter(w.start), isTrue);
    },
  );
  test(
    'each resource retains its own peaks and timestamps with bounded memory',
    () {
      final w = ResourceTrendWindow.at(now, 90);
      final rows = List.generate(
        10000,
        (i) => row(
          w.start.add(Duration(minutes: i)),
          i == 4321 ? 90000 : 1000,
          bucket: i == 4322 ? 1 : 100,
        ),
      );
      final data = ResourceTrendData.fromRows(w, rows, maxPoints: 100);
      expect(data.points('fuel').map((p) => p.value), contains(90000));
      expect(data.points('bucket').map((p) => p.value), contains(1));
      expect(data.points('fuel').length, lessThanOrEqualTo(100));
      expect(
        data.points('bucket').last.time,
        DateTime.fromMillisecondsSinceEpoch(
          rows.last['timestamp'] as int,
          isUtc: true,
        ),
      );
    },
  );
  test(
    'database pages sort imported and equal-time rows by timestamp then id',
    () async {
      final db = await LogbookDatabase.openForTesting();
      addTearDown(db.close);
      final raw = await db.database;
      final w = ResourceTrendWindow.at(now, 1);
      await raw.insert('resource_logs', row(now, 1200));
      await raw.insert(
        'resource_logs',
        row(w.start.subtract(const Duration(minutes: 5)), 800),
      );
      await raw.insert(
        'resource_logs',
        row(w.start.add(const Duration(hours: 1)), 900),
      );
      await raw.insert('resource_logs', row(now, 1300));
      final rows = await db
          .streamResourceLogsByTimestamp(
            start: w.start,
            end: w.end,
            pageSize: 1,
          )
          .toList();
      expect(rows.map((r) => r['fuel']), [900, 1200, 1300]);
      final data = await loadResourceTrend(db, w);
      expect(data.current('fuel'), 1300);
      expect(data.delta('fuel'), 500);
    },
  );
}
