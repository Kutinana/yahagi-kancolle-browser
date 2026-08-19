import 'package:flutter/material.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import 'battle_prediction_settings.dart';
import 'battle_prediction_settings_section.dart';
import 'safety_settings_controller.dart';
import 'safety_settings_store.dart';
import 'settings_ui_helpers.dart';

class BattleSettingsPage extends StatelessWidget with SettingsUIHelpers {
  const BattleSettingsPage({
    super.key,
    this.battlePredictionSettingsController,
    required this.safetySettingsController,
  });

  final BattlePredictionSettingsController? battlePredictionSettingsController;
  final SafetySettingsController safetySettingsController;

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
            buildSectionTitle(l10n.gameSafety),
            buildCard(
              child: AnimatedBuilder(
                animation: safetySettingsController,
                builder: (context, _) => Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.blockSortieTitle,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      DropdownButton<BattleWarningMode>(
                        value: safetySettingsController.battleWarningMode,
                        underline: const SizedBox(),
                        items: [
                          DropdownMenuItem(
                            value: BattleWarningMode.off,
                            child: Text(l10n.battleWarningOff),
                          ),
                          DropdownMenuItem(
                            value: BattleWarningMode.confirm,
                            child: Text(l10n.battleWarningConfirm),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            safetySettingsController.setBattleWarningMode(
                              value,
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            buildSectionTitle(l10n.battleAlertsSection),
            buildCard(
              child: AnimatedBuilder(
                animation: safetySettingsController,
                builder: (context, _) => buildSwitchTile(
                  title: l10n.battleDamageVibration,
                  subtitle: l10n.battleDamageVibrationDesc,
                  value: safetySettingsController.battleDamageVibrationEnabled,
                  onChanged:
                      safetySettingsController.setBattleDamageVibrationEnabled,
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (battlePredictionSettingsController != null) ...<Widget>[
              buildSectionTitle(l10n.battlePredictionSection),
              buildCard(
                child: BattlePredictionSettingsSection(
                  controller: battlePredictionSettingsController!,
                ),
              ),
              const SizedBox(height: 24),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
