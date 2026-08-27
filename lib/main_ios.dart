/// iOS-specific entry point for Yahagi KanColle Browser.
///
/// This file is the iOS build target entry (configured via Xcode
/// FLUTTER_TARGET=lib/main_ios.dart). It re-uses the upstream [YahagiApp]
/// shell but injects iOS-specific components:
///
/// - [IOSGameWebView] as the game surface (with lifecycle audio, AudioContext
///   tracking, WKWebView compatibility)
/// - [RawDataServerController] for developer-mode master data extraction
/// - Developer mode easter egg (7-tap on settings nav)
/// - SafeArea with left/right enabled for notch/Dynamic Island
/// - Scaffold background color matching iOS design
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import 'main.dart';
import 'src/battle/battle_controller.dart';
import 'src/battle/fcd_map_controller.dart';
import 'src/battle/fcd_map_store.dart';
import 'src/battle/fcd_map_update_service.dart';
import 'src/audio/game_audio_controller.dart';
import 'src/audio/game_audio_store.dart';
import 'src/browser/game_browser_controller.dart';
import 'src/browser/gadget_bypass_controller.dart';
import 'src/browser/gadget_bypass_store.dart';
import 'src/browser/game_toolbar_controller.dart';
import 'src/browser/game_toolbar_display_controller.dart';
import 'src/browser/game_screenshot_controller.dart';
import 'src/capture/capture_mode_controller.dart';
import 'src/capture/capture_mode_store.dart';
import 'src/capture/game_capture_controller.dart';
import 'src/capture/raw_data_server_controller.dart';
import 'src/game_state/game_state_controller.dart';
import 'src/game_state/game_state_store.dart';
import 'src/ios_game_webview.dart';
import 'src/prototype_status_controller.dart';
import 'src/quest/shared_preferences_quest_store.dart';
import 'src/settings/layout_settings_controller.dart';
import 'src/settings/layout_settings_store.dart';
import 'src/settings/network_settings_controller.dart';
import 'src/settings/network_settings_store.dart';
import 'src/settings/display_mode_controller.dart';
import 'src/settings/display_mode_store.dart';
import 'src/settings/orientation_policy.dart';
import 'src/settings/safety_settings_controller.dart';
import 'src/settings/safety_settings_store.dart';
import 'src/settings/release_check_service.dart';
import 'src/settings/screen_awake_controller.dart';
import 'src/senka/senka_controller.dart';
import 'src/senka/senka_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // ── Shared initialization (mirrors upstream main.dart) ──
  final layoutSettingsController = await LayoutSettingsController.load(
    SharedPreferencesLayoutSettingsStore(),
    systemLocaleCode: _localeStorageCode(
      WidgetsBinding.instance.platformDispatcher.locale,
    ),
  );
  final networkSettingsController = NetworkSettingsController(
    store: SharedPreferencesNetworkSettingsStore(),
  );
  await networkSettingsController.initialize();
  final gadgetBypassController = await GadgetBypassController.load(
    SharedPreferencesGadgetBypassStore(),
  );
  final safetySettingsController = await SafetySettingsController.load(
    SharedPreferencesSafetySettingsStore(),
  );
  final displayModeController = await DisplayModeController.load(
    SharedPreferencesDisplayModeStore(),
  );
  applyOrientationPolicy(
    currentWindowSize(),
    displayModeController.displayMode,
  );
  final captureModeController = await CaptureModeController.load(
    SharedPreferencesCaptureModeStore(),
  );
  final controller = PrototypeStatusController(
    captureEnabled: () => captureModeController.captureEnabled,
  );
  final browserController = GameBrowserController();
  final audioController = await GameAudioController.load(
    SharedPreferencesGameAudioStore(),
  );
  final toolbarController = GameToolbarController();
  final toolbarDisplayController = await GameToolbarDisplayController.load(
    SharedPreferencesGameToolbarDisplayStore(),
  );
  final gameScreenshotController = GameScreenshotController(
    const MethodChannelGameScreenshotPort(),
  );
  final questStore = SharedPreferencesQuestStore();
  final gameStateStore = GameStateStore();

  // ── iOS-specific: RawDataServerController ──
  final rawDataServerController = RawDataServerController();

  final gameStateController = GameStateController(
    questStore: questStore,
    gameStateStore: gameStateStore,
  );
  final senkaController = SenkaController(
    store: await SharedPreferencesSenkaStore.create(),
  );
  await senkaController.initialize();
  final currentVersion = (await PackageInfo.fromPlatform()).version;
  FcdMapStorage fcdMapStorage;
  try {
    fcdMapStorage = await ApplicationFcdMapStorage.create();
  } catch (error) {
    debugPrint('FCD 数据目录不可用，改用内置数据: $error');
    fcdMapStorage = const BundledOnlyFcdMapStorage();
  }
  final fcdMapStore = FcdMapStore(fcdMapStorage);
  final loadedFcdMap = await fcdMapStore.loadBestAvailable();
  if (loadedFcdMap.diagnosticError case final error?) {
    debugPrint('FCD 本地数据降级: $error');
  }
  final loadedFcdMapState = await fcdMapStore.loadState();
  final fcdMapState =
      loadedFcdMapState?.version == loadedFcdMap.dataset.version.toString()
      ? loadedFcdMapState
      : null;
  final fcdMapController = FcdMapController(
    dataset: loadedFcdMap.dataset,
    updater: FcdMapUpdateService(
      client: http.Client(),
      store: fcdMapStore,
      appVersion: currentVersion,
    ),
    lastCheckedAt: fcdMapState?.lastCheckedAt,
    sourceHost: fcdMapState?.source ?? '',
  );
  final battleController = BattleController(
    gameState: () => gameStateController.state,
  );
  fcdMapController.addListener(battleController.refreshNodeLabel);

  // ── iOS-specific: inject raw data capture into the event pipeline ──
  final gameCaptureController = GameCaptureController(
    onAcceptedEvent: (event) {
      gameStateController.accept(event);
      senkaController.accept(event);
      battleController.accept(event);
      // Save api_start2 master data when developer mode is enabled
      if (event.path.contains('/api_start2/getData') &&
          rawDataServerController.developerMode) {
        rawDataServerController.saveRawMasterData(event.responseBody);
      }
    },
  );

  final releaseChecker = GitHubReleaseChecker();
  final screenAwakeController = await ScreenAwakeController.load(
    SharedPreferencesScreenAwakeStore(),
  );
  await screenAwakeController.attachPort(const MethodChannelScreenAwakePort());

  runApp(
    _IOSYahagiApp(
      layoutSettingsController: layoutSettingsController,
      networkSettingsController: networkSettingsController,
      gadgetBypassController: gadgetBypassController,
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
      senkaController: senkaController,
      battleController: battleController,
      fcdMapController: fcdMapController,
      currentVersion: currentVersion,
      releaseChecker: releaseChecker,
      screenAwakeController: screenAwakeController,
      rawDataServerController: rawDataServerController,
    ),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(fcdMapController.checkForUpdates());
  });
}

