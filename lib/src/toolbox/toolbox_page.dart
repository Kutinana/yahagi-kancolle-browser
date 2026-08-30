import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../game_state/game_state.dart';
import 'fleet_export_page.dart';

enum ToolboxMode { fleetExport, other }

class ToolboxPage extends StatelessWidget {
  const ToolboxPage({
    super.key,
    required this.state,
    this.mode = ToolboxMode.fleetExport,
  });

  final GameState state;
  final ToolboxMode mode;

  @override
  Widget build(BuildContext context) {
    if (mode == ToolboxMode.fleetExport) {
      return FleetExportPage(state: state);
    }
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.otherToolsComingSoon),
          const SizedBox(height: 8),
          Text(l10n.otherToolsHint),
        ],
      ),
    );
  }
}
