import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import '../fleet/ship_portrait.dart';
import '../fleet/ship_status_style.dart';
import '../game_state/game_state.dart';
import '../game_state/game_state_controller.dart';
import '../widgets/frozen_data_table.dart';
import 'owned_inventory_projection.dart';
import 'owned_inventory_sort_state.dart';

class OwnedInventoryPage extends StatefulWidget {
  const OwnedInventoryPage({
    super.key,
    required this.controller,
    this.showShips,
    this.onSectionChanged,
    this.showSectionControl = true,
  });

  final GameStateController controller;
  final bool? showShips;
  final ValueChanged<bool>? onSectionChanged;
  final bool showSectionControl;

  @override
  State<OwnedInventoryPage> createState() => _OwnedInventoryPageState();
}

class _OwnedInventoryPageState extends State<OwnedInventoryPage> {
  bool _localShowShips = true;
  ShipInventoryCategory _shipCategory = ShipInventoryCategory.all;
  EquipmentInventoryCategory _equipmentCategory =
      EquipmentInventoryCategory.all;
  ShipInventorySortState _sortState = const ShipInventorySortState.initial();
  late GameState _state;
  late _InventoryDependencies _inventoryDependencies;
  List<ShipInventoryRow>? _cachedShipRows;
  List<EquipmentInventoryGroup>? _cachedEquipmentGroups;
  final _equipmentRowHeightCache = _EquipmentRowHeightCache();

  bool get _showShips => widget.showShips ?? _localShowShips;

