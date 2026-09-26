import 'package:flutter/material.dart';
import '../fleet/fleet_ui_strings.dart';
import 'fleet_display_options.dart';
import 'layout_settings_controller.dart';

FleetSelectorLabelMode _repairFleetSelectorLabelMode =
    FleetSelectorLabelMode.customName;

FleetSelectorLabelMode get repairFleetSelectorLabelModeSetting =>
    _repairFleetSelectorLabelMode;

void setRepairFleetSelectorLabelModeSetting(FleetSelectorLabelMode mode) {
  _repairFleetSelectorLabelMode = mode;
}

const moduleDisplayOptions = FleetUiKeys.moduleDisplayOptions;
const moduleDisplayTitles = FleetUiKeys.moduleDisplayTitles;

abstract class ModuleDisplaySettingsStore {
  Future<List<String>?> loadModuleDisplayFields(String module);
  Future<void> saveModuleDisplayFields(String module, List<String> fields);
  Future<bool> loadModuleShowLogo(String module) async => true;
  Future<void> saveModuleShowLogo(String module, bool show) async {}
  Future<bool> loadModuleShowName(String module) async => true;
  Future<void> saveModuleShowName(String module, bool show) async {}
  Future<FleetSelectorLabelMode> loadRepairFleetSelectorLabelMode() async =>
      FleetSelectorLabelMode.customName;
  Future<void> saveRepairFleetSelectorLabelMode(
    FleetSelectorLabelMode mode,
  ) async {}
}

Widget? moduleDisplayGear(
  BuildContext context,
  String module,
  VoidCallback? onPressed,
) => onPressed == null
    ? null
    : IconButton(
        key: Key('$module-display-settings-button'),
        tooltip: fleetText(
          context,
          moduleDisplayTitles[module] ?? FleetUiKeys.displayContent,
        ),
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        padding: EdgeInsets.zero,
        icon: const Icon(
          Icons.settings_outlined,
          size: 19,
          color: Color(0xffd4a85f),
        ),
        onPressed: onPressed,
      );

Future<void> showModuleDisplaySettings(
  BuildContext context,
  LayoutSettingsController controller,
  String module,
) => showDialog<void>(
  context: context,
  builder: (context) => Dialog(
    backgroundColor: const Color(0xff142735),
    insetPadding: const EdgeInsets.all(16),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final fields = controller.moduleDisplayFields(module);
          final options =
              moduleDisplayOptions[module] ?? const <String, String>{};
          final hasOptions = options.isNotEmpty;
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          fleetText(
                            context,
                            moduleDisplayTitles[module] ??
                                FleetUiKeys.displayContent,
                          ),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        key: Key('$module-display-reset'),
                        tooltip: fleetText(context, FleetUiKeys.reset),
                        icon: const Icon(Icons.settings_backup_restore_rounded),
                        onPressed: () {
                          controller.setModuleShowLogo(module, true);
                          controller.setModuleShowName(module, true);
                          if (hasOptions) {
                            controller.setModuleDisplayFields(
                              module,
                              options.keys,
                            );
                          }
                          if (module == 'repair') {
                            controller.setRepairFleetSelectorLabelMode(
                              FleetSelectorLabelMode.customName,
                            );
                          }
                        },
                      ),
                      const Spacer(),
                      IconButton(
                        key: Key('$module-display-close'),
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).closeButtonTooltip,
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    fleetText(context, FleetUiKeys.capsuleAppearance),
                    style: const TextStyle(
                      color: Color(0xffd8ad60),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      FilterChip(
                        key: Key('$module-capsule-logo'),
                        label: Text(fleetText(context, 'LOGO')),
                        selected: controller.moduleShowLogo(module),
                        showCheckmark: false,
                        onSelected: (enabled) {
                          controller.setModuleShowLogo(module, enabled);
                        },
                      ),
                      FilterChip(
                        key: Key('$module-capsule-name'),
                        label: Text(fleetText(context, FleetUiKeys.name)),
                        selected: controller.moduleShowName(module),
                        showCheckmark: false,
                        onSelected: (enabled) {
                          controller.setModuleShowName(module, enabled);
                        },
                      ),
                    ],
                  ),
                  if (hasOptions) ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: Color(0xff294052)),
                    const SizedBox(height: 8),
                    Text(
                      fleetText(context, FleetUiKeys.displayContent),
                      style: const TextStyle(
                        color: Color(0xffd8ad60),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final item in options.entries)
                          FilterChip(
                            key: Key('$module-display-${item.key}'),
                            label: Text(fleetText(context, item.value)),
                            selected: fields.contains(item.key),
                            showCheckmark: false,
                            onSelected: (enabled) {
                              final next = {...fields};
                              enabled
                                  ? next.add(item.key)
                                  : next.remove(item.key);
                              controller.setModuleDisplayFields(module, next);
                            },
                          ),
                      ],
                    ),
                  ],
                  if (module == 'repair') ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: Color(0xff294052)),
                    const SizedBox(height: 8),
                    Text(
                      fleetText(context, FleetUiKeys.fleetSelectorName),
                      style: const TextStyle(
                        color: Color(0xffd8ad60),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        ChoiceChip(
                          key: const Key('repair-selector-label-custom-name'),
                          label: Text(
                            fleetText(context, FleetUiKeys.customFleetName),
                          ),
                          selected:
                              controller.repairFleetSelectorLabelMode ==
                              FleetSelectorLabelMode.customName,
                          showCheckmark: false,
                          onSelected: (_) {
                            controller.setRepairFleetSelectorLabelMode(
                              FleetSelectorLabelMode.customName,
                            );
                          },
                        ),
                        ChoiceChip(
                          key: const Key('repair-selector-label-number'),
                          label: Text(
                            fleetText(context, FleetUiKeys.shortFleetNumber),
                          ),
                          selected:
                              controller.repairFleetSelectorLabelMode ==
                              FleetSelectorLabelMode.number,
                          showCheckmark: false,
                          onSelected: (_) {
                            controller.setRepairFleetSelectorLabelMode(
                              FleetSelectorLabelMode.number,
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    ),
  ),
);

class ModuleSlotGrid extends StatelessWidget {
  const ModuleSlotGrid({
    super.key,
    required this.children,
    required this.emptyLabel,
    this.columns = 2,
  });
  final int columns;
  final List<Widget> children;
  final String emptyLabel;
  @override
  Widget build(BuildContext context) => children.isEmpty
      ? Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            fleetText(context, emptyLabel),
            style: const TextStyle(color: Color(0xff8197a5)),
          ),
        )
      : LayoutBuilder(
          builder: (context, constraints) => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final child in children)
                SizedBox(
                  width: (constraints.maxWidth - 8 * (columns - 1)) / columns,
                  child: child,
                ),
            ],
          ),
        );
}
