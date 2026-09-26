/// iOS-specific entry point for Yahagi KanColle Browser.
///
/// This file is the iOS build target entry (configured via Xcode
/// FLUTTER_TARGET=lib/main_ios.dart). It aligns with upstream [main.dart]
/// and injects iOS-specific components:
///
/// - [IOSGameWebView] as the game surface (with lifecycle audio, AudioContext
///   tracking, WKWebView compatibility)
/// - [RawDataServerController] for developer-mode master data extraction
/// - Developer mode easter egg (7-tap on settings nav)
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n/app_localizations.dart';
import 'main.dart';
import 'src/account/account_session.dart';
import 'src/audio/game_audio_controller.dart';
import 'src/audio/game_audio_store.dart';
import 'src/battle/battle_controller.dart';
import 'src/battle/battle_damage_alert.dart';
import 'src/battle/fcd_map_controller.dart';
import 'src/battle/fcd_map_store.dart';
import 'src/battle/fcd_map_update_service.dart';
import 'src/battle/formation_memory.dart';
import 'src/bridge/captured_api_event.dart';
import 'src/browser/gadget_bypass_controller.dart';
import 'src/browser/gadget_bypass_store.dart';
import 'src/browser/game_browser_controller.dart';
import 'src/browser/game_resource_cache_controller.dart';
import 'src/browser/game_resource_manifest_builder.dart';
import 'src/browser/game_resource_manifest_consumer.dart';
import 'src/browser/game_screenshot_controller.dart';
import 'src/fleet/morale_recovery_timer_controller.dart';
import 'src/settings/game_frame_refresh_shortcut_settings.dart';
import 'src/settings/game_mouse_wheel_settings.dart';
import 'src/browser/game_toolbar_controller.dart';
import 'src/browser/game_toolbar_display_controller.dart';
import 'src/capture/capture_mode_controller.dart';
import 'src/capture/capture_mode_store.dart';
import 'src/capture/game_capture_controller.dart';
import 'src/capture/raw_data_server_controller.dart';
import 'src/diagnostics/diagnostic_controller.dart';
import 'src/diagnostics/diagnostic_event.dart';
import 'src/diagnostics/diagnostic_export_service.dart';
import 'src/diagnostics/diagnostic_game_api_observer.dart';
import 'src/diagnostics/diagnostic_performance_monitor.dart';
import 'src/diagnostics/diagnostic_platform_port.dart';
import 'src/diagnostics/diagnostic_recorder.dart';
import 'src/diagnostics/diagnostic_settings_store.dart';
import 'src/diagnostics/diagnostic_storage.dart';
import 'src/game_state/game_api_event_pipeline.dart';
import 'src/game_state/game_state_controller.dart';
import 'src/game_state/game_state_store.dart';
import 'src/improvement/improvement_dataset_store.dart';
import 'src/improvement/improvement_dataset_update_service.dart';
import 'src/improvement/improvement_favorites_store.dart';
import 'src/improvement/improvement_planner_controller.dart';
import 'src/ios_game_webview.dart';
import 'src/kcwiki_report/kcwiki_report_collector.dart';
import 'src/kcwiki_report/kcwiki_report_consumer.dart';
import 'src/kcwiki_report/kcwiki_report_dispatcher.dart';
import 'src/kcwiki_report/kcwiki_report_settings.dart';
import 'src/kcwiki_report/kcwiki_report_transport.dart';
import 'src/logbook/logbook_database.dart';
import 'src/new_ship/new_ship_reminder_controller.dart';
import 'src/new_ship/new_ship_reminder_store.dart';
import 'src/notice/game_info_notice_controller.dart';
import 'src/notification/game_notification_coordinator.dart';
import 'src/notification/notification_models.dart';
import 'src/notification/notification_port.dart';
import 'src/notification/notification_timer_anchor_store.dart';
import 'src/prototype_status_controller.dart';
import 'src/quest/quest_catalog_controller.dart';
import 'src/quest/quest_catalog_store.dart';
import 'src/quest/quest_catalog_update_service.dart';
import 'src/quest/quest_progress_engine.dart';
import 'src/quest/shared_preferences_quest_store.dart';
import 'src/senka/senka_controller.dart';
import 'src/senka/senka_store.dart';
import 'src/settings/background_game_retention_controller.dart';
import 'src/settings/battle_prediction_settings.dart';
import 'src/settings/display_mode_controller.dart';
import 'src/settings/display_mode_store.dart';
import 'src/settings/game_connector.dart';
import 'src/settings/game_connector_controller.dart';
import 'src/settings/game_frame_rate_settings.dart';
import 'src/settings/game_rendering_mode_controller.dart';
import 'src/settings/layout_settings_controller.dart';
import 'src/settings/layout_settings_store.dart';
import 'src/settings/network_settings_controller.dart';
import 'src/settings/network_settings_store.dart';
import 'src/settings/notification_settings_controller.dart';
import 'src/settings/notification_settings_store.dart';
import 'src/settings/orientation_policy.dart';
import 'src/settings/raw_data_section.dart';
import 'src/settings/release_check_service.dart';
import 'src/settings/safety_settings_controller.dart';
import 'src/settings/safety_settings_store.dart';
import 'src/settings/screen_awake_controller.dart';
import 'src/telemetry/telemetry_controller.dart';
import 'src/telemetry/telemetry_service.dart';
import 'src/telemetry/telemetry_settings_store.dart';
import 'src/toolbox/sortie_map_query/enemy_catalog.dart';
import 'src/toolbox/sortie_map_query/enemy_catalog_controller.dart';
import 'src/toolbox/sortie_map_query/enemy_catalog_store.dart';
import 'src/toolbox/sortie_map_query/enemy_catalog_update_service.dart';
import 'src/toolbox/sortie_map_query/sortie_map_catalog.dart';
import 'src/toolbox/sortie_map_query/sortie_map_catalog_controller.dart';
import 'src/toolbox/sortie_map_query/sortie_map_catalog_store.dart';
import 'src/toolbox/sortie_map_query/sortie_map_catalog_update_service.dart';
import 'src/widgets/top_notice.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final accountSession = AccountSession.shared;
  LogbookDatabase.bindAccountSession(accountSession);
  late final GameApiEventPipeline gameApiEventPipeline;
  late final GameCaptureController gameCaptureController;
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

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

  final notificationSettingsController = NotificationSettingsController(
    store: const SharedPreferencesNotificationSettingsStore(),
  );
  await notificationSettingsController.initialize();
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
    accountSession: accountSession,
  );
  final displayModeController = await DisplayModeController.load(
    SharedPreferencesDisplayModeStore(),
  );
  final gameFrameRateSettingsController =
      await GameFrameRateSettingsController.load(
        SharedPreferencesGameFrameRateSettingsStore(),
      );
  final gameRenderingModeController = await GameRenderingModeController.load(
    SharedPreferencesGameRenderingModeStore(),
  );
  final gameConnectorController = await GameConnectorController.load(
    SharedPreferencesGameConnectorStore(),
  );
  final backgroundGameRetentionController =
      await BackgroundGameRetentionController.load(
        SharedPreferencesBackgroundGameRetentionStore(),
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
    onSessionReset: () async {
      gameApiEventPipeline.invalidatePendingEvents(waitForLoginStart: true);
      accountSession.reset();
      await gameCaptureController.invalidateSession();
    },
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
  final questStore = SharedPreferencesQuestStore(
    accountSession: accountSession,
  );
  final gameStateStore = GameStateStore();
  final gameStateController = GameStateController(
    accountSession: accountSession,
    questStore: questStore,
    questProgress: await QuestProgressEngine.load(),
    gameStateStore: gameStateStore,
  );
  await gameStateController.initialize();
  final kcwikiReportController = await KcwikiReportController.load(
    SharedPreferencesKcwikiReportSettingsStore(),
  );
  final gameResourceCacheController = GameResourceCacheController();
  await gameResourceCacheController.initialize();
  final senkaController = SenkaController(
    accountSession: accountSession,
    store: await SharedPreferencesSenkaStore.create(
      accountSession: accountSession,
    ),
  );
  await senkaController.initialize();

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
    accountSession: accountSession,
    dataset: improvementDataset,
    favoritesStore: SharedPreferencesImprovementFavoritesStore(),
    updater: ImprovementDatasetUpdateService(
      client: http.Client(),
      store: improvementStore,
    ),
  );
  await improvementPlannerController.loadFavorites();

  final packageInfo = await PackageInfo.fromPlatform();
  final currentVersion = packageInfo.version;

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

  final bundledSortieMapCatalog = await SortieMapCatalog.loadAsset();
  late FileSortieMapCatalogStore sortieMapCatalogStore;
  try {
    sortieMapCatalogStore = await FileSortieMapCatalogStore.create(
      currentAppVersion: currentVersion,
    );
  } catch (error) {
    debugPrint('海域资料目录不可用，改用临时缓存: $error');
    sortieMapCatalogStore = FileSortieMapCatalogStore(
      root: Directory(
        '${Directory.systemTemp.path}${Platform.pathSeparator}yahagi-sortie-catalog',
      ),
      currentAppVersion: currentVersion,
    );
  }
  final cachedSortieMapCatalog = await sortieMapCatalogStore.loadCached();
  final useCachedSortieMapCatalog =
      cachedSortieMapCatalog != null &&
      cachedSortieMapCatalog.data.versionInfo.compareTo(
            bundledSortieMapCatalog.versionInfo,
          ) >=
          0;
  final sortieMapCatalogController = SortieMapCatalogController(
    data: useCachedSortieMapCatalog
        ? cachedSortieMapCatalog.data
        : bundledSortieMapCatalog,
    cacheRoot: useCachedSortieMapCatalog ? cachedSortieMapCatalog.root : null,
    updater: SortieMapCatalogUpdateService(
      client: http.Client(),
      installer: sortieMapCatalogStore,
      appVersion: currentVersion,
    ),
  );

  final bundledEnemyCatalog = await EnemyCatalogData.loadAsset();
  late FileEnemyCatalogStore enemyCatalogStore;
  try {
    enemyCatalogStore = await FileEnemyCatalogStore.create();
  } catch (error) {
    debugPrint('敌舰资料目录不可用，改用临时缓存: $error');
    enemyCatalogStore = FileEnemyCatalogStore(
      cacheFile: File(
        '${Directory.systemTemp.path}${Platform.pathSeparator}yahagi-enemy-catalog.json',
      ),
      bundledReader: () async => bundledEnemyCatalog.rawJson,
    );
  }
  final loadedEnemyCatalog = await enemyCatalogStore.loadBestAvailable();
  final enemyCatalogController = EnemyCatalogController(
    data: loadedEnemyCatalog,
    usesCachedData: loadedEnemyCatalog.revision > bundledEnemyCatalog.revision,
    updater: EnemyCatalogUpdateService(
      client: http.Client(),
      store: enemyCatalogStore,
      appVersion: currentVersion,
    ),
  );

  final battleController = BattleController(
    accountSession: accountSession,
    gameState: () => gameStateController.state,
    waitForGameState: () => gameStateController.idle,
    onFriendlyHpUpdated: gameStateController.applyFriendlyBattleHp,
    onDamageControlConsumed: gameStateController.applyDamageControlConsumption,
    damageAlertPort: const MethodChannelBattleDamageAlertPort(),
    battleStatusEffectSettings: () =>
        safetySettingsController.battleStatusEffects,
    nodeLabelResolver: fcdMapController,
    formationMemory: formationMemoryController,
  );
  gameStateController.questBattleSnapshot = () => battleController.current;
  gameStateController.questBattleTrusted = () =>
      battleController.isPredictionConfirmed;
  fcdMapController.addListener(battleController.refreshNodeLabel);

  final gameResourceManifestConsumer = GameResourceManifestConsumer(
    controller: gameResourceCacheController,
    ownedShipMasterIds: () => gameStateController.state.ships.values
        .map((ship) => ship.masterId)
        .toSet(),
    ownedSlotItemMasterIds: () => gameStateController.state.slotItems.values
        .map((item) => item.masterId)
        .toSet(),
    staticUrlsLoader: GameResourceStaticCatalog.load,
    waitForGameState: () => gameStateController.idle,
  );

  late final KcwikiReportDispatcher kcwikiReportDispatcher;
  kcwikiReportDispatcher = KcwikiReportDispatcher(
    transportFactory: () => HttpKcwikiReportTransport(
      client: http.Client(),
      baseUri: configuredKcwikiReportEndpoint() ?? Uri(),
    ),
    onQueued: (module) => kcwikiReportController.recordQueued(
      module: module.wireName,
      occurredAt: DateTime.now(),
    ),
    onResult: (result) => kcwikiReportController.recordResult(
      module: result.module.wireName,
      succeeded: result.accepted,
      occurredAt: DateTime.now(),
      statusCode: result.statusCode,
      failure: switch (result.failure) {
        KcwikiTransportFailure.bodyTooLarge => KcwikiReportFailure.bodyTooLarge,
        KcwikiTransportFailure.timeout => KcwikiReportFailure.timeout,
        KcwikiTransportFailure.network => KcwikiReportFailure.network,
        KcwikiTransportFailure.rejected => KcwikiReportFailure.httpRejected,
        null => null,
      },
    ),
    onDropped: kcwikiReportController.recordDropped,
  );

  final kcwikiReportConsumer = KcwikiReportConsumer(
    accountSession: accountSession,
    controller: kcwikiReportController,
    collector: KcwikiReportCollector(),
    dispatcher: kcwikiReportDispatcher,
    gameState: () => gameStateController.state,
    waitForGameState: () => gameStateController.idle,
  );

  late final GameNotificationCoordinator notificationCoordinator;
  final newShipReminderController = NewShipReminderController(
    accountSession: accountSession,
    stateProvider: () => gameStateController.state,
    waitForGameState: () => gameStateController.idle,
    store: NewShipReminderStore(await SharedPreferences.getInstance()),
    onPublish: (alert) {
      final state = gameStateController.state;
      final l10n = lookupAppLocalizations(const Locale('zh'));
      final names = alert.masterIds
          .map(
            (id) => state.masterShips[id]?.name ?? l10n.newShipFallbackName(id),
          )
          .join('、');
      notificationCoordinator.enqueueImmediateAlert(
        ImmediateNotificationItem(
          key: 'new-ship:${alert.key}',
          type: GameNotificationType.newShip,
          occurredAt: alert.occurredAt,
          title: l10n.newShipAlertTitle,
          body: l10n.newShipAlertBody(names),
        ),
      );
    },
  );

  final headerNoticeController = TopNoticeController();
  final gameInfoNoticeController = GameInfoNoticeController(
    stateProvider: () => gameStateController.state,
    accountSession: accountSession,
    layoutSettingsController: layoutSettingsController,
    topNoticeController: headerNoticeController,
  );

  // ── iOS-specific: RawDataServerController for developer mode master data capture ──
  final rawDataServerController = RawDataServerController();
  final rawDataConsumer = _IOSRawDataConsumer(rawDataServerController);

  gameApiEventPipeline = GameApiEventPipeline(
    settleGameState: () async {
      await gameStateController.idle;
      await battleController.idle;
      await gameStateController.idle;
    },
    consumers: <GameApiEventConsumer>[
      accountSession,
      gameStateController,
      kcwikiReportConsumer,
      gameResourceManifestConsumer,
      senkaController,
      battleController,
      newShipReminderController,
      gameInfoNoticeController,
      rawDataConsumer,
    ],
    onBackgroundDecodeFallback: (path) {
      if (!kcwikiReportController.enabled) return;
      kcwikiReportController.recordParseRecovered(
        path: path,
        occurredAt: DateTime.now(),
      );
    },
  );

  gameCaptureController = GameCaptureController(
    onAcceptedEvent: gameApiEventPipeline.add,
  );

  final releaseChecker = GitHubReleaseChecker();
  final gameMouseWheelSettingsController =
      await GameMouseWheelSettingsController.load();
  final gameFrameRefreshShortcutSettings =
      await GameFrameRefreshShortcutSettings.load();
  final screenAwakeController = await ScreenAwakeController.load(
    SharedPreferencesScreenAwakeStore(),
  );
  await screenAwakeController.attachPort(const MethodChannelScreenAwakePort());

  final applicationSupportDirectory = await getApplicationSupportDirectory();
  final temporaryDirectory = await getTemporaryDirectory();
  final diagnosticStorage = DiagnosticStorage(
    directory: Directory(
      p.join(applicationSupportDirectory.path, 'diagnostics'),
    ),
  );
  final diagnosticRecorder = DiagnosticRecorder(
    sink: diagnosticStorage,
    enabled: false,
  );
  const diagnosticPlatform = MethodChannelDiagnosticPlatformPort();
  final diagnosticApiObserver = DiagnosticGameApiObserver(
    recorder: diagnosticRecorder,
  );
  var lastBrowserDiagnosticState = browserController.loadState;
  void recordBrowserState() {
    final state = browserController.loadState;
    if (state == lastBrowserDiagnosticState) return;
    lastBrowserDiagnosticState = state;
    diagnosticRecorder.record(
      DiagnosticEvent.webViewState(
        occurredAt: DateTime.now(),
        state: state.name,
        durationMs: 0,
      ),
    );
  }

  var diagnosticNativeWebViewGeneration = -1;
  DiagnosticWebViewHost diagnosticWebViewHost() =>
      DiagnosticWebViewHost.flutterPlatformView;

  DiagnosticGameRenderer diagnosticRenderer() => DiagnosticGameRenderer.webgl;

  int diagnosticGeneration() => diagnosticNativeWebViewGeneration < 0
      ? 0
      : diagnosticNativeWebViewGeneration;

  final diagnosticPerformanceMonitor = DiagnosticPerformanceMonitor(
    recorder: diagnosticRecorder,
    platform: diagnosticPlatform,
    pendingApiEvents: () => gameApiEventPipeline.pendingEventCount,
    activeApiPath: () => gameApiEventPipeline.activePath,
    backgroundDecodeFallbacks: () =>
        gameApiEventPipeline.backgroundFallbackCount,
    databaseBytes: () => LogbookDatabase.instance.diagnosticFileSizeBytes(),
    webViewHost: diagnosticWebViewHost,
    renderer: diagnosticRenderer,
    generationId: diagnosticGeneration,
  );

  final diagnosticController = DiagnosticController(
    settings: SharedPreferencesDiagnosticSettingsStore(),
    storage: diagnosticStorage,
    recorder: diagnosticRecorder,
    platform: diagnosticPlatform,
    webViewHost: diagnosticWebViewHost,
    renderer: diagnosticRenderer,
    generationId: diagnosticGeneration,
    renderingModeName: () => gameRenderingModeController.mode.storageName,
    exporter: DiagnosticExportService(
      storage: diagnosticStorage,
      exportDirectory: Directory(
        p.join(temporaryDirectory.path, 'diagnostics-export'),
      ),
      platform: diagnosticPlatform,
      appVersion: '${packageInfo.version}+${packageInfo.buildNumber}',
    ),
    performanceMonitor: diagnosticPerformanceMonitor,
    onAttachObservers: () {
      gameApiEventPipeline.observer = diagnosticApiObserver;
      browserController.addListener(recordBrowserState);
    },
    onDetachObservers: () {
      if (identical(gameApiEventPipeline.observer, diagnosticApiObserver)) {
        gameApiEventPipeline.observer = null;
      }
      browserController.removeListener(recordBrowserState);
    },
  );
  await diagnosticController.initialize();

  const telemetrySettingsStore = SharedPreferencesTelemetrySettingsStore();
  final telemetryService = AppTelemetryService(
    telemetryDeckAppID: '685D5F38-DD7D-48CB-896D-88642F96F92D',
    appVersion: currentVersion,
    diagnosticPlatformPort: diagnosticPlatform,
  );
  final telemetryController = await TelemetryController.create(
    store: telemetrySettingsStore,
    service: telemetryService,
  );

  const notificationTimerAnchorStore =
      SharedPreferencesNotificationTimerAnchorStore();
  final notificationTimerAnchors = await notificationTimerAnchorStore.load();
  notificationCoordinator = GameNotificationCoordinator(
    accountSession: accountSession,
    gameStateController: gameStateController,
    settingsController: notificationSettingsController,
    localeCodeProvider: () =>
        layoutSettingsController.localeCode ??
        _localeStorageCode(WidgetsBinding.instance.platformDispatcher.locale),
    localeListenable: layoutSettingsController,
    notificationPort: const _IOSNotificationPort(),
    initialTimerAnchors: notificationTimerAnchors,
    timerAnchorStore: notificationTimerAnchorStore,
  );
  notificationCoordinator.start();

  runApp(
    _IOSYahagiApp(
      layoutSettingsController: layoutSettingsController,
      networkSettingsController: networkSettingsController,
      gadgetBypassController: gadgetBypassController,
      safetySettingsController: safetySettingsController,
      notificationSettingsController: notificationSettingsController,
      battlePredictionSettingsController: battlePredictionSettingsController,
      gameFrameRateSettingsController: gameFrameRateSettingsController,
      gameRenderingModeController: gameRenderingModeController,
      gameConnectorController: gameConnectorController,
      backgroundGameRetentionController: backgroundGameRetentionController,
      displayModeController: displayModeController,
      controller: controller,
      browserController: browserController,
      captureModeController: captureModeController,
      audioController: audioController,
      toolbarController: toolbarController,
      toolbarDisplayController: toolbarDisplayController,
      gameScreenshotController: gameScreenshotController,
      gameCaptureController: gameCaptureController,
      gameApiEventPipeline: gameApiEventPipeline,
      kcwikiReportController: kcwikiReportController,
      kcwikiReportConsumer: kcwikiReportConsumer,
      gameStateController: gameStateController,
      newShipReminderController: newShipReminderController,
      moraleRecoveryTimerController:
          notificationCoordinator.moraleRecoveryTimerController,
      gameResourceCacheController: gameResourceCacheController,
      senkaController: senkaController,
      battleController: battleController,
      fcdMapController: fcdMapController,
      questCatalogController: questCatalogController,
      sortieMapCatalogController: sortieMapCatalogController,
      enemyCatalogController: enemyCatalogController,
      improvementPlannerController: improvementPlannerController,
      currentVersion: currentVersion,
      releaseChecker: releaseChecker,
      screenAwakeController: screenAwakeController,
      headerNoticeController: headerNoticeController,
      gameInfoNoticeController: gameInfoNoticeController,
      gameMouseWheelSettingsController: gameMouseWheelSettingsController,
      gameFrameRefreshShortcutSettings: gameFrameRefreshShortcutSettings,
      diagnosticController: diagnosticController,
      telemetryController: telemetryController,
      rawDataServerController: rawDataServerController,
      nativeWebViewGenerationSink: (value) {
        diagnosticNativeWebViewGeneration = value;
      },
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(fcdMapController.checkForUpdates());
    unawaited(questCatalogController.checkForUpdates());
    unawaited(improvementPlannerController.checkForUpdates());
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (telemetryController.enabled) {
        unawaited(telemetryController.startIfEnabled());
      }
    });
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

