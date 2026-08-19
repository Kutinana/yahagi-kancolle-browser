import 'package:flutter/material.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import '../battle/fcd_map_controller.dart';
import '../browser/game_browser_controller.dart';
import '../browser/game_resource_cache_controller.dart';
import '../capture/capture_mode_controller.dart';
import '../capture/capture_mode_selector.dart';
import '../capture/game_capture_controller.dart';
import '../diagnostics/diagnostic_controller.dart';
import '../game_state/game_state_controller.dart';
import '../improvement/improvement_dataset_update_section.dart';
import '../improvement/improvement_planner_controller.dart';
import '../logbook/logbook_database.dart';
import '../prototype_status_controller.dart';
import '../quest/quest_catalog_controller.dart';
import 'diagnostic_user_section.dart';
import 'diagnostics_section.dart';
import 'fcd_map_update_section.dart';
import 'game_rendering_mode_controller.dart';
import 'game_resource_cache_section.dart';
import 'quest_catalog_update_section.dart';
import 'settings_ui_helpers.dart';

class DataSettingsPage extends StatelessWidget with SettingsUIHelpers {
  const DataSettingsPage({
    super.key,
    required this.captureModeController,
    required this.browserController,
    required this.gameCaptureController,
    required this.prototypeStatusController,
    required this.gameStateController,
    this.gameResourceCacheController,
    this.diagnosticController,
    this.showDeveloperDiagnostics = false,
    this.gameRenderingModeController,
    this.fcdMapController,
    this.questCatalogController,
    this.improvementPlannerController,
  });

