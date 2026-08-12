import '../game_state/game_state.dart';

class HeaderResourceSpec {
  const HeaderResourceSpec({
    required this.id,
    required this.label,
    required this.assetPath,
    this.type,
    this.useItemId,
  });

  final String id;
  final String label;
  final String assetPath;
  final GameResourceType? type;
  final int? useItemId;

  int? value(GameState state) {
    final material = type;
    return material == null
        ? state.useItemCount(useItemId!)
        : state.resource(material);
  }
}

const headerResourceCatalog = <HeaderResourceSpec>[
  HeaderResourceSpec(
    id: 'material-1',
    label: '燃料',
    assetPath: 'assets/images/material/01.png',
    type: GameResourceType.fuel,
  ),
  HeaderResourceSpec(
    id: 'material-2',
    label: '弾薬',
    assetPath: 'assets/images/material/02.png',
    type: GameResourceType.ammunition,
  ),
  HeaderResourceSpec(
    id: 'material-3',
    label: '鋼材',
    assetPath: 'assets/images/material/03.png',
    type: GameResourceType.steel,
  ),
  HeaderResourceSpec(
    id: 'material-4',
    label: 'ボーキサイト',
    assetPath: 'assets/images/material/04.png',
    type: GameResourceType.bauxite,
  ),
  HeaderResourceSpec(
    id: 'material-5',
    label: '高速建造材',
    assetPath: 'assets/images/material/05.png',
    type: GameResourceType.instantBuild,
  ),
  HeaderResourceSpec(
    id: 'material-6',
    label: '高速修復材',
    assetPath: 'assets/images/material/06.png',
    type: GameResourceType.instantRepair,
  ),
  HeaderResourceSpec(
    id: 'material-7',
    label: '開発資材',
    assetPath: 'assets/images/material/07.png',
    type: GameResourceType.developmentMaterial,
  ),
  HeaderResourceSpec(
    id: 'material-8',
    label: '改修資材',
    assetPath: 'assets/images/material/08.png',
    type: GameResourceType.improvementMaterial,
  ),
  HeaderResourceSpec(
    id: 'useitem-10',
    useItemId: 10,
    label: '家具箱（小）',
    assetPath: 'assets/images/material/10.png',
  ),
  HeaderResourceSpec(
    id: 'useitem-11',
    useItemId: 11,
    label: '家具箱（中）',
    assetPath: 'assets/images/material/11.png',
  ),
  HeaderResourceSpec(
    id: 'useitem-12',
    useItemId: 12,
    label: '家具箱（大）',
    assetPath: 'assets/images/material/12.png',
  ),
  HeaderResourceSpec(
    id: 'useitem-54',
    useItemId: 54,
    label: '給糧艦「間宮」',
    assetPath: 'assets/images/material/useitem_54.png',
  ),
  HeaderResourceSpec(
    id: 'useitem-57',
    useItemId: 57,
    label: '勲章',
    assetPath: 'assets/images/material/useitem_57.png',
  ),
  HeaderResourceSpec(
    id: 'useitem-59',
    useItemId: 59,
    label: '給糧艦「伊良湖」',
    assetPath: 'assets/images/material/useitem_59.png',
  ),
  HeaderResourceSpec(
    id: 'useitem-61',
    useItemId: 61,
    label: '甲種勲章',
    assetPath: 'assets/images/material/useitem_61.png',
  ),
  HeaderResourceSpec(
    id: 'useitem-68',
    useItemId: 68,
    label: '秋刀魚',
    assetPath: 'assets/images/material/useitem_68.png',
  ),
  HeaderResourceSpec(
    id: 'useitem-70',
    useItemId: 70,
    label: '熟練搭乗員',
    assetPath: 'assets/images/material/useitem_70.png',
  ),
  HeaderResourceSpec(
    id: 'useitem-75',
    useItemId: 75,
    label: '新型砲熕兵装資材',
    assetPath: 'assets/images/material/useitem_75.png',
  ),
  HeaderResourceSpec(
    id: 'useitem-77',
    useItemId: 77,
    label: '新型航空兵装資材',
    assetPath: 'assets/images/material/useitem_77.png',
  ),
  HeaderResourceSpec(
    id: 'useitem-78',
    useItemId: 78,
    label: '戦闘詳報',
    assetPath: 'assets/images/material/useitem_78.png',
  ),
  HeaderResourceSpec(
    id: 'useitem-94',
    useItemId: 94,
    label: '新型兵装資材',
    assetPath: 'assets/images/material/useitem_94.png',
  ),
  HeaderResourceSpec(
    id: 'useitem-95',
    useItemId: 95,
    label: '潜水艦補給物資',
    assetPath: 'assets/images/material/useitem_95.png',
  ),
  HeaderResourceSpec(
    id: 'useitem-100',
    useItemId: 100,
    label: '海外艦最新技術',
    assetPath: 'assets/images/material/useitem_100.png',
  ),
];

final headerResourceById = <String, HeaderResourceSpec>{
  for (final item in headerResourceCatalog) item.id: item,
};
