import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../fleet/ship_portrait.dart';
import '../../game_state/game_state.dart';
import 'enemy_catalog.dart';
import 'sortie_map_models.dart';

Future<void> showSortieEnemyDetails(
  BuildContext context, {
  required EnemyShipEntry entry,
  required GameState state,
  EnemyCatalogData? catalog,
}) async {
  if (catalog == null) {
    final loaded = await EnemyCatalogData.loadAsset();
    if (!context.mounted) return;
    return showSortieEnemyDetails(
      context,
      entry: entry,
      state: state,
      catalog: loaded,
    );
  }
  final details = catalog.resolve(entry);
  if (details == null) {
    final strings = _EnemyDetailsStrings.of(context);
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(strings.preciseConfigurationMissing)),
    );
    return Future<void>.value();
  }
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (context) =>
        _SortieEnemyDetailsDialog(entry: entry, details: details, state: state),
  );
}

class _SortieEnemyDetailsDialog extends StatelessWidget {
  const _SortieEnemyDetailsDialog({
    required this.entry,
    required this.details,
    required this.state,
  });

  final EnemyShipEntry entry;
  final EnemyConfiguration details;
  final GameState state;

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    final strings = _EnemyDetailsStrings.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: math.min(360, viewport.width - 32),
          maxHeight: math.max(0, viewport.height - 32),
        ),
        child: Material(
          key: const Key('sortie-enemy-details-card'),
          color: const Color(0xff192f3d),
          elevation: 18,
          shadowColor: Colors.black87,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0x99ff907e)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(entry: entry, details: details, state: state),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _InfoChip(
                      label: 'ID ${details.id}',
                      color: const Color(0xffff907e),
                    ),
                    _InfoChip(
                      label: details.shipType ?? strings.enemyShip,
                      color: const Color(0xffffc95c),
                    ),
                    _InfoChip(
                      label: strings.preciseConfiguration,
                      color: const Color(0xff70c7bc),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 14,
                  runSpacing: 5,
                  children: [
                    Text('Lv. ${_number(details.level)}'),
                    Text('${strings.hp} ${_number(details.hp)}'),
                    Text('${strings.speed} ${details.speed ?? '—'}'),
                    Text('${strings.range} ${details.range ?? '—'}'),
                    Text(
                      '${strings.aircraftCapacity} ${_number(details.aircraftCapacity)}',
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                _StatsGrid(details: details),
                const SizedBox(height: 10),
                Text(
                  strings.equipment,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                if (details.equipment.isEmpty)
                  Text(
                    strings.equipmentMissing,
                    style: const TextStyle(
                      color: Color(0xff93aab8),
                      fontSize: 11,
                    ),
                  )
                else
                  for (final item in details.equipment)
                    _EquipmentRow(item: item),
                if (details.note case final note?) ...[
                  const SizedBox(height: 8),
                  Text(
                    note,
                    style: const TextStyle(
                      color: Color(0xff93aab8),
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _number(num? value) => value?.toString() ?? '—';
}

class _Header extends StatelessWidget {
  const _Header({
    required this.entry,
    required this.details,
    required this.state,
  });

  final EnemyShipEntry entry;
  final EnemyConfiguration details;
  final GameState state;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ShipPortrait(
        ship: state.masterShips[details.id] ?? state.masterShips[entry.id],
        serverOrigin: state.serverOrigin,
        width: 72,
        height: 34,
        decodeHeight: 68,
        resourceType: ShipPortraitResourceType.banner,
      ),
      const SizedBox(width: 9),
      Expanded(
        child: Text(
          entry.nameJa,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      IconButton(
        key: const Key('sortie-enemy-details-close'),
        tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
        onPressed: () => Navigator.of(context).pop(),
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints.tightFor(width: 44, height: 44),
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.close, size: 19, color: Color(0xffa5bac4)),
      ),
    ],
  );
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.details});

  final EnemyConfiguration details;

  @override
  Widget build(BuildContext context) {
    final strings = _EnemyDetailsStrings.of(context);
    final stats = <(String, String)>[
      (strings.firepower, _stat(details.firepower)),
      (strings.torpedo, _stat(details.torpedo)),
      (strings.antiAir, _stat(details.antiAir)),
      (strings.armor, _stat(details.armor)),
      (strings.evasion, _number(details.evasion)),
      (strings.antiSub, _number(details.antiSub)),
      (strings.search, _number(details.search)),
      (strings.luck, _number(details.luck)),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xff10232e),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
        child: GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 4,
          childAspectRatio: 2.35,
          children: [
            for (final stat in stats)
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    stat.$1,
                    style: const TextStyle(
                      color: Color(0xff93aab8),
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    stat.$2,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  static String _number(num? value) => value?.toString() ?? '—';

  static String _stat(EnemyStat? value) => value == null
      ? '—'
      : value.equipped == null || value.equipped == value.base
      ? '${value.base}'
      : '${value.base} → ${value.equipped}';
}

class _EquipmentRow extends StatelessWidget {
  const _EquipmentRow({required this.item});

  final EnemyEquipment item;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: const Color(0xff284858),
            borderRadius: BorderRadius.circular(5),
          ),
          child: const Icon(Icons.settings, size: 14, color: Color(0xffffc95c)),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.name, style: const TextStyle(fontSize: 12)),
              Text(
                item.type ?? _EnemyDetailsStrings.of(context).unknownType,
                style: const TextStyle(color: Color(0xff93aab8), fontSize: 9.5),
              ),
            ],
          ),
        ),
        if (_equipmentSummary(context, item.stats) case final summary?)
          Text(
            summary,
            style: const TextStyle(color: Color(0xff70c7bc), fontSize: 10),
          ),
      ],
    ),
  );

  static String? _equipmentSummary(
    BuildContext context,
    EnemyEquipmentStats? stats,
  ) {
    if (stats == null) return null;
    final strings = _EnemyDetailsStrings.of(context);
    final values = <String>[
      if (stats.firepower case final value? when value != 0)
        '${strings.firepower} $value',
      if (stats.torpedo case final value? when value != 0)
        '${strings.torpedo} $value',
      if (stats.bombing case final value? when value != 0)
        '${strings.bombing} $value',
      if (stats.antiAir case final value? when value != 0)
        '${strings.antiAir} $value',
      if (stats.antiSub case final value? when value != 0)
        '${strings.antiSub} $value',
    ];
    return values.isEmpty ? null : values.join('  ');
  }
}

