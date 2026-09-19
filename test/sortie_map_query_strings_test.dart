import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/sortie_map_catalog.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/sortie_map_models.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/sortie_map_query_strings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('labels every node kind emitted by the bundled catalog', () {
    const strings = SortieMapQueryStrings(Locale('zh'));
    const expected = <String, String>{
      'battle': '战斗点',
      'boss': 'BOSS',
      'resource': '资源点',
      'airstrike': '空袭',
      'night': '夜战',
      'noenemy': '无战斗',
      'imaginary': '战斗回避',
      'maelstorm1': '漩涡',
      'maelstorm2': '漩涡（强）',
      'activebranch': '能动分歧',
      '未知': '未知',
    };

    for (final entry in expected.entries) {
      expect(strings.nodeKind(entry.key), entry.value, reason: entry.key);
    }
  });

  test('enemy names follow the interface locale', () {
    const ship = EnemyShipEntry(id: 1512, nameJa: '空母ヲ級', nameZh: '空母ヲ级');

    expect(
      const SortieMapQueryStrings(Locale('zh')).enemyShipName(ship),
      '空母ヲ级',
    );
    expect(
      const SortieMapQueryStrings(Locale('ja')).enemyShipName(ship),
      '空母ヲ級',
    );
    expect(
      const SortieMapQueryStrings(Locale('ja')).sourceDetail('中文备注'),
      isNull,
    );
  });

  test('fleet groups and KCWiki attribution are localized', () {
    const zh = SortieMapQueryStrings(Locale('zh'));
    const ja = SortieMapQueryStrings(Locale('ja'));

    expect(zh.fleetNumber(1), '敌方主力舰队');
    expect(zh.fleetNumber(2), '敌方伴随舰队');
    expect(ja.fleetNumber(1), '敵主力艦隊');
    expect(ja.fleetNumber(2), '敵随伴艦隊');
    expect(zh.attribution, contains('kcwiki.cn'));
    expect(zh.attribution, contains('知识共享署名'));
  });

  test('unknown experience stays inside the experience pill', () {
    expect(const SortieMapQueryStrings(Locale('zh')).experienceUnknown, '经验不明');
    expect(
      const SortieMapQueryStrings(Locale('zh', 'TW')).experienceUnknown,
      '經驗不明',
    );
    expect(
      const SortieMapQueryStrings(Locale('ja')).experienceUnknown,
      '経験値不明',
    );
  });

  test('air-state pills use explicit localized labels', () {
    const zh = SortieMapQueryStrings(Locale('zh'));
    const ja = SortieMapQueryStrings(Locale('ja'));

    expect(zh.airPower, '制空值');
    expect(zh.airSuperiority, '空优值');
    expect(zh.airSupremacy, '空确值');
    expect(ja.airPower, '制空値');
    expect(ja.airSuperiority, '航空優勢');
    expect(ja.airSupremacy, '制空権確保');
  });

  test('bundled catalog introduces no unlabeled node kinds', () async {
    const strings = SortieMapQueryStrings(Locale('zh'));
    final catalog = await SortieMapCatalog.loadAsset();
    final kinds = catalog.maps
        .expand((map) => map.nodes)
        .map((node) => node.kind)
        .toSet();

    expect(kinds.where((kind) => strings.nodeKind(kind) == '特殊点'), isEmpty);
  });
}
