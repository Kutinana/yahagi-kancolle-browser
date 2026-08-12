class SenkaCatalogItem {
  const SenkaCatalogItem({
    required this.id,
    required this.label,
    required this.shortName,
    required this.senka,
    this.code,
  });

  final int id;
  final String label;
  final String shortName;
  final int senka;
  final String? code;

  String get matrixLabel => code == null ? shortName : '$code $shortName';
}

const double experienceToSenkaRate = 7 / 10000;

const List<SenkaCatalogItem> senkaEoCatalog = [
  SenkaCatalogItem(id: 15, label: '镇守府近海（1-5）', shortName: '1-5', senka: 75),
  SenkaCatalogItem(id: 16, label: '镇守府近海航路（1-6）', shortName: '1-6', senka: 75),
  SenkaCatalogItem(id: 25, label: '冲之岛近海（2-5）', shortName: '2-5', senka: 100),
  SenkaCatalogItem(id: 35, label: '北方阿留申海域（3-5）', shortName: '3-5', senka: 150),
  SenkaCatalogItem(
    id: 45,
    label: '咖喱洋里兰卡岛海域（4-5）',
    shortName: '4-5',
    senka: 180,
  ),
  SenkaCatalogItem(id: 55, label: '沙门海域北方（5-5）', shortName: '5-5', senka: 200),
  SenkaCatalogItem(id: 56, label: '拉包尔方面海域（5-6）', shortName: '5-6', senka: 225),
  SenkaCatalogItem(
    id: 65,
    label: 'KW 环礁沿海海域（6-5）',
    shortName: '6-5',
    senka: 250,
  ),
  SenkaCatalogItem(id: 75, label: '爪哇岛海域（7-5）', shortName: '7-5', senka: 170),
];

const List<SenkaCatalogItem> senkaQuestCatalog = [
  SenkaCatalogItem(
    id: 854,
    code: 'Bq2',
    label: '战果扩张任务！“Z作战”前段作战',
    shortName: 'Z作战前',
    senka: 350,
  ),
  SenkaCatalogItem(
    id: 888,
    code: 'Bq7',
    label: '新编成“三川舰队”、突入铁底海峡！',
    shortName: '三川舰队',
    senka: 200,
  ),
  SenkaCatalogItem(
    id: 893,
    code: 'Bq8',
    label: '彻底确保泊地周边海域的安全！',
    shortName: '泊地周边',
    senka: 300,
  ),
  SenkaCatalogItem(
    id: 872,
    code: 'Bq10',
    label: '战果扩张任务！“Z作战”后段作战',
    shortName: 'Z作战后',
    senka: 400,
  ),
  SenkaCatalogItem(
    id: 284,
    code: 'Bq11',
    label: '西南诸岛方面“海上警备行动”发布！',
    shortName: '海上警备',
    senka: 80,
  ),
  SenkaCatalogItem(
    id: 845,
    code: 'Bq12',
    label: '发布！“西方海域作战”',
    shortName: '西方海域',
    senka: 330,
  ),
  SenkaCatalogItem(
    id: 903,
    code: 'Bq13',
    label: '扩张“六水战”、前往最前线！',
    shortName: '六水战',
    senka: 390,
  ),
];

SenkaCatalogItem? senkaEoById(int id) => _catalogById(senkaEoCatalog, id);

SenkaCatalogItem? senkaQuestById(int id) => _catalogById(senkaQuestCatalog, id);

SenkaCatalogItem? _catalogById(List<SenkaCatalogItem> catalog, int id) {
  for (final item in catalog) {
    if (item.id == id) return item;
  }
  return null;
}
