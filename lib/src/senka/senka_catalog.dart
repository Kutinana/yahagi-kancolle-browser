enum SenkaRewardCategory { eo, quarterly, annual, oneTime }

class SenkaCatalogItem {
  const SenkaCatalogItem({
    required this.id,
    required this.label,
    required this.shortName,
    required this.senka,
    required this.category,
    this.code,
  });

  final int id;
  final String label;
  final String shortName;
  final int senka;
  final SenkaRewardCategory category;
  final String? code;

  String get matrixLabel => code == null ? shortName : '$code $shortName';
}

const double experienceToSenkaRate = 7 / 10000;

const List<SenkaCatalogItem> senkaEoCatalog = [
  SenkaCatalogItem(
    id: 15,
    label: '镇守府近海（1-5）',
    shortName: '1-5',
    senka: 75,
    category: SenkaRewardCategory.eo,
  ),
  SenkaCatalogItem(
    id: 16,
    label: '镇守府近海航路（1-6）',
    shortName: '1-6',
    senka: 75,
    category: SenkaRewardCategory.eo,
  ),
  SenkaCatalogItem(
    id: 25,
    label: '冲之岛近海（2-5）',
    shortName: '2-5',
    senka: 100,
    category: SenkaRewardCategory.eo,
  ),
  SenkaCatalogItem(
    id: 35,
    label: '北方阿留申海域（3-5）',
    shortName: '3-5',
    senka: 150,
    category: SenkaRewardCategory.eo,
  ),
  SenkaCatalogItem(
    id: 45,
    label: '咖喱洋里兰卡岛海域（4-5）',
    shortName: '4-5',
    senka: 180,
    category: SenkaRewardCategory.eo,
  ),
  SenkaCatalogItem(
    id: 55,
    label: '沙门海域北方（5-5）',
    shortName: '5-5',
    senka: 200,
    category: SenkaRewardCategory.eo,
  ),
  SenkaCatalogItem(
    id: 56,
    label: '拉包尔方面海域（5-6）',
    shortName: '5-6',
    senka: 225,
    category: SenkaRewardCategory.eo,
  ),
  SenkaCatalogItem(
    id: 65,
    label: 'KW 环礁沿海海域（6-5）',
    shortName: '6-5',
    senka: 250,
    category: SenkaRewardCategory.eo,
  ),
  SenkaCatalogItem(
    id: 75,
    label: '爪哇岛海域（7-5）',
    shortName: '7-5',
    senka: 170,
    category: SenkaRewardCategory.eo,
  ),
];

const List<SenkaCatalogItem> senkaQuarterlyQuestCatalog = [
  SenkaCatalogItem(
    id: 854,
    code: 'Bq2',
    label: '战果扩张任务！“Z作战”前段作战',
    shortName: 'Z作战前',
    senka: 350,
    category: SenkaRewardCategory.quarterly,
  ),
  SenkaCatalogItem(
    id: 888,
    code: 'Bq7',
    label: '新编成“三川舰队”、突入铁底海峡！',
    shortName: '三川舰队',
    senka: 200,
    category: SenkaRewardCategory.quarterly,
  ),
  SenkaCatalogItem(
    id: 893,
    code: 'Bq8',
    label: '彻底确保泊地周边海域的安全！',
    shortName: '泊地周边',
    senka: 300,
    category: SenkaRewardCategory.quarterly,
  ),
  SenkaCatalogItem(
    id: 872,
    code: 'Bq10',
    label: '战果扩张任务！“Z作战”后段作战',
    shortName: 'Z作战后',
    senka: 400,
    category: SenkaRewardCategory.quarterly,
  ),
  SenkaCatalogItem(
    id: 284,
    code: 'Bq11',
    label: '西南诸岛方面“海上警备行动”发布！',
    shortName: '海上警备',
    senka: 80,
    category: SenkaRewardCategory.quarterly,
  ),
  SenkaCatalogItem(
    id: 845,
    code: 'Bq12',
    label: '发布！“西方海域作战”',
    shortName: '西方海域',
    senka: 330,
    category: SenkaRewardCategory.quarterly,
  ),
  SenkaCatalogItem(
    id: 903,
    code: 'Bq13',
    label: '扩张“六水战”、前往最前线！',
    shortName: '六水战',
    senka: 390,
    category: SenkaRewardCategory.quarterly,
  ),
];

const List<SenkaCatalogItem> senkaAnnualQuestCatalog = [
  SenkaCatalogItem(
    id: 947,
    label: 'AL作戦',
    shortName: 'AL作戦',
    senka: 480,
    category: SenkaRewardCategory.annual,
  ),
  SenkaCatalogItem(
    id: 948,
    label: '機動部隊決戦',
    shortName: '機動部隊決戦',
    senka: 600,
    category: SenkaRewardCategory.annual,
  ),
];

const List<SenkaCatalogItem> senkaOneTimeQuestCatalog = [
  SenkaCatalogItem(
    id: 949,
    label: '改装特務空母「Gambier Bay Mk.II」抜錨！',
    shortName: '火球炮',
    senka: 800,
    category: SenkaRewardCategory.oneTime,
  ),
];

const List<SenkaCatalogItem> senkaQuestCatalog = [
  ...senkaQuarterlyQuestCatalog,
  ...senkaAnnualQuestCatalog,
  ...senkaOneTimeQuestCatalog,
];

SenkaCatalogItem? senkaEoById(int id) => _catalogById(senkaEoCatalog, id);

SenkaCatalogItem? senkaQuestById(int id) => _catalogById(senkaQuestCatalog, id);

SenkaCatalogItem? _catalogById(List<SenkaCatalogItem> catalog, int id) {
  for (final item in catalog) {
    if (item.id == id) return item;
  }
  return null;
}

const _senkaServerNames = <String, String>{
  'w01': '横須賀鎮守府（横须贺）',
  'w02': '呉鎮守府（吴）',
  'w03': '佐世保鎮守府（佐世保）',
  'w04': '舞鶴鎮守府（舞鹤）',
  'w05': '大湊警備府（大凑）',
  'w06': 'トラック泊地（特鲁克）',
  'w07': 'リンガ泊地（林加）',
  'w08': 'ラバウル基地（拉包尔）',
  'w09': 'ショートランド泊地（肖特兰）',
  'w10': 'ブイン基地（布因）',
  'w11': 'タウイタウイ泊地（塔威塔威）',
  'w12': 'パラオ泊地（帕劳）',
  'w13': 'ブルネイ泊地（文莱）',
  'w14': '単冠湾泊地（单冠湾）',
  'w15': '幌筵泊地（幌筵）',
  'w16': '宿毛湾泊地（宿毛湾）',
  'w17': '鹿屋基地（鹿屋）',
  'w18': '岩川基地（岩川）',
  'w19': '佐伯湾泊地（佐伯湾）',
  'w20': '柱島泊地（柱岛）',
};

String senkaServerName(String origin) {
  final uri = Uri.tryParse(origin);
  if (uri == null ||
      !const {'http', 'https'}.contains(uri.scheme) ||
      uri.host.isEmpty) {
    return '未知服务器';
  }
  final match = RegExp(r'^w(\d{2})[a-z]?(?:\.|$)').firstMatch(uri.host);
  if (match == null) return '未知服务器';
  return _senkaServerNames['w${match.group(1)}'] ?? '未知服务器';
}
