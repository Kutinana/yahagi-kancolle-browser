import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'toolbox_page.dart';

class ToolboxModeTabs extends StatelessWidget {
  const ToolboxModeTabs({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  final ToolboxMode mode;
  final ValueChanged<ToolboxMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      key: const Key('toolbox-mode-tabs'),
      width: 220,
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xff0b202d),
        border: Border.all(color: const Color(0xff315064)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          for (final value in ToolboxMode.values)
            Expanded(
              child: Material(
                color: mode == value
                    ? const Color(0xff8a6628)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  key: Key('toolbox-mode-${value.name}'),
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onChanged(value),
                  child: Center(
                    child: Text(
                      value == ToolboxMode.fleetExport
                          ? l10n.fleetExport
                          : l10n.otherTools,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: mode == value
                            ? const Color(0xffffdc88)
                            : const Color(0xff9fb3bf),
                        fontSize: 12,
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
}
