import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/main.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_controller.dart';
import 'package:yahagi_kancolle_browser/src/audio/game_audio_controller.dart';
import 'package:yahagi_kancolle_browser/src/audio/game_audio_store.dart';
import 'package:yahagi_kancolle_browser/src/browser/gadget_bypass_channel.dart';
import 'package:yahagi_kancolle_browser/src/browser/gadget_bypass_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/gadget_bypass_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/workspace_menu_settings.dart';
import 'package:yahagi_kancolle_browser/src/settings/network_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/network_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/display_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/display_mode_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/senka/senka_controller.dart';
import 'package:yahagi_kancolle_browser/src/senka/senka_page.dart';
import 'package:yahagi_kancolle_browser/src/senka/senka_state.dart';
import 'package:yahagi_kancolle_browser/src/senka/senka_store.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_browser_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_toolbar_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_toolbar_display_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_screenshot_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_fullscreen_exit_dialog.dart';
import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode_store.dart';
import 'package:yahagi_kancolle_browser/src/capture/game_capture_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/game_capture_port.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_reducer.dart';
import 'package:yahagi_kancolle_browser/src/fleet/anchorage_repair_view.dart';
import 'package:yahagi_kancolle_browser/src/fleet/fleet_information_center.dart';
import 'package:yahagi_kancolle_browser/src/fleet/fleet_summary_card.dart';
import 'package:yahagi_kancolle_browser/src/fleet/land_base_summary_card.dart';
import 'package:yahagi_kancolle_browser/src/fleet/repair_summary_card.dart';
import 'package:yahagi_kancolle_browser/src/logbook/logbook_page.dart';
import 'package:yahagi_kancolle_browser/src/prototype_status_controller.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/toolbox_page.dart';
import 'package:yahagi_kancolle_browser/src/development/equipment_development_page.dart';
import 'package:yahagi_kancolle_browser/src/widgets/top_notice.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_completion_feedback.dart';
import 'fixtures/kcsapi_fixtures.dart';

Future<void> _tapWorkspaceNavigationItem(
  WidgetTester tester,
  String destinationId,
) async {
  final item = find.byKey(Key('workspace-nav-$destinationId'));
  final navigation = find.byKey(const Key('workspace-navigation-list'));
  await tester.dragUntilVisible(item, navigation, const Offset(0, -50));
  await tester.drag(navigation, const Offset(0, -50));
  await tester.pump();
  await tester.tap(item);
}

