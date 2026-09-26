import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_detail_models.dart';
import 'package:yahagi_kancolle_browser/src/logbook/battle_detail_page.dart';
import 'fixtures/battle_detail_ui_sample.dart';

Widget app(
  int hp, {
  BattleDetailSide side = BattleDetailSide.friend,
  bool unknown = false,
  int maxHp = 100,
}) => MaterialApp(
  home: BattleDetailPage(
    onBack: () {},
    detail: BattleDetailSnapshot(
      completedAtMillis: 0,
      mapLabel: '1-1',
      nodeLabel: 'C点',
      rank: 'S',
      enemyFleetName: '测试舰队',
      fleets: [
        BattleDetailFleet(
          side: side,
          role: BattleDetailFleetRole.main,
          ships: [
            BattleDetailShip(
              name: '测试舰',
              side: side,
              role: BattleDetailFleetRole.main,
              position: 0,
              initialHp: 100,
              finalHp: hp,
              maxHp: maxHp,
              hpUnknown: unknown,
              damageReceived: 120,
            ),
          ],
        ),
      ],
    ),
  ),
);

void main() {
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
      testWidgets('fleet status $side HP=${entry.key}', (tester) async {
        await tester.pumpWidget(app(entry.key, side: side));
        for (final status in ['小破', '中破', '大破', '击沉']) {
          expect(
            find.text(status),
            status == entry.value ? findsOneWidget : findsNothing,
          );
        }
        if (entry.value != null) {
          final badge = tester.getRect(find.text(entry.value!));
          final name = tester.getRect(find.text('测试舰'));
          expect(badge.left, greaterThan(name.right));
          final tag = tester.widget<Tag>(
            find.ancestor(
              of: find.text(entry.value!),
              matching: find.byType(Tag),
            ),
          );
          expect(tag.size, 11);
          expect(tag.pill, isTrue);
        }
      });
    }
  }
  for (final setting in [
    (100, false, 100),
    (0, true, 100),
    (0, false, 0),
    (-1, false, 100),
  ]) {
    testWidgets(
      'restored or unknown HP does not infer damage from received total $setting',
      (tester) async {
        await tester.pumpWidget(
          app(setting.$1, unknown: setting.$2, maxHp: setting.$3),
        );
        for (final status in ['小破', '中破', '大破', '击沉']) {
          expect(find.text(status), findsNothing);
        }
        expect(find.text('承受 120'), findsOneWidget);
      },
    );
  }
  for (final size in [
    const Size(360, 780),
    const Size(390, 844),
    const Size(915, 412),
    const Size(914, 836),
    const Size(1280, 800),
    const Size(800, 1280),
  ]) {
    testWidgets('fleet status badges fit $size with large text', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: BattleDetailPage(detail: sampleBattle(true), onBack: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('小破'), findsWidgets);
      expect(find.text('中破'), findsWidgets);
      expect(find.text('大破'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -900),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
