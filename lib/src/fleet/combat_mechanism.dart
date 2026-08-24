import 'dart:math' as math;

import '../game_state/game_state.dart';
import 'equipment_display.dart';

List<EquipmentMechanismDisplay> detectShipCombatMechanisms(
  GameState state,
  OwnedShip ship,
) {
  final master = state.masterForShip(ship);
  if (master == null) {
    return const <EquipmentMechanismDisplay>[];
  }
  final equipment = state.equipmentForShip(ship);
  final result = <EquipmentMechanismDisplay>[];

  if (_canOpeningAsw(master, ship, equipment)) {
    result.add(
      const EquipmentMechanismDisplay(
        label: '先制对潜',
        shortLabel: '先反',
        description: '开幕雷击前先进行一次对潜攻击。当前舰娘的舰种、对潜值和装备组合满足 Yahagi 的先制对潜静态判定。',
        tone: MechanismTone.antiSubmarine,
      ),
    );
  }
  if (_canAntiAirCutIn(master, equipment)) {
    result.add(
      const EquipmentMechanismDisplay(
        label: '对空 CI',
        shortLabel: '对空',
        description: '当前装备组合可触发对空弹幕（对空 Cut-in）。实际触发类型和击坠效果由舰娘与装备组合决定。',
        tone: MechanismTone.antiAir,
      ),
    );
  }
  if (_canAntiAirRocketBarrage(master, equipment)) {
    final rate = _calculateAarocketBarrageRate(master, ship, equipment);
    final percent = (rate * 100).round();
    result.add(
      EquipmentMechanismDisplay(
        label: '对空喷进弹幕',
        shortLabel: '喷2',
        rate: rate,
        description:
            '当前舰种装备了 12cm 30连装喷进炮改二，可在航空战中判定对空喷进弹幕。当前配装预估发动概率约为 $percent%。',
        tone: MechanismTone.antiAir,
      ),
    );
  }
  if (_canNightCarrierAttack(master, equipment)) {
    result.add(
      const EquipmentMechanismDisplay(
        label: '空母夜间航空攻击',
        shortLabel: '夜袭',
        description: '搭载夜间飞机（夜战/夜攻）及夜间作战航空要员或自带夜战起飞能力，可在夜战中发动空母夜间航空攻击（夜袭 CI）。',
        tone: MechanismTone.nightAttack,
      ),
    );
  }
  return result;
}

