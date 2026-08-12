import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/fleet/ship_status_style.dart';
import 'package:yahagi_kancolle_browser/src/fleet/ship_status_visuals.dart';

void main() {
  testWidgets('damage pulse builder advances only for damaged hp', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DamagePulseBuilder(
          ratio: 0.2,
          mode: DamagePulseMode.enhanced,
          normalColor: yahagiStatusRed,
          builder: (context, spec, phase) => Opacity(
            key: const Key('shared-damage-pulse-phase'),
            opacity: phase,
            child: const SizedBox(width: 20, height: 20),
          ),
        ),
      ),
    );

    final phase = find.byKey(const Key('shared-damage-pulse-phase'));
    final before = tester.widget<Opacity>(phase).opacity;
    await tester.pump(const Duration(milliseconds: 190));

    expect(tester.widget<Opacity>(phase).opacity, greaterThan(before));
  });

  testWidgets('damage pulse builder stays static for healthy hp', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DamagePulseBuilder(
          ratio: 1,
          mode: DamagePulseMode.enhanced,
          normalColor: yahagiStatusGreen,
          builder: (context, spec, phase) => Opacity(
            key: const Key('healthy-damage-pulse-phase'),
            opacity: phase,
            child: const SizedBox(width: 20, height: 20),
          ),
        ),
      ),
    );

    final phase = find.byKey(const Key('healthy-damage-pulse-phase'));
    expect(tester.widget<Opacity>(phase).opacity, 1);
    await tester.pump(const Duration(milliseconds: 190));
    expect(tester.widget<Opacity>(phase).opacity, 1);
  });

  testWidgets('damage pulse builder adopts mode changes immediately', (
    tester,
  ) async {
    Widget subject(DamagePulseMode mode) => MaterialApp(
      home: DamagePulseBuilder(
        key: const Key('mode-aware-damage-pulse'),
        ratio: 0.2,
        mode: mode,
        normalColor: yahagiStatusRed,
        builder: (context, spec, phase) => Text(
          '${spec.duration.inMilliseconds}',
          textDirection: TextDirection.ltr,
        ),
      ),
    );

    await tester.pumpWidget(subject(DamagePulseMode.enhanced));
    expect(find.text('760'), findsOneWidget);

    await tester.pumpWidget(subject(DamagePulseMode.normal));
    expect(find.text('2400'), findsOneWidget);
  });

  testWidgets('enhanced damage frame adds a synchronized portrait tint', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 240,
          height: 120,
          child: ShipHpFrame(
            shipId: 41,
            ratio: 0.18,
            color: yahagiStatusRed,
            mode: DamagePulseMode.enhanced,
          ),
        ),
      ),
    );

    final tint = find.byKey(const Key('fleet-damage-tint-41'));
    expect(tint, findsOneWidget);
    final firstOpacity = tester.widget<Opacity>(tint).opacity;

    await tester.pump(const Duration(milliseconds: 190));

    expect(tester.widget<Opacity>(tint).opacity, greaterThan(firstOpacity));
    expect(find.byKey(const Key('fleet-damage-pulse-41')), findsOneWidget);
  });

  testWidgets('normal damage frame keeps the old outer-only effect', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 240,
          height: 120,
          child: ShipHpFrame(
            shipId: 42,
            ratio: 0.18,
            color: yahagiStatusRed,
            mode: DamagePulseMode.normal,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('fleet-damage-pulse-42')), findsOneWidget);
    expect(find.byKey(const Key('fleet-damage-tint-42')), findsNothing);
  });

  testWidgets('healthy ships do not render damage pulse layers', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 240,
          height: 120,
          child: ShipHpFrame(
            shipId: 43,
            ratio: 0.9,
            color: yahagiStatusGreen,
            mode: DamagePulseMode.enhanced,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('fleet-damage-pulse-43')), findsNothing);
    expect(find.byKey(const Key('fleet-damage-tint-43')), findsNothing);
  });
}
