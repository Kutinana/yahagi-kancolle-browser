import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/fleet/repair_summary_card.dart';
import 'package:yahagi_kancolle_browser/src/fleet/anchorage_repair_view.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_store.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/layout/hd_bottom_strip.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';
import 'fixtures/fleet_display_sample.dart';

class _Store extends GameStateStore {
  _Store(this.shipCount);
  final int shipCount;
  @override
  Future<GameState> load() async =>
      shipCount == 7 ? sevenShipDemoState() : demoState();
}

void main() {
  for (final shipCount in [6, 7]) {
    testWidgets(
      'HD anchorage and nosaki place selector left of $shipCount ships',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final state = GameStateController(gameStateStore: _Store(shipCount));
        await state.initialize();
        final layout = await LayoutSettingsController.load(
          SharedPreferencesLayoutSettingsStore(),
        );
        addTearDown(state.dispose);
        addTearDown(layout.dispose);
        await layout.setHdSplit(false);
        await layout.setHdModule('wide', 'repair');
        RepairDestination? opened;
        for (final width in [665.0, 780.0]) {
          await tester.pumpWidget(
            MaterialApp(
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: SizedBox(
                  width: width,
                  height: 350,
                  child: HdBottomStrip(
                    controller: layout,
                    moduleBuilder: (_) => SingleChildScrollView(
                      child: RepairSummaryCard(
                        controller: state,
                        collapsed: false,
                        onToggleCollapse: () {},
                        onOpenRepair: (value) => opened = value,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          for (final columns in [2, 3, 2]) {
            await layout.setHdModuleSpan('repair', columns);
            await tester.pumpAndSettle();
            for (final mode in ['anchorage', 'nosaki']) {
              await tester.tap(find.byKey(Key('repair-summary-mode-$mode')));
              await tester.pumpAndSettle();
              final slots = [
                for (var i = 0; i < shipCount; i++)
                  find.byKey(Key('repair-summary-$mode-slot-$i')),
              ];
              final rects = slots.map(tester.getRect).toList();
              final selector = tester.getRect(
                find.byKey(const Key('repair-summary-fleet-selector')),
              );
              expect(selector.right, lessThan(rects.first.left));
              expect(selector.top, closeTo(rects.first.top, .1));
              expect(selector.width, 70);
              for (var i = 0; i < shipCount; i++) {
                expect(
                  rects[i].top,
                  closeTo(rects[i ~/ columns * columns].top, .1),
                );
                expect(rects[i].width, closeTo(rects.first.width, .1));
                if (i % columns > 0) {
                  expect(rects[i].left, greaterThan(rects[i - 1].right));
                }
                if (i >= columns) {
                  expect(rects[i].top, greaterThan(rects[i - columns].top));
                }
              }
              opened = null;
              await tester.tap(slots.first);
              expect(
                opened?.mode,
                mode == 'anchorage'
                    ? RepairCenterMode.anchorage
                    : RepairCenterMode.nosaki,
              );
              await tester.tap(find.byKey(const Key('repair-summary-fleet-2')));
              await tester.pumpAndSettle();
              opened = null;
              await tester.tap(slots.first);
              expect(opened?.fleetId, 2);
              await tester.tap(find.byKey(const Key('repair-summary-fleet-1')));
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
            }
          }
        }
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
