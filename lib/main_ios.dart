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

import 'main.dart';
import 'src/backup/record_backup.dart';
import 'src/ios/ios_backup_document_port.dart';
import 'src/ios/ios_camera_geometry_host.dart';
import 'src/ios/ios_custom_font_store.dart';
import 'src/ios/ios_game_state_cache.dart';
import 'src/ios/ios_telemetry.dart';
import 'src/localization/record_backup_strings.dart';
import 'src/subtitles/ship_subtitle_runtime_controller.dart';
import 'src/subtitles/ship_subtitle_settings.dart';
import 'src/theme/custom_font_controller.dart';
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
import 'src/browser/game_workspace_visibility.dart';
import 'src/browser/game_resource_cache_channel.dart';
import 'src/browser/game_resource_cache_controller.dart';
import 'src/browser/game_resource_cache_store.dart';
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
import 'src/notification/method_channel_notification_port.dart';
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

import 'src/localization/ui_locale.dart';
import 'src/localization/game_name_catalog.dart';
import 'src/notice/debuff_reminder_controller.dart';
import 'src/notification/new_ship_notification.dart';
import 'src/quest/quest_progress_dataset.dart';
import 'src/quest/quest_progress_dataset_store.dart';
import 'src/quest/quest_progress_rules_controller.dart';
import 'src/quest/quest_progress_update_service.dart';
import 'src/subtitles/ship_subtitle_catalog_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  IOSGameStateCache? gameStateCache;
  try {
    gameStateCache = await IOSGameStateCache.create();
    await gameStateCache.migratePreferences(
      await SharedPreferences.getInstance(),
    );
  } on Object catch (error) {
    debugPrint('iOS game cache migration deferred: ${error.runtimeType}');
  }
  final accountSession = AccountSession.shared;
  LogbookDatabase.bindAccountSession(accountSession);
  late final GameApiEventPipeline gameApiEventPipeline;
  late final GameCaptureController gameCaptureController;
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  final customFontController = await CustomFontController.load(
    store: const IOSCustomFontStore(),
  );
  final layoutSettingsController = await LayoutSettingsController.load(
    SharedPreferencesLayoutSettingsStore(),
    customFontController: customFontController,
    systemLocaleCode: uiLocaleStorageCode(
      WidgetsBinding.instance.platformDispatcher.locale,
    ),
  );
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
  final gameConnectorController = await GameConnectorController.load(
    SharedPreferencesGameConnectorStore(),
  );
  final backgroundGameRetentionController =
      await BackgroundGameRetentionController.load(
        SharedPreferencesBackgroundGameRetentionStore(),
      );
  if (backgroundGameRetentionController.enabled) {
    await backgroundGameRetentionController.setEnabled(false);
  }
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
  final gameStateStore = GameStateStore(
    readString: gameStateCache?.readString,
    writeString: gameStateCache?.writeString,
  );
  final questProgressDatasetStore = QuestProgressDatasetStore(
    const PreferencesQuestProgressDatasetStorage(),
  );
  final bundledQuestProgressDataset = await QuestProgressDataset.loadBundled();
  final questProgressDataset = await questProgressDatasetStore
      .loadBestAvailable(bundledQuestProgressDataset);
  final gameStateController = GameStateController(
    accountSession: accountSession,
    questStore: questStore,
    questProgress: QuestProgressEngine(
      goals: questProgressDataset.goals,
      storage: PreferencesQuestProgressStorage(),
    ),
    gameStateStore: gameStateStore,
  );
  await gameStateController.initialize();
  final kcwikiReportController = await KcwikiReportController.load(
    SharedPreferencesKcwikiReportSettingsStore(),
  );
  final gameResourceCacheController = GameResourceCacheController(
    port: const _IosDisabledGameResourceCachePort(),
  );
  await gameResourceCacheController.initialize();
  await gameResourceCacheController.setMode(GameResourceCacheMode.none);
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
  final questProgressRulesController = QuestProgressRulesController(
    dataset: questProgressDataset,
    sourceHost: identical(questProgressDataset, bundledQuestProgressDataset)
        ? ''
        : 'github.com',
    updater: QuestProgressUpdateService(
      client: http.Client(),
      store: questProgressDatasetStore,
      appVersion: currentVersion,
    ),
    onUpdated: (dataset) =>
        gameStateController.updateQuestProgressGoals(dataset.goals),
  );
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
  String notificationLocaleCode() =>
      layoutSettingsController.localeCode ??
      uiLocaleStorageCode(WidgetsBinding.instance.platformDispatcher.locale);
  late final GameNotificationCoordinator notificationCoordinator;
  late final ShipSubtitleCatalogController shipSubtitleCatalogController;
  GameNameCatalog? notificationNameCache;
  GameNameCatalog notificationNames() {
    final bundle = shipSubtitleCatalogController.kc3Bundle;
    final locale = Locale(notificationLocaleCode());
    final cached = notificationNameCache;
    if (cached != null &&
        cached.locale == locale &&
        identical(cached.bundle, bundle)) {
      return cached;
    }
    return notificationNameCache = GameNameCatalog(
      bundle: bundle,
      locale: locale,
    );
  }

  final newShipReminderController = NewShipReminderController(
    accountSession: accountSession,
    stateProvider: () => gameStateController.state,
    waitForGameState: () => gameStateController.idle,
    store: NewShipReminderStore(await SharedPreferences.getInstance()),
    onPublish: (alert) {
      notificationCoordinator.enqueueImmediateAlert(
        buildNewShipNotification(
          alert: alert,
          state: gameStateController.state,
          localeCode: notificationLocaleCode(),
          names: notificationNames(),
        ),
      );
    },
  );
  final headerNoticeController = TopNoticeController();
  final gameInfoNoticeController = GameInfoNoticeController(
    namesProvider: notificationNames,
    stateProvider: () => gameStateController.state,
    accountSession: accountSession,
    layoutSettingsController: layoutSettingsController,
    topNoticeController: headerNoticeController,
  );
  final debuffReminderController = DebuffReminderController(
    accountSession: accountSession,
  );
  final rawDataServerController = RawDataServerController();
  gameApiEventPipeline = GameApiEventPipeline(
    settleGameState: () async {
      await gameStateController.idle;
      await battleController.idle;
      await gameStateController.idle;
    },
    consumers: <GameApiEventConsumer>[
      _IOSRawDataConsumer(rawDataServerController),
      accountSession,
      gameStateController,
      kcwikiReportConsumer,
      gameResourceManifestConsumer,
      senkaController,
      battleController,
      newShipReminderController,
      gameInfoNoticeController,
      debuffReminderController,
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
    onCaptureInterrupted: () {
      gameApiEventPipeline.invalidateQueuedEvents();
      battleController.invalidateCaptureContinuity();
    },
  );
  final releaseChecker = GitHubReleaseChecker();
  final gameMouseWheelSettingsController =
      await GameMouseWheelSettingsController.load();
  final shipSubtitleSettingsController =
      await ShipSubtitleSettingsController.load();
  shipSubtitleCatalogController = await ShipSubtitleCatalogController.load(
    language: shipSubtitleSettingsController.language,
  );
  final shipSubtitleRuntimeController = ShipSubtitleRuntimeController(
    settings: shipSubtitleSettingsController,
    catalog: shipSubtitleCatalogController,
    layout: layoutSettingsController,
    gameState: gameStateController,
  );
  await shipSubtitleRuntimeController.initialize();
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
  DateTime? browserNavigationStartedAt;
  void recordBrowserState() {
    final state = browserController.loadState;
    if (state == lastBrowserDiagnosticState) return;
    lastBrowserDiagnosticState = state;
    final now = DateTime.now();
    if (state == GamePageLoadState.loading) browserNavigationStartedAt = now;
    final elapsed = browserNavigationStartedAt == null
        ? 0
        : now.difference(browserNavigationStartedAt!).inMilliseconds;
    diagnosticRecorder.record(
      DiagnosticEvent.webViewState(
        occurredAt: now,
        state: state.name,
        durationMs: elapsed < 0 ? 0 : elapsed,
      ),
    );
  }

  DiagnosticWebViewHost diagnosticWebViewHost() =>
      DiagnosticWebViewHost.flutterPlatformView;
  DiagnosticGameRenderer diagnosticRenderer() => DiagnosticGameRenderer.webgl;
  int diagnosticGeneration() => 0;
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
    renderingModeName: () => 'wkWebView',
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
    telemetryDeckStartFn: startIOSTelemetry,
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
    localeCodeProvider: notificationLocaleCode,
    namesProvider: notificationNames,
    namesListenable: shipSubtitleCatalogController,
    localeListenable: layoutSettingsController,
    notificationPort: const MethodChannelNotificationPort(),
    initialTimerAnchors: notificationTimerAnchors,
    timerAnchorStore: notificationTimerAnchorStore,
  );
  notificationCoordinator.start();
  final backupService = RecordBackupService(
    session: accountSession,
    port: const IOSBackupDocumentPort(),
    senkaStore: senkaController.store as SenkaBackupStore,
    senkaController: senkaController,
  );
  Object? backupStartupError;
  RecordBackupService.shared = backupService;
  try {
    await backupService.start();
  } catch (error) {
    debugPrint('Record backup initialization failed: $error');
    backupStartupError = error;
  }
  final backupMaintenanceOverlay = ValueNotifier<Widget?>(null);
  final app = _IOSYahagiApp(
    layoutSettingsController: layoutSettingsController,
    networkSettingsController: networkSettingsController,
    gadgetBypassController: gadgetBypassController,
    safetySettingsController: safetySettingsController,
    notificationSettingsController: notificationSettingsController,
    battlePredictionSettingsController: battlePredictionSettingsController,
    gameFrameRateSettingsController: gameFrameRateSettingsController,
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
    debuffReminderController: debuffReminderController,
    moraleRecoveryTimerController:
        notificationCoordinator.moraleRecoveryTimerController,
    gameResourceCacheController: gameResourceCacheController,
    senkaController: senkaController,
    battleController: battleController,
    fcdMapController: fcdMapController,
    questCatalogController: questCatalogController,
    questProgressRulesController: questProgressRulesController,
    sortieMapCatalogController: sortieMapCatalogController,
    enemyCatalogController: enemyCatalogController,
    improvementPlannerController: improvementPlannerController,
    currentVersion: currentVersion,
    releaseChecker: releaseChecker,
    screenAwakeController: screenAwakeController,
    headerNoticeController: headerNoticeController,
    gameInfoNoticeController: gameInfoNoticeController,
    gameMouseWheelSettingsController: gameMouseWheelSettingsController,
    shipSubtitleSettingsController: shipSubtitleSettingsController,
    shipSubtitleCatalogController: shipSubtitleCatalogController,
    shipSubtitleRuntimeController: shipSubtitleRuntimeController,
    gameFrameRefreshShortcutSettings: gameFrameRefreshShortcutSettings,
    diagnosticController: diagnosticController,
    telemetryController: telemetryController,
    rawDataServerController: rawDataServerController,
    backupMaintenanceOverlay: backupMaintenanceOverlay,
  );

  var mainAppLaunched = false;
  void launchMainApp() {
    mainAppLaunched = true;
    runApp(GameWorkspaceSurfacePolicy(keepInWindow: true, child: app));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(fcdMapController.checkForUpdates());
      unawaited(questCatalogController.checkForUpdates());
      unawaited(questProgressRulesController.checkForUpdates());
      unawaited(improvementPlannerController.checkForUpdates());
      unawaited(
        const MethodChannelNotificationPort().requestNotificationPermission(),
      );
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (telemetryController.enabled) {
          unawaited(telemetryController.startIfEnabled());
        }
      });
    });
  }

  Future<void> finishBackupMaintenance() async {
    // Keep the document cutoff before reload so only the new game's responses
    // can write to the restored records. The WebView itself stays mounted.
    gameApiEventPipeline.resumeAfterMaintenance();
    try {
      if (mainAppLaunched) await browserController.reload();
      backupMaintenanceOverlay.value = null;
    } catch (error) {
      backupMaintenanceOverlay.value = _IOSBackupRecoveryGate(
        service: backupService,
        initialError: error,
        onRecovered: () => unawaited(finishBackupMaintenance()),
      );
    }
  }

  backupService.configureMaintenance(
    begin: () async {
      gameApiEventPipeline.pauseForMaintenance();
      // Keep the live WebView's native message listener installed. The pipeline
      // drops old-document responses and reload starts a new document below.
      gameCaptureController.clearCapturedEvents();
      backupMaintenanceOverlay.value = const _IOSBackupMaintenanceScreen();
      await WidgetsBinding.instance.endOfFrame;
      await gameApiEventPipeline.idle;
      await gameStateController.logbookIdle;
      await senkaController.idle;
    },
    end: () => unawaited(finishBackupMaintenance()),
    blocked: (error) {
      backupMaintenanceOverlay.value = _IOSBackupRecoveryGate(
        service: backupService,
        initialError: error,
        onRecovered: () => unawaited(finishBackupMaintenance()),
      );
    },
  );
  WidgetsBinding.instance.addObserver(
    _IOSBackupLifecycleFlushObserver(
      service: backupService,
      pipeline: gameApiEventPipeline,
      gameState: gameStateController,
    ),
  );

  if (backupStartupError != null) {
    runApp(
      MaterialApp(
        home: _IOSBackupRecoveryGate(
          service: backupService,
          initialError: backupStartupError,
          onRecovered: launchMainApp,
        ),
      ),
    );
  } else {
    launchMainApp();
  }
}

