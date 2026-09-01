import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import '../fleet/equipment_type_icon.dart';
import '../fleet/ship_portrait.dart';
import '../game_state/game_state.dart';
import '../widgets/standalone_text_input_dialog.dart';
import 'equipment_compatibility_projection.dart';

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
  int? _shipTypeId;
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
      shipTypeId: _shipTypeId,
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
                            onClose: widget.onClose,
                          ),
                          if (widget.state.hasEquipmentCompatibilityData)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 2, 14, 10),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      _ToolButton(
                                        key: const Key(
                                          'equipment-compatibility-ship-type-button',
                                        ),
                                        icon: Icons.filter_alt_rounded,
                                        tooltip: l10n.allTypes,
                                        active: _shipTypeId != null,
                                        onPressed: () =>
                                            _showShipTypeDialog(allRows),
                                      ),
                                      const SizedBox(width: 4),
                                      _ToolButton(
                                        key: const Key(
                                          'equipment-compatibility-search-button',
                                        ),
                                        icon: Icons.search_rounded,
                                        tooltip: l10n
                                            .equipmentCompatibilitySearchHint,
                                        active: _query.isNotEmpty,
                                        onPressed: _showSearchDialog,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _ScopeTabs(
                                          ownedOnly: _ownedOnly,
                                          ownedCount: ownedCount,
                                          allCount: allCount,
                                          onChanged: (value) => setState(
                                            () => _ownedOnly = value,
                                          ),
                                        ),
                                      ),
                                    ],
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

  Future<void> _showShipTypeDialog(
    List<EquipmentCompatibilityShipRow> allRows,
  ) async {
    final shipTypes = <int, String>{
      for (final row in allRows) row.shipMaster.shipTypeId: row.shipTypeName,
    };
    final selected = await showDialog<int>(
      context: context,
      builder: (context) => _ShipTypeDialog(
        shipTypes: shipTypes,
        selectedShipTypeId: _shipTypeId,
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => _shipTypeId = selected == 0 ? null : selected);
  }

  Future<void> _showSearchDialog() async {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    final value = await showDialog<String>(
      context: context,
      builder: (context) => StandaloneTextInputDialog(
        key: const Key('equipment-compatibility-search-dialog'),
        title: l10n.equipmentCompatibilitySearchHint,
        label: l10n.equipmentCompatibilitySearchHint,
        initialValue: _query,
        fieldKey: const Key('equipment-compatibility-search-dialog-field'),
        cancelKey: const Key('equipment-compatibility-search-dialog-cancel'),
        confirmKey: const Key('equipment-compatibility-search-dialog-confirm'),
        cancelLabel: l10n.cancel,
        confirmLabel: l10n.confirm,
      ),
    );
    if (value == null || !mounted) return;
    setState(() => _query = value.trim());
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.equipment,
    required this.iconId,
    required this.onClose,
  });

  final MasterSlotItem equipment;
  final int iconId;
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
            child: Text(
              equipment.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xfff2f7f9),
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
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

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    isSelected: active,
    visualDensity: VisualDensity.compact,
    style: IconButton.styleFrom(
      backgroundColor: active
          ? const Color(0xff2b7180)
          : const Color(0xff102a38),
      foregroundColor: active
          ? const Color(0xfff2f7f9)
          : const Color(0xff9bb0bb),
      side: BorderSide(
        color: active ? const Color(0xff69d2cf) : const Color(0xff315064),
      ),
    ),
    onPressed: onPressed,
    icon: Icon(icon, size: 19),
  );
}

class _ShipTypeDialog extends StatelessWidget {
  const _ShipTypeDialog({
    required this.shipTypes,
    required this.selectedShipTypeId,
  });

  final Map<int, String> shipTypes;
  final int? selectedShipTypeId;

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    return Dialog(
      key: const Key('equipment-compatibility-ship-type-dialog'),
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: Colors.transparent,
      child: Container(
        width: 360,
        constraints: const BoxConstraints(maxHeight: 520),
        decoration: BoxDecoration(
          color: const Color(0xff101d27),
          border: Border.all(color: const Color(0xff385064)),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 22, spreadRadius: 2),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 52,
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  const Icon(
                    Icons.filter_alt_rounded,
                    size: 20,
                    color: Color(0xff69d2cf),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.allTypes,
                    style: const TextStyle(
                      color: Color(0xfff2f7f9),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: l10n.close,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xffc7d5dc),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xff385064)),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(10),
                children: [
                  _ShipTypeOption(
                    key: const Key(
                      'equipment-compatibility-ship-type-option-all',
                    ),
                    label: l10n.all,
                    selected: selectedShipTypeId == null,
                    onTap: () => Navigator.of(context).pop(0),
                  ),
                  for (final entry in shipTypes.entries) ...[
                    const SizedBox(height: 5),
                    _ShipTypeOption(
                      key: Key(
                        'equipment-compatibility-ship-type-option-${entry.key}',
                      ),
                      label: entry.value.isEmpty ? l10n.otherType : entry.value,
                      selected: selectedShipTypeId == entry.key,
                      onTap: () => Navigator.of(context).pop(entry.key),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShipTypeOption extends StatelessWidget {
  const _ShipTypeOption({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? const Color(0xff1d5f91) : const Color(0xff172a38),
    borderRadius: BorderRadius.circular(7),
    child: InkWell(
      borderRadius: BorderRadius.circular(7),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: const Color(0xffe8f0f4),
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                size: 19,
                color: Color(0xff7fd6ff),
              ),
          ],
        ),
      ),
    ),
  );
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
      key: const Key('equipment-compatibility-scope-tabs'),
      height: 32,
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
