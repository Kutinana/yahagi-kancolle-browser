import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/fleet/ship_status_style.dart';
import 'package:yahagi_kancolle_browser/src/fleet/ship_status_visuals.dart';
import 'package:yahagi_kancolle_browser/src/settings/battle_status_effect_settings.dart';

void main() {
  testWidgets('damage pulse builder advances only for damaged hp', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DamagePulseBuilder(
          currentHp: 20,
          maxHp: 100,
          filter: DamagePulseFilter.heavyOnly,
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
          currentHp: 100,
          maxHp: 100,
          filter: DamagePulseFilter.all,
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

  testWidgets('damage pulse builder adopts exact filter changes immediately', (
    tester,
  ) async {
    Widget subject(DamagePulseFilter filter) => MaterialApp(
      home: DamagePulseBuilder(
        key: const Key('filter-aware-damage-pulse'),
        currentHp: 20,
        maxHp: 100,
        filter: filter,
        normalColor: yahagiStatusRed,
        builder: (context, spec, phase) => Text(
          '${spec.duration.inMilliseconds}',
          textDirection: TextDirection.ltr,
        ),
      ),
    );

    await tester.pumpWidget(subject(DamagePulseFilter.heavyOnly));
    expect(find.text('760'), findsOneWidget);

    await tester.pumpWidget(subject(DamagePulseFilter.moderateOnly));
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
            currentHp: 18,
            maxHp: 100,
            color: yahagiStatusRed,
            filter: DamagePulseFilter.heavyOnly,
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

  testWidgets('a non-matching exact filter keeps a static damage frame', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 240,
          height: 120,
          child: ShipHpFrame(
            shipId: 42,
            currentHp: 18,
            maxHp: 100,
            color: yahagiStatusRed,
            filter: DamagePulseFilter.moderateOnly,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('fleet-damage-pulse-42')), findsNothing);
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
            currentHp: 90,
            maxHp: 100,
            color: yahagiStatusGreen,
            filter: DamagePulseFilter.all,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('fleet-damage-pulse-43')), findsNothing);
    expect(find.byKey(const Key('fleet-damage-tint-43')), findsNothing);
  });
}
