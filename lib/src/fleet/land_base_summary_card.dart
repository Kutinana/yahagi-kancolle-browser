import 'package:flutter/material.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import '../game_state/game_state.dart';
import '../game_state/game_state_controller.dart';
import 'dashboard_card.dart';
import 'equipment_type_icon.dart';
import 'fleet_ship_status_capsule.dart';
import 'land_base_air_power.dart';
import 'land_base_status_visuals.dart';
import 'ship_status_style.dart';
import 'ship_status_visuals.dart';
import 'slot_item_portrait.dart';

class LandBaseSummaryCard extends StatefulWidget {
  const LandBaseSummaryCard({
    super.key,
    required this.controller,
    required this.collapsed,
    required this.onToggleCollapse,
    this.damagePulseMode = DamagePulseMode.enhanced,
  });

  final GameStateController controller;
  final bool collapsed;
  final VoidCallback onToggleCollapse;
  final DamagePulseMode damagePulseMode;

  @override
  State<LandBaseSummaryCard> createState() => _LandBaseSummaryCardState();
}

class _LandBaseSummaryCardState extends State<LandBaseSummaryCard> {
  int? _selectedAreaId;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final l10n =
          AppLocalizations.of(context) ??
          lookupAppLocalizations(const Locale('zh'));
      final state = widget.controller.state;
      final areaIds =
          state.landBases.map((base) => base.areaId).toSet().toList()..sort();
      if (!areaIds.contains(_selectedAreaId)) {
        _selectedAreaId = areaIds.firstOrNull;
      }
      final areaId = _selectedAreaId;
      final bases = areaId == null
          ? <LandBaseState>[]
          : state.landBases.where((base) => base.areaId == areaId).toList();
      bases.sort((left, right) => left.baseId.compareTo(right.baseId));

      return DashboardCard(
        title: l10n.landBaseBrief,
        icon: const Icon(Icons.flight_rounded),
        collapsed: widget.collapsed,
        onToggleCollapse: widget.onToggleCollapse,
        collapseButtonKey: const Key('land-base-collapse-button'),
        trailing: _LandBaseAreaSwitcher(
          areaIds: areaIds,
          selectedAreaId: areaId,
          onSelected: (selected) => setState(() => _selectedAreaId = selected),
        ),
        child: bases.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    l10n.landBaseNoData,
                    style: const TextStyle(color: Color(0xff8197a5)),
                  ),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _AreaHeading(
                    areaId: areaId!,
                    name:
                        state.masterMapAreas[areaId] ??
                        l10n.landBaseAreaFallback(areaId),
                    countLabel: l10n.landBaseUnitCount(bases.length),
                  ),
                  const SizedBox(height: 6),
                  for (var index = 0; index < bases.length; index++) ...[
                    LandBaseAirGroupRow(
                      state: state,
                      base: bases[index],
                      damagePulseMode: widget.damagePulseMode,
                    ),
                    if (index != bases.length - 1) const SizedBox(height: 4),
                  ],
                ],
              ),
      );
    },
  );
}

class _LandBaseAreaSwitcher extends StatelessWidget {
  const _LandBaseAreaSwitcher({
    required this.areaIds,
    required this.selectedAreaId,
    required this.onSelected,
  });

