import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_browser_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode_store.dart';
import 'package:yahagi_kancolle_browser/src/capture/game_capture_controller.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/prototype_status_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/data_settings_page.dart';

void main() {
  testWidgets('data settings contain capture mode and local data actions', (
    tester,
  ) async {
    final capture = await CaptureModeController.load(_MemoryCaptureModeStore());
    final browser = GameBrowserController();
    final gameCapture = GameCaptureController();
    final prototype = PrototypeStatusController();
    final gameState = GameStateController();
    addTearDown(capture.dispose);
    addTearDown(browser.dispose);
    addTearDown(gameCapture.dispose);
    addTearDown(prototype.dispose);
    addTearDown(gameState.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: DataSettingsPage(
          captureModeController: capture,
          browserController: browser,
          gameCaptureController: gameCapture,
          prototypeStatusController: prototype,
          gameStateController: gameState,
          showDeveloperDiagnostics: true,
        ),
      ),
    );

    final logout = find.byKey(const Key('settings-logout-label'));
    final captureMode = find.byKey(const Key('capture-mode-selector'));
    expect(logout, findsOneWidget);
    expect(captureMode, findsOneWidget);
    expect(
      tester.getTopLeft(logout).dy,
      lessThan(tester.getTopLeft(captureMode).dy),
    );
    expect(find.byKey(const Key('settings-clear-quest-cache')), findsOneWidget);
    expect(find.byKey(const Key('settings-clear-logbook')), findsOneWidget);
    expect(find.byKey(const Key('settings-clear-web-cache')), findsOneWidget);
    expect(find.text('安全边界'), findsOneWidget);
  });
}

final class _MemoryCaptureModeStore implements CaptureModeStore {
  @override
  Future<CaptureMode?> read() async => CaptureMode.game;

  @override
  Future<void> write(CaptureMode mode) async {}
}