EquipmentMechanismDisplay? detectFleetSpecialAttack(
  GameState state,
  Fleet fleet,
) {
  final ships = state.shipsForFleet(fleet.id);
  if (ships.length < 2) {
    return null;
  }
  final masters = <MasterShip?>[
    for (final ship in ships) state.masterForShip(ship),
  ];
  if (masters.any((item) => item == null)) {
    return null;
  }
  final flagship = masters[0]!;
  final second = masters[1]!;
  final fullFleet = ships.length >= 6;
  final flagshipHealthy = _notMediumDamage(ships[0]);
  final secondHealthy = _notHeavyDamage(ships[1]);

  EquipmentMechanismDisplay mechanism(
    String label,
    String summary, {
    double? rate,
  }) {
    final percentText = rate != null
        ? '当前配装预估发动概率约为 ${(rate * 100).round()}%。'
        : '';
    return EquipmentMechanismDisplay(
      label: label,
      shortLabel: '特攻',
      rate: rate,
      description:
          '$summary $percentText当前仅表示编成与耐久等静态条件匹配；实际发动还受阵型、联合舰队状态和本次出击中的使用次数限制。',
      tone: MechanismTone.specialAttack,
    );
  }

  if (fullFleet &&
      flagship.classTypeId == 88 &&
      flagshipHealthy &&
      _nelsonPositionsAreValid(masters)) {
    final rate = _calculateFleetSpecialAttackRate(
      state,
      fleet,
      ships,
      masters,
      'Nelson Touch',
    );
    return mechanism('Nelson Touch', 'Nelson 级旗舰的特殊攻击编成。', rate: rate);
  }
  if (fullFleet &&
      flagship.id == 541 &&
      flagshipHealthy &&
      _isBattleship(second) &&
      secondHealthy) {
    final rate = _calculateFleetSpecialAttackRate(
      state,
      fleet,
      ships,
      masters,
      '一齐射击（长门）',
    );
    return mechanism('一齐射击（长门）', '长门改二旗舰的特殊攻击编成。', rate: rate);
  }
  if (fullFleet &&
      flagship.id == 573 &&
      flagshipHealthy &&
      _isBattleship(second) &&
      secondHealthy) {
    final rate = _calculateFleetSpecialAttackRate(
      state,
      fleet,
      ships,
      masters,
      '一齐射击（陆奥）',
    );
    return mechanism('一齐射击（陆奥）', '陆奥改二旗舰的特殊攻击编成。', rate: rate);
  }
  if (fullFleet &&
      flagship.classTypeId == 93 &&
      flagshipHealthy &&
      masters.length >= 3 &&
      _isBattleship(second) &&
      _isBattleship(masters[2]!) &&
      secondHealthy &&
      _notHeavyDamage(ships[2])) {
    return mechanism('Colorado Touch', 'Colorado 级旗舰的特殊攻击编成。');
  }
  if (fullFleet &&
      const <int>{911, 916, 546}.contains(flagship.id) &&
      flagshipHealthy &&
      _yamatoPartner(second) &&
      _notMediumDamage(ships[1])) {
    final rate = _calculateFleetSpecialAttackRate(
      state,
      fleet,
      ships,
      masters,
      '大和型特殊攻击',
    );
    return mechanism('大和型特殊攻击', '大和改二／武藏改二旗舰的特殊攻击编成。', rate: rate);
  }
  if (fullFleet &&
      const <int>{591, 592, 593, 954, 694}.contains(flagship.id) &&
      flagshipHealthy &&
      const <int>{
        151,
        152,
        364,
        439,
        591,
        592,
        593,
        694,
        733,
        927,
        954,
      }.contains(second.id) &&
      _notMediumDamage(ships[1])) {
    final rate = _calculateFleetSpecialAttackRate(
      state,
      fleet,
      ships,
      masters,
      '僚舰夜战突击',
    );
    return mechanism('僚舰夜战突击', '金刚级改二丙／榛名改二乙系旗舰的夜战特殊攻击编成。', rate: rate);
  }
  if (fullFleet &&
      const <int>{364, 733}.contains(flagship.id) &&
      const <int>{364, 733}.contains(second.id) &&
      flagship.id != second.id &&
      flagshipHealthy &&
      secondHealthy) {
    final rate = _calculateFleetSpecialAttackRate(
      state,
      fleet,
      ships,
      masters,
      'Queen Elizabeth级特殊攻击',
    );
    return mechanism(
      'Queen Elizabeth级特殊攻击',
      'Warspite改与Valiant改组成的特殊攻击编成。',
      rate: rate,
    );
  }
  if (fullFleet &&
      const <int>{392, 969, 724}.contains(flagship.id) &&
      const <int>{392, 969, 724}.contains(second.id) &&
      flagship.id != second.id &&
      flagshipHealthy &&
      secondHealthy) {
    final rate = _calculateFleetSpecialAttackRate(
      state,
      fleet,
      ships,
      masters,
      'Richelieu级特殊攻击',
    );
    return mechanism(
      'Richelieu级特殊攻击',
      'Richelieu改／Deux与Jean Bart改组成的特殊攻击编成。',
      rate: rate,
    );
  }
  if (ships.length >= 4 &&
      flagship.shipTypeId == 20 &&
      ships[0].level >= 30 &&
      _notHeavyDamage(ships[0]) &&
      _submarineTenderHelpersAreValid(masters, ships)) {
    return mechanism('潜水舰队攻击', '潜水母舰旗舰与潜水舰僚舰的特殊攻击编成。');
  }
  return null;
}