final class _IOSRawDataConsumer implements GameApiEventConsumer {
  _IOSRawDataConsumer(this._controller);

  final RawDataServerController _controller;

  @override
  bool supportsPath(String path) => path.contains('/api_start2/getData');

  @override
  void accept(CapturedApiEvent event) {
    if (_controller.developerMode) {
      _controller.saveRawMasterData(event.responseBody);
    }
  }

  @override
  Future<void> get idle => Future.value();
}

final class _IOSNotificationPort implements NotificationPort {
  const _IOSNotificationPort();

  @override
  Future<NotificationApplyResult> applySnapshot(
    NotificationSnapshot snapshot,
  ) async {
    return const NotificationApplyResult(
      scheduledExact: 0,
      scheduledInexact: 0,
      canceled: 0,
      failures: <String>[],
    );
  }

  @override
  Future<NotificationPlatformCapabilities> getCapabilities() async {
    return const NotificationPlatformCapabilities(
      notificationsGranted: false,
      exactAlarmsGranted: false,
      channelsEnabled: false,
    );
  }

  @override
  Future<bool> requestNotificationPermission() async => false;

  @override
  Future<void> requestExactAlarmPermission() async {}

  @override
  Future<void> openSystemNotificationSettings() async {}
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
    this.notificationSettingsController,
    this.battlePredictionSettingsController,
    this.gameFrameRateSettingsController,
    this.gameRenderingModeController,
    this.gameConnectorController,
    this.backgroundGameRetentionController,
    required this.displayModeController,
    required this.controller,
    required this.browserController,
    required this.captureModeController,
    required this.audioController,
    required this.toolbarController,
    required this.gameCaptureController,
    this.gameApiEventPipeline,
    this.kcwikiReportController,
    this.kcwikiReportConsumer,
    required this.gameStateController,
    this.newShipReminderController,
    this.moraleRecoveryTimerController,
    this.gameResourceCacheController,
    this.senkaController,
    required this.battleController,
    this.fcdMapController,
    this.questCatalogController,
    this.sortieMapCatalogController,
    this.enemyCatalogController,
    this.improvementPlannerController,
    this.currentVersion = '1.0.2',
    this.releaseChecker,
    this.screenAwakeController,
    this.headerNoticeController,
    this.gameInfoNoticeController,
    this.gameMouseWheelSettingsController,
    this.gameFrameRefreshShortcutSettings,
    this.toolbarDisplayController,
    this.gameScreenshotController,
    this.diagnosticController,
    this.telemetryController,
    this.nativeWebViewGenerationSink,
    this.rawDataServerController,
  });

  final LayoutSettingsController layoutSettingsController;
  final NetworkSettingsController networkSettingsController;
  final GadgetBypassController gadgetBypassController;
  final SafetySettingsController safetySettingsController;
  final NotificationSettingsController? notificationSettingsController;
  final BattlePredictionSettingsController? battlePredictionSettingsController;
  final GameFrameRateSettingsController? gameFrameRateSettingsController;
  final GameRenderingModeController? gameRenderingModeController;
  final GameConnectorController? gameConnectorController;
  final BackgroundGameRetentionController? backgroundGameRetentionController;
  final DisplayModeController displayModeController;
  final PrototypeStatusController controller;
  final GameBrowserController browserController;
  final CaptureModeController captureModeController;
  final GameAudioController audioController;
  final GameToolbarController toolbarController;
  final GameCaptureController gameCaptureController;
  final GameApiEventPipeline? gameApiEventPipeline;
  final KcwikiReportController? kcwikiReportController;
  final KcwikiReportConsumer? kcwikiReportConsumer;
  final GameStateController gameStateController;
  final NewShipReminderController? newShipReminderController;
  final MoraleRecoveryTimerController? moraleRecoveryTimerController;
  final GameResourceCacheController? gameResourceCacheController;
  final SenkaController? senkaController;
  final BattleController battleController;
  final FcdMapController? fcdMapController;
  final QuestCatalogController? questCatalogController;
  final SortieMapCatalogController? sortieMapCatalogController;
  final EnemyCatalogController? enemyCatalogController;
  final ImprovementPlannerController? improvementPlannerController;
  final String currentVersion;
  final ReleaseChecker? releaseChecker;
  final ScreenAwakeController? screenAwakeController;
  final TopNoticeController? headerNoticeController;
  final GameInfoNoticeController? gameInfoNoticeController;
  final GameMouseWheelSettingsController? gameMouseWheelSettingsController;
  final GameFrameRefreshShortcutSettings? gameFrameRefreshShortcutSettings;
  final GameToolbarDisplayController? toolbarDisplayController;
  final GameScreenshotController? gameScreenshotController;
  final DiagnosticController? diagnosticController;
  final TelemetryController? telemetryController;
  final void Function(int)? nativeWebViewGenerationSink;
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
      oldWidget.rawDataServerController
          ?.removeListener(_onRawDataControllerChanged);
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
      notificationSettingsController: widget.notificationSettingsController,
      battlePredictionSettingsController:
          widget.battlePredictionSettingsController,
      gameFrameRateSettingsController: widget.gameFrameRateSettingsController,
      gameRenderingModeController: widget.gameRenderingModeController,
      gameConnectorController: widget.gameConnectorController,
      backgroundGameRetentionController:
          widget.backgroundGameRetentionController,
      displayModeController: widget.displayModeController,
      controller: widget.controller,
      browserController: widget.browserController,
      captureModeController: widget.captureModeController,
      audioController: widget.audioController,
      toolbarController: widget.toolbarController,
      toolbarDisplayController: widget.toolbarDisplayController,
      gameScreenshotController: widget.gameScreenshotController,
      gameCaptureController: widget.gameCaptureController,
      gameApiEventPipeline: widget.gameApiEventPipeline,
      kcwikiReportController: widget.kcwikiReportController,
      kcwikiReportConsumer: widget.kcwikiReportConsumer,
      gameStateController: widget.gameStateController,
      newShipReminderController: widget.newShipReminderController,
      moraleRecoveryTimerController: widget.moraleRecoveryTimerController,
      gameResourceCacheController: widget.gameResourceCacheController,
      senkaController: widget.senkaController,
      battleController: widget.battleController,
      fcdMapController: widget.fcdMapController,
      questCatalogController: widget.questCatalogController,
      sortieMapCatalogController: widget.sortieMapCatalogController,
      enemyCatalogController: widget.enemyCatalogController,
      improvementPlannerController: widget.improvementPlannerController,
      currentVersion: widget.currentVersion,
      releaseChecker: widget.releaseChecker,
      screenAwakeController: widget.screenAwakeController,
      headerNoticeController: widget.headerNoticeController,
      gameInfoNoticeController: widget.gameInfoNoticeController,
      gameMouseWheelSettingsController: widget.gameMouseWheelSettingsController,
      gameFrameRefreshShortcutSettings: widget.gameFrameRefreshShortcutSettings,
      showDeveloperDiagnostics: _developerMode,
      diagnosticController: widget.diagnosticController,
      telemetryController: widget.telemetryController,
      nativeWebViewGenerationSink: widget.nativeWebViewGenerationSink,
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
