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

      final multiplier = _reconMultiplier(
        typeId: typeId,
        lineOfSight: master.lineOfSight,
        actionKind: base.actionKind,
      );
      reconMultiplier = math.max(reconMultiplier, multiplier);

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
    final standardAircraft =
        <int>{6, 7, 45, 47, 57}.contains(typeId) ||
        (typeId == 26 && master.antiAir > 0);
    final carrierAircraft = typeId == 8 || typeId == 11;
    final localFighter = typeId == 48;
    final sortieRecon =
        actionKind == 1 && (typeId == 10 || typeId == 41 || typeId == 49);
    if (!standardAircraft &&
        !carrierAircraft &&
        !localFighter &&
        !sortieRecon) {
      return null;
    }

    final proficiency = owned.proficiency.clamp(0, 7).toInt();
    final improvementFactor =
        master.antiAir > 3 && (standardAircraft || localFighter || typeId == 49)
        ? (master.bombing > 0 ? 0.25 : 0.2)
        : 0.0;
    var effectiveAntiAir = master.antiAir + owned.level * improvementFactor;
    if (localFighter) {
      if (actionKind == 1) {
        effectiveAntiAir += 1.5 * master.interception;
      } else if (actionKind == 2) {
        effectiveAntiAir += master.interception + 2 * master.antiBomber;
      }
    }

    final typeBonus = switch (typeId) {
      6 || 26 || 45 || 48 => _fighterBonuses[proficiency],
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

  static double _reconMultiplier({
    required int typeId,
    required int lineOfSight,
    required int actionKind,
  }) {
    if ((typeId == 10 || typeId == 41) && actionKind == 2) {
      if (lineOfSight >= 9) return 1.16;
      if (lineOfSight == 8) return 1.13;
      return 1.1;
    }
    if (typeId == 9 && actionKind == 2) {
      return lineOfSight >= 9 ? 1.3 : 1.2;
    }
    if (typeId == 49) {
      if (actionKind == 1) return lineOfSight >= 9 ? 1.18 : 1.15;
      if (actionKind == 2) return lineOfSight >= 9 ? 1.23 : 1.18;
    }
    return 1;
  }
}
