import 'dart:math' as math;

import '../game_state/game_state.dart';
import 'expedition_composition_formatter.dart';
import 'expedition_income_calculator.dart';
import 'expedition_models.dart';
import 'expedition_rule_catalog.dart';

export 'expedition_models.dart';

class ExpeditionEvaluator {
  const ExpeditionEvaluator();

  ExpeditionEvaluation evaluate({
    required GameState state,
    required Fleet fleet,
    required int missionId,
    int greatSuccessTarget = 100,
  }) {
    final rule = expeditionRules[missionId];
    final ships = fleet.shipIds
        .map((shipId) => state.ships[shipId])
        .whereType<OwnedShip>()
        .toList(growable: false);
    final normal = <ExpeditionConditionResult>[];
    if (rule != null) {
      for (final requirement in rule.requirements) {
        normal.addAll(_evaluateRequirement(requirement, state, ships));
      }
      normal.add(_resupply(state, ships));
    }
    final great = _greatSuccess(state, ships, missionId, greatSuccessTarget);
    return ExpeditionEvaluation(
      hasRule: rule != null,
      normalConditions: normal,
      greatSuccessConditions: great.conditions,
      greatSuccessRate: great.rate,
      greatSuccessTarget: greatSuccessTarget,
      daihatsuFill: _daihatsuFill(state, fleet, ships),
    );
  }

  List<ExpeditionConditionResult> _evaluateRequirement(
    ExpeditionRequirement requirement,
    GameState state,
    List<OwnedShip> ships,
  ) {
    final flagship = ships.isEmpty ? null : ships.first;
    switch (requirement.type) {
      case ExpeditionRequirementType.flagshipLevel:
        return [
          _result(
            ExpeditionConditionKind.flagshipLevel,
            '旗舰等级 ≥ ${requirement.value}',
            flagship?.level ?? 0,
            requirement.value,
          ),
        ];
      case ExpeditionRequirementType.shipCount:
        return [
          _result(
            ExpeditionConditionKind.shipCount,
            '舰船数量 ≥ ${requirement.value}',
            ships.length,
            requirement.value,
          ),
        ];
      case ExpeditionRequirementType.levelSum:
        return [
          _result(
            ExpeditionConditionKind.levelSum,
            '舰队等级合计 ≥ ${requirement.value}',
            ships.fold(0, (v, s) => v + s.level),
            requirement.value,
          ),
        ];
      case ExpeditionRequirementType.morale:
        final actual = ships.isEmpty
            ? 0
            : ships.map((s) => s.condition).reduce(math.min);
        return [
          _result(
            ExpeditionConditionKind.morale,
            '全员士气 ≥ ${requirement.value}',
            actual,
            requirement.value,
          ),
        ];
      case ExpeditionRequirementType.flagshipType:
        final actual = flagship == null
            ? 0
            : state.masterForShip(flagship)?.shipTypeId ?? 0;
        return [
          ExpeditionConditionResult(
            kind: ExpeditionConditionKind.flagshipType,
            label: '旗舰舰种为${formatExpeditionFlagshipType(requirement.value)}',
            actual: actual == requirement.value ? '已满足' : '未满足',
            passed: actual == requirement.value,
          ),
        ];
      case ExpeditionRequirementType.composition:
        final passed = requirement.compositions.any(
          (composition) => composition.entries.every(
            (entry) => _countType(entry.key, state, ships) >= entry.value,
          ),
        );
        return [
          ExpeditionConditionResult(
            kind: ExpeditionConditionKind.composition,
            label: _compositionLabel(requirement.compositions),
            actual: passed ? '已满足' : '未满足',
            passed: passed,
          ),
        ];
      case ExpeditionRequirementType.drumCount:
        return [
          _result(
            ExpeditionConditionKind.drumCount,
            '运输桶数量 ≥ ${requirement.value}',
            _drumCount(state, ships),
            requirement.value,
          ),
        ];
      case ExpeditionRequirementType.drumCarrierCount:
        final count = ships
            .where(
              (ship) => state
                  .equipmentForShip(ship)
                  .any((e) => e.owned.masterSlotItemId == 75),
            )
            .length;
        return [
          _result(
            ExpeditionConditionKind.drumCarrierCount,
            '携带运输桶舰船 ≥ ${requirement.value}',
            count,
            requirement.value,
          ),
        ];
      case ExpeditionRequirementType.firepower:
        final stats = requirement.compositions.isEmpty
            ? const <String, int>{}
            : requirement.compositions.first;
        return [
          if (requirement.value > 0)
            _result(
              ExpeditionConditionKind.firepower,
              '总火力 ≥ ${requirement.value}',
              ships.fold(0, (v, s) => v + s.firepower),
              requirement.value,
            ),
          if ((stats['aa'] ?? 0) > 0)
            _result(
              ExpeditionConditionKind.antiAir,
              '总对空 ≥ ${stats['aa']}',
              ships.fold(0, (v, s) => v + s.antiAir),
              stats['aa']!,
            ),
          if ((stats['asw'] ?? 0) > 0)
            _result(
              ExpeditionConditionKind.antiSub,
              '总对潜 ≥ ${stats['asw']}',
              _effectiveAntiSub(state, ships),
              stats['asw']!,
            ),
          if ((stats['los'] ?? 0) > 0)
            _result(
              ExpeditionConditionKind.lineOfSight,
              '总索敌 ≥ ${stats['los']}',
              ships.fold(0, (v, s) => v + s.lineOfSight),
              stats['los']!,
            ),
        ];
      case ExpeditionRequirementType.antiAir:
      case ExpeditionRequirementType.antiSub:
      case ExpeditionRequirementType.lineOfSight:
        return const [];
    }
  }

