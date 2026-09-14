import 'package:flutter/material.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import '../audio/game_audio_controller.dart';
import '../browser/game_toolbar_display_controller.dart';
import 'background_game_retention_controller.dart';
import 'display_mode_controller.dart';
import 'display_mode_section.dart';
import 'game_frame_rate_settings.dart';
import 'game_frame_rate_settings_section.dart';
import 'game_rendering_mode_controller.dart';
import 'game_rendering_mode_section.dart';
import 'layout_settings_controller.dart';
import 'screen_awake_controller.dart';
import 'game_mouse_wheel_settings.dart';
import 'game_mouse_wheel_settings_section.dart';
import 'game_frame_refresh_shortcut_settings.dart';
import 'settings_ui_helpers.dart';
import 'hd_layout_settings_section.dart';

class ScreenSettingsPage extends StatelessWidget with SettingsUIHelpers {
  const ScreenSettingsPage({
    super.key,
    required this.layoutSettingsController,
    required this.displayModeController,
    this.audioController,
    this.backgroundGameRetentionController,
    this.toolbarDisplayController,
    this.gameFrameRateSettingsController,
    this.screenAwakeController,
    this.gameMouseWheelSettingsController,
    this.gameFrameRefreshShortcutSettings,
    this.gameRenderingModeController,
    this.isBattleActive = false,
  });

