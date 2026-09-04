import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_controller.dart';
import 'package:yahagi_kancolle_browser/src/battle/prediction/battle_prediction_engine.dart';
import 'package:yahagi_kancolle_browser/src/battle/prediction/battle_prediction_executor.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_api_decoder.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_api_event_pipeline.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_reducer.dart';
import 'package:yahagi_kancolle_browser/src/logbook/logbook_database.dart';
import 'package:yahagi_kancolle_browser/src/logbook/logbook_event_recorder.dart';

import 'fixtures/kcsapi_fixtures.dart';

class HeldPredictionExecutor implements BattlePredictionExecutor {
  final entered = Completer<void>();
  final release = Completer<void>();

  @override
  Future<BattlePredictionAppendResult> append({
    required BattlePredictionEngine engine,
    required String path,
    required Map<String, Object?> data,
  }) async {
    entered.complete();
    await release.future;
    return (engine: engine, prediction: engine.append(path: path, data: data));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'standalone raid resets the node engine before the next battle',
    () async {
      final state = GameStateController();
      addTearDown(state.dispose);
      final battle = BattleController(
        gameState: () => state.state,
        waitForGameState: () => state.idle,
        onFriendlyHpUpdated: state.applyFriendlyBattleHp,
      );
      addTearDown(battle.dispose);
      final pipeline = GameApiEventPipeline(
        consumers: [state, battle],
        settleGameState: () async {
          await state.idle;
          await battle.idle;
          await state.idle;
        },
      );
      pipeline
        ..add(start2Event)
        ..add(portEvent)
        ..add(mapStartEvent);
      for (final damage in [10, 5]) {
        pipeline.add(
          kcsapiEvent('/kcsapi/api_req_sortie/battle', {
            'api_deck_id': 1,
            'api_f_nowhps': [28, 8],
            'api_f_maxhps': [30, 15],
            'api_e_nowhps': [20],
            'api_e_maxhps': [20],
            'api_ship_ke': [501],
            'api_hougeki1': {
              'api_at_eflag': [0],
              'api_at_list': [0],
              'api_df_list': [
                [0],
              ],
              'api_damage': [
                [damage],
              ],
            },
          }, sequence: 700 + damage),
        );
        await pipeline.idle;
        expect(battle.current!.enemyMain.single.currentHp, 20 - damage);
        if (damage == 10) {
          pipeline.add(
            kcsapiEvent('/kcsapi/api_req_map/air_raid', {
              'api_maparea_id': 1,
              'api_destruction_battle': {
                'api_f_maxhps': [200],
                'api_f_nowhps': [200],
                'api_air_base_attack': {
                  'api_stage1': {'api_disp_seiku': 1},
                },
              },
            }, sequence: 720),
          );
          await pipeline.idle;
          expect(battle.current!.enemyMain, isEmpty);
        }
      }
    },
  );

