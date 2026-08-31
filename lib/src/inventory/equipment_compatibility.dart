import '../game_state/game_state.dart';

class EquipmentCompatibility {
  const EquipmentCompatibility({
    required this.canEquipInRegularSlot,
    required this.canEquipInExpansionSlot,
    this.expansionSlotMinimumImprovement = 0,
  });

  final bool canEquipInRegularSlot;
  final bool canEquipInExpansionSlot;
  final int expansionSlotMinimumImprovement;

  bool get canEquip => canEquipInRegularSlot || canEquipInExpansionSlot;
}

class EquipmentCompatibilityService {
  const EquipmentCompatibilityService(this.state);

  final GameState state;

  EquipmentCompatibility? resolve({
    required int shipMasterId,
    required int equipmentMasterId,
  }) {
    final ship = state.masterShips[shipMasterId];
    final equipment = state.masterSlotItems[equipmentMasterId];
    if (ship == null || equipment == null || equipment.type.length < 3) {
      return null;
    }

    final typeId = effectiveEquipmentTypeId(equipment);
    final categoryAllowed = ship.equipTypeIds.contains(typeId);
    final whitelist = ship.limitedEquipmentIdsByType[typeId];
    final regularSlotAllowed =
        categoryAllowed &&
        (whitelist == null || whitelist.contains(equipmentMasterId));

    final generalExpansionAllowed =
        regularSlotAllowed &&
        state.expansionSlotEquipmentTypeIds.contains(typeId) &&
        !(state.expansionSlotLimitsByShipId[shipMasterId]?.contains(typeId) ??
            false);
    final specialRule = state.expansionSlotSpecialRules[equipmentMasterId];
    final specialExpansionAllowed =
        categoryAllowed &&
        specialRule != null &&
        _matchesSpecialRule(ship, specialRule);

    return EquipmentCompatibility(
      canEquipInRegularSlot: regularSlotAllowed,
      canEquipInExpansionSlot:
          generalExpansionAllowed || specialExpansionAllowed,
      expansionSlotMinimumImprovement: specialExpansionAllowed
          ? specialRule.minimumImprovement
          : 0,
    );
  }

  static int effectiveEquipmentTypeId(MasterSlotItem equipment) =>
      _effectiveTypeOverrides[equipment.id] ??
      (equipment.type.length > 2 ? equipment.type[2] : 0);

  static bool _matchesSpecialRule(
    MasterShip ship,
    ExpansionSlotSpecialRule rule,
  ) =>
      rule.shipTypeIds.contains(99) ||
      rule.shipMasterIds.contains(ship.id) ||
      rule.classTypeIds.contains(ship.classTypeId) ||
      rule.shipTypeIds.contains(ship.shipTypeId);

  static const Map<int, int> _effectiveTypeOverrides = <int, int>{
    128: 38,
    142: 93,
    151: 94,
    281: 38,
    460: 93,
    465: 38,
    467: 95,
    561: 91,
  };
}
