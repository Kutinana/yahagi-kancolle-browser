import 'dart:collection';

import 'development_dataset.dart';
import 'development_pool_matcher.dart';
import 'development_resources.dart';

class DevelopmentEquipmentProjection {
  DevelopmentEquipmentProjection({
    required this.equipment,
    required this.totalRate,
    required List<double> rateDetails,
  }) : rateDetails = List.unmodifiable(rateDetails);

  final DevelopmentEquipmentRecord equipment;
  final double totalRate;
  final List<double> rateDetails;

  int get id => equipment.id;
}

class DevelopmentEquipmentGroups {
  DevelopmentEquipmentGroups({
    required List<DevelopmentEquipmentProjection> targets,
    required List<DevelopmentEquipmentProjection> other,
    required List<DevelopmentEquipmentProjection> insufficient,
    required List<DevelopmentEquipmentProjection> replaced,
  }) : targets = List.unmodifiable(targets),
       other = List.unmodifiable(other),
       insufficient = List.unmodifiable(insufficient),
       replaced = List.unmodifiable(replaced);

  final List<DevelopmentEquipmentProjection> targets;
  final List<DevelopmentEquipmentProjection> other;
  final List<DevelopmentEquipmentProjection> insufficient;
  final List<DevelopmentEquipmentProjection> replaced;
}

DevelopmentEquipmentGroups projectDevelopmentEquipment({
  required Map<int, double> totals,
  required Map<int, List<double>> details,
  required Set<int> targets,
  required DevelopmentResources resources,
  required Map<int, DevelopmentEquipmentRecord> equipment,
}) {
  final targetOutput = <DevelopmentEquipmentProjection>[];
  final other = <DevelopmentEquipmentProjection>[];
  final insufficient = <DevelopmentEquipmentProjection>[];
  final replaced = <DevelopmentEquipmentProjection>[];

  for (final entry in totals.entries) {
    final item = equipment[entry.key];
    if (item == null) continue;
    final projection = DevelopmentEquipmentProjection(
      equipment: item,
      totalRate: entry.value,
      rateDetails: details[entry.key] ?? const [],
    );
    if (entry.value == 0) {
      replaced.add(projection);
    } else if (!resources.covers(item.minimumResources)) {
      insufficient.add(projection);
    } else if (targets.contains(entry.key)) {
      targetOutput.add(projection);
    } else {
      other.add(projection);
    }
  }
  return DevelopmentEquipmentGroups(
    targets: targetOutput,
    other: other,
    insufficient: insufficient,
    replaced: replaced,
  );
}

Set<int> calculateEnabledDevelopmentEquipment(
  DevelopmentDataset dataset,
  Set<int> targets,
) {
  final output = <int>{};
  final includeNegative = targets.contains(development96LandAttackerId);
  for (final selectable in dataset.selectablePools) {
    for (final type in DevelopmentPoolType.values) {
      final typeId = developmentPoolTypeId(type);
      DevelopmentPoolRecord? base;
      for (final candidate
          in dataset.poolsByName[selectable.name] ?? const []) {
        if (candidate.poolId == typeId) {
          base = candidate;
          break;
        }
      }
      if (base == null) continue;
      final rates = mergeDevelopmentDropRates(
        findCompatibleDevelopmentPools(dataset.pools, base, type),
        includeNegative: includeNegative,
      );
      if (developmentPoolAdmits(rates, targets)) output.addAll(rates.keys);
    }
  }
  return UnmodifiableSetView(output);
}
