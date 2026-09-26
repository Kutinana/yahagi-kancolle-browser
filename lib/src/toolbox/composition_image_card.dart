import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../fleet/equipment_type_icon.dart';
import '../fleet/ship_portrait.dart';
import '../fleet/slot_item_portrait.dart';
import '../fleet/fleet_ui_strings.dart';
import '../game_state/fleet_metrics.dart';
import '../game_state/game_state.dart';
import 'composition_image_strings.dart';

enum CompositionPlaneCountMode { hidden, current, maximum }

/// A complete, deterministic paper layout suitable for RepaintBoundary capture.
/// Its parent supplies enough horizontal space and handles preview scaling.
class CompositionImageCard extends StatelessWidget {
  const CompositionImageCard({
    super.key,
    required this.state,
    required this.fleetIds,
    required this.landBaseAreaId,
    required this.landBaseIds,
    required this.planeCountMode,
    required this.generatedAt,
    this.recordMode = false,
  });

  final GameState state;
  final Set<int> fleetIds;
  final int? landBaseAreaId;
  final Set<int> landBaseIds;
  final CompositionPlaneCountMode planeCountMode;
  final DateTime generatedAt;
  final bool recordMode;

  @override
  Widget build(BuildContext context) {
    final strings = CompositionImageStrings.of(context);
    final fleets =
        state.fleets.where((fleet) => fleetIds.contains(fleet.id)).toList()
          ..sort((a, b) => a.id.compareTo(b.id));
    final bases =
        state.landBases
            .where(
              (base) =>
                  base.areaId == landBaseAreaId &&
                  landBaseIds.contains(base.baseId),
            )
            .toList()
          ..sort((a, b) => a.baseId.compareTo(b.baseId));
    return MediaQuery.withNoTextScaling(
      child: DefaultTextStyle(
        style: (Theme.of(context).textTheme.bodyMedium ?? const TextStyle())
            .copyWith(color: _ink, fontSize: 14, height: 1.35),
        child: Container(
          key: const Key('composition-image-card'),
          width: recordMode ? 1000 : 1200,
          decoration: recordMode
              ? const BoxDecoration(color: Color(0xff112a37))
              : const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xff122c3e),
                      Color(0xff081a28),
                      Color(0xff102739),
                    ],
                  ),
                ),
          child: CustomPaint(
            painter: recordMode ? null : const _PaperLines(),
            child: Padding(
              padding: EdgeInsets.all(recordMode ? 0 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!recordMode)
                    Row(
                      key: const Key('composition-image-header'),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: _gold.withValues(alpha: .6),
                            ),
                            borderRadius: BorderRadius.circular(12),
                            color: const Color(0xff203747),
                          ),
                          child: const Icon(
                            Icons.explore_outlined,
                            color: _gold,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            strings.title,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _Pill(
                          text: DateFormat(
                            'yyyy-MM-dd HH:mm:ss',
                          ).format(generatedAt.toLocal()),
                          textKey: const Key('composition-generated-at'),
                          icon: Icons.schedule_rounded,
                          color: _muted,
                        ),
                      ],
                    ),
                  if (!recordMode)
                    Container(
                      height: 1,
                      margin: const EdgeInsets.symmetric(vertical: 16),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_gold, Color(0x1069c9c1)],
                        ),
                      ),
                    ),
                  if (fleets.isEmpty && bases.isEmpty)
                    _EmptyPanel(text: strings.emptySelection),
                  for (final fleet in fleets) ...[
                    Text(
                      fleet.name.trim().isEmpty
                          ? strings.fleet(fleet.id)
                          : fleet.name,
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: recordMode ? 6 : 10),
                    if (fleet.shipIds.any((id) => id > 0)) ...[
                      _FleetMetricsStrip(
                        state: state,
                        fleet: fleet,
                        recordMode: recordMode,
                      ),
                      SizedBox(height: recordMode ? 0 : 12),
                    ],
                    if (fleet.shipIds.every((id) => id <= 0))
                      _EmptyPanel(text: strings.emptyFleet)
                    else
                      Column(
                        children: [
                          for (final shipId in fleet.shipIds.where(
                            (id) => id > 0,
                          )) ...[
                            if (!recordMode &&
                                shipId !=
                                    fleet.shipIds.where((id) => id > 0).first)
                              const SizedBox(height: 6),
                            _ShipCard(
                              key: Key('composition-ship-${fleet.id}-$shipId'),
                              state: state,
                              fleetId: fleet.id,
                              shipId: shipId,
                              mode: planeCountMode,
                              recordMode: recordMode,
                            ),
                          ],
                        ],
                      ),
                    SizedBox(height: recordMode ? 18 : 28),
                  ],
                  if (bases.isNotEmpty) ...[
                    _SectionTitle(
                      title: strings.airBaseTitle,
                      subtitle:
                          state.masterMapAreas[landBaseAreaId] ??
                          strings.area(landBaseAreaId!),
                      detail: strings.landBaseCount(bases.length),
                      recordMode: recordMode,
                    ),
                    SizedBox(height: recordMode ? 6 : 14),
                    Column(
                      children: [
                        for (var index = 0; index < bases.length; index++) ...[
                          if (!recordMode && index > 0)
                            const SizedBox(height: 6),
                          _LandBaseCard(
                            key: Key(
                              'composition-base-${bases[index].areaId}-${bases[index].baseId}',
                            ),
                            state: state,
                            base: bases[index],
                            mode: planeCountMode,
                            recordMode: recordMode,
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: recordMode ? 18 : 28),
                  ],
                  if (!recordMode)
                    Row(
                      children: [
                        const Expanded(
                          child: Divider(color: Color(0xff315064), height: 1),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            strings.footer,
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 12,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                        const Expanded(
                          child: Divider(color: Color(0xff315064), height: 1),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const _ink = Color(0xffeaf1f4);
const _muted = Color(0xff92abbc);
const _gold = Color(0xffd7bb78);
const _cyan = Color(0xff81d8cc);
const _recordGridLine = Color(0xff5c7d90);
const _recordColumnLine = Color(0xff527286);
const _mutedStyle = TextStyle(color: _muted, fontSize: 13);

class _FleetMetricsStrip extends StatelessWidget {
  const _FleetMetricsStrip({
    required this.state,
    required this.fleet,
    this.recordMode = false,
  });

  final GameState state;
  final Fleet fleet;
  final bool recordMode;

  @override
  Widget build(BuildContext context) {
    final l =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    final shipIds = fleet.shipIds.where((id) => id > 0).toList();
    final completeShips =
        shipIds.isNotEmpty && shipIds.every(state.ships.containsKey);
    final metrics = completeShips ? FleetMetrics.fromState(state, fleet) : null;
    // Missing records must not make the exported scouting score look complete.
    final completeEquipment =
        completeShips &&
        shipIds.every((id) {
          final ship = state.ships[id]!;
          return [
            ...ship.slotIds,
            ship.extraSlotId,
          ].where((id) => id > 0).every((id) {
            final item = state.slotItems[id];
            return item != null &&
                state.masterSlotItems.containsKey(item.masterSlotItemId);
          });
        });
    final airPower = metrics?.airPower;
    final airPowerMaximum = metrics?.airPowerMaximum;
    final values = <(String, String, String)>[
      (
        'speed',
        l.speed,
        metrics == null ? l.noValue : fleetText(context, metrics.speedLabel),
      ),
      (
        'total-level',
        l.totalLevel,
        metrics?.totalLevel.toString() ?? l.noValue,
      ),
      ('firepower', l.firepower, metrics?.firepower.toString() ?? l.noValue),
      ('torpedo', l.torpedo, metrics?.torpedo.toString() ?? l.noValue),
      ('anti-air', l.antiAir, metrics?.antiAir.toString() ?? l.noValue),
      ('anti-sub', l.antiSub, metrics?.antiSub.toString() ?? l.noValue),
      (
        'air-power',
        l.airPower,
        airPower == null
            ? l.noValue
            : airPowerMaximum != null && airPowerMaximum > airPower
            ? '$airPower+'
            : '$airPower',
      ),
      (
        'line-of-sight',
        l.lineOfSight,
        metrics == null || !completeEquipment || metrics.formula33.isEmpty
            ? l.noValue
            : metrics.formula33.first.total.toStringAsFixed(2),
      ),
    ];
    return Row(
      key: Key('composition-fleet-metrics-${fleet.id}'),
      children: [
        for (var index = 0; index < values.length; index++) ...[
          if (!recordMode && index > 0) const SizedBox(width: 6),
          Expanded(
            child: Container(
              key: Key('composition-metric-${fleet.id}-${values[index].$1}'),
              padding: EdgeInsets.symmetric(
                horizontal: 6,
                vertical: recordMode ? 3 : 5,
              ),
              decoration: BoxDecoration(
                color: const Color(0xff142c3c),
                borderRadius: recordMode ? null : BorderRadius.circular(8),
                border: recordMode
                    ? Border(
                        top: const BorderSide(
                          color: _recordGridLine,
                          width: 1.2,
                        ),
                        bottom: const BorderSide(
                          color: _recordGridLine,
                          width: 1.2,
                        ),
                        left: const BorderSide(
                          color: _recordGridLine,
                          width: 1.2,
                        ),
                        right: index == values.length - 1
                            ? const BorderSide(
                                color: _recordGridLine,
                                width: 1.2,
                              )
                            : BorderSide.none,
                      )
                    : Border.all(color: const Color(0xff4b6b7d)),
                boxShadow: recordMode
                    ? null
                    : const [
                        BoxShadow(
                          color: Color(0x40000000),
                          blurRadius: 5,
                          offset: Offset(0, 2),
                        ),
                      ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    values[index].$2,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    values[index].$3,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
    required this.detail,
    this.recordMode = false,
  });
  final String title;
  final String subtitle;
  final String detail;
  final bool recordMode;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      if (!recordMode)
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xff203b4b),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xff45606d)),
          ),
          child: const Icon(Icons.flight_takeoff, color: _gold, size: 26),
        ),
      if (!recordMode) const SizedBox(width: 13),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              subtitle,
              style: const TextStyle(
                color: _cyan,
                fontSize: 11,
                letterSpacing: 1.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
      const SizedBox(width: 14),
      Text(detail, style: _mutedStyle),
    ],
  );
}

class _ShipCard extends StatelessWidget {
  const _ShipCard({
    super.key,
    required this.state,
    required this.fleetId,
    required this.shipId,
    required this.mode,
    this.recordMode = false,
  });

  final GameState state;
  final int fleetId;
  final int shipId;
  final CompositionPlaneCountMode mode;
  final bool recordMode;

  @override
  Widget build(BuildContext context) {
    final strings = CompositionImageStrings.of(context);
    final ship = state.ships[shipId];
    final master = ship == null ? null : state.masterForShip(ship);
    final slotCount = ship == null ? 0 : _regularSlotCount(ship, master);
    final hasExpansion = ship != null && ship.extraSlotId != 0;
    final heading = _UnitHeading(
      recordMode: recordMode,
      name: master?.name ?? strings.missingShip,
      type: ship == null ? '—' : state.typeForShip(ship)?.name ?? '—',
      level: ship?.level,
      luck: ship?.luck,
      portrait: master == null
          ? null
          : ShipPortrait(
              ship: master,
              serverOrigin: state.serverOrigin,
              width: recordMode ? 92 : 112,
              height: 60,
            ),
    );
    return _RosterPanel(
      recordMode: recordMode,
      child: Padding(
        padding: EdgeInsets.all(recordMode ? 0 : 5),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (recordMode)
                Expanded(flex: 2, child: heading)
              else
                SizedBox(width: 280, child: heading),
              if (!recordMode && ship != null) const SizedBox(width: 7),
              if (recordMode && ship == null) const Spacer(flex: 6),
              if (ship != null)
                Expanded(
                  flex: recordMode ? 6 : 1,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var index = 0; index < slotCount; index++) ...[
                        if (!recordMode && index > 0) const SizedBox(width: 6),
                        Expanded(
                          child: _EquipmentRow(
                            state: state,
                            suffix: '$fleetId-$shipId-${index + 1}',
                            label: strings.slot(index + 1),
                            showLabel: false,
                            recordMode: recordMode,
                            itemId: index < ship.slotIds.length
                                ? ship.slotIds[index]
                                : -1,
                            planeCount: switch (mode) {
                              CompositionPlaneCountMode.hidden => null,
                              CompositionPlaneCountMode.current => _at(
                                ship.onSlot,
                                index,
                              ),
                              CompositionPlaneCountMode.maximum =>
                                _at(ship.maxSlotCounts, index) ??
                                    _at(
                                      master?.slotCapacities ?? const [],
                                      index,
                                    ),
                            },
                            showPlaneCount:
                                mode != CompositionPlaneCountMode.hidden,
                          ),
                        ),
                      ],
                      if (hasExpansion) ...[
                        if (!recordMode && slotCount > 0)
                          const SizedBox(width: 6),
                        Expanded(
                          child: _EquipmentRow(
                            state: state,
                            suffix: '$fleetId-$shipId-extra',
                            label: strings.expansionSlot,
                            itemId: ship.extraSlotId,
                            isExpansion: true,
                            recordMode: recordMode,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

int _regularSlotCount(OwnedShip ship, MasterShip? master) {
  // The ship's declared slots decide the width; -1 padding is not a slot.
  return math.max(
    master?.slotCount ?? ship.slotIds.length,
    ship.slotIds.lastIndexWhere((id) => id > 0) + 1,
  );
}

int? _at(List<int> counts, int index) =>
    index < counts.length && counts[index] >= 0 ? counts[index] : null;

class _LandBaseCard extends StatelessWidget {
  const _LandBaseCard({
    super.key,
    required this.state,
    required this.base,
    required this.mode,
    this.recordMode = false,
  });

  final GameState state;
  final LandBaseState base;
  final CompositionPlaneCountMode mode;
  final bool recordMode;

  @override
  Widget build(BuildContext context) {
    final strings = CompositionImageStrings.of(context);
    final squadrons = {
      for (final squadron in base.squadrons) squadron.squadronId: squadron,
    };
    MasterSlotItem? representative;
    for (final squadron in base.squadrons) {
      final owned = state.slotItems[squadron.slotItemId];
      final master = owned == null
          ? null
          : state.masterSlotItems[owned.masterSlotItemId];
      if (master != null) {
        representative = master;
        break;
      }
    }
    return _RosterPanel(
      recordMode: recordMode,
      child: Padding(
        padding: EdgeInsets.all(recordMode ? 0 : 5),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: recordMode ? 250 : 280,
                child: _UnitHeading(
                  recordMode: recordMode,
                  name: base.name.trim().isEmpty
                      ? strings.landBase(base.baseId)
                      : base.name,
                  portrait: Container(
                    key: Key(
                      'composition-base-portrait-${base.areaId}-${base.baseId}',
                    ),
                    width: recordMode ? 92 : 112,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xff1b3d43),
                      border: Border.all(color: const Color(0xff547485)),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: SlotItemPortrait(
                      item: representative,
                      serverOrigin: state.serverOrigin,
                      width: recordMode ? 92 : 112,
                      height: 60,
                      fit: BoxFit.cover,
                    ),
                  ),
                  trailing: Row(
                    children: [
                      if (recordMode)
                        Text(
                          strings.baseMode(base.actionKind),
                          style: const TextStyle(
                            color: _cyan,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        )
                      else
                        _Pill(
                          text: strings.baseMode(base.actionKind),
                          color: _cyan,
                          bold: true,
                        ),
                      const SizedBox(width: 4),
                      if (recordMode)
                        Text(
                          strings.range(base.effectiveDistance),
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        )
                      else
                        _Pill(
                          text: strings.range(base.effectiveDistance),
                          color: _muted,
                          bold: true,
                        ),
                    ],
                  ),
                ),
              ),
              if (!recordMode) const SizedBox(width: 7),
              for (var index = 1; index <= 4; index++) ...[
                if (!recordMode && index > 1) const SizedBox(width: 6),
                Expanded(
                  child: _EquipmentRow(
                    state: state,
                    suffix: 'base-${base.areaId}-${base.baseId}-$index',
                    label: strings.squadron(index),
                    showLabel: false,
                    itemId: squadrons[index]?.slotItemId ?? -1,
                    planeCount: mode == CompositionPlaneCountMode.maximum
                        ? squadrons[index]?.maxCount
                        : squadrons[index]?.currentCount,
                    showPlaneCount: mode != CompositionPlaneCountMode.hidden,
                    isLandBase: true,
                    recordMode: recordMode,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _UnitHeading extends StatelessWidget {
  const _UnitHeading({
    required this.name,
    this.recordMode = false,
    this.type,
    this.level,
    this.luck,
    this.portrait,
    this.trailing,
  });

  final String name;
  final bool recordMode;
  final String? type;
  final int? level;
  final int? luck;
  final Widget? portrait;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: const Color(0xff203b49),
      borderRadius: recordMode ? null : BorderRadius.circular(8),
      border: null,
    ),
    child: Row(
      children: [
        if (portrait != null)
          ClipRRect(
            borderRadius: recordMode
                ? BorderRadius.zero
                : const BorderRadius.horizontal(left: Radius.circular(7)),
            child: portrait!,
          )
        else
          SizedBox(
            width: recordMode ? 92 : 112,
            height: 60,
            child: const Icon(Icons.sailing_outlined, color: _muted, size: 32),
          ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 7),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (type != null) ...[
                  Text(
                    type!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                ],
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (trailing != null) ...[const SizedBox(height: 5), trailing!],
                if (level != null) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (recordMode)
                        Text(
                          CompositionImageStrings.of(context).level(level!),
                          style: const TextStyle(
                            color: _gold,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        )
                      else
                        _Pill(
                          text: CompositionImageStrings.of(
                            context,
                          ).level(level!),
                          color: _gold,
                          compact: true,
                        ),
                      const SizedBox(width: 3),
                      if (recordMode)
                        Text(
                          '${CompositionImageStrings.of(context).luck} ${luck ?? 0}',
                          style: const TextStyle(
                            color: _cyan,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        )
                      else
                        _Pill(
                          text:
                              '${CompositionImageStrings.of(context).luck} ${luck ?? 0}',
                          color: _cyan,
                          compact: true,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _EquipmentRow extends StatelessWidget {
  const _EquipmentRow({
    required this.state,
    required this.suffix,
    required this.label,
    required this.itemId,
    this.planeCount,
    this.showPlaneCount = false,
    this.isLandBase = false,
    this.isExpansion = false,
    this.showLabel = true,
    this.recordMode = false,
  });

  final GameState state;
  final String suffix;
  final String label;
  final int itemId;
  final int? planeCount;
  final bool showPlaneCount;
  final bool isLandBase;
  final bool isExpansion;
  final bool showLabel;
  final bool recordMode;

  @override
  Widget build(BuildContext context) {
    final strings = CompositionImageStrings.of(context);
    final item = state.slotItems[itemId];
    final master = item == null
        ? null
        : state.masterSlotItems[item.masterSlotItemId];
    final empty = itemId <= 0;
    final aircraft = _isAircraft(master) || (isLandBase && !empty);
    return Container(
      key: Key('composition-slot-$suffix'),
      constraints: const BoxConstraints(minHeight: 60),
      padding: EdgeInsets.symmetric(
        horizontal: recordMode ? 4 : 5,
        vertical: recordMode ? 1 : 3,
      ),
      decoration: BoxDecoration(
        color: isExpansion ? const Color(0xff202e36) : const Color(0xff102b39),
        border: recordMode
            ? Border(
                left: BorderSide(
                  color: isExpansion
                      ? const Color(0xff9b7e4d)
                      : _recordColumnLine,
                  width: 1.2,
                ),
              )
            : Border.all(
                color: isExpansion
                    ? const Color(0xff786643)
                    : const Color(0xff32515e),
              ),
        borderRadius: recordMode ? null : BorderRadius.circular(7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showLabel) ...[
            Text(
              label,
              style: TextStyle(
                color: isExpansion ? _gold : const Color(0xff83a4b3),
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
          ],
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (!empty)
                  EquipmentTypeIconImage(
                    iconId: master != null && master.type.length > 3
                        ? master.type[3]
                        : -1,
                    width: isLandBase ? 30 : 24,
                    height: isLandBase ? 30 : 24,
                  )
                else
                  Icon(
                    itemId == 0 && isExpansion
                        ? Icons.lock_outline
                        : Icons.remove,
                    color: const Color(0xff496477),
                    size: 24,
                  ),
                const SizedBox(width: 5),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _EquipmentName(
                        name: empty
                            ? strings.emptySlot
                            : master?.name ?? strings.missingEquipment,
                        textKey: Key('composition-equipment-name-$suffix'),
                        empty: empty,
                      ),
                      if (item != null &&
                          ((aircraft && item.proficiency > 0) ||
                              item.level > 0 ||
                              (aircraft && showPlaneCount))) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            if (item.level > 0) ...[
                              Text(
                                '★${item.level}',
                                style: const TextStyle(
                                  color: _cyan,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 3),
                            ],
                            if (aircraft && item.proficiency > 0) ...[
                              Image.asset(
                                'assets/images/airplane/alv${item.proficiency.clamp(1, 7)}.png',
                                key: Key('composition-proficiency-$suffix'),
                                width: 16,
                                height: 12,
                              ),
                              const SizedBox(width: 3),
                            ],
                            if (aircraft && showPlaneCount)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xff16373e),
                                  border: Border.all(
                                    color: const Color(0xff315b60),
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  planeCount?.toString() ?? '—',
                                  key: Key('composition-plane-count-$suffix'),
                                  style: const TextStyle(
                                    color: _cyan,
                                    fontSize: 9,
                                    height: 1,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EquipmentName extends StatelessWidget {
  const _EquipmentName({
    required this.name,
    required this.textKey,
    required this.empty,
  });

  final String name;
  final Key textKey;
  final bool empty;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerLeft,
    child: Text(
      name,
      key: textKey,
      maxLines: 1,
      softWrap: false,
      style: TextStyle(
        color: empty ? const Color(0xff708c9e) : _ink,
        fontSize: 13,
        height: 1.2,
        fontWeight: empty ? FontWeight.w400 : FontWeight.w700,
      ),
    ),
  );
}

bool _isAircraft(MasterSlotItem? item) {
  if (item == null || item.type.length < 3) return false;
  final type = item.type[2];
  return (type >= 6 && type <= 11) ||
      (type >= 25 && type <= 26) ||
      (type >= 47 && type <= 48) ||
      (type >= 56 && type <= 59) ||
      const {41, 45, 94}.contains(type);
}

class _RosterPanel extends StatelessWidget {
  const _RosterPanel({required this.child, this.recordMode = false});
  final Widget child;
  final bool recordMode;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: const Color(0xff142c3c),
      borderRadius: recordMode ? null : BorderRadius.circular(13),
      border: recordMode
          ? const Border(
              left: BorderSide(color: _recordGridLine, width: 1.2),
              right: BorderSide(color: _recordGridLine, width: 1.2),
              bottom: BorderSide(color: _recordGridLine, width: 1.2),
            )
          : Border.all(color: const Color(0xff355063)),
      boxShadow: recordMode
          ? null
          : const [
              BoxShadow(
                color: Color(0x18000000),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
    ),
    child: child,
  );
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.text,
    required this.color,
    this.icon,
    this.textKey,
    this.compact = false,
    this.bold = false,
  });
  final String text;
  final Color color;
  final IconData? icon;
  final Key? textKey;
  final bool compact;
  final bool bold;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: compact ? 5 : 9,
      vertical: compact ? 2 : 4,
    ),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withValues(alpha: .23)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
        ],
        Text(
          text,
          key: textKey,
          style: TextStyle(
            color: color,
            fontSize: compact ? 9 : 11,
            fontWeight: compact || bold ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 34),
    child: Text(text, textAlign: TextAlign.center, style: _mutedStyle),
  );
}

class _PaperLines extends CustomPainter {
  const _PaperLines();

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = const Color(0x0669c9c1)
      ..strokeWidth = .5;
    for (var y = 0.0; y < size.height; y += 32) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
    for (var x = 0.0; x < size.width; x += 32) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
  }

  @override
  bool shouldRepaint(_PaperLines oldDelegate) => false;
}
