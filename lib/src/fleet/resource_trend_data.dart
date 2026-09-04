import '../logbook/logbook_database.dart';
import 'resource_trend_sampler.dart';

DateTime resourceTrendJst(DateTime instant) =>
    instant.toUtc().add(const Duration(hours: 9));

class ResourceTrendWindow {
  const ResourceTrendWindow(this.start, this.end, this.days);

  factory ResourceTrendWindow.at(DateTime now, int days) {
    assert([1, 7, 30, 90].contains(days));
    final local = resourceTrendJst(now);
    final start = DateTime.utc(
      local.year,
      local.month,
      local.day,
    ).subtract(Duration(days: days - 1, hours: 9));
    return ResourceTrendWindow(start, now.toUtc(), days);
  }

  final DateTime start;
  final DateTime end;
  final int days;
}

class ResourceTrendSnapshot {
  ResourceTrendSnapshot(Map<String, dynamic> row)
    : time = DateTime.fromMillisecondsSinceEpoch(
        (row['timestamp'] as num).toInt(),
        isUtc: true,
      ),
      values = {
        for (final key in resourceTrendKeys) key: (row[key] as num).toInt(),
      };

  final DateTime time;
  final Map<String, int> values;
  int value(String key) => values[key]!;

  static ResourceTrendSnapshot? parse(Map<String, dynamic> row) {
    if (row['timestamp'] is! num ||
        !resourceTrendKeys.every(
          (key) => row[key] is num && (row[key] as num) >= 0,
        )) {
      return null;
    }
    return ResourceTrendSnapshot(row);
  }
}

class ResourceTrendPoint {
  const ResourceTrendPoint(this.time, this.value);
  final DateTime time;
  final int value;
}

class ResourceTrendData {
  ResourceTrendData._(
    this.window,
    this.baseline,
    this.latest,
    this.recordCount,
    this._series,
  );

  factory ResourceTrendData.fromRows(
    ResourceTrendWindow window,
    List<Map<String, dynamic>> rows, {
    int maxPoints = 500,
  }) {
    final sorted = rows.indexed.toList()
      ..sort((a, b) {
        final byTime = ((a.$2['timestamp'] as num?) ?? 0).compareTo(
          (b.$2['timestamp'] as num?) ?? 0,
        );
        return byTime != 0
            ? byTime
            : ((a.$2['id'] as num?) ?? a.$1).compareTo(
                (b.$2['id'] as num?) ?? b.$1,
              );
      });
    final builder = _TrendBuilder(window, maxPoints);
    for (final pair in sorted) {
      final snapshot = ResourceTrendSnapshot.parse(pair.$2);
      if (snapshot != null && !snapshot.time.isAfter(window.end)) {
        builder.add(snapshot);
      }
    }
    return builder.finish();
  }

  final ResourceTrendWindow window;
  final ResourceTrendSnapshot? baseline;
  final ResourceTrendSnapshot? latest;
  final int recordCount;
  final Map<String, List<ResourceTrendPoint>> _series;

  int? current(String key) => latest?.value(key);
  int? delta(String key) =>
      recordCount == 0 ||
          baseline == null ||
          (recordCount == 1 && identical(baseline, latest))
      ? null
      : latest!.value(key) - baseline!.value(key);
  List<ResourceTrendPoint> points(String key) => _series[key]!;
}

Future<ResourceTrendData> loadResourceTrend(
  LogbookDatabase database,
  ResourceTrendWindow window, {
  int maxPoints = 500,
}) async {
  final builder = _TrendBuilder(window, maxPoints);
  final row = await database.getResourceSnapshotAtOrBefore(window.start);
  if (row != null) {
    final snapshot = ResourceTrendSnapshot.parse(row);
    // Exact-boundary records are included in the stream, not twice.
    if (snapshot != null && snapshot.time.isBefore(window.start)) {
      builder.add(snapshot);
    }
  }
  await for (final row in database.streamResourceLogsByTimestamp(
    start: window.start,
    end: window.end,
  )) {
    final snapshot = ResourceTrendSnapshot.parse(row);
    if (snapshot != null) builder.add(snapshot);
  }
  return builder.finish();
}

class _TrendBuilder {
  _TrendBuilder(this.window, int maxPoints)
    : samplers = {
        for (final key in resourceTrendKeys)
          key: _ExtremaSampler(window, maxPoints.clamp(6, 2000)),
      };
  final ResourceTrendWindow window;
  final Map<String, _ExtremaSampler> samplers;
  ResourceTrendSnapshot? baseline;
  ResourceTrendSnapshot? latest;
  int count = 0;

  void add(ResourceTrendSnapshot row) {
    latest = row;
    if (row.time.isBefore(window.start)) {
      baseline = row;
      return;
    }
    baseline ??= row;
    count++;
    for (final key in resourceTrendKeys) {
      samplers[key]!.add(ResourceTrendPoint(row.time, row.value(key)));
    }
  }

  ResourceTrendData finish() => ResourceTrendData._(
    window,
    baseline,
    latest,
    count,
    {for (final key in resourceTrendKeys) key: samplers[key]!.finish()},
  );
}

/// Two extrema per time bucket, independently for each material. A large fuel
/// swing must not hide a small but important bucket/screw change. Endpoints
/// and chronological positions are retained; storage never grows with row count.
class _ExtremaSampler {
  _ExtremaSampler(this.window, this.maxPoints) : buckets = (maxPoints - 2) ~/ 2;
  final ResourceTrendWindow window;
  final int maxPoints;
  final int buckets;
  final List<ResourceTrendPoint> kept = [];
  // Keep small series lossless. The parallel extrema stream lets us discard
  // this bounded buffer as soon as the budget is exceeded, without rereading DB.
  List<ResourceTrendPoint>? _original = [];
  ResourceTrendPoint? first, last, minimum, maximum;
  int activeBucket = -1, sequence = 0, minSequence = 0, maxSequence = 0;

  void add(ResourceTrendPoint point) {
    final original = _original;
    if (original != null) {
      if (original.length < maxPoints) {
        original.add(point);
      } else {
        _original = null;
      }
    }
    first ??= point;
    last = point;
    final duration = window.end
        .difference(window.start)
        .inMilliseconds
        .clamp(1, 1 << 53);
    final bucket =
        (point.time.difference(window.start).inMilliseconds *
                buckets ~/
                duration)
            .clamp(0, buckets - 1);
    if (bucket != activeBucket) {
      flush();
      activeBucket = bucket;
      minimum = maximum = point;
      minSequence = maxSequence = sequence;
    } else {
      if (point.value < minimum!.value) {
        minimum = point;
        minSequence = sequence;
      }
      if (point.value >= maximum!.value) {
        maximum = point;
        maxSequence = sequence;
      }
    }
    sequence++;
  }

  void flush() {
    if (minimum == null) return;
    if (minSequence <= maxSequence) {
      kept.add(minimum!);
      if (!identical(minimum, maximum)) kept.add(maximum!);
    } else {
      kept.add(maximum!);
      kept.add(minimum!);
    }
  }

  List<ResourceTrendPoint> finish() {
    if (_original != null) return List.unmodifiable(_original!);
    flush();
    if (first == null) return const [];
    if (!identical(kept.first, first)) kept.insert(0, first!);
    if (!identical(kept.last, last)) kept.add(last!);
    return List.unmodifiable(kept);
  }
}
