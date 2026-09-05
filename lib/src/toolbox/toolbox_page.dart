import 'package:flutter/material.dart';

import '../game_state/game_state.dart';
import 'fleet_export_page.dart';

class ToolboxPage extends StatelessWidget {
  const ToolboxPage({super.key, required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) => FleetExportPage(state: state);
}