  final List<int> areaIds;
  final int? selectedAreaId;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('land-base-area-switcher'),
    constraints: const BoxConstraints(minWidth: 42, maxWidth: 150),
    height: 22,
    padding: const EdgeInsets.all(2),
    decoration: BoxDecoration(
      color: const Color(0xff102331),
      border: Border.all(color: const Color(0xff294052)),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final areaId in areaIds)
          Material(
            key: Key('land-base-area-selector-$areaId'),
            color: areaId == selectedAreaId
                ? const Color(0xff8a6628)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            child: InkWell(
              onTap: () => onSelected(areaId),
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 32,
                child: Center(
                  child: Text(
                    '$areaId',
                    style: TextStyle(
                      color: areaId == selectedAreaId
                          ? const Color(0xffffdc88)
                          : const Color(0xff9fb3bf),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _AreaHeading extends StatelessWidget {
  const _AreaHeading({
    required this.areaId,
    required this.name,
    required this.countLabel,
  });

  final int areaId;
  final String name;
  final String countLabel;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Expanded(
        child: Text(
          '[$areaId] $name',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xffdce6eb),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      Text(
        countLabel,
        style: const TextStyle(
          color: Color(0xff8197a5),
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class LandBaseAirGroupRow extends StatelessWidget {
  const LandBaseAirGroupRow({
    super.key,
    required this.state,
    required this.base,
    this.damagePulseMode = DamagePulseMode.enhanced,
  });

  final GameState state;
  final LandBaseState base;
  final DamagePulseMode damagePulseMode;

  String get _keySuffix => '${base.areaId}-${base.baseId}';

  @override
  Widget build(BuildContext context) {
    final maximumHp = base.maxHp ?? 200;
    final currentHp = base.currentHp ?? maximumHp;
    final hpRatio = maximumHp <= 0
        ? 0.0
        : (currentHp / maximumHp).clamp(0.0, 1.0);
    final fatigue = landBaseFatigueLevel(
      base.squadrons.map((squadron) => squadron.condition),
    );
    final airPower = LandBaseAirPower.calculate(state: state, base: base);
    final portraitMaster = _portraitMaster(state, base);

    return Container(
      key: Key('land-base-row-$_keySuffix'),
      padding: const EdgeInsets.fromLTRB(6, 5, 6, 5),
      decoration: BoxDecoration(
        color: const Color(0xff1c3547),
        border: Border.all(color: const Color(0xff4c6b84), width: 1.2),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 460;
          final portraitWidth = narrow ? 82.0 : 112.0;
          final portraitHeight = narrow ? 42.0 : 52.0;
          return Row(
            children: <Widget>[
              SizedBox(
                key: Key('land-base-portrait-$_keySuffix'),
                width: portraitWidth,
                height: portraitHeight,
                child: Stack(
                  fit: StackFit.expand,
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: SlotItemPortrait(
                        item: portraitMaster,
                        serverOrigin: state.serverOrigin,
                        width: portraitWidth,
                        height: portraitHeight,
                      ),
                    ),
                    ShipHpFrame(
                      key: Key('land-base-portrait-hp-frame-$_keySuffix'),
                      shipId: base.areaId * 10 + base.baseId,
                      ratio: hpRatio,
                      color: shipHpBarColor(hpRatio, isZeroHp: currentHp <= 0),
                      mode: damagePulseMode,
                      strokeWidth: 2,
                    ),
                    if (fatigue != LandBaseFatigueLevel.none)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: FatigueFace(
                          level: fatigue == LandBaseFatigueLevel.red
                              ? FatigueFaceLevel.red
                              : FatigueFaceLevel.yellow,
                          size: narrow ? 15 : 18,
                          faceKey: Key('land-base-fatigue-face-$_keySuffix'),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(width: narrow ? 6 : 9),
              Expanded(
                flex: narrow ? 4 : 5,
                child: _LandBaseIdentity(
                  base: base,
                  airPower: airPower,
                  currentHp: currentHp,
                  maximumHp: maximumHp,
                  hpRatio: hpRatio,
                  damagePulseMode: damagePulseMode,
                ),
              ),
              SizedBox(width: narrow ? 5 : 10),
              Expanded(
                flex: narrow ? 5 : 6,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    for (var squadronId = 1; squadronId <= 4; squadronId++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 2),
                          child: _LandBaseSquadronSlot(
                            state: state,
                            squadron: _squadron(base, squadronId),
                            areaId: base.areaId,
                            baseId: base.baseId,
                            squadronId: squadronId,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LandBaseIdentity extends StatelessWidget {
  const _LandBaseIdentity({
    required this.base,
    required this.airPower,
    required this.currentHp,
    required this.maximumHp,
    required this.hpRatio,
    required this.damagePulseMode,
  });

  final LandBaseState base;
  final LandBaseAirPowerResult airPower;
  final int currentHp;
  final int maximumHp;
  final double hpRatio;
  final DamagePulseMode damagePulseMode;

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    final suffix = '${base.areaId}-${base.baseId}';
    final hpColor = shipHpBarColor(hpRatio, isZeroHp: currentHp <= 0);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          base.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xffe8f1f5),
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${l10n.airPower} ${airPower.displayValue} · '
          '${l10n.landBaseRange} ${base.effectiveDistance}',
          maxLines: 1,
          style: const TextStyle(
            color: Color(0xff9fb3bf),
            fontSize: 8,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: _actionColor(base.actionKind).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _actionLabel(base.actionKind, l10n),
                style: TextStyle(
                  color: _actionColor(base.actionKind),
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: DamagePulseBuilder(
                ratio: hpRatio,
                mode: damagePulseMode,
                normalColor: hpColor,
                builder: (context, spec, phase) => Opacity(
                  opacity: spec.pulses
                      ? spec.minFrameOpacity +
                            phase * (1 - spec.minFrameOpacity)
                      : 1,
                  child: CompactStatusMeter(
                    height: 13,
                    icon: Icon(Icons.favorite_rounded, color: hpColor, size: 9),
                    value: '$currentHp/$maximumHp',
                    ratio: hpRatio,
                    valueColor: shipHpValueColor(
                      hpRatio,
                      isZeroHp: currentHp <= 0,
                    ),
                    barColor: spec.color,
                    trackKey: Key('land-base-hp-meter-$suffix'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LandBaseSquadronSlot extends StatelessWidget {
  const _LandBaseSquadronSlot({
    required this.state,
    required this.squadron,
    required this.areaId,
    required this.baseId,
    required this.squadronId,
  });

  final GameState state;
  final LandBaseSquadronState? squadron;
  final int areaId;
  final int baseId;
  final int squadronId;

  @override
  Widget build(BuildContext context) {
    final owned = squadron == null
        ? null
        : state.slotItems[squadron!.slotItemId];
    final master = owned == null
        ? null
        : state.masterSlotItems[owned.masterSlotItemId];
    final iconId = master != null && master.type.length > 3
        ? master.type[3]
        : -1;
    final fatigue = landBaseFatigueLevel(<int>[
      if (squadron != null) squadron!.condition,
    ]);
    final fatigueColor = landBaseFatigueColor(fatigue);
    final relocating = squadron?.state == 2;
    final missing =
        squadron != null &&
        squadron!.maxCount > 0 &&
        squadron!.currentCount < squadron!.maxCount;
    final suffix = '$areaId-$baseId-$squadronId';
    final content = Container(
      key: Key('land-base-slot-$suffix'),
      height: 38,
      decoration: BoxDecoration(
        color: const Color(0xff102331),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: missing
              ? const Color(0xffef775f)
              : fatigueColor?.withValues(alpha: 0.9) ?? const Color(0xff294052),
        ),
        boxShadow: fatigueColor == null
            ? null
            : <BoxShadow>[
                BoxShadow(
                  color: fatigueColor.withValues(alpha: 0.42),
                  blurRadius: fatigue == LandBaseFatigueLevel.red ? 7 : 4,
                ),
              ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          EquipmentTypeIconImage(iconId: iconId, width: 18, height: 18),
          Text(
            squadron == null ? '—' : '${squadron!.currentCount}',
            style: TextStyle(
              color: missing
                  ? const Color(0xffff8b78)
                  : const Color(0xffe8f1f5),
              fontSize: 8,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
    return relocating
        ? Opacity(
            key: Key('land-base-slot-relocating-$suffix'),
            opacity: 0.38,
            child: content,
          )
        : content;
  }
}

MasterSlotItem? _portraitMaster(GameState state, LandBaseState base) {
  for (final squadron in base.squadrons) {
    final owned = state.slotItems[squadron.slotItemId];
    final master = owned == null
        ? null
        : state.masterSlotItems[owned.masterSlotItemId];
    if (master != null) return master;
  }
  return null;
}

LandBaseSquadronState? _squadron(LandBaseState base, int id) {
  for (final squadron in base.squadrons) {
    if (squadron.squadronId == id) return squadron;
  }
  return null;
}

String _actionLabel(int actionKind, AppLocalizations l10n) =>
    switch (actionKind) {
      1 => l10n.landBaseActionSortie,
      2 => l10n.landBaseActionAirDefense,
      3 => l10n.landBaseActionRest,
      4 => l10n.landBaseActionRetreat,
      _ => l10n.standby,
    };

Color _actionColor(int actionKind) => switch (actionKind) {
  1 => const Color(0xffef7777),
  2 => const Color(0xff69aee8),
  3 => const Color(0xff70c697),
  4 => const Color(0xff9ca8b2),
  _ => const Color(0xffb7c4cc),
};
