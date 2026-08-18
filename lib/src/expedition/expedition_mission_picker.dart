import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game_state/game_state.dart';
import 'expedition_strings.dart';

const _poiAreaOrder = <int>[1, 2, 3, 7, 4, 5, 6];

class ExpeditionAreaGroup {
  const ExpeditionAreaGroup({required this.areaId, required this.missionIds});

  final int areaId;
  final List<int> missionIds;
}

List<ExpeditionAreaGroup> groupExpeditionMissions(
  Map<int, MasterMission> missions,
  Iterable<int> missionIds,
) {
  final byArea = <int, List<int>>{};
  for (final missionId in missionIds) {
    final masterAreaId = missions[missionId]?.mapAreaId ?? 0;
    final areaId = masterAreaId > 0
        ? masterAreaId
        : expeditionAreaIdForMission(missionId);
    if (areaId <= 0) continue;
    byArea.putIfAbsent(areaId, () => <int>[]).add(missionId);
  }
  for (final values in byArea.values) {
    values.sort();
  }
  final orderedAreaIds = <int>[
    for (final areaId in _poiAreaOrder)
      if (byArea.containsKey(areaId)) areaId,
    for (final areaId in byArea.keys.toList()..sort())
      if (!_poiAreaOrder.contains(areaId)) areaId,
  ];
  return <ExpeditionAreaGroup>[
    for (final areaId in orderedAreaIds)
      ExpeditionAreaGroup(
        areaId: areaId,
        missionIds: List<int>.unmodifiable(byArea[areaId]!),
      ),
  ];
}

int expeditionAreaIdForMission(int missionId) => switch (missionId) {
  >= 1 && <= 8 || >= 100 && <= 105 => 1,
  >= 9 && <= 16 || >= 110 && <= 115 => 2,
  >= 17 && <= 24 => 3,
  >= 25 && <= 32 || >= 131 && <= 133 => 4,
  >= 33 && <= 40 || >= 141 && <= 142 => 5,
  >= 41 && <= 46 => 7,
  _ => 0,
};

String expeditionDisplayId(int missionId, MasterMission? mission) {
  if (mission?.displayNumber.isNotEmpty ?? false) {
    return mission!.displayNumber;
  }
  return switch (missionId) {
    >= 100 && <= 105 => 'A${missionId - 99}',
    >= 110 && <= 115 => 'B${missionId - 109}',
    >= 131 && <= 133 => 'D${missionId - 130}',
    >= 141 && <= 142 => 'E${missionId - 140}',
    _ => '$missionId',
  };
}

class ExpeditionMissionPicker extends StatelessWidget {
  const ExpeditionMissionPicker({
    super.key,
    required this.missions,
    required this.missionIds,
    required this.selectedMissionId,
    required this.onSelected,
    this.selectedTextKey,
    this.compact = false,
  });

