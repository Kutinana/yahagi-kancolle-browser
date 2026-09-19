import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/sortie_map_models.dart';

void main() {
  test('parses boss formations, final variants, and combined fleets', () {
    final catalog = SortieMapCatalogData.fromJsonString('''
{
  "version": 1,
  "source": "https://example.test",
  "maps": [
    {
      "id": "6-5",
      "nameJa": "KW環礁沖海域",
      "difficulty": 10,
      "coverAsset": "assets/covers/6-5.png",
      "mapAsset": "assets/maps/6-5.png",
      "mapAspectRatio": 2.0,
      "source": "https://example.test/6-5",
      "nodes": [
        {
          "point": "M",
          "kind": "boss",
          "typeLabel": "ボス",
          "battleTypeLabel": "通常戦闘",
          "nameJa": "敵連合艦隊",
          "reward": null,
          "formations": [
            {
              "variant": 2,
              "final": true,
              "formation": "第三警戒航行序列",
              "experience": 420,
              "airPower": 468,
              "airSuperiority": 702,
              "airSupremacy": 1404,
              "fleetGroups": [
                [{"id": 1505, "nameJa": "軽巡ホ級", "nameZh": "轻巡ホ级"}],
                [{"id": 1501, "nameJa": "駆逐イ級", "nameZh": "驱逐イ级"}]
              ],
              "note": "斩杀"
            }
          ]
        }
      ]
    }
  ]
}
''');

    expect(catalog.version, 1);
    expect(catalog.maps, hasLength(1));
    final map = catalog.maps.single;
    expect(map.id, '6-5');
    expect(map.nameJa, 'KW環礁沖海域');
    expect(map.difficulty, 10);
    expect(map.mapAspectRatio, 2.0);
    final node = map.nodes.single;
    expect(node.isBoss, isTrue);
    expect(node.typeLabel, 'ボス');
    expect(node.battleTypeLabel, '通常戦闘');
    expect(node.nameJa, '敵連合艦隊');
    final formation = node.formations.single;
    expect(formation.isFinal, isTrue);
    expect(formation.experience, 420);
    expect(formation.airPower, 468);
    expect(formation.airSuperiority, 702);
    expect(formation.airSupremacy, 1404);
    expect(formation.fleetGroups, hasLength(2));
    expect(formation.fleetGroups.first.single.displayName, '轻巡ホ级');
  });

  test('parses resource nodes without enemy formations', () {
    final catalog = SortieMapCatalogData.fromJsonString('''
{"version":1,"source":"source","maps":[{"id":"1-2","nameJa":"南西諸島冲","difficulty":1,"coverAsset":"cover","mapAsset":"map","source":null,"nodes":[{"point":"B","kind":"resource","typeLabel":"資源","battleTypeLabel":"資源","nameJa":null,"reward":"弹药+10,15,20,40","formations":[]}]}]}
''');

    final node = catalog.maps.single.nodes.single;
    expect(node.isBoss, isFalse);
    expect(node.reward, '弹药+10,15,20,40');
    expect(node.formations, isEmpty);
  });

  test('uses a safe route-map ratio for legacy or invalid catalog values', () {
    Map<String, dynamic> mapJson([Object? ratio = 'missing']) => {
      'id': '1-1',
      'nameJa': '鎮守府正面海域',
      'difficulty': 1,
      'coverAsset': 'cover',
      'mapAsset': 'map',
      if (ratio != 'missing') 'mapAspectRatio': ratio,
      'source': null,
      'nodes': <Object?>[],
    };

    expect(SortieMapInfo.fromJson(mapJson()).mapAspectRatio, 5 / 3);
    expect(SortieMapInfo.fromJson(mapJson(2)).mapAspectRatio, 2);
    expect(SortieMapInfo.fromJson(mapJson(0)).mapAspectRatio, 5 / 3);
    expect(SortieMapInfo.fromJson(mapJson(-2)).mapAspectRatio, 5 / 3);
    expect(SortieMapInfo.fromJson(mapJson(double.nan)).mapAspectRatio, 5 / 3);
  });
}
