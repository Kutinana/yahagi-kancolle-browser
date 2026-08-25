import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/kcwiki_report/kcwiki_report_collector.dart';
import 'package:yahagi_kancolle_browser/src/kcwiki_report/kcwiki_report_request.dart';

void main() {
  late KcwikiReportCollector collector;
  late GameState state;

  setUp(() {
    collector = KcwikiReportCollector(clock: () => DateTime.utc(2026, 8, 25));
    state = _state();
  });

  test('completed quest reports newly unlocked quests only', () {
    collector.accept(_questList(<int>[101, 102]), state);
    collector.accept(
      _event(
        '/kcsapi/api_req_quest/clearitemget',
        const <String, Object?>{},
        requestParams: const <String, Object?>{'api_quest_id': '101'},
      ),
      state,
    );

    final reports = collector.accept(_questList(<int>[102, 301]), state);

    expect(reports, hasLength(1));
    expect(reports.single.module, KcwikiReportModule.quest);
    expect(reports.single.fields['current'], 101);
    expect(reports.single.fields['after'], <int>[301]);
    expect(reports.single.fields['detail'], isA<List<Object?>>());
  });

  test('daily quest rollover guard does not create a false relation', () {
    collector.accept(_questList(<int>[101]), state);
    collector.accept(
      _event(
        '/kcsapi/api_req_quest/clearitemget',
        const <String, Object?>{},
        requestParams: const <String, Object?>{'api_quest_id': '101'},
      ),
      state,
    );

    expect(collector.accept(_questList(<int>[201, 301]), state), isEmpty);
  });

  test('remodel detail includes assistant ship and selected recipe', () {
    collector.accept(
      _event('/kcsapi/api_req_kousyou/remodel_slotlist', <Object?>[
        <String, Object?>{'api_id': 7, 'api_slot_id': 55},
      ]),
      state,
    );

    final reports = collector.accept(
      _event(
        '/kcsapi/api_req_kousyou/remodel_slotlist_detail',
        const <String, Object?>{'api_req_fuel': 10},
        requestParams: const <String, Object?>{'api_id': '7'},
      ),
      state,
    );

    expect(reports.single.module, KcwikiReportModule.remodel);
    expect((reports.single.fields['ship'] as Map)['api_id'], 2);
    final recipes = reports.single.fields['list'] as List<Object?>;
    expect((recipes.single as Map)['api_req_fuel'], 10);
  });

  test('map start creates a next_way_v2 report with fleet context', () {
    final reports = collector.accept(_mapStart(), state);

    expect(reports.single.module, KcwikiReportModule.nextWayV2);
    expect(reports.single.fields['deck1'], isA<List<Object?>>());
    expect(reports.single.fields['slot1'], isA<List<Object?>>());
    expect((reports.single.fields['nextInfo'] as Map)['api_maparea_id'], 1);
    expect(
      (reports.single.fields['saku'] as Map).keys,
      contains('sakuOne33x4'),
    );
  });

  test('destruction battle creates air_base_attack beside route report', () {
    collector.accept(_mapStart(), state);
    final reports = collector.accept(
      _event('/kcsapi/api_req_map/next', <String, Object?>{
        'api_no': 2,
        'api_maparea_id': 1,
        'api_mapinfo_no': 1,
        'api_destruction_battle': <String, Object?>{
          'api_air_base_attack': <Object?>[
            <String, Object?>{
              'api_stage1': <String, Object?>{'api_f_count': 18},
            },
          ],
          'api_lost_kind': 1,
        },
      }),
      state,
    );

    expect(
      reports.map((report) => report.module),
      containsAll(<KcwikiReportModule>[
        KcwikiReportModule.nextWayV2,
        KcwikiReportModule.airBaseAttack,
      ]),
    );
    final air = reports.singleWhere(
      (report) => report.module == KcwikiReportModule.airBaseAttack,
    );
    expect(air.fields['api_air_base_attack'], isA<String>());
    expect(air.fields['curCellId'], 2);
  });

  test('night battle friendly data creates a friendly_info report', () {
    collector.accept(_mapStart(), state);
    final reports = collector.accept(
      _event('/kcsapi/api_req_battle_midnight/battle', <String, Object?>{
        'api_ship_ke': <int>[1001],
        'api_e_nowhps': <int>[20],
        'api_friendly_info': <String, Object?>{
          'api_ship_id': <int>[501],
          'api_ship_lv': <int>[80],
        },
        'api_friendly_battle': <String, Object?>{},
      }),
      state,
    );

    final friendly = reports.singleWhere(
      (report) => report.module == KcwikiReportModule.friendlyInfo,
    );
    expect(friendly.fields['maparea_id'], 1);
    expect(friendly.fields['curCellId'], 1);
    expect(friendly.fields['deck1'], isA<List<Object?>>());
  });

  test('battle phases are flushed as one battle report on port', () {
    collector.accept(_mapStart(), state);
    collector.accept(
      _event('/kcsapi/api_req_sortie/battle', <String, Object?>{
        'api_ship_ke': <int>[1001],
        'api_token': 'response-secret',
      }),
      state,
    );
    collector.accept(
      _event('/kcsapi/api_req_sortie/battleresult', <String, Object?>{
        'api_win_rank': 'S',
      }),
      state,
    );

    final reports = collector.accept(
      _event('/kcsapi/api_port/port', const <String, Object?>{}),
      state,
    );

    final battle = reports.singleWhere(
      (report) => report.module == KcwikiReportModule.battle,
    );
    final data = battle.fields['data'] as Map;
    expect(data['map'], <int>[1, 1, 1]);
    expect(data['packet'], hasLength(2));
    expect(jsonEncode(battle.fields), isNot(contains('response-secret')));
    expect(jsonEncode(battle.fields), isNot(contains('api_token')));
  });

  test('reset discards unfinished cross-event state', () {
    collector.accept(_mapStart(), state);
    collector.accept(
      _event('/kcsapi/api_req_sortie/battle', const <String, Object?>{}),
      state,
    );

    collector.reset();

    expect(
      collector.accept(
        _event('/kcsapi/api_port/port', const <String, Object?>{}),
        state,
      ),
      isEmpty,
    );
  });
}

