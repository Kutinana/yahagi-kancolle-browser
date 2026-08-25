import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/fleet/land_base_status_visuals.dart';
import 'package:yahagi_kancolle_browser/src/fleet/ship_status_visuals.dart';

void main() {
  test('fatigue uses only the worst reported squadron condition', () {
    expect(landBaseFatigueLevel(const <int>[]), LandBaseFatigueLevel.none);
    expect(landBaseFatigueLevel(const <int>[1, 1]), LandBaseFatigueLevel.none);
    expect(
      landBaseFatigueLevel(const <int>[1, 2]),
      LandBaseFatigueLevel.yellow,
    );
    expect(landBaseFatigueLevel(const <int>[1, 3]), LandBaseFatigueLevel.red);
  });

  testWidgets('shared fatigue face renders the requested level', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Row(
          children: <Widget>[
            FatigueFace(
              level: FatigueFaceLevel.yellow,
              size: 18,
              faceKey: Key('yellow-face'),
            ),
            FatigueFace(
              level: FatigueFaceLevel.red,
              size: 18,
              faceKey: Key('red-face'),
            ),
          ],
        ),
      ),
    );

    expect(find.byKey(const Key('yellow-face')), findsOneWidget);
    expect(find.byIcon(Icons.sentiment_dissatisfied_rounded), findsOneWidget);
    expect(find.byKey(const Key('red-face')), findsOneWidget);
    expect(
      find.byIcon(Icons.sentiment_very_dissatisfied_rounded),
      findsOneWidget,
    );
  });
}
