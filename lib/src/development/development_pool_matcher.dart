import 'dart:collection';

import 'development_dataset.dart';
import 'development_resources.dart';

const development96LandAttackerId = 168;

DevelopmentPoolType selectDevelopmentPoolType(DevelopmentResources resources) {
  if (resources.bauxite > resources.fuel &&
      resources.bauxite > resources.ammo &&
      resources.bauxite > resources.steel) {
    return DevelopmentPoolType.bauxite;
  }
  if (resources.ammo > resources.fuel && resources.ammo > resources.steel) {
    return DevelopmentPoolType.ammunition;
  }
  return DevelopmentPoolType.fuelSteel;
}

int developmentPoolTypeId(DevelopmentPoolType type) => switch (type) {
  DevelopmentPoolType.bauxite => 1,
  DevelopmentPoolType.ammunition => 2,
  DevelopmentPoolType.fuelSteel => 3,
};

List<DevelopmentPoolRecord> findCompatibleDevelopmentPools(
  Iterable<DevelopmentPoolRecord> pools,
  DevelopmentPoolRecord basePool,
  DevelopmentPoolType type, {
  DevelopmentResources? resources,
}) {
  final typeId = developmentPoolTypeId(type);
  return pools
      .where((candidate) {
        if (candidate.poolId.abs() != typeId) return false;
        if (!candidate.shipIdSet.containsAll(basePool.shipIdSet)) return false;
        final minimum = candidate.minimumResources;
        if (resources != null &&
            minimum != null &&
            !resources.covers(minimum)) {
          return false;
        }
        return true;
      })
      .toList(growable: false);
}

List<DevelopmentPoolRecord> sortCompatibleDevelopmentPools(
  Iterable<DevelopmentPoolRecord> pools,
) {
  final sorted = pools.toList();
  sorted.sort((left, right) {
    final byWidth = right.shipIds.length.compareTo(left.shipIds.length);
    if (byWidth != 0) return byWidth;
    final byRateCount = right.dropRates.length.compareTo(left.dropRates.length);
    if (byRateCount != 0) return byRateCount;
    return left.key.compareTo(right.key);
  });
  return sorted;
}

Map<int, double> mergeDevelopmentDropRates(
  Iterable<DevelopmentPoolRecord> compatible, {
  required bool includeNegative,
}) {
  final result = <int, double>{};
  for (final pool in compatible) {
    if (includeNegative || pool.poolId > 0) {
      for (final entry in pool.dropRates.entries) {
        result.update(
          entry.key,
          (value) => value + entry.value,
          ifAbsent: () => entry.value,
        );
      }
    } else {
      for (final id in pool.dropRates.keys) {
        result.putIfAbsent(id, () => 0);
      }
    }
  }
  return result;
}

bool developmentPoolAdmits(Map<int, double> dropRates, Iterable<int> targets) =>
    targets.every((target) => (dropRates[target] ?? 0) > 0);

class DevelopmentRatesResult {
  DevelopmentRatesResult({
    required Map<int, double> totals,
    required Map<int, List<double>> details,
    required List<DevelopmentPoolRecord> compatiblePools,
  }) : totals = UnmodifiableMapView(totals),
       details = UnmodifiableMapView(
         details.map((key, value) => MapEntry(key, List.unmodifiable(value))),
       ),
       compatiblePools = List.unmodifiable(compatiblePools);

  final Map<int, double> totals;
  final Map<int, List<double>> details;
  final List<DevelopmentPoolRecord> compatiblePools;
}

DevelopmentRatesResult calculateDevelopmentRates(
  DevelopmentDataset dataset,
  DevelopmentPoolRecord basePool,
  DevelopmentResources resources,
) {
  final type = selectDevelopmentPoolType(resources);
  final compatible = sortCompatibleDevelopmentPools(
    findCompatibleDevelopmentPools(
      dataset.pools,
      basePool,
      type,
      resources: resources,
    ),
  );
  final details = <int, List<double>>{};
  for (var poolIndex = 0; poolIndex < compatible.length; poolIndex++) {
    for (final entry in compatible[poolIndex].dropRates.entries) {
      final values = details.putIfAbsent(
        entry.key,
        () => poolIndex > 0 ? <double>[0] : <double>[],
      );
      values.add(entry.value);
    }
  }
  final totals = <int, double>{
    for (final entry in details.entries)
      entry.key: entry.value.fold(0, (total, rate) => total + rate),
  };
  return DevelopmentRatesResult(
    totals: totals,
    details: details,
    compatiblePools: compatible,
  );
}
