import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_controller.dart';
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
