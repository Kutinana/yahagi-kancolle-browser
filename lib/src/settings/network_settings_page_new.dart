import 'package:flutter/material.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import '../browser/gadget_bypass_controller.dart';
import '../browser/game_browser_controller.dart';
import 'gadget_bypass_section.dart';
import 'network_settings_controller.dart';
import 'network_settings_section.dart';
import 'settings_ui_helpers.dart';

class NetworkSettingsPageNew extends StatelessWidget with SettingsUIHelpers {
  const NetworkSettingsPageNew({
    super.key,
    required this.networkSettingsController,
    required this.gadgetBypassController,
    required this.browserController,
  });

  final NetworkSettingsController networkSettingsController;
  final GadgetBypassController gadgetBypassController;
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
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
