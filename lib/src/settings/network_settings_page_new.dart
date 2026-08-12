import 'package:flutter/material.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import '../browser/gadget_bypass_controller.dart';
import '../browser/game_browser_controller.dart';
import '../game_state/game_state_controller.dart';
import '../logbook/logbook_database.dart';
import 'gadget_bypass_section.dart';
import 'network_settings_controller.dart';
import 'network_settings_section.dart';
import 'settings_ui_helpers.dart';

class NetworkSettingsPageNew extends StatelessWidget with SettingsUIHelpers {
  const NetworkSettingsPageNew({
    super.key,
    required this.networkSettingsController,
    required this.gadgetBypassController,
    required this.gameStateController,
    required this.browserController,
  });

  final NetworkSettingsController networkSettingsController;
  final GadgetBypassController gadgetBypassController;
  final GameStateController gameStateController;
  final GameBrowserController browserController;

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
            buildSectionTitle(l10n.networkSettings),
            buildCard(
              child: NetworkSettingsSection(
                controller: networkSettingsController,
                onApplySuccess: () {
                  // Reload game page
                  browserController.reload();
                },
              ),
            ),
            const SizedBox(height: 24),
            buildSectionTitle(l10n.gadgetBypass),
            buildCard(
              child: GadgetBypassSection(
                controller: gadgetBypassController,
                onReloadRequired: browserController.reload,
              ),
            ),
            const SizedBox(height: 24),
            buildSectionTitle(l10n.storageAndCache),
            buildCard(
              child: Column(
                children: [
                  ListTile(
                    title: Text(
                      l10n.logoutAndClear,
                      key: const Key('settings-logout-label'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      l10n.logoutAndClearDesc,
                      style: const TextStyle(color: Color(0xff8197a5)),
                    ),
                    trailing: const Icon(
                      Icons.logout,
                      color: Color(0xffd4a85f),
                    ),
                    onTap: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(l10n.logoutConfirmTitle),
                          content: Text(l10n.logoutConfirmDesc),
                          backgroundColor: const Color(0xff142735),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          actions: <Widget>[
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: Text(l10n.cancel),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: Text(l10n.confirmClear),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true) return;
                      try {
                        await browserController.logoutAndClearSession();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.logoutSucceeded)),
                          );
                        }
                      } catch (error) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.logoutFailed)),
                          );
                        }
                      }
                    },
                  ),
                  const Divider(color: Color(0xff294052), height: 1),
                  ListTile(
                    title: Text(
                      l10n.clearQuestCache,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      l10n.clearQuestCacheDesc,
                      style: const TextStyle(color: Color(0xff8197a5)),
                    ),
                    trailing: const Icon(
                      Icons.delete_outline,
                      color: Color(0xffd4a85f),
                    ),
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
                  ListTile(
                    title: Text(
                      l10n.clearWebCache,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      l10n.clearWebCacheDesc,
                      style: const TextStyle(color: Color(0xff8197a5)),
                    ),
                    trailing: const Icon(
                      Icons.cleaning_services_outlined,
                      color: Color(0xffd4a85f),
                    ),
                    onTap: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(
                            l10n.clearWebCacheConfirmTitle,
                            style: const TextStyle(fontSize: 18),
                          ),
                          content: Text(
                            l10n.clearWebCacheConfirmDesc,
                            style: const TextStyle(height: 1.5, fontSize: 14),
                          ),
                          backgroundColor: const Color(0xff142735),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: Text(
                                l10n.cancel,
                                style: const TextStyle(
                                  color: Color(0xff8197a5),
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: Text(
                                l10n.confirmClear,
                                style: const TextStyle(
                                  color: Color(0xffd4a85f),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );

                      if (confirmed == true) {
                        await browserController.clearCache();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.webCacheCleared)),
                          );
                        }
                      }
                    },
                  ),
                  const Divider(color: Color(0xff294052), height: 1),
                  ListTile(
                    title: Text(
                      l10n.clearLogbook,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      l10n.clearLogbookDesc,
                      style: const TextStyle(color: Color(0xff8197a5)),
                    ),
                    trailing: const Icon(
                      Icons.delete_forever_outlined,
                      color: Color(0xffd4a85f),
                    ),
                    onTap: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(
                            l10n.clearLogbookConfirmTitle,
                            style: const TextStyle(fontSize: 18),
                          ),
                          content: Text(
                            l10n.clearLogbookConfirmDesc,
                            style: const TextStyle(height: 1.5, fontSize: 14),
                          ),
                          backgroundColor: const Color(0xff142735),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: Text(
                                l10n.cancel,
                                style: const TextStyle(
                                  color: Color(0xff8197a5),
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: Text(
                                l10n.confirmClear,
                                style: const TextStyle(
                                  color: Color(0xffd4a85f),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );

                      if (confirmed == true) {
                        try {
                          await LogbookDatabase.instance.clearAll();
                        } catch (error) {
                          debugPrint('清理航海日志失败: $error');
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.logbookCleared)),
                          );
                        }
                      }
                    },
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
}
