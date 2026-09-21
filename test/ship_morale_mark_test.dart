import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/fleet/ship_status_visuals.dart';

void main() {
  testWidgets('sparkle animation reuses star glyphs while changing phase', (
    tester,
  ) async {
    final animation = AnimationController(
      vsync: tester,
      duration: const Duration(seconds: 1),
    );
    addTearDown(animation.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 160,
          height: 72,
          child: ShipMoraleMark(shipId: 40, value: 80, sparklePulse: animation),
        ),
      ),
    );
    final finder = find.byIcon(Icons.auto_awesome_rounded);
    final before = tester.widgetList<Icon>(finder).toList();
    animation.value = .2;
    await tester.pump();
    final after = tester.widgetList<Icon>(finder).toList();
    for (var i = 0; i < before.length; i++) {
      expect(identical(before[i], after[i]), isTrue);
    }
    final star = find.byKey(const Key('fleet-sparkle-40-0'));
    expect(
      tester.widget<Transform>(star).transform.entry(0, 0),
      closeTo(.9, .001),
    );
    final opacity = find.descendant(of: star, matching: find.byType(Opacity));
    expect(tester.widget<Opacity>(opacity).opacity, closeTo(.5, .001));
    animation.value = .28;
    await tester.pump();
    expect(tester.widget<Opacity>(opacity).opacity, 1);
    animation.value = .5;
    await tester.pump();
    expect(tester.widget<Opacity>(opacity).opacity, 0);
  });
  testWidgets('sparkle switch hides only stars and keeps fatigue visuals', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 160,
          height: 72,
          child: ShipMoraleMark(
            shipId: 40,
            value: 55,
            sparklePulse: AlwaysStoppedAnimation<double>(0.2),
            sparkleEnabled: false,
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('fleet-morale-stars-40')), findsNothing);

    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 160,
          height: 72,
          child: ShipMoraleMark(
            shipId: 40,
            value: 18,
            sparklePulse: AlwaysStoppedAnimation<double>(0.2),
            sparkleEnabled: false,
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('fleet-fatigue-face-18')), findsOneWidget);
    expect(find.byKey(const Key('fleet-fatigue-badge-40')), findsOneWidget);
  });

  testWidgets('detail portrait keeps the low-morale face at top-left', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            key: Key('portrait'),
            width: 160,
            height: 72,
            child: ShipMoraleMark(
              shipId: 41,
              value: 18,
              sparklePulse: AlwaysStoppedAnimation<double>(0),
              repairLabel: '入渠',
              layout: ShipMoraleMarkLayout.detail,
            ),
          ),
        ),
      ),
    );

    final portrait = tester.getRect(find.byKey(const Key('portrait')));
    final repair = tester.getRect(
      find.byKey(const Key('fleet-repair-badge-41')),
    );
    final fatigue = tester.getRect(
      find.byKey(const Key('fleet-fatigue-badge-41')),
    );
    final face = tester.getRect(find.byKey(const Key('fleet-fatigue-face-18')));
    final repairText = tester.widget<Text>(find.text('入渠'));
    final fatigueText = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('fleet-fatigue-badge-41')),
        matching: find.byType(Text),
      ),
    );
    final fatigueSpans = (fatigueText.textSpan! as TextSpan).children!;
    final fatigueLabelStyle = (fatigueSpans.first as TextSpan).style!;

    expect(face.left, closeTo(portrait.left + 4, 0.1));
    expect(face.top, closeTo(portrait.top + 4, 0.1));
    expect(repair.top, closeTo(portrait.top + 4, 0.1));
    expect(repair.right, closeTo(portrait.right - 5, 0.1));
    expect(fatigue.bottom, closeTo(portrait.bottom - 4, 0.1));
    expect(fatigue.right, closeTo(portrait.right - 5, 0.1));
    expect(repair.size, fatigue.size);
    expect(repairText.style!.fontSize, fatigueLabelStyle.fontSize);
    expect(repair.overlaps(face), isFalse);
  });

  testWidgets(
    'brief portrait uses a smaller top-right face and rounded repair badge',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: SizedBox(
              key: Key('portrait'),
              width: 60,
              height: 28,
              child: ShipMoraleMark(
                shipId: 42,
                value: 18,
                sparklePulse: AlwaysStoppedAnimation<double>(0),
                showTextBadge: false,
                repairLabel: '入渠',
                layout: ShipMoraleMarkLayout.brief,
              ),
            ),
          ),
        ),
      );

      final portrait = tester.getRect(find.byKey(const Key('portrait')));
      final repair = tester.getRect(
        find.byKey(const Key('fleet-repair-badge-42')),
      );
      final face = tester.getRect(
        find.byKey(const Key('fleet-fatigue-face-18')),
      );
      final repairContainer = tester.widget<Container>(
        find.byKey(const Key('fleet-repair-badge-42')),
      );
      final repairDecoration = repairContainer.decoration! as BoxDecoration;

      expect(face.top, closeTo(portrait.top, 0.1));
      expect(face.right, closeTo(portrait.right - 4, 0.1));
      expect(face.width, lessThan(18));
      expect(repair.right, closeTo(portrait.right, 0.1));
      expect(repair.bottom, closeTo(portrait.bottom, 0.1));
      expect(repairDecoration.borderRadius, BorderRadius.circular(999));
      expect(repair.overlaps(face), isFalse);
    },
  );
}
