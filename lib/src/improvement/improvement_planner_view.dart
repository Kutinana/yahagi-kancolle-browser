import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import '../fleet/equipment_type_icon.dart';
import '../game_state/game_state.dart';
import '../inventory/owned_inventory_projection.dart';
import '../widgets/filter_controls.dart';
import '../widgets/frozen_data_table.dart';
import 'improvement_dataset.dart';
import 'improvement_planner_controller.dart';
import 'improvement_projection.dart';

class ImprovementPlannerView extends StatelessWidget {
  const ImprovementPlannerView({
    super.key,
    required this.controller,
    required this.state,
  });

  final ImprovementPlannerController controller;
  final GameState state;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xff081923),
    child: AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final rows = controller.rowsFor(state);
        return Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _WeekdayFilter(controller: controller),
              const SizedBox(height: 6),
              Expanded(
                child: rows.isEmpty
                    ? const _EmptyState()
                    : _ImprovementTable(
                        rows: rows,
                        controller: controller,
                        state: state,
                      ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _WeekdayFilter extends StatelessWidget {
  const _WeekdayFilter({required this.controller});
  final ImprovementPlannerController controller;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 34,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _SlidingSegment<int>(
            key: const Key('improvement-weekday-segmented'),
            sliderKey: const Key('improvement-weekday-slider'),
            selected: controller.selectedWeekday,
            segmentWidth: 52,
            options: <_SegmentOption<int>>[
              const _SegmentOption<int>(
                value: improvementAllWeekdays,
                label: '全部',
                key: Key('improvement-weekday-all'),
              ),
              for (var day = 1; day <= 7; day++)
                _SegmentOption<int>(
                  value: day,
                  label: const <String>[
                    '周一',
                    '周二',
                    '周三',
                    '周四',
                    '周五',
                    '周六',
                    '周日',
                  ][day - 1],
                  key: Key('improvement-weekday-$day'),
                ),
            ],
            onChanged: controller.selectWeekday,
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 30,
            height: 30,
            child: Material(
              color: controller.favoritesOnly
                  ? const Color(0xff8a6628)
                  : const Color(0xff102936),
              shape: CircleBorder(
                side: BorderSide(
                  color: controller.favoritesOnly
                      ? const Color(0xffffc85a)
                      : const Color(0xff315064),
                ),
              ),
              child: InkWell(
                key: const Key('improvement-favorites-only'),
                customBorder: const CircleBorder(),
                onTap: controller.toggleFavoritesOnly,
                child: Icon(
                  controller.favoritesOnly ? Icons.star : Icons.star_border,
                  size: 18,
                  color: const Color(0xffffc85a),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          HeaderFilterIconButton(
            key: const Key('improvement-search-button'),
            icon: Icons.search,
            active: controller.hasSearch,
            tooltip: '搜索装备',
            onPressed: () => _showImprovementSearch(context, controller),
          ),
          const SizedBox(width: 4),
          HeaderFilterIconButton(
            key: const Key('improvement-filter-button'),
            icon: Icons.filter_alt_outlined,
            active: controller.hasFilters,
            tooltip: '筛选装备',
            onPressed: () => _showImprovementFilters(context, controller),
          ),
        ],
      ),
    ),
  );
}

Future<void> _showImprovementSearch(
  BuildContext context,
  ImprovementPlannerController controller,
) => showDialog<void>(
  context: context,
  builder: (_) => _ImprovementSearchDialog(controller: controller),
);

class _ImprovementSearchDialog extends StatefulWidget {
  const _ImprovementSearchDialog({required this.controller});

  final ImprovementPlannerController controller;

  @override
  State<_ImprovementSearchDialog> createState() =>
      _ImprovementSearchDialogState();
}

class _ImprovementSearchDialogState extends State<_ImprovementSearchDialog> {
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.controller.query);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('搜索装备'),
    content: TextField(
      key: const Key('improvement-search-field'),
      controller: _textController,
      autofocus: true,
      onChanged: widget.controller.setQuery,
      decoration: const InputDecoration(
        hintText: '搜索装备名称',
        prefixIcon: Icon(Icons.search),
      ),
    ),
    actions: [
      TextButton(
        key: const Key('improvement-search-clear'),
        onPressed: () {
          _textController.clear();
          widget.controller.setQuery('');
        },
        child: const Text('清除'),
      ),
      FilledButton(
        key: const Key('improvement-search-close'),
        onPressed: () => Navigator.pop(context),
        child: const Text('完成'),
      ),
    ],
  );
}

