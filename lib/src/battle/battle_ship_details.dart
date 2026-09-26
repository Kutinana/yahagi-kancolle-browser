import '../game_state/game_state.dart';

/// Details captured with the fleet, never inferred from another enemy encounter.
class BattleShipDetails {
  BattleShipDetails({
    this.level,
    this.nextExperience,
    this.remodelShipId,
    this.remodelLevel,
    this.remodelName,
    this.enemyVariant,
    this.fuelPercent,
    this.ammoPercent,
    this.firepower,
    this.torpedo,
    this.antiAir,
    this.armor,
    List<BattleEquipmentDetails>? equipment,
  }) : equipment = equipment == null ? null : List.unmodifiable(equipment);

  final int? level;
  final int? nextExperience;
  final int? remodelShipId;
  final int? remodelLevel;
  final String? remodelName;
  final String? enemyVariant;
  final int? fuelPercent;
  final int? ammoPercent;
  final int? firepower;
  final int? torpedo;
  final int? antiAir;
  final int? armor;

  /// null means unavailable; an empty list means known to have no equipment.
  final List<BattleEquipmentDetails>? equipment;

  factory BattleShipDetails.friendly(OwnedShip ship, GameState state) {
    final master = state.masterForShip(ship);
    int? percent(int value, int? max) => max == null || max <= 0
        ? null
        : (value * 100 / max).floor().clamp(0, 100);
    BattleEquipmentDetails equipment(int instanceId, bool extra) {
      final owned = state.slotItems[instanceId];
      return BattleEquipmentDetails.fromMaster(
        owned?.masterSlotItemId,
        state,
        improvement: owned?.level ?? 0,
        proficiency: owned?.proficiency ?? 0,
        extra: extra,
      );
    }

    return BattleShipDetails(
      level: ship.level,
      nextExperience: ship.nextExperience,
      remodelShipId: master?.afterShipId,
      remodelLevel: master?.afterLv,
      remodelName: master?.afterShipId == master?.id
          ? null
          : state.masterShips[master?.afterShipId]?.name,
      fuelPercent: percent(ship.currentFuel, master?.maxFuel),
      ammoPercent: percent(ship.currentAmmo, master?.maxAmmo),
      firepower: ship.firepower,
      torpedo: ship.torpedo,
      antiAir: ship.antiAir,
      armor: ship.armor,
      equipment: [
        for (final id in ship.slotIds)
          if (id > 0) equipment(id, false),
        if (ship.extraSlotId > 0) equipment(ship.extraSlotId, true),
      ],
    );
  }

  factory BattleShipDetails.enemy({
    required Object? level,
    required Object? parameters,
    required Object? slots,
    required GameState state,
    String? reading,
  }) {
    int? number(Object? value) =>
        value is num && value >= 0 ? value.toInt() : null;
    final equipmentMasters = <MasterSlotItem>[];
    var hasCompleteEquipment = slots is List;
    if (slots is List) {
      for (final id in slots) {
        if (id is! num) {
          hasCompleteEquipment = false;
        } else if (id > 0) {
          final master = state.masterSlotItems[id.toInt()];
          if (master == null) {
            hasCompleteEquipment = false;
          } else {
            equipmentMasters.add(master);
          }
        }
      }
    }

    // api_eParam contains base stats. Match Poi's default finalParam display
    // and the already-equipped friendly stats by adding every equipment copy.
    // Missing equipment data must not make base values look like known totals.
    int? stat(int index, int Function(MasterSlotItem) bonus) {
      final base = parameters is List && index < parameters.length
          ? number(parameters[index])
          : null;
      if (base == null || !hasCompleteEquipment) return null;
      return equipmentMasters.fold<int>(
        base,
        (total, item) => total + bonus(item),
      );
    }

    return BattleShipDetails(
      level: number(level),
      enemyVariant: switch (reading?.trim().toLowerCase()) {
        'elite' => 'elite',
        'flagship' => 'Flagship',
        _ => null,
      },
      firepower: stat(0, (item) => item.firepower),
      torpedo: stat(1, (item) => item.torpedo),
      antiAir: stat(2, (item) => item.antiAir),
      armor: stat(3, (item) => item.armor),
      equipment: slots is List
          ? [
              for (final id in slots)
                if (id is! num)
                  BattleEquipmentDetails.fromMaster(null, state)
                else if (id > 0)
                  BattleEquipmentDetails.fromMaster(id.toInt(), state),
            ]
          : null,
    );
  }
}

class BattleEquipmentDetails {
  const BattleEquipmentDetails({
    this.masterId,
    this.name,
    this.iconId = -1,
    this.improvement = 0,
    this.proficiency = 0,
    this.extra = false,
  });

  final int? masterId;
  final String? name;
  final int iconId;
  final int improvement;
  final int proficiency;
  final bool extra;

  factory BattleEquipmentDetails.fromMaster(
    int? masterId,
    GameState state, {
    int improvement = 0,
    int proficiency = 0,
    bool extra = false,
  }) {
    final master = state.masterSlotItems[masterId];
    return BattleEquipmentDetails(
      masterId: masterId,
      name: master?.name,
      iconId: master != null && master.type.length > 3 ? master.type[3] : -1,
      improvement: improvement,
      proficiency: proficiency,
      extra: extra,
    );
  }
}
