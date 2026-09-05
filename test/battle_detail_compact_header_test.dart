import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/logbook/battle_detail_page.dart';
import 'fixtures/battle_detail_ui_sample.dart';

void main() {
  Widget app() => MaterialApp(
    home: BattleDetailPage(detail: sampleBattle(true), onBack: () {}),
  );

  testWidgets(
    'compact header omits time and groups enemy capsule before rank',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(915, 412));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(app());
      expect(find.textContaining('2026/09/05'), findsNothing);
      expect(find.text('敌联合舰队'), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text('敌联合舰队'),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).borderRadius ==
                    BorderRadius.circular(20),
          ),
        ),
        findsOneWidget,
      );
      final enemy = tester.getRect(find.text('敌联合舰队'));
      final rank = tester.getRect(find.text('S'));
      expect(enemy.right, lessThan(rank.left));
      expect((enemy.center.dy - rank.center.dy).abs(), lessThan(2));
      expect(
        tester.getRect(find.byKey(const Key('detail-tabs'))).top,
        lessThan(12),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('fleet HP shows damage received and preserves existing metrics', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app());
    expect(find.text('98 / 98（-0）'), findsOneWidget);
    expect(find.text('44 / 99（-55）'), findsOneWidget);
    expect(find.text('0 / 160（-188）'), findsOneWidget);
    expect(find.text('耐久 99 → 44'), findsOneWidget);
    expect(find.text('造成 68'), findsOneWidget);
    expect(find.text('承受 55'), findsOneWidget);
  });
  testWidgets('restored HP still shows cumulative received damage', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    expect(find.text('32 / 32（-40）'), findsOneWidget);
    expect(find.text('耐久 32 → 32'), findsOneWidget);
    expect(find.text('承受 40'), findsOneWidget);
  });
}
