import 'package:flutter/widgets.dart';

import 'battle_detail_models.dart';

/// Translates display text without changing stored replay labels or identities.
class BattleDetailStrings {
  const BattleDetailStrings.forLocale(this.locale);

  factory BattleDetailStrings.of(BuildContext context) =>
      BattleDetailStrings.forLocale(Localizations.localeOf(context));

  final Locale locale;
  bool get _ja => locale.languageCode == 'ja';
  bool get _traditional =>
      locale.scriptCode == 'Hant' ||
      const ['TW', 'HK', 'MO'].contains(locale.countryCode);

  String _text(String zh, String hant, String ja) => _ja
      ? ja
      : _traditional
      ? hant
      : zh;

  String get fleet => _text('舰队', '艦隊', '艦隊');
  String get process => _text('战斗过程', '戰鬥過程', '戦闘経過');
  String get back => _text('返回出击记录', '返回出擊記錄', '出撃記録に戻る');
  String get title => _text('战斗详情', '戰鬥詳情', '戦闘詳細');
  String get all => _text('全部', '全部', 'すべて');
  String get chronological => _text('按发生顺序', '按發生順序', '発生順');
  String get noAttacks =>
      _text('没有符合条件的攻击记录', '沒有符合條件的攻擊記錄', '条件に一致する攻撃記録はありません');
  String get attack => _text('攻击', '攻擊', '攻撃');
  String get miss => _text('未命中', '未命中', 'ミス');
  String get critical => _text('暴击', '暴擊', 'クリティカル');
  String get damageControl => _text('损管发动', '損管發動', 'ダメコン発動');
  String get hpUnknown => _text('耐久未知', '耐久未知', '耐久不明');
  String get equipmentUnavailable => _text('装备数据未提供', '裝備資料未提供', '装備データ未取得');
  String get noEquipment => _text('当前没有装备', '目前沒有裝備', '装備なし');
  String get proficiency => _text('熟练度', '熟練度', '熟練度');
  String get expansionSlot => _text('增设', '增設', '増設');
  String get escaped => _text('退避', '退避', '退避');
  String sideName(BattleDetailSide side) => switch (side) {
    BattleDetailSide.friend => _text('我方', '我方', '味方'),
    BattleDetailSide.enemy => _text('敌方', '敵方', '敵'),
    BattleDetailSide.npc => _text('友军', '友軍', '友軍'),
  };
  String sideAttack(BattleDetailSide side) => '${sideName(side)}$attack';
  String dealt(int damage) =>
      _text('造成 $damage', '造成 $damage', '与ダメージ $damage');
  String received(int damage) =>
      _text('承受 $damage', '承受 $damage', '被ダメージ $damage');
  String damage(int damage) =>
      _text('造成 $damage 伤害', '造成 $damage 傷害', '$damage ダメージ');
  String stageDamage(BattleDetailSide side, int dealt, int received) => _text(
    '${sideName(side)}造成 $dealt · ${sideName(side)}承受 $received',
    '${sideName(side)}造成 $dealt · ${sideName(side)}承受 $received',
    '${sideName(side)}の与ダメージ $dealt · ${sideName(side)}の被ダメージ $received',
  );
  String attackCount(int count) => _text('$count 条', '$count 條', '$count 件');
  String shipCount(int count) => _text('$count 艘', '$count 艘', '$count 隻');
  String targetHp(int before, int after, int damage, {required bool unknown}) =>
      unknown
      ? _text('目标HP 未知（-$damage）', '目標HP 未知（-$damage）', '対象HP 不明（-$damage）')
      : _text(
          '目标HP $before → $after（-$damage）',
          '目標HP $before → $after（-$damage）',
          '対象HP $before → $after（-$damage）',
        );
  String hpChange(int before, int after) => '耐久 $before → $after';
  String fleetTitle(BattleDetailSide side, BattleDetailFleetRole role) {
    final escort = role == BattleDetailFleetRole.escort;
    if (side == BattleDetailSide.friend) {
      return escort
          ? _text('第二舰队 · 随伴', '第二艦隊 · 隨伴', '第二艦隊 · 随伴')
          : _text('第一舰队 · 主力', '第一艦隊 · 主力', '第一艦隊 · 主力');
    }
    if (side == BattleDetailSide.npc) {
      return escort
          ? _text('友军随伴', '友軍隨伴', '友軍随伴')
          : _text('友军主力', '友軍主力', '友軍主力');
    }
    return escort ? _text('敌方随伴', '敵方隨伴', '敵随伴') : _text('敌方主力', '敵方主力', '敵主力');
  }

  String damageStatus(String code) => switch (code) {
    'sunk' => _text('击沉', '擊沉', '撃沈'),
    'heavy' => '大破',
    'moderate' => '中破',
    'minor' => '小破',
    _ => code,
  };