  for (final escapeIndex in [2, 8]) {
    test(
      'burst combined sortie/result/retreat/next keeps only selected pair ($escapeIndex)',
      () async {
        final state = GameStateController();
        addTearDown(state.dispose);
        final battle = BattleController(
          gameState: () => state.state,
          waitForGameState: () => state.idle,
          onFriendlyHpUpdated: state.applyFriendlyBattleHp,
        );
        addTearDown(battle.dispose);
        final pipeline = GameApiEventPipeline(
          consumers: [state, battle],
          settleGameState: () async {
            await state.idle;
            await battle.idle;
            await state.idle;
          },
        );
        final port = Map<String, Object?>.from(
          GameApiDecoder.decodeEventData(portEvent) as Map,
        );
        final ships = List<Object?>.from(port['api_ship'] as List);
        final template = Map<String, Object?>.from(ships.last as Map);
        port['api_ship'] = [
          ...ships,
          for (final id in [9101, 9102, 9103]) {...template, 'api_id': id},
        ];
        port['api_combined_flag'] = 1;
        port['api_deck_port'] = [
          {
            'api_id': 1,
            'api_name': '主队',
            'api_ship': [9001, 9002, -1, -1, -1, -1],
          },
          {
            'api_id': 2,
            'api_name': '护卫',
            'api_ship': [9101, 9102, 9103, -1, -1, -1],
          },
        ];
        pipeline
          ..add(start2Event)
          ..add(kcsapiEvent('/kcsapi/api_port/port', port, sequence: 500))
          ..add(mapStartEvent)
          ..add(
            kcsapiEvent('/kcsapi/api_req_combined_battle/battle_water', {
              'api_deck_id': 1,
              'api_f_nowhps': [28, 2],
              'api_f_maxhps': [30, 15],
              'api_f_nowhps_combined': [15, 2, 15],
              'api_f_maxhps_combined': [15, 15, 15],
              'api_e_nowhps': [20],
              'api_e_maxhps': [20],
              'api_ship_ke': [501],
            }, sequence: 501),
          )
          ..add(
            kcsapiEvent('/kcsapi/api_req_combined_battle/battleresult', {
              'api_win_rank': 'A',
              'api_escape_flag': 1,
              'api_escape': {
                'api_escape_idx': [escapeIndex],
                'api_tow_idx': [9, 7, 8],
              },
            }, sequence: 502),
          )
          ..add(
            kcsapiEvent(
              '/kcsapi/api_req_combined_battle/goback_port',
              null,
              includeApiData: false,
              sequence: 503,
            ),
          )
          ..add(
            kcsapiEvent('/kcsapi/api_req_map/next', {
              'api_no': 2,
              'api_maparea_id': 1,
              'api_mapinfo_no': 1,
            }, sequence: 504),
          );
        await pipeline.idle;
        final escaped = {escapeIndex == 2 ? 9002 : 9102, 9103};
        expect(state.state.combatState.escapedShipIds, escaped);
        expect(
          battle.current!.friendShips
              .where((ship) => ship.isEscaped)
              .map((ship) => ship.ownedShipId)
              .toSet(),
          escaped,
        );
        expect(state.state.ships[9002]!.currentHp, 2);
        expect(state.state.ships[9102]!.currentHp, 2);
        expect(battle.current!.friendEscort.first.isEscaped, isFalse);
        expect(battle.current!.context.node, 2);
        expect(battle.lastError, isNull);
        pipeline.add(kcsapiEvent('/kcsapi/api_port/port', port, sequence: 505));
        await pipeline.idle;
        expect(battle.current, isNull);
        expect(state.state.combatState.escapedShipIds, isEmpty);
      },
    );
  }

  test('live retreat display reads authoritative ship IDs', () async {
    final reducer = GameStateReducer();
    var state = reducer.reduce(GameState.empty, start2Event);
    state = reducer.reduce(state, portEvent);
    state = reducer.reduce(state, mapStartEvent);
    final battle = BattleController(gameState: () => state);
    addTearDown(battle.dispose);
    battle.accept(mapStartEvent);
    await battle.idle;
    state = state.copyWith(
      combatState: state.combatState.copyWith(escapedShipIds: {9002}),
    );
    expect(
      battle.current!.friendMain
          .where((ship) => ship.isEscaped)
          .map((ship) => ship.ownedShipId),
      [9002],
    );
    state = state.copyWith(
      combatState: state.combatState.copyWith(escapedShipIds: {}),
    );
    expect(battle.current!.friendMain.any((ship) => ship.isEscaped), isFalse);
  });

  for (final path in [
    '/kcsapi/api_req_sortie/goback_port',
    '/kcsapi/api_req_combined_battle/goback_port',
  ]) {
    test('$path accepts successful response without api_data', () async {
      final reducer = GameStateReducer();
      var state = reducer.reduce(GameState.empty, start2Event);
      state = reducer.reduce(state, portEvent);
      state = reducer.reduce(state, mapStartEvent);
      state = state.copyWith(
        combatState: state.combatState.copyWith(pendingEscapeShipIds: [9002]),
      );
      final battle = BattleController(gameState: () => state);
      addTearDown(battle.dispose);
      battle.accept(mapStartEvent);
      await battle.idle;
      final retreat = kcsapiEvent(
        path,
        null,
        includeApiData: false,
        sequence: 999,
      );
      state = reducer.reduce(state, retreat);
      battle.accept(retreat);
      await battle.idle;
      expect(state.combatState.escapedShipIds, {9002});
      expect(battle.current!.friendMain.last.isEscaped, isTrue);
      expect(battle.lastError, isNull);
    });
  }

