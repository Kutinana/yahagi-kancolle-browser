import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/logbook/battle_detail_page.dart';
import 'fixtures/battle_detail_ui_sample.dart';

void main() {
  testWidgets(
    'header tabs use smaller text and compact capsules without changing title',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BattleDetailPage(detail: sampleBattle(false), onBack: () {}),
        ),
      );
      final title = tester.widget<Text>(find.text('战斗详情 · 1-1 C点'));
      expect(title.style!.fontSize, 15);
      for (final tab in ['舰队', '战斗过程']) {
        final text = tester.widget<Text>(find.text(tab));
        expect(text.style!.fontSize, 12);
        expect(text.style!.fontWeight, title.style!.fontWeight);
      }
      expect(
        tester.getSize(find.byKey(const Key('detail-tabs'))).height,
        lessThanOrEqualTo(36),
      );
      expect(
        tester.getSize(find.byKey(const Key('detail-tabs'))).width,
        lessThanOrEqualTo(142),
      );
    },
  );

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
        tester.getSize(find.byKey(const Key('battle-detail-header'))).height,
        lessThanOrEqualTo(38),
      );
      expect(
        tester.getRect(find.byKey(const Key('detail-tabs'))).top,
        lessThan(12),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'process filter tabs use segmented capsules matching detail tabs',
    (tester) async {
      await tester.pumpWidget(app());
      await tester.tap(find.byKey(const Key('battle-detail-tab-process')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('battle-detail-filter-container')),
        findsOneWidget,
      );
      for (final filterText in ['全部', '我方攻击', '敌方攻击']) {
        final text = tester.widget<Text>(
          find.descendant(
            of: find.byKey(const Key('battle-detail-filter-container')),
            matching: find.text(filterText),
          ),
        );
        expect(text.style!.fontSize, 12);
        expect(text.style!.fontWeight, FontWeight.w700);
      }
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
