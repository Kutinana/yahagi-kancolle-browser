import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';

GameState demoState() {
  const names = ['日進甲', '如月改二', '文月改二', '島風改', '長波改二', '五十鈴改二'];
  const hp = [49, 20, 9, 8, 24, 44];
  const maxHp = [49, 27, 27, 36, 33, 44];
  const cond = [85, 49, 27, 15, 40, 65];
  const levels = [85, 94, 85, 94, 91, 85];
  return GameState.empty.copyWith(
    hasPortData: true,
    admiralLevel: 120,
    masterShipTypes: {
      16: const MasterShipType(id: 16, name: '水母'),
      2: const MasterShipType(id: 2, name: '驱逐'),
      3: const MasterShipType(id: 3, name: '轻巡'),
    },
    masterShips: {
      for (var i = 0; i < 6; i++)
        i + 1: MasterShip(
          id: i + 1,
          name: names[i],
          shipTypeId: i == 0
              ? 16
              : i == 5
              ? 3
              : 2,
          speed: 10,
          maxFuel: i == 0 ? 40 : 25,
          maxAmmo: i == 0 ? 45 : 30,
          slotCount: 3,
          slotCapacities: [8, 8, 4],
        ),
    },
    ships: {
      for (var i = 0; i < 6; i++)
        i + 1: OwnedShip(
          id: i + 1,
          masterId: i + 1,
          level: levels[i],
          currentHp: hp[i],
          maxHp: maxHp[i],
          condition: cond[i],
          currentFuel: i == 0 ? 40 : 12 + i,
          currentAmmo: i == 0 ? 45 : 14 + i,
          lineOfSight: 35,
          antiSub: 90,
          firepower: 42 + i * 4,
          torpedo: 63 + i * 3,
          antiAir: 56 + i * 2,
          slotIds: [i * 3 + 1, i * 3 + 2, i * 3 + 3],
          onSlot: [8, 8, 4],
        ),
    },
    masterSlotItems: {
      1: const MasterSlotItem(
        id: 1,
        name: '水上爆撃機',
        type: [0, 0, 11, 10],
        antiAir: 5,
        lineOfSight: 6,
      ),
      2: const MasterSlotItem(
        id: 2,
        name: '小口径主砲',
        type: [0, 0, 1, 1],
        firepower: 3,
      ),
      3: const MasterSlotItem(
        id: 3,
        name: '電探',
        type: [0, 0, 12, 11],
        lineOfSight: 4,
      ),
    },
    slotItems: {
      for (var i = 1; i <= 18; i++)
        i: OwnedSlotItem(instanceId: i, masterSlotItemId: (i - 1) % 3 + 1),
    },
    fleets: const [
      Fleet(id: 1, name: '第一舰队', shipIds: [1, 2, 3, 4, 5, 6]),
      Fleet(id: 2, name: '第二舰队', shipIds: [2, 5, 6]),
      Fleet(id: 3, name: '第三舰队', shipIds: [1, 6]),
      Fleet(id: 4, name: '第四舰队'),
    ],
  );
}

/// Seven distinct owned ships, keeping the six-ship sample unchanged.
GameState sevenShipDemoState() {
  final state = demoState();
  return state.copyWith(
    ships: {
      ...state.ships,
      7: const OwnedShip(
        id: 7,
        masterId: 1,
        level: 80,
        currentHp: 40,
        maxHp: 49,
        condition: 49,
        currentFuel: 40,
        currentAmmo: 45,
      ),
    },
    fleets: [
      const Fleet(id: 1, name: '游击舰队', shipIds: [1, 2, 3, 4, 5, 6, 7]),
      ...state.fleets.skip(1),
    ],
  );
}
