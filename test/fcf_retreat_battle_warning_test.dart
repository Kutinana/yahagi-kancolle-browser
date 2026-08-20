import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_controller.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_models.dart';
import 'package:yahagi_kancolle_browser/src/battle/detailed_battle_panel.dart';
import 'package:yahagi_kancolle_browser/src/capture/battle_result_warning_overlay.dart';
import 'package:yahagi_kancolle_browser/src/fleet/ship_repair_status.dart';
import 'package:yahagi_kancolle_browser/src/game_state/combat_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_reducer.dart';

import 'fixtures/kcsapi_fixtures.dart';

void main() {
  group('FCF Retreat (舰队司令部退避) & Battle Warning', () {
    late GameStateReducer reducer;

    setUp(() {
      reducer = GameStateReducer();
    });

    test('parses api_escape in battleresult and commits upon goback_port', () {
      var state = GameState.empty.copyWith(
        fleets: const <Fleet>[
          Fleet(
            id: 1,
            name: '主力',
            shipIds: <int>[101, 102, 103, 104, 105, 106],
          ),
          Fleet(
            id: 2,
            name: '随伴',
            shipIds: <int>[201, 202, 203, 204, 205, 206],
          ),
        ],
        combinedFleetType: CombinedFleetType.carrierTaskForce,
        combatState: const CombatState(
          sortieFleetId: 1,
          mapArea: 60,
          mapInfo: 1,
          currentNode: 5,
        ),
      );

      // Battle result with api_escape (escape ship index 8 = escort ship 2 = shipId 202, tow index 9 = escort ship 3 = shipId 203)
      state = reducer.reduce(
        state,
        kcsapiEvent(
          '/kcsapi/api_req_combined_battle/battleresult',
          <String, Object?>{
            'api_win_rank': 'S',
            'api_escape_flag': 1,
            'api_escape': <String, Object?>{
              'api_escape_idx': <int>[8],
              'api_tow_idx': <int>[9],
            },
          },
        ),
      );

      expect(state.combatState.pendingEscapeShipIds, <int>[202, 203]);
      expect(state.combatState.escapedShipIds, isEmpty);

      // goback_port confirms retreat
      state = reducer.reduce(
        state,
        kcsapiEvent(
          '/kcsapi/api_req_combined_battle/goback_port',
          <String, Object?>{},
        ),
      );

      expect(state.combatState.escapedShipIds, <int>{202, 203});
      expect(state.combatState.pendingEscapeShipIds, isEmpty);

      // Moving to next node keeps escaped ships
      state = reducer.reduce(
        state,
        kcsapiEvent('/kcsapi/api_req_map/next', <String, Object?>{
          'api_no': 6,
          'api_maparea_id': 60,
          'api_mapinfo_no': 1,
        }),
      );

      expect(state.combatState.escapedShipIds, <int>{202, 203});
      expect(state.combatState.currentNode, 6);

      // Returning to port or new sortie resets escaped ships
      state = reducer.reduce(
        state,
        kcsapiEvent('/kcsapi/api_port/port', <String, Object?>{
          'api_basic': <String, Object?>{'api_member_id': '1'},
          'api_material': <Object?>[],
          'api_ship': <Object?>[],
          'api_deck_port': <Object?>[],
          'api_ndock': <Object?>[],
        }),
      );

      expect(state.combatState.escapedShipIds, isEmpty);
    });

    test(
      'correctly maps 1-based indices in partial combined fleet (3+3 ships)',
      () {
        var state = GameState.empty.copyWith(
          fleets: const <Fleet>[
            Fleet(
              id: 1,
              name: '主力',
              shipIds: <int>[101, 102, 103], // 3 ships: slots 1, 2, 3
            ),
            Fleet(
              id: 2,
              name: '随伴',
              shipIds: <int>[
                201,
                202,
                203,
              ], // 3 ships: slots 7, 8, 9 (indices 8 & 9)
            ),
          ],
          combinedFleetType: CombinedFleetType.surfaceTaskForce,
          combatState: const CombatState(
            sortieFleetId: 1,
            mapArea: 60,
            mapInfo: 1,
            currentNode: 5,
          ),
        );

        // Escort slot 2 (index 8 = ship 202) and slot 3 (index 9 = ship 203)
        state = reducer.reduce(
          state,
          kcsapiEvent(
            '/kcsapi/api_req_combined_battle/battleresult',
            <String, Object?>{
              'api_win_rank': 'A',
              'api_escape_flag': 1,
              'api_escape': <String, Object?>{
                'api_escape_idx': <int>[9], // 胧 (slot 9)
                'api_tow_idx': <int>[8], // 子日 (slot 8)
              },
            },
          ),
        );

        expect(state.combatState.pendingEscapeShipIds, <int>[203, 202]);

        state = reducer.reduce(
          state,
          kcsapiEvent(
            '/kcsapi/api_req_combined_battle/goback_port',
            <String, Object?>{},
          ),
        );

        expect(state.combatState.escapedShipIds, <int>{203, 202});
      },
    );

    test(
      'BattleController updates current LiveBattle on goback_port',
      () async {
        var state = GameState.empty.copyWith(
          fleets: const <Fleet>[
            Fleet(id: 1, name: '主力', shipIds: <int>[101, 102, 103]),
            Fleet(id: 2, name: '随伴', shipIds: <int>[201, 202, 203]),
          ],
          ships: const <int, OwnedShip>{
            101: OwnedShip(
              id: 101,
              masterId: 546,
              level: 99,
              currentHp: 99,
              maxHp: 99,
            ),
            102: OwnedShip(
              id: 102,
              masterId: 662,
              level: 99,
              currentHp: 60,
              maxHp: 60,
            ),
            103: OwnedShip(
              id: 103,
              masterId: 119,
              level: 99,
              currentHp: 43,
              maxHp: 43,
            ),
            201: OwnedShip(
              id: 201,
              masterId: 144,
              level: 97,
              currentHp: 49,
              maxHp: 49,
            ),
            202: OwnedShip(
              id: 202,
              masterId: 35,
              level: 1,
              currentHp: 16,
              maxHp: 16,
            ),
            203: OwnedShip(
              id: 203,
              masterId: 36,
              level: 1,
              currentHp: 15,
              maxHp: 15,
            ),
          },
          combinedFleetType: CombinedFleetType.surfaceTaskForce,
          combatState: const CombatState(
            sortieFleetId: 1,
            mapArea: 60,
            mapInfo: 1,
            currentNode: 5,
          ),
        );

        final controller = BattleController(gameState: () => state);

        // 0. Map and Battle phase
        final mapEvent = kcsapiEvent(
          '/kcsapi/api_req_map/next',
          <String, Object?>{
            'api_no': 5,
            'api_maparea_id': 60,
            'api_mapinfo_no': 1,
          },
          sequence: 1,
        );
        state = reducer.reduce(state, mapEvent);
        controller.accept(mapEvent);

        final battleEvent = kcsapiEvent(
          '/kcsapi/api_req_combined_battle/battle_water',
          <String, Object?>{
            'api_deck_id': 1,
            'api_f_nowhps': <int>[99, 60, 43],
            'api_f_maxhps': <int>[99, 60, 43],
            'api_f_nowhps_combined': <int>[43, 16, 1],
            'api_f_maxhps_combined': <int>[49, 16, 15],
            'api_ship_ke': <int>[1501, 1502, 1503],
            'api_e_nowhps': <int>[960, 64, 70],
            'api_e_maxhps': <int>[960, 64, 70],
          },
          sequence: 2,
        );
        state = reducer.reduce(state, battleEvent);
        controller.accept(battleEvent);
        await controller.idle;

        // 1. Battle result packet
        final resultEvent = kcsapiEvent(
          '/kcsapi/api_req_combined_battle/battleresult',
          <String, Object?>{
            'api_win_rank': 'A',
            'api_escape_flag': 1,
            'api_escape': <String, Object?>{
              'api_escape_idx': <int>[9],
              'api_tow_idx': <int>[8],
            },
          },
          sequence: 3,
        );
        state = reducer.reduce(state, resultEvent);
        controller.accept(resultEvent);
        await controller.idle;

        // 2. Before goback_port, state has pending but not escaped yet
        expect(state.combatState.pendingEscapeShipIds, <int>[203, 202]);

        // 3. User confirms retreat in game -> goback_port
        final gobackEvent = kcsapiEvent(
          '/kcsapi/api_req_combined_battle/goback_port',
          <String, Object?>{},
          sequence: 4,
        );
        state = reducer.reduce(state, gobackEvent);
        controller.accept(gobackEvent);
        await controller.idle;

        expect(state.combatState.escapedShipIds, <int>{203, 202});
        expect(controller.current, isNotNull);
        final currentEscort = controller.current!.friendEscort;
        expect(
          currentEscort.where((s) => s.ownedShipId == 203).first.isEscaped,
          isTrue,
        );
        expect(
          currentEscort.where((s) => s.ownedShipId == 202).first.isEscaped,
          isTrue,
        );
        expect(
          currentEscort.where((s) => s.ownedShipId == 201).first.isEscaped,
          isFalse,
        );
      },
    );

    test('shouldShowPostBattleWarning ignores escaped ships', () {
      const escapedShip = BattleShipSnapshot(
        masterId: 421,
        ownedShipId: 202,
        name: '秋月改',
        side: BattleSide.friend,
        fleetRole: BattleFleetRole.escort,
        position: 1,
        initialHp: 37,
        maxHp: 37,
        currentHp: 8, // Heavily damaged (8/37 <= 25%)
        isEscaped: true,
      );

      const healthyShip = BattleShipSnapshot(
        masterId: 546,
        ownedShipId: 101,
        name: '武藏改二',
        side: BattleSide.friend,
        fleetRole: BattleFleetRole.main,
        position: 0,
        initialHp: 106,
        maxHp: 106,
        currentHp: 94,
      );

      const nonEscapedHeavyShip = BattleShipSnapshot(
        masterId: 422,
        ownedShipId: 204,
        name: '雪风改二',
        side: BattleSide.friend,
        fleetRole: BattleFleetRole.escort,
        position: 3,
        initialHp: 35,
        maxHp: 35,
        currentHp: 7, // Heavily damaged
        isEscaped: false,
      );

      // 1. When only escaped ships are heavily damaged -> NO warning
      final safeBattle = LiveBattle(
        context: const BattleContext(node: 2, bossNode: 5),
        displayStage: BattleDisplayStage.result,
        friendMain: const <BattleShipSnapshot>[healthyShip],
        friendEscort: const <BattleShipSnapshot>[escapedShip],
      );

      expect(shouldShowPostBattleWarning(safeBattle), isFalse);

      // 2. When there is a non-escaped heavily damaged ship -> SHOW warning
      final dangerBattle = LiveBattle(
        context: const BattleContext(node: 2, bossNode: 5),
        displayStage: BattleDisplayStage.result,
        friendMain: const <BattleShipSnapshot>[healthyShip],
        friendEscort: const <BattleShipSnapshot>[
          escapedShip,
          nonEscapedHeavyShip,
        ],
      );

      expect(shouldShowPostBattleWarning(dangerBattle), isTrue);
    });

    testWidgets('DetailedBattlePanel renders 退避 badge for escaped ships', (
      tester,
    ) async {
      const escapedShip = BattleShipSnapshot(
        masterId: 421,
        ownedShipId: 202,
        name: '秋月改',
        side: BattleSide.friend,
        fleetRole: BattleFleetRole.main,
        position: 0,
        initialHp: 37,
        maxHp: 37,
        currentHp: 8,
        isEscaped: true,
      );

      final battle = LiveBattle(
        context: const BattleContext(mapAreaId: 60, mapInfoNo: 1, node: 3),
        displayStage: BattleDisplayStage.battle,
        friendMain: const <BattleShipSnapshot>[escapedShip],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DetailedBattlePanel(
              battle: battle,
              gameState: GameState.empty,
            ),
          ),
        ),
      );

      expect(find.text('秋月改'), findsOneWidget);
      expect(find.text('退避'), findsOneWidget);
      expect(find.text('8 / 37'), findsNothing);
    });

    test('ShipRepairStatus identifies retreated ship and provides label', () {
      final state = GameState.empty.copyWith(
        combatState: const CombatState(escapedShipIds: <int>{202}),
      );

      final status = shipRepairStatusFor(
        state: state,
        shipId: 202,
        anchorageRepairStartedAt: null,
        now: DateTime.now(),
      );

      expect(status, ShipRepairStatus.retreat);
      expect(status?.label, '退避');
    });

    test('map/next automatically commits pending escape ship IDs', () {
      final state = GameState.empty.copyWith(
        combatState: const CombatState(pendingEscapeShipIds: <int>[203, 202]),
      );

      final nextEvent = kcsapiEvent(
        '/kcsapi/api_req_map/next',
        <String, Object?>{
          'api_no': 6,
          'api_maparea_id': 60,
          'api_mapinfo_no': 1,
        },
      );

      final nextState = reducer.reduce(state, nextEvent);
      expect(nextState.combatState.escapedShipIds, <int>{203, 202});
      expect(nextState.combatState.pendingEscapeShipIds, isEmpty);
    });

    test(
      'BattleController auto-detects retreated ship when battle nowHp is negative',
      () async {
        final state = GameState.empty.copyWith(
          fleets: const <Fleet>[
            Fleet(id: 1, name: '主力', shipIds: <int>[101]),
            Fleet(id: 2, name: '随伴', shipIds: <int>[201, 202, 203]),
          ],
          ships: const <int, OwnedShip>{
            101: OwnedShip(
              id: 101,
              masterId: 546,
              level: 99,
              currentHp: 99,
              maxHp: 99,
            ),
            201: OwnedShip(
              id: 201,
              masterId: 421,
              level: 99,
              currentHp: 42,
              maxHp: 60,
            ),
            202: OwnedShip(
              id: 202,
              masterId: 422,
              level: 99,
              currentHp: 32,
              maxHp: 34,
            ),
            203: OwnedShip(
              id: 203,
              masterId: 423,
              level: 99,
              currentHp: 2,
              maxHp: 15,
            ),
          },
          masterShips: const <int, MasterShip>{
            546: MasterShip(id: 546, name: '伊势改二', shipTypeId: 2),
            421: MasterShip(id: 421, name: '矢矧改二乙', shipTypeId: 3),
            422: MasterShip(id: 422, name: '朝霜改二补', shipTypeId: 1),
            423: MasterShip(id: 423, name: '敷波', shipTypeId: 1),
          },
          combinedFleetType: CombinedFleetType.carrierTaskForce,
          combatState: const CombatState(
            sortieFleetId: 1,
            mapArea: 60,
            mapInfo: 1,
            currentNode: 6,
          ),
        );

        final controller = BattleController(gameState: () => state);

        // In Node F battle packet: 敷波 (index 2 in escort) has nowHp = -1 because she retreated
        final battleEvent = kcsapiEvent(
          '/kcsapi/api_req_combined_battle/ld_airbattle',
          <String, Object?>{
            'api_deck_id': 1,
            'api_f_nowhps': <int>[99],
            'api_f_maxhps': <int>[99],
            'api_f_nowhps_combined': <int>[42, 32, -1],
            'api_f_maxhps_combined': <int>[60, 34, -1],
            'api_ship_ke': <int>[1501],
            'api_e_nowhps': <int>[200],
            'api_e_maxhps': <int>[200],
          },
        );

        controller.accept(battleEvent);
        await controller.idle;

        expect(controller.current, isNotNull);
        final escort = controller.current!.friendEscort;
        expect(escort.length, 3);
        expect(escort[0].name, '矢矧改二乙');
        expect(escort[0].isEscaped, isFalse);
        expect(escort[1].name, '朝霜改二补');
        expect(escort[1].isEscaped, isFalse);
        expect(escort[2].name, '敷波');
        expect(escort[2].isEscaped, isTrue); // Auto-detected as escaped!
      },
    );

    test(
      'BattleController auto-detects retreated ship in a later battle phase',
      () async {
        final state = GameState.empty.copyWith(
          fleets: const <Fleet>[
            Fleet(id: 1, name: '主力', shipIds: <int>[101]),
            Fleet(id: 2, name: '随伴', shipIds: <int>[201, 202, 203]),
          ],
          ships: const <int, OwnedShip>{
            101: OwnedShip(
              id: 101,
              masterId: 546,
              level: 99,
              currentHp: 99,
              maxHp: 99,
            ),
            201: OwnedShip(
              id: 201,
              masterId: 421,
              level: 99,
              currentHp: 42,
              maxHp: 60,
            ),
            202: OwnedShip(
              id: 202,
              masterId: 422,
              level: 99,
              currentHp: 32,
              maxHp: 34,
            ),
            203: OwnedShip(
              id: 203,
              masterId: 423,
              level: 99,
              currentHp: 2,
              maxHp: 15,
            ),
          },
          masterShips: const <int, MasterShip>{
            546: MasterShip(id: 546, name: '伊势改二', shipTypeId: 2),
            421: MasterShip(id: 421, name: '矢矧改二乙', shipTypeId: 3),
            422: MasterShip(id: 422, name: '朝霜改二补', shipTypeId: 1),
            423: MasterShip(id: 423, name: '敷波', shipTypeId: 1),
          },
          combinedFleetType: CombinedFleetType.carrierTaskForce,
          combatState: const CombatState(
            sortieFleetId: 1,
            mapArea: 60,
            mapInfo: 1,
            currentNode: 6,
          ),
        );

        final controller = BattleController(gameState: () => state);

        // First phase: nobody has retreated yet.
        controller.accept(
          kcsapiEvent(
            '/kcsapi/api_req_combined_battle/airbattle',
            <String, Object?>{
              'api_deck_id': 1,
              'api_f_nowhps': <int>[99],
              'api_f_maxhps': <int>[99],
              'api_f_nowhps_combined': <int>[42, 32, 15],
              'api_f_maxhps_combined': <int>[60, 34, 15],
              'api_ship_ke': <int>[1501],
              'api_e_nowhps': <int>[200],
              'api_e_maxhps': <int>[200],
            },
            sequence: 1,
          ),
        );
        await controller.idle;

        // Later phase: 敷波 (index 2 in escort) has nowHp = -1 because she retreated.
        controller.accept(
          kcsapiEvent(
            '/kcsapi/api_req_combined_battle/ld_airbattle',
            <String, Object?>{
              'api_deck_id': 1,
              'api_f_nowhps': <int>[99],
              'api_f_maxhps': <int>[99],
              'api_f_nowhps_combined': <int>[42, 32, -1],
              'api_f_maxhps_combined': <int>[60, 34, -1],
              'api_ship_ke': <int>[1501],
              'api_e_nowhps': <int>[200],
              'api_e_maxhps': <int>[200],
            },
            sequence: 2,
          ),
        );
        await controller.idle;

        expect(controller.current, isNotNull);
        final escort = controller.current!.friendEscort;
        expect(escort.length, 3);
        expect(escort[0].isEscaped, isFalse);
        expect(escort[1].isEscaped, isFalse);
        expect(escort[2].name, '敷波');
        expect(escort[2].isEscaped, isTrue); // Auto-detected as escaped!
      },
    );

    test(
      'striking force sortie is not treated as a combined fleet even when fleets 1/2 are combined',
      () {
        var state = GameState.empty.copyWith(
          fleets: const <Fleet>[
            Fleet(
              id: 1,
              name: '主力',
              shipIds: <int>[101, 102, 103, 104, 105, 106],
            ),
            Fleet(
              id: 2,
              name: '随伴',
              shipIds: <int>[201, 202, 203, 204, 205, 206],
            ),
            Fleet(
              id: 3,
              name: '游击部队',
              shipIds: <int>[301, 302, 303, 304, 305, 306, 307],
            ),
          ],
          combinedFleetType: CombinedFleetType.carrierTaskForce,
          combatState: const CombatState(
            sortieFleetId: 3,
            mapArea: 60,
            mapInfo: 1,
            currentNode: 5,
          ),
        );

        state = reducer.reduce(
          state,
          kcsapiEvent('/kcsapi/api_req_sortie/battleresult', <String, Object?>{
            'api_win_rank': 'S',
            'api_escape_flag': 1,
            'api_escape': <String, Object?>{
              'api_escape_idx': <int>[1, 7],
              'api_tow_idx': <int>[],
            },
          }),
        );

        // idx 1 -> fleet 3 first ship, idx 7 -> fleet 3 seventh ship.
        expect(state.combatState.pendingEscapeShipIds, <int>[301, 307]);
      },
    );

    test(
      'battleresult falls back to the request deck id when sortie fleet id is unknown',
      () {
        var state = GameState.empty.copyWith(
          fleets: const <Fleet>[
            Fleet(
              id: 1,
              name: '主力',
              shipIds: <int>[101, 102, 103, 104, 105, 106],
            ),
            Fleet(
              id: 2,
              name: '随伴',
              shipIds: <int>[201, 202, 203, 204, 205, 206],
            ),
            Fleet(
              id: 3,
              name: '游击部队',
              shipIds: <int>[301, 302, 303, 304, 305, 306, 307],
            ),
          ],
          combinedFleetType: CombinedFleetType.carrierTaskForce,
          combatState: const CombatState(
            mapArea: 60,
            mapInfo: 1,
            currentNode: 5,
          ),
        );

        state = reducer.reduce(
          state,
          kcsapiEvent(
            '/kcsapi/api_req_sortie/battleresult',
            <String, Object?>{
              'api_win_rank': 'S',
              'api_escape_flag': 1,
              'api_escape': <String, Object?>{
                'api_escape_idx': <int>[1],
                'api_tow_idx': <int>[],
              },
            },
            requestParams: <String, Object?>{'api_deck_id': 3},
          ),
        );

        expect(state.combatState.pendingEscapeShipIds, <int>[301]);
      },
    );
  });
}
