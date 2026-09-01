import 'package:flutter/material.dart';

import '../development/development_repository.dart';
import '../development/equipment_development_page.dart';
import '../game_state/game_state.dart';
import 'fleet_export_page.dart';

enum ToolboxMode { fleetExport, equipmentDevelopment }

class ToolboxPage extends StatelessWidget {
  const ToolboxPage({
    super.key,
    required this.state,
    this.mode = ToolboxMode.fleetExport,
    this.developmentRepository,
  });

  final GameState state;
  final ToolboxMode mode;
  final DevelopmentRepository? developmentRepository;

  @override
  Widget build(BuildContext context) {
    if (mode == ToolboxMode.fleetExport) {
      return FleetExportPage(state: state);
    }
    return EquipmentDevelopmentPage(
      state: state,
      repository: developmentRepository,
    );
  }
}
