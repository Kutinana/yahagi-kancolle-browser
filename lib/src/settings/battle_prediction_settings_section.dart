import 'package:flutter/material.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import 'battle_prediction_settings.dart';
import 'settings_ui_helpers.dart';

class BattlePredictionSettingsSection extends StatelessWidget
    with SettingsUIHelpers {
  const BattlePredictionSettingsSection({super.key, required this.controller});

  final BattlePredictionSettingsController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          buildSwitchTile(
            title: l10n.battleEnemyPreviewPortraits,
            switchKey: const Key('battle-enemy-preview-portraits'),
            subtitle: l10n.battleEnemyPreviewPortraitsDesc,
            value: controller.enemyPortraitsEnabled,
            onChanged: controller.setEnemyPortraitsEnabled,
          ),
          const Divider(color: Color(0xff294052), height: 1),
          buildSwitchTile(
            title: l10n.battleLastFormationHint,
            switchKey: const Key('battle-last-formation-hint'),
            subtitle: l10n.battleLastFormationHintDesc,
            value: controller.lastFormationHintEnabled,
            onChanged: controller.setLastFormationHintEnabled,
          ),
        ],
      ),
    );
  }
}
