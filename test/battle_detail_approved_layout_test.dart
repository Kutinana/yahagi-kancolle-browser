import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_detail_models.dart';
import 'package:yahagi_kancolle_browser/src/logbook/battle_detail_page.dart';
import 'fixtures/battle_detail_ui_sample.dart';

void main() {
  const sizes = [
    Size(360, 780),
    Size(390, 844),
    Size(915, 412),
    Size(914, 836),
    Size(1280, 800),
    Size(800, 1280),
  ];
  Widget app(BattleDetailSnapshot data, {double scale = 1}) => MaterialApp(
    theme: ThemeData(brightness: Brightness.dark),
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: BattleDetailPage(detail: data, onBack: () {}),
      ),
    ),
  );

  for (final size in sizes) {
    for (final combined in [false, true]) {
      testWidgets('fleet and process fit $size, combined=$combined', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(app(sampleBattle(combined)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('无随伴舰队'), findsNothing);
        expect(
          find.text('第二舰队 · 随伴'),
          combined ? findsOneWidget : findsNothing,
        );
        expect(find.text('敌方随伴'), combined ? findsOneWidget : findsNothing);
        final header = tester.getRect(find.text(combined ? 'S' : 'SS'));
        final title = tester.getRect(
          find.text(combined ? '战斗详情 · 6-5 M点' : '战斗详情 · 1-1 C点'),
        );
        expect(header.left, greaterThan(title.left));
        if (size.width >= 640) {
          final tabs = tester.getRect(find.byKey(const Key('detail-tabs')));
          expect(tabs.left, greaterThan(header.right));
        }
        await tester.tap(find.byKey(const Key('battle-detail-tab-process')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('第 1 段'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const Key('battle-detail-filter-enemy')));
        await tester.pumpAndSettle();
        expect(find.text('我方攻击'), findsOneWidget); // filter only
        expect(tester.takeException(), isNull);
        final list = find.byType(ListView);
        for (var i = 0; i < 8; i++) {
          await tester.drag(list, const Offset(0, -350));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      });
    }
  }
  for (final size in sizes) {
    testWidgets('large text fits $size', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(app(sampleBattle(true), scale: 1.3));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('battle-detail-tab-process')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (var i = 0; i < 12; i++) {
        await tester.drag(find.byType(ListView), const Offset(0, -250));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }
  testWidgets('repair, multi-hit totals and stage collapse work', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(915, 412));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app(sampleBattle(true)));
    await tester.tap(find.byKey(const Key('battle-detail-tab-process')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('attack-8')),
      160,
      scrollable: find.byType(Scrollable).last,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('attack-8')),
        matching: find.text('敌方大破'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('attack-8')),
        matching: find.text('造成 120 伤害'),
      ),
      findsOneWidget,
    );
    expect(find.text('第 2 段'), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const Key('attack-15')),
      160,
      scrollable: find.byType(Scrollable).last,
    );
    await Scrollable.ensureVisible(
      tester.element(find.byKey(const Key('attack-15'))),
      alignment: .2,
    );
    await tester.pumpAndSettle();
    expect(find.text('损管发动'), findsOneWidget);
    expect(find.text('目标HP 32 → 32（-40）'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('stage-torpedo')));
    await tester.tap(find.byKey(const Key('stage-torpedo')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('attack-15')), findsNothing);
    expect(tester.takeException(), isNull);
  });
  test('samples have coherent HP and fleet totals', () {
    for (final combined in [false, true]) {
      final data = sampleBattle(combined);
      for (final fleet in data.fleets) {
        for (final ship in fleet.ships) {
          bool identity(
            BattleDetailSide side,
            BattleDetailFleetRole? role,
            int? pos,
          ) => side == ship.side && role == ship.role && pos == ship.position;
          final attacks = data.stages.expand((s) => s.attacks);
          final received = attacks.where(
            (a) => identity(a.defenderSide, a.defenderRole, a.defenderPosition),
          );
          final dealt = attacks.where(
            (a) => identity(a.attackerSide, a.attackerRole, a.attackerPosition),
          );
          expect(
            received.fold(0, (sum, a) => sum + a.totalDamage),
            ship.damageReceived,
          );
          expect(
            dealt.fold(0, (sum, a) => sum + a.totalDamage),
            ship.damageDealt,
          );
          var hp = ship.initialHp;
          for (final a in received) {
            expect(a.defenderHpBefore, hp);
            hp = a.defenderHpAfter;
          }
          expect(hp, ship.finalHp);
        }
      }
    }
  });
}
