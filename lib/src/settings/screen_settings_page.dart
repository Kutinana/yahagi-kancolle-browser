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
import 'header_resource_settings.dart';
import 'settings_ui_helpers.dart';
import 'hd_layout_settings_section.dart';
import '../fleet/fleet_ui_strings.dart';

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
                    Padding(
                      key: const Key('settings-ui-display-size-row'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.uiDisplaySizeTitle,
                                  key: const Key(
                                    'settings-ui-display-size-label',
                                  ),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  l10n.uiDisplaySizeDesc,
                                  style: const TextStyle(
                                    color: Color(0xff8197a5),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          DropdownButton<UiDisplaySize>(
                            key: const Key('settings-ui-display-size-dropdown'),
                            value: layoutSettingsController.uiDisplaySize,
                            underline: const SizedBox(),
                            alignment: AlignmentDirectional.centerEnd,
                            items: [
                              DropdownMenuItem(
                                value: UiDisplaySize.normal,
                                child: Text(l10n.uiDisplaySizeNormal),
                              ),
                              DropdownMenuItem(
                                value: UiDisplaySize.compact,
                                child: Text(l10n.uiDisplaySizeCompact),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                layoutSettingsController.setUiDisplaySize(
                                  value,
                                );
                              }
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
                    buildActionTile(
                      title: fleetText(context, '功能区位置'),
                      titleKey: const Key('settings-information-panel-left'),
                      subtitle: fleetText(context, '选择功能区显示在左侧或右侧，竖屏保持上下布局。'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          OutlinedButton.icon(
                            key: const Key(
                              'settings-reset-dashboard-card-order',
                            ),
                            onPressed: layoutSettingsController
                                .resetDashboardCardOrder,
                            icon: const Icon(Icons.restore, size: 18),
                            label: Text(l10n.restoreDefaultOrder),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 60,
                            child: DropdownButton<String>(
                              key: const Key(
                                'settings-information-panel-position',
                              ),
                              isExpanded: true,
                              padding: const EdgeInsets.only(left: 14),
                              underline: const SizedBox.shrink(),
                              value:
                                  layoutSettingsController
                                      .informationPanelOnLeft
                                  ? 'left'
                                  : 'right',
                              items: [
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
                                      .setInformationPanelOnLeft(
                                        value == 'left',
                                      );
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (layoutSettingsController.hdSettings.enabled) ...[
                      const Divider(color: Color(0xff294052), height: 1),
                      buildActionTile(
                        title: fleetText(context, '拓展功能区位置'),
                        titleKey: const Key(
                          'settings-hd-extension-position-title',
                        ),
                        trailing: DropdownButton<String>(
                          key: const Key('settings-hd-extension-position'),
                          underline: const SizedBox.shrink(),
                          value:
                              layoutSettingsController
                                  .hdSettings
                                  .extensionAboveGame
                              ? 'top'
                              : 'bottom',
                          items: [
                            DropdownMenuItem(
                              value: 'bottom',
                              child: Text(l10n.menuPositionBottom),
                            ),
                            DropdownMenuItem(
                              value: 'top',
                              child: Text(l10n.menuPositionTop),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              layoutSettingsController.setHdExtensionPosition(
                                value,
                              );
                            }
                          },
                        ),
                      ),
                    ],
                    const Divider(color: Color(0xff294052), height: 1),
                    buildSwitchTile(
                      title: l10n.uiLockTitle,
                      titleKey: const Key('settings-ui-lock-switch'),
                      subtitle: l10n.uiLockDesc,
                      value: layoutSettingsController.uiLocked,
                      onChanged: layoutSettingsController.setUiLocked,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            buildSectionTitle(l10n.topNoticeSectionTitle),
            buildCard(
              child: AnimatedBuilder(
                animation: layoutSettingsController,
                builder: (context, _) => Column(
                  children: [
                    buildSwitchTile(
                      title: l10n.topNoticeEnabledTitle,
                      titleKey: const Key('settings-top-notice-enabled'),
                      subtitle: l10n.topNoticeEnabledSubtitle,
                      value: layoutSettingsController.topNoticeEnabled,
                      onChanged: layoutSettingsController.setTopNoticeEnabled,
                    ),
                    const Divider(color: Color(0xff294052), height: 1),
                    Opacity(
                      opacity: layoutSettingsController.topNoticeEnabled
                          ? 1.0
                          : 0.45,
                      child: IgnorePointer(
                        ignoring: !layoutSettingsController.topNoticeEnabled,
                        child: Padding(
                          key: const Key('settings-top-notice-duration-row'),
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
                                      l10n.topNoticeDurationTitle,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      l10n.topNoticeDurationSubtitle,
                                      style: const TextStyle(
                                        color: Color(0xff8197a5),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  key: const Key(
                                    'settings-top-notice-duration-dropdown',
                                  ),
                                  value:
                                      const [5, 10, 15].contains(
                                        layoutSettingsController
                                            .topNoticeDurationSeconds,
                                      )
                                      ? layoutSettingsController
                                            .topNoticeDurationSeconds
                                      : 5,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        layoutSettingsController
                                            .topNoticeEnabled
                                        ? const Color(0xffd4a85f)
                                        : const Color(0xff526776),
                                  ),
                                  items: [
                                    DropdownMenuItem(
                                      value: 5,
                                      child: Text(l10n.topNoticeDuration5s),
                                    ),
                                    DropdownMenuItem(
                                      value: 10,
                                      child: Text(l10n.topNoticeDuration10s),
                                    ),
                                    DropdownMenuItem(
                                      value: 15,
                                      child: Text(l10n.topNoticeDuration15s),
                                    ),
                                  ],
                                  onChanged:
                                      layoutSettingsController.topNoticeEnabled
                                      ? (value) {
                                          if (value != null) {
                                            layoutSettingsController
                                                .setTopNoticeDurationSeconds(
                                                  value,
                                                );
                                          }
                                        }
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ),
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
                child: GameMouseWheelSettingsSection(controller: wheel),
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
                            subtitle:
                                retention.errorMessage ??
                                l10n.backgroundGameRetentionDesc,
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