  /// Only app-owned labels and precisely defined generated wrappers are mapped.
  /// Unknown names pass through, including game-owned Japanese proper names.
  String localize(String raw) {
    final exact = _labels[raw];
    if (exact != null) return _text(raw, exact.$1, exact.$2);
    final numbered = RegExp(r'^(基地航空队|舰船|装备|节点|阵型|航向) (\d+)$').firstMatch(raw);
    if (numbered != null) {
      return '${localize(numbered.group(1)!)} ${numbered.group(2)}';
    }
    if (raw.startsWith('友军·')) {
      return '${sideName(BattleDetailSide.npc)}·${localize(raw.substring(3))}';
    }
    if (raw.startsWith('敌') && _labels.containsKey(raw.substring(1))) {
      return '${_text('敌', '敵', '敵')}${localize(raw.substring(1))}';
    }
    final combined = RegExp(r'^(.+)（(.+)）$').firstMatch(raw);
    if (combined != null && _labels.containsKey(combined.group(1))) {
      return '${localize(combined.group(1)!)}（${localize(combined.group(2)!)}）';
    }
    final node = RegExp(r'^([A-Za-z0-9]+)点$').firstMatch(raw);
    if (node != null) {
      return _text(raw, '${node.group(1)}點', '${node.group(1)}マス');
    }
    return raw;
  }

