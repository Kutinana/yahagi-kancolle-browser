import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/logbook/battle_detail_page.dart';
import 'fixtures/battle_detail_ui_sample.dart';

void main() {
  for (final width in [
    360.0,
    390.0,
    529.0,
    530.0,
    531.0,
    540.0,
    600.0,
    659.0,
    660.0,
    700.0,
    915.0,
    1280.0,
  ]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets(
        'attack and result remain side by side width=$width scale=$scale',
        (tester) async {
          await tester.binding.setSurfaceSize(Size(width, 844));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: BattleDetailPage(
                  detail: sampleBattle(false),
                  onBack: () {},
                ),
              ),
            ),
          );
          await tester.tap(find.byKey(const Key('battle-detail-tab-process')));
          await tester.pumpAndSettle();
          final row = find.byKey(const Key('attack-1'));
          Finder text(String value) =>
              find.descendant(of: row, matching: find.text(value));
          final attack = tester.getRect(text('我方攻击'));
          final damage = tester.getRect(text('造成 67 伤害'));
          expect(damage.left, greaterThan(attack.right));
          expect(damage.top, closeTo(attack.top, .01));
          expect(
            tester.getRect(text('目标HP 33 → 0（-67）')).left,
            tester
                .getRect(
                  find.ancestor(
                    of: text('造成 67 伤害'),
                    matching: find.byType(Tag),
                  ),
                )
                .left,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'damage and state capsules use the attack badge typography and height',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BattleDetailPage(detail: sampleBattle(false), onBack: () {}),
        ),
      );
      await tester.tap(find.byKey(const Key('battle-detail-tab-process')));
      await tester.pumpAndSettle();
      final row = find.byKey(const Key('attack-1'));
      Finder text(String value) =>
          find.descendant(of: row, matching: find.text(value));
      Finder tag(String value) =>
          find.ancestor(of: text(value), matching: find.byType(Tag));
      final attackStyle = tester.widget<Text>(text('我方攻击')).style!;
      for (final value in ['造成 67 伤害', '敌方击沉']) {
        final style = tester.widget<Text>(text(value)).style!;
        expect(style.fontSize, attackStyle.fontSize);
        expect(style.fontWeight, attackStyle.fontWeight);
        expect(
          tester.getSize(tag(value)).height,
          tester.getSize(tag('我方攻击')).height,
        );
      }
    },
  );
}