  final LayoutSettingsController layoutSettingsController;
  final DisplayModeController displayModeController;
  final GameAudioController? audioController;
  final BackgroundGameRetentionController? backgroundGameRetentionController;
  final GameToolbarDisplayController? toolbarDisplayController;
  final GameFrameRateSettingsController? gameFrameRateSettingsController;
  final ScreenAwakeController? screenAwakeController;
  final GameMouseWheelSettingsController? gameMouseWheelSettingsController;
  final GameFrameRefreshShortcutSettings? gameFrameRefreshShortcutSettings;
  final GameRenderingModeController? gameRenderingModeController;
  final bool isBattleActive;

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
          children: [
            buildSectionTitle(l10n.layoutSettings),
            buildCard(
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  layoutSettingsController,
                  displayModeController,
                ]),
                builder: (context, _) => Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l10n.language,
                            key: const Key('settings-language-label'),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          DropdownButton<String>(
                            value: layoutSettingsController.localeCode ?? 'zh',
                            underline: const SizedBox(),
                            alignment: AlignmentDirectional.centerEnd,
                            items: [
                              DropdownMenuItem(
                                value: 'zh',
                                child: Text(l10n.langZh),
                              ),
                              DropdownMenuItem(
                                value: 'zh_Hant',
                                child: Text(l10n.langZhHant),
                              ),
                              DropdownMenuItem(
                                value: 'ja',
                                child: Text(l10n.langJa),
                              ),
                            ],
                            onChanged: (value) {
                              layoutSettingsController.setLocaleCode(value);
                            },
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Color(0xff294052), height: 1),
                    buildSwitchTile(
                      title: l10n.autoZoom,
                      titleKey: const Key('settings-auto-zoom-label'),
                      value: layoutSettingsController.autoZoom,
                      onChanged: (v) => layoutSettingsController.setAutoZoom(v),
                    ),
                    const Divider(color: Color(0xff294052), height: 1),
                    buildSliderTile(
                      title: l10n.infoPanelWidth,
                      value: layoutSettingsController
                          .effectiveInformationPanelRatio,
                      min: 0.25,
                      max: 0.5,
                      onChanged:
                          layoutSettingsController
                              .canAdjustInformationPanelRatio
                          ? (v) => layoutSettingsController.setGameAreaRatio(
                              1.0 - v,
                            )
                          : null,
                    ),
                    const Divider(color: Color(0xff294052), height: 1),
                    DisplayModeSection(controller: displayModeController),
                    const Divider(color: Color(0xff294052), height: 1),
                    Padding(
                      key: const Key('settings-workspace-menu-position'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.workspaceMenuPosition,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  l10n.workspaceMenuPositionDesc,
                                  style: const TextStyle(
                                    color: Color(0xff8197a5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              OutlinedButton.icon(
                                key: const Key(
                                  'settings-reset-workspace-menu-order',
                                ),
                                onPressed: layoutSettingsController
                                    .resetWorkspaceMenuOrder,
                                icon: const Icon(Icons.restore, size: 18),
                                label: Text(l10n.restoreDefaultOrder),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 60,
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  padding: const EdgeInsets.only(left: 14),
                                  underline: const SizedBox.shrink(),
                                  value: layoutSettingsController
                                      .workspaceMenuPosition,
                                  items: [
                                    DropdownMenuItem(
                                      value: 'top',
                                      child: Text(l10n.menuPositionTop),
                                    ),
                                    DropdownMenuItem(
                                      value: 'bottom',
                                      child: Text(l10n.menuPositionBottom),
                                    ),
                                    DropdownMenuItem(
                                      value: 'left',
                                      child: Text(l10n.menuPositionLeft),
                                    ),
                                    DropdownMenuItem(
                                      value: 'right',
                                      child: Text(l10n.menuPositionRight),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    if (value != null) {
                                      layoutSettingsController
                                          .setWorkspaceMenuPosition(value);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Color(0xff294052), height: 1),
                    buildSwitchTile(
                      title: l10n.informationPanelOnLeft,
                      titleKey: const Key('settings-information-panel-left'),
                      subtitle: l10n.informationPanelOnLeftDesc,
                      value: layoutSettingsController.informationPanelOnLeft,
                      onChanged:
                          layoutSettingsController.setInformationPanelOnLeft,
                      trailingBeforeSwitch: OutlinedButton.icon(
                        key: const Key('settings-reset-dashboard-card-order'),
                        onPressed:
                            layoutSettingsController.resetDashboardCardOrder,
                        icon: const Icon(Icons.restore, size: 18),
                        label: Text(l10n.restoreDefaultOrder),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            buildSectionTitle(l10n.hdMode),
            buildCard(
              child: HdLayoutSettingsSection(
                controller: layoutSettingsController,
              ),
            ),
            if (gameMouseWheelSettingsController case final wheel?) ...<Widget>[
              const SizedBox(height: 24),
              buildSectionTitle(l10n.mouseWheelCompatibility),
              buildCard(
                child: GameMouseWheelSettingsSection(
                  controller: wheel,
                  frameRefreshSettings: gameFrameRefreshShortcutSettings,
                ),
              ),
            ],
            if (gameFrameRateSettingsController != null) ...<Widget>[
              const SizedBox(height: 24),
              buildSectionTitle(l10n.frameRateSettingsSection),
              buildCard(
                child: GameFrameRateSettingsSection(
                  controller: gameFrameRateSettingsController!,
                ),
              ),
            ],
            if (gameRenderingModeController != null) ...<Widget>[
              const SizedBox(height: 24),
              buildSectionTitle(l10n.gameRenderingModeTitle),
              buildCard(
                child: GameRenderingModeSection(
                  controller: gameRenderingModeController!,
                  isBattleActive: isBattleActive,
                ),
              ),
            ],
            if (screenAwakeController != null) ...<Widget>[
              const SizedBox(height: 24),
              buildSectionTitle(l10n.screenAwake),
              buildCard(
                child: AnimatedBuilder(
                  animation: screenAwakeController!,
                  builder: (context, _) => buildSwitchTile(
                    title: l10n.screenAwake,
                    subtitle: l10n.screenAwakeDesc,
                    value: screenAwakeController!.enabled,
                    onChanged: screenAwakeController!.setEnabled,
                  ),
                ),
              ),
            ],
            if (audioController case final audio?) ...<Widget>[
              const SizedBox(height: 24),
              buildSectionTitle(l10n.gameAndSound),
              buildCard(
                child: AnimatedBuilder(
                  animation: audio,
                  builder: (context, _) => Column(
                    children: <Widget>[
                      buildSwitchTile(
                        title: l10n.gameSound,
                        value: !audio.isMuted,
                        onChanged: (value) {
                          if (audio.canToggle) audio.toggleMuted();
                        },
                      ),
                      const Divider(color: Color(0xff294052), height: 1),
                      buildSwitchTile(
                        title: l10n.backgroundAudio,
                        titleKey: const Key('settings-background-audio'),
                        subtitle: l10n.backgroundAudioDesc,
                        value: audio.backgroundPlaybackEnabled,
                        onChanged: audio.setBackgroundPlaybackEnabled,
                      ),
                      if (backgroundGameRetentionController
                          case final retention?) ...<Widget>[
                        const Divider(color: Color(0xff294052), height: 1),
                        AnimatedBuilder(
                          animation: retention,
                          builder: (context, _) => buildSwitchTile(
                            title: l10n.backgroundGameRetention,
                            titleKey: const Key(
                              'settings-background-game-retention',
                            ),
                            subtitle: l10n.backgroundGameRetentionDesc,
                            value: retention.enabled,
                            onChanged: retention.setEnabled,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