  @override
  void initState() {
    super.initState();
    _state = widget.controller.state;
    _inventoryDependencies = _InventoryDependencies.from(_state);
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(covariant OwnedInventoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.controller, widget.controller)) return;
    oldWidget.controller.removeListener(_handleControllerChanged);
    _state = widget.controller.state;
    _inventoryDependencies = _InventoryDependencies.from(_state);
    _clearDerivedData();
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    super.dispose();
  }

  void _handleControllerChanged() {
    final nextState = widget.controller.state;
    final nextDependencies = _InventoryDependencies.from(nextState);
    final shipProjectionChanged = !_inventoryDependencies.matchesShipProjection(
      nextDependencies,
    );
    final equipmentProjectionChanged = !_inventoryDependencies
        .matchesEquipmentProjection(nextDependencies);
    final serverOriginChanged =
        _inventoryDependencies.serverOrigin != nextDependencies.serverOrigin;
    if (!shipProjectionChanged &&
        !equipmentProjectionChanged &&
        !serverOriginChanged) {
      return;
    }

    _state = nextState;
    _inventoryDependencies = nextDependencies;
    if (shipProjectionChanged) _cachedShipRows = null;
    if (equipmentProjectionChanged) _cachedEquipmentGroups = null;

    final activeTableChanged = _showShips
        ? shipProjectionChanged || serverOriginChanged
        : equipmentProjectionChanged;
    if (activeTableChanged) setState(() {});
  }

  void _clearDerivedData() {
    _cachedShipRows = null;
    _cachedEquipmentGroups = null;
  }

  List<ShipInventoryRow> _shipRows() =>
      _cachedShipRows ??= OwnedInventoryProjection(_state).shipRows(
        category: _shipCategory,
        sortCriteria: _sortState.effectiveCriteria,
      );

  List<EquipmentInventoryGroup> _equipmentGroups() =>
      _cachedEquipmentGroups ??= OwnedInventoryProjection(
        _state,
      ).equipmentGroups(category: _equipmentCategory);

  void _changeSection(bool value) {
    if (widget.showShips == null) {
      setState(() => _localShowShips = value);
    }
    widget.onSectionChanged?.call(value);
  }

  void _tapShipSort(ShipInventorySortField field) {
    setState(() {
      _sortState = _sortState.tap(field);
      _cachedShipRows = null;
    });
  }

  void _longPressShipSort(ShipInventorySortField field) {
    final nextState = _sortState.longPress(field);
    if (identical(nextState, _sortState)) return;
    setState(() {
      _sortState = nextState;
      _cachedShipRows = null;
    });
  }

  void _restoreDefaultShipSort() {
    setState(() {
      _sortState = _sortState.restoreDefault();
      _cachedShipRows = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    final shipRows = _showShips ? _shipRows() : const <ShipInventoryRow>[];
    final equipmentGroups = _showShips
        ? const <EquipmentInventoryGroup>[]
        : _equipmentGroups();
    return ColoredBox(
      color: const Color(0xff081923),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.showSectionControl) ...[
              Align(
                alignment: Alignment.centerRight,
                child: OwnedInventorySegmented(
                  showShips: _showShips,
                  shipCount: _state.ships.length,
                  equipmentCount: _state.equipmentCapacityUsed,
                  onChanged: _changeSection,
                ),
              ),
              const SizedBox(height: 4),
            ],
            if (_showShips)
              _FilterStrip<ShipInventoryCategory>(
                values: ShipInventoryCategory.values,
                selected: _shipCategory,
                resultCount: shipRows.length,
                label: (value) => _shipCategoryLabel(value, l10n),
                keyFor: (value) => Key('ship-filter-${value.name}'),
                actionLabel: l10n.restoreDefaultOrder,
                actionIcon: Icons.restore,
                actionKey: const Key('owned-inventory-sort-reset'),
                onAction: _restoreDefaultShipSort,
                onSelected: (value) => setState(() {
                  _shipCategory = value;
                  _cachedShipRows = null;
                }),
              )
            else
              _FilterStrip<EquipmentInventoryCategory>(
                values: EquipmentInventoryCategory.values,
                selected: _equipmentCategory,
                resultCount: equipmentGroups.length,
                resultSuffix: l10n.inventoryTypeSuffix,
                label: (value) => _equipmentCategoryLabel(value, l10n),
                keyFor: (value) => Key('equipment-filter-${value.name}'),
                onSelected: (value) => setState(() {
                  _equipmentCategory = value;
                  _cachedEquipmentGroups = null;
                }),
              ),
            const SizedBox(height: 4),
            Expanded(
              child: _showShips
                  ? _ShipInventoryTable(
                      state: _state,
                      rows: shipRows,
                      sortState: _sortState,
                      onSort: _tapShipSort,
                      onLongPressSort: _longPressShipSort,
                    )
                  : _EquipmentInventoryTable(
                      groups: equipmentGroups,
                      rowHeightCache: _equipmentRowHeightCache,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InventoryDependencies {
  const _InventoryDependencies({
    required this.ships,
    required this.fleets,
    required this.slotItems,
    required this.masterShips,
    required this.masterShipTypes,
    required this.masterSlotItems,
    required this.serverOrigin,
  });

  factory _InventoryDependencies.from(GameState state) =>
      _InventoryDependencies(
        ships: state.ships,
        fleets: state.fleets,
        slotItems: state.slotItems,
        masterShips: state.masterShips,
        masterShipTypes: state.masterShipTypes,
        masterSlotItems: state.masterSlotItems,
        serverOrigin: state.serverOrigin,
      );

  final Object ships;
  final Object fleets;
  final Object slotItems;
  final Object masterShips;
  final Object masterShipTypes;
  final Object masterSlotItems;
  final String serverOrigin;

  bool matchesShipProjection(_InventoryDependencies other) =>
      identical(ships, other.ships) &&
      identical(fleets, other.fleets) &&
      identical(slotItems, other.slotItems) &&
      identical(masterShips, other.masterShips) &&
      identical(masterShipTypes, other.masterShipTypes) &&
      identical(masterSlotItems, other.masterSlotItems);

  bool matchesEquipmentProjection(_InventoryDependencies other) =>
      identical(ships, other.ships) &&
      identical(slotItems, other.slotItems) &&
      identical(masterShips, other.masterShips) &&
      identical(masterSlotItems, other.masterSlotItems);
}

class OwnedInventorySegmented extends StatelessWidget {
  const OwnedInventorySegmented({
    super.key,
    required this.showShips,
    required this.shipCount,
    required this.equipmentCount,
    required this.onChanged,
  });
  final bool showShips;
  final int shipCount;
  final int equipmentCount;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    return Container(
      key: const Key('owned-inventory-segmented'),
      width: 260,
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xff0b202d),
        border: Border.all(color: const Color(0xff315064)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegmentButton(
              key: const Key('owned-inventory-tab-ships'),
              selected: showShips,
              label: '${l10n.shipGirl} $shipCount',
              onTap: () => onChanged(true),
            ),
          ),
          Expanded(
            child: _SegmentButton(
              key: const Key('owned-inventory-tab-equipment'),
              selected: !showShips,
              label: '${l10n.equipment} $equipmentCount',
              onTap: () => onChanged(false),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
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
    color: selected ? const Color(0xff8a6628) : Colors.transparent,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? const Color(0xffffdc88)
                  : const Color(0xff9fb3bf),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    ),
  );
}

class _FilterStrip<T> extends StatelessWidget {
  const _FilterStrip({
    required this.values,
    required this.selected,
    required this.resultCount,
    required this.label,
    required this.keyFor,
    required this.onSelected,
    this.resultSuffix = '',
    this.actionLabel,
    this.actionIcon,
    this.actionKey,
    this.onAction,
  });
  final List<T> values;
  final T selected;
  final int resultCount;
  final String resultSuffix;
  final String Function(T) label;
  final Key Function(T) keyFor;
  final ValueChanged<T> onSelected;
  final String? actionLabel;
  final IconData? actionIcon;
  final Key? actionKey;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    return SizedBox(
      height: 28,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final value in values) ...[
              _FilterChip(
                key: keyFor(value),
                label: label(value),
                selected: value == selected,
                onTap: () => onSelected(value),
              ),
              const SizedBox(width: 6),
            ],
            if (actionLabel != null && onAction != null) ...[
              if (actionIcon == null)
                _FilterChip(
                  key: actionKey,
                  label: actionLabel!,
                  selected: false,
                  onTap: onAction!,
                )
              else
                _FilterActionButton(
                  key: actionKey,
                  label: actionLabel!,
                  icon: actionIcon!,
                  onTap: onAction!,
                ),
              const SizedBox(width: 6),
            ],
            Text(
              l10n.inventoryFilterResults,
              style: const TextStyle(color: Color(0xff8ba2af), fontSize: 12),
            ),
            Text(
              '$resultCount$resultSuffix',
              style: const TextStyle(
                color: Color(0xffffc85a),
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterActionButton extends StatelessWidget {
  const _FilterActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    onTap: onTap,
    excludeSemantics: true,
    child: Tooltip(
      message: label,
      child: SizedBox(
        width: 34,
        height: 28,
        child: Material(
          color: const Color(0xff102936),
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: Color(0xff315064)),
            borderRadius: BorderRadius.circular(9),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(9),
            child: Center(
              child: Icon(icon, size: 19, color: const Color(0xffffc85a)),
            ),
          ),
        ),
      ),
    ),
  );
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 28,
    child: Material(
      color: selected ? const Color(0xff60491f) : const Color(0xff102936),
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: selected ? const Color(0xffb7832a) : const Color(0xff315064),
        ),
        borderRadius: BorderRadius.circular(9),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected
                    ? const Color(0xffffcf62)
                    : const Color(0xffa8bac4),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _ShipInventoryTable extends StatelessWidget {
  const _ShipInventoryTable({
    required this.state,
    required this.rows,
    required this.sortState,
    required this.onSort,
    required this.onLongPressSort,
  });
  final GameState state;
  final List<ShipInventoryRow> rows;
  final ShipInventorySortState sortState;
  final ValueChanged<ShipInventorySortField> onSort;
  final ValueChanged<ShipInventorySortField> onLongPressSort;

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    const fields = ShipInventorySortField.values;
    final labels = <String>[
      l10n.shipName,
      l10n.shipType,
      l10n.speed,
      l10n.level,
      l10n.condition,
      'HP',
      l10n.firepower,
      l10n.torpedo,
      l10n.antiAir,
      l10n.armor,
      l10n.luck,
      l10n.evasion,
      l10n.antiSub,
      l10n.los,
      l10n.equipment,
      l10n.lockedStatus,
    ];
    final widths = <double>[
      96,
      78,
      78,
      78,
      78,
      78,
      78,
      78,
      78,
      78,
      78,
      78,
      78,
      210,
      52,
    ];
    Widget header(ShipInventorySortField field, String label, {Key? key}) {
      final lockedIndex = sortState.lockedCriteria.indexWhere(
        (criterion) => criterion.field == field,
      );
      final locked = lockedIndex >= 0;
      final temporarilyActive = sortState.activeCriterion?.field == field;
      final active = locked || temporarilyActive;
      final criterion = locked
          ? sortState.lockedCriteria[lockedIndex]
          : temporarilyActive
          ? sortState.activeCriterion
          : null;
      final priority = locked
          ? lockedIndex + 1
          : temporarilyActive && sortState.lockedCriteria.isNotEmpty
          ? sortState.lockedCriteria.length + 1
          : null;
      return _SortableHeader(
        key: key ?? Key('owned-inventory-sort-${field.name}'),
        label: label,
        active: active,
        locked: locked,
        priority: priority,
        descending: criterion?.descending ?? true,
        onTap: () => onSort(field),
        onLongPress: () => onLongPressSort(field),
      );
    }

    return FrozenDataTable(
      key: const Key('owned-inventory-table-ships'),
      keyPrefix: 'owned-inventory',
      rowHeights: List<double>.filled(rows.length, 56),
      frozenColumnWidths: const <double>[240],
      frozenHeaders: <Widget>[
        header(
          fields.first,
          labels.first,
          key: const Key('ship-table-frozen-header'),
        ),
      ],
      frozenCells: (index) => <Widget>[
        _ShipNameCell(state: state, row: rows[index]),
      ],
      scrollableColumnWidths: widths,
      scrollableHeaders: [
        for (var i = 1; i < fields.length; i++) header(fields[i], labels[i]),
      ],
      scrollableCells: (index) {
        final row = rows[index];
        final ship = row.ship;
        return <Widget>[
          _TextCell(row.type?.name ?? '—'),
          _TextCell(_speedLabel(ship.effectiveSpeed(row.master), l10n)),
          _TextCell('${ship.level}', strong: true),
          _TextCell(
            '${ship.condition}',
            color: shipFatigueColor(ship.condition),
          ),
          _TextCell(
            '${ship.currentHp}/${ship.maxHp}',
            strong: true,
            color: shipHpValueColor(
              ship.maxHp <= 0 ? 0 : ship.currentHp / ship.maxHp,
              isZeroHp: ship.currentHp <= 0,
            ),
          ),
          _TextCell(_statText(ship.firepower, ship.firepowerMax)),
          _TextCell(_statText(ship.torpedo, ship.torpedoMax)),
          _TextCell(_statText(ship.antiAir, ship.antiAirMax)),
          _TextCell(_statText(ship.armor, ship.armorMax)),
          _TextCell(_statText(ship.luck, ship.luckMax)),
          _TextCell('${ship.evasion}'),
          _TextCell('${ship.antiSub}'),
          _TextCell('${ship.lineOfSight}'),
          _ShipEquipmentCell(equipment: row.equipment),
          Center(
            child: ship.locked
                ? const Icon(Icons.lock, size: 14, color: Color(0xffe8eef1))
                : const SizedBox.shrink(),
          ),
        ];
      },
    );
  }
}

class _ShipNameCell extends StatelessWidget {
  const _ShipNameCell({required this.state, required this.row});
  final GameState state;
  final ShipInventoryRow row;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    child: Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: ShipPortrait(
            key: Key('owned-ship-portrait-${row.ship.id}'),
            ship: row.master,
            serverOrigin: state.serverOrigin,
            width: 78,
            height: 51,
            decodeHeight: (53 * MediaQuery.devicePixelRatioOf(context)).ceil(),
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              row.master?.name ?? '—',
              style: const TextStyle(
                color: Color(0xffe8f0f4),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        if (row.fleetNumber != null)
          Text(
            _circledNumber(row.fleetNumber!),
            style: const TextStyle(
              color: Color(0xff59d8ce),
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
      ],
    ),
  );
}

class _ShipEquipmentCell extends StatelessWidget {
  const _ShipEquipmentCell({required this.equipment});
  final List<ShipEquipment> equipment;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
    child: Row(
      children: [
        for (final item in equipment.take(7))
          Padding(
            padding: const EdgeInsets.only(right: 3),
            child: _EquipmentIcon(master: item.master, owned: item.owned),
          ),
      ],
    ),
  );
}

class _EquipmentInventoryTable extends StatefulWidget {
  const _EquipmentInventoryTable({
    required this.groups,
    required this.rowHeightCache,
  });
  final List<EquipmentInventoryGroup> groups;
  final _EquipmentRowHeightCache rowHeightCache;

  @override
  State<_EquipmentInventoryTable> createState() =>
      _EquipmentInventoryTableState();
}

class _EquipmentRowHeightCache {
  List<EquipmentInventoryGroup>? _heightGroups;
  TextScaler? _heightTextScaler;
  TextStyle? _heightDefaultStyle;
  List<double>? _cachedRowHeights;

  List<double> resolve(
    BuildContext context,
    List<EquipmentInventoryGroup> groups,
  ) {
    final textScaler = MediaQuery.textScalerOf(context);
    final defaultStyle = DefaultTextStyle.of(context).style;
    if (identical(_heightGroups, groups) &&
        _heightTextScaler == textScaler &&
        _heightDefaultStyle == defaultStyle &&
        _cachedRowHeights != null) {
      return _cachedRowHeights!;
    }
    _heightGroups = groups;
    _heightTextScaler = textScaler;
    _heightDefaultStyle = defaultStyle;
    return _cachedRowHeights = <double>[
      for (final group in groups)
        _EquipmentInventoryTableState._equipmentRowHeight(context, group),
    ];
  }
}

class _EquipmentInventoryTableState extends State<_EquipmentInventoryTable> {
  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    final groups = widget.groups;
    final rowHeights = widget.rowHeightCache.resolve(context, groups);
    return FrozenDataTable(
      key: const Key('owned-inventory-table-equipment'),
      keyPrefix: 'owned-inventory',
      rowHeights: rowHeights,
      frozenColumnWidths: const <double>[230],
      frozenHeaders: <Widget>[
        _PlainHeader(
          key: const Key('equipment-table-frozen-header'),
          label: l10n.equipmentName,
        ),
      ],
      frozenCells: (index) => <Widget>[
        SizedBox.expand(
          key: Key('equipment-name-row-${groups[index].master.id}'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                _EquipmentIcon(master: groups[index].master),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    groups[index].master.name,
                    style: const TextStyle(
                      color: Color(0xffe8f0f4),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      scrollableColumnWidths: const <double>[118, 270, 560],
      scrollableHeaders: <Widget>[
        _PlainHeader(label: l10n.equipmentTotalRemaining),
        _PlainHeader(label: l10n.equipmentImprovementProficiency),
        _PlainHeader(label: l10n.equipmentUsage),
      ],
      scrollableCells: (index) {
        final group = groups[index];
        final summaries = summarizeEquipmentVariants(group.variants);
        return <Widget>[
          _TextCell('${group.total}（${group.remaining}）', strong: true),
          Align(
            key: Key('equipment-variants-cell-${group.master.id}'),
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Wrap(
                spacing: 12,
                runSpacing: 4,
                alignment: WrapAlignment.start,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final summary in summaries)
                    _EquipmentVariantSummaryView(
                      key: ValueKey<String>(
                        'equipment-${summary.kind.name}-${group.master.id}-${summary.level}',
                      ),
                      summary: summary,
                    ),
                ],
              ),
            ),
          ),
          Align(
            key: Key('equipment-wearings-cell-${group.master.id}'),
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Wrap(
                spacing: 12,
                runSpacing: 4,
                alignment: WrapAlignment.start,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final wearing in group.wearings)
                    Text(
                      key: ValueKey<String>(
                        'equipment-wearing-item-${group.master.id}-${wearing.shipId}',
                      ),
                      'Lv.${wearing.level} ${wearing.shipName} ×${wearing.count}',
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: const TextStyle(
                        color: Color(0xffc7d5dc),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ];
      },
    );
  }

  static double _equipmentRowHeight(
    BuildContext context,
    EquipmentInventoryGroup group,
  ) {
    final summaries = summarizeEquipmentVariants(group.variants);
    final defaultStyle = DefaultTextStyle.of(context).style;
    final variantStyle = defaultStyle.merge(
      const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
    );
    final wearingStyle = defaultStyle.merge(
      const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
    );
    final nameStyle = defaultStyle.merge(
      const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
    );
    final textScaler = MediaQuery.textScalerOf(context);
    final nameHeight = math.max(
      25.0,
      _wrappedTextHeight(group.master.name, nameStyle, textScaler, 182),
    );
    final variantWidths = <double>[
      for (final summary in summaries)
        if (summary.kind == EquipmentVariantSummaryKind.improvement)
          _textWidth(
            '★${summary.level >= 10 ? 'max' : summary.level} ×${summary.count}',
            variantStyle,
            textScaler,
          )
        else
          17 + 2 + _textWidth('×${summary.count}', variantStyle, textScaler),
    ];
    final wearingWidths = <double>[
      for (final wearing in group.wearings)
        _textWidth(
          'Lv.${wearing.level} ${wearing.shipName} ×${wearing.count}',
          wearingStyle,
          textScaler,
        ),
    ];
    final variantHeight = _packedContentHeight(
      variantWidths,
      254,
      math.max(17, _textHeight(variantStyle, textScaler)),
    );
    final wearingHeight = _packedContentHeight(
      wearingWidths,
      544,
      _textHeight(wearingStyle, textScaler),
    );
    return math.max(
      44.0,
      12.0 + math.max(nameHeight, math.max(variantHeight, wearingHeight)),
    );
  }

  static double _packedContentHeight(
    List<double> widths,
    double availableWidth,
    double lineHeight,
  ) {
    final lines = _packedLineCount(widths, availableWidth);
    return lines * lineHeight + math.max(0, lines - 1) * 4;
  }

  static int _packedLineCount(List<double> widths, double availableWidth) {
    if (widths.isEmpty) return 1;
    var lines = 1;
    var used = 0.0;
    for (final rawWidth in widths) {
      final width = math.min(rawWidth, availableWidth);
      final required = used == 0 ? width : width + 12;
      if (used > 0 && used + required > availableWidth) {
        lines++;
        used = width;
      } else {
        used += required;
      }
    }
    return lines;
  }

  static double _textWidth(
    String text,
    TextStyle style,
    TextScaler textScaler,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout();
    return painter.width;
  }

  static double _textHeight(TextStyle style, TextScaler textScaler) {
    final painter = TextPainter(
      text: TextSpan(text: 'Ag舰', style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout();
    return painter.height;
  }

  static double _wrappedTextHeight(
    String text,
    TextStyle style,
    TextScaler textScaler,
    double maxWidth,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout(maxWidth: maxWidth);
    return painter.height;
  }
}

class _EquipmentVariantSummaryView extends StatelessWidget {
  const _EquipmentVariantSummaryView({super.key, required this.summary});
  final EquipmentVariantSummary summary;
  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: Color(0xff68bde6),
      fontSize: 12,
      fontWeight: FontWeight.w800,
    );
    if (summary.kind == EquipmentVariantSummaryKind.improvement) {
      return Text(
        '★${summary.level >= 10 ? 'max' : summary.level} ×${summary.count}',
        style: style,
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/airplane/alv${summary.level.clamp(1, 7)}.png',
          width: 17,
          height: 17,
        ),
        const SizedBox(width: 2),
        Text('×${summary.count}', style: style),
      ],
    );
  }
}

class _EquipmentIcon extends StatelessWidget {
  const _EquipmentIcon({required this.master, this.owned});
  final MasterSlotItem? master;
  final OwnedSlotItem? owned;
  @override
  Widget build(BuildContext context) {
    final iconId = master != null && master!.type.length > 3
        ? master!.type[3]
        : -1;
    final proficiency = owned?.proficiency ?? 0;
    final level = owned?.level;
    return SizedBox(
      width: 25,
      height: 25,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 1,
            top: 1,
            child: Image.asset(
              'assets/images/slotitem/$iconId.png',
              width: 23,
              height: 23,
              errorBuilder: (context, error, stackTrace) => Image.asset(
                'assets/images/slotitem/-1.png',
                width: 23,
                height: 23,
              ),
            ),
          ),
          if (proficiency > 0 || (level != null && level > 0))
            Positioned(
              right: -3,
              top: -4,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (level != null && level > 0)
                    Text(
                      '★${level >= 10 ? 'max' : level}',
                      style: const TextStyle(
                        color: Color(0xff69c8ef),
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        shadows: [Shadow(color: Colors.black, blurRadius: 2)],
                      ),
                    ),
                  if (proficiency > 0)
                    Image.asset(
                      'assets/images/airplane/alv${proficiency.clamp(1, 7)}.png',
                      width: 13,
                      height: 13,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SortableHeader extends StatelessWidget {
  const _SortableHeader({
    super.key,
    required this.label,
    required this.active,
    required this.locked,
    required this.priority,
    required this.descending,
    required this.onTap,
    required this.onLongPress,
  });
  final String label;
  final bool active;
  final bool locked;
  final int? priority;
  final bool descending;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    final semanticsParts = <String>[
      label,
      if (active) descending ? l10n.sortDescending : l10n.sortAscending,
      if (priority != null) l10n.sortPriority(priority!),
      if (active) locked ? l10n.sortLockedState : l10n.sortTemporaryState,
    ];
    final lockAction = CustomSemanticsAction(
      label: locked ? l10n.sortUnlockAction : l10n.sortLockAction,
    );

    return Semantics(
      container: true,
      button: true,
      label: semanticsParts.join(', '),
      hint: locked ? l10n.sortHeaderLockedHint : l10n.sortHeaderHint,
      onTap: onTap,
      onLongPress: onLongPress,
      excludeSemantics: true,
      customSemanticsActions: <CustomSemanticsAction, VoidCallback>{
        lockAction: onLongPress,
      },
      child: Shortcuts(
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.enter, shift: true):
              _LockSortIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            _LockSortIntent: CallbackAction<_LockSortIntent>(
              onInvoke: (_) {
                onLongPress();
                return null;
              },
            ),
          },
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$label${active ? ' ${descending ? '▼' : '▲'}${priority == null ? '' : _circledPriority(priority!)}' : ''}',
                        maxLines: 1,
                        style: TextStyle(
                          color: locked
                              ? const Color(0xff72bded)
                              : active
                              ? const Color(0xffffc85a)
                              : const Color(0xff9fb3bf),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (locked) ...[
                        const SizedBox(width: 3),
                        const Icon(
                          Icons.lock,
                          size: 12,
                          color: Color(0xff72bded),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LockSortIntent extends Intent {
  const _LockSortIntent();
}

String _circledPriority(int priority) => priority >= 1 && priority <= 20
    ? String.fromCharCode(0x245f + priority)
    : '($priority)';

class _PlainHeader extends StatelessWidget {
  const _PlainHeader({super.key, required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        maxLines: 1,
        style: const TextStyle(
          color: Color(0xff9fb3bf),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );
}

class _TextCell extends StatelessWidget {
  const _TextCell(
    this.value, {
    this.color = const Color(0xffd7e3e9),
    this.strong = false,
  });
  final String value;
  final Color color;
  final bool strong;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: strong ? FontWeight.w900 : FontWeight.w600,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    ),
  );
}

String _statText(int current, int maximum) {
  if (maximum <= 0) return '$current';
  return current >= maximum ? '$current/MAX' : '$current/+${maximum - current}';
}

String _speedLabel(int speed, AppLocalizations l10n) => switch (speed) {
  >= 20 => l10n.highSpeedPlus,
  >= 10 => l10n.fastSpeed,
  _ => l10n.slowSpeed,
};
String _circledNumber(int number) => switch (number) {
  1 => '①',
  2 => '②',
  3 => '③',
  4 => '④',
  _ => '($number)',
};
String _shipCategoryLabel(ShipInventoryCategory value, AppLocalizations l10n) =>
    switch (value) {
      ShipInventoryCategory.all => l10n.all,
      ShipInventoryCategory.bbBc => 'BB/BC',
      ShipInventoryCategory.cvCvl => 'CV/CVL',
      ShipInventoryCategory.ca => 'CA',
      ShipInventoryCategory.cl => 'CL',
      ShipInventoryCategory.dd => 'DD',
      ShipInventoryCategory.de => 'DE',
      ShipInventoryCategory.ss => 'SS',
      ShipInventoryCategory.support => 'AV/AO/AS…',
    };
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
