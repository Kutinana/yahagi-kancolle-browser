import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'notification_settings_controller.dart';
import 'notification_settings_store.dart';
import 'settings_ui_helpers.dart';

class NotificationSettingsPage extends StatelessWidget with SettingsUIHelpers {
  const NotificationSettingsPage({super.key, required this.controller});

  final NotificationSettingsController controller;

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));

    return Container(
      color: const Color(0xff0d1a26),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final settings = controller.settings;
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. 全局通知服务
                buildSectionTitle(l10n.notificationSectionGeneral),
                buildCard(
                  child: Column(
                    children: [
                      buildSwitchTile(
                        title: l10n.notificationEnableMaster,
                        value: settings.master,
                        onChanged: (v) => controller.setMaster(v),
                      ),
                      const Divider(color: Color(0xff294052), height: 1),
                      buildSwitchTile(
                        title: l10n.notificationSound,
                        value: settings.sound,
                        onChanged: settings.master
                            ? (v) => controller.setSound(v)
                            : (v) {},
                      ),
                      const Divider(color: Color(0xff294052), height: 1),
                      buildSwitchTile(
                        title: l10n.notificationVibration,
                        value: settings.vibration,
                        onChanged: settings.master
                            ? (v) => controller.setVibration(v)
                            : (v) {},
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 2. 后台进行中常驻进度 (Ongoing)
                buildSectionTitle(l10n.notificationSectionOngoing),
                buildCard(
                  child: Column(
                    children: [
                      buildSwitchTile(
                        title: l10n.notificationOngoingLive,
                        value: settings.ongoingLive,
                        onChanged: settings.master
                            ? (v) => controller.setOngoingLive(v)
                            : (v) {},
                      ),
                      const Divider(color: Color(0xff294052), height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildCheckItem(
                              label: l10n.notificationProgress,
                              value: settings.showProgress,
                              enabled: settings.master && settings.ongoingLive,
                              onChanged: (v) =>
                                  controller.setShowProgress(v ?? true),
                            ),
                            _buildCheckItem(
                              label: l10n.notificationPercent,
                              value: settings.showPercent,
                              enabled: settings.master && settings.ongoingLive,
                              onChanged: (v) =>
                                  controller.setShowPercent(v ?? true),
                            ),
                            _buildCheckItem(
                              label: l10n.notificationCountdown,
                              value: settings.showCountdown,
                              enabled: settings.master && settings.ongoingLive,
                              onChanged: (v) =>
                                  controller.setShowCountdown(v ?? true),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 3. 业务通知分类与提醒时机 (Type)
                buildSectionTitle(l10n.notificationSectionTypes),
                buildCard(
                  child: Column(
                    children: [
                      // 3.1 远征归还
                      buildSwitchTile(
                        title: l10n.notificationExpedition,
                        value: settings.expedition,
                        onChanged: settings.master
                            ? (v) => controller.setExpedition(v)
                            : (v) {},
                      ),
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 16,
                          right: 16,
                          bottom: 12,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<int>(
                            segments: [
                              ButtonSegment<int>(
                                value: 0,
                                label: Text(l10n.notificationPunctual),
                              ),
                              ButtonSegment<int>(
                                value: 30,
                                label: Text(l10n.notificationPreempt30s),
                              ),
                              ButtonSegment<int>(
                                value: 60,
                                label: Text(l10n.notificationPreempt60s),
                              ),
                              ButtonSegment<int>(
                                value: 120,
                                label: Text(l10n.notificationPreempt120s),
                              ),
                            ],
                            selected: {settings.expeditionPreemptSeconds},
                            onSelectionChanged:
                                settings.master && settings.expedition
                                    ? (set) => controller
                                        .setExpeditionPreemptSeconds(set.first)
                                    : null,
                            style: _segmentedButtonStyle,
                          ),
                        ),
                      ),
                      const Divider(color: Color(0xff294052), height: 1),

                      // 3.2 入渠修复
                      buildSwitchTile(
                        title: l10n.notificationRepair,
                        value: settings.repair,
                        onChanged: settings.master
                            ? (v) => controller.setRepair(v)
                            : (v) {},
                      ),
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 16,
                          right: 16,
                          bottom: 12,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<int>(
                            segments: [
                              ButtonSegment<int>(
                                value: 0,
                                label: Text(l10n.notificationRepairPunctual),
                              ),
                              ButtonSegment<int>(
                                value: 60,
                                label: Text(l10n.notificationPreempt60s),
                              ),
                            ],
                            selected: {settings.repairPreemptSeconds},
                            onSelectionChanged:
                                settings.master && settings.repair
                                    ? (set) => controller
                                        .setRepairPreemptSeconds(set.first)
                                    : null,
                            style: _segmentedButtonStyle,
                          ),
                        ),
                      ),
                      const Divider(color: Color(0xff294052), height: 1),

                      // 3.3 泊地修理
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Text(
                                    l10n.notificationAnchorage,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Color(0xffd4a85f),
                                      borderRadius: BorderRadius.all(
                                        Radius.circular(3),
                                      ),
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 1,
                                      ),
                                      child: Text(
                                        'NEW',
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: settings.anchorage,
                              onChanged: settings.master
                                  ? (v) => controller.setAnchorage(v)
                                  : (v) {},
                              activeThumbColor: const Color(0xffd4a85f),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 16,
                          right: 16,
                          bottom: 12,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<AnchorageNotificationMode>(
                            segments: [
                              ButtonSegment<AnchorageNotificationMode>(
                                value:
                                    AnchorageNotificationMode.twentyMinutes,
                                label: Text(l10n.notificationAnchorage20m),
                              ),
                              ButtonSegment<AnchorageNotificationMode>(
                                value: AnchorageNotificationMode.allRepaired,
                                label: Text(l10n.notificationAnchorageFull),
                              ),
                              ButtonSegment<AnchorageNotificationMode>(
                                value: AnchorageNotificationMode.both,
                                label: Text(l10n.notificationAnchorageBoth),
                              ),
                            ],
                            selected: {settings.anchorageMode},
                            onSelectionChanged:
                                settings.master && settings.anchorage
                                    ? (set) => controller.setAnchorageMode(
                                        set.first,
                                      )
                                    : null,
                            style: _segmentedButtonStyle,
                          ),
                        ),
                      ),
                      const Divider(color: Color(0xff294052), height: 1),

                      // 3.4 工厂建造
                      buildSwitchTile(
                        title: l10n.notificationConstruction,
                        value: settings.construction,
                        onChanged: settings.master
                            ? (v) => controller.setConstruction(v)
                            : (v) {},
                      ),
                      const Divider(color: Color(0xff294052), height: 1),

                      // 3.5 士气 / 疲劳与刷闪
                      buildSwitchTile(
                        title: l10n.notificationMorale,
                        value: settings.morale,
                        onChanged: settings.master
                            ? (v) => controller.setMorale(v)
                            : (v) {},
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCheckItem({
    required String label,
    required bool value,
    required bool enabled,
    required ValueChanged<bool?> onChanged,
  }) {
    return InkWell(
      onTap: enabled ? () => onChanged(!value) : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(
            value: value,
            onChanged: enabled ? onChanged : null,
            activeColor: const Color(0xffd4a85f),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: enabled ? const Color(0xff8197a5) : const Color(0xff526776),
            ),
          ),
        ],
      ),
    );
  }

  static final ButtonStyle _segmentedButtonStyle = ButtonStyle(
    textStyle: WidgetStateProperty.all(
      const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
    ),
    side: WidgetStateProperty.all(
      const BorderSide(color: Color(0xff294052), width: 1),
    ),
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return const Color(0xff526776);
      }
      if (states.contains(WidgetState.selected)) {
        return const Color(0xffd4a85f);
      }
      return const Color(0xff8197a5);
    }),
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return const Color(0xff0d1a26);
      }
      return Colors.transparent;
    }),
  );
}
