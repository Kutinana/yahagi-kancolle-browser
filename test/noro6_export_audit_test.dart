import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_reducer.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_serializer.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/deck_builder_exporter.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/external_fleet_tool_launcher.dart';
import 'fixtures/kcsapi_fixtures.dart';

GameState auditState() {
  final reducer = GameStateReducer();
  var state = reducer.reduce(
    GameState.empty,
    kcsapiEvent('/kcsapi/api_get_member/ship3', {
      'api_ship_data': [
        {
          'api_id': 7,
          'api_ship_id': 187,
          'api_lv': 133,
          'api_exp': [100000, 1000, 0],
          'api_nowhp': 40,
          'api_maxhp': 96,
          'api_lucky': [30, 99],
          'api_taisen': [76, 90],
          'api_kyouka': [20, 0, 30, 15, 12, 2, 6],
          'api_sally_area': 3,
          'api_sp_effect_items': [
            {'api_kind': 1},
          ],
          'api_slotnum': 3,
          'api_onslot_max': [20, 0, 15, 999],
          'api_onslot': [18, 0, 0],
          'api_slot': [501, -1, 502],
          'api_slot_ex': -1,
        },
        {
          'api_id': 8,
          'api_ship_id': 187,
          'api_lv': 99,
          'api_exp': [100, 100, 0],
          'api_slot_ex': 0,
          'api_slot': [-1, -1, -1],
        },
      ],
    }),
  );
  state = reducer.reduce(
    state,
    kcsapiEvent('/kcsapi/api_get_member/slot_item', [
      {'api_id': 501, 'api_slotitem_id': 86, 'api_level': 7, 'api_alv': 7},
      {'api_id': 502, 'api_slotitem_id': 86, 'api_level': 3, 'api_alv': 2},
      {'api_id': 503, 'api_slotitem_id': 86, 'api_level': 3, 'api_alv': 2},
    ]),
  );
  return state.copyWith(
    hasPortData: true,
    admiralLevel: 120,
    combinedFleetType: CombinedFleetType.surfaceTaskForce,
    fleets: [
      const Fleet(id: 1, name: 'A & B # + % / 日本', shipIds: [7, 8]),
    ],
    landBases: [
      const LandBaseState(
        areaId: 48,
        baseId: 2,
        name: '基地',
        actionKind: 2,
        squadrons: [
          LandBaseSquadronState(
            squadronId: 3,
            slotItemId: 503,
            currentCount: 0,
            maxCount: 18,
          ),
        ],
      ),
    ],
  );
}

Map decodeImport(GameState state) =>
    jsonDecode(
          Uri.decodeComponent(
            externalFleetToolUri(
              ExternalFleetTool.noro6,
              const DeckBuilderExporter().exportJson(state),
              state: state,
            ).fragment.substring('import:'.length),
          ),
        )
        as Map;