CapturedApiEvent _questList(List<int> ids) =>
    _event('/kcsapi/api_get_member/questlist', <String, Object?>{
      'api_list': <Object?>[
        for (final id in ids)
          <String, Object?>{
            'api_no': id,
            'api_title': 'quest-$id',
            'api_detail': 'detail-$id',
            'api_category': 1,
            'api_type': 4,
            'api_state': 2,
            'api_progress_flag': 0,
            'api_get_material': <int>[0, 0, 0, 0],
          },
      ],
    });

CapturedApiEvent _mapStart() => _event(
  '/kcsapi/api_req_map/start',
  <String, Object?>{
    'api_no': 1,
    'api_next': 2,
    'api_maparea_id': 1,
    'api_mapinfo_no': 1,
    'api_cell_data': <Object?>[
      <String, Object?>{'api_no': 1, 'api_color_no': 1},
    ],
  },
  requestParams: const <String, Object?>{'api_deck_id': '1'},
);

CapturedApiEvent _event(
  String path,
  Object? data, {
  Map<String, Object?> requestParams = const <String, Object?>{},
}) {
  final envelope = <String, Object?>{'api_result': 1, 'api_data': data};
  return CapturedApiEvent(
    path: path,
    requestParams: requestParams,
    responseBody: jsonEncode(envelope),
    source: CaptureSource.manual,
    capturedAt: DateTime.utc(2026, 8, 25),
    decodedEnvelope: envelope,
  );
}

GameState _state() => GameState(
  admiralLevel: 120,
  mapDifficulties: const <int, int>{101: 4},
  memberMapInfos: const <int, MemberMapInfo>{
    101: MemberMapInfo(
      id: 101,
      mapAreaId: 1,
      mapNo: 1,
      selectedRank: 4,
      currentHp: 900,
      maxHp: 1000,
      requiredDefeatCount: 5,
      defeatCount: 1,
    ),
  },
  masterShips: const <int, MasterShip>{
    101: MasterShip(id: 101, name: 'ship-101', shipTypeId: 2, speed: 10),
    102: MasterShip(id: 102, name: 'ship-102', shipTypeId: 2, speed: 10),
  },
  masterSlotItems: const <int, MasterSlotItem>{
    501: MasterSlotItem(
      id: 501,
      name: 'recon',
      lineOfSight: 6,
      type: <int>[0, 0, 10, 10],
    ),
  },
  ships: const <int, OwnedShip>{
    1: OwnedShip(
      id: 1,
      masterId: 101,
      level: 80,
      currentHp: 30,
      maxHp: 30,
      lineOfSight: 40,
      speed: 10,
      slotIds: <int>[11],
      onSlot: <int>[2],
    ),
    2: OwnedShip(
      id: 2,
      masterId: 102,
      level: 50,
      currentHp: 25,
      maxHp: 30,
      lineOfSight: 20,
      speed: 10,
    ),
  },
  slotItems: const <int, OwnedSlotItem>{
    11: OwnedSlotItem(instanceId: 11, masterSlotItemId: 501, level: 2),
  },
  fleets: const <Fleet>[
    Fleet(id: 1, name: '第一舰队', shipIds: <int>[1, 2]),
  ],
);
