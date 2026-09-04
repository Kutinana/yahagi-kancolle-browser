import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_detail_models.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_detail_replay_builder.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_models.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_session.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';

void main() {
  test(
    'replay keeps multi-hit HP and enemy attack against friendly escort',
    () {
      final friendMain = <BattleShipSnapshot>[
        ship('大和改二重', BattleSide.friend, BattleFleetRole.main, hp: 100),
      ];
      final friendEscort = <BattleShipSnapshot>[
        ship('矢矧改二乙', BattleSide.friend, BattleFleetRole.escort, hp: 60),
      ];
      final enemyMain = <BattleShipSnapshot>[
        ship('战舰栖姬', BattleSide.enemy, BattleFleetRole.main, hp: 200),
      ];
      final enemyEscort = <BattleShipSnapshot>[
        ship('重巡ネ级', BattleSide.enemy, BattleFleetRole.escort, hp: 80),
      ];
      final session =
          BattleSession(
            id: 'battle-1',
            context: const BattleContext(
              mapAreaId: 62,
              mapInfoNo: 5,
              node: 48,
              combinedFleetType: CombinedFleetType.surfaceTaskForce,
            ),
            startedAt: DateTime.fromMillisecondsSinceEpoch(1000),
            friendMain: friendMain,
            friendEscort: friendEscort,
            enemyMain: enemyMain,
            enemyEscort: enemyEscort,
          )..appendPacket(
            path: '/kcsapi/api_req_combined_battle/each_battle',
            sequence: 1,
            capturedAt: DateTime.fromMillisecondsSinceEpoch(1100),
            data: <String, Object?>{
              'api_hougeki1': <String, Object?>{
                'api_at_eflag': <int>[0, 1],
                'api_at_list': <int>[0, 6],
                'api_df_list': <Object?>[
                  <int>[0, 0],
                  <int>[6],
                ],
                'api_damage': <Object?>[
                  <num>[40.9, 20.8],
                  <num>[15.9],
                ],
                'api_cl_list': <Object?>[
                  <int>[1, 2],
                  <int>[2],
                ],
                'api_at_type': <int>[2, 0],
              },
            },
          );
      final battle = LiveBattle(
        context: session.context,
        friendMain: friendMain,
        friendEscort: friendEscort,
        enemyMain: enemyMain,
        enemyEscort: enemyEscort,
        rank: BattleRank.s,
        enemyFleetName: '深海联合舰队',
      );

      final detail = const BattleDetailReplayBuilder().build(
        session: session,
        battle: battle,
        completedAt: DateTime.fromMillisecondsSinceEpoch(2000),
        gameState: GameState.empty,
      );

      expect(detail.fleets, hasLength(4));
      final stage = detail.stages.single;
      expect(stage.title, '第一炮击战');
      expect(stage.attacks, hasLength(2));

      final ours = stage.attacks.first;
      expect(ours.attackerName, '大和改二重');
      expect(ours.defenderName, '战舰栖姬');
      expect(ours.hits.map((hit) => hit.damage), <int>[40, 20]);
      expect(ours.hits.map((hit) => hit.hpAfter), <int>[160, 140]);
      expect(ours.hits.last.kind, BattleDetailHitKind.critical);

      final enemy = stage.attacks.last;
      expect(enemy.attackerSide, BattleDetailSide.enemy);
      expect(enemy.attackerRole, BattleDetailFleetRole.escort);
      expect(enemy.attackerName, '重巡ネ级');
      expect(enemy.defenderRole, BattleDetailFleetRole.escort);
      expect(enemy.defenderName, '矢矧改二乙');
      expect(enemy.defenderHpBefore, 60);
      expect(enemy.defenderHpAfter, 45);
    },
  );

  test('replay records a miss without reducing HP', () {
    final friend = <BattleShipSnapshot>[
      ship('雪风改二', BattleSide.friend, BattleFleetRole.main, hp: 35),
    ];
    final enemy = <BattleShipSnapshot>[
      ship('驱逐イ级', BattleSide.enemy, BattleFleetRole.main, hp: 20),
    ];
    final session =
        BattleSession(
          id: 'battle-2',
          context: const BattleContext(mapAreaId: 1, mapInfoNo: 1, node: 1),
          startedAt: DateTime.fromMillisecondsSinceEpoch(1000),
          friendMain: friend,
          enemyMain: enemy,
        )..appendPacket(
          path: '/kcsapi/api_req_sortie/battle',
          sequence: 1,
          capturedAt: DateTime.fromMillisecondsSinceEpoch(1100),
          data: <String, Object?>{
            'api_hougeki1': <String, Object?>{
              'api_at_eflag': <int>[0],
              'api_at_list': <int>[0],
              'api_df_list': <Object?>[
                <int>[0],
              ],
              'api_damage': <Object?>[
                <num>[0],
              ],
              'api_cl_list': <Object?>[
                <int>[0],
              ],
            },
          },
        );

    final detail = const BattleDetailReplayBuilder().build(
      session: session,
      battle: LiveBattle(
        context: session.context,
        friendMain: friend,
        enemyMain: enemy,
      ),
      completedAt: DateTime.fromMillisecondsSinceEpoch(2000),
      gameState: GameState.empty,
    );

    final attack = detail.stages.single.attacks.single;
    expect(attack.hits.single.kind, BattleDetailHitKind.miss);
    expect(attack.defenderHpBefore, 20);
    expect(attack.defenderHpAfter, 20);
  });
}

BattleShipSnapshot ship(
  String name,
  BattleSide side,
  BattleFleetRole role, {
  required int hp,
}) => BattleShipSnapshot(
  masterId: name.hashCode,
  name: name,
  side: side,
  fleetRole: role,
  position: 0,
  initialHp: hp,
  maxHp: hp,
  currentHp: hp,
);
