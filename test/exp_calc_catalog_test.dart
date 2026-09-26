import 'package:flutter_test/flutter_test.dart';
import 'dart:io';
import 'package:yahagi_kancolle_browser/src/toolbox/exp_calc/exp_calc_models.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/exp_calc/exp_calc_catalog.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/sortie_map_models.dart';

SortieMapNode node(List<int?> values) => SortieMapNode(
  point: 'C',
  kind: 'battle',
  typeLabel: '',
  battleTypeLabel: '',
  nameJa: null,
  reward: null,
  formations: [
    for (var i = 0; i < values.length; i++)
      EnemyFormation(
        variant: i + 1,
        isFinal: i == values.length - 1,
        formation: null,
        experience: values[i],
        airPower: null,
        fleetGroups: const [],
        note: null,
      ),
  ],
);

void main() {
  test('uses the shared full catalog, including 5-2 C and non-legacy maps', () {
    final catalog = SortieMapCatalogData.fromJsonString(
      File('assets/data/sortie_map_catalog.json').readAsStringSync(),
    );
    final maps = experienceMaps(catalog);
    expect(maps.length, greaterThan(30));
    expect(
      maps
          .firstWhere((m) => m.id == '5-2')
          .nodes
          .firstWhere((n) => n.id == 'C')
          .baseExp,
      150,
    );
    expect(maps.any((m) => m.id == '4-4'), isTrue);
    final map71 = maps.firstWhere((m) => m.id == '7-1');
    expect(
      map71.nodes.any((n) => n.id == 'A' || n.id == 'E' || n.id == 'J'),
      isFalse,
    );
    expect(map71.nodes.firstWhere((n) => n.id == 'D').baseExp, 180);
  });
  test('averages round to the nearest ten before bonuses', () {
    final value = NodeExperience.fromNode(
      node([100, 100, 201]),
    ).roundedAverage!;
    expect(
      computeMapExp(
        baseExp: value,
        rank: BattleRank.s,
        isFlagship: true,
        isMvp: true,
      ),
      468,
    );
    expect(
      computeMapExp(
        baseExp: 0,
        rank: BattleRank.s,
        isFlagship: true,
        isMvp: true,
      ),
      0,
    );
    expect(formatExperience(value), '130');
    expect(NodeExperience.fromNode(node([174])).roundedAverage, 170);
    expect(NodeExperience.fromNode(node([175])).roundedAverage, 180);
    expect(NodeExperience.fromNode(node([null])).roundedAverage, isNull);
  });
  test(
    'averages every formation including duplicate values and final phase',
    () {
      expect(NodeExperience.fromNode(node([140, 150, 160])).average, 150);
      expect(
        NodeExperience.fromNode(node([100, 100, 201])).average,
        closeTo(401 / 3, 1e-10),
      );
    },
  );
  test('missing values are excluded and coverage is retained', () {
    final result = NodeExperience.fromNode(node([100, null, 200]));
    expect(result.average, 150);
    expect(result.knownCount, 2);
    expect(result.totalCount, 3);
    expect(NodeExperience.fromNode(node([null])).average, isNull);
    expect(NodeExperience.fromNode(node([])).average, isNull);
    expect(NodeExperience.fromNode(node([0, 100])).average, 50);
  });
}
