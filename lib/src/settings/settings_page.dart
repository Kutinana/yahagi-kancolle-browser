import 'package:flutter/material.dart';

import '../audio/game_audio_controller.dart';
import '../browser/gadget_bypass_controller.dart';
import '../browser/game_browser_controller.dart';
import '../browser/game_toolbar_display_controller.dart';
import '../browser/game_resource_cache_controller.dart';
import '../capture/capture_mode_controller.dart';
import '../capture/game_capture_controller.dart';
import '../diagnostics/diagnostic_controller.dart';
import '../prototype_status_controller.dart';
import '../game_state/game_state_controller.dart';
import '../senka/senka_controller.dart';
import 'layout_settings_controller.dart';
import 'display_mode_controller.dart';
import 'safety_settings_controller.dart';
import 'network_settings_controller.dart';
import 'release_check_service.dart';
import 'screen_awake_controller.dart';
import '../battle/fcd_map_controller.dart';
import '../quest/quest_catalog_controller.dart';
import '../improvement/improvement_planner_controller.dart';
import 'screen_settings_page.dart';
import 'battle_settings_page.dart';
import 'notification_settings_controller.dart';
import 'notification_settings_page.dart';
import 'network_settings_page_new.dart';
import 'data_settings_page.dart';
import 'about_support_settings_page.dart';
import 'battle_prediction_settings.dart';
import 'game_frame_rate_settings.dart';
import 'game_rendering_mode_controller.dart';
import 'game_connector_controller.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.layoutSettingsController,
    required this.networkSettingsController,
    required this.gadgetBypassController,
    required this.displayModeController,
    required this.audioController,
    required this.captureModeController,
    required this.browserController,
    required this.gameCaptureController,
    required this.prototypeStatusController,
    required this.gameStateController,
    this.senkaController,
    this.gameResourceCacheController,
    required this.safetySettingsController,
    this.notificationSettingsController,
    required this.currentVersion,
    this.releaseChecker,
    this.screenAwakeController,
    this.toolbarDisplayController,
    this.fcdMapController,
    this.questCatalogController,
    this.improvementPlannerController,
    this.showTitle = true,
    this.showDeveloperDiagnostics = false,
    this.battlePredictionSettingsController,
    this.gameFrameRateSettingsController,
    this.selectedIndex = 0,
    this.gameRenderingModeController,
    this.gameConnectorController,
    this.isBattleActive = false,
    this.diagnosticController,
  });

  final LayoutSettingsController layoutSettingsController;
  final NetworkSettingsController networkSettingsController;
  final GadgetBypassController gadgetBypassController;
  final DisplayModeController displayModeController;
  final GameAudioController audioController;
  final CaptureModeController captureModeController;
  final GameBrowserController browserController;
  final GameCaptureController gameCaptureController;
  final PrototypeStatusController prototypeStatusController;
  final GameStateController gameStateController;
  final SenkaController? senkaController;
  final GameResourceCacheController? gameResourceCacheController;
  final SafetySettingsController safetySettingsController;
  final NotificationSettingsController? notificationSettingsController;
  final bool showTitle;
  final String currentVersion;
  final ReleaseChecker? releaseChecker;
  final ScreenAwakeController? screenAwakeController;
  final GameToolbarDisplayController? toolbarDisplayController;
  final FcdMapController? fcdMapController;
  final QuestCatalogController? questCatalogController;
  final ImprovementPlannerController? improvementPlannerController;
  final bool showDeveloperDiagnostics;
  final BattlePredictionSettingsController? battlePredictionSettingsController;
  final GameFrameRateSettingsController? gameFrameRateSettingsController;
  final int selectedIndex;
  final GameRenderingModeController? gameRenderingModeController;
  final GameConnectorController? gameConnectorController;
  final bool isBattleActive;
  final DiagnosticController? diagnosticController;

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: selectedIndex,
      children: [
        ScreenSettingsPage(
          layoutSettingsController: layoutSettingsController,
          displayModeController: displayModeController,
          audioController: audioController,
          toolbarDisplayController: toolbarDisplayController,
          gameFrameRateSettingsController: gameFrameRateSettingsController,
          screenAwakeController: screenAwakeController,
          gameRenderingModeController: gameRenderingModeController,
          isBattleActive: isBattleActive,
        ),
        BattleSettingsPage(
          battlePredictionSettingsController:
              battlePredictionSettingsController,
          safetySettingsController: safetySettingsController,
        ),
        NotificationSettingsPage(
          controller:
              notificationSettingsController ??
              NotificationSettingsController(),
        ),
        NetworkSettingsPageNew(
          networkSettingsController: networkSettingsController,
          gadgetBypassController: gadgetBypassController,
          browserController: browserController,
          gameConnectorController: gameConnectorController,
        ),
        DataSettingsPage(
          captureModeController: captureModeController,
          browserController: browserController,
          gameCaptureController: gameCaptureController,
          prototypeStatusController: prototypeStatusController,
          gameStateController: gameStateController,
          senkaController: senkaController,
          gameResourceCacheController: gameResourceCacheController,
          diagnosticController: diagnosticController,
          showDeveloperDiagnostics: showDeveloperDiagnostics,
          gameRenderingModeController: gameRenderingModeController,
          fcdMapController: fcdMapController,
          questCatalogController: questCatalogController,
          improvementPlannerController: improvementPlannerController,
        ),
        AboutSupportSettingsPage(
          currentVersion: currentVersion,
          releaseChecker: releaseChecker,
        ),
      ],
    );
  }
}
