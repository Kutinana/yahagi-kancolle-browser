import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/widgets/marquee_text.dart';

void main() {
  tearDown(() {
    MarqueeText.disableAnimationForTest = false;
  });

  testWidgets(
    'Short text within bounds renders static text without translation',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 500,
              child: MarqueeText(
                text: 'Short notice',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Short notice'), findsOneWidget);
      // Should NOT have marquee translation since it fits within 500px
      expect(find.byKey(const Key('marquee-translate')), findsNothing);
    },
  );

  testWidgets(
    'Long text exceeding bounds starts animation and scrolls smoothly',
    (tester) async {
      const longNotice = '【出撃】南西諸島海域の制海権を握れ！出撃艦隊を編成し敵艦隊を撃滅せよ！';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 120, // narrow container
              child: MarqueeText(
                text: longNotice,
                style: TextStyle(fontSize: 14),
                velocity: 50.0,
                pauseDuration: Duration(milliseconds: 500),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text(longNotice), findsOneWidget);

      final transformFinder = find.byKey(const Key('marquee-translate'));
      expect(transformFinder, findsOneWidget);

      // Initial pause phase (0 ~ 500ms): translation should be 0
      final initialTransform = tester.widget<Transform>(transformFinder);
      final initialOffset = initialTransform.transform.getTranslation().x;
      expect(initialOffset, equals(0.0));

      // After pause duration (e.g. 500ms pause + 800ms scrolling), translation offset should be negative
      await tester.pump(const Duration(milliseconds: 1000));
      final scrollingTransform = tester.widget<Transform>(transformFinder);
      final scrollingOffset = scrollingTransform.transform.getTranslation().x;
      expect(scrollingOffset, lessThan(0.0));
    },
  );

  testWidgets(
    'disableAnimationForTest prevents scrolling and renders static text',
    (tester) async {
      MarqueeText.disableAnimationForTest = true;
      const longNotice = 'Very long text that should not scroll when disabled';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 80,
              child: MarqueeText(
                text: longNotice,
                style: TextStyle(fontSize: 14),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text(longNotice), findsOneWidget);
      expect(find.byKey(const Key('marquee-translate')), findsNothing);
    },
  );

  testWidgets('Empty text renders empty without errors', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 200, child: MarqueeText(text: '')),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(Text), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Updating text reconfigures animation and resets offset', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 100,
            child: MarqueeText(
              text: 'First very long text that scrolls across the screen',
              style: TextStyle(fontSize: 14),
              velocity: 50.0,
              pauseDuration: Duration(milliseconds: 200),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Update with new text
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 100,
            child: MarqueeText(
              text: 'Second very long text replacing the first one',
              style: TextStyle(fontSize: 14),
              velocity: 50.0,
              pauseDuration: Duration(milliseconds: 200),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      find.text('Second very long text replacing the first one'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
