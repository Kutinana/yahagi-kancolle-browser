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
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n/app_localizations.dart';
import 'main.dart';
import 'src/audio/game_audio_controller.dart';
import 'src/audio/game_audio_store.dart';
import 'src/battle/battle_controller.dart';
import 'src/battle/battle_damage_alert.dart';
import 'src/battle/fcd_map_controller.dart';
import 'src/battle/fcd_map_store.dart';
import 'src/battle/fcd_map_update_service.dart';
import 'src/browser/gadget_bypass_controller.dart';
import 'src/browser/gadget_bypass_store.dart';
import 'src/browser/game_browser_controller.dart';
import 'src/browser/game_screenshot_controller.dart';
import 'src/browser/game_toolbar_controller.dart';
import 'src/browser/game_toolbar_display_controller.dart';
import 'src/capture/capture_mode_controller.dart';
import 'src/capture/capture_mode_store.dart';
import 'src/capture/game_capture_controller.dart';
import 'src/capture/raw_data_server_controller.dart';
import 'src/battle/formation_memory.dart';
import 'src/game_state/game_state_controller.dart';
import 'src/game_state/game_state_store.dart';
import 'src/improvement/improvement_dataset_store.dart';
import 'src/improvement/improvement_dataset_update_service.dart';
import 'src/improvement/improvement_favorites_store.dart';
import 'src/improvement/improvement_planner_controller.dart';
import 'src/ios_game_webview.dart';
import 'src/new_ship/new_ship_reminder_controller.dart';
import 'src/new_ship/new_ship_reminder_store.dart';
import 'src/prototype_status_controller.dart';
import 'src/quest/quest_catalog_controller.dart';
import 'src/quest/quest_catalog_store.dart';
import 'src/quest/quest_catalog_update_service.dart';
import 'src/quest/shared_preferences_quest_store.dart';
import 'src/senka/senka_controller.dart';
import 'src/senka/senka_store.dart';
import 'src/settings/battle_prediction_settings.dart';
import 'src/settings/display_mode_controller.dart';
import 'src/settings/display_mode_store.dart';
import 'src/settings/game_connector.dart';
import 'src/settings/game_connector_controller.dart';
import 'src/settings/game_frame_rate_settings.dart';
import 'src/settings/layout_settings_controller.dart';
import 'src/settings/layout_settings_store.dart';
import 'src/settings/network_settings_controller.dart';
import 'src/settings/network_settings_store.dart';
import 'src/settings/orientation_policy.dart';
import 'src/settings/release_check_service.dart';
import 'src/settings/safety_settings_controller.dart';
import 'src/settings/safety_settings_store.dart';
import 'src/settings/screen_awake_controller.dart';
import 'src/settings/raw_data_section.dart';
import 'src/widgets/top_notice.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // ── Shared initialization (mirrors upstream main.dart) ──
  final systemLocaleCode = _localeStorageCode(
    WidgetsBinding.instance.platformDispatcher.locale,
  );
  final layoutSettingsController = await LayoutSettingsController.load(
    SharedPreferencesLayoutSettingsStore(),
    systemLocaleCode: systemLocaleCode,
  );
  // iOS-specific: Ensure initial locale is explicitly established and persisted
  // so that UI localization and settings selection stay in sync from first launch.
  if (layoutSettingsController.localeCode == null) {
    await layoutSettingsController.setLocaleCode(systemLocaleCode);
  }
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
  final battlePredictionSettingsController =
      await BattlePredictionSettingsController.load(
        SharedPreferencesBattlePredictionSettingsStore(),
      );
  final formationMemoryController = await FormationMemoryController.load(
    SharedPreferencesFormationMemoryStore(),
  );
  final displayModeController = await DisplayModeController.load(
    SharedPreferencesDisplayModeStore(),
  );
  final gameFrameRateSettingsController =
      await GameFrameRateSettingsController.load(
        SharedPreferencesGameFrameRateSettingsStore(),
      );
  final gameConnectorController = await GameConnectorController.load(
    SharedPreferencesGameConnectorStore(),
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
  final browserController = GameBrowserController(
    homeUri: gameConnectorController.connector.entryUri,
  );
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

  ImprovementDatasetStorage improvementStorage;
  try {
    improvementStorage = await ApplicationImprovementDatasetStorage.create();
  } catch (error) {
    debugPrint('改修资料目录不可用，改用内置数据: $error');
    improvementStorage = const BundledOnlyImprovementDatasetStorage();
  }
  final improvementStore = ImprovementDatasetStore(improvementStorage);
  final improvementDataset = await improvementStore.loadBestAvailable();
  final improvementPlannerController = ImprovementPlannerController(
    dataset: improvementDataset,
    favoritesStore: SharedPreferencesImprovementFavoritesStore(),
    updater: ImprovementDatasetUpdateService(
      client: http.Client(),
      store: improvementStore,
    ),
  );
  await improvementPlannerController.loadFavorites();

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

  QuestCatalogStorage questCatalogStorage;
  try {
    questCatalogStorage = await ApplicationQuestCatalogStorage.create();
  } catch (error) {
    debugPrint('任务资料目录不可用，改用内置数据: $error');
    questCatalogStorage = const BundledOnlyQuestCatalogStorage();
  }
  final questCatalogStore = QuestCatalogStore(questCatalogStorage);
  final loadedQuestCatalog = await questCatalogStore.loadBestAvailable();
  final loadedQuestCatalogState = await questCatalogStore.loadState();
  final questCatalogState =
      loadedQuestCatalogState?.version.commitSha ==
              loadedQuestCatalog.dataset.version.commitSha
          ? loadedQuestCatalogState
          : null;
  final questCatalogController = QuestCatalogController(
    dataset: loadedQuestCatalog.dataset,
    updater: QuestCatalogUpdateService(
      client: http.Client(),
      store: questCatalogStore,
      appVersion: currentVersion,
    ),
    lastCheckedAt: questCatalogState?.lastCheckedAt,
    sourceHost: questCatalogState?.source ?? '',
  );

  final battleController = BattleController(
    gameState: () => gameStateController.state,
    waitForGameState: () => gameStateController.idle,
    onFriendlyHpUpdated: gameStateController.applyFriendlyBattleHp,
    damageAlertPort: const MethodChannelBattleDamageAlertPort(),
    battleStatusEffectSettings: () =>
        safetySettingsController.battleStatusEffects,
    nodeLabelResolver: fcdMapController,
    formationMemory: formationMemoryController,
  );
  fcdMapController.addListener(battleController.refreshNodeLabel);

  final newShipReminderController = NewShipReminderController(
    stateProvider: () => gameStateController.state,
    store: NewShipReminderStore(await SharedPreferences.getInstance()),
    onPublish: (alert) {
      final state = gameStateController.state;
      final l10n = lookupAppLocalizations(const Locale('zh'));
      final names = alert.masterIds
          .map(
            (id) => state.masterShips[id]?.name ?? l10n.newShipFallbackName(id),
          )
          .join('、');
      debugPrint('新舰娘掉落提醒: $names');
    },
  );

  // ── iOS-specific: inject raw data capture and new ship reminder into the event pipeline ──
  final gameCaptureController = GameCaptureController(
    onAcceptedEvent: (event) {
      gameStateController.accept(event);
      senkaController.accept(event);
      battleController.accept(event);
      newShipReminderController.accept(event);
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
      battlePredictionSettingsController: battlePredictionSettingsController,
      gameFrameRateSettingsController: gameFrameRateSettingsController,
      gameConnectorController: gameConnectorController,
      questCatalogController: questCatalogController,
      improvementPlannerController: improvementPlannerController,
      newShipReminderController: newShipReminderController,
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
    unawaited(questCatalogController.checkForUpdates());
    unawaited(improvementPlannerController.checkForUpdates());
  });
}