String _localeStorageCode(Locale locale) {
  if (locale.languageCode == 'ja') return 'ja';
  if (locale.languageCode == 'zh' && locale.scriptCode == 'Hant') {
    return 'zh_Hant';
  }
  return 'zh';
}

/// iOS-specific app wrapper.
///
/// Wraps [YahagiApp] and overrides the game surface with [IOSGameWebView].
/// The upstream [main.dart] and [YahagiApp] remain completely unmodified.
class _IOSYahagiApp extends StatelessWidget {
  const _IOSYahagiApp({
    required this.layoutSettingsController,
    required this.networkSettingsController,
    required this.gadgetBypassController,
    required this.safetySettingsController,

    required this.displayModeController,
    required this.controller,
    required this.browserController,
    required this.captureModeController,
    required this.audioController,
    required this.toolbarController,
    required this.gameCaptureController,
    required this.gameStateController,
    required this.senkaController,
    required this.battleController,
    this.fcdMapController,
    this.currentVersion = '1.0.2',
    this.releaseChecker,
    this.screenAwakeController,
    this.toolbarDisplayController,
    this.gameScreenshotController,
    this.rawDataServerController,
  });

  final LayoutSettingsController layoutSettingsController;
  final NetworkSettingsController networkSettingsController;
  final GadgetBypassController gadgetBypassController;
  final SafetySettingsController safetySettingsController;

  final DisplayModeController displayModeController;
  final PrototypeStatusController controller;
  final GameBrowserController browserController;
  final CaptureModeController captureModeController;
  final GameAudioController audioController;
  final GameToolbarController toolbarController;
  final GameCaptureController gameCaptureController;
  final GameStateController gameStateController;
  final SenkaController senkaController;
  final BattleController battleController;
  final FcdMapController? fcdMapController;
  final String currentVersion;
  final ReleaseChecker? releaseChecker;
  final ScreenAwakeController? screenAwakeController;
  final GameToolbarDisplayController? toolbarDisplayController;
  final GameScreenshotController? gameScreenshotController;
  final RawDataServerController? rawDataServerController;

  @override
  Widget build(BuildContext context) {
    // Delegate to upstream YahagiApp with iOS-specific gameSurface
    return YahagiApp(
      layoutSettingsController: layoutSettingsController,
      networkSettingsController: networkSettingsController,
      gadgetBypassController: gadgetBypassController,
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
      senkaController: senkaController,
      battleController: battleController,
      fcdMapController: fcdMapController,
      currentVersion: currentVersion,
      releaseChecker: releaseChecker,
      screenAwakeController: screenAwakeController,
      // iOS-specific: use IOSGameWebView instead of upstream GameWebView
      gameSurface: IOSGameWebView(
        key: const GlobalObjectKey('yahagi_game_webview'),
        networkSettingsController: networkSettingsController,
        safetySettingsController: safetySettingsController,
        controller: controller,
        browserController: browserController,
        captureModeController: captureModeController,
        audioController: audioController,
        toolbarController: toolbarController,
        gameCaptureController: gameCaptureController,
      ),
    );
  }
}
