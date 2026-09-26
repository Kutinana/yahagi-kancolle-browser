import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'layout_settings_controller.dart';
import 'settings_ui_helpers.dart';

class HdLayoutSettingsSection extends StatelessWidget with SettingsUIHelpers {
  const HdLayoutSettingsSection({super.key, required this.controller});
  final LayoutSettingsController controller;

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return buildSwitchTile(
          title: l10n.hdMode,
          switchKey: const Key('settings-hd-mode'),
          subtitle: l10n.hdModeDescription,
          value: controller.hdSettings.enabled,
          onChanged: controller.setHdEnabled,
        );
      },
    );
  }
}
