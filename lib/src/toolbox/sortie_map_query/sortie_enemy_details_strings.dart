import 'package:flutter/widgets.dart';

// Japanese game equipment categories map to stable icon identifiers.
const enemyEquipmentTypeIconIds = <String, int>{
  '小口径主砲': 1,
  '中口径主砲': 2,
  '大口径主砲': 3,
  '副砲': 4,
  '魚雷': 5,
  '艦上戦闘機': 6,
  '艦上爆撃機': 7,
  '艦上攻撃機': 8,
  '水上偵察機': 10,
  '水上爆撃機': 11,
  '小型電探': 12,
  '大型電探': 13,
  'ソナー': 14,
  '爆雷投射機': 15,
  '特殊潜航艇': 17,
  '対空機銃': 18,
  '回転翼機': 20,
  '探照灯': 23,
  '航空要員': 29,
  '潜水艦装備': 43,
  '陸上攻撃機': 47,
  '対艦強化弾': 53,
  '艦載発煙装置': 56,
};

final class EnemyDetailsStrings {
  const EnemyDetailsStrings._(this._ja, this._traditional);

  factory EnemyDetailsStrings.of(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context) ?? const Locale('zh');
    return EnemyDetailsStrings._(
      locale.languageCode == 'ja',
      locale.languageCode == 'zh' &&
          (locale.scriptCode == 'Hant' ||
              const ['TW', 'HK', 'MO'].contains(locale.countryCode)),
    );
  }

  final bool _ja;
  final bool _traditional;

  String _pick(String simplified, String traditional, String japanese) =>
      _ja ? japanese : (_traditional ? traditional : simplified);

  String get preciseConfigurationMissing =>
      _pick('未找到该敌舰的精确配置资料', '未找到該敵艦的精確配置資料', 'この敵艦の正確な編成データはありません');
  String get enemyShip => _pick('敌舰', '敵艦', '敵艦');
  String get preciseConfiguration => _pick('精确配置', '精確配置', '正確な編成');
  String get hp => 'HP';
  String get speed => _pick('速力', '速力', '速力');
  String get range => _pick('射程', '射程', '射程');
  String get aircraftCapacity => _pick('搭载', '搭載', '搭載');
  String get equipment => _pick('装备', '裝備', '装備');
  String get equipmentMissing => _pick('暂无装备资料', '暫無裝備資料', '装備データがありません');
  String get unknownType => _pick('种别不明', '種類不明', '種別不明');
  String get firepower => _pick('火力', '火力', '火力');
  String get torpedo => _pick('雷装', '雷裝', '雷装');
  String get bombing => _pick('爆装', '爆裝', '爆装');
  String get antiAir => _pick('对空', '對空', '対空');
  String get armor => _pick('装甲', '裝甲', '装甲');
  String get evasion => _pick('回避', '回避', '回避');
  String get antiSub => _pick('对潜', '對潜', '対潜');
  String get search => _pick('索敌', '索敵', '索敵');
  String get luck => _pick('运', '運', '運');
}
