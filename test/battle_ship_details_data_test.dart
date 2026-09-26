import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_controller.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_models.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_ship_details.dart';
import 'package:yahagi_kancolle_browser/src/battle/prediction/battle_prediction_engine.dart';
import 'package:yahagi_kancolle_browser/src/battle/prediction/battle_prediction_executor.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_reducer.dart';

import 'fixtures/kcsapi_fixtures.dart';

void main() {
  late GameState state;

  setUp(() {
    final reducer = GameStateReducer();
    state = reducer.reduce(GameState.empty, start2Event);
    state = reducer.reduce(state, portEvent);
    state = reducer.reduce(state, slotItemEvent);
  });

  test(
    'friendly captures owned total stats, fuel and equipment instance data',
    () {
      final details = BattleShipDetails.friendly(state.ships[9001]!, state);

      expect(details.level, 50);
      expect(details.fuelPercent, 100);
      expect(details.ammoPercent, 87);
      expect(_stats(details), [55, 42, 38, 46]);
      expect(details.equipment!.map((item) => item.masterId), [201, 202, 203]);
      expect(details.equipment!.map((item) => item.iconId), [1, 10, 18]);
      expect(details.equipment!.map((item) => item.improvement), [4, 0, 1]);
      expect(details.equipment!.map((item) => item.proficiency), [0, 6, 0]);
      expect(details.equipment!.map((item) => item.extra), [
        false,
        false,
        false,
      ]);
    },
  );

  test('friendly captures immediate remodel and remaining experience', () {
    final source = state.copyWith(
      masterShips: const {
        101: MasterShip(
          id: 101,
          name: '夕張',
          shipTypeId: 2,
          afterShipId: 102,
          afterLv: 75,
        ),
        102: MasterShip(
          id: 102,
          name: '夕張改二',
          shipTypeId: 2,
          afterShipId: 101,
          afterLv: 80,
        ),
      },
    );
    final details = BattleShipDetails.friendly(
      const OwnedShip(id: 9001, masterId: 101, level: 50, nextExperience: 2283),
      source,
    );
    expect(details.nextExperience, 2283);
    expect(details.remodelName, '夕張改二');
    expect(details.remodelLevel, 75);
    expect(details.remodelShipId, 102);
    final unknown = BattleShipDetails.friendly(
      const OwnedShip(id: 2, masterId: 999, level: 1),
      source,
    );
    expect(unknown.remodelShipId, isNull);
    expect(unknown.remodelName, isNull);
  });

  test(
    'friendly preserves extra equipment and missing inventory placeholders',
    () {
      final details = BattleShipDetails.friendly(
        const OwnedShip(
          id: 9001,
          masterId: 101,
          level: 50,
          slotIds: [7002, -1, 99999],
          extraSlotId: 7004,
        ),
        state,
      );

      expect(details.equipment!.map((item) => item.masterId), [202, null, 203]);
      expect(details.equipment!.map((item) => item.extra), [
        false,
        false,
        true,
      ]);
      expect(details.equipment!.last.improvement, 1);
      expect(details.equipment![1].name, isNull);
    },
  );

  test(
    'friendly unknown fuel capacity stays unknown and known empty slots stay empty',
    () {
      final details = BattleShipDetails.friendly(
        const OwnedShip(id: 1, masterId: 99999, level: 1),
        state,
      );

      expect(details.fuelPercent, isNull);
      expect(details.ammoPercent, isNull);
      expect(details.equipment, isEmpty);
    },
  );

  test('enemy adds every equipped copy to the packet base stats like Poi', () {
    // Poi _initEnemy computes finalParam = api_eParam + equipment stats.
    final details = BattleShipDetails.enemy(
      level: 17,
      parameters: [25, 26, 68, 80],
      slots: [201, 201, 202, -1],
      state: state,
    );

    expect(details.level, 17);
    expect(_stats(details), [31, 26, 73, 80]);
    expect(details.equipment!.map((item) => item.masterId), [201, 201, 202]);
    expect(details.fuelPercent, isNull);
    expect(details.ammoPercent, isNull);
  });

  test(
    'enemy missing equipment data is distinct from confirmed empty equipment',
    () {
      BattleShipDetails enemy(Object? slots) => BattleShipDetails.enemy(
        level: 1,
        parameters: [25, 0, 0, 80],
        slots: slots,
        state: state,
      );

      expect(enemy(null).equipment, isNull);
      expect(_stats(enemy(null)), [null, null, null, null]);
      expect(enemy([-1, -1]).equipment, isEmpty);
      expect(_stats(enemy([-1, -1])), [25, 0, 0, 80]);
      expect(_stats(enemy([])), [25, 0, 0, 80]);
      expect(enemy([99999]).equipment!.single.masterId, 99999);
      expect(enemy([99999]).equipment!.single.name, isNull);
      expect(_stats(enemy([99999])), [null, null, null, null]);
    },
  );

  test(
    'enemy keeps known zero stats and does not fill absent base stats with zero',
    () {
      final details = BattleShipDetails.enemy(
        level: null,
        parameters: [0, null, -1],
        slots: [201],
        state: state,
      );

      expect(details.level, isNull);
      expect(_stats(details), [3, null, null, null]);
    },
  );

  test('details detach and freeze constructor and API equipment lists', () {
    final equipment = [const BattleEquipmentDetails(masterId: 201)];
    final details = BattleShipDetails(equipment: equipment);
    equipment.clear();
    expect(details.equipment, hasLength(1));
    expect(() => details.equipment!.clear(), throwsUnsupportedError);

    final slots = [201];
    final enemy = BattleShipDetails.enemy(
      level: 1,
      parameters: [1, 2, 3, 4],
      slots: slots,
      state: state,
    );
    slots[0] = 202;
    expect(enemy.equipment!.single.masterId, 201);
    expect(() => enemy.equipment!.clear(), throwsUnsupportedError);
  });

  test(
    'malformed enemy slots stay unknown instead of reporting no equipment',
    () {
      final details = BattleShipDetails.enemy(
        level: '17',
        parameters: [25, 26, 68, 80],
        slots: [null, '201', <String, Object?>{}, 201, -1],
        state: state,
      );
      expect(details.level, isNull);
      expect(details.equipment!.map((item) => item.masterId), [
        null,
        null,
        null,
        201,
      ]);
      expect(_stats(details), [null, null, null, null]);
    },
  );

  for (final legacySentinel in [false, true]) {
    test(
      'combined fleets retain aligned details (legacy sentinel: $legacySentinel)',
      () async {
        state = state.copyWith(
          combinedFleetType: CombinedFleetType.carrierTaskForce,
          fleets: const [
            Fleet(id: 1, name: 'Main', shipIds: [9001]),
            Fleet(id: 2, name: 'Escort', shipIds: [9002]),
          ],
        );
        final controller = _controller(() => state);
        addTearDown(controller.dispose);
        List<int> fleet(List<int> values) => [
          if (legacySentinel) -1,
          ...values,
        ];
        controller.accept(mapStartEvent);
        controller.accept(
          kcsapiEvent('/kcsapi/api_req_combined_battle/each_battle', {
            'api_deck_id': 1,
            'api_f_nowhps': fleet([30]),
            'api_f_maxhps': fleet([30]),
            'api_f_nowhps_combined': fleet([15]),
            'api_f_maxhps_combined': fleet([15]),
            'api_ship_ke': fleet([501, 502]),
            'api_ship_lv': fleet([17, 28]),
            'api_e_nowhps': fleet([96, 76]),
            'api_e_maxhps': fleet([96, 76]),
            'api_eParam': [
              [25, 26, 68, 80],
              [1, 2, 3, 4],
            ],
            'api_eSlot': [
              [201],
              [],
            ],
            'api_ship_ke_combined': fleet([503, 504]),
            'api_ship_lv_combined': fleet([39, 40]),
            'api_e_nowhps_combined': fleet([57, 37]),
            'api_e_maxhps_combined': fleet([57, 37]),
            'api_eParam_combined': [
              [5, 6, 7, 8],
              [9, 10, 11, 12],
            ],
            'api_eSlot_combined': [
              [202],
              [-1],
            ],
          }, sequence: 21),
        );
        await controller.idle;

        expect(controller.lastError, isNull);
        final battle = controller.current!;
        expect(battle.friendMain.single.details!.level, 50);
        expect(battle.friendEscort.single.details!.level, 44);
        expect(battle.enemyMain.map((ship) => ship.details!.level), [17, 28]);
        expect(battle.enemyEscort.map((ship) => ship.details!.level), [39, 40]);
        expect(_stats(battle.enemyMain[0].details!), [28, 26, 70, 80]);
        expect(_stats(battle.enemyMain[1].details!), [1, 2, 3, 4]);
        expect(_stats(battle.enemyEscort[0].details!), [5, 6, 8, 8]);
        expect(_stats(battle.enemyEscort[1].details!), [9, 10, 11, 12]);
      },
    );
  }

  test(
    'navigation, prediction replay, night and result retain captured details',
    () async {
      final controller = _controller(() => state);
      addTearDown(controller.dispose);
      controller.accept(mapStartEvent);
      await controller.idle;
      expect(controller.current!.friendMain.first.details!.level, 50);
      final body = jsonDecode(dayBattleEvent.responseBody) as Map;
      final data = Map<String, Object?>.from(body['api_data'] as Map)
        ..['api_ship_lv'] = [17, 28]
        ..['api_eParam'] = [
          [25, 26, 68, 80],
          [1, 2, 3, 4],
        ]
        ..['api_eSlot'] = [
          [201],
          [],
        ];
      controller.accept(kcsapiEvent(dayBattleEvent.path, data, sequence: 21));
      await controller.idle;
      final capturedFriendly = controller.current!.friendMain.first.details!;
      final capturedEnemy = controller.current!.enemyMain.first.details!;

      // An inventory refresh and a later packet without details must not change
      // the equipment captured at this battle's opening.
      state = state.copyWith(slotItems: const {});
      controller.accept(nightBattleEvent);
      await controller.idle;
      expect(controller.lastError, isNull);
      expect(
        controller.current!.friendMain.first.details,
        same(capturedFriendly),
      );
      expect(controller.current!.enemyMain.first.details, same(capturedEnemy));
      expect(capturedFriendly.equipment!.first.improvement, 4);
      expect(_stats(capturedEnemy), [28, 26, 70, 80]);

      controller.accept(battleResultEvent);
      await controller.idle;
      expect(controller.current!.status, LiveBattleStatus.confirmed);
      expect(
        controller.records.single.battle.enemyMain.first.details,
        same(capturedEnemy),
      );
      expect(
        controller.records.single.battle.friendMain.first.details,
        same(capturedFriendly),
      );
    },
  );

  test(
    'later battle phase picks up a new authoritative proficiency rank',
    () async {
      final controller = _controller(() => state);
      addTearDown(controller.dispose);
      controller.accept(mapStartEvent);
      controller.accept(dayBattleEvent);
      await controller.idle;
      expect(
        controller.current!.friendMain.first.details!.equipment![1].proficiency,
        6,
      );

      state = state.copyWith(
        slotItems: {
          ...state.slotItems,
          7002: const OwnedSlotItem(
            instanceId: 7002,
            masterSlotItemId: 202,
            proficiency: 7,
          ),
        },
      );
      controller.accept(nightBattleEvent);
      await controller.idle;
      expect(controller.lastError, isNull);
      expect(
        controller.current!.friendMain.first.details!.equipment![1].proficiency,
        7,
      );
    },
  );

  test(
    'new encounter with missing details cannot reuse the previous enemy data',
    () async {
      final controller = _controller(() => state);
      addTearDown(controller.dispose);
      controller.accept(mapStartEvent);
      controller.accept(dayBattleEvent);
      await controller.idle;
      expect(controller.current!.enemyMain.first.details!.level, 1);

      controller.accept(
        kcsapiEvent('/kcsapi/api_req_map/next', {
          'api_maparea_id': 1,
          'api_mapinfo_no': 1,
          'api_no': 2,
          'api_event_id': 4,
          'api_event_kind': 1,
        }, sequence: 24),
      );
      controller.accept(
        kcsapiEvent(dayBattleEvent.path, {
          'api_ship_ke': [501],
          'api_e_nowhps': [20],
          'api_e_maxhps': [20],
        }, sequence: 25),
      );
      await controller.idle;
      final details = controller.current!.enemyMain.single.details!;
      expect(details.level, isNull);
      expect(details.equipment, isNull);
      expect(_stats(details), [null, null, null, null]);
    },
  );
}

List<int?> _stats(BattleShipDetails details) => [
  details.firepower,
  details.torpedo,
  details.antiAir,
  details.armor,
];

BattleController _controller(GameState Function() state) => BattleController(
  gameState: state,
  predictionExecutor: const _InlineExecutor(),
);

class _InlineExecutor implements BattlePredictionExecutor {
  const _InlineExecutor();

  @override
  Future<BattlePredictionAppendResult> append({
    required BattlePredictionEngine engine,
    required String path,
    required Map<String, Object?> data,
  }) async =>
      (engine: engine, prediction: engine.append(path: path, data: data));
}
