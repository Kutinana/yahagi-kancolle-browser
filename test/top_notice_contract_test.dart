import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/main.dart';
import 'package:yahagi_kancolle_browser/src/audio/game_audio_controller.dart';
import 'package:yahagi_kancolle_browser/src/audio/game_audio_store.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/gadget_bypass_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_browser_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_toolbar_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode_store.dart';
import 'package:yahagi_kancolle_browser/src/capture/game_capture_controller.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/prototype_status_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/display_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/network_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/widgets/top_notice.dart';

void main() {
  test('app mounts exactly one TopNoticeHost at MaterialApp home', () {
    final source = File('lib/main.dart').readAsStringSync();

    expect(RegExp(r'home:\s*TopNoticeHost\(').allMatches(source), hasLength(1));
    expect(RegExp(r'\bTopNoticeHost\s*\(').allMatches(source), hasLength(1));
  });

  testWidgets('YahagiApp exposes one TopNoticeHost directly as home', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(
          builder: (builderContext) {
            context = builderContext;
            return const SizedBox();
          },
        ),
      ),
    );

    GameStateController.disableTimerForTest = true;
    addTearDown(() => GameStateController.disableTimerForTest = false);
    final captureModeController = await CaptureModeController.load(
      _MemoryCaptureModeStore(),
    );
    final audioController = await GameAudioController.load(_MemoryAudioStore());
    final toolbarController = GameToolbarController();
    final gameCaptureController = GameCaptureController();
    final gameStateController = GameStateController();
    final battleController = BattleController(
      gameState: () => gameStateController.state,
    );
    addTearDown(captureModeController.dispose);
    addTearDown(audioController.dispose);
    addTearDown(toolbarController.dispose);
    addTearDown(gameCaptureController.dispose);
    addTearDown(gameStateController.dispose);
    addTearDown(battleController.dispose);

    final app = YahagiApp(
      layoutSettingsController: _LayoutSettingsControllerStub(),
      networkSettingsController: _NetworkSettingsControllerStub(),
      gadgetBypassController: _GadgetBypassControllerStub(),
      safetySettingsController: _SafetySettingsControllerStub(),
      displayModeController: _DisplayModeControllerStub(),
      controller: PrototypeStatusController(),
      browserController: GameBrowserController(),
      captureModeController: captureModeController,
      audioController: audioController,
      toolbarController: toolbarController,
      gameCaptureController: gameCaptureController,
      gameStateController: gameStateController,
      battleController: battleController,
      gameSurface: const SizedBox(),
    );

    final animatedBuilder = app.build(context) as AnimatedBuilder;
    final materialApp = animatedBuilder.builder(context, null) as MaterialApp;
    final home = materialApp.home;

    expect(home, isA<TopNoticeHost>());
    expect((home! as TopNoticeHost).child, isNot(isA<TopNoticeHost>()));
  });
}

class _LayoutSettingsControllerStub extends ChangeNotifier
    implements LayoutSettingsController {
  @override
  String get fontFamily => 'sans-serif';

  @override
  List<String> get fontFamilyFallback => const <String>[];

  @override
  String? get localeCode => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _NetworkSettingsControllerStub extends ChangeNotifier
    implements NetworkSettingsController {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _GadgetBypassControllerStub extends ChangeNotifier
    implements GadgetBypassController {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _SafetySettingsControllerStub extends ChangeNotifier
    implements SafetySettingsController {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _DisplayModeControllerStub extends ChangeNotifier
    implements DisplayModeController {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MemoryCaptureModeStore implements CaptureModeStore {
  @override
  Future<CaptureMode?> read() async => null;

  @override
  Future<void> write(CaptureMode mode) async {}
}

class _MemoryAudioStore implements GameAudioStore {
  @override
  Future<bool?> readBackgroundPlaybackEnabled() async => null;

  @override
  Future<bool?> readMuted() async => null;

  @override
  Future<void> writeBackgroundPlaybackEnabled(bool enabled) async {}

  @override
  Future<void> writeMuted(bool muted) async {}
}
