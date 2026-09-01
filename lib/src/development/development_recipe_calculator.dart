import 'development_dataset.dart';
import 'development_pool_matcher.dart';
import 'development_resources.dart';

class DevelopmentRecipeResult {
  const DevelopmentRecipeResult({
    required this.poolKey,
    required this.poolType,
    required this.resources,
    required this.targetRate,
    required this.failureRate,
  });

  final String poolKey;
  final DevelopmentPoolType poolType;
  final DevelopmentResources resources;
  final double targetRate;
  final double failureRate;

  int get totalResources => resources.total;
}

List<DevelopmentResources> deriveMinimumRecipes(
  DevelopmentPoolType poolType,
  Set<int> targets,
  Map<int, DevelopmentEquipmentRecord> equipment,
) {
  var base = const DevelopmentResources(10, 10, 10, 10);
  if (targets.contains(development96LandAttackerId)) {
    base = const DevelopmentResources(240, 260, 10, 250);
  }
  base = DevelopmentResources.maxima([
    base,
    for (final target in targets)
      if (equipment[target] case final item?) item.minimumResources,
  ]);

  switch (poolType) {
    case DevelopmentPoolType.bauxite:
      final dominant = [
        base.fuel,
        base.ammo,
        base.steel,
      ].reduce((left, right) => left > right ? left : right);
      return [
        DevelopmentResources(
          base.fuel,
          base.ammo,
          base.steel,
          base.bauxite > dominant ? base.bauxite : dominant + 1,
        ),
      ];
    case DevelopmentPoolType.ammunition:
      final fuelSteel = base.fuel > base.steel ? base.fuel : base.steel;
      var ammo = base.ammo > fuelSteel ? base.ammo : fuelSteel + 1;
      if (ammo < base.bauxite) ammo = base.bauxite;
      return [DevelopmentResources(base.fuel, ammo, base.steel, base.bauxite)];
    case DevelopmentPoolType.fuelSteel:
      final oilDominant = base.fuel >= base.ammo && base.fuel >= base.bauxite;
      final steelDominant =
          base.steel >= base.ammo && base.steel >= base.bauxite;
      if (oilDominant || steelDominant) return [base];
      final ammoBauxite = base.ammo > base.bauxite ? base.ammo : base.bauxite;
      return [
        DevelopmentResources(ammoBauxite, base.ammo, base.steel, base.bauxite),
        DevelopmentResources(base.fuel, base.ammo, ammoBauxite, base.bauxite),
      ];
  }
}

DevelopmentRecipeResult evaluateDevelopmentRecipe({
  required String poolKey,
  required DevelopmentPoolType poolType,
  required DevelopmentResources resources,
  required Map<int, double> dropRates,
  required Set<int> targets,
  required Map<int, DevelopmentEquipmentRecord> equipment,
}) {
  var targetRate = 0.0;
  var otherRate = 0.0;
  for (final entry in dropRates.entries) {
    if (targets.contains(entry.key)) {
      targetRate += entry.value;
      continue;
    }
    final item = equipment[entry.key];
    if (item != null && resources.covers(item.minimumResources)) {
      otherRate += entry.value;
    }
  }
  return DevelopmentRecipeResult(
    poolKey: poolKey,
    poolType: poolType,
    resources: resources,
    targetRate: targetRate,
    failureRate: 100 - targetRate - otherRate,
  );
}

List<DevelopmentRecipeResult> calculateDevelopmentRecipes(
  DevelopmentDataset dataset,
  Set<int> targets,
) {
  if (targets.isEmpty) return const [];
  final includeNegative = targets.contains(development96LandAttackerId);
  final output = <DevelopmentRecipeResult>[];

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
      final compatible = findCompatibleDevelopmentPools(
        dataset.pools,
        base,
        type,
      );
      final rates = mergeDevelopmentDropRates(
        compatible,
        includeNegative: includeNegative,
      );
      if (!developmentPoolAdmits(rates, targets)) continue;
      for (final resources in deriveMinimumRecipes(
        type,
        targets,
        dataset.equipment,
      )) {
        output.add(
          evaluateDevelopmentRecipe(
            poolKey: base.key,
            poolType: type,
            resources: resources,
            dropRates: rates,
            targets: targets,
            equipment: dataset.equipment,
          ),
        );
      }
    }
  }
  return sortDevelopmentRecipes(output);
}

List<DevelopmentRecipeResult> sortDevelopmentRecipes(
  Iterable<DevelopmentRecipeResult> results,
) {
  final sorted = results.toList();
  sorted.sort((left, right) {
    if (left.targetRate != right.targetRate) {
      return right.targetRate.compareTo(left.targetRate);
    }
    if ((left.totalResources - right.totalResources).abs() > 1) {
      return left.totalResources.compareTo(right.totalResources);
    }
    return right.failureRate.compareTo(left.failureRate);
  });
  return sorted;
}