bool _canOpeningAsw(
  MasterShip master,
  OwnedShip ship,
  List<ShipEquipment> equipment,
) {
  const unconditionalShips = <int>{
    141,
    394,
    478,
    624,
    562,
    689,
    596,
    692,
    628,
    629,
    681,
    726,
    893,
    906,
    920,
    941,
    1040,
  };
  if (unconditionalShips.contains(master.id)) {
    return true;
  }

  final hasSonar = equipment.any((item) => _isSonar(item.master));
  final hasOriginalAircraftCapacity =
      master.slotCapacities.fold<int>(0, (sum, capacity) => sum + capacity) > 0;

  if (master.id == 554) {
    final hasS51J = equipment.any(
      (item) => const <int>{326, 327}.contains(item.master?.id),
    );
    final autogyroCount = equipment
        .where((item) => _type(item.master) == 25)
        .length;
    return hasS51J || autogyroCount >= 2;
  }

  if (const <int>{411, 412}.contains(master.id)) {
    final hasRequiredEquipment = equipment.any(
      (item) => const <int>{11, 15, 25}.contains(_type(item.master)),
    );
    return ship.antiSub >= 100 &&
        equipment.any((item) => item.master?.id == 132) &&
        hasOriginalAircraftCapacity &&
        hasRequiredEquipment;
  }

  if (const <int>{943, 948}.contains(master.id)) {
    return ship.antiSub >= 100 &&
        hasSonar &&
        hasOriginalAircraftCapacity &&
        _hasAswAircraft(equipment, const <int>{7, 25, 26}, minimumAsw: 1);
  }

  if (const <int>{626, 916}.contains(master.id)) {
    return ship.antiSub >= 100 &&
        hasSonar &&
        hasOriginalAircraftCapacity &&
        _hasAswAircraft(equipment, const <int>{11, 25}, minimumAsw: 0);
  }

  const escortCarriers = <int>{380, 529, 381, 536, 382, 889, 646};
  if (escortCarriers.contains(master.id)) {
    return hasOriginalAircraftCapacity &&
        _hasAswAircraft(equipment, const <int>{7, 8, 25, 26}, minimumAsw: 1);
  }

  const excludedOrdinaryLightCarriers = <int>{
    508,
    509,
    521,
    522,
    526,
    380,
    529,
    534,
    381,
    536,
    884,
    382,
    889,
  };
  if (master.shipTypeId == 7 &&
      !excludedOrdinaryLightCarriers.contains(master.id)) {
    if (!hasOriginalAircraftCapacity) {
      return false;
    }
    final hasAsw7Aircraft = _hasAswAircraft(equipment, const <int>{
      8,
      25,
      26,
    }, minimumAsw: 7);
    return (ship.antiSub >= 50 && hasSonar && hasAsw7Aircraft) ||
        (ship.antiSub >= 65 && hasAsw7Aircraft) ||
        (ship.antiSub >= 100 &&
            hasSonar &&
            _hasAswAircraft(equipment, const <int>{7, 8}, minimumAsw: 1));
  }

  if (master.shipTypeId == 1) {
    if (master.name.startsWith('Norge') || master.name.startsWith('Eidsvold')) {
      return false;
    }
    final equipmentAsw = equipment.fold<int>(
      0,
      (sum, item) => sum + (item.master?.antiSub ?? 0),
    );
    return (ship.antiSub >= 60 && hasSonar) ||
        (ship.antiSub >= 75 && equipmentAsw >= 4);
  }
  if (const <int>{2, 3, 4, 21, 22}.contains(master.shipTypeId)) {
    return ship.antiSub >= 100 && hasSonar;
  }
  return false;
}

bool _isSonar(MasterSlotItem? item) =>
    const <int>{17, 18}.contains(_icon(item));

bool _hasAswAircraft(
  List<ShipEquipment> equipment,
  Set<int> types, {
  required int minimumAsw,
}) => equipment.any(
  (item) =>
      types.contains(_type(item.master)) &&
      (item.master?.antiSub ?? 0) >= minimumAsw,
);

