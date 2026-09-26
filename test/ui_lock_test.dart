import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_browser_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_browser_toolbar.dart';
import 'package:yahagi_kancolle_browser/src/fleet/dashboard_card.dart';
import 'package:yahagi_kancolle_browser/src/fleet/resource_grid.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/layout/hd_bottom_strip.dart';
import 'package:yahagi_kancolle_browser/src/layout/hd_portrait_grid.dart';
import 'package:yahagi_kancolle_browser/src/settings/display_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/display_mode_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';
import 'package:yahagi_kancolle_browser/main.dart';
import 'package:yahagi_kancolle_browser/src/settings/screen_settings_page.dart';
import 'package:yahagi_kancolle_browser/src/widgets/top_notice.dart';

class _FailingUiLockStore extends SharedPreferencesLayoutSettingsStore {
  @override
  Future<void> saveUiLocked(bool locked) async {
    throw Exception('Simulated disk write failure');
  }
}

Widget _wrapTestWidget({
  required Widget child,
  Locale locale = const Locale('zh'),
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: TopNoticeHost(child: Scaffold(body: child)),
  );
}

void main() {
  group('UI Lock Controller & Store', () {
    test('defaults to unlocked and persists when changed', () async {
      SharedPreferences.setMockInitialValues({});
      var controller = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      addTearDown(controller.dispose);
      expect(controller.uiLocked, isFalse);

      var notifications = 0;
      controller.addListener(() => notifications++);

      await controller.setUiLocked(true);
      expect(controller.uiLocked, isTrue);
      expect(notifications, 1);

      controller = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      addTearDown(controller.dispose);
      expect(controller.uiLocked, isTrue);

      await controller.toggleUiLocked();
      expect(controller.uiLocked, isFalse);
    });

    test('rolls back uiLocked state when persistence fails', () async {
      final controller = await LayoutSettingsController.load(
        _FailingUiLockStore(),
      );
      addTearDown(controller.dispose);
      expect(controller.uiLocked, isFalse);

      await expectLater(
        () => controller.setUiLocked(true),
        throwsA(isA<Exception>()),
      );
      expect(controller.uiLocked, isFalse);
    });
  });

  group('GameBrowserToolbar UI Lock Button', () {
    testWidgets('renders lock button next to reload in realWeb mode', (
      tester,
    ) async {
      var toggles = 0;
      var uiLockedState = false;

      await tester.pumpWidget(
        _wrapTestWidget(
          child: StatefulBuilder(
            builder: (context, setState) => GameBrowserToolbar(
              mode: GameBrowserMode.realWeb,
              loadState: GamePageLoadState.ready,
              displayAddress: 'https://accounts.dmm.com/login',
              onBack: () async {},
              onReload: () async {},
              onHome: () async {},
              onEnterDmm: () async {},
              isMuted: false,
              audioEnabled: true,
              onToggleMuted: () async {},
              onCollapse: () {},
              onFitScreen: () {},
              uiLocked: uiLockedState,
              onToggleUiLock: () async {
                toggles++;
                setState(() => uiLockedState = !uiLockedState);
              },
            ),
          ),
        ),
      );

      final lockButtonFinder = find.byKey(const Key('browser-ui-lock'));
      expect(lockButtonFinder, findsOneWidget);
      expect(find.byIcon(Icons.lock_open), findsOneWidget);
      expect(find.byIcon(Icons.lock), findsNothing);

      // Verify it is placed after reload button
      final reloadCenter = tester.getCenter(
        find.byKey(const Key('browser-reload')),
      );
      final lockCenter = tester.getCenter(lockButtonFinder);
      expect(lockCenter.dx, greaterThan(reloadCenter.dx));

      // Tap lock button
      await tester.tap(lockButtonFinder);
      await tester.pump();

      expect(toggles, 1);
      expect(find.byIcon(Icons.lock), findsOneWidget);
      expect(find.byIcon(Icons.lock_open), findsNothing);
    });

    testWidgets('renders lock button next to reload in local mode', (
      tester,
    ) async {
      var toggles = 0;
      var uiLockedState = false;

      await tester.pumpWidget(
        _wrapTestWidget(
          child: StatefulBuilder(
            builder: (context, setState) => GameBrowserToolbar(
              mode: GameBrowserMode.localPrototype,
              loadState: GamePageLoadState.ready,
              displayAddress: 'local://kancolle',
              onBack: () async {},
              onReload: () async {},
              onHome: () async {},
              onEnterDmm: () async {},
              isMuted: false,
              audioEnabled: true,
              onToggleMuted: () async {},
              onCollapse: () {},
              onFitScreen: () {},
              uiLocked: uiLockedState,
              onToggleUiLock: () async {
                toggles++;
                setState(() => uiLockedState = !uiLockedState);
              },
            ),
          ),
        ),
      );

      final lockButtonFinder = find.byKey(const Key('browser-ui-lock'));
      expect(lockButtonFinder, findsOneWidget);
      expect(find.byIcon(Icons.lock_open), findsOneWidget);
      expect(find.byIcon(Icons.lock), findsNothing);

      // Verify it is placed after reload button
      final reloadCenter = tester.getCenter(
        find.byKey(const Key('browser-reload')),
      );
      final lockCenter = tester.getCenter(lockButtonFinder);
      expect(lockCenter.dx, greaterThan(reloadCenter.dx));

      // Tap lock button
      await tester.tap(lockButtonFinder);
      await tester.pump();

      expect(toggles, 1);
      expect(find.byIcon(Icons.lock), findsOneWidget);
      expect(find.byIcon(Icons.lock_open), findsNothing);
    });
  });

  group('ScreenSettingsPage UI Lock Switch', () {
    testWidgets('switch reflects controller and toggles uiLocked', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final controller = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      addTearDown(controller.dispose);
      final display = await DisplayModeController.load(
        MemoryDisplayModeStore(),
      );

      await tester.pumpWidget(
        _wrapTestWidget(
          child: ScreenSettingsPage(
            layoutSettingsController: controller,
            displayModeController: display,
          ),
        ),
      );

      final switchLabelFinder = find.byKey(
        const Key('settings-ui-lock-switch'),
      );
      await tester.ensureVisible(switchLabelFinder);
      expect(switchLabelFinder, findsOneWidget);

      final row = find
          .ancestor(of: switchLabelFinder, matching: find.byType(Row))
          .first;
      final switchFinder = find.descendant(
        of: row,
        matching: find.byType(Switch),
      );
      expect(tester.widget<Switch>(switchFinder).value, isFalse);

      await tester.tap(switchFinder);
      await tester.pump();

      expect(controller.uiLocked, isTrue);
      expect(tester.widget<Switch>(switchFinder).value, isTrue);

      await controller.setUiLocked(false);
      await tester.pump();
      expect(tester.widget<Switch>(switchFinder).value, isFalse);
    });
  });

  group('Customization Prevention when UI Locked', () {
    testWidgets(
      'HdPortraitGrid ignores long press and shows toast when uiLocked',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final controller = await LayoutSettingsController.load(
          SharedPreferencesLayoutSettingsStore(),
        );
        addTearDown(controller.dispose);
        await controller.setUiLocked(true);

        var editing = false;
        await tester.pumpWidget(
          _wrapTestWidget(
            child: StatefulBuilder(
              builder: (context, setState) => HdPortraitGrid(
                controller: controller,
                editing: editing,
                onEditingChanged: (value) => setState(() => editing = value),
                cardBuilder: (id) => DashboardCard(
                  title: id,
                  icon: const Icon(Icons.info),
                  collapsed: false,
                  onToggleCollapse: () {},
                  child: const SizedBox(height: 100),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        await tester.longPress(
          find.byKey(const ValueKey('hd-portrait-cell-battle')),
        );
        await tester.pump();

        // Should still be false because uiLocked is true
        expect(editing, isFalse);
        // Feedback toast should be shown
        expect(find.byKey(topNoticeKey), findsOneWidget);

        // Now unlock and verify long press activates editing
        await controller.setUiLocked(false);
        await tester.pumpWidget(
          _wrapTestWidget(
            child: StatefulBuilder(
              builder: (context, setState) => HdPortraitGrid(
                controller: controller,
                editing: editing,
                onEditingChanged: (value) => setState(() => editing = value),
                cardBuilder: (id) => DashboardCard(
                  title: id,
                  icon: const Icon(Icons.info),
                  collapsed: false,
                  onToggleCollapse: () {},
                  child: const SizedBox(height: 100),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.longPress(
          find.byKey(const ValueKey('hd-portrait-cell-battle')),
        );
        await tester.pumpAndSettle();

        expect(editing, isTrue);
      },
    );

    testWidgets(
      'HdBottomStrip ignores long press and shows toast when uiLocked',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final controller = await LayoutSettingsController.load(
          SharedPreferencesLayoutSettingsStore(),
        );
        addTearDown(controller.dispose);
        await controller.setUiLocked(true);

        var startEditingCalled = false;
        await tester.pumpWidget(
          _wrapTestWidget(
            child: SizedBox(
              width: 800,
              height: 200,
              child: HdBottomStrip(
                controller: controller,
                editing: false,
                onStartEditing: () => startEditingCalled = true,
                moduleBuilder: (id) => Text(id),
              ),
            ),
          ),
        );

        await tester.longPress(find.byType(HdBottomStrip));
        await tester.pump();
        expect(startEditingCalled, isFalse);
        expect(find.byKey(topNoticeKey), findsOneWidget);

        // Unlock and try again
        await controller.setUiLocked(false);
        await tester.pumpWidget(
          _wrapTestWidget(
            child: SizedBox(
              width: 800,
              height: 200,
              child: HdBottomStrip(
                controller: controller,
                editing: false,
                onStartEditing: () => startEditingCalled = true,
                moduleBuilder: (id) => Text(id),
              ),
            ),
          ),
        );

        await tester.longPress(find.byType(HdBottomStrip));
        await tester.pumpAndSettle();
        expect(startEditingCalled, isTrue);
      },
    );

    testWidgets(
      'CompactResourceBar prevents long press when uiLocked and exits editing dynamically',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final controller = await LayoutSettingsController.load(
          SharedPreferencesLayoutSettingsStore(),
        );
        addTearDown(controller.dispose);
        await controller.setUiLocked(true);

        await tester.pumpWidget(
          _wrapTestWidget(
            child: SizedBox(
              width: 1000,
              height: 40,
              child: CompactResourceBar(
                state: const GameState(),
                settingsController: controller,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final timerItem = find.byKey(
          const Key('header-resource-anchorage-timer'),
        );
        expect(timerItem, findsOneWidget);

        // Long press while locked
        await tester.longPress(timerItem);
        await tester.pump();

        // Edit mode button should NOT appear
        expect(
          find.byKey(const Key('header-resource-edit-done')),
          findsNothing,
        );
        // Top notice feedback should appear
        expect(find.byKey(topNoticeKey), findsOneWidget);

        // Unlock
        await controller.setUiLocked(false);
        await tester.pumpAndSettle();

        // Long press while unlocked
        await tester.longPress(timerItem);
        await tester.pumpAndSettle();

        // Edit mode should now be active
        expect(
          find.byKey(const Key('header-resource-edit-done')),
          findsOneWidget,
        );

        // Now lock UI while still in edit mode -> should dynamically exit edit mode!
        await controller.setUiLocked(true);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('header-resource-edit-done')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'CompactResourceBar auto-closes filter dialog when uiLocked becomes true',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final controller = await LayoutSettingsController.load(
          SharedPreferencesLayoutSettingsStore(),
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _wrapTestWidget(
            child: SizedBox(
              width: 1000,
              height: 40,
              child: CompactResourceBar(
                state: const GameState(),
                settingsController: controller,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Enter edit mode
        final timerItem = find.byKey(
          const Key('header-resource-anchorage-timer'),
        );
        await tester.longPress(timerItem);
        await tester.pumpAndSettle();

        // Open filter dialog
        final filterButton = find.byKey(const Key('header-resource-filter'));
        expect(filterButton, findsOneWidget);
        await tester.tap(filterButton);
        await tester.pumpAndSettle();

        // Filter dialog should be visible (title shows "选择顶部栏显示的项目")
        expect(find.byType(Dialog), findsOneWidget);

        // Now set uiLocked to true while the dialog is open
        await controller.setUiLocked(true);
        await tester.pumpAndSettle();

        // Dialog should be automatically closed!
        expect(find.byType(Dialog), findsNothing);
        // And editing should also be exited
        expect(
          find.byKey(const Key('header-resource-edit-done')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'WorkspaceNavigation allows navigation but prevents reordering when uiLocked',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final controller = await LayoutSettingsController.load(
          SharedPreferencesLayoutSettingsStore(),
        );
        addTearDown(controller.dispose);
        await controller.setUiLocked(true);

        var selectedIndex = 0;
        await tester.pumpWidget(
          _wrapTestWidget(
            child: SizedBox(
              width: 80,
              height: 600,
              child: WorkspaceNavigation(
                controller: controller,
                selectedIndex: selectedIndex,
                onRight: false,
                onSelected: (index) => selectedIndex = index,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final fleetButton = find.byKey(const Key('workspace-nav-fleet'));
        expect(fleetButton, findsOneWidget);

        // Tap while locked
        await tester.tap(fleetButton);
        await tester.pump();

        expect(selectedIndex, 1);
        expect(find.byKey(topNoticeKey), findsNothing);

        final originalOrder = List<String>.of(controller.workspaceMenuOrder);
        await tester.longPress(fleetButton);
        await tester.pumpAndSettle();
        expect(controller.workspaceMenuOrder, originalOrder);
        expect(
          tester
              .widgetList<ReorderableDelayedDragStartListener>(
                find.byType(ReorderableDelayedDragStartListener),
              )
              .every((listener) => !listener.enabled),
          isTrue,
        );

        // Unlock
        await controller.setUiLocked(false);
        selectedIndex = 0;
        await tester.pumpWidget(
          _wrapTestWidget(
            child: SizedBox(
              width: 80,
              height: 600,
              child: WorkspaceNavigation(
                controller: controller,
                selectedIndex: selectedIndex,
                onRight: false,
                onSelected: (index) => selectedIndex = index,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap while unlocked
        await tester.tap(fleetButton);
        await tester.pumpAndSettle();

        // Should switch to fleet (index 1)
        expect(selectedIndex, 1);
      },
    );
  });
}
