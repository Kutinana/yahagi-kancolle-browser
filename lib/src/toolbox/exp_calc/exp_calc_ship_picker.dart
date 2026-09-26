import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../fleet/ship_portrait.dart';
import '../../game_state/game_state.dart';
import '../../inventory/owned_inventory_projection.dart';
import '../../theme/app_fonts.dart';
import 'exp_calc_strings.dart';

class ExpCalcShipPicker extends StatelessWidget {
  const ExpCalcShipPicker({
    super.key,
    required this.state,
    required this.ships,
    required this.selectedId,
    required this.onSelected,
  });
  final GameState state;
  final List<OwnedShip> ships;
  final int? selectedId;
  final ValueChanged<OwnedShip?> onSelected;

  @override
  Widget build(BuildContext context) {
    final ship = state.ships[selectedId];
    final label = ship == null
        ? AppLocalizations.of(context)!.expCalcFreeMode
        : '${state.masterShips[ship.masterId]?.name ?? 'Ship #${ship.id}'} · Lv.${ship.level}';
    return Material(
      color: const Color(0xff0c202b),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: const BorderSide(color: Color(0xff284553)),
      ),
      child: InkWell(
        key: const Key('exp-calc-ship-selector'),
        borderRadius: BorderRadius.circular(6),
        onTap: () async {
          final id = await showDialog<int>(
            context: context,
            builder: (_) =>
                _ShipDialog(state: state, ships: ships, selectedId: selectedId),
          );
          if (id != null && context.mounted) onSelected(state.ships[id]);
        },
        child: SizedBox(
          height: 44,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                if (ship != null) ...[
                  _portrait(state, ship),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xffecf3f5),
                      fontSize: 12,
                    ),
                  ),
                ),
                const Icon(
                  Icons.expand_more,
                  color: Color(0xff91aab8),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget _portrait(GameState state, OwnedShip ship, {double scale = 1}) =>
    ShipPortrait(
      key: ValueKey('exp-calc-ship-portrait-${ship.id}'),
      ship: state.masterShips[ship.masterId],
      serverOrigin: state.serverOrigin,
      width: 48 * scale,
      height: 22 * scale,
      decodeHeight: (44 * scale).round(),
      resourceType: ShipPortraitResourceType.banner,
    );

class _ShipDialog extends StatefulWidget {
  const _ShipDialog({
    required this.state,
    required this.ships,
    required this.selectedId,
  });
  final GameState state;
  final List<OwnedShip> ships;
  final int? selectedId;
  @override
  State<_ShipDialog> createState() => _ShipDialogState();
}

class _ShipDialogState extends State<_ShipDialog> {
  var category = ShipInventoryCategory.all;
  String categoryLabel(ShipInventoryCategory value) => switch (value) {
    ShipInventoryCategory.all => AppLocalizations.of(context)!.all,
    ShipInventoryCategory.bbBc => 'BB/BC',
    ShipInventoryCategory.support => 'AV/AO/AS…',
    _ => value.name.toUpperCase(),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final fontFamily = AppFonts.forLocale(
      Localizations.localeOf(context).toString(),
    );
    final size = MediaQuery.sizeOf(context);
    final ships = widget.ships
        .where(
          (ship) => shipTypeMatchesInventoryCategory(
            widget.state.masterShips[ship.masterId]?.shipTypeId ?? 0,
            category,
          ),
        )
        .toList();
    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      backgroundColor: const Color(0xff101d27),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xff385064)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        key: const Key('exp-calc-ship-dialog'),
        width: math.min(660, size.width - 24),
        height: math.min(520, size.height - 48),
        child: Column(
          children: [
            SizedBox(
              height: 44,
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.directions_boat_outlined,
                    size: 18,
                    color: Color(0xffd7b56d),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    ExpCalcStrings(context).selectShip,
                    style: const TextStyle(
                      color: Color(0xffecf3f5),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close,
                      size: 20,
                      color: Color(0xffc3d0d7),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xff385064)),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: size.width < 420 ? 76 : 104,
                    child: ColoredBox(
                      color: const Color(0xff0b1720),
                      child: ListView(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        children: [
                          for (final value in ShipInventoryCategory.values)
                            Semantics(
                              selected: category == value,
                              button: true,
                              child: Material(
                                color: category == value
                                    ? const Color(0xff244b69)
                                    : Colors.transparent,
                                child: InkWell(
                                  key: Key(
                                    'exp-calc-ship-category-${value.name}',
                                  ),
                                  onTap: () => setState(() => category = value),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 10,
                                    ),
                                    child: Text(
                                      categoryLabel(value),
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontFamily: fontFamily,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const VerticalDivider(width: 1, color: Color(0xff385064)),
                  Expanded(
                    child: ListView.separated(
                      key: ValueKey(category),
                      padding: const EdgeInsets.all(6),
                      itemCount: ships.length + 1,
                      separatorBuilder: (_, _) => const SizedBox(height: 3),
                      itemBuilder: (context, index) {
                        final ship = index == 0 ? null : ships[index - 1];
                        final selected = ship?.id == widget.selectedId;
                        final name = ship == null
                            ? l10n.expCalcFreeMode
                            : widget.state.masterShips[ship.masterId]?.name ??
                                  'Ship #${ship.id}';
                        return Semantics(
                          selected: selected,
                          button: true,
                          child: Material(
                            color: selected
                                ? const Color(0xff1d5f91)
                                : const Color(0xff172a38),
                            borderRadius: BorderRadius.circular(5),
                            child: InkWell(
                              key: Key(
                                'exp-calc-ship-option-${ship?.id ?? 'custom'}',
                              ),
                              onTap: () =>
                                  Navigator.of(context).pop(ship?.id ?? -1),
                              borderRadius: BorderRadius.circular(5),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: 44,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    children: [
                                      if (ship != null) ...[
                                        _portrait(
                                          widget.state,
                                          ship,
                                          scale: 1.5,
                                        ),
                                        const SizedBox(width: 6),
                                      ],
                                      Expanded(
                                        child: Text(
                                          name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontFamily: fontFamily,
                                            fontWeight: FontWeight.w700,
                                            fontSize: ship == null ? 12 : 18,
                                          ),
                                        ),
                                      ),
                                      if (ship != null) ...[
                                        const SizedBox(width: 6),
                                        Text(
                                          'Lv.${ship.level}',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontFamily: fontFamily,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16.5,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
