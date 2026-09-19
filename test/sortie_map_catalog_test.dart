import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/sortie_map_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled catalog contains every regular map and image asset', () async {
    final catalog = await SortieMapCatalog.loadAsset();

    expect(catalog.maps, hasLength(37));
    expect(catalog.maps.first.id, '1-1');
    expect(catalog.maps.last.id, '7-5');
    expect(catalog.maps[1].nameJa, '南西諸島沖');
    expect(catalog.maps[2].nameJa, '製油所地帯沿岸');
    final nodes = catalog.maps.expand((map) => map.nodes).toList();
    expect(nodes, hasLength(490));
    expect(nodes.where((node) => node.typeLabel.trim().isEmpty), isEmpty);
    expect(nodes.where((node) => node.battleTypeLabel.trim().isEmpty), isEmpty);
    final formations = nodes.expand((node) => node.formations).toList();
    expect(formations, hasLength(1446));
    expect(formations.where((formation) => formation.isFinal), hasLength(62));
    expect(
      formations.where((formation) => formation.experience == null),
      hasLength(262),
    );
    expect(
      formations.where((formation) => formation.fleetGroups.length > 1),
      hasLength(4),
    );
    final airFormations = formations
        .where((formation) => formation.airPower != null)
        .toList();
    expect(airFormations, hasLength(523));
    for (final formation in airFormations) {
      expect(formation.airSuperiority, isNotNull);
      expect(formation.airSupremacy, isNotNull);
    }
    final romanizedClass = RegExp(
      r'(?:I|RO|HA|NI|HO|HE|TO|CHI|RI|NU|RU|WO|WA|KA|YO|TA|RE|SO|TSU|NE)级',
    );
    final enemyNames = formations
        .expand((formation) => formation.fleetGroups)
        .expand((group) => group)
        .map((ship) => ship.displayName);
    expect(enemyNames, hasLength(6813));
    expect(enemyNames.where(romanizedClass.hasMatch), isEmpty);
    expect(enemyNames, contains('空母ヲ級'));
    expect(
      catalog.maps
          .singleWhere((map) => map.id == '7-3')
          .nodes
          .singleWhere((node) => node.point == 'H')
          .kind,
      'resource',
    );

    for (final map in catalog.maps) {
      expect(
        (await rootBundle.load(map.coverAsset)).lengthInBytes,
        greaterThan(0),
      );
      expect(
        (await rootBundle.load(map.mapAsset)).lengthInBytes,
        greaterThan(0),
      );
    }
  });
}