  ExpeditionConditionResult _resupply(GameState state, List<OwnedShip> ships) {
    final missing = ships.where((ship) {
      final master = state.masterForShip(ship);
      return master == null ||
          ship.currentFuel < master.maxFuel ||
          ship.currentAmmo < master.maxAmmo;
    }).length;
    return ExpeditionConditionResult(
      kind: ExpeditionConditionKind.resupply,
      label: '舰队完成补给',
      actual: missing == 0 ? '已补满' : '缺少 $missing 艘',
      passed: missing == 0,
    );
  }

  ({double rate, List<ExpeditionConditionResult> conditions}) _greatSuccess(
    GameState state,
    List<OwnedShip> ships,
    int id,
    int target,
  ) {
    final sparkled = ships.where((s) => s.condition >= 50).length;
    final allSparkled = ships.isNotEmpty && sparkled == ships.length;
    double rate;
    final conditions = <ExpeditionConditionResult>[];
    final drum = _greatDrum[id];
    if (drum != null) {
      final count = _drumCount(state, ships);
      final base = count >= drum.$2
          ? 40
          : drum.$1 == 0
          ? 20
          : count >= drum.$1
          ? 5
          : 0;
      rate = base == 0 ? 0 : _roundedRate(sparkled * 15 + base);
      conditions.add(
        _result(
          ExpeditionConditionKind.drumCount,
          '大成功运输桶数量 ≥ ${drum.$3}',
          count,
          drum.$3,
        ),
      );
    } else if (_flagshipGreatSuccess.contains(id)) {
      final level = ships.isEmpty ? 0 : ships.first.level;
      rate = ships.isEmpty
          ? 0
          : _roundedRate(
              sparkled * 15 + 15 + (math.sqrt(level) + level / 10).floor(),
            );
    } else {
      rate = allSparkled ? _roundedRate(ships.length * 15 + 20) : 0;
      conditions.add(
        ExpeditionConditionResult(
          kind: ExpeditionConditionKind.allSparkled,
          label: '舰队全体处于战意高昂',
          actual: allSparkled ? '已满足' : '未满足',
          passed: allSparkled,
        ),
      );
    }
    conditions.insert(
      0,
      ExpeditionConditionResult(
        kind: ExpeditionConditionKind.greatSuccessRate,
        label: '当前大成功概率 ≥ $target%',
        actual: '${rate.toStringAsFixed(2)}%',
        passed: rate >= target,
      ),
    );
    return (rate: rate, conditions: conditions);
  }

