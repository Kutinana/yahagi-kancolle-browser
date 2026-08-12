import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/logbook/logbook_database.dart';
import 'package:yahagi_kancolle_browser/src/logbook/logbook_event_recorder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LogbookDatabase database;
  late LogbookEventRecorder recorder;
  late GameState state;

  setUp(() async {
    database = await LogbookDatabase.openForTesting();
    recorder = LogbookEventRecorder(database: database);
    state = const GameState(
      masterShipTypes: {
        2: MasterShipType(id: 2, name: '驱逐舰'),
        3: MasterShipType(id: 3, name: '轻巡洋舰'),
      },
      masterShips: {
        1: MasterShip(id: 1, name: '雪风', shipTypeId: 2),
        2: MasterShip(id: 2, name: '矢矧改二乙', shipTypeId: 3),
        3: MasterShip(id: 3, name: '深雪', shipTypeId: 2),
      },
      masterSlotItems: {
        201: MasterSlotItem(id: 201, name: '46cm三连装炮', type: [0, 0, 1, 1]),
      },
      masterMissions: {
        38: MasterMission(
          id: 38,
          name: '东京急行（弐）',
          duration: Duration(minutes: 175),
          displayNumber: '38',
        ),
        110: MasterMission(
          id: 110,
          name: '南西方面航空偵察作戦',
          duration: Duration(minutes: 35),
          displayNumber: 'B1',
        ),
      },
      ships: {
        100: OwnedShip(id: 100, masterId: 2, level: 132),
        101: OwnedShip(id: 101, masterId: 3, level: 1),
      },
      fleets: [
        Fleet(id: 1, name: '第一舰队', shipIds: [100]),
        Fleet(
          id: 3,
          name: '第三舰队',
          mission: FleetMission(state: 2, missionId: 110),
        ),
      ],
    );
  });

  tearDown(() => database.close());

  test('records development recipe, equipment icon and secretary', () async {
    await recorder.record(
      _event(
        '/kcsapi/api_req_kousyou/createitem',
        params: const {
          'api_item1': '10',
          'api_item2': '251',
          'api_item3': '250',
          'api_item4': '10',
        },
        data: const {
          'api_create_flag': 1,
          'api_slot_item': {'api_slotitem_id': 201},
        },
      ),
      state,
    );

    final row = (await database.getDevelopmentRecords()).single;
    expect(row['equipment_name'], '46cm三连装炮');
    expect(row['equipment_type'], '小口径主炮');
    expect(row['equipment_icon_id'], 1);
    expect(row['secretary_name'], '矢矧改二乙 Lv.132');
  });

  test('records equipment from the modern api_get_items response', () async {
    await recorder.record(
      _event(
        '/kcsapi/api_req_kousyou/createitem',
        params: const {
          'api_item1': '10',
          'api_item2': '251',
          'api_item3': '250',
          'api_item4': '10',
        },
        data: const {
          'api_create_flag': 1,
          'api_get_items': [
            {'api_id': 46637, 'api_slotitem_id': 201},
          ],
        },
      ),
      state,
    );

    final row = (await database.getDevelopmentRecords()).single;
    expect(row['equipment_id'], 201);
    expect(row['equipment_name'], '46cm三连装炮');
    expect(row['equipment_type'], '小口径主炮');
    expect(row['equipment_icon_id'], 1);
  });

  test(
    'records multi-development results with one database notification',
    () async {
      var changes = 0;
      database.changesFor(LogbookChangeCategory.development).addListener(() {
        changes += 1;
      });

      await recorder.record(
        _event(
          '/kcsapi/api_req_kousyou/createitem',
          params: const {
            'api_item1': '10',
            'api_item2': '20',
            'api_item3': '30',
            'api_item4': '40',
          },
          data: const {
            'api_get_items': [
              {'api_id': 1, 'api_slotitem_id': 201},
              {'api_id': 2, 'api_slotitem_id': 201},
            ],
          },
        ),
        state,
      );

      expect(await database.getDevelopmentRecords(), hasLength(2));
      expect(changes, 1);
    },
  );

  test('joins construction start with getship result', () async {
    await recorder.record(
      _event(
        '/kcsapi/api_req_kousyou/createship',
        params: const {
          'api_kdock_id': '2',
          'api_item1': '30',
          'api_item2': '30',
          'api_item3': '30',
          'api_item4': '30',
          'api_item5': '1',
          'api_large_flag': '0',
        },
      ),
      state,
    );
    var rows = await database.getConstructionRecords();
    expect(rows, hasLength(1));
    expect(rows.single['ship_name'], '建造中');

    await recorder.record(
      _event(
        '/kcsapi/api_req_kousyou/getship',
        params: const {'api_kdock_id': '2'},
        data: const {
          'api_ship': {'api_ship_id': 1},
        },
      ),
      state,
    );

    rows = await database.getConstructionRecords();
    expect(rows, hasLength(1));
    final row = rows.single;
    expect(row['ship_name'], '雪风');
    expect(row['ship_type'], '驱逐舰');
    expect(row['construction_type'], '普通建造');
    expect(row['secretary_name'], '矢矧改二乙 Lv.132');
  });

  test(
    'uses the ship already exposed by the construction dock response',
    () async {
      await recorder.record(
        _event(
          '/kcsapi/api_req_kousyou/createship',
          params: const {
            'api_kdock_id': '2',
            'api_item1': '30',
            'api_item2': '30',
            'api_item3': '30',
            'api_item4': '30',
            'api_item5': '1',
            'api_large_flag': '0',
          },
          data: const {
            'api_kdock': [
              {'api_id': 2, 'api_created_ship_id': 1},
            ],
          },
        ),
        state,
      );

      final row = (await database.getConstructionRecords()).single;
      expect(row['ship_name'], '雪风');
      expect(row['ship_type'], '驱逐舰');
    },
  );

  test(
    'updates a pending construction when the dock list reveals the ship',
    () async {
      await recorder.record(
        _event(
          '/kcsapi/api_req_kousyou/createship',
          params: const {
            'api_kdock_id': '2',
            'api_item1': '30',
            'api_item2': '30',
            'api_item3': '30',
            'api_item4': '30',
            'api_item5': '1',
            'api_large_flag': '0',
          },
        ),
        state,
      );

      await recorder.record(
        _event(
          '/kcsapi/api_get_member/kdock',
          data: const <Object?>[
            {'api_id': 2, 'api_created_ship_id': 1},
          ],
        ),
        state,
      );

      final rows = await database.getConstructionRecords();
      expect(rows, hasLength(1));
      expect(rows.single['ship_name'], '雪风');
      expect(rows.single['ship_type'], '驱逐舰');
    },
  );

  test(
    'records consumed ships as red scrap or blue modernization rows',
    () async {
      await recorder.record(
        _event(
          '/kcsapi/api_req_kousyou/destroyship',
          params: const {'api_ship_id': '101'},
        ),
        state,
      );
      await recorder.record(
        _event(
          '/kcsapi/api_req_kaisou/powerup',
          params: const {'api_id_items': '101'},
        ),
        state,
      );

      final rows = await database.getRetirementRecords();
      expect(rows.map((row) => row['type']), containsAll(['解体', '改修']));
      expect(rows.every((row) => row['ship_name'] == '深雪'), isTrue);
    },
  );

  test('records authoritative expedition and reward item names', () async {
    await recorder.record(
      _event(
        '/kcsapi/api_req_mission/result',
        params: const {'api_mission_id': '38'},
        data: const {
          'api_clear_result': 2,
          'api_quest_name': '错误的远征名',
          'api_get_material': [0, 0, 300, 420],
          'api_get_item1': {
            'api_useitem_id': 1,
            'api_useitem_name': '高速修复材',
            'api_useitem_count': 1,
          },
          'api_get_item2': {'api_useitem_id': 3, 'api_useitem_count': 1},
        },
      ),
      state,
    );

    final row = (await database.getExpeditionRecords()).single;
    expect(row['expedition_id'], 38);
    expect(row['name'], '东京急行（弐）');
    expect(row['item1_name'], '高速修复材');
    expect(row['item2_name'], '开发资材');
  });

  test('records material rewards identified by api_useitem_flag', () async {
    await recorder.record(
      _event(
        '/kcsapi/api_req_mission/result',
        params: const {'api_mission_id': '6'},
        data: const {
          'api_clear_result': 2,
          'api_get_material': [0, 0, 0, 120],
          'api_useitem_flag': [1, 0],
          'api_get_item1': {
            'api_useitem_id': -1,
            'api_useitem_name': null,
            'api_useitem_count': 1,
          },
        },
      ),
      state,
    );

    final row = (await database.getExpeditionRecords()).single;
    expect(row['yield_bucket'], 1);
    expect(row['item1_id'], 1);
    expect(row['item1_name'], '高速修复材');
    expect(row['item1_count'], 1);
    expect(jsonDecode('${row['reward_items_json']}'), <Map<String, Object?>>[
      {'id': 1, 'name': '高速修复材', 'count': 1},
    ]);
  });

  test(
    'uses the numbered reward slot when only api_get_item2 exists',
    () async {
      await recorder.record(
        _event(
          '/kcsapi/api_req_mission/result',
          params: const {'api_mission_id': '110'},
          data: const {
            'api_clear_result': 2,
            'api_get_material': [0, 0, 36, 54],
            'api_useitem_flag': [0, 1],
            'api_get_item2': {
              'api_useitem_id': -1,
              'api_useitem_name': null,
              'api_useitem_count': 1,
            },
          },
        ),
        state,
      );

      final row = (await database.getExpeditionRecords()).single;
      expect(row['yield_bucket'], 1);
      expect(row['item1_id'], 1);
      expect(row['item1_count'], 1);
      expect(jsonDecode('${row['reward_items_json']}'), <Map<String, Object?>>[
        {'id': 1, 'name': '高速修复材', 'count': 1},
      ]);
    },
  );

  test('resolves mission from deck and stores every reward item', () async {
    await recorder.record(
      _event(
        '/kcsapi/api_req_mission/result',
        params: const {'api_deck_id': '3'},
        data: const {
          'api_clear_result': 2,
          'api_quest_name': '南西方面航空偵察作戦',
          'api_get_material': [0, 0, 36, 54],
          'api_get_items': [
            {'api_useitem_id': 1, 'api_useitem_count': 2},
            {'api_useitem_id': 3, 'api_useitem_count': 1},
            {'api_useitem_id': 10, 'api_useitem_count': 3},
          ],
        },
      ),
      state,
    );

    final row = (await database.getExpeditionRecords()).single;
    expect(row['expedition_id'], 110);
    expect(row['name'], '南西方面航空偵察作戦');
    final rewards = jsonDecode('${row['reward_items_json']}') as List<dynamic>;
    expect(rewards, hasLength(3));
    expect(rewards.map((item) => item['id']), <int>[1, 3, 10]);
    expect(rewards.map((item) => item['count']), <int>[2, 1, 3]);
  });

  test('timestamps expedition results when the API is captured', () async {
    await recorder.record(
      _event(
        '/kcsapi/api_req_mission/result',
        params: const {'api_deck_id': '3'},
        data: const {
          'api_clear_result': 1,
          'api_quest_name': '南西方面航空偵察作戦',
          'api_get_material': [0, 0, 36, 54],
        },
      ),
      state,
    );

    final row = (await database.getExpeditionRecords()).single;
    expect(
      row['timestamp'],
      DateTime.utc(2026, 8, 11, 12).millisecondsSinceEpoch,
    );
  });
}

CapturedApiEvent _event(
  String path, {
  Map<String, Object?> params = const {},
  Object? data = const <String, Object?>{},
}) => CapturedApiEvent(
  path: path,
  requestParams: params,
  responseBody: jsonEncode({'api_result': 1, 'api_data': data}),
  source: CaptureSource.manual,
  capturedAt: DateTime.utc(2026, 8, 11, 12),
);