  final Map<int, MasterMission> missions;
  final Iterable<int> missionIds;
  final int selectedMissionId;
  final ValueChanged<int> onSelected;
  final Key? selectedTextKey;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final mission = missions[selectedMissionId];
    final label =
        '${expeditionDisplayId(selectedMissionId, mission)} · ${mission?.name ?? ExpeditionStrings.of(context).expeditionFallbackName}';
    return Material(
      key: const Key('expedition-mission-picker'),
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(5),
        onTap: () => _showPicker(context),
        child: Container(
          height: compact ? 34 : 40,
          padding: EdgeInsets.symmetric(
            horizontal: 10,
            vertical: compact ? 5 : 8,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xff536772)),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Row(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final text = Text(
                      label,
                      key: selectedTextKey,
                      maxLines: 1,
                      softWrap: false,
                      overflow: compact ? TextOverflow.ellipsis : null,
                      style: TextStyle(
                        fontSize: compact && constraints.maxWidth < 300
                            ? 11
                            : compact
                            ? 12
                            : 13,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                    return compact
                        ? text
                        : FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: text,
                          );
                  },
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.unfold_more_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showPicker(BuildContext context) async {
    final groups = groupExpeditionMissions(missions, missionIds);
    if (groups.isEmpty) return;
    final selectedAreaId = groups
        .firstWhere(
          (group) => group.missionIds.contains(selectedMissionId),
          orElse: () => groups.first,
        )
        .areaId;
    final selected = await showDialog<int>(
      context: context,
      builder: (dialogContext) => _ExpeditionMissionPickerDialog(
        groups: groups,
        missions: missions,
        selectedAreaId: selectedAreaId,
        selectedMissionId: selectedMissionId,
      ),
    );
    if (selected != null) onSelected(selected);
  }
}

class _ExpeditionMissionPickerDialog extends StatefulWidget {
  const _ExpeditionMissionPickerDialog({
    required this.groups,
    required this.missions,
    required this.selectedAreaId,
    required this.selectedMissionId,
  });

  final List<ExpeditionAreaGroup> groups;
  final Map<int, MasterMission> missions;
  final int selectedAreaId;
  final int selectedMissionId;

  @override
  State<_ExpeditionMissionPickerDialog> createState() =>
      _ExpeditionMissionPickerDialogState();
}

class _ExpeditionMissionPickerDialogState
    extends State<_ExpeditionMissionPickerDialog> {
  late int areaId = widget.selectedAreaId;

  @override
  Widget build(BuildContext context) {
    final strings = ExpeditionStrings.of(context);
    final screen = MediaQuery.sizeOf(context);
    final width = math.min(720.0, math.max(300.0, screen.width - 32));
    final height = math.min(560.0, math.max(360.0, screen.height * 0.72));
    final leftWidth = (width * 0.29).clamp(112.0, 190.0);
    final group = widget.groups.firstWhere((value) => value.areaId == areaId);
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: Colors.transparent,
      child: Container(
        key: const Key('expedition-mission-picker-dialog'),
        width: width,
        height: height,
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
          children: [
            _DialogHeader(strings: strings),
            const Divider(height: 1, color: Color(0xff385064)),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: leftWidth,
                    child: _AreaList(
                      groups: widget.groups,
                      selectedAreaId: areaId,
                      strings: strings,
                      onSelected: (value) => setState(() => areaId = value),
                    ),
                  ),
                  const VerticalDivider(width: 1, color: Color(0xff385064)),
                  Expanded(
                    child: _MissionList(
                      missionIds: group.missionIds,
                      missions: widget.missions,
                      selectedMissionId: widget.selectedMissionId,
                      fallbackName: strings.expeditionFallbackName,
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

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({required this.strings});

  final ExpeditionStrings strings;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 52,
    child: Row(
      children: [
        const SizedBox(width: 16),
        const Icon(Icons.public_rounded, size: 20, color: Color(0xffd4a85f)),
        const SizedBox(width: 8),
        Text(
          strings.selectExpedition,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const Spacer(),
        IconButton(
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
        ),
        const SizedBox(width: 4),
      ],
    ),
  );
}

class _AreaList extends StatelessWidget {
  const _AreaList({
    required this.groups,
    required this.selectedAreaId,
    required this.strings,
    required this.onSelected,
  });

  final List<ExpeditionAreaGroup> groups;
  final int selectedAreaId;
  final ExpeditionStrings strings;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xff0b1720),
    child: ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        final selected = group.areaId == selectedAreaId;
        return Material(
          color: selected ? const Color(0xff244b69) : Colors.transparent,
          child: InkWell(
            key: Key('expedition-area-${group.areaId}'),
            onTap: () => onSelected(group.areaId),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Text(
                strings.expeditionAreaName(group.areaId),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0xffc3d0d7),
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _MissionList extends StatelessWidget {
  const _MissionList({
    required this.missionIds,
    required this.missions,
    required this.selectedMissionId,
    required this.fallbackName,
  });

  final List<int> missionIds;
  final Map<int, MasterMission> missions;
  final int selectedMissionId;
  final String fallbackName;

  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.all(10),
    itemCount: missionIds.length,
    separatorBuilder: (_, _) => const SizedBox(height: 5),
    itemBuilder: (context, index) {
      final missionId = missionIds[index];
      final mission = missions[missionId];
      final selected = missionId == selectedMissionId;
      return Material(
        color: selected ? const Color(0xff1d5f91) : const Color(0xff172a38),
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          key: Key('expedition-mission-option-$missionId'),
          borderRadius: BorderRadius.circular(7),
          onTap: () => Navigator.of(context).pop(missionId),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Container(
                  constraints: const BoxConstraints(minWidth: 40),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xff68b7ef)
                        : const Color(0xff263e4e),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    expeditionDisplayId(missionId, mission),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected
                          ? const Color(0xff071722)
                          : const Color(0xffdce6eb),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    mission?.name ?? fallbackName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
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
    },
  );
}