void main() {
  test(
    'pending export refresh clears on authoritative updates and removal',
    () {
      final reducer = GameStateReducer();
      final before = auditState();
      final dirty = reducer.reduce(
        before,
        kcsapiEvent(
          '/kcsapi/api_req_kaisou/unsetslot_all',
          null,
          includeApiData: false,
          requestParams: {'api_id': '7'},
        ),
      );
      final freshShip = {
        'api_id': 7,
        'api_ship_id': 187,
        'api_slot': [-1, -1, -1],
        'api_taisen': [56, 90],
      };
      for (final entry in <String, Object?>{
        '/kcsapi/api_get_member/ship2': [freshShip],
        '/kcsapi/api_get_member/ship_deck': {
          'api_ship_data': [freshShip],
        },
        '/kcsapi/api_req_kaisou/slot_exchange_index': {
          'api_ship_data': freshShip,
        },
        '/kcsapi/api_req_kaisou/slot_deprive': {
          'api_ship_data': {'api_set_ship': freshShip},
        },
        '/kcsapi/api_req_kaisou/marriage': freshShip,
        '/kcsapi/api_req_kaisou/powerup': {'api_ship': freshShip},
        '/kcsapi/api_req_kousyou/getship': {'api_ship': freshShip},
        '/kcsapi/api_port/port': {
          'api_ship': [freshShip],
        },
        '/kcsapi/api_req_kousyou/destroyship': {},
      }.entries) {
        final state = reducer.reduce(
          dirty,
          kcsapiEvent(
            entry.key,
            entry.value,
            requestParams: {'api_ship_id': '7'},
          ),
        );
        expect(state.pendingExportShipIds, isEmpty, reason: entry.key);
        expect(state.canExportFleet, isTrue, reason: entry.key);
      }
      final charge = reducer.reduce(
        dirty,
        kcsapiEvent('/kcsapi/api_req_hokyu/charge', {
          'api_ship': [
            {
              'api_id': 7,
              'api_fuel': 10,
              'api_bull': 10,
              'api_onslot': [0, 0, 0],
            },
          ],
        }),
      );
      expect(charge.canExportFleet, isFalse);
      final failed = reducer.reduce(
        before,
        kcsapiEvent(
          '/kcsapi/api_req_kaisou/slotset',
          null,
          includeApiData: false,
          requestParams: {
            'api_id': '7',
            'api_slot_idx': '0',
            'api_item_id': '501',
          },
        ),
      );
      expect(
        failed.canExportFleet,
        isTrue,
        reason: 'unchanged equipment does not wait for another response',
      );
      final restarted = reducer.reduce(
        dirty,
        kcsapiEvent('/kcsapi/api_start2/getData', {}),
      );
      expect(restarted.pendingExportShipIds, isEmpty);
      expect(restarted.canExportFleet, isFalse);
    },
  );

  test(
    'new land base is captured and subsequent equipment changes are exportable',
    () {
      final reducer = GameStateReducer();
      var state = reducer.reduce(
        auditState(),
        kcsapiEvent('/kcsapi/api_req_air_corps/expand_base', [
          {
            'api_area_id': 6,
            'api_rid': 1,
            'api_name': 'new base',
            'api_action_kind': 0,
            'api_distance': {'api_base': 0, 'api_bonus': 0},
            'api_plane_info': [],
          },
        ]),
      );
      expect(state.landBases, hasLength(2));
      state = reducer.reduce(
        state,
        kcsapiEvent(
          '/kcsapi/api_req_air_corps/set_plane',
          {
            'api_distance': {'api_base': 5, 'api_bonus': 0},
            'api_plane_info': [
              {
                'api_squadron_id': 1,
                'api_slotid': 501,
                'api_count': 18,
                'api_max_count': 18,
              },
            ],
          },
          requestParams: {'api_area_id': '6', 'api_base_id': '1'},
        ),
      );
      final output = const DeckBuilderExporter().exportMap(
        state,
        eventLandBasesOnly: false,
      );
      expect((output['a1'] as Map)['name'], 'new base');
      expect(((output['a1'] as Map)['items'] as Map)['i1'], {
        'id': 86,
        'rf': 7,
        'mas': 7,
        'ac': 18,
      });
      expect((output['a2'] as Map)['name'], '基地');
      expect(
        (const DeckBuilderExporter().exportMap(state)['a1'] as Map)['name'],
        '基地',
      );
    },
  );

  test('equipment changes wait for matching ship stats before export', () {
    final reducer = GameStateReducer();
    for (final path in ['slotset', 'slotset_ex', 'unsetslot_all']) {
      var state = reducer.reduce(
        auditState(),
        kcsapiEvent(
          '/kcsapi/api_req_kaisou/$path',
          null,
          includeApiData: false,
          requestParams: {
            'api_id': '7',
            'api_slot_idx': '0',
            'api_item_id': '-1',
          },
        ),
      );
      // slotset_ex opens an already-empty slot in this fixture; use a real equipment change.
      if (path == 'slotset_ex') {
        state = reducer.reduce(
          state,
          kcsapiEvent(
            '/kcsapi/api_req_kaisou/slotset_ex',
            null,
            includeApiData: false,
            requestParams: {'api_id': '7', 'api_item_id': '501'},
          ),
        );
      }
      expect(state.canExportFleet, isFalse, reason: path);
      state = reducer.reduce(
        state,
        kcsapiEvent('/kcsapi/api_get_member/ship3', {
          'api_ship_data': [
            {
              'api_id': 8,
              'api_ship_id': 187,
              'api_slot': [-1],
              'api_taisen': [30, 90],
            },
          ],
        }),
      );
      expect(
        state.canExportFleet,
        isFalse,
        reason: 'another ship is not sufficient',
      );
      state = reducer.reduce(
        state,
        kcsapiEvent('/kcsapi/api_get_member/ship3', {
          'api_ship_data': [
            {'api_id': 7, 'api_ship_id': 187, 'api_lv': 133},
          ],
        }),
      );
      expect(
        state.canExportFleet,
        isFalse,
        reason: 'a partial response without stats is not sufficient',
      );
      state = reducer.reduce(
        state,
        kcsapiEvent('/kcsapi/api_get_member/ship3', {
          'api_ship_data': [
            {
              'api_id': 7,
              'api_ship_id': 187,
              'api_slot': [-1, -1, 502],
              'api_taisen': [66, 90],
            },
          ],
        }),
      );
      expect(state.canExportFleet, isTrue, reason: path);
      expect(decodeImport(state)['predeck']['f1']['s1']['asw'], 66);
    }
  });

  test(
    'bulk land-base actions preserve repeated values and standby in export',
    () {
      final reducer = GameStateReducer();
      var state = auditState().copyWith(
        landBases: [
          for (var id = 1; id <= 3; id++)
            LandBaseState(
              areaId: 48,
              baseId: id,
              name: 'base$id',
              actionKind: 1,
            ),
        ],
      );
      for (final actions in ['2,2,2', '0,0,0', '2,0,1']) {
        state = reducer.reduce(
          state,
          kcsapiEvent(
            '/kcsapi/api_req_air_corps/set_action',
            null,
            includeApiData: false,
            requestParams: {
              'api_area_id': '48',
              'api_base_id': '1,2,3',
              'api_action_kind': actions,
            },
          ),
        );
        final expected = actions.split(',').map(int.parse).toList();
        expect(state.landBases.map((base) => base.actionKind), expected);
        final predeck = decodeImport(state)['predeck'];
        expect([
          for (var id = 1; id <= 3; id++) predeck['a$id']['mode'],
        ], expected);
      }
    },
  );

  test('current fleet carries displayed ASW for modernization recovery', () {
    expect(decodeImport(auditState())['predeck']['f1']['s1']['asw'], 76);
  });

  test('equipment recovery and item exchange update inventory immediately', () {
    final reducer = GameStateReducer();
    var state = reducer.reduce(
      auditState(),
      kcsapiEvent('/kcsapi/api_req_kousyou/remodel_slot_recover', {
        'api_after_slot': {
          'api_id': 501,
          'api_slotitem_id': 86,
          'api_level': 9,
        },
      }),
    );
    expect(state.slotItems[501]!.level, 9);
    state = reducer.reduce(
      state,
      kcsapiEvent('/kcsapi/api_req_member/itemuse', {
        'api_getitem': [
          {
            'api_slotitem': {
              'api_id': 504,
              'api_slotitem_id': 87,
              'api_level': 0,
            },
          },
          {'api_useitem_id': 1},
        ],
      }),
    );
    expect(state.slotItems[504]!.masterSlotItemId, 87);
    expect(state.slotItems.length, 4);
  });

  test('switching member clears personal assets and keeps master data', () {
    final reducer = GameStateReducer();
    final old = auditState().copyWith(
      memberId: 1,
      masterMapAreas: {1: 'world'},
    );
    for (final directPort in [false, true]) {
      var state = reducer.reduce(
        old,
        kcsapiEvent(
          directPort ? '/kcsapi/api_port/port' : '/kcsapi/api_get_member/basic',
          directPort
              ? {
                  'api_basic': {'api_member_id': 2},
                }
              : {'api_member_id': 2},
        ),
      );
      expect(state.slotItems, isEmpty);
      expect(state.landBases, isEmpty);
      expect(state.ships, isEmpty);
      expect(state.masterMapAreas, {1: 'world'});
      expect(state.hasPortData, directPort);
      expect(state.canExportFleet, isFalse);
      state = reducer.reduce(
        state,
        kcsapiEvent('/kcsapi/api_get_member/require_info', {
          'api_slot_item': [],
        }),
      );
      expect(state.slotItems, isEmpty);
      expect(state.hasEquipmentInventory, isTrue);
      expect(state.canExportFleet, directPort);
    }
  });

  test(
    'login inventory before identity is retained only in the new session',
    () {
      final reducer = GameStateReducer();
      var state = reducer.reduce(
        auditState().copyWith(memberId: 1),
        kcsapiEvent('/kcsapi/api_start2/getData', {}),
      );
      expect(state.memberId, 0);
      expect(state.hasEquipmentInventory, isFalse);
      expect(state.canExportFleet, isFalse);
      state = reducer.reduce(
        state,
        kcsapiEvent('/kcsapi/api_get_member/require_info', {
          'api_slot_item': [
            {'api_id': 1, 'api_slotitem_id': 2},
          ],
        }),
      );
      expect(state.canExportFleet, isFalse);
      state = reducer.reduce(
        state,
        kcsapiEvent('/kcsapi/api_get_member/basic', {'api_member_id': 2}),
      );
      state = reducer.reduce(
        state,
        kcsapiEvent('/kcsapi/api_port/port', {
          'api_basic': {'api_member_id': 2},
        }),
      );
      expect(state.canExportFleet, isTrue);
      expect(state.slotItems.keys, [1]);
      final cached = GameStateSerializer.deserialize(
        GameStateSerializer.serialize(state),
      );
      expect(cached.hasEquipmentInventory, isFalse);
    },
  );

  test('partial refresh preserves ship status beyond the exported fields', () {
    final reducer = GameStateReducer();
    var state = reducer.reduce(
      auditState(),
      kcsapiEvent('/kcsapi/api_get_member/ship3', {
        'api_ship_data': [
          {
            'api_id': 7,
            'api_ship_id': 187,
            'api_cond': 65,
            'api_fuel': 80,
            'api_bull': 70,
            'api_karyoku': [50, 90],
            'api_raisou': [20, 60],
            'api_taiku': [30, 70],
            'api_taisen': [40, 80],
            'api_sakuteki': [45, 70],
            'api_soukou': [60, 90],
            'api_kaihi': [55, 80],
            'api_soku': 10,
            'api_leng': 2,
            'api_ndock_time': 20000,
            'api_ndock_item': [10, 0, 15],
            'api_locked': 1,
          },
        ],
      }),
    );
    state = reducer.reduce(
      state,
      kcsapiEvent('/kcsapi/api_get_member/ship3', {
        'api_ship_data': [
          {'api_id': 7, 'api_ship_id': 187, 'api_lv': 134},
        ],
      }),
    );
    final ship = state.ships[7]!;
    expect([ship.condition, ship.currentFuel, ship.currentAmmo], [65, 80, 70]);
    expect(
      [
        ship.firepower,
        ship.firepowerMax,
        ship.torpedo,
        ship.torpedoMax,
        ship.antiAir,
        ship.antiAirMax,
        ship.antiSub,
        ship.lineOfSight,
        ship.armor,
        ship.armorMax,
        ship.evasion,
        ship.speed,
        ship.range,
      ],
      [50, 90, 20, 60, 30, 70, 40, 45, 60, 90, 55, 10, 2],
    );
    expect(ship.locked, true);
    expect(
      [
        ship.repairDurationMilliseconds,
        ship.repairFuelCost,
        ship.repairSteelCost,
      ],
      [20000, 10, 15],
    );
    final cleared = reducer
        .reduce(
          state,
          kcsapiEvent('/kcsapi/api_get_member/ship3', {
            'api_ship_data': [
              {
                'api_id': 7,
                'api_ship_id': 187,
                'api_fuel': 0,
                'api_karyoku': [0, 0],
                'api_locked': 0,
                'api_ndock_item': [],
                'api_ndock_time': 0,
              },
            ],
          }),
        )
        .ships[7]!;
    expect(
      [
        cleared.currentFuel,
        cleared.firepower,
        cleared.firepowerMax,
        cleared.repairDurationMilliseconds,
        cleared.repairFuelCost,
        cleared.repairSteelCost,
      ],
      [0, 0, 0, 0, 0, 0],
    );
    expect(cleared.locked, false);
  });
  test(
    'malformed negative slot count does not reject an entire ship refresh',
    () {
      final state = GameStateReducer().reduce(
        auditState(),
        kcsapiEvent('/kcsapi/api_get_member/ship3', {
          'api_ship_data': [
            {
              'api_id': 7,
              'api_ship_id': 187,
              'api_lv': 134,
              'api_slotnum': -1,
              'api_onslot_max': [20, 0, 15],
            },
          ],
        }),
      );
      expect(state.ships[7]!.level, 134);
      expect(state.ships[7]!.maxSlotCounts, isEmpty);
    },
  );

  test(
    'full capture exports sparse slots, metadata, duplicates and zero aircraft without loss',
    () {
      final state = auditState();
      final data = decodeImport(state);
      final stocks = data['ships'] as List;
      expect(stocks.map((s) => s['id']), [7, 8]);
      expect(stocks.first['ship_id'], stocks.last['ship_id']);
      expect(stocks.first['st'], [20, 0, 30, 15, 12, 2, 6]);
      expect(stocks.first['slots'], [20, 0, 15]);
      expect(stocks.first['sp'], [1]);
      expect(stocks.first['area'], 3);
      expect(stocks.first['ex'], 1);
      expect(stocks.last['ex'], 0);
      expect(data['items'], [
        {'id': 86, 'lv': 7},
        {'id': 86, 'lv': 3},
        {'id': 86, 'lv': 3},
      ]);
      final deck = data['predeck'] as Map;
      expect(deck['f1']['name'], 'A & B # + % / 日本');
      expect(deck['f1']['t'], 2);
      final ship = deck['f1']['s1'];
      expect(ship['exa'], true);
      expect(deck['f1']['s2']['exa'], false);
      expect(ship['spi'], [
        {'kind': 1},
      ]);
      expect(ship['items'], {
        'i1': {'id': 86, 'rf': 7, 'mas': 7, 'ac': 18},
        'i3': {'id': 86, 'rf': 3, 'mas': 2, 'ac': 0},
      });
      expect(deck['a1']['items'], {
        'i3': {'id': 86, 'rf': 3, 'mas': 2, 'ac': 0},
      });
      final restored = GameStateSerializer.deserialize(
        GameStateSerializer.serialize(state),
      );
      expect(decodeImport(restored)['ships'], stocks);
      expect(
        restored.hasPortData,
        false,
      ); // Partial display cache must not enable export.
      if (Platform.environment['NORO6_AUDIT_PAYLOAD'] case final String path) {
        File(path).writeAsStringSync(jsonEncode(data));
      }
    },
  );
  test(
    'partial ship refresh preserves export fields while explicit reset clears them',
    () {
      final reducer = GameStateReducer();
      final initial = auditState();
      var state = reducer.reduce(
        initial,
        kcsapiEvent('/kcsapi/api_get_member/ship3', {
          'api_ship_data': [
            {'api_id': 7, 'api_ship_id': 187, 'api_lv': 134},
          ],
        }),
      );
      final stock = (decodeImport(state)['ships'] as List).first;
      expect(stock['lv'], 134);
      expect(stock['slots'], [20, 0, 15]);
      expect(stock['st'], [20, 0, 30, 15, 12, 2, 6]);
      expect(stock['area'], 3);
      expect(stock['sp'], [1]);
      expect(decodeImport(state)['predeck']['f1']['s1']['hp'], 96);
      expect(state.ships[7]!.slotIds, [501, -1, 502]);
      state = reducer.reduce(
        state,
        kcsapiEvent('/kcsapi/api_get_member/ship3', {
          'api_ship_data': [
            {
              'api_id': 7,
              'api_ship_id': 187,
              'api_sally_area': 0,
              'api_sp_effect_items': [],
              'api_slot_ex': 0,
              'api_slot': [-1, -1, -1],
            },
          ],
        }),
      );
      final reset = (decodeImport(state)['ships'] as List).first;
      expect(reset['area'], 0);
      expect(reset['sp'], isNull);
      expect(reset['ex'], 0);
      expect(state.ships[7]!.slotIds, [-1, -1, -1]);
    },
  );

  test(
    'equipment modernization updates stock and consumes materials even on failure',
    () {
      final reducer = GameStateReducer();
      var state = auditState();
      state = reducer.reduce(
        state,
        kcsapiEvent('/kcsapi/api_req_kousyou/remodel_slot', {
          'api_remodel_flag': 1,
          'api_use_slot_id': [503],
          'api_after_slot': {
            'api_id': 501,
            'api_slotitem_id': 86,
            'api_level': 8,
            'api_alv': 7,
          },
        }),
      );
      expect(state.slotItems.keys, [501, 502]);
      expect(state.slotItems[501]!.level, 8);
      expect(
        decodeImport(state)['predeck']['f1']['s1']['items']['i1']['rf'],
        8,
      );
      state = reducer.reduce(
        state,
        kcsapiEvent('/kcsapi/api_req_kousyou/remodel_slot', {
          'api_remodel_flag': 0,
          'api_use_slot_id': [502],
        }),
      );
      expect(state.slotItems.keys, [501]);
      expect(state.slotItems[501]!.level, 8);
    },
  );
  test('expansion and hangar responses update exports immediately', () {
    final reducer = GameStateReducer();
    var state = auditState();
    state = reducer.reduce(
      state,
      kcsapiEvent(
        '/kcsapi/api_req_kaisou/open_exslot',
        null,
        includeApiData: false,
        requestParams: {'api_id': '8'},
      ),
    );
    expect(decodeImport(state)['predeck']['f1']['s2']['exa'], true);
    state = reducer.reduce(
      state,
      kcsapiEvent(
        '/kcsapi/api_req_kaisou/hangar_expand',
        {
          'api_onslot_max': [21, 0, 15],
        },
        requestParams: {'api_ship_id': '7'},
      ),
    );
    expect((decodeImport(state)['ships'] as List).first['slots'], [21, 0, 15]);
    expect(state.ships[7]!.slotIds, [501, -1, 502]);
  });
  test('marriage response refreshes level, maximum HP and luck', () {
    final state = GameStateReducer().reduce(
      auditState(),
      kcsapiEvent('/kcsapi/api_req_kaisou/marriage', {
        'api_id': 8,
        'api_ship_id': 187,
        'api_lv': 100,
        'api_maxhp': 94,
        'api_lucky': [21, 99],
        'api_kyouka': [0, 0, 0, 0, 3, 0, 0],
      }),
    );
    final ship = decodeImport(state)['predeck']['f1']['s2'];
    expect(ship['lv'], 100);
    expect(ship['hp'], 94);
    expect(ship['luck'], 21);
  });
}