  static const _labels = <String, (String, String)>{
    '未知': ('未知', '不明'),
    '敌': ('敵', '敵'),
    '我方': ('我方', '味方'),
    '敌方': ('敵方', '敵'),
    '敌方舰队': ('敵方艦隊', '敵艦隊'),
    '友军': ('友軍', '友軍'),
    '我方主力': ('我方主力', '味方主力'),
    '我方随伴': ('我方隨伴', '味方随伴'),
    '敌方主力': ('敵方主力', '敵主力'),
    '敌方随伴': ('敵方隨伴', '敵随伴'),
    '敌方护卫': ('敵方護衛', '敵護衛'),
    '我方舰队': ('我方艦隊', '味方艦隊'),
    '敌联合舰队': ('敵聯合艦隊', '敵連合艦隊'),
    '联合舰队': ('聯合艦隊', '連合艦隊'),
    '出击舰队': ('出擊艦隊', '出撃艦隊'),
    '空母机动部队': ('空母機動部隊', '空母機動部隊'),
    '水上打击部队': ('水上打擊部隊', '水上打撃部隊'),
    '输送护卫部队': ('輸送護衛部隊', '輸送護衛部隊'),
    '预判': ('預判', '予測'),
    '已确认': ('已確認', '確認済み'),
    '航行中': ('航行中', '航行中'),
    '基地空袭': ('基地空襲', '基地空襲'),
    '演习': ('演習', '演習'),
    '节点': ('節點', 'マス'),
    '起点': ('起點', '開始マス'),
    '无战斗': ('無戰鬥', '戦闘なし'),
    '资源获得': ('資源獲得', '資源獲得'),
    '资源损失': ('資源損失', '資源喪失'),
    '普通战斗': ('普通戰鬥', '通常戦闘'),
    '潜艇战': ('潜艇戰', '潜水艦戦'),
    'Boss 战': ('Boss 戰', 'ボス戦'),
    '空袭战': ('空襲戰', '空襲戦'),
    '护送成功': ('護送成功', '護衛成功'),
    '运输点': ('運輸點', '揚陸マス'),
    '长距离空袭战': ('長距離空襲戰', '長距離空襲戦'),
    '路线选择': ('路線選擇', '進路選択'),
    '航空侦察': ('航空偵察', '航空偵察'),
    '泊地修理': ('泊地修理', '泊地修理'),
    '节点事件': ('節點事件', 'マスイベント'),
    '战斗': ('戰鬥', '戦闘'),
    '昼战': ('晝戰', '昼戦'),
    '确保': ('確保', '制空権確保'),
    '优势': ('優勢', '航空優勢'),
    '均衡': ('均衡', '航空均衡'),
    '劣势': ('劣勢', '航空劣勢'),
    '丧失': ('喪失', '制空権喪失'),
    '单纵阵': ('單縱陣', '単縦陣'),
    '复纵阵': ('複縱陣', '複縦陣'),
    '轮形阵': ('輪形陣', '輪形陣'),
    '梯形阵': ('梯形陣', '梯形陣'),
    '单横阵': ('單橫陣', '単横陣'),
    '警戒阵': ('警戒陣', '警戒陣'),
    '第一警戒': ('第一警戒', '第一警戒'),
    '第二警戒': ('第二警戒', '第二警戒'),
    '第三警戒': ('第三警戒', '第三警戒'),
    '第四警戒': ('第四警戒', '第四警戒'),
    '阵型': ('陣型', '陣形'),
    '同航战': ('同航戰', '同航戦'),
    '反航战': ('反航戰', '反航戦'),
    'T 字有利': ('T 字有利', 'T字有利'),
    'T 字不利': ('T 字不利', 'T字不利'),
    '航向': ('航向', '交戦形態'),
    '未知舰船': ('未知艦船', '不明な艦船'),
    '未知舰娘': ('未知艦娘', '不明な艦娘'),
    '未知攻击方': ('未知攻擊方', '攻撃側不明'),
    '未知目标': ('未知目標', '対象不明'),
    '未知海域': ('未知海域', '海域不明'),
    '节点未知': ('節點未知', 'マス不明'),
    '未知节点': ('未知節點', '不明なマス'),
    '敌舰队': ('敵艦隊', '敵艦隊'),
    '未知敌舰队': ('未知敵艦隊', '不明な敵艦隊'),
    '舰船': ('艦船', '艦船'),
    '装备': ('裝備', '装備'),
    '攻击': ('攻擊', '攻撃'),
    '战斗阶段': ('戰鬥階段', '戦闘段階'),
    '夜战支援': ('夜戰支援', '夜戦支援'),
    '夜战第一轮': ('夜戰第一輪', '夜戦第1巡'),
    '夜战第二轮': ('夜戰第二輪', '夜戦第2巡'),
    '友军舰队': ('友軍艦隊', '友軍艦隊'),
    '夜战': ('夜戰', '夜戦'),
    '基地喷气强袭': ('基地噴氣強襲', '基地噴式強襲'),
    '喷气强袭': ('噴氣強襲', '噴式強襲'),
    '基地航空队': ('基地航空隊', '基地航空隊'),
    '友军航空战': ('友軍航空戰', '友軍航空戦'),
    '航空战': ('航空戰', '航空戦'),
    '第二次航空战': ('第二次航空戰', '第2次航空戦'),
    '支援攻击': ('支援攻擊', '支援攻撃'),
    '开幕反潜': ('開幕反潛', '先制対潜'),
    '开幕雷击': ('開幕雷擊', '先制雷撃'),
    '雷击战': ('雷擊戰', '雷撃戦'),
    '第一炮击战': ('第一砲擊戰', '第1砲撃戦'),
    '第二炮击战': ('第二砲擊戰', '第2砲撃戦'),
    '第三炮击战': ('第三砲擊戰', '第3砲撃戦'),
    '应急修理要员': ('應急修理要員', '応急修理要員'),
    '应急修理女神': ('應急修理女神', '応急修理女神'),
    '长门特殊攻击': ('長門特殊攻擊', '長門特殊攻撃'),
    '陆奥特殊攻击': ('陸奧特殊攻擊', '陸奥特殊攻撃'),
    'Colorado 特殊攻击': ('Colorado 特殊攻擊', 'Colorado 特殊攻撃'),
    'Richelieu 特殊攻击': ('Richelieu 特殊攻擊', 'Richelieu 特殊攻撃'),
    'Queen Elizabeth 特殊攻击': ('Queen Elizabeth 特殊攻擊', 'Queen Elizabeth 特殊攻撃'),
    '潜水舰特殊攻击（2·3号舰）': ('潛水艦特殊攻擊（2·3號艦）', '潜水艦特殊攻撃（2・3番艦）'),
    '潜水舰特殊攻击（3·4号舰）': ('潛水艦特殊攻擊（3·4號艦）', '潜水艦特殊攻撃（3・4番艦）'),
    '潜水舰特殊攻击（2·4号舰）': ('潛水艦特殊攻擊（2·4號艦）', '潜水艦特殊攻撃（2・4番艦）'),
    '大和三舰特殊攻击': ('大和三艦特殊攻擊', '大和3隻特殊攻撃'),
    '大和两舰特殊攻击': ('大和兩艦特殊攻擊', '大和2隻特殊攻撃'),
    '四式陆战特殊攻击': ('四式陸戰特殊攻擊', '四式陸戦特殊攻撃'),
    '连击': ('連擊', '連撃'),
    '主炮·鱼雷 Cut-in': ('主砲·魚雷 Cut-in', '主砲・魚雷カットイン'),
    '鱼雷 Cut-in': ('魚雷 Cut-in', '魚雷カットイン'),
    '主炮·副炮 Cut-in': ('主砲·副砲 Cut-in', '主砲・副砲カットイン'),
    '主炮·主炮 Cut-in': ('主砲·主砲 Cut-in', '主砲・主砲カットイン'),
    '僚舰夜战突击': ('僚艦夜戰突擊', '僚艦夜戦突撃'),
    '夜间瑞云攻击': ('夜間瑞雲攻擊', '夜間瑞雲攻撃'),
    '夜战攻击': ('夜戰攻擊', '夜戦攻撃'),
    '激光攻击': ('雷射攻擊', 'レーザー攻撃'),
    '主炮连击': ('主砲連擊', '主砲連撃'),
    '主炮·电探 Cut-in': ('主砲·電探 Cut-in', '主砲・電探カットイン'),
    '主炮·彻甲弹 Cut-in': ('主砲·徹甲彈 Cut-in', '主砲・徹甲弾カットイン'),
    '战爆联合 Cut-in': ('戰爆聯合 Cut-in', '戦爆連合カットイン'),
    '炮击': ('砲擊', '砲撃'),
  };
}
