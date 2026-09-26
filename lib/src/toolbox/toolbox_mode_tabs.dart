import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'composition_image_strings.dart';
import 'sortie_map_query/sortie_map_query_strings.dart';
import 'toolbox_mode.dart';

class ToolboxModeTabs extends StatelessWidget {
  const ToolboxModeTabs({
    super.key,
    required this.mode,
    required this.onChanged,
    this.compact = false,
  });

  final ToolboxMode mode;
  final ValueChanged<ToolboxMode> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    String label(ToolboxMode value) => switch (value) {
      ToolboxMode.export => l10n.fleetExport,
      ToolboxMode.composition => CompositionImageStrings.of(context).title,
      ToolboxMode.expCalc => l10n.expCalculator,
      ToolboxMode.mapQuery => SortieMapQueryStrings.of(context).title,
      ToolboxMode.other => l10n.otherTools,
    };
    return Container(
      key: const Key('toolbox-mode-tabs'),
      width: compact ? null : 400,
      height: compact ? 36 : 38,
      padding: EdgeInsets.all(compact ? 1 : 3),
      decoration: BoxDecoration(
        color: const Color(0xff0b202d),
        border: Border.all(color: const Color(0xff315064)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          for (final value in ToolboxMode.values)
            Expanded(
              child: Semantics(
                button: true,
                selected: mode == value,
                label: label(value),
                excludeSemantics: true,
                onTap: () => onChanged(value),
                child: Material(
                  key: Key('toolbox-tab-${value.name}'),
                  color: mode == value
                      ? const Color(0xff8a6628)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => onChanged(value),
                    child: Center(
                      child: Text(
                        label(value),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: mode == value
                              ? const Color(0xffffdc88)
                              : const Color(0xff9fb3bf),
                          fontSize: compact ? 10 : 12,
                          fontWeight: FontWeight.w800,
                        ),
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
}
