import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_detail_models.dart';
import 'package:yahagi_kancolle_browser/src/logbook/battle_detail_page.dart';
import 'fixtures/battle_detail_ui_sample.dart';

Widget app(BattleDetailSnapshot data) => MaterialApp(
  home: BattleDetailPage(detail: data, onBack: () {}),
);

BattleDetailSnapshot report(
  BattleDetailSide target,
  int hp, {
  bool repair = false,
  bool unknown = false,
  int maxHp = 100,
}) => BattleDetailSnapshot(
  completedAtMillis: 0,
  mapLabel: '1-1',
  nodeLabel: 'C点',
  rank: 'S',
  enemyFleetName: '测试舰队',
  fleets: [
    BattleDetailFleet(
      side: target,
      role: BattleDetailFleetRole.escort,
      ships: [
        BattleDetailShip(
          name: '受击舰',
          side: target,
          role: BattleDetailFleetRole.escort,
          position: 0,
          initialHp: 100,
          maxHp: maxHp,
          finalHp: hp,
          hpUnknown: unknown,
        ),
      ],
    ),
    // Same position in main fleet must not determine escort status.
    BattleDetailFleet(
      side: target,
      role: BattleDetailFleetRole.main,
      ships: [
        BattleDetailShip(
          name: '同名舰',
          side: target,
          role: BattleDetailFleetRole.main,
          position: 0,
          initialHp: 200,
          maxHp: 200,
          finalHp: 200,
        ),
      ],
    ),
  ],
  stages: [
    BattleDetailStage(
      keyName: 'test',
      title: '炮击战',
      attacks: [
        BattleDetailAttack(
          attackerSide: target == BattleDetailSide.enemy
              ? BattleDetailSide.friend
              : BattleDetailSide.enemy,
          attackerName: '攻击舰',
          defenderSide: target,
          defenderName: '受击舰',
          defenderRole: BattleDetailFleetRole.escort,
          defenderPosition: 0,
          attackType: '炮击',
          defenderHpBefore: 100,
          defenderHpAfter: hp,
          damageControlName: repair ? '应急修理女神' : null,
          hits: [
            BattleDetailHit(
              damage: repair ? 120 : 100 - hp,
              kind: BattleDetailHitKind.hit,
              hpAfter: hp,
            ),
          ],
        ),
      ],
    ),
  ],
);

void main() {
  testWidgets('target HP includes this attack damage', (tester) async {
    await tester.pumpWidget(app(sampleBattle(true)));
    await tester.tap(find.byKey(const Key('battle-detail-tab-process')));
    await tester.pumpAndSettle();
    expect(find.text('目标HP 120 → 96（-24）'), findsOneWidget);
  });
  testWidgets('reports hide attack type and hit count but preserve results', (
    tester,
  ) async {
    final data = sampleBattle(true);
    final attack = data.stages
        .expand((s) => s.attacks)
        .firstWhere((a) => a.hits.length == 2);
    await tester.pumpWidget(
      app(
        BattleDetailSnapshot(
          completedAtMillis: data.completedAtMillis,
          mapLabel: data.mapLabel,
          nodeLabel: data.nodeLabel,
          rank: data.rank,
          enemyFleetName: data.enemyFleetName,
          fleets: data.fleets,
          stages: [
            BattleDetailStage(
              keyName: 'test',
              title: '第一炮击战',
              attacks: [attack],
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('battle-detail-tab-process')));
    await tester.pumpAndSettle();
    expect(find.text(attack.attackType), findsNothing);
    expect(find.text('2段'), findsNothing);
    expect(find.text('第一炮击战'), findsOneWidget);
    expect(find.text('造成 120 伤害'), findsOneWidget);
    expect(find.text('敌方大破'), findsOneWidget);
    expect(find.text('目标HP 160 → 40（-120）'), findsOneWidget);
  });
  testWidgets('fleet equipment is not displayed', (tester) async {
    await tester.pumpWidget(app(sampleBattle(false)));
    expect(find.text('15.5cm三连装副炮'), findsNothing);
    expect(find.text('甲标的 丙型 ★4'), findsNothing);
    expect(find.text('造成 371'), findsOneWidget);
  });
  testWidgets('reports have no expandable details and use target HP', (
    tester,
  ) async {
    await tester.pumpWidget(app(sampleBattle(false)));
    await tester.tap(find.byKey(const Key('battle-detail-tab-process')));
    await tester.pumpAndSettle();
    expect(find.text('目标HP 33 → 0（-67）'), findsOneWidget);
    expect(find.textContaining('点击战报看明细'), findsNothing);
    final row = find.byKey(const Key('attack-1'));
    expect(
      find.descendant(of: row, matching: find.byType(InkWell)),
      findsNothing,
    );
    expect(
      find.descendant(of: row, matching: find.byIcon(Icons.expand_more)),
      findsNothing,
    );
    expect(find.text('第 1 段'), findsNothing);
    expect(
      find.ancestor(of: find.text('造成 67 伤害'), matching: find.byType(Tag)),
      findsOneWidget,
    );
  });
  for (final side in [BattleDetailSide.friend, BattleDetailSide.enemy]) {
    for (final entry in {
      76: null,
      75: '小破',
      51: '小破',
      50: '中破',
      26: '中破',
      25: '大破',
      1: '大破',
      0: '击沉',
    }.entries) {
      testWidgets('target state $side HP=${entry.key}', (tester) async {
        await tester.pumpWidget(app(report(side, entry.key)));
        await tester.tap(find.byKey(const Key('battle-detail-tab-process')));
        await tester.pumpAndSettle();
        final prefix = side == BattleDetailSide.friend ? '我方' : '敌方';
        for (final status in ['小破', '中破', '大破', '击沉']) {
          expect(
            find.text('$prefix$status'),
            status == entry.value ? findsOneWidget : findsNothing,
          );
        }
      });
    }
  }
  testWidgets('damage control reports restored HP, not sinking', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(report(BattleDetailSide.friend, 100, repair: true)),
    );
    await tester.tap(find.byKey(const Key('battle-detail-tab-process')));
    await tester.pumpAndSettle();
    expect(find.text('损管发动'), findsOneWidget);
    expect(find.text('目标HP 100 → 100（-120）'), findsOneWidget);
    expect(find.text('我方击沉'), findsNothing);
    expect(find.text('我方大破'), findsNothing);
  });
  for (final unknown in [true, false]) {
    testWidgets('unknown or missing maximum HP is not guessed $unknown', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          report(
            BattleDetailSide.enemy,
            20,
            unknown: unknown,
            maxHp: unknown ? 100 : 0,
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('battle-detail-tab-process')));
      await tester.pumpAndSettle();
      expect(find.text('敌方大破'), findsNothing);
      expect(find.text('敌方中破'), findsNothing);
      expect(find.text('敌方小破'), findsNothing);
    });
  }
}
