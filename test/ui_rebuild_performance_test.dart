import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/fleet/fleet_information_center.dart';
import 'package:yahagi_kancolle_browser/src/fleet/fleet_summary_card.dart';
import 'package:yahagi_kancolle_browser/src/fleet/fleet_ship_status_capsule.dart';
import 'package:yahagi_kancolle_browser/src/fleet/operation_status_views.dart';
import 'package:yahagi_kancolle_browser/src/fleet/repair_summary_card.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/widgets/marquee_text.dart';

import 'fixtures/kcsapi_fixtures.dart';

Widget wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

Future<GameStateController> game() async {
  final controller = GameStateController();
  addTearDown(controller.dispose);
  controller.accept(start2Event);
  controller.accept(portEvent);
  await controller.idle;
  return controller;
}

void main() {
  testWidgets('repair dock tick reuses unchanged card and mode selector', (
    tester,
  ) async {
    final controller = await game();
    await tester.pumpWidget(
      wrap(
        RepairSummaryCard(
          controller: controller,
          collapsed: false,
          onToggleCollapse: () {},
          onOpenRepair: (_) {},
        ),
      ),
    );
    final finder = find.byKey(const Key('repair-summary-mode-selector'));
    final before = tester.widget(finder);
    await tester.pump(const Duration(seconds: 1));
    expect(identical(before, tester.widget(finder)), isTrue);
  });
  testWidgets('collapsed fleet summary does not rebuild on second ticks', (
    tester,
  ) async {
    final controller = await game();
    await tester.pumpWidget(
      wrap(
        FleetSummaryCard(
          controller: controller,
          collapsed: true,
          onToggleCollapse: () {},
          onOpenFleet: (_) {},
        ),
      ),
    );
    final finder = find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == 'DashboardCard',
    );
    final before = tester.widget(finder);
    await tester.pump(const Duration(seconds: 2));
    expect(identical(before, tester.widget(finder)), isTrue);
  });
  testWidgets('expedition page does not rebuild its shell on second ticks', (
    tester,
  ) async {
    final controller = await game();
    var rebuilds = 0;
    final previous = debugOnRebuildDirtyWidget;
    debugOnRebuildDirtyWidget = (element, builtOnce) {
      previous?.call(element, builtOnce);
      if (element.widget is ExpeditionStatusView) rebuilds++;
    };
    addTearDown(() => debugOnRebuildDirtyWidget = previous);
    await tester.pumpWidget(
      wrap(
        FleetInformationCenter(
          controller: controller,
          page: FleetInformationPage.expedition,
        ),
      ),
    );
    final before = rebuilds;
    expect(before, greaterThan(0));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(rebuilds - before, 0);
  });

  testWidgets('marquee animation reuses text while translation advances', (
    tester,
  ) async {
    const text = 'A long notice that needs to scroll within a narrow viewport';
    await tester.pumpWidget(
      wrap(
        const SizedBox(
          width: 100,
          child: MarqueeText(
            text: text,
            style: TextStyle(fontSize: 14),
            pauseDuration: Duration(milliseconds: 100),
          ),
        ),
      ),
    );
    await tester.pump();
    final original = tester.widget<Text>(find.text(text));
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      tester
          .widget<Transform>(find.byKey(const Key('marquee-translate')))
          .transform
          .getTranslation()
          .x,
      lessThan(0),
    );
    expect(identical(original, tester.widget<Text>(find.text(text))), isTrue);
  });

  testWidgets('fleet summary reuses static metrics between second ticks', (
    tester,
  ) async {
    final controller = await game();
    await tester.pumpWidget(
      wrap(
        SingleChildScrollView(
          child: FleetSummaryCard(
            controller: controller,
            collapsed: false,
            onToggleCollapse: () {},
            onOpenFleet: (_) {},
            moraleSparkleEnabled: false,
          ),
        ),
      ),
    );
    final metricsFinder = find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == '_FleetSummaryMetrics',
    );
    final Object? before = (tester.widget(metricsFinder) as dynamic).metrics;
    final shipBefore = tester
        .widgetList<FleetShipStatusCapsule>(find.byType(FleetShipStatusCapsule))
        .first;
    expect(before, isNotNull);
    await tester.pump(const Duration(seconds: 1));
    final Object? after = (tester.widget(metricsFinder) as dynamic).metrics;
    expect(identical(before, after), isTrue);
    expect(
      identical(
        shipBefore,
        tester
            .widgetList<FleetShipStatusCapsule>(
              find.byType(FleetShipStatusCapsule),
            )
            .first,
      ),
      isTrue,
    );
    // A new server snapshot must still replace the derived metrics.
    controller.accept(portEvent);
    await controller.idle;
    await tester.pump();
    final Object? updated = (tester.widget(metricsFinder) as dynamic).metrics;
    expect(identical(after, updated), isFalse);
    expect(
      identical(
        shipBefore,
        tester
            .widgetList<FleetShipStatusCapsule>(
              find.byType(FleetShipStatusCapsule),
            )
            .first,
      ),
      isFalse,
    );
  });
}
