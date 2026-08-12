import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_models.dart';
import 'package:yahagi_kancolle_browser/src/battle/prediction/yahagi_battle_prediction_engine.dart';

BattleShipSnapshot ship({
  required BattleSide side,
  required int position,
  required int hp,
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
);

void main() {
  test('night packet continues daytime HP and refreshes rank', () {
    final engine = YahagiBattlePredictionEngine(
      friendMain: <BattleShipSnapshot>[
        ship(side: BattleSide.friend, position: 0, hp: 30),
        ship(side: BattleSide.friend, position: 1, hp: 15),
      ],
      enemyMain: <BattleShipSnapshot>[
        ship(side: BattleSide.enemy, position: 0, hp: 20),
      ],
    );

    final day = engine.append(
      path: '/kcsapi/api_req_sortie/battle',
      data: const <String, Object?>{},
    );
    expect(day.rank, BattleRank.d);

    final night = engine.append(
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

    expect(night.enemyMain.single.currentHp, 0);
    expect(night.rank, BattleRank.ss);
    expect(night.issues, isEmpty);
  });

  test('land-base main and combined damage use their explicit fleets', () {
    final engine = YahagiBattlePredictionEngine(
      friendMain: <BattleShipSnapshot>[
        ship(side: BattleSide.friend, position: 0, hp: 30),
      ],
      enemyMain: <BattleShipSnapshot>[
        ship(side: BattleSide.enemy, position: 0, hp: 100),
      ],
      enemyEscort: <BattleShipSnapshot>[
        ship(
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
}
