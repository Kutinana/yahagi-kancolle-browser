import 'package:flutter/material.dart';
import '../fleet/fleet_ui_strings.dart';
import 'fleet_display_options.dart';
import 'layout_settings_controller.dart';

class FleetDisplaySettingsSection extends StatelessWidget {
  const FleetDisplaySettingsSection({
    super.key,
    required this.controller,
    this.twoColumns = false,
  });
  final bool twoColumns;
  final LayoutSettingsController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final limit = twoColumns ? 7 : maximumSummaryFields;
      final visible = twoColumns
          ? controller.hdFleetDisplayFields
          : controller.fleetDisplayFields;
      void save(Set<String> fields) {
        if (twoColumns) {
          controller.setHdFleetDisplayFields(fields);
        } else {
          controller.setFleetDisplayFields(fields);
        }
      }

      final count = visible.intersection(summaryFields).length;
      void change(String key, bool enabled) {
        if (enabled && summaryFields.contains(key) && count >= limit) {
          return;
        }
        final next = {...visible};
        enabled ? next.add(key) : next.remove(key);
        save(next);
      }

      String text(String value) => fleetText(context, value);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    text(FleetUiKeys.fleetSummaryDisplay),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  key: const Key('fleet-display-default'),
                  tooltip: text(FleetUiKeys.reset),
                  icon: const Icon(
                    Icons.settings_backup_restore_rounded,
                    color: Color(0xff8fa8b6),
                  ),
                  onPressed: () {
                    controller.setModuleShowLogo('fleet', true);
                    controller.setModuleShowName('fleet', true);
                    controller.setFleetSelectorLabelMode(
                      FleetSelectorLabelMode.customName,
                    );
                    save({
                      ...defaultFields,
                      if (twoColumns) ...{'firepower', 'anti-sub'},
                    });
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xff294052)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              text(FleetUiKeys.capsuleAppearance),
              style: const TextStyle(
                color: Color(0xffd8ad60),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 2,
              children: [
                FilterChip(
                  key: const Key('fleet-capsule-logo'),
                  label: Text(text('LOGO')),
                  selected: controller.moduleShowLogo('fleet'),
                  showCheckmark: false,
                  onSelected: (enabled) {
                    controller.setModuleShowLogo('fleet', enabled);
                  },
                ),
                FilterChip(
                  key: const Key('fleet-capsule-name'),
                  label: Text(text(FleetUiKeys.name)),
                  selected: controller.moduleShowName('fleet'),
                  showCheckmark: false,
                  onSelected: (enabled) {
                    controller.setModuleShowName('fleet', enabled);
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xff294052)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              text(FleetUiKeys.fleetSelectorName),
              style: const TextStyle(
                color: Color(0xffd8ad60),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 2,
              children: [
                ChoiceChip(
                  key: const Key('fleet-selector-label-custom-name'),
                  label: Text(text(FleetUiKeys.customFleetName)),
                  selected:
                      controller.fleetSelectorLabelMode ==
                      FleetSelectorLabelMode.customName,
                  showCheckmark: false,
                  onSelected: (_) => controller.setFleetSelectorLabelMode(
                    FleetSelectorLabelMode.customName,
                  ),
                ),
                ChoiceChip(
                  key: const Key('fleet-selector-label-number'),
                  label: Text(text(FleetUiKeys.shortFleetNumber)),
                  selected:
                      controller.fleetSelectorLabelMode ==
                      FleetSelectorLabelMode.number,
                  showCheckmark: false,
                  onSelected: (_) => controller.setFleetSelectorLabelMode(
                    FleetSelectorLabelMode.number,
                  ),
                ),
              ],
            ),
          ),
          for (final group in displayGroups.entries) ...[
            const Divider(height: 1, color: Color(0xff294052)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                '${text(group.key)}${group.key == FleetUiKeys.summaryGroup ? ' · $count / $limit' : ''}',
                style: const TextStyle(
                  color: Color(0xffd8ad60),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (group.key == FleetUiKeys.summaryGroup)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  text(FleetUiKeys.summaryLimitHint).replaceAll('5', '$limit'),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 2,
                children: [
                  for (final item in group.value.entries)
                    FilterChip(
                      key: Key('fleet-display-${item.key}'),
                      label: Text(text(item.value)),
                      selected: visible.contains(item.key),
                      onSelected:
                          summaryFields.contains(item.key) &&
                              !visible.contains(item.key) &&
                              count >= limit
                          ? null
                          : (value) => change(item.key, value),
                      tooltip: item.key == 'mechanisms'
                          ? text(FleetUiKeys.mechanismsHint)
                          : null,
                      // Selection is indicated by the background only.
                      showCheckmark: false,
                    ),
                ],
              ),
            ),
            if (group.key == FleetUiKeys.singleShipGroup) ...[
              const Divider(height: 1, color: Color(0xff294052)),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  text(FleetUiKeys.shipTypeName),
                  style: const TextStyle(
                    color: Color(0xffd8ad60),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 2,
                  children: [
                    ChoiceChip(
                      key: const Key('fleet-ship-type-label-localized'),
                      label: Text(text(FleetUiKeys.chinese)),
                      selected:
                          controller.fleetShipTypeLabelMode ==
                          FleetShipTypeLabelMode.localizedName,
                      showCheckmark: false,
                      onSelected: (_) => controller.setFleetShipTypeLabelMode(
                        FleetShipTypeLabelMode.localizedName,
                      ),
                    ),
                    ChoiceChip(
                      key: const Key('fleet-ship-type-label-abbreviation'),
                      label: Text(text(FleetUiKeys.englishAbbreviation)),
                      selected:
                          controller.fleetShipTypeLabelMode ==
                          FleetShipTypeLabelMode.abbreviation,
                      showCheckmark: false,
                      onSelected: (_) => controller.setFleetShipTypeLabelMode(
                        FleetShipTypeLabelMode.abbreviation,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      );
    },
  );
}

Future<void> showFleetDisplaySettings(
  BuildContext context,
  LayoutSettingsController controller, {
  bool twoColumns = false,
}) => showDialog<void>(
  context: context,
  builder: (context) => Dialog(
    backgroundColor: const Color(0xff142735),
    insetPadding: const EdgeInsets.all(16),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              key: const Key('fleet-display-close'),
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              child: FleetDisplaySettingsSection(
                controller: controller,
                twoColumns: twoColumns,
              ),
            ),
          ),
        ],
      ),
    ),
  ),
);
