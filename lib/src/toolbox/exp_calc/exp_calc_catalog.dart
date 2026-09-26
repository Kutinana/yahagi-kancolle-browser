import '../sortie_map_query/sortie_map_models.dart';
import 'exp_calc_models.dart';

/// Every recorded formation has equal weight; unknown EXP is not zero EXP.
class NodeExperience {
  const NodeExperience(this.average, this.knownCount, this.totalCount);

  factory NodeExperience.fromNode(SortieMapNode node) {
    final values = node.formations
        .map((formation) => formation.experience)
        .whereType<int>()
        .where((value) => value >= 0)
        .toList();
    return NodeExperience(
      values.isEmpty ? null : values.reduce((a, b) => a + b) / values.length,
      values.length,
      node.formations.length,
    );
  }

  final double? average;
  int? get roundedAverage =>
      average == null ? null : (average! / 10).round() * 10;
  final int knownCount;
  final int totalCount;
}

List<SortieMapPreset> experienceMaps(SortieMapCatalogData catalog) => [
  for (final map in catalog.maps)
    if (map.nodes.any(_isCombatNode))
      SortieMapPreset(
        id: map.id,
        name: '${map.id} ${map.nameJa}',
        nodes: [
          for (final node in map.nodes)
            if (_isCombatNode(node)) _point(node),
        ],
      ),
];

bool _isCombatNode(SortieMapNode node) =>
    const {'battle', 'boss', 'night', 'airstrike'}.contains(node.kind);

MapNodePreset _point(SortieMapNode node) {
  final experience = NodeExperience.fromNode(node);
  return MapNodePreset(
    id: node.point,
    name: node.point,
    baseExp: experience.roundedAverage,
    knownCount: experience.knownCount,
    totalCount: experience.totalCount,
  );
}

String formatExperience(num value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
