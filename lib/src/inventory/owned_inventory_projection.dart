import '../game_state/game_state.dart';

enum ShipInventoryCategory { all, bbBc, cv, cvl, ca, cl, dd, de, ss, support }

enum ShipInventorySortField {
  name,
  type,
  speed,
  level,
  condition,
  hp,
  firepower,
  torpedo,
  antiAir,
  armor,
  luck,
  evasion,
  antiSub,
  lineOfSight,
  equipment,
  locked,
  officialId,
  instanceId,
}

class ShipInventorySortCriterion {
  const ShipInventorySortCriterion({
    required this.field,
    required this.descending,
  });

  final ShipInventorySortField field;
  final bool descending;

  ShipInventorySortCriterion copyWith({bool? descending}) =>
      ShipInventorySortCriterion(
        field: field,
        descending: descending ?? this.descending,
      );
}

const defaultShipInventorySortCriteria = <ShipInventorySortCriterion>[
  ShipInventorySortCriterion(
    field: ShipInventorySortField.level,
    descending: true,
  ),
];

enum EquipmentInventoryCategory {
  all,
  mainGun,
  secondaryGun,
  machineGun,
  torpedo,
  carrierAircraft,
  seaplane,
  landBasedAircraft,
  antiSubmarine,
  radar,
  landingTransport,
  support,
}

enum EquipmentInventorySortField { name, total, officialId }

class EquipmentInventorySortCriterion {
  const EquipmentInventorySortCriterion({
    required this.field,
    required this.descending,
  });

  final EquipmentInventorySortField field;
  final bool descending;

  EquipmentInventorySortCriterion copyWith({bool? descending}) =>
      EquipmentInventorySortCriterion(
        field: field,
        descending: descending ?? this.descending,
      );
}

class ShipInventoryRow {
  const ShipInventoryRow({
    required this.ship,
    required this.master,
    required this.type,
    required this.fleetNumber,
    required this.equipment,
  });

  final OwnedShip ship;
  final MasterShip? master;
  final MasterShipType? type;
  final int? fleetNumber;
  final List<ShipEquipment> equipment;
}

class EquipmentInventoryVariant {
  const EquipmentInventoryVariant({
    required this.level,
    required this.proficiency,
    required this.count,
  });
  final int level;
  final int proficiency;
  final int count;
}

enum EquipmentVariantSummaryKind { improvement, proficiency }

class EquipmentVariantSummary {
  const EquipmentVariantSummary({
    required this.kind,
    required this.level,
    required this.count,
  });

  final EquipmentVariantSummaryKind kind;
  final int level;
  final int count;
}

/// Builds the two independent distributions shown in the inventory table.
/// Improvement levels always precede proficiency levels; both are ascending.
List<EquipmentVariantSummary> summarizeEquipmentVariants(
  Iterable<EquipmentInventoryVariant> variants,
) {
  final improvements = <int, int>{};
  final proficiencies = <int, int>{};
  for (final variant in variants) {
    improvements[variant.level] =
        (improvements[variant.level] ?? 0) + variant.count;
    if (variant.proficiency > 0) {
      proficiencies[variant.proficiency] =
          (proficiencies[variant.proficiency] ?? 0) + variant.count;
    }
  }

  final improvementLevels = improvements.keys.toList()..sort();
  final proficiencyLevels = proficiencies.keys.toList()..sort();
  return <EquipmentVariantSummary>[
    for (final level in improvementLevels)
      EquipmentVariantSummary(
        kind: EquipmentVariantSummaryKind.improvement,
        level: level,
        count: improvements[level]!,
      ),
    for (final level in proficiencyLevels)
      EquipmentVariantSummary(
        kind: EquipmentVariantSummaryKind.proficiency,
        level: level,
        count: proficiencies[level]!,
      ),
  ];
}

class EquipmentWearing {
  const EquipmentWearing({
    required this.shipId,
    required this.shipName,
    required this.level,
    required this.count,
  });
  final int shipId;
  final String shipName;
  final int level;
  final int count;
}

class EquipmentInventoryGroup {
  const EquipmentInventoryGroup({
    required this.master,
    required this.total,
    required this.remaining,
    required this.variants,
    required this.wearings,
  });
  final MasterSlotItem master;
  final int total;
  final int remaining;
  final List<EquipmentInventoryVariant> variants;
  final List<EquipmentWearing> wearings;
}

class OwnedInventoryProjection {
  const OwnedInventoryProjection(this.state);
  final GameState state;

  int? fleetNumberForShip(int shipId) {
    for (final fleet in state.fleets) {
      if (fleet.shipIds.contains(shipId)) return fleet.id;
    }
    return null;
  }

