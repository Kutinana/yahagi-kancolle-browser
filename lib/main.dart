import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'src/widgets/app_scroll_behavior.dart';
import 'src/settings/fleet_display_settings_section.dart';
import 'src/settings/module_display_settings.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import 'src/battle/battle_controller.dart';
import 'src/battle/battle_damage_alert.dart';
import 'src/battle/fcd_map_controller.dart';
import 'src/battle/fcd_map_store.dart';
import 'src/battle/fcd_map_update_service.dart';
import 'src/battle/formation_memory.dart';
import 'src/logbook/logbook_database.dart';
import 'src/logbook/logbook_page.dart';
import 'src/battle/live_battle_card.dart';
import 'src/audio/game_audio_controller.dart';
import 'src/audio/game_audio_store.dart';
import 'src/browser/game_browser_controller.dart';
import 'src/browser/gadget_bypass_controller.dart';
import 'src/browser/gadget_bypass_store.dart';
import 'src/browser/game_browser_overlay.dart';
import 'src/browser/game_browser_toolbar.dart';
import 'src/browser/game_fullscreen_controls.dart';
import 'src/browser/game_frame_reload_port.dart';
import 'src/browser/game_refresh_dialog.dart';
import 'src/browser/game_toolbar_controller.dart';
import 'src/browser/game_toolbar_display_controller.dart';
import 'src/browser/game_screenshot_controller.dart';
import 'src/browser/game_surface_boundary.dart';
import 'src/browser/game_surface_viewport.dart';
import 'src/browser/game_workspace_visibility.dart';
import 'src/browser/game_environment_host.dart';
import 'src/browser/game_application_restart_port.dart';
import 'src/browser/game_resource_cache_controller.dart';
import 'src/browser/game_resource_manifest_builder.dart';
import 'src/browser/game_resource_manifest_consumer.dart';
import 'src/browser/native_game_surface_slot.dart';
import 'src/capture/battle_result_warning_overlay.dart';
import 'src/capture/capture_mode_controller.dart';
import 'src/capture/capture_mode_store.dart';
import 'src/capture/game_capture_controller.dart';
import 'src/notice/game_info_notice_controller.dart';
import 'src/capture/game_capture_port.dart';
import 'src/diagnostics/diagnostic_controller.dart';
import 'src/diagnostics/diagnostic_event.dart';
import 'src/diagnostics/diagnostic_export_service.dart';
import 'src/diagnostics/diagnostic_game_api_observer.dart';
import 'src/diagnostics/diagnostic_performance_monitor.dart';
import 'src/diagnostics/diagnostic_platform_port.dart';
import 'src/telemetry/telemetry_controller.dart';
import 'src/telemetry/telemetry_service.dart';
import 'src/telemetry/telemetry_settings_store.dart';
import 'src/diagnostics/diagnostic_recorder.dart';
import 'src/diagnostics/diagnostic_settings_store.dart';
import 'src/diagnostics/diagnostic_storage.dart';
import 'src/development/development_repository.dart';
import 'src/fleet/fleet_information_center.dart';
import 'src/settings/battle_status_effect_settings.dart';
import 'src/settings/header_resource_settings.dart';
import 'src/settings/workspace_menu_settings.dart';
import 'src/fleet/anchorage_repair_navigation.dart';
import 'src/fleet/anchorage_repair_view.dart';
import 'src/fleet/fleet_summary_card.dart';
import 'src/fleet/land_base_summary_card.dart';
import 'src/fleet/expedition_summary_card.dart';
import 'src/fleet/repair_summary_card.dart';
import 'src/fleet/construction_summary_card.dart';
import 'src/fleet/nosaki_sparkle_calculator.dart';
import 'src/fleet/morale_recovery_timer_controller.dart';
import 'src/fleet/pre_sortie_check_summary.dart';

import 'src/game_webview.dart';
import 'src/native_activity_game_surface.dart';
import 'src/game_state/game_state_controller.dart';
import 'src/game_state/game_state.dart';
import 'src/account/account_session.dart';
import 'src/game_state/game_api_event_pipeline.dart';
import 'src/game_state/game_state_store.dart';
import 'src/layout/adaptive_layout.dart';
import 'src/layout/hd_workspace_geometry.dart';
import 'src/layout/hd_bottom_strip.dart';
import 'src/layout/hd_portrait_grid.dart';
import 'src/layout/hd_home_editor.dart';
import 'src/layout/workspace_navigation_side.dart';
import 'src/layout/workspace_context_header.dart';
import 'src/layout/window_metrics_change.dart';
import 'src/layout/window_metrics_recovery_scheduler.dart';
import 'src/kcwiki_report/kcwiki_report_collector.dart';
import 'src/kcwiki_report/kcwiki_report_consumer.dart';
import 'src/kcwiki_report/kcwiki_report_dispatcher.dart';
import 'src/kcwiki_report/kcwiki_report_settings.dart';
import 'src/kcwiki_report/kcwiki_report_transport.dart';
import 'src/performance/second_tick_scope.dart';
import 'src/inventory/owned_inventory_page.dart';
import 'src/new_ship/new_ship_reminder_controller.dart';
import 'src/new_ship/new_ship_reminder_store.dart';
import 'src/notification/game_notification_coordinator.dart';
import 'src/notification/notification_models.dart';
import 'src/improvement/improvement_dataset_store.dart';
import 'src/improvement/improvement_dataset_update_service.dart';
import 'src/improvement/improvement_favorites_store.dart';
import 'src/improvement/improvement_planner_controller.dart';
import 'src/prototype_status_controller.dart';
import 'src/quest/pinned_quests_summary.dart';
import 'src/quest/quest_completion_badge.dart';
import 'src/quest/quest_completion_feedback.dart';
import 'src/quest/quest_completion_drawer.dart';
import 'src/quest/quest_progress_engine.dart';
import 'src/quest/quest_center_page.dart';
import 'src/quest/quest_catalog_controller.dart';
import 'src/quest/quest_catalog_store.dart';
import 'src/quest/quest_catalog_update_service.dart';
import 'src/toolbox/sortie_map_query/sortie_map_catalog.dart';
import 'src/toolbox/sortie_map_query/sortie_map_catalog_controller.dart';
import 'src/toolbox/sortie_map_query/sortie_map_catalog_store.dart';
import 'src/toolbox/sortie_map_query/sortie_map_catalog_update_service.dart';
import 'src/toolbox/sortie_map_query/enemy_catalog.dart';
import 'src/toolbox/sortie_map_query/enemy_catalog_controller.dart';
import 'src/toolbox/sortie_map_query/enemy_catalog_store.dart';
import 'src/toolbox/sortie_map_query/enemy_catalog_update_service.dart';
import 'src/quest/shared_preferences_quest_store.dart';
import 'src/settings/layout_settings_controller.dart';
import 'src/settings/layout_settings_store.dart';
import 'src/settings/ui_display_size.dart';
import 'src/settings/network_settings_controller.dart';
import 'src/settings/network_settings_store.dart';
import 'src/settings/display_mode_controller.dart';
import 'src/settings/display_mode_store.dart';
import 'src/settings/orientation_policy.dart';
import 'src/settings/safety_settings_controller.dart';
import 'src/settings/safety_settings_store.dart';
import 'src/settings/settings_page.dart';
import 'src/settings/release_check_service.dart';
import 'src/settings/startup_update_notice.dart';
import 'src/settings/screen_awake_controller.dart';
import 'src/settings/game_mouse_wheel_settings.dart';
import 'src/settings/game_frame_refresh_shortcut_settings.dart';
import 'src/browser/game_frame_refresh_shortcut_dialog.dart';
import 'src/browser/game_frame_refresh_shortcut_action.dart';
import 'src/toolbox/toolbox_page.dart';
import 'src/localization/runtime_message_text.dart';
import 'src/settings/background_game_retention_controller.dart';
import 'src/settings/battle_prediction_settings.dart';
import 'src/settings/game_frame_rate_settings.dart';
import 'src/settings/game_connector_controller.dart';
import 'src/settings/game_connector.dart';
import 'src/settings/game_rendering_mode_controller.dart';
import 'src/settings/game_rendering_mode.dart';
import 'src/settings/notification_settings_controller.dart';
import 'src/settings/notification_settings_store.dart';
import 'src/notification/method_channel_notification_port.dart';
import 'src/notification/notification_timer_anchor_store.dart';
import 'src/senka/senka_controller.dart';
import 'src/senka/senka_page.dart';
import 'src/senka/senka_store.dart';
import 'src/widgets/top_notice.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final accountSession = AccountSession.shared;
  LogbookDatabase.bindAccountSession(accountSession);
  late final GameApiEventPipeline gameApiEventPipeline;
  late final GameCaptureController gameCaptureController;
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  final layoutSettingsController = await LayoutSettingsController.load(
    SharedPreferencesLayoutSettingsStore(),
    systemLocaleCode: _localeStorageCode(
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
      baseUri: Uri.parse(
        const String.fromEnvironment(
          'KCWIKI_REPORT_BASE_URL',
          defaultValue: 'http://report2.kcwiki.org:17027',
        ),
      ),
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
    layoutSettingsController: layoutSettingsController,
    topNoticeController: headerNoticeController,
  );
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
  DiagnosticWebViewHost diagnosticWebViewHost() {
    final mode = gameRenderingModeController.mode;
    if (!mode.usesActivityWebView) {
      return DiagnosticWebViewHost.flutterPlatformView;
    }
    return diagnosticNativeWebViewGeneration >= 0
        ? DiagnosticWebViewHost.activityDirect
        : DiagnosticWebViewHost.absent;
  }

  DiagnosticGameRenderer diagnosticRenderer() {
    final mode = gameRenderingModeController.mode;
    return mode.usesCanvasRenderer
        ? DiagnosticGameRenderer.canvas
        : DiagnosticGameRenderer.webgl;
  }

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
    notificationPort: const MethodChannelNotificationPort(),
    initialTimerAnchors: notificationTimerAnchors,
    timerAnchorStore: notificationTimerAnchorStore,
  );
  notificationCoordinator.start();
  runApp(
    YahagiApp(
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
      gameMouseWheelSettingsController: gameMouseWheelSettingsController,
      gameFrameRefreshShortcutSettings: gameFrameRefreshShortcutSettings,
      diagnosticController: diagnosticController,
      telemetryController: telemetryController,
      nativeWebViewGenerationSink: (value) {
        diagnosticNativeWebViewGeneration = value;
      },
    ),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(fcdMapController.checkForUpdates());
    unawaited(questCatalogController.checkForUpdates());
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (telemetryController.enabled) {
        unawaited(telemetryController.startIfEnabled());
      }
    });
  });
}

final RouteObserver<ModalRoute<dynamic>> yahagiGameRouteObserver =
    YahagiGameRouteObserver();

bool shouldUsePersistentGameToolbar({
  required GameToolbarDisplayMode? displayMode,
  required GameRenderingMode? renderingMode,
}) {
  return displayMode == GameToolbarDisplayMode.persistent ||
      (renderingMode?.usesActivityWebView ?? false);
}

double portraitGamePanelExtraExtent({
  required GameToolbarDisplayMode? displayMode,
  required GameRenderingMode? renderingMode,
}) {
  if (renderingMode?.usesActivityWebView ?? false) {
    return 10;
  }
  return displayMode == GameToolbarDisplayMode.persistent ? 42 : 0;
}

Widget buildGameSurfaceForRenderingMode({
  required GameRenderingMode mode,
  required Key key,
  required Widget Function(Key key) buildNativeActivityGameSurface,
  required Widget Function(Key key, GameRenderingMode mode) buildGameWebView,
  required Widget Function(Widget child) withBattleWarning,
}) {
  if (mode.usesActivityWebView) {
    return withBattleWarning(buildNativeActivityGameSurface(key));
  }
  return withBattleWarning(buildGameWebView(key, mode));
}

