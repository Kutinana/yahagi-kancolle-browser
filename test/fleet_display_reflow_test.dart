import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'fixtures/fleet_display_sample.dart';
import 'package:yahagi_kancolle_browser/src/settings/fleet_display_options.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/fleet/fleet_summary_card.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_store.dart';
import 'package:yahagi_kancolle_browser/src/fleet/fleet_ship_status_capsule.dart';
import 'package:yahagi_kancolle_browser/src/fleet/ship_repair_status.dart';
import 'package:yahagi_kancolle_browser/src/fleet/ship_status_visuals.dart';
import 'package:yahagi_kancolle_browser/src/settings/battle_status_effect_settings.dart';

class _SampleStore extends GameStateStore {
  @override
  Future<GameState> load() async => demoState();
}

void main() {
  testWidgets('right aligned meters keep the same icon gap as fuel', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              for (var i = 0; i < 3; i++)
                SizedBox(
                  width: 120,
                  child: CompactStatusMeter(
                    height: 16,
                    showTrack: false,
                    alignRight: i != 0,
                    icon: SizedBox(
                      key: Key('gap-icon-$i'),
                      width: 10,
                      height: 10,
                    ),
                    value: ['20/25', '22/24', '24/30'][i],
                    valueKey: Key('gap-value-$i'),
                    ratio: 1,
                    valueColor: Colors.white,
                    barColor: Colors.white,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    final gaps = [
      for (var i = 0; i < 3; i++)
        tester.getRect(find.byKey(Key('gap-value-$i'))).left -
            tester.getRect(find.byKey(Key('gap-icon-$i'))).right,
    ];
    expect(gaps[1], closeTo(gaps[0], 0.1));
    expect(gaps[2], closeTo(gaps[0], 0.1));
    expect(tester.takeException(), isNull);
  });
  testWidgets('text-only name, morale and repair status share one row', (
    tester,
  ) async {
    final state = demoState();
    for (final width in [280.0, 360.0, 560.0]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: FleetShipStatusCapsule(
                  state: state,
                  ship: state.ships[3]!,
                  repairStatus: ShipRepairStatus.anchorage,
                  visible: defaultFields.difference({'portrait'}),
                ),
              ),
            ),
          ),
        ),
      );
      final name = tester.getRect(find.byKey(const Key('text-name-3')));
      final morale = tester.getRect(find.byKey(const Key('text-morale-3')));
      final status = tester.getRect(find.byKey(const Key('text-status-3')));
      final face = tester.getRect(
        find.byKey(const Key('fleet-fatigue-face-27')),
      );
      expect(face.left, greaterThanOrEqualTo(morale.left));
      expect(face.right, lessThanOrEqualTo(morale.right));
      expect(face.center.dy, closeTo(name.center.dy, 0.1));
      expect(face.center.dy, closeTo(status.center.dy, 0.1));
      expect(morale.left, greaterThan(name.right));
      expect(status.left, greaterThan(morale.right));
      expect(morale.center.dy, closeTo(name.center.dy, 1));
      expect(status.center.dy, closeTo(name.center.dy, 1));
      expect(
        tester.widget<ShipHpFrame>(find.byType(ShipHpFrame)).filter,
        DamagePulseFilter.off,
      );
      expect(
        tester
            .widget<ShipMoraleMark>(find.byType(ShipMoraleMark))
            .sparkleEnabled,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
  test(
    'saved settings migrate mechanisms and enforce a maximum of five metrics',
    () {
      expect(normalizeDisplayFields({'asw', 'night'}), {'mechanisms'});
      final restored = normalizeDisplayFields(allFields);
      expect(restored.intersection(summaryFields).length, 5);
      expect(normalizeDisplayFields({}), isEmpty);
    },
  );
  testWidgets('hidden fields return width to name and all combinations fit', (
    tester,
  ) async {
    final controller = GameStateController(gameStateStore: _SampleStore());
    await controller.initialize();
    addTearDown(controller.dispose);
    Future<void> show(Set<String> fields, double width) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: FleetSummaryCard(
                  controller: controller,
                  visible: fields,
                  collapsed: false,
                  onToggleCollapse: () {},
                  onOpenFleet: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
    }

    await show(compactFields, 280);
    final hpRight = tester
        .getRect(find.byKey(const Key('fleet-focus-hp-value-1')))
        .right;
    final ammoRight = tester
        .getRect(find.byKey(const Key('fleet-focus-ammo-value-1')))
        .right;
    expect(hpRight, closeTo(ammoRight, 0.1));
    final hpMeter = find.ancestor(
      of: find.byKey(const Key('fleet-focus-hp-value-1')),
      matching: find.byType(CompactStatusMeter),
    );
    expect(hpRight, closeTo(tester.getRect(hpMeter).right, 0.1));
    await show(compactFields, 360);
    final initial = tester
        .getSize(find.byKey(const Key('text-identity-1')))
        .width;
    await show(compactFields.difference({'fuel'}), 360);
    expect(
      tester.getSize(find.byKey(const Key('text-identity-1'))).width,
      greaterThan(initial + 50),
    );
    for (final width in [280.0, 360.0, 560.0]) {
      for (var mask = 0; mask < 32; mask++) {
        final fields = {...defaultFields};
        final keys = ['portrait', 'fuel', 'ammo', 'bars', 'hp'];
        for (var bit = 0; bit < 5; bit++) {
          if ((mask & (1 << bit)) != 0) fields.remove(keys[bit]);
        }
        await show(fields, width);
        expect(
          find.byKey(const Key('fleet-focus-hp-value-1')),
          fields.contains('hp') ? findsOneWidget : findsNothing,
        );
        expect(tester.takeException(), isNull, reason: '$width $mask');
      }
    }
    await show({'speed', 'firepower', 'torpedo', 'anti-air', 'anti-sub'}, 360);
    final fiveWidth = tester
        .getSize(find.byKey(const Key('fleet-summary-metric-speed')))
        .width;
    expect(
      find.byKey(const Key('fleet-summary-metric-firepower')),
      findsOneWidget,
    );
    await show({'speed', 'firepower'}, 360);
    expect(
      tester.getSize(find.byKey(const Key('fleet-summary-metric-speed'))).width,
      greaterThan(fiveWidth * 2),
    );
    await show({}, 360);
    expect(find.byKey(const Key('fleet-summary-metrics')), findsNothing);
    expect(find.byKey(const Key('fleet-focus-hp-value-1')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
