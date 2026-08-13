import 'package:flutter/material.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import 'about_dialog.dart';
import 'release_check_service.dart';
import 'settings_ui_helpers.dart';

class AboutSupportSettingsPage extends StatelessWidget with SettingsUIHelpers {
  const AboutSupportSettingsPage({
    super.key,
    required this.currentVersion,
    this.releaseChecker,
  });

  final String currentVersion;
  final ReleaseChecker? releaseChecker;

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
            buildSectionTitle(l10n.aboutApp),
            AboutContentWidget(
              currentVersion: currentVersion,
              releaseChecker: releaseChecker,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