class YahagiApp extends StatelessWidget {
  const YahagiApp({
    super.key,
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
    this.newShipReminderController,
    this.kcwikiReportController,
    this.kcwikiReportConsumer,
    required this.gameStateController,
    this.moraleRecoveryTimerController,
    this.gameResourceCacheController,
    this.senkaController,
    required this.battleController,
    this.fcdMapController,
    this.questCatalogController,
    this.sortieMapCatalogController,
    this.enemyCatalogController,
    this.improvementPlannerController,
    this.gameSurface,
    this.currentVersion = '1.0.2',
    this.releaseChecker,
    this.screenAwakeController,
    this.headerNoticeController,
    this.gameMouseWheelSettingsController,
    this.gameFrameRefreshShortcutSettings,
    this.toolbarDisplayController,
    this.gameScreenshotController,
    this.showDeveloperDiagnostics = false,
    this.diagnosticController,
    this.telemetryController,
    this.gameRouteObserver,
    this.nativeWebViewGenerationSink,
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
  final NewShipReminderController? newShipReminderController;
  final KcwikiReportController? kcwikiReportController;
  final KcwikiReportConsumer? kcwikiReportConsumer;
  final GameStateController gameStateController;
  final MoraleRecoveryTimerController? moraleRecoveryTimerController;
  final GameResourceCacheController? gameResourceCacheController;
  final SenkaController? senkaController;
  final BattleController battleController;
  final FcdMapController? fcdMapController;
  final QuestCatalogController? questCatalogController;
  final SortieMapCatalogController? sortieMapCatalogController;
  final EnemyCatalogController? enemyCatalogController;
  final ImprovementPlannerController? improvementPlannerController;
  final Widget? gameSurface;
  final String currentVersion;
  final ReleaseChecker? releaseChecker;
  final ScreenAwakeController? screenAwakeController;
  final TopNoticeController? headerNoticeController;
  final GameMouseWheelSettingsController? gameMouseWheelSettingsController;
  final GameFrameRefreshShortcutSettings? gameFrameRefreshShortcutSettings;
  final GameToolbarDisplayController? toolbarDisplayController;
  final GameScreenshotController? gameScreenshotController;
  final bool showDeveloperDiagnostics;
  final DiagnosticController? diagnosticController;
  final TelemetryController? telemetryController;
  final RouteObserver<ModalRoute<dynamic>>? gameRouteObserver;
  final void Function(int)? nativeWebViewGenerationSink;

  @override
  Widget build(BuildContext context) {
    battleController.bindFriendlyHpUpdater(
      gameStateController.applyFriendlyBattleHp,
    );
    battleController.bindDamageControlUpdater(
      gameStateController.applyDamageControlConsumption,
    );
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        layoutSettingsController,
        safetySettingsController,
        ?toolbarDisplayController,
        ?gameRenderingModeController,
      ]),
      builder: (context, _) {
        final routeObserver = gameRouteObserver ?? yahagiGameRouteObserver;
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          scrollBehavior: const AppScrollBehavior(),
          title: 'ヤハギ',
          locale: layoutSettingsController.localeCode != null
              ? (layoutSettingsController.localeCode == 'zh_Hant'
                    ? const Locale.fromSubtags(
                        languageCode: 'zh',
                        scriptCode: 'Hant',
                      )
                    : Locale(layoutSettingsController.localeCode!))
              : null,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          navigatorObservers: <NavigatorObserver>[routeObserver],
          theme: ThemeData(
            brightness: Brightness.dark,
            fontFamily: layoutSettingsController.fontFamily,
            fontFamilyFallback: layoutSettingsController.fontFamilyFallback,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xffd4a85f),
              brightness: Brightness.dark,
            ),
            scaffoldBackgroundColor: const Color(0xff0a1823),
            useMaterial3: true,
          ),
          home: TopNoticeHost(
            child: StartupUpdateNotice(
              checker: releaseChecker ?? GitHubReleaseChecker(),
              currentVersion: currentVersion,
              enabled: releaseChecker != null,
              child: SecondTickScope(
                child: YahagiShell(
                  layoutSettingsController: layoutSettingsController,
                  networkSettingsController: networkSettingsController,
                  gadgetBypassController: gadgetBypassController,
                  safetySettingsController: safetySettingsController,
                  notificationSettingsController:
                      notificationSettingsController,
                  battlePredictionSettingsController:
                      battlePredictionSettingsController,
                  gameFrameRateSettingsController:
                      gameFrameRateSettingsController,
                  gameRenderingModeController: gameRenderingModeController,
                  gameConnectorController: gameConnectorController,
                  backgroundGameRetentionController:
                      backgroundGameRetentionController,
                  displayModeController: displayModeController,
                  controller: controller,
                  browserController: browserController,
                  captureModeController: captureModeController,
                  audioController: audioController,
                  toolbarController: toolbarController,
                  gameCaptureController: gameCaptureController,
                  kcwikiReportController: kcwikiReportController,
                  kcwikiReportConsumer: kcwikiReportConsumer,
                  gameStateController: gameStateController,
                  newShipReminderController: newShipReminderController,
                  moraleRecoveryTimerController: moraleRecoveryTimerController,
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
                  gameMouseWheelSettingsController:
                      gameMouseWheelSettingsController,
                  gameFrameRefreshShortcutSettings:
                      gameFrameRefreshShortcutSettings,
                  toolbarDisplayController: toolbarDisplayController,
                  gameScreenshotController: gameScreenshotController,
                  headerNoticeController: headerNoticeController,
                  showDeveloperDiagnostics: showDeveloperDiagnostics,
                  diagnosticController: diagnosticController,
                  telemetryController: telemetryController,
                  gameSurface: _buildGameSurface(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGameSurface() {
    Widget withBattleWarning(Widget child) => BattleResultWarningOverlay(
      accountSession: gameStateController.accountSession,
      gameCaptureController: gameCaptureController,
      loadSafetyState: () async {
        final event = gameCaptureController.latestEvent;
        await gameApiEventPipeline?.dispatchIdle;
        await battleController.idle;
        await gameStateController.idle;
        if (event != null &&
            gameApiEventPipeline?.isCurrentDocument(event) == false) {
          return GameState.empty;
        }
        return gameStateController.state;
      },
      safetySettingsController: safetySettingsController,
      damageAlertPort: const MethodChannelBattleDamageAlertPort(),
      child: child,
    );

    if (gameSurface case final injected?) {
      return withBattleWarning(injected);
    }
    final renderingController = gameRenderingModeController;
    if (renderingController == null) {
      return buildGameSurfaceForRenderingMode(
        mode: GameRenderingMode.compatibility,
        key: const GlobalObjectKey('yahagi_game_webview'),
        buildNativeActivityGameSurface: _buildNativeActivityGameSurface,
        buildGameWebView: (key, mode) =>
            _buildGameWebView(key, renderingMode: mode),
        withBattleWarning: withBattleWarning,
      );
    }
    return GameEnvironmentHost(
      controller: renderingController,
      beforeRestart: _waitForCaptureQueues,
      applicationRestartPort: const MethodChannelGameApplicationRestartPort(),
      gameBuilder: (context, mode, key) => buildGameSurfaceForRenderingMode(
        mode: mode,
        key: key,
        buildNativeActivityGameSurface: _buildNativeActivityGameSurface,
        buildGameWebView: (key, mode) =>
            _buildGameWebView(key, renderingMode: mode),
        withBattleWarning: withBattleWarning,
      ),
    );
  }

  Widget _buildNativeActivityGameSurface(Key key) => NativeActivityGameSurface(
    key: key,
    onGenerationChanged: nativeWebViewGenerationSink,
    statusController: controller,
    browserController: browserController,
    toolbarController: toolbarController,
    routeObserver: gameRouteObserver ?? yahagiGameRouteObserver,
    networkSettingsController: networkSettingsController,
    captureModeController: captureModeController,
    audioController: audioController,
    gameCaptureController: gameCaptureController,
    frameRateSettingsController: gameFrameRateSettingsController,
  );

  Widget _buildGameWebView(Key key, {GameRenderingMode? renderingMode}) =>
      GameWebView(
        key: key,
        networkSettingsController: networkSettingsController,
        safetySettingsController: safetySettingsController,
        controller: controller,
        browserController: browserController,
        captureModeController: captureModeController,
        audioController: audioController,
        toolbarController: toolbarController,
        gameCaptureController: gameCaptureController,
        frameRateSettingsController: gameFrameRateSettingsController,
        mouseWheelSettingsController: gameMouseWheelSettingsController,
        renderingMode:
            renderingMode ??
            gameRenderingModeController?.mode ??
            GameRenderingMode.compatibility,
      );

  Future<void> _waitForCaptureQueues() async {
    try {
      await (() async {
        await Future.wait<void>([
          ?gameApiEventPipeline?.idle,
          gameStateController.idle,
          ?senkaController?.idle,
          battleController.idle,
        ]);
        // Snapshot this queue only after all captures have scheduled their logs.
        await gameStateController.logbookIdle;
      })().timeout(const Duration(seconds: 5));
    } on TimeoutException {
      debugPrint(
        'Timed out waiting for capture queues before WebView rebuild.',
      );
    }
  }
}

String _localeStorageCode(Locale locale) {
  if (locale.languageCode == 'ja') return 'ja';
  if (locale.languageCode == 'zh' && locale.scriptCode == 'Hant') {
    return 'zh_Hant';
  }
  return 'zh';
}

class YahagiShell extends StatefulWidget {
  const YahagiShell({
    super.key,
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
    this.backgroundGameRetentionPort,
    required this.displayModeController,
    required this.controller,
    required this.browserController,
    required this.captureModeController,
    required this.audioController,
    required this.toolbarController,
    required this.gameSurface,
    required this.gameCaptureController,
    this.kcwikiReportController,
    this.kcwikiReportConsumer,
    required this.gameStateController,
    this.newShipReminderController,
    this.moraleRecoveryTimerController,
    this.gameResourceCacheController,
    this.senkaController,
    required this.battleController,
    required this.currentVersion,
    this.releaseChecker,
    this.screenAwakeController,
    this.gameMouseWheelSettingsController,
    this.gameFrameRefreshShortcutSettings,
    this.toolbarDisplayController,
    this.gameScreenshotController,
    this.headerNoticeController,
    this.fcdMapController,
    this.questCatalogController,
    this.sortieMapCatalogController,
    this.enemyCatalogController,
    this.improvementPlannerController,
    this.showDeveloperDiagnostics = false,
    this.diagnosticController,
    this.telemetryController,
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
  final BackgroundGameRetentionPort? backgroundGameRetentionPort;
  final DisplayModeController displayModeController;
  final PrototypeStatusController controller;
  final GameBrowserController browserController;
  final CaptureModeController captureModeController;
  final GameAudioController audioController;
  final GameToolbarController toolbarController;
  final Widget gameSurface;
  final GameCaptureController gameCaptureController;
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
  final GameMouseWheelSettingsController? gameMouseWheelSettingsController;
  final GameFrameRefreshShortcutSettings? gameFrameRefreshShortcutSettings;
  final GameToolbarDisplayController? toolbarDisplayController;
  final GameScreenshotController? gameScreenshotController;
  final TopNoticeController? headerNoticeController;
  final bool showDeveloperDiagnostics;
  final DiagnosticController? diagnosticController;
  final TelemetryController? telemetryController;

  @override
  State<YahagiShell> createState() => _YahagiShellState();
}

class _YahagiShellState extends State<YahagiShell> with WidgetsBindingObserver {
  bool _hdEditing = false;
  static const _gameFrameReloadChannel = MethodChannel(
    gameFrameReloadMethodChannelName,
  );
  final WindowMetricsRecoveryScheduler _windowMetricsRecoveryScheduler =
      WindowMetricsRecoveryScheduler();
  WindowMetricsChangeTracker? _windowMetricsChangeTracker;
  int _workspaceIndex = 0;
  bool _gameFullscreen = false;
  Size? _normalWorkspaceSize;
  int? _expeditionCheckFleetId;
  int? _fleetCenterInitialFleetId;
  int? _repairCenterInitialFleetId;
  int? _questCenterInitialQuestId;
  bool _inventoryShowShips = true;
  bool _inventoryShowOwned = true;
  bool _newShipDialogScheduled = false;
  DialogRoute<void>? _newShipDialogRoute;
  int _logbookTabIndex = 0;
  int _settingsTabIndex = 0;
  RepairCenterMode _repairCenterMode = RepairCenterMode.dock;
  QuestCenterMode _questCenterMode = QuestCenterMode.active;
  bool _questTranslationEnabled = false;
  final QuestFilterController _questFilters = QuestFilterController();
  ExpeditionSummaryMode _expeditionCenterMode = ExpeditionSummaryMode.summary;
  ConstructionCenterMode _constructionCenterMode =
      ConstructionCenterMode.construction;
  DevelopmentWorkbenchMode _developmentWorkbenchMode =
      DevelopmentWorkbenchMode.calculator;
  SenkaCenterMode _senkaCenterMode = SenkaCenterMode.info;
  ToolboxMode _toolboxMode = ToolboxMode.export;
  final DevelopmentRepository _developmentRepository = DevelopmentRepository();
  BackgroundGameRetentionCoordinator? _backgroundGameRetentionCoordinator;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.displayModeController.addListener(_onDisplayModeChanged);
    widget.layoutSettingsController.addListener(_onLayoutSettingsChanged);
    widget.newShipReminderController?.addListener(_handleNewShipAlert);
    _gameFrameReloadChannel.setMethodCallHandler(
      _handleNativeGameFrameReloadMessage,
    );
    if (widget.backgroundGameRetentionController case final controller?) {
      _backgroundGameRetentionCoordinator = BackgroundGameRetentionCoordinator(
        controller: controller,
        toolbarController: widget.toolbarController,
        port:
            widget.backgroundGameRetentionPort ??
            const MethodChannelBackgroundGameRetentionPort(),
      );
    }
    _applyOrientationPolicy();
  }

  @override
  void dispose() {
    _gameFrameReloadChannel.setMethodCallHandler(null);
    widget.displayModeController.removeListener(_onDisplayModeChanged);
    widget.layoutSettingsController.removeListener(_onLayoutSettingsChanged);
    widget.newShipReminderController?.removeListener(_handleNewShipAlert);
    widget.kcwikiReportConsumer?.dispose();
    _questFilters.dispose();
    _windowMetricsRecoveryScheduler.dispose();
    _backgroundGameRetentionCoordinator?.dispose();
    widget.telemetryController?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _handleNativeGameFrameReloadMessage(MethodCall call) async {
    if (call.method != 'shortcutResult' || !mounted) return;
    GameFrameReloadResult result;
    try {
      result = decodeGameFrameReloadResult(call.arguments as String?);
    } catch (_) {
      result = GameFrameReloadResult.blocked;
    }
    final message = gameFrameReloadErrorMessage(
      AppLocalizations.of(context) ??
          lookupAppLocalizations(const Locale('zh')),
      result,
    );
    if (message != null && mounted) {
      TopNotice.show(context, message: message, tone: TopNoticeTone.error);
    }
  }

  void _handleNewShipAlert() {
    final controller = widget.newShipReminderController;
    final alert = controller?.currentAlert;
    if (!mounted) return;
    if (alert == null) {
      final route = _newShipDialogRoute;
      if (route != null && route.isActive) {
        route.navigator?.removeRoute(route);
      }
      return;
    }
    if (_newShipDialogScheduled) return;
    _newShipDialogScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (!identical(controller?.currentAlert, alert)) {
        _newShipDialogScheduled = false;
        _handleNewShipAlert();
        return;
      }
      final state = widget.gameStateController.state;
      final l10n = AppLocalizations.of(context)!;
      final names = alert.masterIds
          .map(
            (id) => state.masterShips[id]?.name ?? l10n.newShipFallbackName(id),
          )
          .toList(growable: false);
      final route = DialogRoute<void>(
        context: context,
        builder: (context) => AlertDialog(
          key: const Key('new-ship-alert-dialog'),
          title: Text(l10n.newShipAlertTitle),
          content: Text(l10n.newShipAlertBody(names.join('、'))),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.acknowledge),
            ),
          ],
        ),
      );
      _newShipDialogRoute = route;
      await Navigator.of(context, rootNavigator: true).push<void>(route);
      _newShipDialogRoute = null;
      if (!mounted) return;
      controller?.acknowledge(alert.key);
      _newShipDialogScheduled = false;
      _handleNewShipAlert();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _windowMetricsChangeTracker ??= WindowMetricsChangeTracker(
      WindowMetricsSnapshot.fromView(View.of(context)),
    );
  }

  void _onLayoutSettingsChanged() {
    if (!mounted) return;
    // The route may keep the shell's parent unchanged. Rebuild the workspace
    // explicitly so manual panel ratios apply without navigating or resizing.
    setState(() {
      if (!widget.layoutSettingsController.hdSettings.enabled ||
          widget.layoutSettingsController.uiLocked) {
        _hdEditing = false;
      }
    });
    widget.browserController.fitGameScreen().catchError((Object _) {});
  }

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    final current = WindowMetricsSnapshot.fromView(View.of(context));
    final tracker = _windowMetricsChangeTracker;
    if (tracker != null) {
      final change = tracker.update(current);
      if (change == WindowMetricsChange.imeOnly) {
        _windowMetricsRecoveryScheduler.cancel();
        return;
      }
      if (change == WindowMetricsChange.unchanged) {
        return;
      }
    } else {
      _windowMetricsChangeTracker = WindowMetricsChangeTracker(current);
    }
    _applyOrientationPolicy();
    _scheduleWindowMetricsRecovery();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    widget.audioController.handleLifecycleState(state);
    widget.screenAwakeController?.handleLifecycleState(state);
    _backgroundGameRetentionCoordinator?.handleLifecycleState(state);
  }

  void _scheduleWindowMetricsRecovery() {
    _windowMetricsRecoveryScheduler.schedule(() {
      if (!mounted) return;
      final tracker = _windowMetricsChangeTracker;
      if (tracker?.isImeVisible ?? false) return;
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (tracker?.isImeVisible ?? false) return;
        tracker?.markCurrentGeometryStable();
        widget.browserController.fitGameScreen().catchError((Object _) {});
      });
    });
  }

  void _onDisplayModeChanged() {
    _applyOrientationPolicy();
    if (mounted) {
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.browserController.fitGameScreen().catchError((Object _) {});
      });
    }
  }

  void _applyOrientationPolicy() {
    applyOrientationPolicy(
      currentWindowSize(),
      widget.displayModeController.displayMode,
    );
  }

  void _selectWorkspace(int index) {
    if (index != 0) {
      widget.toolbarController.collapse();
      if (_gameFullscreen) _setGameFullscreen(false);
    }
    if (_workspaceIndex != index) {
      setState(() => _workspaceIndex = index);
    }
  }

  void _setGameFullscreen(bool fullscreen) {
    if (_gameFullscreen == fullscreen) return;
    setState(() => _gameFullscreen = fullscreen);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.browserController.fitGameScreen().catchError((Object _) {});
      }
    });
  }

  Future<void> _refreshGameFrameFromHeader() async {
    final settings = widget.gameFrameRefreshShortcutSettings;
    if (settings == null ||
        !await confirmGameFrameRefreshShortcut(
          context: context,
          settings: settings,
        ) ||
        !mounted) {
      return;
    }
    await runGameFrameRefreshShortcut(
      context: context,
      reload: widget.browserController.reloadGameFrame,
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget buildWorkspaceNavigation(int completedCount) => WorkspaceNavigation(
      controller: widget.layoutSettingsController,
      selectedIndex: _workspaceIndex,
      onRight: widget.layoutSettingsController.workspaceMenuOnRight,
      onSelected: _selectWorkspace,
      completedQuestCount: completedCount,
      gameStateController: widget.gameStateController,
    );

    Widget buildHeaderToolbar() => AnimatedBuilder(
      animation: Listenable.merge([
        widget.browserController,
        widget.audioController,
        ?widget.gameRenderingModeController,
        widget.layoutSettingsController,
      ]),
      builder: (context, _) => GameBrowserToolbar(
        compact:
            widget.layoutSettingsController.uiDisplaySize ==
            UiDisplaySize.compact,
        enableBackdropBlur:
            widget.gameRenderingModeController?.mode.enablesToolbarBlur ?? true,
        interactionEnabled:
            !(widget.gameRenderingModeController?.isBusy ?? false),
        mode: widget.browserController.mode,
        loadState: widget.browserController.loadState,
        displayAddress: widget.browserController.displayAddress,
        onBack: () async {
          await widget.browserController.goBack();
        },
        onReload: () async {
          await showGameRefreshDialog(
            context: context,
            onRefreshPage: widget.browserController.reload,
            onReloadGame: widget.browserController.reloadGameFrame,
          );
        },
        onHome: () async {
          await widget.browserController.goHome();
        },
        onEnterDmm: () async {
          await widget.browserController.enterDmmLoginTest();
        },
        isMuted: widget.audioController.isMuted,
        audioEnabled: widget.audioController.canToggle,
        onToggleMuted: () async {
          await widget.audioController.toggleMuted();
        },
        onCollapse: widget.toolbarController.collapse,
        onFitScreen: () {
          widget.browserController.fitGameScreen();
        },
        onEnterFullscreen: () => _setGameFullscreen(true),
        onScreenshot: widget.gameScreenshotController == null
            ? null
            : () async {
                final l10n = AppLocalizations.of(context)!;
                TopNotice.show(context, message: l10n.screenshotSaving);
                await WidgetsBinding.instance.endOfFrame;
                if (!context.mounted) return;
                final result = await widget.gameScreenshotController!.capture();
                if (!context.mounted) return;
                final message = result.path != null
                    ? l10n.screenshotSaved(result.path!)
                    : result.errorMessage == null
                    ? l10n.screenshotFailed
                    : '${l10n.screenshotFailed}\n${result.errorMessage}';
                final isSuccess = result.path != null;
                final tone = isSuccess
                    ? TopNoticeTone.success
                    : TopNoticeTone.error;
                TopNotice.show(context, message: message, tone: tone);
              },
        uiLocked: widget.layoutSettingsController.uiLocked,
        onToggleUiLock: () {
          final next = !widget.layoutSettingsController.uiLocked;
          unawaited(widget.layoutSettingsController.setUiLocked(next));
          if (context.mounted) {
            final l10n = AppLocalizations.of(context)!;
            TopNotice.show(
              context,
              message: next ? l10n.uiLockedToast : l10n.uiUnlockedToast,
            );
          }
        },
        persistent: false,
      ),
    );

    final screenDisplayMode = widget.displayModeController.displayMode;
    final windowSize = MediaQuery.sizeOf(context);
    final menuHorizontal =
        widget.layoutSettingsController.workspaceMenuHorizontal;
    final menuTop =
        widget.layoutSettingsController.workspaceMenuPosition == 'top';
    final logbookMenuExtent = workspaceNavigationExtent(
      widget.layoutSettingsController.uiDisplaySize,
    );
    final logbookOccupiedInsets = menuHorizontal
        ? EdgeInsets.only(bottom: menuTop ? 0 : logbookMenuExtent)
        : widget.layoutSettingsController.workspaceMenuOnRight
        ? EdgeInsets.only(right: logbookMenuExtent)
        : EdgeInsets.only(left: logbookMenuExtent);
    final hdPortrait =
        widget.layoutSettingsController.hdSettings.enabled &&
        (screenDisplayMode == DisplayMode.portrait ||
            (screenDisplayMode != DisplayMode.landscape &&
                windowSize.height >= windowSize.width));
    final hdWindow =
        screenDisplayMode != DisplayMode.portrait &&
        usesHdLandscape(
          windowSize,
          enabled: widget.layoutSettingsController.hdSettings.enabled,
        );
    final panelAlignedNavigation =
        _workspaceIndex == 0 &&
        (menuTop ||
            (!menuHorizontal &&
                !hdWindow &&
                usesVerticalWorkspace(windowSize, screenDisplayMode)));

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: PopScope(
        canPop: !_gameFullscreen,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && _gameFullscreen) _setGameFullscreen(false);
        },
        child: SafeArea(
          left: false,
          right: false,
          top: false,
          bottom: false,
          child: GameFullscreenControls(
            active: _gameFullscreen,
            useNativeOverlay: Platform.isAndroid,
            onExit: () => _setGameFullscreen(false),
            onUnavailable: () {
              _setGameFullscreen(false);
              TopNotice.show(
                context,
                message: AppLocalizations.of(
                  context,
                )!.gameFullscreenUnavailable,
              );
            },
            child: QuestCompletionDrawerHost(
              controller: widget.headerNoticeController,
              child: QuestCompletionFeedback(
                controller: widget.gameStateController,
                layoutSettingsController: widget.layoutSettingsController,
                builder: (context, completedCount) => Column(
                  children: [
                    Offstage(
                      offstage: _gameFullscreen,
                      child: AnimatedBuilder(
                        animation: Listenable.merge([
                          widget.toolbarController,
                          widget.layoutSettingsController,
                        ]),
                        builder: (context, _) {
                          final uiSize =
                              widget.layoutSettingsController.uiDisplaySize;
                          final isCompact = uiSize == UiDisplaySize.compact;
                          final headerHeight = topHeaderHeight(uiSize);
                          final isGameWorkspace = _workspaceIndex == 0;
                          final isToolbarVisible =
                              isGameWorkspace &&
                              widget.toolbarController.isVisible;
                          return Container(
                            height: headerHeight,
                            padding: EdgeInsets.symmetric(
                              horizontal: isCompact ? 8 : 10,
                            ),
                            decoration: const BoxDecoration(
                              color: Color(0xff122431),
                              border: Border(
                                bottom: BorderSide(color: Color(0xff294052)),
                              ),
                            ),
                            child: TooltipVisibility(
                              visible: false,
                              child: Row(
                                children: [
                                  Material(
                                    color: isToolbarVisible
                                        ? const Color(0xff1a3447)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    child: InkWell(
                                      key: const Key('yahagi-brand-button'),
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: isGameWorkspace
                                          ? widget.toolbarController.toggle
                                          : null,
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: isCompact ? 6 : 8,
                                          vertical: isCompact ? 2 : 6,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Image.asset(
                                              'assets/app_icon.png',
                                              width: isCompact ? 18 : 22,
                                              height: isCompact ? 18 : 22,
                                              fit: BoxFit.contain,
                                            ),
                                            SizedBox(width: isCompact ? 6 : 8),
                                            Text(
                                              'ヤハギ',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: isCompact ? 13 : null,
                                              ),
                                            ),
                                            if (hdWindow || hdPortrait) ...[
                                              const SizedBox(width: 5),
                                              Text(
                                                'HD',
                                                key: const Key(
                                                  'yahagi-hd-label',
                                                ),
                                                style: TextStyle(
                                                  color: const Color(
                                                    0xffffd54f,
                                                  ),
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: isCompact
                                                      ? 12
                                                      : null,
                                                ),
                                              ),
                                            ],
                                            if (isGameWorkspace) ...[
                                              const SizedBox(width: 4),
                                              Icon(
                                                isToolbarVisible
                                                    ? Icons.chevron_left
                                                    : Icons.chevron_right,
                                                size: isCompact ? 14 : 16,
                                                color: isToolbarVisible
                                                    ? const Color(0xffd4a85f)
                                                    : const Color(0xff8197a5),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: isCompact ? 6 : 8),
                                  Expanded(
                                    child: QuestCompletionHeaderSlot(
                                      toolbarVisible: isToolbarVisible,
                                      child: Stack(
                                        alignment: Alignment.centerLeft,
                                        children: [
                                          AnimatedOpacity(
                                            duration: const Duration(
                                              milliseconds: 200,
                                            ),
                                            opacity: isToolbarVisible
                                                ? 0.0
                                                : 1.0,
                                            child: IgnorePointer(
                                              ignoring: isToolbarVisible,
                                              child: AnimatedBuilder(
                                                animation: Listenable.merge(<
                                                  Listenable
                                                >[
                                                  widget.gameStateController,
                                                  if (widget.senkaController !=
                                                      null)
                                                    widget.senkaController!,
                                                ]),
                                                builder: (context, _) => WorkspaceContextHeader(
                                                  workspaceIndex:
                                                      _workspaceIndex,
                                                  state: widget
                                                      .gameStateController
                                                      .state,
                                                  senkaState: widget
                                                      .senkaController
                                                      ?.state,
                                                  onSenkaTap:
                                                      widget.senkaController ==
                                                          null
                                                      ? null
                                                      : () =>
                                                            _selectWorkspace(9),
                                                  onFrameRefreshTap:
                                                      widget.gameFrameRefreshShortcutSettings ==
                                                          null
                                                      ? null
                                                      : _refreshGameFrameFromHeader,
                                                  anchorageRepairStartedAt: widget
                                                      .gameStateController
                                                      .anchorageRepairStartedAt,
                                                  onAnchorageTimerTap: () {
                                                    final startedAt = widget
                                                        .gameStateController
                                                        .anchorageRepairStartedAt;
                                                    final now = DateTime.now()
                                                        .toUtc();
                                                    final elapsed =
                                                        startedAt == null ||
                                                            now.isBefore(
                                                              startedAt,
                                                            )
                                                        ? Duration.zero
                                                        : now.difference(
                                                            startedAt,
                                                          );
                                                    final fleetId =
                                                        preferredAnchorageRepairFleetId(
                                                          state: widget
                                                              .gameStateController
                                                              .state,
                                                          elapsed: elapsed,
                                                        );
                                                    setState(() {
                                                      _repairCenterMode =
                                                          RepairCenterMode
                                                              .anchorage;
                                                      _repairCenterInitialFleetId =
                                                          fleetId;
                                                    });
                                                    _selectWorkspace(3);
                                                  },
                                                  nosakiSparkleStartedAt: widget
                                                      .gameStateController
                                                      .nosakiSparkleStartedAt,
                                                  onNosakiTimerTap: () {
                                                    final startedAt = widget
                                                        .gameStateController
                                                        .nosakiSparkleStartedAt;
                                                    final now = DateTime.now()
                                                        .toUtc();
                                                    final elapsed =
                                                        startedAt == null ||
                                                            now.isBefore(
                                                              startedAt,
                                                            )
                                                        ? Duration.zero
                                                        : now.difference(
                                                            startedAt,
                                                          );
                                                    final fleetId =
                                                        NosakiSparkleCalculator.preferredNosakiSparkleFleetId(
                                                          state: widget
                                                              .gameStateController
                                                              .state,
                                                          elapsed: elapsed,
                                                        );
                                                    setState(() {
                                                      _repairCenterMode =
                                                          RepairCenterMode
                                                              .nosaki;
                                                      _repairCenterInitialFleetId =
                                                          fleetId;
                                                    });
                                                    _selectWorkspace(3);
                                                  },
                                                  layoutSettingsController: widget
                                                      .layoutSettingsController,
                                                  selectedFleetId:
                                                      _fleetCenterInitialFleetId ??
                                                      1,
                                                  onFleetSelected: (fleetId) {
                                                    setState(() {
                                                      _fleetCenterInitialFleetId =
                                                          fleetId;
                                                    });
                                                  },
                                                  inventoryShowShips:
                                                      _inventoryShowShips,
                                                  inventoryShowOwned:
                                                      _inventoryShowOwned,
                                                  onInventoryOwnershipChanged:
                                                      (value) {
                                                        setState(
                                                          () =>
                                                              _inventoryShowOwned =
                                                                  value,
                                                        );
                                                      },
                                                  onInventorySectionChanged:
                                                      (value) {
                                                        setState(
                                                          () =>
                                                              _inventoryShowShips =
                                                                  value,
                                                        );
                                                      },
                                                  logbookTabIndex:
                                                      _logbookTabIndex,
                                                  onLogbookTabChanged: (value) {
                                                    setState(
                                                      () => _logbookTabIndex =
                                                          value,
                                                    );
                                                  },
                                                  settingsTabIndex:
                                                      _settingsTabIndex,
                                                  onSettingsTabChanged: (value) {
                                                    setState(
                                                      () => _settingsTabIndex =
                                                          value,
                                                    );
                                                  },
                                                  repairMode: _repairCenterMode,
                                                  onRepairModeChanged: (mode) {
                                                    setState(
                                                      () => _repairCenterMode =
                                                          mode,
                                                    );
                                                  },
                                                  questMode: _questCenterMode,
                                                  questFilters: _questFilters,
                                                  questTranslationEnabled:
                                                      _questTranslationEnabled,
                                                  onQuestTranslationChanged:
                                                      (enabled) {
                                                        setState(
                                                          () =>
                                                              _questTranslationEnabled =
                                                                  enabled,
                                                        );
                                                      },
                                                  onQuestModeChanged: (mode) {
                                                    setState(
                                                      () => _questCenterMode =
                                                          mode,
                                                    );
                                                  },
                                                  expeditionMode:
                                                      _expeditionCenterMode,
                                                  onExpeditionModeChanged: (mode) {
                                                    setState(
                                                      () =>
                                                          _expeditionCenterMode =
                                                              mode,
                                                    );
                                                  },
                                                  constructionMode:
                                                      _constructionCenterMode,
                                                  onConstructionModeChanged: (mode) {
                                                    setState(() {
                                                      _constructionCenterMode =
                                                          mode;
                                                      if (mode ==
                                                          ConstructionCenterMode
                                                              .development) {
                                                        _developmentWorkbenchMode =
                                                            DevelopmentWorkbenchMode
                                                                .calculator;
                                                      }
                                                    });
                                                  },
                                                  developmentMode:
                                                      _developmentWorkbenchMode,
                                                  onDevelopmentModeChanged: (mode) {
                                                    setState(
                                                      () =>
                                                          _developmentWorkbenchMode =
                                                              mode,
                                                    );
                                                  },
                                                  senkaMode: _senkaCenterMode,
                                                  toolboxMode: _toolboxMode,
                                                  onToolboxModeChanged: (mode) {
                                                    setState(
                                                      () => _toolboxMode = mode,
                                                    );
                                                  },
                                                  onSenkaModeChanged: (mode) {
                                                    setState(
                                                      () => _senkaCenterMode =
                                                          mode,
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                          ),
                                          IgnorePointer(
                                            ignoring: !isToolbarVisible,
                                            child: AnimatedSwitcher(
                                              duration: const Duration(
                                                milliseconds: 240,
                                              ),
                                              reverseDuration: const Duration(
                                                milliseconds: 200,
                                              ),
                                              transitionBuilder:
                                                  (child, animation) {
                                                    final slide =
                                                        Tween<Offset>(
                                                          begin: const Offset(
                                                            -0.2,
                                                            0,
                                                          ),
                                                          end: Offset.zero,
                                                        ).animate(
                                                          CurvedAnimation(
                                                            parent: animation,
                                                            curve: Curves
                                                                .easeOutCubic,
                                                          ),
                                                        );
                                                    return FadeTransition(
                                                      opacity: animation,
                                                      child: SlideTransition(
                                                        position: slide,
                                                        child: child,
                                                      ),
                                                    );
                                                  },
                                              child: isToolbarVisible
                                                  ? KeyedSubtree(
                                                      key: const Key(
                                                        'game-toolbar-visible',
                                                      ),
                                                      child:
                                                          buildHeaderToolbar(),
                                                    )
                                                  : const SizedBox.shrink(
                                                      key: Key(
                                                        'game-toolbar-hidden',
                                                      ),
                                                    ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Expanded(
                      child: Flex(
                        direction: menuHorizontal
                            ? Axis.vertical
                            : Axis.horizontal,
                        verticalDirection: menuHorizontal && !menuTop
                            ? VerticalDirection.up
                            : VerticalDirection.down,
                        textDirection: workspaceNavigationTextDirection(
                          menuOnRight: widget
                              .layoutSettingsController
                              .workspaceMenuOnRight,
                        ),
                        children: [
                          if (!panelAlignedNavigation)
                            Offstage(
                              key: const Key('workspace-navigation-sidebar'),
                              offstage: _gameFullscreen,
                              child: buildWorkspaceNavigation(completedCount),
                            ),
                          Expanded(
                            key: const Key('workspace-content-expanded'),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                GameWorkspaceActive(
                                  active: _workspaceIndex == 0,
                                  child: TickerMode(
                                    enabled: _workspaceIndex == 0,
                                    child: Offstage(
                                      offstage: _workspaceIndex != 0,
                                      child: LayoutBuilder(
                                        key: const Key('game-workspace'),
                                        builder: (context, actualConstraints) {
                                          if (!_gameFullscreen) {
                                            _normalWorkspaceSize =
                                                actualConstraints.biggest;
                                          }
                                          final constraints =
                                              BoxConstraints.tight(
                                                _normalWorkspaceSize ??
                                                    actualConstraints.biggest,
                                              );
                                          final gameAreaRatio =
                                              widget
                                                  .layoutSettingsController
                                                  .autoZoom
                                              ? 0.67
                                              : widget
                                                    .layoutSettingsController
                                                    .gameAreaRatio
                                                    .clamp(0.5, 0.75);
                                          final hdGeometry = hdWindow
                                              ? HdWorkspaceGeometry.forSize(
                                                  constraints.biggest,
                                                  gameAreaRatio: gameAreaRatio,
                                                )
                                              : null;
                                          final isLandscape =
                                              hdGeometry != null ||
                                              !usesVerticalWorkspace(
                                                Size(
                                                  constraints.maxWidth,
                                                  constraints.maxHeight,
                                                ),
                                                screenDisplayMode,
                                              );
                                          final gameFlex =
                                              (gameAreaRatio * 1000).round();
                                          final portraitGamePanelExtra =
                                              portraitGamePanelExtraExtent(
                                                displayMode: widget
                                                    .toolbarDisplayController
                                                    ?.mode,
                                                renderingMode: widget
                                                    .gameRenderingModeController
                                                    ?.mode,
                                              );
                                          final gameSurfaceWrapper =
                                              GameSurfaceViewport(
                                                aspectRatio: 1200 / 720,
                                                fullscreen: _gameFullscreen,
                                                isLandscape: isLandscape,
                                                displayMode: screenDisplayMode,
                                                fitWithinBounds:
                                                    menuHorizontal &&
                                                    !_gameFullscreen,
                                                child: GameSurfaceBoundary(
                                                  child: widget.gameSurface,
                                                ),
                                              );
                                          final gameWidget = GameBrowserOverlay(
                                            controller:
                                                widget.toolbarController,
                                            gameSurface: gameSurfaceWrapper,
                                          );

                                          Widget buildInfo({
                                            String? module,
                                          }) => _InformationPanel(
                                            hdEditing: _hdEditing,
                                            onHdEditingChanged: (editing) =>
                                                setState(
                                                  () => _hdEditing =
                                                      editing &&
                                                      !widget
                                                          .layoutSettingsController
                                                          .uiLocked,
                                                ),
                                            hd:
                                                hdGeometry != null ||
                                                hdPortrait,
                                            hdPortrait: hdPortrait,
                                            singleModule: module,
                                            excludedModules:
                                                hdGeometry != null &&
                                                    module == null
                                                ? widget
                                                      .layoutSettingsController
                                                      .hdSettings
                                                      .activeModules
                                                      .toSet()
                                                : const {},
                                            layoutSettingsController:
                                                widget.layoutSettingsController,
                                            safetySettingsController:
                                                widget.safetySettingsController,
                                            controller: widget.controller,
                                            browserController:
                                                widget.browserController,
                                            captureModeController:
                                                widget.captureModeController,
                                            gameCaptureController:
                                                widget.gameCaptureController,
                                            gameStateController:
                                                widget.gameStateController,
                                            moraleRecoveryTimerController: widget
                                                .moraleRecoveryTimerController,
                                            battleController:
                                                widget.battleController,
                                            battlePredictionSettingsController:
                                                widget
                                                    .battlePredictionSettingsController,
                                            onOpenFleet: (fleetId) {
                                              setState(() {
                                                _fleetCenterInitialFleetId =
                                                    fleetId;
                                              });
                                              _selectWorkspace(1);
                                            },
                                            onOpenRepair: (destination) {
                                              setState(() {
                                                _repairCenterMode =
                                                    destination.mode;
                                                _repairCenterInitialFleetId =
                                                    destination.fleetId;
                                              });
                                              _selectWorkspace(3);
                                            },
                                            onOpenConstruction: () =>
                                                _selectWorkspace(4),
                                            onOpenExpedition: () =>
                                                _selectWorkspace(2),
                                            onOpenQuest: (questId) {
                                              setState(() {
                                                _questCenterInitialQuestId =
                                                    questId;
                                              });
                                              _selectWorkspace(5);
                                            },
                                            onOpenExpeditionCheck: (fleetId) {
                                              setState(() {
                                                _expeditionCheckFleetId =
                                                    fleetId;
                                                _expeditionCenterMode =
                                                    ExpeditionSummaryMode.check;
                                              });
                                              _selectWorkspace(2);
                                            },
                                          );

                                          final infoWidget = buildInfo();
                                          const dividerExtent = 1.0;
                                          final availableWidth =
                                              constraints.maxWidth -
                                              dividerExtent;
                                          final gamePanelExtent =
                                              hdGeometry?.gameWidth ??
                                              (isLandscape
                                                  ? availableWidth *
                                                        gameFlex /
                                                        1000
                                                  : (constraints.maxWidth *
                                                                720 /
                                                                1200 +
                                                            portraitGamePanelExtra)
                                                        .clamp(
                                                          0.0,
                                                          constraints
                                                                  .maxHeight -
                                                              dividerExtent,
                                                        )
                                                        .toDouble());

                                          final infoOnLeft =
                                              isLandscape &&
                                              widget
                                                  .layoutSettingsController
                                                  .informationPanelOnLeft;
                                          final infoPanelExtent =
                                              availableWidth - gamePanelExtent;
                                          final menuNavigationExtent =
                                              workspaceNavigationExtent(
                                                widget
                                                    .layoutSettingsController
                                                    .uiDisplaySize,
                                              );

                                          final topMenuExtent = menuTop
                                              ? menuNavigationExtent
                                              : 0.0;
                                          final topMenuY =
                                              hdGeometry?.gameHeight ??
                                              (isLandscape
                                                  ? constraints.maxHeight -
                                                        topMenuExtent
                                                  : gamePanelExtent +
                                                        dividerExtent);
                                          return Stack(
                                            children: [
                                              Positioned(
                                                left:
                                                    !_gameFullscreen &&
                                                        infoOnLeft
                                                    ? infoPanelExtent +
                                                          dividerExtent
                                                    : 0,
                                                top: 0,
                                                width: _gameFullscreen
                                                    ? actualConstraints.maxWidth
                                                    : (isLandscape
                                                          ? gamePanelExtent
                                                          : constraints
                                                                .maxWidth),
                                                height: _gameFullscreen
                                                    ? actualConstraints
                                                          .maxHeight
                                                    : (isLandscape
                                                          ? (hdGeometry
                                                                    ?.gameHeight ??
                                                                constraints
                                                                        .maxHeight -
                                                                    topMenuExtent)
                                                          : gamePanelExtent),
                                                child: DecoratedBox(
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xff0a1823,
                                                    ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black38,
                                                        offset: isLandscape
                                                            ? Offset(
                                                                infoOnLeft
                                                                    ? -2
                                                                    : 2,
                                                                0,
                                                              )
                                                            : const Offset(
                                                                0,
                                                                2,
                                                              ),
                                                        blurRadius: 4,
                                                      ),
                                                    ],
                                                  ),
                                                  child: gameWidget,
                                                ),
                                              ),
                                              Positioned(
                                                left: isLandscape
                                                    ? (infoOnLeft
                                                          ? infoPanelExtent
                                                          : gamePanelExtent)
                                                    : 0,
                                                top: isLandscape
                                                    ? 0
                                                    : gamePanelExtent,
                                                width: isLandscape
                                                    ? dividerExtent
                                                    : constraints.maxWidth,
                                                height: isLandscape
                                                    ? constraints.maxHeight
                                                    : dividerExtent,
                                                child: Offstage(
                                                  offstage: _gameFullscreen,
                                                  child: isLandscape
                                                      ? const VerticalDivider(
                                                          width: dividerExtent,
                                                          thickness:
                                                              dividerExtent,
                                                          color: Color(
                                                            0xff294052,
                                                          ),
                                                        )
                                                      : const Divider(
                                                          height: dividerExtent,
                                                          thickness:
                                                              dividerExtent,
                                                          color: Color(
                                                            0xff294052,
                                                          ),
                                                        ),
                                                ),
                                              ),
                                              Positioned(
                                                left: isLandscape
                                                    ? (infoOnLeft
                                                          ? 0
                                                          : gamePanelExtent +
                                                                dividerExtent)
                                                    : (panelAlignedNavigation &&
                                                              !menuHorizontal &&
                                                              !widget
                                                                  .layoutSettingsController
                                                                  .workspaceMenuOnRight
                                                          ? menuNavigationExtent
                                                          : 0),
                                                top: isLandscape
                                                    ? 0
                                                    : gamePanelExtent +
                                                          dividerExtent +
                                                          topMenuExtent,
                                                width: math.max(
                                                  0.0,
                                                  isLandscape
                                                      ? infoPanelExtent
                                                      : constraints.maxWidth -
                                                            (panelAlignedNavigation &&
                                                                    !menuHorizontal
                                                                ? menuNavigationExtent
                                                                : 0),
                                                ),
                                                height: math.max(
                                                  0.0,
                                                  isLandscape
                                                      ? constraints.maxHeight
                                                      : constraints.maxHeight -
                                                            gamePanelExtent -
                                                            dividerExtent -
                                                            topMenuExtent,
                                                ),
                                                child: Offstage(
                                                  offstage: _gameFullscreen,
                                                  child: Padding(
                                                    key: const Key(
                                                      'workspace-information-panel',
                                                    ),
                                                    padding: isLandscape
                                                        ? (infoOnLeft
                                                              ? const EdgeInsets.only(
                                                                  right: 2,
                                                                )
                                                              : const EdgeInsets.only(
                                                                  left: 2,
                                                                ))
                                                        : const EdgeInsets.only(
                                                            top: 4,
                                                          ),
                                                    child: infoWidget,
                                                  ),
                                                ),
                                              ),
                                              if (hdGeometry != null)
                                                Positioned(
                                                  key: const Key(
                                                    'hd-bottom-region',
                                                  ),
                                                  left: infoOnLeft
                                                      ? infoPanelExtent +
                                                            dividerExtent
                                                      : 0,
                                                  top:
                                                      hdGeometry.gameHeight +
                                                      topMenuExtent,
                                                  width: hdGeometry.gameWidth,
                                                  height: math.max(
                                                    0.0,
                                                    hdGeometry.bottomHeight -
                                                        topMenuExtent,
                                                  ),
                                                  child: Offstage(
                                                    offstage: _gameFullscreen,
                                                    child: HdBottomStrip(
                                                      editing: _hdEditing,
                                                      onStartEditing:
                                                          widget
                                                              .layoutSettingsController
                                                              .uiLocked
                                                          ? null
                                                          : () => setState(
                                                              () => _hdEditing =
                                                                  true,
                                                            ),
                                                      controller: widget
                                                          .layoutSettingsController,
                                                      moduleBuilder: (module) =>
                                                          buildInfo(
                                                            module: module,
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                              if (panelAlignedNavigation &&
                                                  !_gameFullscreen)
                                                Positioned(
                                                  left: menuHorizontal
                                                      ? (isLandscape &&
                                                                infoOnLeft
                                                            ? infoPanelExtent +
                                                                  dividerExtent
                                                            : 0)
                                                      : (widget
                                                                .layoutSettingsController
                                                                .workspaceMenuOnRight
                                                            ? constraints
                                                                      .maxWidth -
                                                                  menuNavigationExtent
                                                            : 0),
                                                  top: menuHorizontal
                                                      ? topMenuY
                                                      : gamePanelExtent +
                                                            dividerExtent,
                                                  width: menuHorizontal
                                                      ? (isLandscape
                                                            ? gamePanelExtent
                                                            : constraints
                                                                  .maxWidth)
                                                      : menuNavigationExtent,
                                                  height: menuHorizontal
                                                      ? menuNavigationExtent
                                                      : math.max(
                                                          0.0,
                                                          constraints
                                                                  .maxHeight -
                                                              gamePanelExtent -
                                                              dividerExtent,
                                                        ),
                                                  child:
                                                      buildWorkspaceNavigation(
                                                        completedCount,
                                                      ),
                                                ),
                                            ],
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                                if (_workspaceIndex == 1)
                                  FleetInformationCenter(
                                    controller: widget.gameStateController,
                                    moraleRecoveryTimerController:
                                        widget.moraleRecoveryTimerController,
                                    moraleMetricMode: widget
                                        .layoutSettingsController
                                        .fleetMoraleMetricMode,
                                    onToggleMoraleMetricMode: widget
                                        .layoutSettingsController
                                        .toggleFleetMoraleMetricMode,
                                    damagePulseMode: widget
                                        .safetySettingsController
                                        .battleStatusEffects
                                        .pulseFilterFor(
                                          BattleEffectSurface.fleet,
                                        ),
                                    moraleSparkleEnabled: widget
                                        .safetySettingsController
                                        .battleStatusEffects
                                        .sparkleEnabledFor(
                                          BattleEffectSurface.fleet,
                                        ),
                                    page: FleetInformationPage.fleet,
                                    initialFleetId: _fleetCenterInitialFleetId,
                                    showContextHeader: false,
                                  ),
                                if (_workspaceIndex == 2)
                                  FleetInformationCenter(
                                    controller: widget.gameStateController,
                                    page: FleetInformationPage.expedition,
                                    initialFleetId: _expeditionCheckFleetId,
                                    showContextHeader: false,
                                    expeditionMode: _expeditionCenterMode,
                                    onExpeditionModeChanged: (mode) {
                                      setState(
                                        () => _expeditionCenterMode = mode,
                                      );
                                    },
                                  ),
                                if (_workspaceIndex == 3)
                                  FleetInformationCenter(
                                    controller: widget.gameStateController,
                                    page: FleetInformationPage.repair,
                                    initialFleetId: _repairCenterInitialFleetId,
                                    onFleetSelected: (fleetId) {
                                      setState(() {
                                        _repairCenterInitialFleetId = fleetId;
                                      });
                                    },
                                    showContextHeader: false,
                                    repairMode: _repairCenterMode,
                                    onRepairModeChanged: (mode) {
                                      setState(() => _repairCenterMode = mode);
                                    },
                                    showRepairModeTabs: false,
                                  ),
                                if (_workspaceIndex == 4)
                                  FleetInformationCenter(
                                    controller: widget.gameStateController,
                                    page: FleetInformationPage.construction,
                                    showContextHeader: false,
                                    constructionMode: _constructionCenterMode,
                                    developmentRepository:
                                        _developmentRepository,
                                    developmentMode: _developmentWorkbenchMode,
                                    onDevelopmentModeChanged: (mode) {
                                      setState(
                                        () => _developmentWorkbenchMode = mode,
                                      );
                                    },
                                    improvementController:
                                        widget.improvementPlannerController,
                                  ),
                                if (_workspaceIndex == 5)
                                  QuestCenterPage(
                                    controller: widget.gameStateController,
                                    catalogController:
                                        widget.questCatalogController,
                                    initialQuestId: _questCenterInitialQuestId,
                                    showTitle: false,
                                    mode: _questCenterMode,
                                    filterController: _questFilters,
                                    translationEnabled:
                                        _questTranslationEnabled,
                                    onTranslationChanged: (enabled) {
                                      setState(
                                        () =>
                                            _questTranslationEnabled = enabled,
                                      );
                                    },
                                    onModeChanged: (mode) {
                                      setState(() => _questCenterMode = mode);
                                    },
                                  ),
                                if (_workspaceIndex == 6)
                                  LogbookPage(
                                    battleController: widget.battleController,
                                    occupiedInsets: logbookOccupiedInsets,
                                    selectedTabIndex: _logbookTabIndex,
                                    onTabChanged: (value) {
                                      setState(() => _logbookTabIndex = value);
                                    },
                                  ),
                                if (_workspaceIndex == 7)
                                  OwnedInventoryPage(
                                    controller: widget.gameStateController,
                                    reminderController:
                                        widget.newShipReminderController,
                                    showOwned: _inventoryShowOwned,
                                    onOwnershipChanged: (value) {
                                      setState(
                                        () => _inventoryShowOwned = value,
                                      );
                                    },
                                    showShips: _inventoryShowShips,
                                    onSectionChanged: (value) {
                                      setState(
                                        () => _inventoryShowShips = value,
                                      );
                                    },
                                    showSectionControl: false,
                                  ),
                                if (_workspaceIndex == 8)
                                  SettingsPage(
                                    layoutSettingsController:
                                        widget.layoutSettingsController,
                                    networkSettingsController:
                                        widget.networkSettingsController,
                                    gadgetBypassController:
                                        widget.gadgetBypassController,
                                    audioController: widget.audioController,
                                    captureModeController:
                                        widget.captureModeController,
                                    browserController: widget.browserController,
                                    gameCaptureController:
                                        widget.gameCaptureController,
                                    kcwikiReportController:
                                        widget.kcwikiReportController,
                                    prototypeStatusController:
                                        widget.controller,
                                    gameStateController:
                                        widget.gameStateController,
                                    senkaController: widget.senkaController,
                                    gameResourceCacheController:
                                        widget.gameResourceCacheController,
                                    safetySettingsController:
                                        widget.safetySettingsController,
                                    notificationSettingsController:
                                        widget.notificationSettingsController,
                                    battlePredictionSettingsController: widget
                                        .battlePredictionSettingsController,
                                    gameFrameRateSettingsController:
                                        widget.gameFrameRateSettingsController,
                                    gameRenderingModeController:
                                        widget.gameRenderingModeController,
                                    gameConnectorController:
                                        widget.gameConnectorController,
                                    backgroundGameRetentionController: widget
                                        .backgroundGameRetentionController,
                                    isBattleActive:
                                        widget.battleController.session !=
                                            null &&
                                        !widget
                                            .battleController
                                            .session!
                                            .completed,
                                    displayModeController:
                                        widget.displayModeController,
                                    currentVersion: widget.currentVersion,
                                    releaseChecker: widget.releaseChecker,
                                    screenAwakeController:
                                        widget.screenAwakeController,
                                    gameMouseWheelSettingsController:
                                        widget.gameMouseWheelSettingsController,
                                    gameFrameRefreshShortcutSettings:
                                        widget.gameFrameRefreshShortcutSettings,
                                    toolbarDisplayController:
                                        widget.toolbarDisplayController,
                                    fcdMapController: widget.fcdMapController,
                                    questCatalogController:
                                        widget.questCatalogController,
                                    sortieMapCatalogController:
                                        widget.sortieMapCatalogController,
                                    enemyCatalogController:
                                        widget.enemyCatalogController,
                                    improvementPlannerController:
                                        widget.improvementPlannerController,
                                    showTitle: false,
                                    showDeveloperDiagnostics:
                                        widget.showDeveloperDiagnostics,
                                    diagnosticController:
                                        widget.diagnosticController,
                                    telemetryController:
                                        widget.telemetryController,
                                    selectedIndex: _settingsTabIndex,
                                  ),
                                if (_workspaceIndex == 9 &&
                                    widget.senkaController != null)
                                  SenkaPage(
                                    controller: widget.senkaController!,
                                    mode: _senkaCenterMode,
                                    onOpenSortieLog: () {
                                      setState(() => _logbookTabIndex = 0);
                                      _selectWorkspace(6);
                                    },
                                  ),
                                if (_workspaceIndex == 10)
                                  AnimatedBuilder(
                                    animation: widget.gameStateController,
                                    builder: (context, _) => ToolboxPage(
                                      state: widget.gameStateController.state,
                                      mode: _toolboxMode,
                                      sortieMapCatalogController:
                                          widget.sortieMapCatalogController,
                                      enemyCatalogController:
                                          widget.enemyCatalogController,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class WorkspaceNavigation extends StatelessWidget {
  const WorkspaceNavigation({
    super.key,
    required this.controller,
    required this.selectedIndex,
    required this.onRight,
    required this.onSelected,
    this.completedQuestCount = 0,
    this.gameStateController,
    this.clock,
  });

  final LayoutSettingsController controller;
  final int selectedIndex;
  final bool onRight;
  final ValueChanged<int> onSelected;
  final int completedQuestCount;
  final GameStateController? gameStateController;
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final menuSize = controller.uiDisplaySize;
    final menuExtent = workspaceNavigationExtent(menuSize);
    final isCompact = menuSize == UiDisplaySize.compact;
    final itemExtent = isCompact ? 50.0 : 52.0;
    return SecondTickBuilder(
      now: clock,
      enabled: gameStateController != null,
      builder: (context, now, _) => Container(
        width: controller.workspaceMenuHorizontal ? null : menuExtent,
        height: controller.workspaceMenuHorizontal ? menuExtent : null,
        decoration: BoxDecoration(
          color: const Color(0xff0a1823),
          border: controller.workspaceMenuHorizontal
              ? const Border(
                  top: BorderSide(color: Color(0xff294052)),
                  bottom: BorderSide(color: Color(0xff294052)),
                )
              : workspaceNavigationBorder(menuOnRight: onRight),
        ),
        child: AnimatedBuilder(
          animation: Listenable.merge([controller, ?gameStateController]),
          builder: (context, _) {
            final destinations = _workspaceDestinations(l10n);
            final ordered = controller.workspaceMenuOrder
                .map((id) => destinations[id])
                .whereType<_WorkspaceDestination>()
                .toList(growable: false);
            return LayoutBuilder(
              builder: (context, constraints) {
                final centeredPadding =
                    (constraints.maxWidth - ordered.length * itemExtent) / 2;
                return ReorderableListView.builder(
                  key: const Key('workspace-navigation-list'),
                  scrollDirection: controller.workspaceMenuHorizontal
                      ? Axis.horizontal
                      : Axis.vertical,
                  padding: controller.workspaceMenuHorizontal
                      ? EdgeInsets.symmetric(
                          horizontal: centeredPadding > 10
                              ? centeredPadding
                              : 10,
                        )
                      : EdgeInsets.symmetric(vertical: isCompact ? 10 : 8),
                  buildDefaultDragHandles: false,
                  itemCount: ordered.length,
                  onReorderItem: controller.uiLocked
                      ? (_, __) {}
                      : controller.reorderWorkspaceMenu,
                  itemBuilder: (context, index) {
                    final destination = ordered[index];
                    void handleTap() {
                      onSelected(destination.pageIndex);
                    }

                    return SizedBox(
                      key: ValueKey('workspace-nav-item-${destination.id}'),
                      width: controller.workspaceMenuHorizontal
                          ? itemExtent
                          : null,
                      height: controller.workspaceMenuHorizontal
                          ? null
                          : itemExtent,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: handleTap,
                        child: Center(
                          child: ReorderableDelayedDragStartListener(
                            index: index,
                            enabled: !controller.uiLocked,
                            child: _NavigationButton(
                              key: Key('workspace-nav-${destination.id}'),
                              icon: destination.icon,
                              label: destination.label,
                              horizontal: controller.workspaceMenuHorizontal,
                              menuSize: menuSize,
                              completedCount: switch (destination.id) {
                                'quests' => completedQuestCount,
                                'expedition' =>
                                  gameStateController?.state.fleets
                                          .where(
                                            (fleet) =>
                                                fleet.mission.isActive &&
                                                now.isBefore(
                                                  fleet.mission.completionTime!,
                                                ),
                                          )
                                          .length ??
                                      0,
                                'construction' =>
                                  gameStateController?.state.constructionDocks
                                          .where(
                                            (dock) => dock.isCompletedAt(now),
                                          )
                                          .length ??
                                      0,
                                'repair' =>
                                  gameStateController?.state.repairDocks
                                          .where(
                                            (dock) =>
                                                dock.isRepairing &&
                                                (dock.completionTime == null ||
                                                    now.isBefore(
                                                      dock.completionTime!,
                                                    )),
                                          )
                                          .length ??
                                      0,
                                _ => 0,
                              },
                              countKey: Key(switch (destination.id) {
                                'repair' => 'repair-active-count',
                                'expedition' => 'expedition-active-count',
                                'quests' => 'quest-completion-count',
                                _ => '${destination.id}-completion-count',
                              }),
                              countLabel: destination.id == 'quests'
                                  ? null
                                  : destination.label,
                              selected: selectedIndex == destination.pageIndex,
                              onTap: handleTap,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

final class _WorkspaceDestination {
  const _WorkspaceDestination({
    required this.id,
    required this.pageIndex,
    required this.icon,
    required this.label,
  });

  final String id;
  final int pageIndex;
  final IconData icon;
  final String label;
}

Map<String, _WorkspaceDestination> _workspaceDestinations(
  AppLocalizations l10n,
) => <String, _WorkspaceDestination>{
  'game': _WorkspaceDestination(
    id: 'game',
    pageIndex: 0,
    icon: Icons.videogame_asset_outlined,
    label: l10n.game,
  ),
  'fleet': _WorkspaceDestination(
    id: 'fleet',
    pageIndex: 1,
    icon: Icons.directions_boat_outlined,
    label: l10n.fleet,
  ),
  'expedition': _WorkspaceDestination(
    id: 'expedition',
    pageIndex: 2,
    icon: Icons.explore_outlined,
    label: l10n.expedition,
  ),
  'repair': _WorkspaceDestination(
    id: 'repair',
    pageIndex: 3,
    icon: Icons.build_circle_outlined,
    label: l10n.repair,
  ),
  'construction': _WorkspaceDestination(
    id: 'construction',
    pageIndex: 4,
    icon: Icons.handyman_outlined,
    label: l10n.construction,
  ),
  'quests': _WorkspaceDestination(
    id: 'quests',
    pageIndex: 5,
    icon: Icons.assignment_outlined,
    label: l10n.quests,
  ),
  'senka': _WorkspaceDestination(
    id: 'senka',
    pageIndex: 9,
    icon: Icons.emoji_events_outlined,
    label: l10n.senka,
  ),
  'battle-records': _WorkspaceDestination(
    id: 'battle-records',
    pageIndex: 6,
    icon: Icons.menu_book_outlined,
    label: l10n.battleRecords,
  ),
  'owned-inventory': _WorkspaceDestination(
    id: 'owned-inventory',
    pageIndex: 7,
    icon: Icons.inventory_2_outlined,
    label: l10n.ownedInventory,
  ),
  'tools': _WorkspaceDestination(
    id: 'tools',
    pageIndex: 10,
    icon: Icons.widgets_outlined,
    label: l10n.toolbox,
  ),
  'settings': _WorkspaceDestination(
    id: 'settings',
    pageIndex: 8,
    icon: Icons.settings_outlined,
    label: l10n.settings,
  ),
};

class _NavigationButton extends StatelessWidget {
  const _NavigationButton({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.completedCount = 0,
    this.countKey = const Key("quest-completion-count"),
    this.countLabel,
    this.horizontal = true,
    this.menuSize = UiDisplaySize.normal,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int completedCount;
  final Key countKey;
  final String? countLabel;
  final bool horizontal;
  final UiDisplaySize menuSize;

  @override
  Widget build(BuildContext context) {
    final isCompact = menuSize == UiDisplaySize.compact;
    final btnSize = horizontal
        ? (isCompact ? const Size(42, 35) : const Size(44, 40))
        : (isCompact ? const Size(35, 42) : const Size(40, 44));
    final iconSize = isCompact ? 20.0 : 22.0;
    return Semantics(
      label: label,
      child: SizedBox(
        width: btnSize.width,
        height: btnSize.height,
        child: IconButton(
          onPressed: onTap,
          style: IconButton.styleFrom(
            fixedSize: btnSize,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: horizontal
                ? const EdgeInsets.only(top: 7.0)
                : EdgeInsets.zero,
            foregroundColor: selected
                ? const Color(0xffd4a85f)
                : const Color(0xff8197a5),
            backgroundColor: selected
                ? const Color(0xff2b2c22)
                : Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9),
            ),
          ),
          icon: QuestCompletionBadge(
            count: completedCount,
            countKey: countKey,
            semanticLabel: countLabel == null
                ? null
                : "$countLabel: $completedCount",
            child: Icon(icon, size: iconSize),
          ),
        ),
      ),
    );
  }
}

class _InformationPanel extends StatefulWidget {
  const _InformationPanel({
    required this.layoutSettingsController,
    required this.safetySettingsController,
    required this.controller,
    required this.browserController,
    required this.captureModeController,
    required this.gameCaptureController,
    required this.gameStateController,
    required this.moraleRecoveryTimerController,
    required this.battleController,
    required this.battlePredictionSettingsController,
    required this.onOpenFleet,
    required this.onOpenRepair,
    required this.onOpenConstruction,
    required this.onOpenExpedition,
    required this.onOpenQuest,
    required this.onOpenExpeditionCheck,
    this.hd = false,
    this.hdPortrait = false,
    this.hdEditing = false,
    this.onHdEditingChanged,
    this.singleModule,
    this.excludedModules = const {},
  });

  final bool hd;
  final bool hdPortrait;
  final bool hdEditing;
  final ValueChanged<bool>? onHdEditingChanged;
  final String? singleModule;
  final Set<String> excludedModules;
  final LayoutSettingsController layoutSettingsController;
  final SafetySettingsController safetySettingsController;
  final PrototypeStatusController controller;
  final GameBrowserController browserController;
  final CaptureModeController captureModeController;
  final GameCaptureController gameCaptureController;
  final GameStateController gameStateController;
  final MoraleRecoveryTimerController? moraleRecoveryTimerController;
  final BattleController battleController;
  final BattlePredictionSettingsController? battlePredictionSettingsController;
  final ValueChanged<int> onOpenFleet;
  final ValueChanged<RepairDestination> onOpenRepair;
  final VoidCallback onOpenConstruction;
  final VoidCallback onOpenExpedition;
  final ValueChanged<int> onOpenQuest;
  final ValueChanged<int> onOpenExpeditionCheck;

  @override
  State<_InformationPanel> createState() => _InformationPanelState();
}

class _InformationPanelState extends State<_InformationPanel> {
  bool _isEditing = false;
  final Set<String> _hdCollapsed = {};

  @override
  void initState() {
    super.initState();
    widget.layoutSettingsController.addListener(_handleLayoutSettingsChanged);
  }

  @override
  void didUpdateWidget(covariant _InformationPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.layoutSettingsController != widget.layoutSettingsController) {
      oldWidget.layoutSettingsController.removeListener(
        _handleLayoutSettingsChanged,
      );
      widget.layoutSettingsController.addListener(_handleLayoutSettingsChanged);
    }
    if (oldWidget.hd != widget.hd || widget.layoutSettingsController.uiLocked) {
      _isEditing = false;
    }
  }

  @override
  void dispose() {
    widget.layoutSettingsController.removeListener(
      _handleLayoutSettingsChanged,
    );
    super.dispose();
  }

  void _handleLayoutSettingsChanged() {
    if (!mounted) return;
    if (widget.layoutSettingsController.uiLocked && _isEditing) {
      setState(() => _isEditing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: widget.singleModule == null
          ? const Key('information-panel')
          : ValueKey('hd-module-content-${widget.singleModule}'),
      decoration: BoxDecoration(
        color: widget.singleModule == null
            ? const Color(0xff0d1a26)
            : Colors.transparent,
        border: widget.singleModule == null
            ? const Border(left: BorderSide(color: Color(0xff294052)))
            : null,
      ),
      child: AnimatedBuilder(
        animation: Listenable.merge([
          widget.layoutSettingsController,
          widget.safetySettingsController,
          widget.browserController,
          widget.gameCaptureController,
          if (widget.battlePredictionSettingsController != null)
            widget.battlePredictionSettingsController!,
        ]),
        builder: (context, _) {
          final hasError =
              widget.browserController.loadState == GamePageLoadState.failed ||
              widget.gameCaptureController.state == GameCaptureState.error ||
              widget.gameCaptureController.state ==
                  GameCaptureState.unsupported;

          final editing =
              (widget.hd ? widget.hdEditing : _isEditing) &&
              !widget.layoutSettingsController.uiLocked;
          final collapsedIds =
              widget.layoutSettingsController.dashboardCardCollapsed;
          final hiddenIds = widget.hd
              ? widget.layoutSettingsController.hdSettings.hidden
              : widget.layoutSettingsController.dashboardCardHidden.toSet();
          final cardOrder = widget.singleModule != null
              ? [widget.singleModule!]
              : widget.hd
              ? widget.layoutSettingsController.hdSettings.orderedModules
              : widget.layoutSettingsController.dashboardCardOrder;
          final validCards = cardOrder
              .where(
                (id) =>
                    LayoutSettingsStore.defaultDashboardCardOrder.contains(id),
              )
              .toList();
          final visibleOrder = validCards
              .where(
                (id) =>
                    !widget.excludedModules.contains(id) &&
                    (widget.singleModule != null || !hiddenIds.contains(id)),
              )
              .toList();
          Widget buildCard(String id) {
            final isCollapsed = widget.hd
                ? editing || _hdCollapsed.contains(id)
                : editing || collapsedIds.contains(id);
            void toggle() {
              if (widget.hd) {
                setState(() {
                  if (!_hdCollapsed.remove(id)) _hdCollapsed.add(id);
                });
              } else {
                widget.layoutSettingsController.toggleDashboardCardCollapsed(
                  id,
                );
              }
            }

            final fleetTwoColumns =
                widget.hd &&
                (widget.hdPortrait
                        ? widget.layoutSettingsController.hdSettings.portrait
                        : widget.layoutSettingsController.hdSettings.bottom)
                    .any((module) => module.id == 'fleet' && module.span == 2);
            final child = switch (id) {
              'fleet' => FleetSummaryCard(
                showLogo: widget.layoutSettingsController.moduleShowLogo(
                  'fleet',
                ),
                showTitle: widget.layoutSettingsController.moduleShowName(
                  'fleet',
                ),
                twoColumnVisible:
                    widget.layoutSettingsController.hdFleetDisplayFields,
                onOpenDisplaySettings: editing
                    ? () => showFleetDisplaySettings(
                        context,
                        widget.layoutSettingsController,
                        twoColumns: fleetTwoColumns,
                      )
                    : null,
                visible: widget.layoutSettingsController.fleetDisplayFields,
                shipTypeLabelMode:
                    widget.layoutSettingsController.fleetShipTypeLabelMode,
                controller: widget.gameStateController,
                moraleRecoveryTimerController:
                    widget.moraleRecoveryTimerController,
                damagePulseFilter: widget
                    .safetySettingsController
                    .battleStatusEffects
                    .pulseFilterFor(BattleEffectSurface.fleet),
                moraleSparkleEnabled: widget
                    .safetySettingsController
                    .battleStatusEffects
                    .sparkleEnabledFor(BattleEffectSurface.fleet),
                collapsed: isCollapsed,
                onToggleCollapse: editing ? () {} : toggle,
                onOpenFleet: widget.onOpenFleet,
              ),
              'land_base' => LandBaseSummaryCard(
                showLogo: widget.layoutSettingsController.moduleShowLogo(
                  'land_base',
                ),
                showTitle: widget.layoutSettingsController.moduleShowName(
                  'land_base',
                ),
                visible: widget.layoutSettingsController.moduleDisplayFields(
                  'land_base',
                ),
                onOpenDisplaySettings: editing
                    ? () => showModuleDisplaySettings(
                        context,
                        widget.layoutSettingsController,
                        'land_base',
                      )
                    : null,
                controller: widget.gameStateController,
                damagePulseMode: widget
                    .safetySettingsController
                    .battleStatusEffects
                    .pulseFilterFor(BattleEffectSurface.fleet),
                collapsed: isCollapsed,
                onToggleCollapse: editing ? () {} : toggle,
              ),
              'expedition' => ExpeditionSummaryCard(
                showLogo: widget.layoutSettingsController.moduleShowLogo(
                  'expedition',
                ),
                showTitle: widget.layoutSettingsController.moduleShowName(
                  'expedition',
                ),
                visible: widget.layoutSettingsController.moduleDisplayFields(
                  'expedition',
                ),
                onOpenDisplaySettings: editing
                    ? () => showModuleDisplaySettings(
                        context,
                        widget.layoutSettingsController,
                        'expedition',
                      )
                    : null,
                controller: widget.gameStateController,
                collapsed: isCollapsed,
                onToggleCollapse: editing ? () {} : toggle,
                onOpenExpedition: widget.onOpenExpedition,
                onOpenExpeditionCheck: widget.onOpenExpeditionCheck,
              ),

              'repair' => RepairSummaryCard(
                showLogo: widget.layoutSettingsController.moduleShowLogo(
                  'repair',
                ),
                showTitle: widget.layoutSettingsController.moduleShowName(
                  'repair',
                ),
                visible: widget.layoutSettingsController.moduleDisplayFields(
                  'repair',
                ),
                onOpenDisplaySettings: editing
                    ? () => showModuleDisplaySettings(
                        context,
                        widget.layoutSettingsController,
                        'repair',
                      )
                    : null,
                controller: widget.gameStateController,
                collapsed: isCollapsed,
                onToggleCollapse: editing ? () {} : toggle,
                onOpenRepair: widget.onOpenRepair,
              ),
              'construction' => ConstructionSummaryCard(
                showLogo: widget.layoutSettingsController.moduleShowLogo(
                  'construction',
                ),
                showTitle: widget.layoutSettingsController.moduleShowName(
                  'construction',
                ),
                visible: widget.layoutSettingsController.moduleDisplayFields(
                  'construction',
                ),
                onOpenDisplaySettings: editing
                    ? () => showModuleDisplaySettings(
                        context,
                        widget.layoutSettingsController,
                        'construction',
                      )
                    : null,
                controller: widget.gameStateController,
                collapsed: isCollapsed,
                onToggleCollapse: editing ? () {} : toggle,
                onOpenConstruction: widget.onOpenConstruction,
              ),
              'quests' => PinnedQuestsSummary(
                showLogo: widget.layoutSettingsController.moduleShowLogo(
                  'quests',
                ),
                showTitle: widget.layoutSettingsController.moduleShowName(
                  'quests',
                ),
                onOpenDisplaySettings: editing
                    ? () => showModuleDisplaySettings(
                        context,
                        widget.layoutSettingsController,
                        'quests',
                      )
                    : null,
                controller: widget.gameStateController,
                collapsed: isCollapsed,
                onToggleCollapse: editing ? () {} : toggle,
                onOpenQuest: widget.onOpenQuest,
              ),
              'battle' => LiveBattleCard(
                key: const PageStorageKey('dashboard-live-battle'),
                showLogo: widget.layoutSettingsController.moduleShowLogo(
                  'battle',
                ),
                showTitle: widget.layoutSettingsController.moduleShowName(
                  'battle',
                ),
                onOpenDisplaySettings: editing
                    ? () => showModuleDisplaySettings(
                        context,
                        widget.layoutSettingsController,
                        'battle',
                      )
                    : null,
                controller: widget.battleController,
                showEnemyPortraits:
                    widget
                        .battlePredictionSettingsController
                        ?.enemyPortraitsEnabled ??
                    true,
                showLastFormationHint:
                    widget
                        .battlePredictionSettingsController
                        ?.lastFormationHintEnabled ??
                    true,
                damagePulseMode: widget
                    .safetySettingsController
                    .battleStatusEffects
                    .pulseFilterFor(BattleEffectSurface.prediction),
                collapsed: isCollapsed,
                onToggleCollapse: editing ? () {} : toggle,
              ),
              'pre_sortie' => PreSortieCheckSummary(
                key: const PageStorageKey('dashboard-pre-sortie'),
                showLogo: widget.layoutSettingsController.moduleShowLogo(
                  'pre_sortie',
                ),
                showTitle: widget.layoutSettingsController.moduleShowName(
                  'pre_sortie',
                ),
                onOpenDisplaySettings: editing
                    ? () => showModuleDisplaySettings(
                        context,
                        widget.layoutSettingsController,
                        'pre_sortie',
                      )
                    : null,
                controller: widget.gameStateController,
                settingsController: widget.layoutSettingsController,
                collapsed: isCollapsed,
                onToggleCollapse: editing ? () {} : toggle,
                onOpenFleet: widget.onOpenFleet,
              ),
              _ => const SizedBox.shrink(),
            };

            Widget finalChild = Padding(
              padding: widget.singleModule == null && !widget.hdPortrait
                  ? const EdgeInsets.only(bottom: 6)
                  : EdgeInsets.zero,
              child: child,
            );

            return KeyedSubtree(key: ValueKey(id), child: finalChild);
          }

          if (widget.hdPortrait) {
            return HdPortraitGrid(
              controller: widget.layoutSettingsController,
              editing: editing,
              onEditingChanged: (value) =>
                  widget.onHdEditingChanged?.call(value),
              cardBuilder: buildCard,
            );
          }

          if (widget.singleModule == null && editing) {
            final controller = widget.layoutSettingsController;
            final modules = validCards
                .where((id) => !widget.excludedModules.contains(id))
                .toList();
            return DashboardEditor(
              modules: modules,
              hidden: hiddenIds,
              cardBuilder: buildCard,
              onToggle: (id) => widget.hd
                  ? controller.toggleHdModuleHidden(id)
                  : controller.toggleDashboardCardHidden(id),
              onReset: () => widget.hd
                  ? controller.resetHdLayout()
                  : controller.resetDashboardCardOrder(),
              onDone: () => widget.hd
                  ? widget.onHdEditingChanged?.call(false)
                  : setState(() => _isEditing = false),
              onMove: (id, target, after) {
                if (widget.hd) {
                  controller.moveHdModuleToSidebar(
                    id,
                    target: target,
                    after: after,
                  );
                } else {
                  final order = [...validCards]..remove(id);
                  final index = target == null ? -1 : order.indexOf(target);
                  order.insert(
                    index < 0 ? order.length : index + (after ? 1 : 0),
                    id,
                  );
                  controller.setDashboardCardOrder(order);
                }
              },
            );
          }

          if (widget.singleModule != null) {
            return GestureDetector(
              onLongPress: editing
                  ? null
                  : () {
                      if (widget.layoutSettingsController.uiLocked) {
                        final l10n =
                            AppLocalizations.of(context) ??
                            lookupAppLocalizations(const Locale('zh'));
                        TopNotice.show(context, message: l10n.uiLockedToast);
                        return;
                      }
                      widget.onHdEditingChanged?.call(true);
                    },
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  key: ValueKey('hd-scroll-${widget.singleModule}'),
                  primary: false,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: buildCard(widget.singleModule!),
                  ),
                ),
              ),
            );
          }

          return GestureDetector(
            onLongPress: editing
                ? null
                : () {
                    if (widget.layoutSettingsController.uiLocked) {
                      final l10n =
                          AppLocalizations.of(context) ??
                          lookupAppLocalizations(const Locale('zh'));
                      TopNotice.show(context, message: l10n.uiLockedToast);
                      return;
                    }
                    if (widget.hd) {
                      widget.onHdEditingChanged?.call(true);
                    } else {
                      setState(() => _isEditing = true);
                    }
                  },
            child: ListView(
              primary: widget.hd ? false : null,
              key: widget.singleModule == null
                  ? null
                  : ValueKey('hd-scroll-${widget.singleModule}'),
              padding: widget.singleModule != null
                  ? EdgeInsets.zero
                  : widget.hd
                  ? const EdgeInsets.all(8)
                  : const EdgeInsets.fromLTRB(8, 8, 8, 0),
              children: [
                for (final id in visibleOrder) buildCard(id),
                if (hasError && widget.singleModule == null)
                  Padding(
                    key: const ValueKey('error_card'),
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _InfoCard(
                      title: AppLocalizations.of(context)!.gameStatusError,
                      subtitle: runtimeMessageText(
                        context,
                        widget.gameCaptureController.errorMessage ??
                            widget.browserController.errorMessage ??
                            AppLocalizations.of(context)!.gameStatusErrorDesc,
                      ),
                      warning: true,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.subtitle,
    this.warning = false,
  });

  final String title;
  final String subtitle;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: warning ? const Color(0xff3a292b) : const Color(0xff142735),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: warning ? const Color(0xff75484a) : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xff8197a5), height: 1.35),
          ),
        ],
      ),
    );
  }
}
