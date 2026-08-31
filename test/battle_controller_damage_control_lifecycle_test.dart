import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_controller.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_damage_alert.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_models.dart';
import 'package:yahagi_kancolle_browser/src/battle/prediction/battle_prediction_engine.dart';
import 'package:yahagi_kancolle_browser/src/battle/prediction/battle_prediction_executor.dart';
import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';

void main() {
  test('does not reuse damage control on the next node', () async {
    final state = damageControlState(const <OwnedSlotItem>[
      OwnedSlotItem(instanceId: 501, masterSlotItemId: 42),
    ]);
    final controller = BattleController(gameState: () => state);
    addTearDown(controller.dispose);

    controller
      ..accept(
        apiEvent(
          '/kcsapi/api_req_map/start',
          mapData,
          sequence: 1,
          requestParams: const <String, Object?>{'api_deck_id': '1'},
        ),
      )
      ..accept(
        apiEvent(
          '/kcsapi/api_req_sortie/battle',
          lethalBattle(30, openingHp: 30),
          sequence: 2,
        ),
      );
    await controller.idle;
    expect(controller.current!.friendMain.single.currentHp, 6);
    expect(
      controller.current!.friendMain.single.usedDamageControlItemIds,
      <int>[42],
    );

    controller
      ..accept(apiEvent('/kcsapi/api_req_map/next', mapData, sequence: 3))
      ..accept(
        apiEvent(
          '/kcsapi/api_req_sortie/battle',
          lethalBattle(6, openingHp: 6),
          sequence: 4,
        ),
      );
    await controller.idle;

    expect(controller.current!.friendMain.single.currentHp, 0);
    expect(
      controller.current!.friendMain.single.usedDamageControlItemIds,
      <int>[42],
    );
  });

  test('uses goddess after personnel across nodes', () async {
    final state = damageControlState(const <OwnedSlotItem>[
      OwnedSlotItem(instanceId: 501, masterSlotItemId: 42),
      OwnedSlotItem(instanceId: 502, masterSlotItemId: 43),
    ]);
    final controller = BattleController(gameState: () => state);
    addTearDown(controller.dispose);

    controller
      ..accept(
        apiEvent(
          '/kcsapi/api_req_map/start',
          mapData,
          sequence: 11,
          requestParams: const <String, Object?>{'api_deck_id': '1'},
        ),
      )
      ..accept(
        apiEvent(
          '/kcsapi/api_req_sortie/battle',
          lethalBattle(30, openingHp: 30),
          sequence: 12,
        ),
      );
    await controller.idle;
    expect(controller.current!.friendMain.single.currentHp, 6);

    controller
      ..accept(apiEvent('/kcsapi/api_req_map/next', mapData, sequence: 13))
      ..accept(
        apiEvent(
          '/kcsapi/api_req_sortie/battle',
          lethalBattle(6, openingHp: 6),
          sequence: 14,
        ),
      );
    await controller.idle;

    expect(controller.current!.friendMain.single.currentHp, 30);
    expect(
      controller.current!.friendMain.single.usedDamageControlItemIds,
      <int>[42, 43],
    );
  });

  test('consumes duplicate personnel one by one across three nodes', () async {
    final state = damageControlState(const <OwnedSlotItem>[
      OwnedSlotItem(instanceId: 501, masterSlotItemId: 42),
      OwnedSlotItem(instanceId: 502, masterSlotItemId: 42),
    ]);
    final controller = BattleController(gameState: () => state);
    addTearDown(controller.dispose);

    controller
      ..accept(
        apiEvent(
          '/kcsapi/api_req_map/start',
          mapData,
          sequence: 15,
          requestParams: const <String, Object?>{'api_deck_id': '1'},
        ),
      )
      ..accept(
        apiEvent(
          '/kcsapi/api_req_sortie/battle',
          lethalBattle(30, openingHp: 30),
          sequence: 16,
        ),
      );
    await controller.idle;
    expect(controller.current!.friendMain.single.currentHp, 6);

    controller
      ..accept(apiEvent('/kcsapi/api_req_map/next', mapData, sequence: 17))
      ..accept(
        apiEvent(
          '/kcsapi/api_req_sortie/battle',
          lethalBattle(6, openingHp: 6),
          sequence: 18,
        ),
      );
    await controller.idle;
    expect(controller.current!.friendMain.single.currentHp, 6);
    expect(
      controller.current!.friendMain.single.usedDamageControlItemIds,
      <int>[42, 42],
    );

    controller
      ..accept(apiEvent('/kcsapi/api_req_map/next', mapData, sequence: 19))
      ..accept(
        apiEvent(
          '/kcsapi/api_req_sortie/battle',
          lethalBattle(6, openingHp: 6),
          sequence: 20,
        ),
      );
    await controller.idle;

    expect(controller.current!.friendMain.single.currentHp, 0);
  });

  test('port resets the sortie damage control ledger', () async {
    final state = damageControlState(const <OwnedSlotItem>[
      OwnedSlotItem(instanceId: 501, masterSlotItemId: 42),
    ]);
    final controller = BattleController(gameState: () => state);
    addTearDown(controller.dispose);

    controller
      ..accept(
        apiEvent(
          '/kcsapi/api_req_map/start',
          mapData,
          sequence: 21,
          requestParams: const <String, Object?>{'api_deck_id': '1'},
        ),
      )
      ..accept(
        apiEvent(
          '/kcsapi/api_req_sortie/battle',
          lethalBattle(30, openingHp: 30),
          sequence: 22,
        ),
      );
    await controller.idle;
    expect(controller.current!.friendMain.single.currentHp, 6);

    controller
      ..accept(
        apiEvent(
          '/kcsapi/api_port/port',
          const <String, Object?>{},
          sequence: 23,
        ),
      )
      ..accept(
        apiEvent(
          '/kcsapi/api_req_map/start',
          mapData,
          sequence: 24,
          requestParams: const <String, Object?>{'api_deck_id': '1'},
        ),
      )
      ..accept(
        apiEvent(
          '/kcsapi/api_req_sortie/battle',
          lethalBattle(30, openingHp: 30),
          sequence: 25,
        ),
      );
    await controller.idle;

    expect(controller.current!.friendMain.single.currentHp, 6);
    expect(
      controller.current!.friendMain.single.usedDamageControlItemIds,
      <int>[42],
    );
  });

  test('keeps seventh-ship damage control consumption across nodes', () async {
    final state = strikingForceDamageControlState();
    final controller = BattleController(gameState: () => state);
    addTearDown(controller.dispose);

    controller
      ..accept(
        apiEvent(
          '/kcsapi/api_req_map/start',
          mapData,
          sequence: 31,
          requestParams: const <String, Object?>{'api_deck_id': '3'},
        ),
      )
      ..accept(
        apiEvent(
          '/kcsapi/api_req_sortie/battle',
          strikingForceLethalBattle(33, seventhOpeningHp: 33),
          sequence: 32,
        ),
      );
    await controller.idle;
    expect(controller.current!.friendMain.map((ship) => ship.currentHp), <int>[
      33,
      33,
      33,
      33,
      33,
      33,
      6,
    ]);

    controller
      ..accept(apiEvent('/kcsapi/api_req_map/next', mapData, sequence: 33))
      ..accept(
        apiEvent(
          '/kcsapi/api_req_sortie/battle',
          strikingForceLethalBattle(6, seventhOpeningHp: 6),
          sequence: 34,
        ),
      );
    await controller.idle;

    expect(controller.current!.friendMain.map((ship) => ship.currentHp), <int>[
      33,
      33,
      33,
      33,
      33,
      33,
      0,
    ]);
    expect(controller.current!.friendEscort, isEmpty);
  });

  test('prediction failure makes later POI nodes untrusted', () async {
    final state = damageControlState(const <OwnedSlotItem>[
      OwnedSlotItem(instanceId: 501, masterSlotItemId: 42),
    ]);
    final published = <Map<int, int>>[];
    final controller = BattleController(
      gameState: () => state,
      predictionExecutor: FailOncePredictionExecutor(),
      onFriendlyHpUpdated: (hpByShipId, _) => published.add(hpByShipId),
    );
    addTearDown(controller.dispose);

    controller
      ..accept(
        apiEvent(
          '/kcsapi/api_req_map/start',
          mapData,
          sequence: 47,
          requestParams: const <String, Object?>{'api_deck_id': '1'},
        ),
      )
      ..accept(
        apiEvent(
          '/kcsapi/api_req_sortie/battle',
          lethalBattle(30, openingHp: 30),
          sequence: 48,
        ),
      );
    await controller.idle;
    expect(controller.lastError, isNotNull);

    published.clear();
    controller
      ..accept(apiEvent('/kcsapi/api_req_map/next', mapData, sequence: 49))
      ..accept(
        apiEvent(
          '/kcsapi/api_req_sortie/battle',
          lethalBattle(6, openingHp: 6),
          sequence: 50,
        ),
      );
    await controller.idle;

    expect(controller.lastError, isNull);
    expect(controller.session!.isConfirmed, isFalse);
    expect(controller.current!.rank, BattleRank.unknown);
    expect(published, isEmpty);
  });

  test('does not publish HP when the sortie ledger is untrusted', () async {
    final state = damageControlState(const <OwnedSlotItem>[
      OwnedSlotItem(instanceId: 501, masterSlotItemId: 42),
    ]);
    final published = <Map<int, int>>[];
    final controller = BattleController(
      gameState: () => state,
      onFriendlyHpUpdated: (hpByShipId, _) => published.add(hpByShipId),
    );
    addTearDown(controller.dispose);

    controller.accept(
      apiEvent(
        '/kcsapi/api_req_sortie/battle',
        lethalBattle(30, openingHp: 30),
        sequence: 51,
      ),
    );
    await controller.idle;

    expect(controller.session!.isConfirmed, isFalse);
    expect(controller.current!.rank, BattleRank.unknown);
    expect(published, isEmpty);

    controller.bindFriendlyHpUpdater(
      (hpByShipId, _) => published.add(hpByShipId),
    );
    expect(published, isEmpty);
  });

  test('parse issues make the POI damage control ledger untrusted', () async {
    final state = damageControlState(const <OwnedSlotItem>[
      OwnedSlotItem(instanceId: 501, masterSlotItemId: 42),
    ]);
    final published = <Map<int, int>>[];
    final controller = BattleController(
      gameState: () => state,
      onFriendlyHpUpdated: (hpByShipId, _) => published.add(hpByShipId),
      poiEngineFactory:
          ({
            required friendMain,
            required friendEscort,
            required enemyMain,
            required enemyEscort,
          }) => EchoPredictionEngine(
            friendMain: friendMain,
            friendEscort: friendEscort,
            enemyMain: enemyMain,
            enemyEscort: enemyEscort,
            issues: const <BattleParseIssue>[
              BattleParseIssue(stage: 'test', message: 'incomplete packet'),
            ],
          ),
    );
    addTearDown(controller.dispose);

    controller
      ..accept(
        apiEvent(
          '/kcsapi/api_req_map/start',
          mapData,
          sequence: 71,
          requestParams: const <String, Object?>{'api_deck_id': '1'},
        ),
      )
      ..accept(
        apiEvent(
          '/kcsapi/api_req_sortie/battle',
          lethalBattle(30, openingHp: 30),
          sequence: 72,
        ),
      );
    await controller.idle;

    expect(controller.session!.isConfirmed, isFalse);
    expect(controller.current!.rank, BattleRank.unknown);
    expect(published, isEmpty);
  });

  test('does not vibrate from an untrusted POI prediction', () async {
    final state = damageControlState(const <OwnedSlotItem>[
      OwnedSlotItem(instanceId: 501, masterSlotItemId: 42),
    ]);
    final alerts = RecordingDamageAlertPort();
    final controller = BattleController(
      gameState: () => state,
      damageAlertPort: alerts,
      battleDamageVibrationEnabled: () => true,
    );
    addTearDown(controller.dispose);

    controller.accept(
      apiEvent(
        '/kcsapi/api_req_sortie/battle',
        lethalBattle(30, openingHp: 30),
        sequence: 61,
      ),
    );
    await controller.idle;

    expect(controller.session!.isConfirmed, isFalse);
    expect(alerts.alerts, isEmpty);
  });
}

