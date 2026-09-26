import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_controller.dart';
import 'package:yahagi_kancolle_browser/src/battle/prediction/battle_prediction_engine.dart';
import 'package:yahagi_kancolle_browser/src/battle/prediction/battle_prediction_executor.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_reducer.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_serializer.dart';

import 'fixtures/kcsapi_fixtures.dart';

void main() {
  GameState parsedMasters() => GameStateReducer().reduce(
    GameState.empty,
    kcsapiEvent('/kcsapi/api_start2/getData', {
      'api_mst_ship': [
        {'api_id': 501, 'api_name': '空母ヲ級', 'api_yomi': 'FLAGSHIP'},
        {'api_id': 502, 'api_name': '空母ヲ級', 'api_yomi': 'Elite'},
        {'api_id': 503, 'api_name': '吹雪', 'api_yomi': 'ふぶき'},
        {'api_id': 504, 'api_name': '駆逐イ級'},
      ],
    }),
  );

  test('start2 reading survives portrait updates and cache round trip', () {
    final state = parsedMasters();
    final withPortrait = state.copyWith(
      masterShips: {
        ...state.masterShips,
        501: state.masterShips[501]!.copyWith(portraitFileName: 'new-portrait'),
      },
    );
    final restored = GameStateSerializer.deserialize(
      GameStateSerializer.serialize(withPortrait),
    );
    final serialized =
        jsonDecode(GameStateSerializer.serialize(restored)) as Map;
    final masters = serialized['masterShips'] as Map;

    expect((masters['501'] as Map)['reading'], 'FLAGSHIP');
    expect((masters['502'] as Map)['reading'], 'Elite');
    expect((masters['503'] as Map)['reading'], 'ふぶき');
    expect((masters['504'] as Map)['reading'], '');
  });

  test('old cached master ships have an empty reading', () {
    final restored = GameStateSerializer.deserialize(
      jsonEncode({
        'masterShips': {
          '501': {'id': 501, 'name': '空母ヲ級', 'shipTypeId': 11},
        },
      }),
    );
    final serialized =
        jsonDecode(GameStateSerializer.serialize(restored)) as Map;

    expect((serialized['masterShips']['501'] as Map)['reading'], '');
  });

  test(
    'enemy details normalize only known variants without changing fleet names',
    () async {
      final state = parsedMasters();
      final controller = BattleController(
        gameState: () => state,
        predictionExecutor: const _InlineExecutor(),
      );
      addTearDown(controller.dispose);
      controller.accept(mapStartEvent);
      controller.accept(
        kcsapiEvent(dayBattleEvent.path, {
          'api_ship_ke': [501, 502, 503, 504],
          'api_ship_lv': [1, 1, 1, 1],
          'api_e_nowhps': [96, 76, 15, 20],
          'api_e_maxhps': [96, 76, 15, 20],
        }, sequence: 21),
      );
      await controller.idle;

      final enemies = controller.current!.enemyMain;
      expect(controller.lastError, isNull);
      expect(enemies.map((ship) => ship.name), ['空母ヲ級', '空母ヲ級', '吹雪', '駆逐イ級']);
      expect(enemies.map((ship) => ship.details!.enemyVariant), [
        'Flagship',
        'elite',
        null,
        null,
      ]);
    },
  );
}

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
