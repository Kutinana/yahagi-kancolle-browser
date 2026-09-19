import 'package:flutter/widgets.dart';

import 'sortie_map_models.dart';

class SortieMapQueryStrings {
  const SortieMapQueryStrings(this.locale);

  factory SortieMapQueryStrings.of(BuildContext context) =>
      SortieMapQueryStrings(
        Localizations.maybeLocaleOf(context) ?? const Locale('zh'),
      );

  final Locale locale;

  String _text(String zh, String hant, String ja) => locale.languageCode == 'ja'
      ? ja
      : locale.scriptCode == 'Hant' ||
            const ['TW', 'HK', 'MO'].contains(locale.countryCode)
      ? hant
      : zh;

  String get title => _text('海域查询', '海域查詢', '海域検索');
  String get selectMap => _text('海域选择', '海域選擇', '海域選択');
  String get routeMap => _text('路线图', '路線圖', 'ルートマップ');
  String get nodeInformation => _text('节点信息', '節點資訊', 'マス情報');
  String get difficulty => _text('难度', '難度', '難易度');
  String get boss => 'BOSS';
  String get formation => _text('阵型', '陣形', '陣形');
  String get experience => _text('经验', '經驗', '経験値');
  String get experienceUnknown => _text('经验不明', '經驗不明', '経験値不明');
  String get airPower => _text('制空值', '制空值', '制空値');
  String get airSuperiority => _text('空优值', '空優值', '航空優勢');
  String get airSupremacy => _text('空确值', '空確值', '制空権確保');
  String get fleet => _text('敌方舰队', '敵方艦隊', '敵艦隊');
  String fleetNumber(int number) => switch (number) {
    1 => _text('敌方主力舰队', '敵方主力艦隊', '敵主力艦隊'),
    2 => _text('敌方伴随舰队', '敵方伴隨艦隊', '敵随伴艦隊'),
    _ => _text('敌方第 $number 舰队', '敵方第 $number 艦隊', '敵第 $number 艦隊'),
  };
  String configuration(int number) =>
      _text('配置 $number', '配置 $number', '編成 $number');
  String get finalConfiguration => _text('斩杀', '斬殺', '最終形態');
  String get clearAfter => _text('攻略后', '攻略後', 'クリア後');
  String get noEnemy => _text('此节点没有敌方配置', '此節點沒有敵方配置', '敵編成なし');
  String get noNodes => _text('暂无节点信息', '暫無節點資訊', 'マス情報なし');
  String get loading => _text('正在加载海域资料…', '正在載入海域資料…', '海域情報を読み込み中…');
  String get loadFailed => _text('海域资料加载失败', '海域資料載入失敗', '海域情報を読み込めませんでした');
  String get retry => _text('重新加载', '重新載入', '再読み込み');
  String get attribution => _text(
    '感谢 kcwiki.cn 提供海域数据 · 知识共享署名',
    '感謝 kcwiki.cn 提供海域資料 · 知識共享署名',
    '海域データ提供：kcwiki.cn · クリエイティブ・コモンズ表示',
  );

  String enemyShipName(EnemyShipEntry ship) =>
      locale.languageCode == 'ja' ? ship.nameJa : ship.displayName;

  String? sourceDetail(String? value) =>
      locale.languageCode == 'ja' ? null : value;

  String nodeKind(String kind) => switch (kind) {
    'boss' => boss,
    'resource' => _text('资源点', '資源點', '資源マス'),
    'air' => _text('航空战', '航空戰', '航空戦'),
    'airstrike' => _text('空袭', '空襲', '空襲戦'),
    'night' => _text('夜战', '夜戰', '夜戦'),
    'battle' => _text('战斗点', '戰鬥點', '戦闘マス'),
    'noenemy' => _text('无战斗', '無戰鬥', '戦闘なし'),
    'imaginary' => _text('战斗回避', '戰鬥回避', '戦闘回避'),
    'maelstorm1' => _text('漩涡', '漩渦', 'うずしお'),
    'maelstorm2' => _text('漩涡（强）', '漩渦（強）', 'うずしお（強）'),
    'activebranch' => _text('能动分歧', '能動分歧', '能動分岐'),
    '未知' => _text('未知', '未知', '不明'),
    _ => _text('特殊点', '特殊點', '特殊マス'),
  };
}
