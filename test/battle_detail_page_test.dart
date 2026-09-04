import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_detail_models.dart';
import 'package:yahagi_kancolle_browser/src/logbook/battle_detail_page.dart';

void main() {
  const sizes = <Size>[
    Size(915, 412),
    Size(914, 836),
    Size(1280, 800),
    Size(800, 1280),
  ];

  for (final size in sizes) {
    testWidgets('battle detail fits ${size.width}x${size.height}', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('battle-detail-page')), findsOneWidget);
      expect(find.text('舰队'), findsOneWidget);
      expect(find.text('战斗过程'), findsOneWidget);
      expect(find.text('第一舰队 · 主力'), findsOneWidget);
      expect(find.text('第二舰队 · 随伴'), findsOneWidget);
      expect(find.text('敌方主力'), findsOneWidget);
      expect(find.text('敌方随伴'), findsOneWidget);
      expect(find.text('结算'), findsNothing);
      expect(find.text('原始数据'), findsNothing);
      expect(find.byKey(const Key('battle-stage-sidebar')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'process shows both attack directions and filters enemy attacks',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(914, 836));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app());

      await tester.tap(find.byKey(const Key('battle-detail-tab-process')));
      await tester.pumpAndSettle();

      expect(find.text('第一炮击战'), findsOneWidget);
      expect(find.text('主炮连击'), findsOneWidget);
      expect(find.text('夜战攻击'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward_rounded), findsWidgets);
      expect(find.byIcon(Icons.arrow_back_rounded), findsWidgets);
      expect(find.text('40'), findsOneWidget);
      expect(find.text('20'), findsOneWidget);

      await tester.tap(find.byKey(const Key('battle-detail-filter-enemy')));
      await tester.pumpAndSettle();

      expect(find.text('夜战攻击'), findsOneWidget);
      expect(find.text('主炮连击'), findsNothing);
      expect(find.text('45 / 60'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('back button delegates to the logbook container', (tester) async {
    var backed = false;
    await tester.pumpWidget(_app(onBack: () => backed = true));

    await tester.tap(find.byKey(const Key('battle-detail-back')));

    expect(backed, isTrue);
  });
}

Widget _app({VoidCallback? onBack}) => MaterialApp(
  theme: ThemeData.dark(useMaterial3: true),
  home: Scaffold(
    body: BattleDetailPage(detail: _detail, onBack: onBack ?? () {}),
  ),
);

const _detail = BattleDetailSnapshot(
  completedAtMillis: 1788533880000,
  mapLabel: '62-5',
  nodeLabel: 'Z点',
  rank: 'S',
  enemyFleetName: '深海联合舰队',
  fleets: <BattleDetailFleet>[
    BattleDetailFleet(
      side: BattleDetailSide.friend,
      role: BattleDetailFleetRole.main,
      ships: <BattleDetailShip>[
        BattleDetailShip(
          name: '大和改二重',
          side: BattleDetailSide.friend,
          role: BattleDetailFleetRole.main,
          position: 0,
          level: 175,
          initialHp: 100,
          maxHp: 100,
          finalHp: 100,
          damageDealt: 60,
          equipment: <BattleDetailEquipment>[
            BattleDetailEquipment(
              masterId: 1,
              name: '51cm 连装炮',
              improvement: 10,
            ),
            BattleDetailEquipment(masterId: 2, name: '水上电探'),
          ],
        ),
      ],
    ),
    BattleDetailFleet(
      side: BattleDetailSide.friend,
      role: BattleDetailFleetRole.escort,
      ships: <BattleDetailShip>[
        BattleDetailShip(
          name: '矢矧改二乙',
          side: BattleDetailSide.friend,
          role: BattleDetailFleetRole.escort,
          position: 0,
          level: 150,
          initialHp: 60,
          maxHp: 60,
          finalHp: 45,
          damageReceived: 15,
        ),
      ],
    ),
    BattleDetailFleet(
      side: BattleDetailSide.enemy,
      role: BattleDetailFleetRole.main,
      ships: <BattleDetailShip>[
        BattleDetailShip(
          name: '战舰栖姬',
          side: BattleDetailSide.enemy,
          role: BattleDetailFleetRole.main,
          position: 0,
          initialHp: 200,
          maxHp: 200,
          finalHp: 140,
          damageReceived: 60,
        ),
      ],
    ),
    BattleDetailFleet(
      side: BattleDetailSide.enemy,
      role: BattleDetailFleetRole.escort,
      ships: <BattleDetailShip>[
        BattleDetailShip(
          name: '重巡ネ级',
          side: BattleDetailSide.enemy,
          role: BattleDetailFleetRole.escort,
          position: 0,
          initialHp: 80,
          maxHp: 80,
          finalHp: 80,
          damageDealt: 15,
        ),
      ],
    ),
  ],
  stages: <BattleDetailStage>[
    BattleDetailStage(
      keyName: 'api_hougeki1',
      title: '第一炮击战',
      attacks: <BattleDetailAttack>[
        BattleDetailAttack(
          attackerSide: BattleDetailSide.friend,
          attackerRole: BattleDetailFleetRole.main,
          attackerPosition: 0,
          attackerName: '大和改二重',
          defenderSide: BattleDetailSide.enemy,
          defenderRole: BattleDetailFleetRole.main,
          defenderPosition: 0,
          defenderName: '战舰栖姬',
          attackType: '主炮连击',
          defenderHpBefore: 200,
          defenderHpAfter: 140,
          hits: <BattleDetailHit>[
            BattleDetailHit(
              damage: 40,
              kind: BattleDetailHitKind.hit,
              hpAfter: 160,
            ),
            BattleDetailHit(
              damage: 20,
              kind: BattleDetailHitKind.critical,
              hpAfter: 140,
            ),
          ],
        ),
        BattleDetailAttack(
          attackerSide: BattleDetailSide.enemy,
          attackerRole: BattleDetailFleetRole.escort,
          attackerPosition: 0,
          attackerName: '重巡ネ级',
          defenderSide: BattleDetailSide.friend,
          defenderRole: BattleDetailFleetRole.escort,
          defenderPosition: 0,
          defenderName: '矢矧改二乙',
          attackType: '夜战攻击',
          defenderHpBefore: 60,
          defenderHpAfter: 45,
          hits: <BattleDetailHit>[
            BattleDetailHit(
              damage: 15,
              kind: BattleDetailHitKind.critical,
              hpAfter: 45,
            ),
          ],
        ),
      ],
    ),
  ],
);
