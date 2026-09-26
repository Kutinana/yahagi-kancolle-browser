import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/layout/hd_bottom_strip.dart';
import 'package:yahagi_kancolle_browser/src/layout/hd_home_editor.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';

void main() {
  testWidgets(
    'home long press enters edit; drag, resize, hide and finish work',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final controller = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      final editing = ValueNotifier(false);
      addTearDown(controller.dispose);
      addTearDown(editing.dispose);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AnimatedBuilder(
              animation: Listenable.merge([controller, editing]),
              builder: (context, _) => Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: SizedBox(
                        height: 200,
                        child: HdBottomStrip(
                          controller: controller,
                          editing: editing.value,
                          onStartEditing: () => editing.value = true,
                          moduleBuilder: (id) => Center(child: Text(id)),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 300,
                    child: editing.value
                        ? DashboardEditor(
                            modules: controller.hdSettings.orderedModules
                                .where(
                                  (id) => !controller.hdSettings.activeModules
                                      .contains(id),
                                )
                                .toList(),
                            hidden: controller.hdSettings.hidden,
                            onToggle: controller.toggleHdModuleHidden,
                            onReset: controller.resetHdLayout,
                            onMove: (id, target, after) =>
                                controller.moveHdModuleToSidebar(
                                  id,
                                  target: target,
                                  after: after,
                                ),
                            onDone: () => editing.value = false,
                            cardBuilder: (id) =>
                                SizedBox(height: 70, child: Text(id)),
                          )
                        : const SizedBox(),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.byType(DropdownButton<String>), findsNothing);
      expect(find.byKey(const Key('hd-slot-layout-left')), findsNothing);
      await tester.longPress(find.byKey(const Key('hd-slot-left')));
      await tester.pumpAndSettle();
      expect(editing.value, isTrue);
      Future<void> drag(String from, String to) async {
        final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(Key(from))),
        );
        await tester.pump(const Duration(milliseconds: 600));
        await gesture.moveTo(tester.getCenter(find.byKey(Key(to))));
        await tester.pump(const Duration(milliseconds: 200));
        await gesture.up();
        await tester.pumpAndSettle();
      }

      await drag('dashboard-drag-region-fleet', 'hd-bottom-target-empty');
      expect(controller.hdSettings.activeModules, [
        'expedition',
        'repair',
        'fleet',
      ]);
      await drag('dashboard-drag-region-fleet', 'hd-bottom-target-expedition');
      expect(controller.hdSettings.activeModules.first, 'fleet');
      await drag('dashboard-drag-region-repair', 'dashboard-target-battle');
      expect(controller.hdSettings.activeModules, ['fleet', 'expedition']);
      await tester.tap(find.byKey(const Key('hd-width-fleet')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is CheckedPopupMenuItem<int> && w.value == 2,
        ),
      );
      await tester.pumpAndSettle();
      expect(controller.hdSettings.bottom.first.span, 2);
      await drag('dashboard-drag-region-expedition', 'dashboard-target-end');
      expect(controller.hdSettings.activeModules, ['fleet']);
      await tester.tap(find.byKey(const Key('hd-width-fleet')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is CheckedPopupMenuItem<int> && w.value == 3,
        ),
      );
      await tester.pumpAndSettle();
      expect(controller.hdSettings.bottom.single.span, 3);
      expect(find.byIcon(Icons.drag_indicator), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('dashboard-edit-done')));
      await tester.pumpAndSettle();
      expect(editing.value, isFalse);
      await tester.longPress(find.byKey(const Key('hd-slot-wide')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dashboard-edit-reset')));
      await tester.pumpAndSettle();
      expect(controller.hdSettings.activeModules, isEmpty);
      expect(
        controller.hdSettings.orderedModules,
        LayoutSettingsStore.defaultDashboardCardOrder,
      );
      for (var i = 0; i < 3; i++) {
        expect(find.byKey(Key('hd-empty-cell-$i')), findsOneWidget);
      }
      expect(find.text('可放置功能区'), findsNWidgets(3));
      await tester.tap(find.byKey(const Key('dashboard-edit-done')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('hd-empty-wide')), findsOneWidget);
      expect(find.text('可放置功能区'), findsOneWidget);
      await tester.longPress(find.byKey(const Key('hd-empty-wide')));
      await tester.pumpAndSettle();
      await drag('dashboard-drag-region-fleet', 'hd-empty-cell-1');
      expect(controller.hdSettings.activeModules, ['fleet']);
      expect(find.text('可放置功能区'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );
}
