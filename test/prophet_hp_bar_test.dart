import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/battle/prophet_hp_bar.dart';

void main() {
  Future<void> pumpBar(WidgetTester tester, double value) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 400,
            child: ProphetHpBar(
              value: value,
              color: Colors.green,
              backgroundColor: const Color(0xff263e4d),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows only thresholds strictly below the filled ratio', (
    tester,
  ) async {
    await pumpBar(tester, 1.0);
    expect(find.byKey(const Key('prophet-hp-threshold-25')), findsOneWidget);
    expect(find.byKey(const Key('prophet-hp-threshold-50')), findsOneWidget);
    expect(find.byKey(const Key('prophet-hp-threshold-75')), findsOneWidget);

    await pumpBar(tester, 0.64);
    expect(find.byKey(const Key('prophet-hp-threshold-25')), findsOneWidget);
    expect(find.byKey(const Key('prophet-hp-threshold-50')), findsOneWidget);
    expect(find.byKey(const Key('prophet-hp-threshold-75')), findsNothing);

    await pumpBar(tester, 0.48);
    expect(find.byKey(const Key('prophet-hp-threshold-25')), findsOneWidget);
    expect(find.byKey(const Key('prophet-hp-threshold-50')), findsNothing);
    expect(find.byKey(const Key('prophet-hp-threshold-75')), findsNothing);

    await pumpBar(tester, 0.25);
    expect(find.byKey(const Key('prophet-hp-threshold-25')), findsNothing);
  });

  testWidgets('places three one-pixel ticks at quarter boundaries', (
    tester,
  ) async {
    await pumpBar(tester, 1.0);

    final barLeft = tester.getTopLeft(find.byType(ProphetHpBar)).dx;
    for (final threshold in const <int>[25, 50, 75]) {
      final tick = find.byKey(Key('prophet-hp-threshold-$threshold'));
      expect(
        tester.getTopLeft(tick).dx - barLeft,
        moreOrLessEquals(400 * threshold / 100, epsilon: 0.01),
      );
      expect(tester.getSize(tick), const Size(1, 4));
    }
    expect(tester.getSize(find.byType(ProphetHpBar)).height, 6);
  });

  testWidgets('clamps progress values before drawing thresholds', (
    tester,
  ) async {
    await pumpBar(tester, -0.5);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      0.0,
    );
    expect(find.byKey(const Key('prophet-hp-threshold-25')), findsNothing);

    await pumpBar(tester, 1.5);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      1.0,
    );
    expect(find.byKey(const Key('prophet-hp-threshold-75')), findsOneWidget);
  });
}
