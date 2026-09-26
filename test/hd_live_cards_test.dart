import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/fleet/fleet_summary_card.dart';
import 'package:yahagi_kancolle_browser/src/fleet/fleet_ship_status_capsule.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_store.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/layout/hd_bottom_strip.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/battle_status_effect_settings.dart';
import 'fixtures/fleet_display_sample.dart';

class _FleetStore extends GameStateStore {
  _FleetStore(this.shipCount);
  final int shipCount;
  @override
  Future<GameState> load() async {
    final state = shipCount == 7 ? sevenShipDemoState() : demoState();
    // Uneven equipment counts must not shift the identity row between peers.
    return state.copyWith(
      slotItems: {
        for (final entry in state.slotItems.entries)
          if (entry.key % 6 < 4) entry.key: entry.value,
      },
    );
  }
}

void main() {
  for (final shipCount in [6, 7]) {
    testWidgets(
      'live $shipCount ship fleet uses span columns, scrolls independently and keeps navigation',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(1280, 800);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final state = GameStateController(
          gameStateStore: _FleetStore(shipCount),
        );
        await state.initialize();
        addTearDown(state.dispose);
        final layout = await LayoutSettingsController.load(
          SharedPreferencesLayoutSettingsStore(),
        );
        addTearDown(layout.dispose);
        await layout.setHdEnabled(true);
        await layout.setHdSplit(false);
        int? openedFleet;
        for (final width in [400.0, 520.0, 665.0, 921.0, 1081.0]) {
          await tester.pumpWidget(
            MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: const Locale('zh'),
              home: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: width,
                    height: 200,
                    child: HdBottomStrip(
                      controller: layout,
                      moduleBuilder: (_) => SingleChildScrollView(
                        primary: false,
                        child: FleetSummaryCard(
                          controller: state,
                          collapsed: false,
                          onToggleCollapse: () {},
                          onOpenFleet: (id) => openedFleet = id,
                          damagePulseFilter: DamagePulseFilter.off,
                          moraleSparkleEnabled: false,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          for (final columns in [1, 2, 3, 2]) {
            await layout.setHdModuleSpan('fleet', columns);
            await tester.pumpAndSettle();
            final metrics = find.byKey(const Key('fleet-summary-metrics'));
            expect(
              find.descendant(of: metrics, matching: find.text('火力')),
              columns == 2 ? findsOneWidget : findsNothing,
            );
            expect(
              find.descendant(of: metrics, matching: find.text('对潜')),
              columns == 2 ? findsOneWidget : findsNothing,
            );
            expect(
              find.descendant(of: metrics, matching: find.byType(Text)),
              findsNWidgets(columns == 2 ? 14 : 10),
            );
            final ships = find.byType(FleetShipStatusCapsule);
            expect(ships, findsNWidgets(shipCount));
            final rects = [
              for (var i = 0; i < shipCount; i++) tester.getRect(ships.at(i)),
            ];
            final metricRect = tester.getRect(
              find.byKey(const Key('fleet-summary-metrics')),
            );
            if (columns > 1) {
              expect(metricRect.right, lessThan(rects.first.left));
              expect(metricRect.top, closeTo(rects.first.top, .1));
              expect(metricRect.width, lessThanOrEqualTo(72));
            } else {
              expect(metricRect.bottom, lessThan(rects.first.top));
            }
            for (var i = 0; i < shipCount; i++) {
              expect(
                rects[i].top,
                closeTo(rects[(i ~/ columns) * columns].top, .1),
              );
              expect(rects[i].left, closeTo(rects[i % columns].left, .1));
              expect(rects[i].width, closeTo(rects.first.width, .1));
              final portrait = find.descendant(
                of: ships.at(i),
                matching: find.byWidgetPredicate(
                  (widget) =>
                      widget.key.toString().contains('fleet-focus-portrait-'),
                ),
              );
              final peerPortrait = find.descendant(
                of: ships.at((i ~/ columns) * columns),
                matching: find.byWidgetPredicate(
                  (widget) =>
                      widget.key.toString().contains('fleet-focus-portrait-'),
                ),
              );
              expect(
                tester.getTopLeft(portrait).dy,
                closeTo(tester.getTopLeft(peerPortrait).dy, .1),
              );
              expect(rects[i].height, closeTo(rects.first.height, .1));
              if (i % columns > 0) {
                expect(rects[i].left, greaterThan(rects[i - 1].right));
              }
              if (i >= columns) {
                expect(rects[i].top, greaterThan(rects[i - columns].top));
              }
            }
            await tester.ensureVisible(ships.last);
            await tester.pumpAndSettle();
            openedFleet = null;
            await tester.tap(ships.last);
            expect(openedFleet, 1);
            expect(tester.takeException(), isNull);
          }
        }
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