void main() {
  testWidgets('backup maintenance preserves shell and restarts game surface', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final timersWereDisabled = GameStateController.disableTimerForTest;
    GameStateController.disableTimerForTest = true;
    addTearDown(
      () => GameStateController.disableTimerForTest = timersWereDisabled,
    );
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final maintenance = ValueNotifier<Widget?>(null);
    final game = GameStateController();
    final toolbar = GameToolbarController();
    final capture = GameCaptureController();
    final battle = BattleController(gameState: () => game.state);
    final layout = await LayoutSettingsController.load(
      _MemoryLayoutSettingsStore(),
    );
    addTearDown(maintenance.dispose);
    addTearDown(game.dispose);
    addTearDown(toolbar.dispose);
    addTearDown(capture.dispose);
    addTearDown(battle.dispose);
    addTearDown(layout.dispose);
    var surfaceDisposals = 0;
    await tester.pumpWidget(
      YahagiApp(
        layoutSettingsController: layout,
        networkSettingsController: NetworkSettingsController(
          store: _MemoryNetworkSettingsStore(),
        ),
        gadgetBypassController: GadgetBypassController(
          store: _MemoryGadgetBypassStore(),
          port: _FakeGadgetBypassPort(),
        ),
        safetySettingsController: await SafetySettingsController.load(
          MemorySafetySettingsStore(),
        ),
        displayModeController: await DisplayModeController.load(
          MemoryDisplayModeStore(),
        ),
        controller: PrototypeStatusController(),
        browserController: GameBrowserController(port: _NoopBrowserPort()),
        captureModeController: await CaptureModeController.load(
          _MemoryModeStore(),
        ),
        gameCaptureController: capture,
        gameStateController: game,
        battleController: battle,
        audioController: await GameAudioController.load(_MemoryAudioStore()),
        toolbarController: toolbar,
        gameSurface: _LifecycleProbe(onDispose: () => surfaceDisposals++),
        backupMaintenanceOverlay: maintenance,
      ),
    );
    await tester.pumpAndSettle();
    final shellState = tester.state(find.byType(YahagiShell));
    maintenance.value = const Scaffold(body: Text('Recovering backup'));
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(YahagiShell)), same(shellState));
    expect(surfaceDisposals, 1);
    expect(find.text('Recovering backup'), findsOneWidget);
    maintenance.value = null;
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(YahagiShell)), same(shellState));
    expect(find.byType(_LifecycleProbe), findsOneWidget);
  });

  testWidgets('quest listener survives navigation and orientation changes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final timersWereDisabled = GameStateController.disableTimerForTest;
    GameStateController.disableTimerForTest = true;
    addTearDown(
      () => GameStateController.disableTimerForTest = timersWereDisabled,
    );
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final game = GameStateController();
    final toolbar = GameToolbarController();
    final capture = GameCaptureController();
    final battle = BattleController(gameState: () => game.state);
    final layout = await LayoutSettingsController.load(
      _MemoryLayoutSettingsStore(),
    );
    addTearDown(game.dispose);
    addTearDown(toolbar.dispose);
    addTearDown(capture.dispose);
    addTearDown(battle.dispose);
    addTearDown(layout.dispose);
    await tester.pumpWidget(
      YahagiApp(
        layoutSettingsController: layout,
        networkSettingsController: NetworkSettingsController(
          store: _MemoryNetworkSettingsStore(),
        ),
        gadgetBypassController: GadgetBypassController(
          store: _MemoryGadgetBypassStore(),
          port: _FakeGadgetBypassPort(),
        ),
        safetySettingsController: await SafetySettingsController.load(
          MemorySafetySettingsStore(),
        ),
        displayModeController: await DisplayModeController.load(
          MemoryDisplayModeStore(),
        ),
        controller: PrototypeStatusController(),
        browserController: GameBrowserController(port: _NoopBrowserPort()),
        captureModeController: await CaptureModeController.load(
          _MemoryModeStore(),
        ),
        gameCaptureController: capture,
        gameStateController: game,
        battleController: battle,
        audioController: await GameAudioController.load(_MemoryAudioStore()),
        toolbarController: toolbar,
        gameSurface: const SizedBox.expand(),
      ),
    );
    await tester.pumpAndSettle();
    final listener = tester.state(find.byType(QuestCompletionFeedback));
    game.accept(
      kcsapiEvent('/kcsapi/api_get_member/questlist', {
        'api_count': 1,
        'api_page_count': 1,
        'api_exec_count': 1,
        'api_list': [
          {
            'api_no': 9001,
            'api_title': '切页同时完成',
            'api_detail': '',
            'api_category': 1,
            'api_type': 4,
            'api_state': 3,
            'api_progress_flag': 0,
          },
        ],
      }, capturedAt: DateTime.now().toUtc()),
    );
    await game.idle;
    tester
        .widget<WorkspaceNavigation>(find.byType(WorkspaceNavigation))
        .onSelected(5);
    await tester.pumpAndSettle();
    expect(find.text('任务达成：切页同时完成'), findsOneWidget);
    expect(tester.state(find.byType(QuestCompletionFeedback)), same(listener));
    tester.view.physicalSize = const Size(844, 390);
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(QuestCompletionFeedback)), same(listener));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'HD is opt-in, keeps a single row and preserves game across toggles and rotation',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 700);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final toolbar = GameToolbarController();
      final capture = GameCaptureController();
      final state = GameStateController();
      final battle = BattleController(gameState: () => state.state);
      addTearDown(toolbar.dispose);
      addTearDown(capture.dispose);
      addTearDown(state.dispose);
      addTearDown(battle.dispose);
      var deactivations = 0;
      var disposals = 0;
      final layout = await LayoutSettingsController.load(
        _MemoryLayoutSettingsStore(),
      );
      await tester.pumpWidget(
        YahagiApp(
          layoutSettingsController: layout,
          networkSettingsController: NetworkSettingsController(
            store: _MemoryNetworkSettingsStore(),
          ),
          gadgetBypassController: GadgetBypassController(
            store: _MemoryGadgetBypassStore(),
            port: _FakeGadgetBypassPort(),
          ),
          safetySettingsController: await SafetySettingsController.load(
            MemorySafetySettingsStore(),
          ),
          displayModeController: await DisplayModeController.load(
            MemoryDisplayModeStore(),
          ),
          controller: PrototypeStatusController(),
          browserController: GameBrowserController(port: _NoopBrowserPort()),
          captureModeController: await CaptureModeController.load(
            _MemoryModeStore(),
          ),
          gameCaptureController: capture,
          gameStateController: state,
          battleController: battle,
          audioController: await GameAudioController.load(_MemoryAudioStore()),
          toolbarController: toolbar,
          gameSurface: _LifecycleProbe(
            key: const Key('fullscreen-probe'),
            onDispose: () => disposals++,
            onDeactivate: () => deactivations++,
          ),
        ),
      );

      await tester.pumpAndSettle();
      // Keep the shell's parent fixed: layout notifications must update the
      // workspace without relying on YahagiApp rebuilding its route.
      final shell = tester.widget<YahagiShell>(find.byType(YahagiShell));
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      await tester.pumpWidget(
        MaterialApp(
          theme: app.theme,
          locale: app.locale,
          localizationsDelegates: app.localizationsDelegates,
          supportedLocales: app.supportedLocales,
          home: shell,
        ),
      );
      await tester.pumpAndSettle();
      deactivations = 0;
      disposals = 0;
      final game = find.byKey(const Key('fullscreen-probe'));
      final originalElement = tester.element(game);
      final bottom = find.byKey(const Key('hd-bottom-region'));
      for (final size in [
        const Size(800, 600),
        const Size(1280, 800),
        const Size(1024, 768),
        const Size(1440, 900),
      ]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        final oldGameRect = tester.getRect(game);
        expect(bottom, findsNothing);
        expect(find.byKey(const Key('yahagi-hd-label')), findsNothing);
        await layout.setHdEnabled(true);
        await tester.pumpAndSettle();
        expect(bottom, findsOneWidget);
        expect(find.byKey(const Key('yahagi-hd-label')), findsOneWidget);
        final wasAuto = layout.autoZoom;
        final previousRatio = layout.gameAreaRatio;
        await layout.setAutoZoom(false);
        for (final ratio in [.5, .65, .75]) {
          await layout.setGameAreaRatio(ratio);
          await tester.pumpAndSettle();
          final workspaceWidth = tester
              .getSize(find.byKey(const Key('game-workspace')))
              .width;
          final panelWidth = tester
              .getSize(find.byKey(const Key('workspace-information-panel')))
              .width;
          expect(panelWidth, closeTo((workspaceWidth - 1) * (1 - ratio), .01));
          expect(tester.getSize(bottom).height, greaterThanOrEqualTo(120));
          expect(tester.element(game), same(originalElement));
          expect(tester.takeException(), isNull);
        }
        await layout.setAutoZoom(true);
        await tester.pumpAndSettle();
        expect(layout.effectiveInformationPanelRatio, .33);
        expect(
          tester
              .getSize(find.byKey(const Key('workspace-information-panel')))
              .width,
          closeTo(
            (tester.getSize(find.byKey(const Key('game-workspace'))).width -
                    1) *
                .33,
            .01,
          ),
        );
        expect(tester.element(game), same(originalElement));
        await layout.setGameAreaRatio(previousRatio);
        await layout.setAutoZoom(wasAuto);
        await tester.pumpAndSettle();

        expect(tester.getSize(game).aspectRatio, closeTo(5 / 3, .001));
        expect(
          tester.getRect(game).bottom,
          closeTo(tester.getRect(bottom).top, .01),
        );
        final left = tester.getRect(find.byKey(const Key('hd-slot-left')));
        final previousGameSize = tester.getSize(game);
        await layout.setHdExtensionPosition('top');
        await tester.pumpAndSettle();
        expect(
          tester.getRect(bottom).bottom,
          closeTo(tester.getRect(game).top, .01),
        );
        expect(tester.getSize(game), previousGameSize);
        expect(tester.element(game), same(originalElement));
        await layout.setHdExtensionPosition('bottom');
        await tester.pumpAndSettle();
        final right = tester.getRect(find.byKey(const Key('hd-slot-right')));
        expect(left.top, right.top);
        expect(left.bottom, right.bottom);
        for (final slotKey in ['hd-slot-left', 'hd-slot-right']) {
          final slot = find.byKey(Key(slotKey));
          final card = find
              .descendant(of: slot, matching: find.byType(AnimatedSize))
              .first;
          expect(
            tester.getRect(card).top,
            closeTo(tester.getRect(slot).top, .01),
          );
          expect(
            tester.getRect(card).bottom,
            closeTo(tester.getRect(slot).bottom, .01),
          );
        }

        expect(left.width, closeTo(right.width, .01));
        expect(tester.getSize(bottom).height, greaterThanOrEqualTo(120));
        expect(tester.element(game), same(originalElement));
        await layout.setHdSplit(false);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('hd-slot-wide')), findsOneWidget);
        expect(find.byKey(const Key('hd-slot-left')), findsNothing);
        for (final module in [
          'fleet',
          'expedition',
          'repair',
          'construction',
          'quests',
        ]) {
          await layout.setHdModule('wide', module);
          await tester.pumpAndSettle();
          expect(find.byKey(Key('hd-module-content-$module')), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
        await layout.setHdSplit(true);
        await layout.setHdEnabled(false);
        await tester.pumpAndSettle();
        expect(bottom, findsNothing);
        expect(find.byKey(const Key('yahagi-hd-label')), findsNothing);
        expect(tester.getRect(game), oldGameRect);
        expect(tester.element(game), same(originalElement));
      }
      await layout.setHdEnabled(true);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('yahagi-brand-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('game-enter-fullscreen')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('hd-slot-left')), findsNothing);
      expect(tester.element(game), same(originalElement));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('hd-slot-left')), findsOneWidget);
      await layout.setInformationPanelOnLeft(true);
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(const Key('information-panel'))).right,
        lessThanOrEqualTo(tester.getRect(game).left),
      );
      for (final size in [
        const Size(600, 800),
        const Size(800, 1280),
        const Size(915, 412),
        const Size(640, 320),
        const Size(412, 915),
        const Size(393, 873),
        const Size(540, 1200),
      ]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        expect(
          bottom,
          size.width > size.height ? findsOneWidget : findsNothing,
        );
        expect(find.byKey(const Key('yahagi-hd-label')), findsOneWidget);
        expect(
          find.byKey(const Key('hd-portrait-grid')),
          size.height >= size.width ? findsOneWidget : findsNothing,
        );
        expect(tester.element(game), same(originalElement));
        expect(tester.takeException(), isNull);
      }
      await layout.setHdEnabled(false);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('hd-portrait-grid')), findsNothing);
      expect(find.byKey(const Key('yahagi-hd-label')), findsNothing);
      expect(tester.element(game), same(originalElement));
      expect(tester.takeException(), isNull);
      expect(deactivations, 0);
      expect(disposals, 0);
    },
  );

  testWidgets('fullscreen restores the same game and panel; back exits first', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      exitFullscreenSkipConfirmationKey: true,
    });
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 700);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final toolbar = GameToolbarController();
    final capture = GameCaptureController();
    final state = GameStateController();
    final battle = BattleController(gameState: () => state.state);
    addTearDown(toolbar.dispose);
    addTearDown(capture.dispose);
    addTearDown(state.dispose);
    addTearDown(battle.dispose);
    var deactivations = 0;
    var disposals = 0;
    await tester.pumpWidget(
      YahagiApp(
        layoutSettingsController: await LayoutSettingsController.load(
          _MemoryLayoutSettingsStore(),
        ),
        networkSettingsController: NetworkSettingsController(
          store: _MemoryNetworkSettingsStore(),
        ),
        gadgetBypassController: GadgetBypassController(
          store: _MemoryGadgetBypassStore(),
          port: _FakeGadgetBypassPort(),
        ),
        safetySettingsController: await SafetySettingsController.load(
          MemorySafetySettingsStore(),
        ),
        displayModeController: await DisplayModeController.load(
          MemoryDisplayModeStore(),
        ),
        controller: PrototypeStatusController(),
        browserController: GameBrowserController(port: _NoopBrowserPort()),
        captureModeController: await CaptureModeController.load(
          _MemoryModeStore(),
        ),
        gameCaptureController: capture,
        gameStateController: state,
        battleController: battle,
        audioController: await GameAudioController.load(_MemoryAudioStore()),
        toolbarController: toolbar,
        gameSurface: _LifecycleProbe(
          key: const Key('fullscreen-probe'),
          onDispose: () => disposals++,
          onDeactivate: () => deactivations++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final game = find.byKey(const Key('fullscreen-probe'));
    final gameElement = tester.element(game);
    final originalRect = tester.getRect(game);
    final panel = find.byKey(const Key('information-panel'));
    final panelElement = tester.element(panel);
    final scrollable = tester.state<ScrollableState>(
      find.descendant(of: panel, matching: find.byType(Scrollable)).first,
    );
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent / 2);
    await tester.pump();
    final offset = scrollable.position.pixels;

    await tester.tap(find.byKey(const Key('yahagi-brand-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('game-toolbar-visible')), findsOneWidget);

    for (final useBack in [false, true]) {
      await tester.tap(find.byKey(const Key('game-enter-fullscreen')));
      await tester.pumpAndSettle();
      expect(panel, findsNothing);
      expect(find.byType(WorkspaceNavigation), findsNothing);
      expect(tester.element(game), same(gameElement));
      expect(tester.getSize(game).width, greaterThan(originalRect.width));
      expect(tester.getSize(game).aspectRatio, closeTo(1200 / 720, 0.001));
      if (useBack) {
        await tester.binding.handlePopRoute();
      } else {
        await tester.tap(find.byKey(const Key('game-exit-fullscreen')));
      }
      await tester.pumpAndSettle();
      expect(tester.element(panel), same(panelElement));
      expect(tester.getRect(game), originalRect);
      expect(scrollable.position.pixels, offset);
      expect(find.byType(WorkspaceNavigation), findsOneWidget);
      expect(deactivations, 0);
      expect(disposals, 0);
    }

    // Rotate while fullscreen and verify the same surface survives both sizes.
    await tester.tap(find.byKey(const Key('game-enter-fullscreen')));
    await tester.pumpAndSettle();
    for (final size in [const Size(412, 915), const Size(915, 412)]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      final exit = tester.getRect(
        find.byKey(const Key('game-exit-fullscreen')),
      );
      expect(exit.left, greaterThanOrEqualTo(0));
      expect(exit.top, greaterThanOrEqualTo(0));
      expect(exit.right, lessThanOrEqualTo(size.width));
      expect(exit.bottom, lessThanOrEqualTo(size.height));
      expect(tester.element(game), same(gameElement));
      expect(tester.getSize(game).aspectRatio, closeTo(1200 / 720, 0.001));
      expect(panel, findsNothing);
    }
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(tester.element(panel), same(panelElement));
    expect(deactivations, 0);
    expect(disposals, 0);
  });

  test('startup restores formation memory and wires its display setting', () {
    final source = File('lib/main.dart').readAsStringSync();

    expect(source, contains('SharedPreferencesFormationMemoryStore()'));
    expect(source, contains('formationMemory: formationMemoryController'));
    expect(
      source,
      matches(
        RegExp(
          r'showLastFormationHint:\s*widget\s*'
          r'\.battlePredictionSettingsController\s*'
          r'\?\.lastFormationHintEnabled\s*\?\?\s*true',
        ),
      ),
    );
  });

  test('root workspace scaffold does not resize when the keyboard opens', () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(
      source,
      matches(RegExp(r'return Scaffold\(\s*resizeToAvoidBottomInset: false,')),
    );
  });

  test('app resume does not schedule a platform-view recovery frame', () {
    final source = File('lib/main.dart').readAsStringSync();
    final lifecycleBody = RegExp(
      r'void didChangeAppLifecycleState\(AppLifecycleState state\) \{(.*?)\n  \}',
      dotAll: true,
    ).firstMatch(source)?.group(1);

    expect(lifecycleBody, isNotNull);
    expect(lifecycleBody, isNot(contains('_scheduleWindowMetricsRecovery')));
  });

  testWidgets('foldable IME geometry does not trigger game surface recovery', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 700);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewInsets);
    final browserPort = _NoopBrowserPort();
    final captureModeController = await CaptureModeController.load(
      _MemoryModeStore(),
    );
    final toolbarController = GameToolbarController();
    final gameCaptureController = GameCaptureController();
    final gameStateController = GameStateController();
    final battleController = BattleController(
      gameState: () => gameStateController.state,
    );
    addTearDown(gameCaptureController.dispose);
    addTearDown(gameStateController.dispose);
    addTearDown(battleController.dispose);
    addTearDown(toolbarController.dispose);

    await tester.pumpWidget(
      YahagiApp(
        layoutSettingsController: await LayoutSettingsController.load(
          _MemoryLayoutSettingsStore(),
        ),
        networkSettingsController: NetworkSettingsController(
          store: _MemoryNetworkSettingsStore(),
        ),
        gadgetBypassController: GadgetBypassController(
          store: _MemoryGadgetBypassStore(),
          port: _FakeGadgetBypassPort(),
        ),
        safetySettingsController: await SafetySettingsController.load(
          MemorySafetySettingsStore(),
        ),
        displayModeController: await DisplayModeController.load(
          MemoryDisplayModeStore(),
        ),
        controller: PrototypeStatusController(),
        browserController: GameBrowserController(port: browserPort),
        captureModeController: captureModeController,
        audioController: await GameAudioController.load(_MemoryAudioStore()),
        toolbarController: toolbarController,
        gameCaptureController: gameCaptureController,
        gameStateController: gameStateController,
        battleController: battleController,
        gameSurface: const ColoredBox(color: Colors.black),
      ),
    );
    await tester.pump();
    final callsBeforeIme = browserPort.fitGameScreenCalls;

    tester.view.physicalSize = const Size(1180, 700);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump(const Duration(seconds: 1));

    expect(browserPort.fitGameScreenCalls, callsBeforeIme);

    tester.view.physicalSize = const Size(1160, 700);
    await tester.pump(const Duration(seconds: 1));

    expect(
      browserPort.fitGameScreenCalls,
      callsBeforeIme,
      reason: 'temporary foldable geometry must be ignored while IME is open',
    );

    tester.view.physicalSize = const Size(1200, 700);
    tester.view.resetViewInsets();
    await tester.pump(const Duration(seconds: 1));

    expect(browserPort.fitGameScreenCalls, callsBeforeIme);

    tester.view.physicalSize = const Size(1000, 700);
    await tester.pump(const Duration(seconds: 1));

    expect(
      browserPort.fitGameScreenCalls,
      callsBeforeIme + 4,
      reason: 'real geometry changes must retain the existing recovery passes',
    );
  });

  testWidgets('auto zoom keeps the information panel compact', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 700);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final layout = await LayoutSettingsController.load(
      _MemoryLayoutSettingsStore(),
    );
    final capture = GameCaptureController();
    final state = GameStateController();
    final battle = BattleController(gameState: () => state.state);
    final toolbar = GameToolbarController();
    addTearDown(layout.dispose);
    addTearDown(capture.dispose);
    addTearDown(state.dispose);
    addTearDown(battle.dispose);
    addTearDown(toolbar.dispose);
    await layout.setAutoZoom(true);

    await tester.pumpWidget(
      YahagiApp(
        layoutSettingsController: layout,
        networkSettingsController: NetworkSettingsController(
          store: _MemoryNetworkSettingsStore(),
        ),
        gadgetBypassController: GadgetBypassController(
          store: _MemoryGadgetBypassStore(),
          port: _FakeGadgetBypassPort(),
        ),
        safetySettingsController: await SafetySettingsController.load(
          MemorySafetySettingsStore(),
        ),
        displayModeController: await DisplayModeController.load(
          MemoryDisplayModeStore(),
        ),
        controller: PrototypeStatusController(),
        browserController: GameBrowserController(port: _NoopBrowserPort()),
        captureModeController: await CaptureModeController.load(
          _MemoryModeStore(),
        ),
        gameCaptureController: capture,
        gameStateController: state,
        battleController: battle,
        audioController: await GameAudioController.load(_MemoryAudioStore()),
        toolbarController: toolbar,
        gameSurface: const SizedBox.expand(),
      ),
    );
    await tester.pumpAndSettle();

    final workspace = find.byKey(const Key('game-workspace'));
    final panel = find.byKey(const Key('workspace-information-panel'));
    expect(
      tester.getSize(panel).width / tester.getSize(workspace).width,
      closeTo(0.33, 0.015),
    );
    expect(
      tester.getRect(find.byType(FleetSummaryCard)).left -
          tester.getRect(panel).left,
      closeTo(11, 0.01),
    );
  });

  testWidgets('shows the game surface, information panel, and capture modes', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 700);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final captureModeController = await CaptureModeController.load(
      _MemoryModeStore(),
    );
    final controller = PrototypeStatusController(
      captureEnabled: () => captureModeController.captureEnabled,
    );
    final layoutSettingsController = await LayoutSettingsController.load(
      _MemoryLayoutSettingsStore(),
    );
    final safetySettingsController = await SafetySettingsController.load(
      MemorySafetySettingsStore(),
    );
    final displayModeController = await DisplayModeController.load(
      MemoryDisplayModeStore(),
    );
    final browserController = GameBrowserController(port: _NoopBrowserPort());
    final audioController = await GameAudioController.load(_MemoryAudioStore());
    final toolbarController = GameToolbarController();
    final toolbarDisplayController = await GameToolbarDisplayController.load(
      _MemoryToolbarDisplayStore(),
    );
    final gameScreenshotController = GameScreenshotController(
      _FakeScreenshotPort(),
    );
    final gameCaptureController = GameCaptureController();
    final gameStateController = GameStateController(
      reducer: _ToolboxStateReducer(),
    );
    final battleController = BattleController(
      gameState: () => gameStateController.state,
    );
    final gameCapturePort = _FakeCapturePort(supported: true);
    await gameCaptureController.attach(gameCapturePort, enabled: true);

    await tester.pumpWidget(
      YahagiApp(
        layoutSettingsController: layoutSettingsController,
        networkSettingsController: NetworkSettingsController(
          store: _MemoryNetworkSettingsStore(),
        ),
        gadgetBypassController: GadgetBypassController(
          store: _MemoryGadgetBypassStore(),
          port: _FakeGadgetBypassPort(),
        ),
        safetySettingsController: safetySettingsController,
        displayModeController: displayModeController,
        controller: controller,
        browserController: browserController,
        captureModeController: captureModeController,
        audioController: audioController,
        toolbarController: toolbarController,
        toolbarDisplayController: toolbarDisplayController,
        gameScreenshotController: gameScreenshotController,
        gameCaptureController: gameCaptureController,
        gameStateController: gameStateController,
        battleController: battleController,
        gameSurface: const ColoredBox(
          key: Key('fake-game-surface'),
          color: Colors.black,
        ),
      ),
    );

    expect(find.byKey(const Key('fake-game-surface')), findsOneWidget);
    final gameSize = tester.getSize(find.byKey(const Key('fake-game-surface')));
    expect(gameSize.width / gameSize.height, closeTo(1200 / 720, 0.001));
    final panel = find.byKey(const Key('information-panel'));
    expect(panel, findsOneWidget);
    final workspaceWidth = tester
        .getSize(find.byKey(const Key('game-workspace')))
        .width;
    final panelWidth = tester.getSize(panel).width;
    expect(panelWidth / workspaceWidth, closeTo(0.5, 0.015));
    for (final informationRatio in <double>[0.25, 0.37, 0.5]) {
      await layoutSettingsController.setGameAreaRatio(1 - informationRatio);
      await tester.pumpAndSettle();
      expect(
        tester.getSize(panel).width / workspaceWidth,
        closeTo(informationRatio, 0.015),
      );
    }
    expect(find.text('功能面板'), findsNothing);
    expect(find.text('编辑顺序'), findsNothing);
    final collapsedBeforeEditing = List<String>.from(
      layoutSettingsController.dashboardCardCollapsed,
    );
    expect(
      tester.widget<FleetSummaryCard>(find.byType(FleetSummaryCard)).collapsed,
      isFalse,
    );
    expect(find.byType(LandBaseSummaryCard), findsOneWidget);
    await tester.longPress(find.byKey(const ValueKey('fleet')));
    await tester.pumpAndSettle();
    expect(find.byType(Checkbox), findsWidgets);
    expect(find.byType(LongPressDraggable<String>), findsWidgets);
    expect(
      find.ancestor(
        of: find.byType(FleetSummaryCard),
        matching: find.byType(LongPressDraggable<String>),
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.drag_handle), findsNothing);
    expect(
      tester.widget<FleetSummaryCard>(find.byType(FleetSummaryCard)).collapsed,
      isTrue,
    );
    final dragRegion = find.byKey(const Key('dashboard-drag-region-fleet'));
    expect(dragRegion, findsOneWidget);
    expect(tester.getSize(dragRegion).width, greaterThan(200));
    expect(
      tester.getSize(find.byType(FleetSummaryCard)).width,
      closeTo(tester.getSize(dragRegion).width - 48, 0.01),
    );
    await tester.tap(find.byKey(const Key('dashboard-edit-done')));
    await tester.pumpAndSettle();
    expect(find.byType(Checkbox), findsNothing);
    expect(
      tester.widget<FleetSummaryCard>(find.byType(FleetSummaryCard)).collapsed,
      isFalse,
    );
    expect(
      layoutSettingsController.dashboardCardCollapsed,
      collapsedBeforeEditing,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('live-battle-card')),
      200,
      scrollable: find
          .descendant(of: panel, matching: find.byType(Scrollable))
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('live-battle-card')), findsOneWidget);
    expect(find.text('未卜先知'), findsOneWidget);
    expect(find.byKey(const Key('yahagi-brand-button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('yahagi-brand-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('browser-home')), findsOneWidget);
    expect(find.byKey(const Key('game-browser-overlay')), findsOneWidget);
    expect(find.byKey(const Key('game-audio-toggle')), findsOneWidget);
    await tester.tap(find.byKey(const Key('browser-screenshot')));
    await tester.pumpAndSettle();
    expect(find.textContaining('yahagi-test.png'), findsOneWidget);
    expect(find.byKey(topNoticeKey), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(topNoticeKey),
        matching: find.byIcon(Icons.check_circle_outline_rounded),
      ),
      findsOneWidget,
    );
    TopNotice.hide(tester.element(find.byType(Scaffold).first));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('yahagi-brand-button')));
    await tester.pumpAndSettle();
    final gameSurfaceElement = tester.element(
      find.byKey(const Key('fake-game-surface')),
    );
    expect(find.byKey(const Key('game-browser-overlay')), findsOneWidget);
    expect(
      tester.element(find.byKey(const Key('fake-game-surface'))),
      same(gameSurfaceElement),
    );

    tester.view.physicalSize = const Size(900, 900);
    tester.binding.handleMetricsChanged();
    await tester.pump(const Duration(seconds: 1));
    expect(
      tester.element(find.byKey(const Key('fake-game-surface'))),
      same(gameSurfaceElement),
    );
    final unfoldedGameRect = tester.getRect(
      find.byKey(const Key('fake-game-surface')),
    );
    expect(
      unfoldedGameRect.width / unfoldedGameRect.height,
      closeTo(1200 / 720, 0.001),
    );
    expect(
      tester.getTopLeft(panel).dy,
      greaterThanOrEqualTo(unfoldedGameRect.bottom),
    );

    tester.view.physicalSize = const Size(1200, 700);
    tester.binding.handleMetricsChanged();
    await tester.pump(const Duration(seconds: 1));
    await _tapWorkspaceNavigationItem(tester, 'settings');
    await tester.pumpAndSettle();

    final settingsLabelX = tester
        .getTopLeft(find.byKey(const Key('settings-language-label')))
        .dx;
    expect(
      tester.getTopLeft(find.byKey(const Key('settings-auto-zoom-label'))).dx,
      closeTo(settingsLabelX, 0.1),
    );
    expect(find.text('应用推荐显示比例（游戏与菜单比例 67:33）'), findsOneWidget);
    expect(find.text('游戏声音'), findsOneWidget);
    expect(find.text('后台播放声音'), findsOneWidget);
    await tester.tap(find.byKey(const Key('settings-tab-1')));
    await tester.pumpAndSettle();
    expect(find.text('大破提醒'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('大破提醒')).dy,
      lessThan(tester.getTopLeft(find.text('战斗状态效果')).dy),
    );
    await tester.tap(find.byKey(const Key('settings-tab-2')));
    await tester.pumpAndSettle();
    expect(find.text('启用通知服务'), findsOneWidget);
    await tester.tap(find.byKey(const Key('settings-tab-3')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('settings-logout-label')), findsNothing);
    expect(find.textContaining('VPN 状态'), findsNothing);
    await tester.tap(find.byKey(const Key('settings-tab-4')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('settings-logout-label')));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.byKey(const Key('settings-logout-label'))).dx,
      closeTo(settingsLabelX, 0.1),
    );

    expect(find.text('游戏模式（默认）'), findsOneWidget);
    expect(find.text('纯浏览模式'), findsOneWidget);
    await tester.tap(find.byKey(const Key('settings-tab-5')));
    await tester.pumpAndSettle();
    expect(find.text('关于 ヤハギ', skipOffstage: false), findsWidgets);
    expect(find.text('诊断与关于', skipOffstage: false), findsNothing);
    expect(find.text('安全边界', skipOffstage: false), findsNothing);
    await tester.tap(find.byKey(const Key('workspace-nav-game')));
    await tester.pumpAndSettle();
    expect(find.text('资源'), findsNothing);
    for (final key in <String>[
      'workspace-nav-fleet',
      'workspace-nav-expedition',
      'workspace-nav-repair',
      'workspace-nav-construction',
      'workspace-nav-quests',
      'workspace-nav-senka',
      'workspace-nav-battle-records',
      'workspace-nav-tools',
    ]) {
      expect(find.byKey(Key(key)), findsOneWidget);
    }
    expect(
      find.descendant(
        of: find.byKey(const Key('workspace-nav-tools')),
        matching: find.byIcon(Icons.widgets_outlined),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('workspace-nav-tools')),
        matching: find.byIcon(Icons.handyman_outlined),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('workspace-nav-construction')),
        matching: find.byIcon(Icons.handyman_outlined),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('workspace-nav-tools')));
    await tester.pumpAndSettle();
    expect(find.byType(ToolboxPage), findsOneWidget);
    expect(find.text('等待母港数据'), findsOneWidget);
    gameStateController.accept(
      CapturedApiEvent(
        path: '/toolbox-state-test',
        responseBody: '{}',
        source: CaptureSource.manual,
        capturedAt: DateTime.utc(2026, 8, 31),
      ),
    );
    await gameStateController.idle;
    await tester.pumpAndSettle();
    expect(find.textContaining('"hqlv":77'), findsOneWidget);
    expect(find.byKey(const Key('toolbox-mode-tabs')), findsOneWidget);
    expect(find.text('导出数据'), findsOneWidget);
    await tester.tap(find.byKey(const Key('event-land-bases-only')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('toolbox-tab-other')));
    await tester.pumpAndSettle();
    expect(find.text('其他功能正在开发中'), findsOneWidget);
    expect(find.textContaining('"hqlv":77'), findsNothing);
    await tester.tap(find.byKey(const Key('toolbox-tab-export')));
    await tester.pumpAndSettle();
    expect(find.text('其他功能正在开发中'), findsNothing);
    expect(find.textContaining('"hqlv":77'), findsOneWidget);
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const Key('event-land-bases-only')),
          )
          .value,
      isFalse,
    );
    await tester.tap(find.byKey(const Key('workspace-nav-construction')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('construction-mode-development')));
    await tester.pump();
    expect(find.byType(EquipmentDevelopmentPage), findsOneWidget);
    gameCaptureController.dispose();
    gameStateController.dispose();
    battleController.dispose();
    await gameCapturePort.close();
    toolbarController.dispose();
  });

  testWidgets('switches to browser-only mode and shows capture is disabled', (
    tester,
  ) async {
    final captureModeController = await CaptureModeController.load(
      _MemoryModeStore(),
    );
    final controller = PrototypeStatusController(
      captureEnabled: () => captureModeController.captureEnabled,
    );
    final audioController = await GameAudioController.load(_MemoryAudioStore());
    final toolbarController = GameToolbarController();
    final gameCaptureController = GameCaptureController();
    final gameStateController = GameStateController();
    final battleController = BattleController(
      gameState: () => gameStateController.state,
    );

    await tester.pumpWidget(
      YahagiApp(
        layoutSettingsController: await LayoutSettingsController.load(
          _MemoryLayoutSettingsStore(),
        ),
        networkSettingsController: NetworkSettingsController(
          store: _MemoryNetworkSettingsStore(),
        ),
        gadgetBypassController: GadgetBypassController(
          store: _MemoryGadgetBypassStore(),
          port: _FakeGadgetBypassPort(),
        ),
        safetySettingsController: await SafetySettingsController.load(
          MemorySafetySettingsStore(),
        ),
        displayModeController: await DisplayModeController.load(
          MemoryDisplayModeStore(),
        ),
        controller: controller,
        browserController: GameBrowserController(port: _NoopBrowserPort()),
        captureModeController: captureModeController,
        audioController: audioController,
        toolbarController: toolbarController,
        gameCaptureController: gameCaptureController,
        gameStateController: gameStateController,
        battleController: battleController,
        showDeveloperDiagnostics: true,
        gameSurface: const ColoredBox(color: Colors.black),
      ),
    );
    await _tapWorkspaceNavigationItem(tester, 'settings');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settings-tab-4')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('纯浏览模式'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('纯浏览模式'));
    await tester.pumpAndSettle();

    expect(captureModeController.mode, CaptureMode.browserOnly);
    expect(find.text('纯浏览模式 · 数据捕获已关闭', skipOffstage: false), findsOneWidget);
    expect(
      find.text('纯浏览模式将在重新载入页面后停止数据捕获。', skipOffstage: false),
      findsOneWidget,
    );
    gameCaptureController.dispose();
    gameStateController.dispose();
    battleController.dispose();
    toolbarController.dispose();
  });

  testWidgets('shows capture unsupported without removing the game surface', (
    tester,
  ) async {
    final captureModeController = await CaptureModeController.load(
      _MemoryModeStore(),
    );
    final gameCaptureController = GameCaptureController();
    final gameCapturePort = _FakeCapturePort(supported: false);
    await gameCaptureController.attach(gameCapturePort, enabled: true);
    final toolbarController = GameToolbarController();
    final gameStateController = GameStateController();
    final battleController = BattleController(
      gameState: () => gameStateController.state,
    );

    await tester.pumpWidget(
      YahagiApp(
        layoutSettingsController: await LayoutSettingsController.load(
          _MemoryLayoutSettingsStore(),
        ),
        networkSettingsController: NetworkSettingsController(
          store: _MemoryNetworkSettingsStore(),
        ),
        gadgetBypassController: GadgetBypassController(
          store: _MemoryGadgetBypassStore(),
          port: _FakeGadgetBypassPort(),
        ),
        safetySettingsController: await SafetySettingsController.load(
          MemorySafetySettingsStore(),
        ),
        displayModeController: await DisplayModeController.load(
          MemoryDisplayModeStore(),
        ),
        controller: PrototypeStatusController(),
        browserController: GameBrowserController(port: _NoopBrowserPort()),
        captureModeController: captureModeController,
        gameCaptureController: gameCaptureController,
        gameStateController: gameStateController,
        battleController: battleController,
        showDeveloperDiagnostics: true,
        audioController: await GameAudioController.load(_MemoryAudioStore()),
        toolbarController: toolbarController,
        gameSurface: const ColoredBox(
          key: Key('unsupported-game-surface'),
          color: Colors.black,
        ),
      ),
    );

    expect(find.byKey(const Key('unsupported-game-surface')), findsOneWidget);
    await _tapWorkspaceNavigationItem(tester, 'settings');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-tab-4')));
    await tester.pumpAndSettle();
    expect(
      find.text('当前 WebView 不支持跨框架捕获', skipOffstage: false),
      findsOneWidget,
    );
    gameCaptureController.dispose();
    gameStateController.dispose();
    battleController.dispose();
    await gameCapturePort.close();
    toolbarController.dispose();
  });

  testWidgets('shows successful port verification for api_result one', (
    tester,
  ) async {
    final captureModeController = await CaptureModeController.load(
      _MemoryModeStore(),
    );
    final gameCaptureController = GameCaptureController();
    final gameCapturePort = _FakeCapturePort(supported: true);
    await gameCaptureController.attach(gameCapturePort, enabled: true);
    final toolbarController = GameToolbarController();
    final gameStateController = GameStateController();
    final battleController = BattleController(
      gameState: () => gameStateController.state,
    );

    await tester.pumpWidget(
      YahagiApp(
        layoutSettingsController: await LayoutSettingsController.load(
          _MemoryLayoutSettingsStore(),
        ),
        networkSettingsController: NetworkSettingsController(
          store: _MemoryNetworkSettingsStore(),
        ),
        gadgetBypassController: GadgetBypassController(
          store: _MemoryGadgetBypassStore(),
          port: _FakeGadgetBypassPort(),
        ),
        safetySettingsController: await SafetySettingsController.load(
          MemorySafetySettingsStore(),
        ),
        displayModeController: await DisplayModeController.load(
          MemoryDisplayModeStore(),
        ),
        controller: PrototypeStatusController(),
        browserController: GameBrowserController(port: _NoopBrowserPort()),
        captureModeController: captureModeController,
        gameCaptureController: gameCaptureController,
        gameStateController: gameStateController,
        battleController: battleController,
        showDeveloperDiagnostics: true,
        audioController: await GameAudioController.load(_MemoryAudioStore()),
        toolbarController: toolbarController,
        gameSurface: const ColoredBox(color: Colors.black),
      ),
    );
    gameCapturePort.emit(
      CapturedApiEvent(
        path: '/kcsapi/api_port/port',
        responseBody: '{"api_result":1}',
        source: CaptureSource.xhr,
        capturedAt: DateTime.utc(2026, 7, 30),
      ),
    );
    await tester.pump();

    await _tapWorkspaceNavigationItem(tester, 'settings');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-tab-4')));
    await tester.pumpAndSettle();
    expect(find.text('母港接口验证通过', skipOffstage: false), findsOneWidget);
    gameCaptureController.dispose();
    gameStateController.dispose();
    battleController.dispose();
    await gameCapturePort.close();
    toolbarController.dispose();
  });

  testWidgets('moves the workspace menu without disposing the game surface', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 720);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final layoutSettingsController = await LayoutSettingsController.load(
      _MemoryLayoutSettingsStore(),
    );
    final captureModeController = await CaptureModeController.load(
      _MemoryModeStore(),
    );
    final gameStateController = GameStateController();
    final senkaStore = _MemorySenkaStore(
      SenkaState.forMonth('2026-08').copyWith(
        rankingHistory: {
          'player': [
            SenkaRankingSnapshot(
              rank: 370,
              senka: 1120,
              capturedAt: DateTime.utc(2026, 8, 11),
              localSenkaAtCapture: 0,
            ),
          ],
        },
      ),
    );
    final senkaController = SenkaController(
      store: senkaStore,
      now: () => DateTime.utc(2026, 8, 11),
    );
    await senkaController.initialize();
    final toolbarController = GameToolbarController();
    var disposeCount = 0;
    var deactivateCount = 0;

    await tester.pumpWidget(
      YahagiApp(
        layoutSettingsController: layoutSettingsController,
        networkSettingsController: NetworkSettingsController(
          store: _MemoryNetworkSettingsStore(),
        ),
        gadgetBypassController: GadgetBypassController(
          store: _MemoryGadgetBypassStore(),
          port: _FakeGadgetBypassPort(),
        ),
        safetySettingsController: await SafetySettingsController.load(
          MemorySafetySettingsStore(),
        ),
        displayModeController: await DisplayModeController.load(
          MemoryDisplayModeStore(),
        ),
        controller: PrototypeStatusController(),
        browserController: GameBrowserController(port: _NoopBrowserPort()),
        captureModeController: captureModeController,
        gameCaptureController: GameCaptureController(),
        gameStateController: gameStateController,
        senkaController: senkaController,
        battleController: BattleController(
          gameState: () => gameStateController.state,
        ),
        audioController: await GameAudioController.load(_MemoryAudioStore()),
        toolbarController: toolbarController,
        gameSurface: _LifecycleProbe(
          key: const Key('side-switch-game-surface'),
          onDispose: () => disposeCount++,
          onDeactivate: () => deactivateCount++,
        ),
      ),
    );

    expect(
      find.descendant(
        of: find.byKey(const Key('workspace-nav-senka')),
        matching: find.byIcon(Icons.emoji_events_outlined),
      ),
      findsOneWidget,
    );
    expect(find.text('战果：1120（#370）'), findsOneWidget);
    senkaStore.state = SenkaState.forMonth('2026-08').copyWith(
      rankingHistory: {
        'player': [
          SenkaRankingSnapshot(
            rank: 365,
            senka: 1138,
            capturedAt: DateTime.utc(2026, 8, 11, 1),
            localSenkaAtCapture: 0,
          ),
        ],
      },
    );
    await senkaController.initialize();
    await tester.pump();
    expect(find.text('战果：1138（#365）'), findsOneWidget);
    final menuButton = find.byKey(const Key('workspace-nav-game'));
    final gameSurface = find.byKey(const Key('side-switch-game-surface'));
    final originalGameSurfaceElement = tester.element(gameSurface);
    expect(
      tester.getCenter(menuButton).dx,
      lessThan(tester.getCenter(gameSurface).dx),
    );

    for (final size in <Size>[
      const Size(900, 700),
      const Size(1280, 720),
      const Size(700, 900),
      const Size(1400, 720),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      expect(disposeCount, 0);
      expect(deactivateCount, 0);
      expect(tester.element(gameSurface), same(originalGameSurfaceElement));
      final renderedGameSize = tester.getSize(gameSurface);
      expect(
        renderedGameSize.width / renderedGameSize.height,
        closeTo(1200 / 720, 0.001),
      );
    }

    final informationPanel = find.byKey(
      const Key('workspace-information-panel'),
    );
    for (final menuOnRight in <bool>[false, true]) {
      await layoutSettingsController.setWorkspaceMenuOnRight(menuOnRight);
      for (final onLeft in <bool>[true, false]) {
        await layoutSettingsController.setInformationPanelOnLeft(onLeft);
        await tester.pumpAndSettle();
        final panelRect = tester.getRect(informationPanel);
        final gameRect = tester.getRect(gameSurface);
        if (onLeft) {
          expect(panelRect.right, lessThanOrEqualTo(gameRect.left));
        } else {
          expect(panelRect.left, greaterThanOrEqualTo(gameRect.right));
        }
        expect(disposeCount, 0);
        expect(deactivateCount, 0);
        expect(tester.element(gameSurface), same(originalGameSurfaceElement));
        expect(tester.takeException(), isNull);
      }
    }
    await layoutSettingsController.setInformationPanelOnLeft(true);
    tester.view.physicalSize = const Size(700, 900);
    await tester.pumpAndSettle();
    final verticalPanelRect = tester.getRect(informationPanel);
    final verticalGameRect = tester.getRect(gameSurface);
    final verticalNavigationRect = tester.getRect(
      find.byType(WorkspaceNavigation),
    );
    expect(verticalGameRect.width, closeTo(700, 0.01));
    expect(
      verticalPanelRect.top,
      greaterThanOrEqualTo(verticalGameRect.bottom),
    );
    expect(verticalNavigationRect.top, verticalPanelRect.top);
    expect(verticalNavigationRect.bottom, verticalPanelRect.bottom);
    expect(
      verticalNavigationRect.left,
      greaterThanOrEqualTo(verticalPanelRect.right),
    );
    tester.view.physicalSize = const Size(1400, 720);
    await layoutSettingsController.setInformationPanelOnLeft(false);
    await tester.pumpAndSettle();

    await layoutSettingsController.setWorkspaceMenuOnRight(true);
    await tester.pumpAndSettle();

    expect(
      tester.getCenter(menuButton).dx,
      greaterThan(tester.getCenter(gameSurface).dx),
    );
    expect(disposeCount, 0);

    for (final hd in [false, true]) {
      await layoutSettingsController.setHdEnabled(hd);
      for (final size in [const Size(800, 1280), const Size(1280, 800)]) {
        tester.view.physicalSize = size;
        for (final position in ['top', 'bottom', 'left', 'right']) {
          await layoutSettingsController.setWorkspaceMenuPosition(position);
          await tester.pumpAndSettle();
          final nav = tester.getRect(find.byType(WorkspaceNavigation));
          final surface = tester.getRect(gameSurface);
          if (position == 'top' || position == 'bottom') {
            expect(
              nav.height,
              workspaceNavigationExtent(
                layoutSettingsController.workspaceMenuSize,
              ),
            );
            final count = layoutSettingsController.workspaceMenuOrder.length;
            if (nav.width >= count * 50 + 20) {
              final first = tester.getRect(
                find.byKey(
                  ValueKey(
                    'workspace-nav-item-${layoutSettingsController.workspaceMenuOrder.first}',
                  ),
                ),
              );
              final last = tester.getRect(
                find.byKey(
                  ValueKey(
                    'workspace-nav-item-${layoutSettingsController.workspaceMenuOrder.last}',
                  ),
                ),
              );
              expect(
                first.left - nav.left,
                closeTo(nav.right - last.right, .01),
              );
            }

            expect(nav.top, greaterThanOrEqualTo(surface.bottom - .01));
            expect(
              tester
                  .widget<ReorderableListView>(
                    find.byKey(const Key('workspace-navigation-list')),
                  )
                  .scrollDirection,
              Axis.horizontal,
            );
            if (position == 'top' && size.height > size.width) {
              expect(
                nav.bottom,
                lessThanOrEqualTo(tester.getRect(informationPanel).top),
              );
            }
          }
          expect(tester.element(gameSurface), same(originalGameSurfaceElement));
          expect(disposeCount, 0);
          expect(deactivateCount, 0);
          expect(tester.takeException(), isNull);
        }
      }
    }
    await layoutSettingsController.setHdEnabled(false);
    await layoutSettingsController.setWorkspaceMenuOnRight(true);
    tester.view.physicalSize = const Size(1400, 720);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('header-senka-summary')));
    await tester.pumpAndSettle();

    expect(find.byType(SenkaPage), findsOneWidget);
    final senkaButton = tester.widget<IconButton>(
      find.descendant(
        of: find.byKey(const Key('workspace-nav-senka')),
        matching: find.byType(IconButton),
      ),
    );
    expect(
      senkaButton.style?.backgroundColor?.resolve(<WidgetState>{}),
      const Color(0xff2b2c22),
    );

    await tester.tap(find.byKey(const Key('senka-recent-records')));
    await tester.pumpAndSettle();

    expect(find.byType(LogbookPage), findsOneWidget);
    expect(find.byKey(const Key('logbook-table-sortie')), findsOneWidget);

    senkaController.dispose();
    toolbarController.dispose();
  });

  testWidgets('switches to fleet center without disposing the game surface', (
    tester,
  ) async {
    final captureModeController = await CaptureModeController.load(
      _MemoryModeStore(),
    );
    final gameCaptureController = GameCaptureController();
    final gameStateController = GameStateController(
      reducer: _RepairNavigationReducer(),
    );
    gameStateController.accept(
      CapturedApiEvent(
        path: '/repair-navigation-test',
        responseBody: '{}',
        source: CaptureSource.manual,
        capturedAt: DateTime.utc(2026, 8, 7),
      ),
    );
    await gameStateController.idle;
    final battleController = BattleController(
      gameState: () => gameStateController.state,
    );
    final toolbarController = GameToolbarController();
    var disposeCount = 0;

    await tester.pumpWidget(
      YahagiApp(
        layoutSettingsController: await LayoutSettingsController.load(
          _MemoryLayoutSettingsStore(),
        ),
        networkSettingsController: NetworkSettingsController(
          store: _MemoryNetworkSettingsStore(),
        ),
        gadgetBypassController: GadgetBypassController(
          store: _MemoryGadgetBypassStore(),
          port: _FakeGadgetBypassPort(),
        ),
        safetySettingsController: await SafetySettingsController.load(
          MemorySafetySettingsStore(),
        ),
        displayModeController: await DisplayModeController.load(
          MemoryDisplayModeStore(),
        ),
        controller: PrototypeStatusController(),
        browserController: GameBrowserController(port: _NoopBrowserPort()),
        captureModeController: captureModeController,
        gameCaptureController: gameCaptureController,
        gameStateController: gameStateController,
        battleController: battleController,
        audioController: await GameAudioController.load(_MemoryAudioStore()),
        toolbarController: toolbarController,
        gameSurface: _LifecycleProbe(
          key: const Key('persistent-game-surface'),
          onDispose: () => disposeCount++,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('workspace-nav-fleet')));
    await tester.pumpAndSettle();

    expect(find.text('舰队'), findsOneWidget);
    expect(
      find.byKey(const Key('persistent-game-surface'), skipOffstage: false),
      findsOneWidget,
    );
    expect(disposeCount, 0);

    await tester.tap(find.byKey(const Key('workspace-nav-expedition')));
    await tester.pumpAndSettle();
    expect(find.text('远征'), findsOneWidget);

    await tester.tap(find.byKey(const Key('workspace-nav-repair')));
    await tester.pumpAndSettle();
    expect(find.text('入渠修理'), findsOneWidget);
    expect(find.text('泊地修理'), findsOneWidget);

    await tester.tap(find.byKey(const Key('repair-mode-anchorage')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('workspace-nav-game')));
    await tester.pumpAndSettle();
    final repairCard = find.byType(RepairSummaryCard);
    await tester.scrollUntilVisible(
      repairCard,
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('information-panel')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    tester
        .widget<RepairSummaryCard>(repairCard)
        .onOpenRepair(
          const RepairDestination(mode: RepairCenterMode.anchorage, fleetId: 2),
        );
    await tester.pumpAndSettle();
    var repairCenter = tester.widget<FleetInformationCenter>(
      find.byType(FleetInformationCenter),
    );
    expect(repairCenter.repairMode, RepairCenterMode.anchorage);
    expect(repairCenter.initialFleetId, 2);

    tester
        .widget<FleetSwitcherBar>(find.byType(FleetSwitcherBar))
        .onFleetSelected!(1);
    await tester.pumpAndSettle();
    repairCenter = tester.widget<FleetInformationCenter>(
      find.byType(FleetInformationCenter),
    );
    expect(repairCenter.initialFleetId, 1);

    await tester.tap(find.byKey(const Key('workspace-nav-construction')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('workspace-nav-repair')));
    await tester.pumpAndSettle();
    repairCenter = tester.widget<FleetInformationCenter>(
      find.byType(FleetInformationCenter),
    );
    expect(repairCenter.repairMode, RepairCenterMode.anchorage);
    expect(repairCenter.initialFleetId, 1);

    await tester.tap(find.byKey(const Key('workspace-nav-game')));
    await tester.pumpAndSettle();
    tester
        .widget<RepairSummaryCard>(repairCard)
        .onOpenRepair(const RepairDestination(mode: RepairCenterMode.dock));
    await tester.pumpAndSettle();
    repairCenter = tester.widget<FleetInformationCenter>(
      find.byType(FleetInformationCenter),
    );
    expect(repairCenter.repairMode, RepairCenterMode.dock);
    expect(repairCenter.initialFleetId, isNull);
    final dockTab = tester.widget<Material>(
      find.descendant(
        of: find.byKey(const Key('repair-mode-dock')),
        matching: find.byType(Material),
      ),
    );
    expect(dockTab.color, const Color(0xff8a6628));

    await tester.tap(find.byKey(const Key('workspace-nav-construction')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(find.byKey(const Key('workspace-title-construction')))
          .data,
      '建造',
    );

    await tester.tap(find.byKey(const Key('workspace-nav-quests')));
    await tester.pumpAndSettle();
    expect(find.text('任务'), findsOneWidget);

    await tester.tap(find.byKey(const Key('workspace-nav-battle-records')));
    await tester.pumpAndSettle();

    expect(find.text('出击'), findsOneWidget);
    expect(find.text('远征'), findsOneWidget);
    expect(find.text('建造'), findsWidgets);
    expect(find.text('开发'), findsOneWidget);
    expect(find.text('除籍'), findsOneWidget);
    expect(find.text('资源'), findsOneWidget);
    expect(
      find.byKey(const Key('persistent-game-surface'), skipOffstage: false),
      findsOneWidget,
    );
    expect(disposeCount, 0);

    await tester.tap(find.byKey(const Key('workspace-nav-game')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('information-panel')), findsOneWidget);
    expect(disposeCount, 0);

    await tester.tap(find.byKey(const Key('header-resource-anchorage-timer')));
    await tester.pumpAndSettle();

    final anchorageCenter = tester.widget<FleetInformationCenter>(
      find.byType(FleetInformationCenter),
    );
    expect(anchorageCenter.repairMode, RepairCenterMode.anchorage);
    expect(anchorageCenter.initialFleetId, 1);

    gameCaptureController.dispose();
    gameStateController.dispose();
    battleController.dispose();
    toolbarController.dispose();
  });

  testWidgets(
    'brand virtual button is only interactive on game workspace and collapses on navigation',
    (tester) async {
      final captureModeController = await CaptureModeController.load(
        _MemoryModeStore(),
      );
      final controller = PrototypeStatusController(
        captureEnabled: () => captureModeController.captureEnabled,
      );
      final layoutSettingsController = await LayoutSettingsController.load(
        _MemoryLayoutSettingsStore(),
      );
      final safetySettingsController = await SafetySettingsController.load(
        MemorySafetySettingsStore(),
      );
      final displayModeController = await DisplayModeController.load(
        MemoryDisplayModeStore(),
      );
      final browserController = GameBrowserController(port: _NoopBrowserPort());
      final audioController = await GameAudioController.load(
        _MemoryAudioStore(),
      );
      final toolbarController = GameToolbarController();
      final toolbarDisplayController = await GameToolbarDisplayController.load(
        _MemoryToolbarDisplayStore(),
      );
      final gameCaptureController = GameCaptureController();
      final gameStateController = GameStateController();
      final battleController = BattleController(
        gameState: () => gameStateController.state,
      );

      await tester.pumpWidget(
        YahagiApp(
          layoutSettingsController: layoutSettingsController,
          networkSettingsController: NetworkSettingsController(
            store: _MemoryNetworkSettingsStore(),
          ),
          gadgetBypassController: GadgetBypassController(
            store: _MemoryGadgetBypassStore(),
            port: _FakeGadgetBypassPort(),
          ),
          safetySettingsController: safetySettingsController,
          displayModeController: displayModeController,
          controller: controller,
          browserController: browserController,
          captureModeController: captureModeController,
          audioController: audioController,
          toolbarController: toolbarController,
          toolbarDisplayController: toolbarDisplayController,
          gameCaptureController: gameCaptureController,
          gameStateController: gameStateController,
          battleController: battleController,
          gameSurface: const ColoredBox(
            key: Key('fake-game-surface'),
            color: Colors.black,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // On Game workspace (index 0)
      final brandButtonFinder = find.byKey(const Key('yahagi-brand-button'));
      expect(brandButtonFinder, findsOneWidget);
      final brandInkWell0 = tester.widget<InkWell>(brandButtonFinder);
      expect(brandInkWell0.onTap, isNotNull);
      expect(
        find.descendant(
          of: brandButtonFinder,
          matching: find.byIcon(Icons.chevron_right),
        ),
        findsOneWidget,
      );

      // Tap to expand toolbar
      await tester.tap(brandButtonFinder);
      await tester.pumpAndSettle();
      expect(toolbarController.isVisible, isTrue);
      expect(find.byKey(const Key('game-toolbar-visible')), findsOneWidget);
      expect(
        find.descendant(
          of: brandButtonFinder,
          matching: find.byIcon(Icons.chevron_left),
        ),
        findsOneWidget,
      );

      // Tap again to collapse the toolbar manually.
      await tester.tap(brandButtonFinder);
      await tester.pumpAndSettle();
      expect(toolbarController.isVisible, isFalse);
      expect(find.byKey(const Key('game-toolbar-visible')), findsNothing);
      expect(
        find.descendant(
          of: brandButtonFinder,
          matching: find.byIcon(Icons.chevron_right),
        ),
        findsOneWidget,
      );

      // Expand again before verifying navigation still collapses it.
      await tester.tap(brandButtonFinder);
      await tester.pumpAndSettle();
      expect(toolbarController.isVisible, isTrue);

      // Switch to fleet workspace (index 1)
      await tester.tap(find.byKey(const Key('workspace-nav-fleet')));
      await tester.pumpAndSettle();
      expect(toolbarController.isVisible, isFalse);
      expect(find.byKey(const Key('game-toolbar-visible')), findsNothing);

      // On non-game workspace, brand button is disabled and chevron is hidden
      final brandInkWell1 = tester.widget<InkWell>(brandButtonFinder);
      expect(brandInkWell1.onTap, isNull);
      expect(
        find.descendant(
          of: brandButtonFinder,
          matching: find.byIcon(Icons.chevron_right),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: brandButtonFinder,
          matching: find.byIcon(Icons.chevron_left),
        ),
        findsNothing,
      );

      // Switch back to game workspace (index 0)
      await tester.tap(find.byKey(const Key('workspace-nav-game')));
      await tester.pumpAndSettle();
      final brandInkWellGame = tester.widget<InkWell>(brandButtonFinder);
      expect(brandInkWellGame.onTap, isNotNull);
      expect(
        find.descendant(
          of: brandButtonFinder,
          matching: find.byIcon(Icons.chevron_right),
        ),
        findsOneWidget,
      );

      gameStateController.dispose();
      toolbarController.dispose();
    },
  );

  testWidgets(
    'split-screen: forced portrait and landscape switch layout without window resizing',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.devicePixelRatio = 1;
      // Start with a wide window geometry (split-screen: 800 x 500)
      tester.view.physicalSize = const Size(800, 500);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final displayStore = MemoryDisplayModeStore(DisplayMode.auto);
      final displayController = await DisplayModeController.load(displayStore);
      final browserPort = _NoopBrowserPort();
      final browserController = GameBrowserController(port: browserPort);
      final layout = await LayoutSettingsController.load(
        _MemoryLayoutSettingsStore(),
      );
      // Disable HD so that landscape layout uses the standard vertical divider
      await layout.setHdEnabled(false);

      final toolbar = GameToolbarController();
      final capture = GameCaptureController();
      final state = GameStateController();
      final battle = BattleController(gameState: () => state.state);
      addTearDown(toolbar.dispose);
      addTearDown(capture.dispose);
      addTearDown(state.dispose);
      addTearDown(battle.dispose);
      addTearDown(displayController.dispose);
      addTearDown(layout.dispose);

      var deactivations = 0;
      var disposals = 0;
      const probeKey = Key('split-screen-orientation-probe');

      await tester.pumpWidget(
        YahagiApp(
          layoutSettingsController: layout,
          networkSettingsController: NetworkSettingsController(
            store: _MemoryNetworkSettingsStore(),
          ),
          gadgetBypassController: GadgetBypassController(
            store: _MemoryGadgetBypassStore(),
            port: _FakeGadgetBypassPort(),
          ),
          safetySettingsController: await SafetySettingsController.load(
            MemorySafetySettingsStore(),
          ),
          displayModeController: displayController,
          controller: PrototypeStatusController(),
          browserController: browserController,
          captureModeController: await CaptureModeController.load(
            _MemoryModeStore(),
          ),
          gameCaptureController: capture,
          gameStateController: state,
          battleController: battle,
          audioController: await GameAudioController.load(_MemoryAudioStore()),
          toolbarController: toolbar,
          gameSurface: _LifecycleProbe(
            key: probeKey,
            onDispose: () => disposals++,
            onDeactivate: () => deactivations++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final originalElement = tester.element(find.byKey(probeKey));
      deactivations = 0;
      disposals = 0;

      // 1. Wide split-screen window with auto mode -> Landscape layout (VerticalDivider)
      expect(find.byType(VerticalDivider), findsOneWidget);
      expect(find.byType(Divider), findsNothing);
      expect(deactivations, 0);
      expect(disposals, 0);

      final initialFitCalls = browserPort.fitGameScreenCalls;

      // 2. Force Portrait in split-screen (window size stays 800x500!)
      await displayController.setDisplayMode(DisplayMode.portrait);
      await tester.pumpAndSettle();

      // Layout switches to portrait/vertical layout (Divider)
      expect(find.byType(Divider), findsOneWidget);
      expect(find.byType(VerticalDivider), findsNothing);
      expect(browserPort.fitGameScreenCalls, greaterThan(initialFitCalls));
      expect(
        deactivations,
        0,
        reason: 'PlatformView must not deactivate on portrait switch',
      );
      expect(
        disposals,
        0,
        reason: 'PlatformView must not dispose on portrait switch',
      );
      expect(tester.element(find.byKey(probeKey)), same(originalElement));

      for (final position in ['top', 'bottom']) {
        await layout.setWorkspaceMenuPosition(position);
        await tester.pumpAndSettle();

        final gameRect = tester.getRect(find.byKey(probeKey));
        final navigationRect = tester.getRect(find.byType(WorkspaceNavigation));
        expect(
          gameRect.bottom,
          lessThanOrEqualTo(navigationRect.top + 0.01),
          reason:
              '$position menu must reduce the game viewport instead of clipping its bottom edge',
        );
        expect(gameRect.width / gameRect.height, closeTo(1200 / 720, 0.001));
        expect(tester.element(find.byKey(probeKey)), same(originalElement));
        expect(deactivations, 0);
        expect(disposals, 0);
      }
      await layout.setWorkspaceMenuPosition('left');
      await tester.pumpAndSettle();

      // 3. Tall split-screen window (400 x 800)
      tester.view.physicalSize = const Size(400, 800);
      await displayController.setDisplayMode(DisplayMode.auto);
      await tester.pumpAndSettle();

      // Auto on tall window -> Portrait layout (Divider)
      expect(find.byType(Divider), findsOneWidget);
      expect(find.byType(VerticalDivider), findsNothing);
      expect(deactivations, 0);
      expect(disposals, 0);
      expect(tester.element(find.byKey(probeKey)), same(originalElement));

      final fitCallsBeforeLandscape = browserPort.fitGameScreenCalls;

      // 4. Force Landscape in split-screen (window size stays 400x800!)
      await displayController.setDisplayMode(DisplayMode.landscape);
      await tester.pumpAndSettle();

      // Layout switches to landscape layout (VerticalDivider)
      expect(find.byType(VerticalDivider), findsOneWidget);
      expect(find.byType(Divider), findsNothing);
      expect(
        browserPort.fitGameScreenCalls,
        greaterThan(fitCallsBeforeLandscape),
      );
      expect(
        deactivations,
        0,
        reason: 'PlatformView must not deactivate on landscape switch',
      );
      expect(
        disposals,
        0,
        reason: 'PlatformView must not dispose on landscape switch',
      );
      expect(tester.element(find.byKey(probeKey)), same(originalElement));

      // 5. Continuous rapid switching in split-screen (portrait -> auto -> landscape -> auto)
      for (final mode in [
        DisplayMode.portrait,
        DisplayMode.auto,
        DisplayMode.landscape,
        DisplayMode.portrait,
        DisplayMode.auto,
      ]) {
        final previousCalls = browserPort.fitGameScreenCalls;
        await displayController.setDisplayMode(mode);
        await tester.pumpAndSettle();

        expect(
          deactivations,
          0,
          reason:
              'Continuous switching to $mode must never deactivate PlatformView',
        );
        expect(
          disposals,
          0,
          reason:
              'Continuous switching to $mode must never dispose PlatformView',
        );
        expect(tester.element(find.byKey(probeKey)), same(originalElement));
        expect(browserPort.fitGameScreenCalls, greaterThan(previousCalls));
      }
    },
  );
}

class _RepairNavigationReducer extends GameStateReducer {
  @override
  GameState reduce(GameState state, CapturedApiEvent event) => const GameState(
    fleets: <Fleet>[
      Fleet(id: 1, name: '第一舰队'),
      Fleet(id: 2, name: '第二舰队'),
    ],
    hasPortData: true,
  );
}

class _ToolboxStateReducer extends GameStateReducer {
  @override
  GameState reduce(GameState state, CapturedApiEvent event) => const GameState(
    admiralLevel: 77,
    hasPortData: true,
    hasEquipmentInventory: true,
  );
}

class _LifecycleProbe extends StatefulWidget {
  const _LifecycleProbe({
    super.key,
    required this.onDispose,
    this.onDeactivate,
  });

  final VoidCallback onDispose;
  final VoidCallback? onDeactivate;

  @override
  State<_LifecycleProbe> createState() => _LifecycleProbeState();
}

class _LifecycleProbeState extends State<_LifecycleProbe> {
  @override
  void deactivate() {
    widget.onDeactivate?.call();
    super.deactivate();
  }

  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(color: Colors.black);
  }
}

final class _MemoryAudioStore implements GameAudioStore {
  bool? savedMuted;
  bool? savedBackgroundPlayback;

  @override
  Future<bool?> readMuted() async => savedMuted;

  @override
  Future<void> writeMuted(bool muted) async {
    savedMuted = muted;
  }

  @override
  Future<bool?> readBackgroundPlaybackEnabled() async =>
      savedBackgroundPlayback;

  @override
  Future<void> writeBackgroundPlaybackEnabled(bool enabled) async {
    savedBackgroundPlayback = enabled;
  }
}

class _MemoryLayoutSettingsStore implements LayoutSettingsStore {
  double _ratio = 0.5;
  double _width = 300;
  bool _autoZoom = false;
  bool _enhancedDamagePulse = true;
  bool _workspaceMenuOnRight = false;
  List<String> _dashboardCardOrder = [
    'fleet',
    'land_base',
    'expedition',
    'repair',
    'construction',
    'quests',
    'battle',
    'pre_sortie',
  ];
  List<String> _dashboardCardCollapsed = [];
  List<String> _dashboardCardHidden = [];

  @override
  Future<double> loadGameAreaRatio() async => _ratio;

  @override
  Future<void> saveGameAreaRatio(double ratio) async => _ratio = ratio;

  @override
  Future<double> loadInformationPanelWidth() async => _width;

  @override
  Future<void> saveInformationPanelWidth(double width) async => _width = width;

  @override
  Future<bool> loadAutoZoom() async => _autoZoom;

  @override
  Future<void> saveAutoZoom(bool autoZoom) async => _autoZoom = autoZoom;

  @override
  Future<bool> loadEnhancedDamagePulse() async => _enhancedDamagePulse;

  @override
  Future<void> saveEnhancedDamagePulse(bool enabled) async {
    _enhancedDamagePulse = enabled;
  }

  @override
  Future<bool> loadWorkspaceMenuOnRight() async => _workspaceMenuOnRight;

  @override
  Future<void> saveWorkspaceMenuOnRight(bool onRight) async {
    _workspaceMenuOnRight = onRight;
  }

  @override
  Future<List<String>> loadDashboardCardOrder() async {
    return _dashboardCardOrder;
  }

  @override
  Future<void> saveDashboardCardOrder(List<String> order) async {
    _dashboardCardOrder = List<String>.from(order);
  }

  @override
  Future<List<String>> loadDashboardCardCollapsed() async {
    return _dashboardCardCollapsed;
  }

  @override
  Future<void> saveDashboardCardCollapsed(List<String> collapsedIds) async {
    _dashboardCardCollapsed = List<String>.from(collapsedIds);
  }

  @override
  Future<List<String>> loadDashboardCardHidden() async {
    return _dashboardCardHidden;
  }

  @override
  Future<void> saveDashboardCardHidden(List<String> hiddenIds) async {
    _dashboardCardHidden = List<String>.from(hiddenIds);
  }

  Future<bool> loadAutoZoomEnabled() async => false;

  Future<void> saveAutoZoomEnabled(bool value) async {}

  @override
  Future<String?> loadFontFamily() async => null;

  @override
  Future<void> saveFontFamily(String? value) async {}

  @override
  Future<String?> loadLocaleCode() async => null;

  @override
  Future<void> saveLocaleCode(String? value) async {}
}

final class _MemoryToolbarDisplayStore implements GameToolbarDisplayStore {
  GameToolbarDisplayMode? value;

  @override
  Future<GameToolbarDisplayMode?> read() async => value;

  @override
  Future<void> write(GameToolbarDisplayMode mode) async => value = mode;
}

final class _FakeScreenshotPort implements GameScreenshotPort {
  @override
  Future<String> captureWebView() async => '/pictures/yahagi-test.png';
}

final class _MemoryNetworkSettingsStore implements NetworkSettingsStore {
  NetworkSettings _settings = const NetworkSettings();

  @override
  Future<NetworkSettings> loadSettings() async => _settings;

  @override
  Future<void> saveSettings(NetworkSettings settings) async {
    _settings = settings;
  }
}

final class _NoopBrowserPort implements GameBrowserPort {
  int fitGameScreenCalls = 0;

  @override
  Future<void> fitGameScreen() async {
    fitGameScreenCalls++;
  }

  @override
  Future<bool> canGoBack() async => false;

  @override
  Future<void> goBack() async {}

  @override
  Future<void> loadUri(Uri uri) async {}

  @override
  Future<void> reload() async {}

  @override
  Future<GameFrameReloadResult> reloadGameFrame() async =>
      GameFrameReloadResult.reloaded;

  @override
  Future<void> showLocalHome() async {}

  @override
  Future<void> runJavaScript(String javascript) async {}

  @override
  Future<void> clearCache() async {}

  @override
  Future<void> clearSession() async {}
}

final class _MemoryModeStore implements CaptureModeStore {
  CaptureMode? savedMode;

  @override
  Future<CaptureMode?> read() async => savedMode;

  @override
  Future<void> write(CaptureMode mode) async {
    savedMode = mode;
  }
}

class _MemoryGadgetBypassStore implements GadgetBypassStore {
  GadgetBypassSettings settings = const GadgetBypassSettings();

  @override
  Future<GadgetBypassSettings> load() async => settings;

  @override
  Future<void> save(GadgetBypassSettings settings) async {
    this.settings = settings;
  }
}

class _FakeGadgetBypassPort implements GadgetBypassPort {
  @override
  Future<bool> configure({
    required bool enabled,
    required String endpoint,
  }) async {
    return true;
  }

  @override
  Future<GadgetBypassStatus> status() async =>
      const GadgetBypassStatus(enabled: false, endpoint: '', supported: true);

  @override
  Future<bool> clearCache() async => true;

  @override
  Future<GadgetBypassDiagnoseResult> diagnose() async {
    return const GadgetBypassDiagnoseResult(
      w00g: GadgetBypassProbe(reachable: true, elapsedMs: 1),
      endpoint: GadgetBypassProbe(reachable: true, elapsedMs: 1),
      kcsapi: GadgetBypassProbe(reachable: true, elapsedMs: 1),
    );
  }
}

final class _MemorySenkaStore implements SenkaStore {
  _MemorySenkaStore(this.state);

  SenkaState? state;

  @override
  Future<SenkaState?> load() async => state;

  @override
  Future<void> save(SenkaState state) async => this.state = state;
}

final class _FakeCapturePort implements GameCapturePort {
  _FakeCapturePort({required this.supported});

  final bool supported;
  final _controller = StreamController<CapturedApiEvent>.broadcast();

  @override
  Stream<CapturedApiEvent> get events => _controller.stream;

  @override
  Future<void> configure({
    required bool enabled,
    required String script,
  }) async {}

  @override
  Future<bool> isSupported() async => supported;

  void emit(CapturedApiEvent event) {
    _controller.add(event);
  }

  @override
  void dispose() {}

  Future<void> close() async {
    await _controller.close();
  }
}