Future<void> _showImprovementFilters(
  BuildContext context,
  ImprovementPlannerController controller,
) {
  final content = _ImprovementFilterSheet(controller: controller);
  if (MediaQuery.sizeOf(context).width < 600) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xff142735),
      builder: (_) => SafeArea(child: content),
    );
  }
  return showDialog<void>(
    context: context,
    builder: (_) => Dialog(child: SizedBox(width: 520, child: content)),
  );
}

class _ImprovementFilterSheet extends StatelessWidget {
  const _ImprovementFilterSheet({required this.controller});

  final ImprovementPlannerController controller;

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    return AnimatedBuilder(
      key: const Key('improvement-filter-sheet'),
      animation: controller,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '筛选装备',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                TextButton(
                  key: const Key('improvement-filter-clear'),
                  onPressed: controller.clearFilters,
                  child: const Text('全部清除'),
                ),
                IconButton(
                  key: const Key('improvement-filter-close'),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('装备分类'),
            const SizedBox(height: 5),
            Wrap(
              runSpacing: 5,
              children: [
                for (final category in EquipmentInventoryCategory.values)
                  CompactFilterChip(
                    key: Key('improvement-filter-equipment-${category.name}'),
                    label: _equipmentCategoryLabel(category, l10n),
                    selected: controller.equipmentCategory == category,
                    onTap: () => controller.selectEquipmentCategory(category),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            const Text('进化状态'),
            const SizedBox(height: 5),
            Wrap(
              runSpacing: 5,
              children: [
                for (final option
                    in const <(ImprovementEvolutionFilter, String)>[
                      (ImprovementEvolutionFilter.all, '全部'),
                      (ImprovementEvolutionFilter.evolvable, '可进化'),
                      (ImprovementEvolutionFilter.notEvolvable, '不可进化'),
                    ])
                  CompactFilterChip(
                    key: Key('improvement-filter-evolution-${option.$1.name}'),
                    label: option.$2,
                    selected: controller.evolutionFilter == option.$1,
                    onTap: () => controller.selectEvolutionFilter(option.$1),
                  ),
              ],
            ),
          ],
        ),
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

class _SegmentOption<T> {
  const _SegmentOption({
    required this.value,
    required this.label,
    required this.key,
  });
  final T value;
  final String label;
  final Key key;
}

class _SlidingSegment<T> extends StatelessWidget {
  const _SlidingSegment({
    super.key,
    required this.sliderKey,
    required this.selected,
    required this.segmentWidth,
    required this.options,
    required this.onChanged,
  });
  final Key sliderKey;
  final T selected;
  final double segmentWidth;
  final List<_SegmentOption<T>> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = math.max(
      0,
      options.indexWhere((item) => item.value == selected),
    );
    return SizedBox(
      width: segmentWidth * options.length,
      height: 30,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xff102936),
          border: Border.all(color: const Color(0xff315064)),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              key: sliderKey,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              left: selectedIndex * segmentWidth + 2,
              top: 2,
              width: segmentWidth - 4,
              height: 24,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xff8a6628),
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
            ),
            Row(
              children: [
                for (final option in options)
                  SizedBox(
                    width: segmentWidth,
                    height: 28,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        key: option.key,
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => onChanged(option.value),
                        child: Center(
                          child: Text(
                            option.label,
                            style: TextStyle(
                              color: option.value == selected
                                  ? const Color(0xffffdc88)
                                  : const Color(0xffa8bac4),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ImprovementTable extends StatelessWidget {
  const _ImprovementTable({
    required this.rows,
    required this.controller,
    required this.state,
  });
  final List<ImprovementPlannerRow> rows;
  final ImprovementPlannerController controller;
  final GameState state;

  MasterSlotItem? _master(int id) => state.masterSlotItems[id];
  String _name(int id) => _master(id)?.name ?? '#$id';
  int _icon(int id) {
    final type = _master(id)?.type ?? const <int>[];
    return type.length > 3 ? type[3] : -1;
  }

  List<String> _secretaryValues(ImprovementPlannerRow row) {
    final routes = row.upgradeRoutes;
    if (routes.isEmpty) return row.secretaryLabels;
    final hasMultipleRoutes = routes.length > 1;
    return <String>[
      for (var routeIndex = 0; routeIndex < routes.length; routeIndex++)
        for (final secretary in routes[routeIndex].secretaryLabels)
          '$secretary${_routeMarker(routeIndex, hasMultipleRoutes)}',
    ];
  }

  int _secretaryLineCount(List<String> values) {
    if (values.isEmpty) return 1;
    const availableWidth = 174.0;
    const spacing = 10.0;
    var lines = 1;
    var usedWidth = 0.0;
    for (final value in values) {
      final painter = TextPainter(
        text: TextSpan(text: value, style: _cellStyle),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout();
      final requiredWidth = painter.width + (usedWidth == 0 ? 0 : spacing);
      if (usedWidth > 0 && usedWidth + requiredWidth > availableWidth) {
        lines += 1;
        usedWidth = painter.width;
      } else {
        usedWidth += requiredWidth;
      }
    }
    return lines;
  }

  double _rowHeight(ImprovementPlannerRow row) {
    final routes = row.upgradeRoutes;
    return math.max(
      FrozenDataTable.minimumRowHeight,
      8 +
          <double>[
            24.0 * row.entry.stage0.length,
            24.0 * row.entry.stage1.length,
            24.0 *
                routes.fold<int>(
                  0,
                  (sum, route) => sum + math.max(1, route.upgrade.items.length),
                ),
            24.0 * _secretaryLineCount(_secretaryValues(row)),
            24.0 * math.max(1, routes.length),
          ].reduce(math.max),
    );
  }

  @override
  Widget build(BuildContext context) {
    final heights = <double>[for (final row in rows) _rowHeight(row)];
    return FrozenDataTable(
      key: const Key('improvement-planner-table'),
      keyPrefix: 'improvement-table',
      rowHeights: heights,
      frozenColumnWidths: const <double>[48, 190],
      frozenHeaders: const <Widget>[
        _Header(key: Key('improvement-frozen-favorite'), label: '收藏'),
        _Header(key: Key('improvement-frozen-equipment'), label: '装备名字'),
      ],
      frozenCells: (index) {
        final entry = rows[index].entry;
        final favorite = controller.favoriteEquipmentIds.contains(
          entry.equipmentId,
        );
        return <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              key: Key('improvement-favorite-${entry.equipmentId}'),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              onPressed: () => controller.toggleFavorite(entry.equipmentId),
              icon: Icon(
                favorite ? Icons.star : Icons.star_border,
                size: 18,
                color: favorite
                    ? const Color(0xffffc85a)
                    : const Color(0xff78909c),
              ),
            ),
          ),
          _EquipmentLine(
            iconId: _icon(entry.equipmentId),
            name: _name(entry.equipmentId),
          ),
        ];
      },
      scrollableColumnWidths: const <double>[170, 210, 210, 220, 190, 82, 220],
      scrollableHeaders: const <Widget>[
        _Header(
          label: '基础消耗',
          alignmentKey: Key('improvement-header-base-cost-align'),
        ),
        _Header(label: '改修消耗（0 → +6）'),
        _Header(label: '改修消耗（+6 → MAX）'),
        _Header(label: '进化消耗'),
        _Header(label: '秘书舰'),
        _Header(label: '可进化'),
        _Header(label: '进化装备'),
      ],
      scrollableCells: (index) {
        final row = rows[index];
        final entry = row.entry;
        final routes = row.upgradeRoutes;
        final evolvableToday = routes.isNotEmpty;
        final hasMultipleRoutes = routes.length > 1;
        return <Widget>[
          _BaseCostCell(
            cost: entry.baseCost,
            alignmentKey: Key(
              'improvement-cell-base-cost-align-${entry.equipmentId}',
            ),
          ),
          _ConsumeItemsCell(items: entry.stage0, name: _name, icon: _icon),
          _ConsumeItemsCell(items: entry.stage1, name: _name, icon: _icon),
          _UpgradeConsumeCell(routes: routes, name: _name, icon: _icon),
          _SecretaryWrap(
            wrapKey: Key('improvement-secretaries-${entry.equipmentId}'),
            values: _secretaryValues(row),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(evolvableToday ? '可进化' : '—', style: _cellStyle),
            ),
          ),
          _Lines(
            values: <String>[
              for (var routeIndex = 0; routeIndex < routes.length; routeIndex++)
                '${_name(routes[routeIndex].upgrade.targetEquipmentId)}${_routeMarker(routeIndex, hasMultipleRoutes)}',
            ],
            leading: <Widget>[
              for (final route in routes)
                EquipmentTypeIconImage(
                  iconId: _icon(route.upgrade.targetEquipmentId),
                  width: 20,
                  height: 20,
                ),
            ],
          ),
        ];
      },
    );
  }
}

const _cellStyle = TextStyle(
  color: Color(0xffdce8ed),
  fontSize: 11,
  fontWeight: FontWeight.w700,
  height: 1.1,
);
const _quantityStyle = TextStyle(
  color: Color(0xff58bce8),
  fontSize: 11,
  fontWeight: FontWeight.w800,
  height: 1.1,
);

String _routeMarker(int index, bool enabled) {
  if (!enabled) return '';
  const markers = <String>['①', '②', '③', '④', '⑤', '⑥', '⑦', '⑧', '⑨', '⑩'];
  return index < markers.length ? markers[index] : '(${index + 1})';
}

String _materialDisplayName(ImprovementConsumeItem item) =>
    item.materialName ??
    const <String, String>{
      'ActionReport': '戦闘詳報',
      'emergency-repair-material': '緊急修理資材',
      'fast-build': '高速建造材',
      'kaigai-skill': '海外艦最新技術',
      'kousyo-sigen': '工廠資源',
      'MedalL': '勲章',
      'NeEngine': 'ネ式エンジン',
      'new_gun_material': '新型砲熕兵装資材',
      'new_model_material': '新型兵装資材',
      'new_plane_material': '新型航空兵装資材',
      'new-funsiki-material': '新型噴進装備開発資材',
      'sensui-hokyu': '潜水艦補給物資',
      'skilled_crew': '熟練搭乗員',
    }[item.materialKey] ??
    item.materialKey ??
    '—';

String? _materialIconAsset(String? materialKey) => const <String, String>{
  'ActionReport': 'assets/images/material/useitem_78.png',
  'emergency-repair-material': 'assets/images/material/useitem_91.png',
  'fast-build': 'assets/images/material/useitem_2.png',
  'kaigai-skill': 'assets/images/material/useitem_100.png',
  'kousyo-sigen': 'assets/images/material/useitem_104.png',
  'MedalL': 'assets/images/material/useitem_57.png',
  'NeEngine': 'assets/images/material/useitem_71.png',
  'new_gun_material': 'assets/images/material/useitem_75.png',
  'new_model_material': 'assets/images/material/useitem_94.png',
  'new_plane_material': 'assets/images/material/useitem_77.png',
  'new-funsiki-material': 'assets/images/material/useitem_92.png',
  'sensui-hokyu': 'assets/images/material/useitem_95.png',
  'skilled_crew': 'assets/images/material/useitem_70.png',
}[materialKey];

class _Header extends StatelessWidget {
  const _Header({super.key, required this.label, this.alignmentKey});
  final String label;
  final Key? alignmentKey;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Align(
      key: alignmentKey,
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xffb8c9d2),
          fontSize: 11,
          fontWeight: FontWeight.w800,
          height: 1.1,
        ),
      ),
    ),
  );
}

class _EquipmentLine extends StatelessWidget {
  const _EquipmentLine({
    required this.iconId,
    required this.name,
    this.count,
    this.suffix = '',
  });
  final int iconId;
  final String name;
  final int? count;
  final String suffix;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    child: Row(
      children: [
        EquipmentTypeIconImage(iconId: iconId, width: 20, height: 20),
        const SizedBox(width: 5),
        Expanded(child: Text('$name$suffix', style: _cellStyle)),
        if (count != null) Text('×$count', style: _quantityStyle),
      ],
    ),
  );
}

class _ConsumeItemsCell extends StatelessWidget {
  const _ConsumeItemsCell({
    required this.items,
    required this.name,
    required this.icon,
  });
  final List<ImprovementConsumeItem> items;
  final String Function(int) name;
  final int Function(int) icon;
  @override
  Widget build(BuildContext context) => items.isEmpty
      ? const _EmptyCell()
      : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final item in items)
              item.equipmentId == null
                  ? _MaterialLine(item: item)
                  : _EquipmentLine(
                      iconId: icon(item.equipmentId!),
                      name: name(item.equipmentId!),
                      count: item.count,
                    ),
          ],
        );
}