bool _canAntiAirCutIn(MasterShip master, List<ShipEquipment> equipment) {
  if (const <int>{13, 14}.contains(master.shipTypeId)) {
    return false;
  }
  final highAngle = equipment.where((item) => _icon(item.master) == 16).length;
  final builtInHighAngle = equipment
      .where(
        (item) => _icon(item.master) == 16 && (item.master?.antiAir ?? 0) >= 8,
      )
      .length;
  final hasAaRadar = equipment.any(
    (item) =>
        const <int>{12, 13}.contains(_type(item.master)) &&
        (item.master?.antiAir ?? 0) > 0,
  );
  final hasAafd = equipment.any((item) => _type(item.master) == 36);
  final hasLargeGun = equipment.any((item) => _type(item.master) == 3);
  final hasType3Shell = equipment.any((item) => _type(item.master) == 18);
  final aaGuns = equipment.where((item) => _type(item.master) == 21).length;
  final hasConcentratedAaGun = equipment.any(
    (item) => _type(item.master) == 21 && (item.master?.antiAir ?? 0) >= 9,
  );
  final slotCount = equipment.length;

  if (_isBattleship(master) &&
      slotCount >= 4 &&
      hasLargeGun &&
      hasType3Shell &&
      hasAafd &&
      hasAaRadar) {
    return true;
  }
  if (slotCount >= 3 &&
      ((builtInHighAngle >= 2 && hasAaRadar) ||
          (highAngle >= 1 && hasAafd && hasAaRadar) ||
          (hasConcentratedAaGun && aaGuns >= 2 && hasAaRadar) ||
          (builtInHighAngle >= 1 && hasConcentratedAaGun && hasAaRadar))) {
    return true;
  }
  if (slotCount >= 2 &&
      ((builtInHighAngle >= 1 && hasAaRadar) || (highAngle >= 1 && hasAafd))) {
    return true;
  }
  if (master.id == 428 &&
      highAngle >= 1 &&
      hasConcentratedAaGun &&
      (hasAaRadar || slotCount >= 2)) {
    return true;
  }
  return false;
}

bool _canAntiAirRocketBarrage(
  MasterShip master,
  List<ShipEquipment> equipment,
) {
  return const <int>{6, 7, 10, 11, 16, 18}.contains(master.shipTypeId) &&
      equipment.any((item) => item.master?.id == 274);
}

bool _canNightCarrierAttack(MasterShip master, List<ShipEquipment> equipment) {
  if (!_isCarrier(master)) {
    return false;
  }

  const nativeNightCarriers = <int>{393, 515, 545, 565, 599, 610, 883, 900};
  final isNativeNightCarrier = nativeNightCarriers.contains(master.id);

  final hasNightPersonnel = equipment.any(
    (item) => const <int>{258, 259}.contains(item.master?.id),
  );

  if (!isNativeNightCarrier && !hasNightPersonnel) {
    return false;
  }

  const nightFighterIds = <int>{254, 255, 389, 390, 413, 448, 449, 479, 506};
  const nightAttackerIds = <int>{
    256,
    257,
    320,
    344,
    345,
    373,
    374,
    399,
    447,
    478,
  };
  const swordfishIds = <int>{242, 243, 244, 369, 370, 464};

  bool isNightFighter(MasterSlotItem? item) {
    if (item == null) return false;
    if (nightFighterIds.contains(item.id)) return true;
    if (_icon(item) == 45) return true;
    return false;
  }

  bool isNightAttacker(MasterSlotItem? item) {
    if (item == null) return false;
    if (nightAttackerIds.contains(item.id)) return true;
    if (_icon(item) == 46) return true;
    return false;
  }

  bool isSwordfish(MasterSlotItem? item) {
    if (item == null) return false;
    return swordfishIds.contains(item.id);
  }

  final hasNightFighter = equipment.any((item) => isNightFighter(item.master));
  final hasNightAttacker = equipment.any(
    (item) => isNightAttacker(item.master),
  );
  final hasSwordfish = equipment.any((item) => isSwordfish(item.master));

  if (const <int>{393, 515}.contains(master.id) && hasSwordfish) {
    return true;
  }

  return hasNightFighter ||
      hasNightAttacker ||
      (hasNightPersonnel && hasSwordfish);
}

bool _nelsonPositionsAreValid(List<MasterShip?> masters) {
  if (masters.length < 6) {
    return false;
  }
  return !_isSubmarine(masters[1]!) &&
      !_isSubmarine(masters[2]!) &&
      !_isCarrier(masters[2]!) &&
      !_isSubmarine(masters[3]!) &&
      !_isSubmarine(masters[4]!) &&
      !_isCarrier(masters[4]!) &&
      !_isSubmarine(masters[5]!);
}