String _localeStorageCode(Locale locale) {
  if (locale.languageCode == 'ja') return 'ja';
  if (locale.languageCode == 'zh') {
    if (locale.scriptCode == 'Hant' ||
        locale.countryCode == 'TW' ||
        locale.countryCode == 'HK' ||
        locale.countryCode == 'MO') {
      return 'zh_Hant';
    }
    return 'zh';
  }
  return 'zh';
}

/// iOS-specific app wrapper.
///
/// Wraps [YahagiApp] and overrides the game surface with [IOSGameWebView].
/// Injects 7-tap settings easter egg and mounts [RawDataSection] into data settings.
class _IOSYahagiApp extends StatefulWidget {
  const _IOSYahagiApp({
    required this.layoutSettingsController,
    required this.networkSettingsController,
    required this.gadgetBypassController,
    required this.safetySettingsController,
    this.battlePredictionSettingsController,
    this.gameFrameRateSettingsController,
    this.gameConnectorController,
    this.questCatalogController,
    this.improvementPlannerController,
    this.newShipReminderController,
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
  final BattlePredictionSettingsController? battlePredictionSettingsController;
  final GameFrameRateSettingsController? gameFrameRateSettingsController;
  final GameConnectorController? gameConnectorController;
  final QuestCatalogController? questCatalogController;
  final ImprovementPlannerController? improvementPlannerController;
  final NewShipReminderController? newShipReminderController;

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
  State<_IOSYahagiApp> createState() => _IOSYahagiAppState();
}

class _IOSYahagiAppState extends State<_IOSYahagiApp> {
  int _settingsTapCount = 0;
  Timer? _settingsTapResetTimer;
  late bool _developerMode;

  @override
  void initState() {
    super.initState();
    _developerMode = widget.rawDataServerController?.developerMode ?? false;
    widget.rawDataServerController?.addListener(_onRawDataControllerChanged);
  }

  @override
  void didUpdateWidget(covariant _IOSYahagiApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rawDataServerController != widget.rawDataServerController) {
      oldWidget.rawDataServerController?.removeListener(_onRawDataControllerChanged);
      widget.rawDataServerController?.addListener(_onRawDataControllerChanged);
      _developerMode = widget.rawDataServerController?.developerMode ?? false;
    }
  }

  @override
  void dispose() {
    _settingsTapResetTimer?.cancel();
    widget.rawDataServerController?.removeListener(_onRawDataControllerChanged);
    super.dispose();
  }

  void _onRawDataControllerChanged() {
    final next = widget.rawDataServerController?.developerMode ?? false;
    if (_developerMode != next) {
      setState(() => _developerMode = next);
    }
  }

  void _onSettingsNavTap(BuildContext context) {
    _settingsTapResetTimer?.cancel();
    _settingsTapCount++;
    _settingsTapResetTimer = Timer(const Duration(milliseconds: 1500), () {
      _settingsTapCount = 0;
    });

    if (_settingsTapCount >= 7) {
      _settingsTapCount = 0;
      _settingsTapResetTimer?.cancel();
      if (!_developerMode) {
        widget.rawDataServerController?.setDeveloperMode(true);
        HapticFeedback.mediumImpact();
        if (context.mounted) {
          TopNotice.show(
            context,
            message: '已开启开发者模式',
            tone: TopNoticeTone.success,
          );
        }
      } else {
        HapticFeedback.lightImpact();
        if (context.mounted) {
          TopNotice.show(
            context,
            message: '当前已处于开发者模式',
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawController = widget.rawDataServerController;
    return YahagiApp(
      layoutSettingsController: widget.layoutSettingsController,
      networkSettingsController: widget.networkSettingsController,
      gadgetBypassController: widget.gadgetBypassController,
      safetySettingsController: widget.safetySettingsController,
      battlePredictionSettingsController: widget.battlePredictionSettingsController,
      gameFrameRateSettingsController: widget.gameFrameRateSettingsController,
      gameConnectorController: widget.gameConnectorController,
      questCatalogController: widget.questCatalogController,
      improvementPlannerController: widget.improvementPlannerController,
      newShipReminderController: widget.newShipReminderController,
      displayModeController: widget.displayModeController,
      controller: widget.controller,
      browserController: widget.browserController,
      captureModeController: widget.captureModeController,
      audioController: widget.audioController,
      toolbarController: widget.toolbarController,
      toolbarDisplayController: widget.toolbarDisplayController,
      gameScreenshotController: widget.gameScreenshotController,
      gameCaptureController: widget.gameCaptureController,
      gameStateController: widget.gameStateController,
      senkaController: widget.senkaController,
      battleController: widget.battleController,
      fcdMapController: widget.fcdMapController,
      currentVersion: widget.currentVersion,
      releaseChecker: widget.releaseChecker,
      screenAwakeController: widget.screenAwakeController,
      showDeveloperDiagnostics: _developerMode,
      onSettingsNavTap: _onSettingsNavTap,
      additionalDataSections: <Widget>[
        if (_developerMode && rawController != null) ...<Widget>[
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              '开发者选项 (Developer Options)',
              style: TextStyle(
                color: Color(0xffd4a85f),
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          Material(
            color: const Color(0xff142735),
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: ListTileTheme(
              data: const ListTileThemeData(
                contentPadding: EdgeInsets.symmetric(horizontal: 16),
                minLeadingWidth: 0,
              ),
              child: RawDataSection(controller: rawController),
            ),
          ),
        ],
      ],
      // iOS-specific: use IOSGameWebView instead of upstream GameWebView
      gameSurface: IOSGameWebView(
        key: const GlobalObjectKey('yahagi_game_webview'),
        networkSettingsController: widget.networkSettingsController,
        safetySettingsController: widget.safetySettingsController,
        controller: widget.controller,
        browserController: widget.browserController,
        captureModeController: widget.captureModeController,
        audioController: widget.audioController,
        toolbarController: widget.toolbarController,
        gameCaptureController: widget.gameCaptureController,
        frameRateSettingsController: widget.gameFrameRateSettingsController,
      ),
    );
  }
}
