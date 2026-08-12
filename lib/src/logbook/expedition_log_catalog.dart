final class ExpeditionRewardSpec {
  const ExpeditionRewardSpec({required this.name, required this.assetPath});

  final String name;
  final String assetPath;
}

const expeditionRewardCatalog = <int, ExpeditionRewardSpec>{
  1: ExpeditionRewardSpec(
    name: '高速修复材',
    assetPath: 'assets/images/material/06.png',
  ),
  2: ExpeditionRewardSpec(
    name: '高速建造材',
    assetPath: 'assets/images/material/05.png',
  ),
  3: ExpeditionRewardSpec(
    name: '开发资材',
    assetPath: 'assets/images/material/07.png',
  ),
  4: ExpeditionRewardSpec(
    name: '改修资材',
    assetPath: 'assets/images/material/08.png',
  ),
  10: ExpeditionRewardSpec(
    name: '家具箱（小）',
    assetPath: 'assets/images/material/10.png',
  ),
  11: ExpeditionRewardSpec(
    name: '家具箱（中）',
    assetPath: 'assets/images/material/11.png',
  ),
  12: ExpeditionRewardSpec(
    name: '家具箱（大）',
    assetPath: 'assets/images/material/12.png',
  ),
  54: ExpeditionRewardSpec(
    name: '给粮舰「间宫」',
    assetPath: 'assets/images/material/useitem_54.png',
  ),
  57: ExpeditionRewardSpec(
    name: '勋章',
    assetPath: 'assets/images/material/useitem_57.png',
  ),
  59: ExpeditionRewardSpec(
    name: '给粮舰「伊良湖」',
    assetPath: 'assets/images/material/useitem_59.png',
  ),
  61: ExpeditionRewardSpec(
    name: '甲种勋章',
    assetPath: 'assets/images/material/useitem_61.png',
  ),
  68: ExpeditionRewardSpec(
    name: '秋刀鱼',
    assetPath: 'assets/images/material/useitem_68.png',
  ),
  70: ExpeditionRewardSpec(
    name: '熟练搭乘员',
    assetPath: 'assets/images/material/useitem_70.png',
  ),
  75: ExpeditionRewardSpec(
    name: '新型炮熕兵装资材',
    assetPath: 'assets/images/material/useitem_75.png',
  ),
  77: ExpeditionRewardSpec(
    name: '新型航空兵装资材',
    assetPath: 'assets/images/material/useitem_77.png',
  ),
  78: ExpeditionRewardSpec(
    name: '战斗详报',
    assetPath: 'assets/images/material/useitem_78.png',
  ),
  94: ExpeditionRewardSpec(
    name: '新型兵装资材',
    assetPath: 'assets/images/material/useitem_94.png',
  ),
  95: ExpeditionRewardSpec(
    name: '潜水舰补给物资',
    assetPath: 'assets/images/material/useitem_95.png',
  ),
  100: ExpeditionRewardSpec(
    name: '海外舰最新技术',
    assetPath: 'assets/images/material/useitem_100.png',
  ),
};

String expeditionRewardName(int id, [String? capturedName]) {
  final catalogName = expeditionRewardCatalog[id]?.name;
  if (catalogName != null) return catalogName;
  final name = capturedName?.trim() ?? '';
  return name.isNotEmpty ? name : '道具 $id';
}
