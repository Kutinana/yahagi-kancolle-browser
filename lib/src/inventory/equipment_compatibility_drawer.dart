import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import '../fleet/equipment_type_icon.dart';
import '../fleet/ship_portrait.dart';
import '../game_state/game_state.dart';
import 'equipment_compatibility_projection.dart';
import 'owned_inventory_projection.dart';

class EquipmentCompatibilityDrawer extends StatefulWidget {
  const EquipmentCompatibilityDrawer({
    super.key,
    required this.state,
    required this.equipment,
    required this.onClose,
  });

  final GameState state;
  final MasterSlotItem equipment;
  final VoidCallback onClose;

  @override
  State<EquipmentCompatibilityDrawer> createState() =>
      _EquipmentCompatibilityDrawerState();
}

class _EquipmentCompatibilityDrawerState
    extends State<EquipmentCompatibilityDrawer> {
  bool _ownedOnly = true;
  String _query = '';
  EquipmentCompatibilitySlotFilter _slotFilter =
      EquipmentCompatibilitySlotFilter.all;
  late EquipmentCompatibilityProjection _projection;

  @override
  void initState() {
    super.initState();
    _projection = EquipmentCompatibilityProjection(widget.state);
  }

  @override
  void didUpdateWidget(covariant EquipmentCompatibilityDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.state, widget.state)) {
      _projection = EquipmentCompatibilityProjection(widget.state);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    final rows = _projection.rows(
      equipmentMasterId: widget.equipment.id,
      ownedOnly: _ownedOnly,
      query: _query,
      filter: _slotFilter,
    );
    final allRows = _projection.rows(equipmentMasterId: widget.equipment.id);
    final ownedRows = _projection.rows(
      equipmentMasterId: widget.equipment.id,
      ownedOnly: true,
    );
    final allCount = allRows.length;
    final ownedCount = ownedRows.length;
    final equipmentOwnedCount = widget.state.slotItems.values
        .where((item) => item.masterSlotItemId == widget.equipment.id)
        .length;
    final regularCount = allRows
        .where((row) => row.compatibility.canEquipInRegularSlot)
        .length;
    final expansionCount = allRows
        .where((row) => row.compatibility.canEquipInExpansionSlot)
        .length;
    final category = _equipmentCategoryLabel(
      equipmentInventoryCategoryFor(widget.equipment),
      l10n,
    );
    final iconId = widget.equipment.type.length > 3
        ? widget.equipment.type[3]
        : -1;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.clamp(0.0, 438.0);
        return CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            const SingleActivator(LogicalKeyboardKey.escape): widget.onClose,
          },
          child: Focus(
            autofocus: true,
            child: Align(
              alignment: Alignment.centerRight,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 1, end: 0),
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                builder: (context, offset, child) => Transform.translate(
                  offset: Offset(width * offset, 0),
                  child: child,
                ),
                child: SizedBox(
                  key: const Key('equipment-compatibility-drawer'),
                  width: width,
                  height: constraints.maxHeight,
                  child: Material(
                    color: const Color(0xff0d2330),
                    elevation: 18,
                    shadowColor: Colors.black87,
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        border: Border(
                          left: BorderSide(color: Color(0xff38586b)),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Header(
                            equipment: widget.equipment,
                            iconId: iconId,
                            ownedCount: ownedCount,
                            allCount: allCount,
                            equipmentOwnedCount: equipmentOwnedCount,
                            regularCount: regularCount,
                            expansionCount: expansionCount,
                            category: category,
                            onClose: widget.onClose,
                          ),
                          if (widget.state.hasEquipmentCompatibilityData)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 2, 14, 10),
                              child: Column(
                                children: [
                                  _ScopeTabs(
                                    ownedOnly: _ownedOnly,
                                    ownedCount: ownedCount,
                                    allCount: allCount,
                                    onChanged: (value) =>
                                        setState(() => _ownedOnly = value),
                                  ),
                                  const SizedBox(height: 10),
                                  TextField(
                                    key: const Key(
                                      'equipment-compatibility-search',
                                    ),
                                    onChanged: (value) =>
                                        setState(() => _query = value),
                                    style: const TextStyle(
                                      color: Color(0xffe8f0f4),
                                      fontSize: 13,
                                    ),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      hintText:
                                          l10n.equipmentCompatibilitySearchHint,
                                      hintStyle: const TextStyle(
                                        color: Color(0xff78909c),
                                      ),
                                      prefixIcon: const Icon(
                                        Icons.search,
                                        size: 18,
                                        color: Color(0xff8ba2af),
                                      ),
                                      filled: true,
                                      fillColor: const Color(0xff081923),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(7),
                                        borderSide: const BorderSide(
                                          color: Color(0xff315064),
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(7),
                                        borderSide: const BorderSide(
                                          color: Color(0xff315064),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _SlotFilters(
                                    selected: _slotFilter,
                                    onChanged: (value) =>
                                        setState(() => _slotFilter = value),
                                  ),
                                ],
                              ),
                            ),
                          Expanded(
                            child: !widget.state.hasEquipmentCompatibilityData
                                ? const _RulesWaiting()
                                : rows.isEmpty
                                ? _EmptyResult(ownedOnly: _ownedOnly)
                                : _CompatibilityList(
                                    state: widget.state,
                                    rows: rows,
                                  ),
                          ),
                          const _SourceNote(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.equipment,
    required this.iconId,
    required this.ownedCount,
    required this.allCount,
    required this.equipmentOwnedCount,
    required this.regularCount,
    required this.expansionCount,
    required this.category,
    required this.onClose,
  });

  final MasterSlotItem equipment;
  final int iconId;
  final int ownedCount;
  final int allCount;
  final int equipmentOwnedCount;
  final int regularCount;
  final int expansionCount;
  final String category;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xff173546),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Padding(
              padding: const EdgeInsets.all(7),
              child: EquipmentTypeIconImage(
                iconId: iconId,
                width: 30,
                height: 30,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  equipment.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xfff2f7f9),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  l10n.equipmentCompatibilitySummary(ownedCount, allCount),
                  style: const TextStyle(
                    color: Color(0xff8ba2af),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 8,
                  runSpacing: 3,
                  children: [
                    Text(
                      l10n.equipmentCompatibilityOfficialId(equipment.id),
                      style: const TextStyle(
                        color: Color(0xff9bb0bb),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      l10n.equipmentCompatibilityCategory(category),
                      style: const TextStyle(
                        color: Color(0xff9bb0bb),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      l10n.equipmentCompatibilityOwnedCount(
                        equipmentOwnedCount,
                      ),
                      style: const TextStyle(
                        color: Color(0xff9bb0bb),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      l10n.equipmentCompatibilityRegularCount(regularCount),
                      style: const TextStyle(
                        color: Color(0xff72d8ae),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      l10n.equipmentCompatibilityExpansionCount(expansionCount),
                      style: const TextStyle(
                        color: Color(0xffffc85a),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            key: const Key('equipment-compatibility-close'),
            tooltip: l10n.close,
            onPressed: onClose,
            icon: const Icon(Icons.close, color: Color(0xffc7d5dc)),
          ),
        ],
      ),
    );
  }
}

class _ScopeTabs extends StatelessWidget {
  const _ScopeTabs({
    required this.ownedOnly,
    required this.ownedCount,
    required this.allCount,
    required this.onChanged,
  });

  final bool ownedOnly;
  final int ownedCount;
  final int allCount;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xff081923),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xff315064)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ScopeTab(
              key: const Key('equipment-compatibility-tab-owned'),
              selected: ownedOnly,
              label: l10n.equipmentCompatibilityOwnedTab(ownedCount),
              onTap: () => onChanged(true),
            ),
          ),
          Expanded(
            child: _ScopeTab(
              key: const Key('equipment-compatibility-tab-all'),
              selected: !ownedOnly,
              label: l10n.equipmentCompatibilityAllTab(allCount),
              onTap: () => onChanged(false),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScopeTab extends StatelessWidget {
  const _ScopeTab({
    super.key,
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? const Color(0xff2b7180) : Colors.transparent,
    borderRadius: BorderRadius.circular(15),
    child: InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: onTap,
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xfff2f7f9) : const Color(0xff8ba2af),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ),
  );
}

class _SlotFilters extends StatelessWidget {
  const _SlotFilters({required this.selected, required this.onChanged});

  final EquipmentCompatibilitySlotFilter selected;
  final ValueChanged<EquipmentCompatibilitySlotFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    return Row(
      children: [
        for (final value in EquipmentCompatibilitySlotFilter.values) ...[
          _FilterChip(
            key: Key('equipment-compatibility-filter-${value.name}'),
            selected: selected == value,
            label: switch (value) {
              EquipmentCompatibilitySlotFilter.all =>
                l10n.equipmentCompatibilityAllSlots,
              EquipmentCompatibilitySlotFilter.regular =>
                l10n.equipmentCompatibilityRegularSlot,
              EquipmentCompatibilitySlotFilter.expansion =>
                l10n.equipmentCompatibilityExpansionSlot,
            },
            onTap: () => onChanged(value),
          ),
          if (value != EquipmentCompatibilitySlotFilter.values.last)
            const SizedBox(width: 6),
        ],
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    super.key,
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? const Color(0xff173f4c) : const Color(0xff102a38),
    borderRadius: BorderRadius.circular(6),
    child: InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xff69d2cf) : const Color(0xff9bb0bb),
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ),
  );
}

class _CompatibilityList extends StatelessWidget {
  const _CompatibilityList({required this.state, required this.rows});

  final GameState state;
  final List<EquipmentCompatibilityShipRow> rows;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    int? previousTypeId;
    for (final row in rows) {
      if (row.shipMaster.shipTypeId != previousTypeId) {
        previousTypeId = row.shipMaster.shipTypeId;
        children.add(_TypeHeader(name: row.shipTypeName));
      }
      children.add(_ShipRow(state: state, row: row));
    }
    return ListView(
      key: const Key('equipment-compatibility-results'),
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 14),
      children: children,
    );
  }
}

class _TypeHeader extends StatelessWidget {
  const _TypeHeader({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
      child: Text(
        name.isEmpty ? l10n.otherType : name,
        style: const TextStyle(
          color: Color(0xff69d2cf),
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ShipRow extends StatelessWidget {
  const _ShipRow({required this.state, required this.row});

  final GameState state;
  final EquipmentCompatibilityShipRow row;

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    final compatibility = row.compatibility;
    final slotLabel =
        compatibility.canEquipInRegularSlot &&
            compatibility.canEquipInExpansionSlot
        ? l10n.equipmentCompatibilityBothSlots
        : compatibility.canEquipInRegularSlot
        ? l10n.equipmentCompatibilityRegularSlot
        : l10n.equipmentCompatibilityExpansionSlot;
    final ownedText = row.ownedShips.isEmpty
        ? null
        : l10n.equipmentCompatibilityOwnedLevels(
            row.ownedShips.map((ship) => ship.level).join(' / '),
          );
    final fleetText = row.fleetNumbers.isEmpty
        ? null
        : l10n.equipmentCompatibilityFleetNumbers(row.fleetNumbers.join('、'));

    return Container(
      key: Key('equipment-compatibility-ship-${row.shipMaster.id}'),
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: const Color(0xff102a38),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0xff294052)),
      ),
      child: Row(
        children: [
          ShipPortrait(
            ship: row.shipMaster,
            serverOrigin: state.serverOrigin,
            width: 74,
            height: 48,
            decodeHeight: (50 * MediaQuery.devicePixelRatioOf(context)).ceil(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.shipMaster.name,
                  style: const TextStyle(
                    color: Color(0xffe8f0f4),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${row.shipTypeName} · ${l10n.equipmentCompatibilityShipClassId(row.shipMaster.classTypeId)}',
                  style: const TextStyle(
                    color: Color(0xff78909c),
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (ownedText != null || fleetText != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    [ownedText, fleetText].whereType<String>().join(' · '),
                    style: const TextStyle(
                      color: Color(0xff9bb0bb),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                slotLabel,
                style: const TextStyle(
                  color: Color(0xff72d8ae),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (compatibility.expansionSlotMinimumImprovement > 0) ...[
                const SizedBox(height: 3),
                Text(
                  l10n.equipmentCompatibilityExpansionRequirement(
                    compatibility.expansionSlotMinimumImprovement,
                  ),
                  style: const TextStyle(
                    color: Color(0xffffc85a),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyResult extends StatelessWidget {
  const _EmptyResult({required this.ownedOnly});

  final bool ownedOnly;

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          ownedOnly
              ? l10n.equipmentCompatibilityEmptyOwned
              : l10n.equipmentCompatibilityEmptyAll,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xff8ba2af), fontSize: 12),
        ),
      ),
    );
  }
}

class _RulesWaiting extends StatelessWidget {
  const _RulesWaiting();

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          l10n.equipmentCompatibilityRulesWaiting,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xff8ba2af), fontSize: 12),
        ),
      ),
    );
  }
}

class _SourceNote extends StatelessWidget {
  const _SourceNote();

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 7, 14, 10),
      child: Text(
        l10n.equipmentCompatibilitySource,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xff78909c), fontSize: 9),
      ),
    );
  }
}

String _equipmentCategoryLabel(
  EquipmentInventoryCategory value,
  AppLocalizations l10n,
) => switch (value) {
  EquipmentInventoryCategory.all => l10n.all,
  EquipmentInventoryCategory.mainGun => l10n.equipmentMainGun,
  EquipmentInventoryCategory.secondaryGun => l10n.equipmentSecondaryGun,
  EquipmentInventoryCategory.machineGun => l10n.equipmentMachineGun,
  EquipmentInventoryCategory.torpedo => l10n.equipmentTorpedo,
  EquipmentInventoryCategory.carrierAircraft => l10n.equipmentCarrierAircraft,
  EquipmentInventoryCategory.seaplane => l10n.equipmentSeaplane,
  EquipmentInventoryCategory.landBasedAircraft =>
    l10n.equipmentLandBasedAircraft,
  EquipmentInventoryCategory.antiSubmarine => l10n.antiSub,
  EquipmentInventoryCategory.radar => l10n.equipmentRadar,
  EquipmentInventoryCategory.landingTransport => l10n.equipmentLandingTransport,
  EquipmentInventoryCategory.support => l10n.equipmentSupport,
};