const Map<String, Object?> mapData = <String, Object?>{
  'api_maparea_id': 1,
  'api_mapinfo_no': 1,
  'api_no': 1,
};

CapturedApiEvent apiEvent(
  String path,
  Object? data, {
  required int sequence,
  Map<String, Object?> requestParams = const <String, Object?>{},
}) => CapturedApiEvent(
  path: path,
  responseBody: jsonEncode(<String, Object?>{
    'api_result': 1,
    'api_data': data,
  }),
  requestParams: requestParams,
  source: CaptureSource.xhr,
  sourceOrigin: 'https://w01y.kancolle-server.com',
  capturedAt: DateTime.utc(2026, 8, 28),
  sequence: sequence,
);

GameState damageControlState(List<OwnedSlotItem> equipment) => GameState(
  hasPortData: true,
  ships: <int, OwnedShip>{
    1001: OwnedShip(
      id: 1001,
      masterId: 1,
      level: 1,
      currentHp: 30,
      maxHp: 30,
      slotIds: <int>[for (final item in equipment) item.instanceId],
    ),
  },
  slotItems: <int, OwnedSlotItem>{
    for (final item in equipment) item.instanceId: item,
  },
  fleets: const <Fleet>[
    Fleet(id: 1, name: 'Test', shipIds: <int>[1001]),
  ],
);

