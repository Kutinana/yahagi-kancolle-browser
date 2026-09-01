import 'package:flutter/material.dart';

import '../development/development_repository.dart';
import '../development/development_workbench_state_store.dart';
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
    this.developmentStateStore,
  });

  final GameState state;
  final ToolboxMode mode;
  final DevelopmentRepository? developmentRepository;
  final DevelopmentWorkbenchStateStore? developmentStateStore;

  @override
  Widget build(BuildContext context) {
    if (mode == ToolboxMode.fleetExport) {
      return FleetExportPage(state: state);
    }
    return EquipmentDevelopmentPage(
      state: state,
      repository: developmentRepository,
      stateStore: developmentStateStore,
    );
  }
}
