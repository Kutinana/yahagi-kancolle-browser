import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../fleet/equipment_type_icon.dart';
import 'equipment_development_controller.dart';

Future<void> showDevelopmentEquipmentPicker(
  BuildContext context,
  EquipmentDevelopmentController controller,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: const Color(0xff091b25),
  builder: (sheetContext) => FractionallySizedBox(
    heightFactor: 0.84,
    child: AnimatedBuilder(
      animation: controller,
      builder: (context, _) =>
          _DevelopmentEquipmentPicker(controller: controller),
    ),
  ),
);

class _DevelopmentEquipmentPicker extends StatelessWidget {
  const _DevelopmentEquipmentPicker({required this.controller});
  final EquipmentDevelopmentController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final typeIds =
        controller.dataset?.equipment.values
            .map((item) => item.typeId)
            .toSet()
            .toList() ??
        <int>[];
    typeIds.sort();
    return SafeArea(
      key: const Key('development-target-sheet'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xff496676),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.developmentChooseTarget,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        l10n.developmentSelectedCount(
                          controller.targets.length,
                        ),
                        style: const TextStyle(color: Color(0xff89a5b3)),
                      ),
                    ],
                  ),
                ),
                FloatingActionButton.small(
                  key: const Key('development-search-button'),
                  tooltip: l10n.developmentSearchEquipment,
                  heroTag: 'development-search',
                  backgroundColor: controller.equipmentSearch.isEmpty
                      ? const Color(0xff315365)
                      : const Color(0xffb98530),
                  foregroundColor: const Color(0xff08151d),
                  onPressed: () => _showSearchDialog(context, controller),
                  child: const Icon(Icons.search),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int?>(
              key: const Key('development-equipment-type-filter'),
              initialValue: controller.equipmentTypeFilter,
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: const Color(0xff102a38),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              items: [
                DropdownMenuItem<int?>(
                  value: null,
                  child: Text(l10n.developmentAllTypes),
                ),
                for (final typeId in typeIds)
                  DropdownMenuItem<int?>(
                    value: typeId,
                    child: Text('#$typeId'),
                  ),
              ],
              onChanged: controller.setEquipmentTypeFilter,
            ),
            if (controller.equipmentSearch.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: InputChip(
                  label: Text(controller.equipmentSearch),
                  avatar: const Icon(Icons.search, size: 16),
                  onDeleted: () => controller.setEquipmentSearch(''),
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: controller.filteredEquipment.isEmpty
                  ? Center(
                      child: Text(
                        l10n.developmentNoResults,
                        style: const TextStyle(color: Color(0xff91a9b5)),
                      ),
                    )
                  : ListView.builder(
                      itemCount: controller.filteredEquipment.length,
                      itemBuilder: (context, index) {
                        final equipment = controller.filteredEquipment[index];
                        final selected = controller.targets.contains(
                          equipment.id,
                        );
                        final enabled =
                            selected ||
                            controller.enabledEquipment.contains(equipment.id);
                        return Card(
                          color: selected
                              ? const Color(0xff3b301d)
                              : const Color(0xff102a38),
                          margin: const EdgeInsets.only(bottom: 6),
                          child: ListTile(
                            key: Key('development-equipment-${equipment.id}'),
                            enabled: enabled,
                            onTap: enabled
                                ? () => controller.toggleTarget(equipment.id)
                                : null,
                            leading: EquipmentTypeIconImage(
                              iconId: equipment.iconId,
                              width: 36,
                              height: 36,
                            ),
                            title: Text(
                              controller.equipmentName(equipment),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              'ID ${equipment.id}  ·  #${equipment.typeId}',
                            ),
                            trailing: Icon(
                              selected
                                  ? Icons.check_circle
                                  : Icons.add_circle_outline,
                              color: selected
                                  ? const Color(0xffffc85a)
                                  : const Color(0xff7594a4),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
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