class _UpgradeConsumeCell extends StatelessWidget {
  const _UpgradeConsumeCell({
    required this.routes,
    required this.name,
    required this.icon,
  });
  final List<ImprovementUpgradeRoute> routes;
  final String Function(int) name;
  final int Function(int) icon;

  @override
  Widget build(BuildContext context) {
    if (routes.isEmpty) {
      return const _EmptyCell();
    }
    final hasMultipleRoutes = routes.length > 1;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var routeIndex = 0; routeIndex < routes.length; routeIndex++)
          for (final item in routes[routeIndex].upgrade.items)
            item.equipmentId == null
                ? _MaterialLine(
                    item: item,
                    suffix: _routeMarker(routeIndex, hasMultipleRoutes),
                  )
                : _EquipmentLine(
                    iconId: icon(item.equipmentId!),
                    name: name(item.equipmentId!),
                    count: item.count,
                    suffix: _routeMarker(routeIndex, hasMultipleRoutes),
                  ),
      ],
    );
  }
}

class _MaterialLine extends StatelessWidget {
  const _MaterialLine({required this.item, this.suffix = ''});
  final ImprovementConsumeItem item;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final iconAsset = _materialIconAsset(item.materialKey);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        children: [
          if (iconAsset != null) ...[
            Image.asset(
              iconAsset,
              key: ValueKey<String>(
                'improvement-material-icon-${item.materialKey}',
              ),
              width: 20,
              height: 20,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 5),
          ],
          Expanded(
            child: Text(
              '${_materialDisplayName(item)}$suffix',
              style: _cellStyle,
            ),
          ),
          Text('×${item.count}', style: _quantityStyle),
        ],
      ),
    );
  }
}

