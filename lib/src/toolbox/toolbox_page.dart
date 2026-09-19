import 'package:flutter/material.dart';

import '../game_state/game_state.dart';
import 'composition_image_page.dart';
import 'exp_calc/exp_calc_page.dart';
import 'fleet_export_page.dart';
import 'sortie_map_query/sortie_map_query_page.dart';
import 'sortie_map_query/sortie_map_catalog_controller.dart';
import 'sortie_map_query/enemy_catalog_controller.dart';
import 'toolbox_mode.dart';

export 'toolbox_mode.dart' show ToolboxMode;

class ToolboxPage extends StatelessWidget {
  const ToolboxPage({
    super.key,
    required this.state,
    this.mode = ToolboxMode.export,
    this.sortieMapCatalogController,
    this.enemyCatalogController,
  });

  final GameState state;
  final ToolboxMode mode;
  final SortieMapCatalogController? sortieMapCatalogController;
  final EnemyCatalogController? enemyCatalogController;

  @override
  Widget build(BuildContext context) => IndexedStack(
    index: mode.index,
    children: [
      FleetExportPage(state: state),
      CompositionImagePage(
        state: state,
        visible: mode == ToolboxMode.composition,
      ),
      ExpCalcPage(state: state),
      SortieMapQueryPage(
        state: state,
        visible: mode == ToolboxMode.mapQuery,
        catalogController: sortieMapCatalogController,
        enemyCatalogController: enemyCatalogController,
      ),
    ],
  );
}