  List<ShipInventoryRow> shipRows({
    ShipInventoryCategory category = ShipInventoryCategory.all,
    List<ShipInventorySortCriterion> sortCriteria =
        defaultShipInventorySortCriteria,
  }) {
    final rows = <ShipInventoryRow>[
      for (final ship in state.ships.values)
        if (_matchesShipCategory(ship, category))
          ShipInventoryRow(
            ship: ship,
            master: state.masterForShip(ship),
            type: state.typeForShip(ship),
            fleetNumber: fleetNumberForShip(ship.id),
            equipment: state.equipmentForShip(ship),
          ),
    ];
    final criteria = sortCriteria.isEmpty
        ? defaultShipInventorySortCriteria
        : sortCriteria;
    rows.sort((left, right) {
      for (final criterion in criteria) {
        final comparison = _compareShipRows(left, right, criterion.field);
        final directed = criterion.descending ? -comparison : comparison;
        if (directed != 0) return directed;
      }
      return left.ship.id.compareTo(right.ship.id);
    });
    return rows;
  }

  bool _matchesShipCategory(OwnedShip ship, ShipInventoryCategory category) {
    final typeId = state.masterForShip(ship)?.shipTypeId ?? 0;
    return shipTypeMatchesInventoryCategory(typeId, category);
  }

  int _compareShipRows(
    ShipInventoryRow left,
    ShipInventoryRow right,
    ShipInventorySortField field,
  ) {
    Comparable<Object> value(ShipInventoryRow row) => switch (field) {
      ShipInventorySortField.name => row.master?.name ?? '',
      ShipInventorySortField.type => row.type?.name ?? '',
      ShipInventorySortField.speed => row.ship.effectiveSpeed(row.master),
      ShipInventorySortField.level => row.ship.level,
      ShipInventorySortField.condition => row.ship.condition,
      ShipInventorySortField.hp => row.ship.currentHp,
      ShipInventorySortField.firepower => row.ship.firepower,
      ShipInventorySortField.torpedo => row.ship.torpedo,
      ShipInventorySortField.antiAir => row.ship.antiAir,
      ShipInventorySortField.armor => row.ship.armor,
      ShipInventorySortField.luck => row.ship.luck,
      ShipInventorySortField.evasion => row.ship.evasion,
      ShipInventorySortField.antiSub => row.ship.antiSub,
      ShipInventorySortField.lineOfSight => row.ship.lineOfSight,
      ShipInventorySortField.equipment => row.equipment.length,
      ShipInventorySortField.locked => row.ship.locked ? 1 : 0,
      ShipInventorySortField.officialId => row.ship.masterId,
      ShipInventorySortField.instanceId => row.ship.id,
    };
    return value(left).compareTo(value(right));
  }

  List<EquipmentInventoryGroup> equipmentGroups({
    EquipmentInventoryCategory category = EquipmentInventoryCategory.all,
    List<EquipmentInventorySortCriterion> sortCriteria =
        const <EquipmentInventorySortCriterion>[],
  }) {
    final ownedByMaster = <int, List<OwnedSlotItem>>{};
    for (final item in state.slotItems.values) {
      ownedByMaster
          .putIfAbsent(item.masterSlotItemId, () => <OwnedSlotItem>[])
          .add(item);
    }
    final equippedByItemId = <int, OwnedShip>{};
    for (final ship in state.ships.values) {
      for (final id in <int>[...ship.slotIds, ship.extraSlotId]) {
        if (id > 0) equippedByItemId[id] = ship;
      }
    }

    final groups = <EquipmentInventoryGroup>[];
    for (final entry in ownedByMaster.entries) {
      final master = state.masterSlotItems[entry.key];
      if (master == null ||
          (category != EquipmentInventoryCategory.all &&
              equipmentInventoryCategoryFor(master) != category)) {
        continue;
      }
      final variantCounts = <(int, int), int>{};
      final wearingCounts = <int, int>{};
      var equippedCount = 0;
      for (final item in entry.value) {
        final variant = (item.level, item.proficiency);
        variantCounts[variant] = (variantCounts[variant] ?? 0) + 1;
        final ship = equippedByItemId[item.instanceId];
        if (ship != null) {
          equippedCount++;
          wearingCounts[ship.id] = (wearingCounts[ship.id] ?? 0) + 1;
        }
      }
      final variants =
          <EquipmentInventoryVariant>[
            for (final variant in variantCounts.entries)
              EquipmentInventoryVariant(
                level: variant.key.$1,
                proficiency: variant.key.$2,
                count: variant.value,
              ),
          ]..sort((a, b) {
            final byLevel = a.level.compareTo(b.level);
            return byLevel != 0
                ? byLevel
                : a.proficiency.compareTo(b.proficiency);
          });
      final wearings =
          <EquipmentWearing>[
            for (final wearing in wearingCounts.entries)
              if (state.ships[wearing.key] case final ship?)
                EquipmentWearing(
                  shipId: ship.id,
                  shipName: state.masterForShip(ship)?.name ?? '—',
                  level: ship.level,
                  count: wearing.value,
                ),
          ]..sort((a, b) {
            final byLevel = b.level.compareTo(a.level);
            return byLevel != 0 ? byLevel : a.shipId.compareTo(b.shipId);
          });
      groups.add(
        EquipmentInventoryGroup(
          master: master,
          total: entry.value.length,
          remaining: entry.value.length - equippedCount,
          variants: variants,
          wearings: wearings,
        ),
      );
    }
    groups.sort((left, right) {
      for (final criterion in sortCriteria) {
        final comparison = _compareEquipmentGroupsByField(
          left,
          right,
          criterion.field,
        );
        final directed = criterion.descending ? -comparison : comparison;
        if (directed != 0) return directed;
      }
      return _compareEquipmentGroups(left, right);
    });
    return groups;
  }
}