class _BaseCostCell extends StatelessWidget {
  const _BaseCostCell({required this.cost, this.alignmentKey});
  final ImprovementResourceCost cost;
  final Key? alignmentKey;
  @override
  Widget build(BuildContext context) {
    final values = <int>[cost.fuel, cost.ammo, cost.steel, cost.bauxite];
    return Align(
      key: alignmentKey,
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < values.length; index++) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/material/0${index + 1}.png',
                    width: 14,
                    height: 14,
                  ),
                  const SizedBox(width: 1),
                  Text('${values[index]}', style: _cellStyle),
                ],
              ),
              if (index != values.length - 1) const SizedBox(width: 2),
            ],
          ],
        ),
      ),
    );
  }
}

class _Lines extends StatelessWidget {
  const _Lines({required this.values, this.leading = const <Widget>[]});
  final List<String> values;
  final List<Widget> leading;
  @override
  Widget build(BuildContext context) => values.isEmpty
      ? const _EmptyCell()
      : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var index = 0; index < values.length; index++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: Row(
                  children: [
                    if (index < leading.length) ...[
                      leading[index],
                      const SizedBox(width: 6),
                    ],
                    Expanded(child: Text(values[index], style: _cellStyle)),
                  ],
                ),
              ),
          ],
        );
}

class _SecretaryWrap extends StatelessWidget {
  const _SecretaryWrap({required this.wrapKey, required this.values});
  final Key wrapKey;
  final List<String> values;

  @override
  Widget build(BuildContext context) => values.isEmpty
      ? const _EmptyCell()
      : Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Wrap(
              key: wrapKey,
              spacing: 10,
              runSpacing: 2,
              alignment: WrapAlignment.start,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final value in values)
                  Text(value, maxLines: 1, style: _cellStyle),
              ],
            ),
          ),
        );
}

class _EmptyCell extends StatelessWidget {
  const _EmptyCell();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 8),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text('—', style: _cellStyle),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => const Center(
    child: Text(
      '当天没有符合条件的改修装备',
      style: TextStyle(color: Color(0xff8da5b2), fontSize: 13),
    ),
  );
}