  ExpeditionConditionResult _daihatsuFill(
    GameState state,
    Fleet fleet,
    List<OwnedShip> ships,
  ) {
    const normal = <int>{68, 193};
    const related = <int>{75, 68, 166, 167, 193, 408, 409, 436, 449};
    final usedByFleets = <int>{};
    for (final otherFleet in state.fleets) {
      for (final shipId in otherFleet.shipIds) {
        final ship = state.ships[shipId];
        if (ship == null) continue;
        usedByFleets.addAll(ship.slotIds.where((id) => id > 0));
        if (ship.extraSlotId > 0) usedByFleets.add(ship.extraSlotId);
      }
    }
    final spare = state.slotItems.values.any(
      (item) =>
          normal.contains(item.masterSlotItemId) &&
          !usedByFleets.contains(item.instanceId),
    );
    final normalBonus =
        ExpeditionIncomeCalculator.daihatsuBonusBreakdownForFleet(
          state,
          fleet,
        ).normal;
    final hasExtraDaihatsuCapability = ships.any((ship) {
      final master = state.masterForShip(ship);
      if (master == null || !master.equipTypeIds.contains(24)) return false;
      final occupiedRelevantSlots = ship.slotIds.where((slotId) {
        final item = state.slotItems[slotId];
        return item != null && related.contains(item.masterSlotItemId);
      }).length;
      return master.slotCount - occupiedRelevantSlots > 0;
    });
    final passed = !spare || normalBonus >= 0.2 || !hasExtraDaihatsuCapability;
    return ExpeditionConditionResult(
      kind: ExpeditionConditionKind.daihatsuFill,
      label: '尽可能多的大发动艇或特大发动艇',
      actual: passed ? '已满足' : '未满足',
      passed: passed,
    );
  }

  static double _roundedRate(int numerator) =>
      (numerator / 0.0099).round() / 100;
  static ExpeditionConditionResult _result(
    ExpeditionConditionKind kind,
    String label,
    int actual,
    int required,
  ) => ExpeditionConditionResult(
    kind: kind,
    label: label,
    actual: '$actual / $required',
    passed: actual >= required,
  );
  static int _drumCount(GameState state, List<OwnedShip> ships) => ships.fold(
    0,
    (sum, ship) =>
        sum +
        state
            .equipmentForShip(ship)
            .where((e) => e.owned.masterSlotItemId == 75)
            .length,
  );

  static int _effectiveAntiSub(GameState state, List<OwnedShip> ships) {
    final total = ships.fold<int>(0, (sum, ship) => sum + ship.antiSub);
    final reconEquipmentAntiSub = ships.fold<int>(0, (sum, ship) {
      return sum +
          state.equipmentForShip(ship).fold<int>(0, (equipmentSum, equipment) {
            final master = equipment.master;
            final category = master != null && master.type.length > 2
                ? master.type[2]
                : 0;
            return equipmentSum +
                (const <int>{10, 11, 41}.contains(category)
                    ? master!.antiSub
                    : 0);
          });
    });
    return total - reconEquipmentAntiSub;
  }

  static int _countType(String type, GameState state, List<OwnedShip> ships) =>
      ships.where((ship) {
        final master = state.masterForShip(ship);
        if (master == null) return false;
        final id = master.shipTypeId;
        return switch (type) {
          'DE' => id == 1,
          'DD' => id == 2,
          'CL' => id == 3,
          'CA' => id == 5,
          'CVL' => id == 7,
          'BBV' => id == 10,
          'AV' => id == 16,
          'AS' => id == 20,
          'CT' => id == 21,
          'SSLike' => id == 13 || id == 14,
          'DDorDE' => id == 1 || id == 2,
          'CVLike' => id == 7 || id == 11 || id == 16 || id == 18,
          'CVE' => id == 7 && master.baseAntiSub > 0,
          _ => false,
        };
      }).length;
  static String _compositionLabel(List<Map<String, int>> variants) =>
      '舰队构成：${formatExpeditionComposition(variants)}';
}

const Set<int> _flagshipGreatSuccess = <int>{
  101,
  102,
  103,
  104,
  105,
  112,
  113,
  114,
  115,
  41,
  43,
  45,
  46,
  32,
  131,
  132,
  133,
  141,
};
const Map<int, (int, int, int)> _greatDrum = <int, (int, int, int)>{
  21: (3, 4, 4),
  24: (0, 2, 2),
  37: (4, 5, 5),
  38: (8, 10, 10),
  40: (0, 4, 4),
  44: (6, 8, 8),
  142: (4, 6, 6),
};