  for (final invalidData in [null, <Object?>[]]) {
    test(
      'malformed successful port preserves the current session ($invalidData)',
      () async {
        final battle = BattleController(gameState: () => GameState.empty);
        addTearDown(battle.dispose);
        battle.accept(mapStartEvent);
        await battle.idle;
        final current = battle.current;
        final session = battle.session;
        battle.accept(
          kcsapiEvent('/kcsapi/api_port/port', invalidData, sequence: 998),
        );
        await battle.idle;
        expect(battle.current, same(current));
        expect(battle.session, same(session));
        expect(battle.lastError, isNotNull);
      },
    );
  }

  for (final settleCore in [false, true]) {
    test('port stays authoritative (core transaction: $settleCore)', () async {
      final state = GameStateController();
      addTearDown(state.dispose);
      await state.initialize();
      state
        ..accept(start2Event)
        ..accept(portEvent);
      await state.idle;
      final executor = HeldPredictionExecutor();
      final battle = BattleController(
        gameState: () => state.state,
        waitForGameState: () => state.idle,
        onFriendlyHpUpdated: state.applyFriendlyBattleHp,
        predictionExecutor: executor,
      );
      addTearDown(battle.dispose);
      final pipeline = GameApiEventPipeline(
        consumers: [state, battle],
        settleGameState: settleCore
            ? () async {
                await state.idle;
                await battle.idle;
                await state.idle;
              }
            : null,
      );
      pipeline.add(mapStartEvent);
      await pipeline.idle;
      pipeline.add(
        kcsapiEvent('/kcsapi/api_req_sortie/battle', {
          'api_deck_id': 1,
          'api_f_nowhps': [28, 8],
          'api_f_maxhps': [30, 15],
          'api_e_nowhps': [20],
          'api_e_maxhps': [20],
          'api_ship_ke': [501],
          'api_hougeki1': {
            'api_at_eflag': [1],
            'api_at_list': [0],
            'api_df_list': [
              [1],
            ],
            'api_damage': [
              [6],
            ],
          },
        }, sequence: 901),
      );
      await executor.entered.future;
      final port = Map<String, Object?>.from(
        GameApiDecoder.decodeEventData(portEvent) as Map,
      );
      port['api_ship'] = [
        for (final raw in port['api_ship'] as List)
          {...raw as Map, 'api_nowhp': raw['api_maxhp']},
      ];
      pipeline.add(
        kcsapiEvent(
          '/kcsapi/api_port/port',
          port,
          sequence: 902,
          capturedAt: DateTime.utc(2026, 7, 30, 9, 31),
        ),
      );
      if (settleCore) {
        await Future<void>.delayed(Duration.zero);
        expect(state.state.combatState.isActive, isTrue);
        expect(state.state.ships[9002]!.currentHp, 8);
      } else {
        await pipeline.dispatchIdle;
        await state.idle;
        expect(state.state.ships[9002]!.currentHp, 15);
      }
      executor.release.complete();
      await pipeline.idle;
      await state.idle;
      expect(battle.current, isNull);
      expect(state.state.combatState.isActive, isFalse);
      expect(state.state.ships[9002]!.currentHp, 15);
    });
  }

  test(
    'a hung logbook write does not block live state or later events',
    () async {
      final release = Completer<void>();
      final database = LogbookDatabase.lazyForTesting(() async {
        await release.future;
        throw StateError('simulated stalled disk');
      });
      final state = GameStateController(
        logbookRecorder: LogbookEventRecorder(database: database),
      );
      addTearDown(state.dispose);
      state
        ..accept(start2Event)
        ..accept(portEvent)
        ..accept(mapStartEvent);
      state.accept(
        kcsapiEvent('/kcsapi/api_req_map/next', {
          'api_maparea_id': 1,
          'api_mapinfo_no': 1,
          'api_no': 2,
          'api_itemget': [
            {'api_usemst': 4, 'api_id': 1, 'api_getcount': 20},
          ],
        }, sequence: 904),
      );
      await state.idle.timeout(const Duration(seconds: 2));
      expect(state.state.combatState.currentNode, 2);
      state.accept(
        kcsapiEvent('/kcsapi/api_req_map/next', {
          'api_maparea_id': 1,
          'api_mapinfo_no': 1,
          'api_no': 3,
        }, sequence: 905),
      );
      await state.idle;
      expect(state.state.combatState.currentNode, 3);
      release.complete();
      await state.logbookIdle;
      expect(state.lastLogbookError, isNotNull);
      expect(state.lastError, isNull);
    },
  );

