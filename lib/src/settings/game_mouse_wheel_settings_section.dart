import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'game_mouse_wheel_settings.dart';
import 'settings_ui_helpers.dart';

class GameMouseWheelSettingsSection extends StatelessWidget
    with SettingsUIHelpers {
  const GameMouseWheelSettingsSection({super.key, required this.controller});
  final GameMouseWheelSettingsController controller;

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Column(
        children: [
          buildSwitchTile(
            switchKey: const Key('settings-mouse-wheel-compatibility'),
            title: l10n.mouseWheelCompatibility,
            subtitle: l10n.mouseWheelCompatibilityDescription,
            value: controller.enabled,
            onChanged: controller.saving ? null : controller.setEnabled,
          ),
          if (controller.saveFailed)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.mouseWheelCompatibilitySaveFailed),
            ),
        ],
      ),
    );
  }
}