GameState strikingForceDamageControlState() => GameState(
  hasPortData: true,
  ships: <int, OwnedShip>{
    for (var index = 0; index < 7; index++)
      3001 + index: OwnedShip(
        id: 3001 + index,
        masterId: 101 + index,
        level: 1,
        currentHp: 33,
        maxHp: 33,
        slotIds: index == 6 ? const <int>[701] : const <int>[],
      ),
  },
  slotItems: const <int, OwnedSlotItem>{
    701: OwnedSlotItem(instanceId: 701, masterSlotItemId: 42),
  },
  fleets: <Fleet>[
    Fleet(
      id: 3,
      name: 'Striking Force',
      shipIds: <int>[for (var index = 0; index < 7; index++) 3001 + index],
      slotCount: 7,
    ),
  ],
);

Map<String, Object?> lethalBattle(num damage, {required int openingHp}) =>
    <String, Object?>{
      'api_deck_id': 1,
      'api_f_nowhps': <int>[-1, openingHp],
      'api_f_maxhps': const <int>[-1, 30],
      'api_e_nowhps': const <int>[-1, 20],
      'api_e_maxhps': const <int>[-1, 20],
      'api_ship_ke': const <int>[-1, 501],
      'api_hougeki1': <String, Object?>{
        'api_at_eflag': const <int>[1],
        'api_at_list': const <int>[0],
        'api_df_list': const <Object?>[
          <int>[0],
        ],
        'api_damage': <Object?>[
          <num>[damage],
        ],
      },
    };