int _compareEquipmentGroupsByField(
  EquipmentInventoryGroup left,
  EquipmentInventoryGroup right,
  EquipmentInventorySortField field,
) {
  Comparable<Object> value(EquipmentInventoryGroup group) => switch (field) {
    EquipmentInventorySortField.name => group.master.name,
    EquipmentInventorySortField.total => group.total,
    EquipmentInventorySortField.officialId => group.master.id,
  };
  return value(left).compareTo(value(right));
}

int _compareEquipmentGroups(
  EquipmentInventoryGroup left,
  EquipmentInventoryGroup right,
) => _compareEquipmentMasters(left.master, right.master);

int _compareEquipmentMasters(MasterSlotItem left, MasterSlotItem right) {
  final leftType = left.type;
  final rightType = right.type;
  final byBroad = (leftType.isNotEmpty ? leftType[0] : 0).compareTo(
    rightType.isNotEmpty ? rightType[0] : 0,
  );
  if (byBroad != 0) return byBroad;
  final byFine = (leftType.length > 2 ? leftType[2] : 0).compareTo(
    rightType.length > 2 ? rightType[2] : 0,
  );
  if (byFine != 0) return byFine;
  final leftSort = left.sortNo > 0 ? left.sortNo : left.id;
  final rightSort = right.sortNo > 0 ? right.sortNo : right.id;
  final bySort = leftSort.compareTo(rightSort);
  return bySort != 0 ? bySort : left.id.compareTo(right.id);
}

bool shipTypeMatchesInventoryCategory(
  int typeId,
  ShipInventoryCategory category,
) => switch (category) {
  ShipInventoryCategory.all => true,
  ShipInventoryCategory.bbBc => const <int>{8, 9, 10, 12}.contains(typeId),
  ShipInventoryCategory.cv => const <int>{11, 18}.contains(typeId),
  ShipInventoryCategory.cvl => typeId == 7,
  ShipInventoryCategory.ca => const <int>{5, 6}.contains(typeId),
  ShipInventoryCategory.cl => const <int>{3, 4, 21}.contains(typeId),
  ShipInventoryCategory.dd => typeId == 2,
  ShipInventoryCategory.de => typeId == 1,
  ShipInventoryCategory.ss => const <int>{13, 14}.contains(typeId),
  ShipInventoryCategory.support => const <int>{
    15,
    16,
    17,
    19,
    20,
    22,
  }.contains(typeId),
};

EquipmentInventoryCategory equipmentInventoryCategoryFor(MasterSlotItem item) {
  final broad = item.type.isNotEmpty ? item.type[0] : 0;
  final fine = item.type.length > 2 ? item.type[2] : 0;
  final icon = item.type.length > 3 ? item.type[3] : 0;
  // Searchlights share the broad equipment group used by drums, so their
  // precise types must win before the landing/transport fallback below.
  if (const <int>{29, 42}.contains(fine)) {
    return EquipmentInventoryCategory.support;
  }
  if (const <int>{12, 13, 51}.contains(fine) ||
      const <int>{11, 42}.contains(icon)) {
    return EquipmentInventoryCategory.radar;
  }
  if (broad == 7 || const <int>{17, 18, 21, 22}.contains(icon)) {
    return EquipmentInventoryCategory.antiSubmarine;
  }
  if (const <int>{8, 9, 20, 23, 27}.contains(broad) ||
      const <int>{20, 25, 36, 41, 52}.contains(icon)) {
    return EquipmentInventoryCategory.landingTransport;
  }
  if (const <int>{21, 22, 25, 26}.contains(broad) ||
      const <int>{37, 38, 44, 47, 48, 49, 56, 57, 59}.contains(icon)) {
    return EquipmentInventoryCategory.landBasedAircraft;
  }
  if (broad == 5 && const <int>{9, 10, 11, 41, 45, 49, 50, 51}.contains(fine)) {
    return EquipmentInventoryCategory.seaplane;
  }
  if (broad == 3 ||
      const <int>{6, 7, 8, 9, 39, 40, 45, 46, 58, 60}.contains(icon)) {
    return EquipmentInventoryCategory.carrierAircraft;
  }
  if (broad == 2 || const <int>{5, 22, 32}.contains(fine)) {
    return EquipmentInventoryCategory.torpedo;
  }
  if (fine == 15 || icon == 15) {
    return EquipmentInventoryCategory.machineGun;
  }
  if (icon == 4 || icon == 16 || fine == 4) {
    return EquipmentInventoryCategory.secondaryGun;
  }
  if (broad == 1 || const <int>{1, 2, 3}.contains(icon)) {
    return EquipmentInventoryCategory.mainGun;
  }
  return EquipmentInventoryCategory.support;
}
