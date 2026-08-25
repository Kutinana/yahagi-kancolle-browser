import 'dart:math' as math;

import '../game_state/game_state.dart';

class LandBaseAirPowerResult {
  const LandBaseAirPowerResult({required this.minimum, required this.maximum});

  final int minimum;
  final int maximum;

  String get displayValue => minimum == maximum ? '$minimum' : '$minimum+';
}

abstract final class LandBaseAirPower {
  static const List<int> _experienceLowerBounds = <int>[
    0,
    10,
    25,
    40,
    55,
    70,
    85,
    100,
  ];
  static const List<int> _experienceUpperBounds = <int>[
    9,
    24,
    39,
    54,
    69,
    84,
    99,
    120,
  ];
  static const List<int> _fighterBonuses = <int>[0, 0, 2, 5, 9, 14, 14, 22];
  static const List<int> _seaplaneBomberBonuses = <int>[0, 1, 1, 1, 1, 3, 3, 6];
  static const Set<int> _airPowerTypes = <int>{
    6,
    7,
    8,
    11,
    26,
    45,
    47,
    48,
    53,
    56,
    57,
    58,
  };
  static const Set<int> _reconTypes = <int>{9, 10, 41, 49};
  static const Map<int, double> _improvementFactors = <int, double>{
    6: 0.2,
    41: 0.15,
    45: 0.2,
    47: 0.5,
    48: 0.2,
    49: 0.2,
    53: 0.5,
    56: 0.2,
  };
  static const Set<int> _sqrtImprovementTypes = <int>{47, 53};
  static const Map<int, double> _improvementFactorsById = <int, double>{
    486: 0.3,
    487: 0.3,
  };
  static const Set<int> _fighterBomberIds = <int>{60, 154, 219, 447};

  static LandBaseAirPowerResult calculate({
    required GameState state,
    required LandBaseState base,
  }) {
    var minimum = 0;
    var maximum = 0;
    var reconMultiplier = 1.0;

    for (final squadron in base.squadrons) {
      if (squadron.state != 1 || squadron.currentCount < 1) continue;
      final owned = state.slotItems[squadron.slotItemId];
      final master = owned == null
          ? null
          : state.masterSlotItems[owned.masterSlotItemId];
      if (owned == null || master == null) continue;
      final typeId = master.type.length > 2 ? master.type[2] : -1;

      if (_reconTypes.contains(typeId)) {
        final multiplier = _reconMultiplier(
          typeId: typeId,
          lineOfSight: master.lineOfSight,
          actionKind: base.actionKind,
        );
        reconMultiplier = math.max(reconMultiplier, multiplier);
      }

      final slot = _slotAirPower(
        master: master,
        owned: owned,
        count: squadron.currentCount,
        actionKind: base.actionKind,
      );
      if (slot != null) {
        minimum += slot.minimum;
        maximum += slot.maximum;
      }
    }

    return LandBaseAirPowerResult(
      minimum: (minimum * reconMultiplier).floor(),
      maximum: (maximum * reconMultiplier).floor(),
    );
  }

  static ({int minimum, int maximum})? _slotAirPower({
    required MasterSlotItem master,
    required OwnedSlotItem owned,
    required int count,
    required int actionKind,
  }) {
    final typeId = master.type.length > 2 ? master.type[2] : -1;
    if (!_countsTowardsAirPower(
      typeId: typeId,
      antiAir: master.antiAir,
      actionKind: actionKind,
    )) {
      return null;
    }

    final proficiency = owned.proficiency.clamp(0, 7).toInt();
    final effectiveAntiAir =
        master.antiAir +
        _improvementAntiAir(master, owned.level) +
        _interceptionBonus(master, actionKind);

    final typeBonus = switch (typeId) {
      6 || 26 || 45 || 48 || 56 => _fighterBonuses[proficiency],
      11 => _seaplaneBomberBonuses[proficiency],
      _ => 0,
    };
    final baseValue = math.sqrt(count) * effectiveAntiAir + typeBonus;
    final minimum =
        baseValue + math.sqrt(_experienceLowerBounds[proficiency] / 10);
    final maximum =
        baseValue + math.sqrt(_experienceUpperBounds[proficiency] / 10);
    return (minimum: minimum.floor(), maximum: maximum.floor());
  }

  static bool _countsTowardsAirPower({
    required int typeId,
    required int antiAir,
    required int actionKind,
  }) {
    if (typeId == 26) return antiAir > 0;
    if (_airPowerTypes.contains(typeId)) return true;
    return typeId != 9 &&
        _reconTypes.contains(typeId) &&
        (actionKind == 1 || actionKind == 2);
  }

  static double _improvementAntiAir(MasterSlotItem master, int level) {
    if (level <= 0) return 0;
    final idFactor = _improvementFactorsById[master.id];
    if (idFactor != null) return idFactor * level;

    final typeId = master.type.length > 2 ? master.type[2] : -1;
    final typeFactor = _improvementFactors[typeId];
    if (typeFactor != null) {
      final levelValue = _sqrtImprovementTypes.contains(typeId)
          ? math.sqrt(level)
          : level;
      return typeFactor * levelValue;
    }
    return _fighterBomberIds.contains(master.id) ? 0.25 * level : 0;
  }

  static double _interceptionBonus(MasterSlotItem master, int actionKind) {
    final typeId = master.type.length > 2 ? master.type[2] : -1;
    if (typeId != 48) return 0;
    if (actionKind == 1) return 1.5 * master.interception;
    if (actionKind == 2) {
      return (master.interception + 2 * master.antiBomber).toDouble();
    }
    return 0;
  }

  static double _reconMultiplier({
    required int typeId,
    required int lineOfSight,
    required int actionKind,
  }) {
    final tier = (lineOfSight - 7).clamp(0, 2);
    if (actionKind == 1) {
      return typeId == 49 ? 1.12 + tier * 0.03 : 1;
    }
    if (actionKind == 2) {
      if (typeId == 9) return 1.2 + tier * 0.05;
      if (typeId == 10 || typeId == 41) return 1.1 + tier * 0.03;
      if (typeId == 49) return 1.12 + tier * 0.06;
    }
    return 1;
  }
}