final class _EnemyDetailsStrings {
  const _EnemyDetailsStrings._(this._ja, this._traditional);

  factory _EnemyDetailsStrings.of(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context) ?? const Locale('zh');
    return _EnemyDetailsStrings._(
      locale.languageCode == 'ja',
      locale.languageCode == 'zh' &&
          (locale.scriptCode == 'Hant' ||
              const ['TW', 'HK', 'MO'].contains(locale.countryCode)),
    );
  }

  final bool _ja;
  final bool _traditional;

  String _pick(String simplified, String traditional, String japanese) =>
      _ja ? japanese : (_traditional ? traditional : simplified);

  String get preciseConfigurationMissing =>
      _pick('未找到该敌舰的精确配置资料', '未找到該敵艦的精確配置資料', 'この敵艦の正確な編成データはありません');
  String get enemyShip => _pick('敌舰', '敵艦', '敵艦');
  String get preciseConfiguration => _pick('精确配置', '精確配置', '正確な編成');
  String get hp => _pick('耐久', '耐久', '耐久');
  String get speed => _pick('速力', '速力', '速力');
  String get range => _pick('射程', '射程', '射程');
  String get aircraftCapacity => _pick('搭载', '搭載', '搭載');
  String get equipment => _pick('装备', '裝備', '装備');
  String get equipmentMissing => _pick('暂无装备资料', '暫無裝備資料', '装備データがありません');
  String get unknownType => _pick('种别不明', '種類不明', '種別不明');
  String get firepower => _pick('火力', '火力', '火力');
  String get torpedo => _pick('雷装', '雷裝', '雷装');
  String get bombing => _pick('爆装', '爆裝', '爆装');
  String get antiAir => _pick('对空', '對空', '対空');
  String get armor => _pick('装甲', '裝甲', '装甲');
  String get evasion => _pick('回避', '回避', '回避');
  String get antiSub => _pick('对潜', '對潜', '対潜');
  String get search => _pick('索敌', '索敵', '索敵');
  String get luck => _pick('运', '運', '運');
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      border: Border.all(color: color.withValues(alpha: .55)),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}