class _IOSBackupLifecycleFlushObserver with WidgetsBindingObserver {
  _IOSBackupLifecycleFlushObserver({
    required this.service,
    required this.pipeline,
    required this.gameState,
  });

  final RecordBackupService service;
  final GameApiEventPipeline pipeline;
  final GameStateController gameState;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.paused &&
        state != AppLifecycleState.detached) {
      return;
    }
    unawaited(_flush());
  }

  Future<void> _flush() async {
    if (!service.hasDirectory || service.maintenanceActive) return;
    try {
      await pipeline.idle;
      await gameState.logbookIdle;
      await service.flush();
    } catch (error) {
      debugPrint('Backup lifecycle flush failed: $error');
    }
  }
}

class _IOSBackupRecoveryGate extends StatefulWidget {
  const _IOSBackupRecoveryGate({
    required this.service,
    required this.initialError,
    required this.onRecovered,
  });

  final RecordBackupService service;
  final Object initialError;
  final VoidCallback onRecovered;

  @override
  State<_IOSBackupRecoveryGate> createState() => _IOSBackupRecoveryGateState();
}

class _IOSBackupRecoveryGateState extends State<_IOSBackupRecoveryGate> {
  late Object _error = widget.initialError;
  bool _busy = false;

  Future<void> _retry({required bool chooseFolder}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final wasMaintenance = widget.service.maintenanceActive;
      if (chooseFolder &&
          !await widget.service.reselectDirectoryForRecovery()) {
        return;
      }
      await widget.service.start();
      await widget.service.recoverPendingRestores();
      if (!wasMaintenance) widget.onRecovered();
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = RecordBackupStrings.of(context);
    final journalCorrupt =
        _error is FormatException ||
        '$_error'.contains('Restore completion marker mismatch');
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(strings.recoveryPending),
              const SizedBox(height: 12),
              Text('$_error'),
              const SizedBox(height: 12),
              Text(
                journalCorrupt
                    ? strings.recoveryCorruptAdvice
                    : strings.recoveryRetryAdvice,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : () => _retry(chooseFolder: false),
                child: Text(strings.retryRestore),
              ),
              if (!journalCorrupt)
                TextButton(
                  onPressed: _busy ? null : () => _retry(chooseFolder: true),
                  child: Text(strings.reselectFolder),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IOSBackupMaintenanceScreen extends StatelessWidget {
  const _IOSBackupMaintenanceScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(RecordBackupStrings.of(context).restoring),
        ],
      ),
    ),
  );
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
    this.questProgressRulesController,
    this.debuffReminderController,
    this.shipSubtitleSettingsController,
    this.shipSubtitleCatalogController,
    this.shipSubtitleRuntimeController,
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
    this.rawDataServerController,
    this.backupMaintenanceOverlay,
  });

  final LayoutSettingsController layoutSettingsController;
  final NetworkSettingsController networkSettingsController;
  final GadgetBypassController gadgetBypassController;
  final SafetySettingsController safetySettingsController;
  final NotificationSettingsController? notificationSettingsController;
  final BattlePredictionSettingsController? battlePredictionSettingsController;
  final GameFrameRateSettingsController? gameFrameRateSettingsController;
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
  final QuestProgressRulesController? questProgressRulesController;
  final DebuffReminderController? debuffReminderController;
  final ShipSubtitleSettingsController? shipSubtitleSettingsController;
  final ShipSubtitleCatalogController? shipSubtitleCatalogController;
  final ShipSubtitleRuntimeController? shipSubtitleRuntimeController;
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
  final RawDataServerController? rawDataServerController;
  final ValueNotifier<Widget?>? backupMaintenanceOverlay;

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
      oldWidget.rawDataServerController?.removeListener(
        _onRawDataControllerChanged,
      );
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
          TopNotice.show(context, message: '当前已处于开发者模式');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawController = widget.rawDataServerController;
    return IOSCameraGeometryHost(
      child: YahagiApp(
        layoutSettingsController: widget.layoutSettingsController,
        networkSettingsController: widget.networkSettingsController,
        gadgetBypassController: widget.gadgetBypassController,
        safetySettingsController: widget.safetySettingsController,
        notificationSettingsController: widget.notificationSettingsController,
        battlePredictionSettingsController:
            widget.battlePredictionSettingsController,
        gameFrameRateSettingsController: widget.gameFrameRateSettingsController,
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
        questProgressRulesController: widget.questProgressRulesController,
        debuffReminderController: widget.debuffReminderController,
        shipSubtitleSettingsController: widget.shipSubtitleSettingsController,
        shipSubtitleCatalogController: widget.shipSubtitleCatalogController,
        shipSubtitleRuntimeController: widget.shipSubtitleRuntimeController,
        questCatalogController: widget.questCatalogController,
        sortieMapCatalogController: widget.sortieMapCatalogController,
        enemyCatalogController: widget.enemyCatalogController,
        improvementPlannerController: widget.improvementPlannerController,
        currentVersion: widget.currentVersion,
        releaseChecker: widget.releaseChecker,
        screenAwakeController: widget.screenAwakeController,
        headerNoticeController: widget.headerNoticeController,
        gameInfoNoticeController: widget.gameInfoNoticeController,
        gameMouseWheelSettingsController:
            widget.gameMouseWheelSettingsController,
        gameFrameRefreshShortcutSettings:
            widget.gameFrameRefreshShortcutSettings,
        showDeveloperDiagnostics: false,
        diagnosticController: widget.diagnosticController,
        telemetryController: widget.telemetryController,
        backupMaintenanceOverlay: widget.backupMaintenanceOverlay,
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
          diagnosticRecorder: widget.diagnosticController?.recorder,
        ),
      ),
    );
  }
}

final class _IosDisabledGameResourceCachePort implements GameResourceCachePort {
  const _IosDisabledGameResourceCachePort();

  @override
  Future<bool> configure(GameResourceCacheMode mode) async => true;

  @override
  Future<GameResourceCacheStatus> status() async =>
      GameResourceCacheStatus.empty;

  @override
  Future<bool> setManifest(
    GameResourceManifest manifest, {
    bool Function()? shouldContinue,
  }) async => false;

  @override
  Future<bool> startDownload({bool allowMetered = false}) async => false;

  @override
  Future<bool> pauseDownload() async => false;

  @override
  Future<GameResourceCacheStatus> checkIntegrity() async =>
      GameResourceCacheStatus.empty;

  @override
  Future<bool> repair({bool allowMetered = false}) async => false;

  @override
  Future<bool> clear() async => false;
}