  for (final path in [
    '/kcsapi/api_req_map/next',
    '/kcsapi/api_req_map/air_raid',
  ]) {
    test('$path applies all raid packets without losing fleet state', () async {
      final state = GameStateController();
      addTearDown(state.dispose);
      final battle = BattleController(
        gameState: () => state.state,
        waitForGameState: () => state.idle,
      );
      addTearDown(battle.dispose);
      final pipeline = GameApiEventPipeline(
        consumers: [state, battle],
        settleGameState: () async {
          await state.idle;
          await battle.idle;
          await state.idle;
        },
      );
      pipeline
        ..add(start2Event)
        ..add(portEvent)
        ..add(mapStartEvent);
      await pipeline.idle;
      final session = battle.session;
      pipeline.add(
        kcsapiEvent(path, {
          'api_maparea_id': 1,
          if (path.endsWith('/next')) 'api_no': 1,
          if (path.endsWith('/next')) 'api_mapinfo_no': 1,
          'api_destruction_battle': [
            {
              'api_f_maxhps': [200, 200],
              'api_f_nowhps': [200, 200],
              'api_air_base_attack': {
                'api_stage1': {'api_disp_seiku': 1},
                'api_stage3': {
                  'api_fdam': [10, 20],
                },
              },
            },
            {
              'api_f_maxhps': [200, 200],
              'api_f_nowhps': [190, 180],
              'api_air_base_attack': {
                'api_stage1': {'api_disp_seiku': 2},
                'api_stage3': {
                  'api_fdam': [30, 40],
                },
              },
            },
          ],
        }, sequence: 906),
      );
      await pipeline.idle;
      expect(state.state.landBases.map((base) => base.currentHp), [160, 140]);
      expect(
        battle.current!.landBaseRaid!.bases.map((base) => base.currentHp),
        [160, 140],
      );
      expect(state.state.combatState.isActive, isTrue);
      expect(state.state.combatState.currentNode, 1);
      if (path.endsWith('/air_raid')) {
        expect(battle.session, isNot(same(session)));
      }
    });
  }

  test('failed port does not end the battle session', () async {
    final state = GameStateController();
    addTearDown(state.dispose);
    await state.initialize();
    state
      ..accept(start2Event)
      ..accept(portEvent);
    await state.idle;
    final battle = BattleController(gameState: () => state.state);
    addTearDown(battle.dispose);
    battle.accept(mapStartEvent);
    await battle.idle;
    final session = battle.session;
    expect(battle.current, isNotNull);
    battle.accept(
      kcsapiEvent('/kcsapi/api_port/port', {}, apiResult: 0, sequence: 903),
    );
    await battle.idle;
    expect(battle.current, isNotNull);
    expect(battle.session, same(session));
  });

  test('failed logbook write cannot drop a map state update', () async {
    final database = LogbookDatabase.lazyForTesting(() async {
      throw StateError('simulated disk failure');
    });
    final state = GameStateController(
      logbookRecorder: LogbookEventRecorder(database: database),
    );
    addTearDown(state.dispose);
    await state.initialize();
    state
      ..accept(start2Event)
      ..accept(portEvent)
      ..accept(mapStartEvent);
    await state.idle;
    state.accept(
      kcsapiEvent('/kcsapi/api_req_map/next', {
        'api_maparea_id': 1,
        'api_mapinfo_no': 1,
        'api_no': 2,
        'api_itemget': [
          {'api_usemst': 4, 'api_id': 1, 'api_getcount': 20},
        ],
      }, sequence: 904),
    );
    await state.idle;
    expect(state.state.combatState.currentNode, 2);
  });
}
