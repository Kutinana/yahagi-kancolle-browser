import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../fleet/equipment_type_icon.dart';
import 'development_dataset.dart';
import 'equipment_development_controller.dart';

Future<void> showDevelopmentEquipmentPicker(
  BuildContext context,
  EquipmentDevelopmentController controller,
) => showDialog<void>(
  context: context,
  builder: (dialogContext) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) =>
        _DevelopmentEquipmentPicker(controller: controller),
  ),
);

class _DevelopmentEquipmentPicker extends StatefulWidget {
  const _DevelopmentEquipmentPicker({required this.controller});

  final EquipmentDevelopmentController controller;

  @override
  State<_DevelopmentEquipmentPicker> createState() =>
      _DevelopmentEquipmentPickerState();
}

class _DevelopmentEquipmentPickerState
    extends State<_DevelopmentEquipmentPicker> {
  late int selectedTypeId = _initialTypeId();

  EquipmentDevelopmentController get controller => widget.controller;

  List<int> get typeIds {
    final values =
        controller.dataset?.equipment.values
            .map((item) => item.typeId)
            .toSet()
            .toList() ??
        <int>[];
    values.sort();
    return values;
  }

  int _initialTypeId() {
    final types = typeIds;
    final current = controller.equipmentTypeFilter;
    if (current != null && types.contains(current)) return current;
    for (final id in controller.targets) {
      final typeId = controller.dataset?.equipment[id]?.typeId;
      if (typeId != null && types.contains(typeId)) return typeId;
    }
    return types.isEmpty ? -1 : types.first;
  }

  String _typeLabel(AppLocalizations l10n, int typeId) {
    final value = controller.equipmentTypeName(typeId);
    return value == '—' ? l10n.developmentOtherSecretaryGroup : value;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final screen = MediaQuery.sizeOf(context);
    final width = math.min(720.0, math.max(300.0, screen.width - 32));
    final height = math.min(620.0, math.max(380.0, screen.height * 0.78));
    final leftWidth = (width * 0.3).clamp(112.0, 190.0);
    final types = typeIds;
    if (types.isNotEmpty && !types.contains(selectedTypeId)) {
      selectedTypeId = types.first;
    }
    final equipment = selectedTypeId < 0
        ? const <DevelopmentEquipmentRecord>[]
        : controller.filteredEquipmentForType(selectedTypeId);
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: Colors.transparent,
      child: Container(
        key: const Key('development-target-dialog'),
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
            _DialogHeader(controller: controller),
            const Divider(height: 1, color: Color(0xff385064)),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: leftWidth,
                    child: ColoredBox(
                      color: const Color(0xff0b1720),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: types.length,
                        itemBuilder: (context, index) {
                          final typeId = types[index];
                          final selected = typeId == selectedTypeId;
                          return Material(
                            color: selected
                                ? const Color(0xff244b69)
                                : Colors.transparent,
                            child: InkWell(
                              key: Key('development-equipment-type-$typeId'),
                              onTap: () =>
                                  setState(() => selectedTypeId = typeId),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 13,
                                ),
                                child: Text(
                                  _typeLabel(l10n, typeId),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: selected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const VerticalDivider(width: 1, color: Color(0xff385064)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (controller.equipmentSearch.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                            child: InputChip(
                              label: Text(controller.equipmentSearch),
                              avatar: const Icon(Icons.search, size: 16),
                              onDeleted: () =>
                                  controller.setEquipmentSearch(''),
                            ),
                          ),
                        Expanded(
                          child: equipment.isEmpty
                              ? Center(
                                  child: Text(
                                    l10n.developmentNoResults,
                                    style: const TextStyle(
                                      color: Color(0xff91a9b5),
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.all(10),
                                  itemCount: equipment.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 5),
                                  itemBuilder: (context, index) =>
                                      _EquipmentOption(
                                        controller: controller,
                                        equipment: equipment[index],
                                      ),
                                ),
                        ),
                      ],
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
  const _DialogHeader({required this.controller});

  final EquipmentDevelopmentController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      height: 58,
      child: Row(
        children: [
          const SizedBox(width: 16),
          const Icon(
            Icons.category_outlined,
            size: 20,
            color: Color(0xffd4a85f),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.developmentChooseTarget,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  l10n.developmentSelectedCount(controller.targets.length),
                  style: const TextStyle(
                    color: Color(0xff89a5b3),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            key: const Key('development-search-button'),
            tooltip: l10n.developmentSearchEquipment,
            onPressed: () => _showSearchDialog(context, controller),
            icon: const Icon(Icons.search, size: 20),
          ),
          const SizedBox(width: 4),
          IconButton(
            key: const Key('development-target-close'),
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _EquipmentOption extends StatelessWidget {
  const _EquipmentOption({required this.controller, required this.equipment});

  final EquipmentDevelopmentController controller;
  final DevelopmentEquipmentRecord equipment;

  @override
  Widget build(BuildContext context) {
    final selected = controller.targets.contains(equipment.id);
    final enabled =
        selected || controller.enabledEquipment.contains(equipment.id);
    return Material(
      color: selected ? const Color(0xff1d5f91) : const Color(0xff172a38),
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        key: Key('development-equipment-${equipment.id}'),
        borderRadius: BorderRadius.circular(7),
        onTap: enabled ? () => controller.toggleTarget(equipment.id) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              EquipmentTypeIconImage(
                iconId: equipment.iconId,
                width: 23,
                height: 23,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  controller.equipmentName(equipment),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: enabled
                        ? const Color(0xffedf4f6)
                        : const Color(0xff647986),
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.add_circle_outline,
                size: 19,
                color: selected
                    ? const Color(0xff68b7ef)
                    : enabled
                    ? const Color(0xff7594a4)
                    : const Color(0xff455966),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showSearchDialog(
  BuildContext context,
  EquipmentDevelopmentController controller,
) async {
  final value = await showDialog<String>(
    context: context,
    builder: (context) =>
        _DevelopmentSearchDialog(initialValue: controller.equipmentSearch),
  );
  if (value != null) controller.setEquipmentSearch(value.trim());
}

class _DevelopmentSearchDialog extends StatefulWidget {
  const _DevelopmentSearchDialog({required this.initialValue});

  final String initialValue;

  @override
  State<_DevelopmentSearchDialog> createState() =>
      _DevelopmentSearchDialogState();
}

class _DevelopmentSearchDialogState extends State<_DevelopmentSearchDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      key: const Key('development-search-dialog'),
      title: Text(l10n.developmentSearchEquipment),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          hintText: l10n.developmentSearchHint,
          prefixIcon: const Icon(Icons.search),
        ),
        onSubmitted: (value) => Navigator.pop(context, value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: Text(l10n.confirm),
        ),
      ],
    );
  }
}
