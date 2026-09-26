import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/composition_record_snapshot.dart';

void main() {
  test('snapshot freezes selected fleets, ships, equipment and land bases', () {
    const state = GameState(
      memberId: 7,
      admiralLevel: 120,
      fleets: [
        Fleet(id: 1, name: '第一舰队', shipIds: [1]),
        Fleet(id: 2, name: '第二舰队', shipIds: [2]),
      ],
      ships: {
        1: OwnedShip(id: 1, masterId: 100, level: 99, slotIds: [501]),
        2: OwnedShip(id: 2, masterId: 200, level: 88, slotIds: [502]),
      },
      masterShips: {
        100: MasterShip(id: 100, name: '矢矧改二乙', shipTypeId: 3),
        200: MasterShip(id: 200, name: '大和改二', shipTypeId: 2),
      },
      slotItems: {
        501: OwnedSlotItem(instanceId: 501, masterSlotItemId: 900),
        502: OwnedSlotItem(instanceId: 502, masterSlotItemId: 901),
        503: OwnedSlotItem(instanceId: 503, masterSlotItemId: 902),
      },
      masterSlotItems: {
        900: MasterSlotItem(id: 900, name: '甲标的'),
        901: MasterSlotItem(id: 901, name: '46cm炮'),
        902: MasterSlotItem(id: 902, name: '陆攻'),
      },
      landBases: [
        LandBaseState(
          areaId: 6,
          baseId: 1,
          name: '第一基地航空队',
          squadrons: [LandBaseSquadronState(squadronId: 1, slotItemId: 503)],
        ),
        LandBaseState(areaId: 6, baseId: 2, name: '第二基地航空队'),
      ],
    );
    final snapshot = deserializeCompositionSnapshot(
      serializeCompositionSnapshot(
        state,
        fleetIds: {1},
        landBaseAreaId: 6,
        landBaseIds: {1},
      ),
    );
    expect(snapshot.admiralLevel, 120);
    expect(snapshot.fleets.map((fleet) => fleet.id), [1]);
    expect(snapshot.ships.keys, [1]);
    expect(snapshot.masterShips[100]?.name, '矢矧改二乙');
    expect(snapshot.slotItems.keys.toSet(), {501, 503});
    expect(snapshot.masterSlotItems.keys.toSet(), {900, 902});
    expect(snapshot.landBases.map((base) => base.baseId), [1]);
  });
}
