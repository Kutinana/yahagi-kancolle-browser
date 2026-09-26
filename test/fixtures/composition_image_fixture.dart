import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';

/// Invented data for layout tests and screenshots; contains no account data.
GameState compositionImageFixture() {
  const names = <String>[
    '矢矧改二乙',
    '大和改二重',
    '武蔵改二',
    '赤城改二',
    '加賀改二',
    '最上改二特',
    '雪風改二',
    '時雨改三',
    '長門改二',
    '陸奥改二',
    '翔鶴改二甲',
    '瑞鶴改二甲',
    '鈴谷改二',
    '龍鳳改二戊',
    '夕張改二特',
    '由良改二',
    'Atlanta改',
    'Fletcher Mk.II',
    'Jervis改',
    '秋月改',
    '涼月改',
    'Commandant Teste改',
    '伊勢改二',
    '日向改二',
    'Ташкент改',
  ];
  return GameState(
    hasMasterData: true,
    hasPortData: true,
    hasEquipmentInventory: true,
    masterShipTypes: const {
      3: MasterShipType(id: 3, name: '軽巡洋艦'),
      11: MasterShipType(id: 11, name: '正規空母'),
    },
    masterShips: {
      for (var index = 0; index < names.length; index++)
        index + 100: MasterShip(
          id: index + 100,
          name: names[index],
          shipTypeId: index % 3 == 0 ? 3 : 11,
          slotCount: 4,
          slotCapacities: const [4, 0, 24, 12],
        ),
    },
    ships: {
      for (var index = 0; index < names.length; index++)
        index + 1: OwnedShip(
          id: index + 1,
          masterId: index + 100,
          level: 99 + index,
          luck: 18 + index,
          slotIds: const [501, -1, 503, 504],
          onSlot: const [0, 0, 11, 12],
          maxSlotCounts: index == 0 ? const [6] : const [],
          extraSlotId: index.isEven ? 505 : 0,
        ),
    },
    masterSlotItems: const {
      201: MasterSlotItem(
        id: 201,
        name: '零式水上偵察機11型乙(熟練)',
        type: [5, 7, 10, 10],
      ),
      203: MasterSlotItem(
        id: 203,
        name: '試製 夜間瑞雲(攻撃装備)／熟練搭乗員・特別訓練飛行隊',
        type: [5, 7, 11, 10],
      ),
      204: MasterSlotItem(id: 204, name: '20.3cm(3号)連装砲', type: [1, 1, 2, 2]),
      205: MasterSlotItem(id: 205, name: '熟練見張員', type: [3, 3, 39, 32]),
      206: MasterSlotItem(id: 206, name: '銀河(熟練)', type: [21, 38, 47, 37]),
    },
    slotItems: const {
      501: OwnedSlotItem(
        instanceId: 501,
        masterSlotItemId: 201,
        level: 6,
        proficiency: 7,
      ),
      503: OwnedSlotItem(
        instanceId: 503,
        masterSlotItemId: 203,
        level: 10,
        proficiency: 5,
      ),
      504: OwnedSlotItem(instanceId: 504, masterSlotItemId: 204, level: 10),
      505: OwnedSlotItem(instanceId: 505, masterSlotItemId: 205, level: 8),
      506: OwnedSlotItem(
        instanceId: 506,
        masterSlotItemId: 206,
        level: 4,
        proficiency: 7,
      ),
    },
    fleets: const [
      Fleet(
        id: 1,
        name: '第一遊撃部隊',
        shipIds: [1, 2, 3, 4, 5, 6, 7],
        slotCount: 7,
      ),
      Fleet(id: 2, name: '第二水雷戦隊', shipIds: [8, 9, 10, 11, 12, 13]),
      Fleet(id: 3, name: '海上護衛部隊', shipIds: [14, 15, 16, 17, 18, 19]),
      Fleet(id: 4, name: '北方輸送艦隊', shipIds: [20, 21, 22, 23, 24, 25]),
    ],
    masterMapAreas: const {47: '期間限定海域', 6: '中部海域'},
    landBases: [
      for (var index = 1; index <= 3; index++)
        LandBaseState(
          areaId: 47,
          baseId: index,
          name: ['第一航空隊', '第二航空隊', '本土防空隊'][index - 1],
          actionKind: index == 3 ? 2 : 1,
          distanceBase: 7,
          distanceBonus: 1,
          squadrons: const [
            LandBaseSquadronState(
              squadronId: 1,
              slotItemId: 506,
              currentCount: 0,
              maxCount: 18,
            ),
            LandBaseSquadronState(
              squadronId: 3,
              slotItemId: 506,
              currentCount: 12,
              maxCount: 18,
            ),
            LandBaseSquadronState(
              squadronId: 4,
              slotItemId: 501,
              currentCount: 4,
              maxCount: 4,
            ),
          ],
        ),
      const LandBaseState(areaId: 6, baseId: 1, name: '別海域の航空隊'),
    ],
  );
}