bool _submarineTenderHelpersAreValid(
  List<MasterShip?> masters,
  List<OwnedShip> ships,
) {
  if (masters.length < 4 || ships.length < 4) {
    return false;
  }
  var readySubmarines = 0;
  for (var i = 1; i <= 3; i++) {
    final master = masters[i];
    final ship = ships[i];
    if (master != null && _isSubmarine(master) && _notMediumDamage(ship)) {
      readySubmarines++;
    }
  }
  return readySubmarines >= 2;
}

bool _yamatoPartner(MasterShip master) {
  return const <int>{
    178,
    360,
    392,
    546,
    724,
    911,
    916,
    969,
  }.contains(master.id);
}

bool _notMediumDamage(OwnedShip ship) => ship.currentHp * 2 > ship.maxHp;

bool _notHeavyDamage(OwnedShip ship) => ship.currentHp * 4 > ship.maxHp;

bool _isSubmarine(MasterShip master) =>
    const <int>{13, 14}.contains(master.shipTypeId);

bool _isCarrier(MasterShip master) =>
    const <int>{7, 11, 18}.contains(master.shipTypeId);

bool _isBattleship(MasterShip master) =>
    const <int>{8, 9, 10, 12}.contains(master.shipTypeId);

int _type(MasterSlotItem? item) =>
    item != null && item.type.length >= 3 ? item.type[2] : -1;

int _icon(MasterSlotItem? item) =>
    item != null && item.type.length >= 4 ? item.type[3] : -1;

bool _isSurfaceRadar(MasterSlotItem? item) {
  if (item == null) return false;
  final type = _type(item);
  final icon = _icon(item);
  final isRadar = type == 12 || type == 13 || icon == 11;
  return isRadar && (item.antiAir < 2 || item.lineOfSight >= 5);
}

bool _isSurfaceRadarWithLos8(MasterSlotItem? item) {
  if (item == null) return false;
  return _isSurfaceRadar(item) && item.lineOfSight >= 8;
}

double _calculateAarocketBarrageRate(
  MasterShip master,
  OwnedShip ship,
  List<ShipEquipment> equipment,
) {
  final rocketCount = equipment.where((e) => e.master?.id == 274).length;
  if (rocketCount == 0) {
    return 0.0;
  }

  var totalEquipAA = 0;
  for (final item in equipment) {
    if (item.master != null) {
      totalEquipAA += item.master!.antiAir;
    }
  }
  final baseAA = (ship.antiAir - totalEquipAA).clamp(0, 9999);

  final hasEquipment = equipment.any((e) => e.master != null);
  final equippedModifier = hasEquipment ? 2 : 1;
  var x = baseAA.toDouble();

  for (final item in equipment) {
    final m = item.master;
    if (m == null) continue;

    final type = _type(m);
    final icon = _icon(m);
    final isHighAngle = icon == 16;
    final isAaDirector = type == 36 || icon == 30;
    final isAaGun = type == 21 || icon == 15;
    final isRadar = type == 12 || type == 13 || icon == 11;
    final isHighAngleWithDirector =
        m.id == 275 || m.id == 295 || m.id == 296 || m.id == 468;

    var equipmentBonus = 0.0;
    if (isHighAngle || isAaDirector) {
      equipmentBonus = 4.0;
    } else if (isAaGun) {
      equipmentBonus = 6.0;
    } else if (isRadar) {
      equipmentBonus = 3.0;
    }

    var levelBonus = 0.0;
    final level = item.owned.level.clamp(0, 10).toDouble();
    if (isHighAngle) {
      levelBonus = isHighAngleWithDirector ? 3.0 : 2.0;
    } else if (isAaGun) {
      levelBonus = (m.antiAir >= 8) ? 6.0 : 4.0;
    } else if (isAaDirector) {
      levelBonus = 2.0;
    }

    x += m.antiAir * equipmentBonus + math.sqrt(level) * levelBonus;
  }

  final adjustedAA = equippedModifier * (x / equippedModifier).floorToDouble();
  var rate = (0.9 * ship.luck + adjustedAA) / 281.0;
  if (rocketCount > 1) {
    rate += (rocketCount - 1) * 0.15;
  }
  if (master.classTypeId == 2 ||
      const <int>{82, 88, 553, 554}.contains(master.id)) {
    rate += 0.25;
  }

  return rate.clamp(0.0, 1.0);
}

