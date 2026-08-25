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
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
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
          final portraitSize = fleetStatusPortraitSize(constraints.maxWidth);
          final portraitWidth = portraitSize.width;
          final portraitHeight = portraitSize.height;
          final fatigueFaceSize = (portraitHeight * 0.34)
              .clamp(14.0, 20.0)
              .toDouble();
          final l10n =
              AppLocalizations.of(context) ??
              lookupAppLocalizations(const Locale('zh'));
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                height: 20,
                child: Row(
                  key: Key('land-base-identity-line-$_keySuffix'),
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        base.name,
                        key: Key('land-base-name-$_keySuffix'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xffe8f1f5),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    _LandBaseActionHpChip(
                      key: Key('land-base-action-chip-$_keySuffix'),
                      label: _actionLabel(base.actionKind, l10n),
                      actionColor: _actionColor(base.actionKind),
                      currentHp: currentHp,
                      maximumHp: maximumHp,
                      hpRatio: hpRatio,
                      damagePulseMode: damagePulseMode,
                      meterKey: Key('land-base-hp-meter-$_keySuffix'),
                    ),
                    const SizedBox(width: 3),
                    _LandBaseInfoChip(
                      key: Key('land-base-air-power-chip-$_keySuffix'),
                      label: '${l10n.airPower} ${airPower.displayValue}',
                      color: const Color(0xffd4a74e),
                    ),
                    const SizedBox(width: 3),
                    _LandBaseInfoChip(
                      key: Key('land-base-range-chip-$_keySuffix'),
                      label: '${l10n.landBaseRange} ${base.effectiveDistance}',
                      color: const Color(0xff70b8d8),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              Row(
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
                          color: shipHpBarColor(
                            hpRatio,
                            isZeroHp: currentHp <= 0,
                          ),
                          mode: damagePulseMode,
                          strokeWidth: 2,
                        ),
                        if (fatigue != LandBaseFatigueLevel.none)
                          Positioned(
                            right: 4,
                            top: 0,
                            child: FatigueFace(
                              level: fatigue == LandBaseFatigueLevel.red
                                  ? FatigueFaceLevel.red
                                  : FatigueFaceLevel.yellow,
                              size: fatigueFaceSize,
                              faceKey: Key(
                                'land-base-fatigue-face-$_keySuffix',
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(width: narrow ? 5 : 7),
                  Expanded(
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
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LandBaseInfoChip extends StatelessWidget {
  const _LandBaseInfoChip({
    super.key,
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      border: Border.all(color: color.withValues(alpha: 0.42)),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      label,
      maxLines: 1,
      style: TextStyle(
        color: color,
        fontSize: 8,
        height: 1,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

class _LandBaseActionHpChip extends StatelessWidget {
  const _LandBaseActionHpChip({
    super.key,
    required this.label,
    required this.actionColor,
    required this.currentHp,
    required this.maximumHp,
    required this.hpRatio,
    required this.damagePulseMode,
    required this.meterKey,
  });

  final String label;
  final Color actionColor;
  final int currentHp;
  final int maximumHp;
  final double hpRatio;
  final DamagePulseMode damagePulseMode;
  final Key meterKey;

  @override
  Widget build(BuildContext context) {
    final hpColor = shipHpBarColor(hpRatio, isZeroHp: currentHp <= 0);
    return DamagePulseBuilder(
      ratio: hpRatio,
      mode: damagePulseMode,
      normalColor: hpColor,
      builder: (context, spec, phase) => Opacity(
        opacity: spec.pulses
            ? spec.minFrameOpacity + phase * (1 - spec.minFrameOpacity)
            : 1,
        child: Container(
          height: 18,
          padding: const EdgeInsets.fromLTRB(5, 2, 5, 3),
          decoration: BoxDecoration(
            color: actionColor.withValues(alpha: 0.16),
            border: Border.all(color: actionColor.withValues(alpha: 0.42)),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    label,
                    style: TextStyle(
                      color: actionColor,
                      fontSize: 8,
                      height: 1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(Icons.favorite_rounded, color: hpColor, size: 8),
                  const SizedBox(width: 2),
                  Text(
                    '$currentHp/$maximumHp',
                    style: TextStyle(
                      color: shipHpValueColor(
                        hpRatio,
                        isZeroHp: currentHp <= 0,
                      ),
                      fontSize: 7,
                      height: 1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              Positioned(
                key: meterKey,
                left: 0,
                right: 0,
                bottom: 0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    value: hpRatio,
                    backgroundColor: const Color(0xff102331),
                    valueColor: AlwaysStoppedAnimation<Color>(spec.color),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
      height: 34,
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
          EquipmentTypeIconImage(iconId: iconId, width: 16, height: 16),
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