  final CaptureModeController captureModeController;
  final GameBrowserController browserController;
  final GameCaptureController gameCaptureController;
  final PrototypeStatusController prototypeStatusController;
  final GameStateController gameStateController;
  final GameResourceCacheController? gameResourceCacheController;
  final DiagnosticController? diagnosticController;
  final bool showDeveloperDiagnostics;
  final GameRenderingModeController? gameRenderingModeController;
  final FcdMapController? fcdMapController;
  final QuestCatalogController? questCatalogController;
  final ImprovementPlannerController? improvementPlannerController;

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    return Container(
      color: const Color(0xff0d1a26),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            buildSectionTitle(l10n.logoutAndClear),
            buildCard(
              child: buildActionTile(
                title: l10n.logoutAndClear,
                titleKey: const Key('settings-logout-label'),
                subtitle: l10n.logoutAndClearDesc,
                trailing: const Icon(Icons.logout, color: Color(0xffd4a85f)),
                onTap: () => _logoutAndClear(context, l10n),
              ),
            ),
            const SizedBox(height: 24),
            buildSectionTitle(l10n.captureMode),
            buildCard(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: CaptureModeSelector(controller: captureModeController),
              ),
            ),
            if (diagnosticController case final diagnostics?) ...<Widget>[
              const SizedBox(height: 24),
              buildSectionTitle(l10n.diagnosticLoggingSection),
              buildCard(
                child: Column(
                  children: <Widget>[
                    AnimatedBuilder(
                      animation: diagnostics,
                      builder: (context, _) => buildSwitchTile(
                        switchKey: const Key('diagnosticLoggingSwitch'),
                        title: l10n.diagnosticLoggingTitle,
                        subtitle: l10n.diagnosticLoggingDesc,
                        value: diagnostics.enabled,
                        onChanged: diagnostics.setEnabled,
                      ),
                    ),
                    const Divider(color: Color(0xff294052), height: 1),
                    DiagnosticUserSection(controller: diagnostics),
                  ],
                ),
              ),
            ],
            if (showDeveloperDiagnostics) ...<Widget>[
              const SizedBox(height: 24),
              buildSectionTitle(l10n.diagnosticsAndAbout),
              buildCard(
                child: DiagnosticsSection(
                  browserController: browserController,
                  captureModeController: captureModeController,
                  gameCaptureController: gameCaptureController,
                  prototypeStatusController: prototypeStatusController,
                  gameRenderingModeController: gameRenderingModeController,
                ),
              ),
            ],
            if (fcdMapController != null ||
                questCatalogController != null ||
                improvementPlannerController != null) ...<Widget>[
              const SizedBox(height: 24),
              buildSectionTitle(l10n.fcdMapSectionTitle),
              buildCard(
                child: Column(
                  children: <Widget>[
                    if (fcdMapController case final controller?)
                      FcdMapUpdateSection(controller: controller),
                    if (fcdMapController != null &&
                        questCatalogController != null)
                      const Divider(height: 1),
                    if (questCatalogController case final controller?)
                      QuestCatalogUpdateSection(controller: controller),
                    if ((fcdMapController != null ||
                            questCatalogController != null) &&
                        improvementPlannerController != null)
                      const Divider(height: 1),
                    if (improvementPlannerController case final controller?)
                      ImprovementDatasetUpdateSection(controller: controller),
                  ],
                ),
              ),
            ],
            if (gameResourceCacheController case final controller?) ...<Widget>[
              const SizedBox(height: 24),
              buildSectionTitle(l10n.gameResourceCacheTitle),
              buildCard(
                child: GameResourceCacheSection(controller: controller),
              ),
            ],
            const SizedBox(height: 24),
            buildSectionTitle(l10n.storageAndCache),
            buildCard(
              child: Column(
                children: <Widget>[
                  buildActionTile(
                    key: const Key('settings-clear-quest-cache'),
                    title: l10n.clearQuestCache,
                    subtitle: l10n.clearQuestCacheDesc,
                    trailing: const Icon(Icons.delete_outline),
                    onTap: () async {
                      await gameStateController.clearQuestsCache();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.questCacheCleared)),
                        );
                      }
                    },
                  ),
                  const Divider(color: Color(0xff294052), height: 1),
                  buildActionTile(
                    key: const Key('settings-clear-logbook'),
                    title: l10n.clearLogbook,
                    subtitle: l10n.clearLogbookDesc,
                    trailing: const Icon(Icons.delete_forever_outlined),
                    onTap: () => _clearLogbook(context, l10n),
                  ),
                  const Divider(color: Color(0xff294052), height: 1),
                  buildActionTile(
                    key: const Key('settings-clear-web-cache'),
                    title: l10n.clearWebCache,
                    subtitle: l10n.clearWebCacheDesc,
                    trailing: const Icon(Icons.cleaning_services_outlined),
                    onTap: () => _clearWebCache(context, l10n),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Future<void> _logoutAndClear(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.logoutConfirmTitle),
        content: Text(l10n.logoutConfirmDesc),
        backgroundColor: const Color(0xff142735),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.confirmClear),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await browserController.logoutAndClearSession();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.logoutSucceeded)));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.logoutFailed)));
      }
    }
  }

  Future<void> _clearWebCache(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final confirmed = await _confirmClear(
      context,
      title: l10n.clearWebCacheConfirmTitle,
      description: l10n.clearWebCacheConfirmDesc,
      l10n: l10n,
    );
    if (!confirmed) return;
    await browserController.clearCache();
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.webCacheCleared)));
    }
  }

  Future<void> _clearLogbook(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final confirmed = await _confirmClear(
      context,
      title: l10n.clearLogbookConfirmTitle,
      description: l10n.clearLogbookConfirmDesc,
      l10n: l10n,
    );
    if (!confirmed) return;
    try {
      await LogbookDatabase.instance.clearAll();
    } catch (error) {
      debugPrint('清理航海日志失败: $error');
    }
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.logbookCleared)));
    }
  }

  Future<bool> _confirmClear(
    BuildContext context, {
    required String title,
    required String description,
    required AppLocalizations l10n,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(description),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(l10n.confirmClear),
              ),
            ],
          ),
        ) ??
        false;
  }
}