double? _calculateFleetSpecialAttackRate(
  GameState state,
  Fleet fleet,
  List<OwnedShip> ships,
  List<MasterShip?> masters,
  String attackLabel,
) {
  if (ships.isEmpty) return null;
  final flagship = ships[0];
  final second = ships.length >= 2 ? ships[1] : null;

  switch (attackLabel) {
    case 'Nelson Touch':
      if (ships.length < 5) return null;
      final ship3 = ships[2];
      final ship5 = ships[4];
      final raw =
          1.1 * math.sqrt(flagship.level) +
          math.sqrt(ship3.level) +
          math.sqrt(ship5.level) +
          1.4 * math.sqrt(flagship.luck) +
          25.0;
      return (raw / 100.0).clamp(0.0, 1.0);

    case '一齐射击（长门）':
    case '一齐射击（陆奥）':
      if (second == null) return null;
      final raw =
          math.sqrt(flagship.level) +
          1.5 * math.sqrt(flagship.luck) +
          math.sqrt(second.level) +
          1.5 * math.sqrt(second.luck) +
          25.0;
      return (raw / 100.0).clamp(0.0, 1.0);

    case '大和型特殊攻击':
      if (second == null) return null;
      var raw =
          math.sqrt(flagship.level) +
          math.sqrt(second.level) +
          1.25 * math.sqrt(flagship.luck) +
          1.25 * math.sqrt(second.luck) +
          33.0;
      final secondMaster = masters[1];
      if (secondMaster != null) {
        if (secondMaster.id == 546) {
          raw += 7.0;
        } else if (secondMaster.id == 911 || secondMaster.id == 916) {
          raw += 4.0;
        }
      }
      final flagshipEq = state.equipmentForShip(flagship);
      final secondEq = state.equipmentForShip(second);
      if (flagshipEq.any((e) => _isSurfaceRadar(e.master))) {
        raw += 10.0;
      }
      if (secondEq.any((e) => _isSurfaceRadar(e.master))) {
        raw += 10.0;
      }
      return (raw / 100.0).clamp(0.0, 1.0);

    case '僚舰夜战突击':
      if (second == null) return null;
      final flagshipMaster = masters[0];
      if (flagshipMaster != null && flagshipMaster.id == 954) {
        return null;
      }
      var raw =
          3.5 * math.sqrt(flagship.level) +
          3.5 * math.sqrt(second.level) +
          1.1 * math.sqrt(flagship.luck) +
          1.1 * math.sqrt(second.luck) -
          33.0;

      final flagshipEq = state.equipmentForShip(flagship);
      if (flagshipEq.any((e) => _isSurfaceRadarWithLos8(e.master))) {
        if (flagshipMaster != null) {
          if (flagshipMaster.id == 591) {
            raw += 30.0;
          } else if (flagshipMaster.id == 592) {
            raw += 10.0;
          } else if (flagshipMaster.id == 593) {
            raw += 15.0;
          } else if (flagshipMaster.id == 694) {
            raw += 20.0;
          }
        }
      }
      if (flagshipEq.any((e) => e.master?.id == 140)) {
        if (flagshipMaster != null) {
          if (flagshipMaster.id == 591) {
            raw += 10.0;
          } else if (flagshipMaster.id == 592) {
            raw += 30.0;
          }
        }
      }
      return (math.max(0.0, raw) / 100.0).clamp(0.0, 1.0);

    case 'Queen Elizabeth级特殊攻击':
    case 'Richelieu级特殊攻击':
      if (second == null) return null;
      final raw =
          math.sqrt(flagship.level) +
          math.sqrt(second.level) +
          1.2 * (math.sqrt(flagship.luck) + math.sqrt(second.luck)) +
          30.0;
      return (raw / 100.0).clamp(0.0, 1.0);

    default:
      return null;
  }
}