Map<String, Object?> strikingForceLethalBattle(
  num damage, {
  required int seventhOpeningHp,
}) => <String, Object?>{
  'api_deck_id': 3,
  'api_f_nowhps': <int>[-1, 33, 33, 33, 33, 33, 33, seventhOpeningHp],
  'api_f_maxhps': const <int>[-1, 33, 33, 33, 33, 33, 33, 33],
  'api_e_nowhps': const <int>[-1, 20],
  'api_e_maxhps': const <int>[-1, 20],
  'api_ship_ke': const <int>[-1, 501],
  'api_hougeki1': <String, Object?>{
    'api_at_eflag': const <int>[1],
    'api_at_list': const <int>[0],
    'api_df_list': const <Object?>[
      <int>[6],
    ],
    'api_damage': <Object?>[
      <num>[damage],
    ],
  },
};

final class EchoPredictionEngine implements BattlePredictionEngine {
  const EchoPredictionEngine({
    required this.friendMain,
    required this.friendEscort,
    required this.enemyMain,
    required this.enemyEscort,
    this.issues = const <BattleParseIssue>[],
  });

  final List<BattleShipSnapshot> friendMain;
  final List<BattleShipSnapshot> friendEscort;
  final List<BattleShipSnapshot> enemyMain;
  final List<BattleShipSnapshot> enemyEscort;
  final List<BattleParseIssue> issues;

  @override
  BattlePrediction append({
    required String path,
    required Map<String, Object?> data,
  }) => BattlePrediction(
    friendMain: friendMain,
    friendEscort: friendEscort,
    enemyMain: enemyMain,
    enemyEscort: enemyEscort,
    rank: BattleRank.d,
    issues: issues,
  );
}

final class RecordingDamageAlertPort implements BattleDamageAlertPort {
  final List<BattleDamageAlertSeverity> alerts = <BattleDamageAlertSeverity>[];

  @override
  Future<void> alert(BattleDamageAlertSeverity severity) async {
    alerts.add(severity);
  }
}

final class FailOncePredictionExecutor implements BattlePredictionExecutor {
  var _failed = false;

  @override
  Future<BattlePredictionAppendResult> append({
    required BattlePredictionEngine engine,
    required String path,
    required Map<String, Object?> data,
  }) async {
    if (!_failed) {
      _failed = true;
      throw StateError('expected prediction failure');
    }
    return (engine: engine, prediction: engine.append(path: path, data: data));
  }
}
