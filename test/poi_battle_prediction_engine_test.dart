import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_models.dart';
import 'package:yahagi_kancolle_browser/src/battle/prediction/poi/poi_battle_prediction_engine.dart';

BattleShipSnapshot poiShip({
  required BattleSide side,
  required int position,
  required int hp,
  List<int> equipment = const <int>[],
  BattleFleetRole fleetRole = BattleFleetRole.main,
}) => BattleShipSnapshot(
  masterId: 100 + position,
  name: '$side-$position',
  side: side,
  fleetRole: fleetRole,
  position: position,
  initialHp: hp,
  maxHp: hp,
  currentHp: hp,
  equipmentMasterIds: equipment,
);

void main() {
  test('POI engine independently continues day state into night', () {
    final engine = PoiBattlePredictionEngine(
      friendMain: <BattleShipSnapshot>[
        poiShip(side: BattleSide.friend, position: 0, hp: 30),
        poiShip(side: BattleSide.friend, position: 1, hp: 15),
      ],
      enemyMain: <BattleShipSnapshot>[
        poiShip(side: BattleSide.enemy, position: 0, hp: 20),
      ],
    );

    expect(
      engine
          .append(
            path: '/kcsapi/api_req_sortie/battle',
            data: const <String, Object?>{},
          )
          .rank,
      BattleRank.d,
    );

    final result = engine.append(
      path: '/kcsapi/api_req_battle_midnight/battle',
      data: <String, Object?>{
        'api_hougeki': <String, Object?>{
          'api_at_eflag': <int>[0],
          'api_at_list': <int>[0],
          'api_df_list': <Object?>[
            <int>[0],
          ],
          'api_damage': <Object?>[
            <num>[20],
          ],
        },
      },
    );

    expect(result.enemyMain.single.currentHp, 0);
    expect(result.rank, BattleRank.ss);
  });

  test('POI engine consumes damage control only once', () {
    final engine = PoiBattlePredictionEngine(
      friendMain: <BattleShipSnapshot>[
        poiShip(
          side: BattleSide.friend,
          position: 0,
          hp: 30,
          equipment: const <int>[42],
        ),
      ],
      enemyMain: <BattleShipSnapshot>[
        poiShip(side: BattleSide.enemy, position: 0, hp: 30),
      ],
    );

    final first = engine.append(
      path: '/kcsapi/api_req_battle_midnight/battle',
      data: _enemyNightDamage(30),
    );
    expect(first.friendMain.single.currentHp, 6);

    final second = engine.append(
      path: '/kcsapi/api_req_battle_midnight/battle',
      data: _enemyNightDamage(6),
    );
    expect(second.friendMain.single.currentHp, 0);
  });

  test(
    'POI engine aggregates ordinary multi-hit damage before damage control',
    () {
      final engine = PoiBattlePredictionEngine(
        friendMain: <BattleShipSnapshot>[
          poiShip(
            side: BattleSide.friend,
            position: 0,
            hp: 30,
            equipment: const <int>[42],
          ),
        ],
        enemyMain: <BattleShipSnapshot>[
          poiShip(side: BattleSide.enemy, position: 0, hp: 30),
        ],
      );

      final result = engine.append(
        path: '/kcsapi/api_req_battle_midnight/battle',
        data: <String, Object?>{
          'api_hougeki': <String, Object?>{
            'api_at_eflag': <int>[1],
            'api_at_list': <int>[0],
            'api_sp_list': <int>[3],
            'api_df_list': <Object?>[
              <int>[0, 0],
            ],
            'api_damage': <Object?>[
              <num>[30, 1],
            ],
          },
        },
      );

      expect(result.friendMain.single.currentHp, 6);
      expect(result.friendMain.single.usedDamageControlItemIds, <int>[42]);
    },
  );

  test('POI engine attributes multi-ship special attack damage per hit', () {
    final engine = PoiBattlePredictionEngine(
      friendMain: <BattleShipSnapshot>[
        for (var position = 0; position < 6; position++)
          poiShip(side: BattleSide.friend, position: position, hp: 30),
      ],
      enemyMain: <BattleShipSnapshot>[
        for (var position = 0; position < 3; position++)
          poiShip(side: BattleSide.enemy, position: position, hp: 100),
      ],
    );

    final result = engine.append(
      path: '/kcsapi/api_req_sortie/battle',
      data: <String, Object?>{
        'api_hougeki1': <String, Object?>{
          'api_at_eflag': <int>[0],
          'api_at_list': <int>[0],
          'api_at_type': <int>[100],
          'api_df_list': <Object?>[
            <int>[0, 1, 2],
          ],
          'api_damage': <Object?>[
            <num>[10, 20, 30],
          ],
        },
      },
    );

    expect(result.friendMain.map((ship) => ship.damageDealt), <int>[
      10,
      0,
      20,
      0,
      30,
      0,
    ]);
  });

  test('POI engine exposes combined night-only MVP semantics', () {
    final engine = PoiBattlePredictionEngine(
      friendMain: <BattleShipSnapshot>[
        for (var position = 0; position < 6; position++)
          poiShip(side: BattleSide.friend, position: position, hp: 30),
      ],
      friendEscort: <BattleShipSnapshot>[
        for (var position = 0; position < 6; position++)
          poiShip(
            side: BattleSide.friend,
            position: position,
            hp: 30,
            fleetRole: BattleFleetRole.escort,
          ),
      ],
      enemyMain: <BattleShipSnapshot>[
        poiShip(side: BattleSide.enemy, position: 0, hp: 100),
      ],
    );

    final result = engine.append(
      path: '/kcsapi/api_req_combined_battle/midnight_battle',
      data: <String, Object?>{
        'api_active_deck': <int>[2, 1],
        'api_hougeki': <String, Object?>{
          'api_at_eflag': <int>[0],
          'api_at_list': <int>[2],
          'api_sp_list': <int>[0],
          'api_df_list': <Object?>[
            <int>[0],
          ],
          'api_damage': <Object?>[
            <num>[40],
          ],
        },
      },
    );

    expect(result.mvpPositions, <int>[0, 8]);
  });

  test('POI engine maps land-base main and combined damage independently', () {
    final engine = PoiBattlePredictionEngine(
      friendMain: <BattleShipSnapshot>[
        poiShip(side: BattleSide.friend, position: 0, hp: 30),
      ],
      enemyMain: <BattleShipSnapshot>[
        poiShip(side: BattleSide.enemy, position: 0, hp: 100),
      ],
      enemyEscort: <BattleShipSnapshot>[
        poiShip(
          side: BattleSide.enemy,
          position: 0,
          hp: 100,
          fleetRole: BattleFleetRole.escort,
        ),
      ],
    );

    final result = engine.append(
      path: '/kcsapi/api_req_combined_battle/battle',
      data: <String, Object?>{
        'api_active_deck': <int>[1, 2],
        'api_air_base_attack': <Object?>[
          <String, Object?>{
            'api_stage3': <String, Object?>{
              'api_edam': <num>[-1, 40.9],
            },
            'api_stage3_combined': <String, Object?>{
              'api_edam': <num>[-1, 20.9],
            },
          },
        ],
      },
    );

    expect(result.enemyMain.single.currentHp, 60);
    expect(result.enemyEscort.single.currentHp, 80);
    expect(result.issues, isEmpty);
  });

  test(
    'POI engine uses seven-ship boundary when attacker flags are absent',
    () {
      final engine = PoiBattlePredictionEngine(
        friendMain: <BattleShipSnapshot>[
          for (var position = 0; position < 7; position++)
            poiShip(side: BattleSide.friend, position: position, hp: 30),
        ],
        enemyMain: <BattleShipSnapshot>[
          poiShip(side: BattleSide.enemy, position: 0, hp: 30),
          poiShip(side: BattleSide.enemy, position: 1, hp: 30),
        ],
      );

      final result = engine.append(
        path: '/kcsapi/api_req_sortie/battle',
        data: <String, Object?>{
          'api_hougeki1': <String, Object?>{
            'api_at_list': <int>[0],
            'api_df_list': <Object?>[
              <int>[7],
            ],
            'api_damage': <Object?>[
              <num>[11],
            ],
          },
        },
      );

      expect(result.enemyMain.map((ship) => ship.currentHp), <int>[19, 30]);
      expect(result.friendMain.every((ship) => ship.currentHp == 30), isTrue);
      expect(result.issues, isEmpty);
    },
  );

  test('POI engine keeps NPC friendly aerial damage off the player fleet', () {
    final engine = PoiBattlePredictionEngine(
      friendMain: <BattleShipSnapshot>[
        poiShip(side: BattleSide.friend, position: 0, hp: 30),
      ],
      enemyMain: <BattleShipSnapshot>[
        poiShip(side: BattleSide.enemy, position: 0, hp: 50),
      ],
    );

    final result = engine.append(
      path: '/kcsapi/api_req_combined_battle/ec_battle',
      data: <String, Object?>{
        'api_friendly_info': <String, Object?>{
          'api_ship_id': <int>[1001],
          'api_ship_lv': <int>[90],
          'api_nowhps': <int>[40],
          'api_maxhps': <int>[40],
          'api_Slot': <Object?>[<int>[]],
          'api_Param': <Object?>[
            <int>[0, 0, 0, 0],
          ],
        },
        'api_friendly_kouku': <String, Object?>{
          'api_stage3': <String, Object?>{
            'api_edam': <num>[12],
            'api_ebak_flag': <int>[1],
            'api_erai_flag': <int>[0],
            'api_ecl_flag': <int>[1],
            'api_fdam': <num>[9],
            'api_fbak_flag': <int>[1],
            'api_frai_flag': <int>[0],
            'api_fcl_flag': <int>[1],
          },
        },
      },
    );

    expect(result.friendMain.single.currentHp, 30);
    expect(result.enemyMain.single.currentHp, 38);
    expect(result.issues, isEmpty);
  });

  test('POI engine replays immutable copies of every captured packet', () {
    final engine = PoiBattlePredictionEngine(
      friendMain: <BattleShipSnapshot>[
        poiShip(side: BattleSide.friend, position: 0, hp: 30),
      ],
      enemyMain: <BattleShipSnapshot>[
        poiShip(side: BattleSide.enemy, position: 0, hp: 50),
      ],
    );
    final firstPacket = <String, Object?>{
      'api_hougeki1': <String, Object?>{
        'api_at_eflag': <int>[0],
        'api_at_list': <int>[0],
        'api_df_list': <Object?>[
          <int>[0],
        ],
        'api_damage': <Object?>[
          <num>[10],
        ],
      },
    };

    engine.append(path: '/kcsapi/api_req_sortie/battle', data: firstPacket);
    ((firstPacket['api_hougeki1']! as Map)['api_damage']! as List)[0] = <num>[
      40,
    ];
    final result = engine.append(
      path: '/kcsapi/api_req_battle_midnight/battle',
      data: const <String, Object?>{},
    );

    expect(result.enemyMain.single.currentHp, 40);
  });

  test('POI engine ignores night-only fields on a day battle path', () {
    final engine = PoiBattlePredictionEngine(
      friendMain: <BattleShipSnapshot>[
        poiShip(side: BattleSide.friend, position: 0, hp: 30),
      ],
      enemyMain: <BattleShipSnapshot>[
        poiShip(side: BattleSide.enemy, position: 0, hp: 30),
      ],
    );

    final result = engine.append(
      path: '/kcsapi/api_req_sortie/battle',
      data: _enemyNightDamage(10),
    );

    expect(result.friendMain.single.currentHp, 30);
  });

  test('POI engine ignores day-only fields on a night battle path', () {
    final engine = PoiBattlePredictionEngine(
      friendMain: <BattleShipSnapshot>[
        poiShip(side: BattleSide.friend, position: 0, hp: 30),
      ],
      enemyMain: <BattleShipSnapshot>[
        poiShip(side: BattleSide.enemy, position: 0, hp: 30),
      ],
    );

    final result = engine.append(
      path: '/kcsapi/api_req_battle_midnight/battle',
      data: <String, Object?>{
        'api_hougeki1': <String, Object?>{
          'api_at_eflag': <int>[0],
          'api_at_list': <int>[0],
          'api_df_list': <Object?>[
            <int>[0],
          ],
          'api_damage': <Object?>[
            <num>[10],
          ],
        },
      },
    );

    expect(result.enemyMain.single.currentHp, 30);
  });

  test('POI engine follows POI phase order for carrier and surface fleets', () {
    PoiBattlePredictionEngine engine(int fleetType) =>
        PoiBattlePredictionEngine(
          fleetType: fleetType,
          friendMain: <BattleShipSnapshot>[
            poiShip(
              side: BattleSide.friend,
              position: 0,
              hp: 30,
              equipment: const <int>[42, 43],
            ),
          ],
          enemyMain: <BattleShipSnapshot>[
            poiShip(side: BattleSide.enemy, position: 0, hp: 30),
          ],
        );

    final packet = <String, Object?>{
      'api_hougeki2': <String, Object?>{
        'api_at_eflag': <int>[1],
        'api_at_list': <int>[0],
        'api_df_list': <Object?>[
          <int>[0],
        ],
        'api_damage': <Object?>[
          <num>[30],
        ],
      },
      'api_raigeki': <String, Object?>{
        'api_fdam': <num>[-1, 6],
      },
    };

    final carrier = engine(
      1,
    ).append(path: '/kcsapi/api_req_combined_battle/battle', data: packet);
    final surface = engine(2).append(
      path: '/kcsapi/api_req_combined_battle/battle_water',
      data: packet,
    );

    expect(carrier.friendMain.single.currentHp, 6);
    expect(carrier.friendMain.single.usedDamageControlItemIds, const <int>[42]);
    expect(surface.friendMain.single.currentHp, 30);
    expect(surface.friendMain.single.usedDamageControlItemIds, const <int>[
      42,
      43,
    ]);
  });
}

Map<String, Object?> _enemyNightDamage(num damage) => <String, Object?>{
  'api_hougeki': <String, Object?>{
    'api_at_eflag': <int>[1],
    'api_at_list': <int>[0],
    'api_df_list': <Object?>[
      <int>[0],
    ],
    'api_damage': <Object?>[
      <num>[damage],
    ],
  },
};
