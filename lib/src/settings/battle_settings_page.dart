import 'package:flutter/material.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import 'battle_prediction_settings.dart';
import 'battle_prediction_settings_section.dart';
import 'battle_status_effect_settings.dart';
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
            buildSectionTitle(l10n.battleStatusEffectsSection),
            buildCard(
              child: AnimatedBuilder(
                animation: safetySettingsController,
                builder: (context, _) {
                  final settings = safetySettingsController.battleStatusEffects;
                  final childrenEnabled = settings.enabled;
                  return Column(
                    children: <Widget>[
                      buildSwitchTile(
                        title: l10n.battleStatusEffectsEnabled,
                        subtitle: l10n.battleStatusEffectsEnabledDesc,
                        switchKey: const Key('battleStatusEffectsMasterSwitch'),
                        value: settings.enabled,
                        onChanged: safetySettingsController
                            .setBattleStatusEffectsEnabled,
                      ),
                      const Divider(height: 1, color: Color(0xff294052)),
                      _StatusEffectRow(
                        title: l10n.battleEffectDisplayScope,
                        subtitle: l10n.battleEffectDisplayScopeDesc,
                        enabled: childrenEnabled,
                        trailing: DropdownButton<BattleEffectDisplayScope>(
                          key: const Key('battleEffectScopeDropdown'),
                          value: settings.displayScope,
                          underline: const SizedBox(),
                          items: BattleEffectDisplayScope.values
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(_scopeLabel(l10n, value)),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: childrenEnabled
                              ? (value) {
                                  if (value != null) {
                                    safetySettingsController
                                        .setBattleEffectDisplayScope(value);
                                  }
                                }
                              : null,
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xff294052)),
                      _StatusEffectRow(
                        title: l10n.battleDamagePulse,
                        subtitle: l10n.battleDamagePulseDesc,
                        enabled: childrenEnabled,
                        trailing: DropdownButton<DamagePulseFilter>(
                          key: const Key('damagePulseFilterDropdown'),
                          value: settings.damagePulseFilter,
                          underline: const SizedBox(),
                          items: DamagePulseFilter.values
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(_pulseFilterLabel(l10n, value)),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: childrenEnabled
                              ? (value) {
                                  if (value != null) {
                                    safetySettingsController
                                        .setDamagePulseFilter(value);
                                  }
                                }
                              : null,
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xff294052)),
                      _StatusEffectRow(
                        title: l10n.battleDamageVibrationEffect,
                        subtitle: l10n.battleDamageVibrationEffectDesc,
                        enabled: childrenEnabled,
                        trailing: DropdownButton<DamageVibrationFilter>(
                          key: const Key('damageVibrationFilterDropdown'),
                          value: settings.damageVibrationFilter,
                          underline: const SizedBox(),
                          items: DamageVibrationFilter.values
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(
                                    _vibrationFilterLabel(l10n, value),
                                  ),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: childrenEnabled
                              ? (value) {
                                  if (value != null) {
                                    safetySettingsController
                                        .setDamageVibrationFilter(value);
                                  }
                                }
                              : null,
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xff294052)),
                      buildSwitchTile(
                        title: l10n.battleMoraleSparkle,
                        subtitle: l10n.battleMoraleSparkleDesc,
                        switchKey: const Key('moraleSparkleSwitch'),
                        value: settings.moraleSparkleEnabled,
                        onChanged: childrenEnabled
                            ? safetySettingsController.setMoraleSparkleEnabled
                            : null,
                      ),
                    ],
                  );
                },
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

String _pulseFilterLabel(AppLocalizations l10n, DamagePulseFilter filter) =>
    switch (filter) {
      DamagePulseFilter.off => l10n.battleEffectOff,
      DamagePulseFilter.minorOnly => l10n.battleEffectMinorOnly,
      DamagePulseFilter.moderateOnly => l10n.battleEffectModerateOnly,
      DamagePulseFilter.heavyOnly => l10n.battleEffectHeavyOnly,
      DamagePulseFilter.all => l10n.battleEffectAll,
    };

String _scopeLabel(AppLocalizations l10n, BattleEffectDisplayScope scope) =>
    switch (scope) {
      BattleEffectDisplayScope.predictionOnly =>
        l10n.battleEffectScopePredictionOnly,
      BattleEffectDisplayScope.fleetOnly => l10n.battleEffectScopeFleetOnly,
      BattleEffectDisplayScope.all => l10n.battleEffectScopeAll,
    };

String _vibrationFilterLabel(
  AppLocalizations l10n,
  DamageVibrationFilter filter,
) => switch (filter) {
  DamageVibrationFilter.off => l10n.battleEffectOff,
  DamageVibrationFilter.moderateOnly => l10n.battleEffectModerateOnly,
  DamageVibrationFilter.heavyOnly => l10n.battleEffectHeavyOnly,
  DamageVibrationFilter.all => l10n.battleEffectAll,
};

class _StatusEffectRow extends StatelessWidget {
  const _StatusEffectRow({
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final bool enabled;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: enabled ? null : const Color(0xff526776),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: enabled ? const Color(0xff8197a5) : const Color(0xff526776),
          ),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    text,
                    const SizedBox(height: 8),
                    Align(alignment: Alignment.centerRight, child: trailing),
                  ],
                )
              : Row(
                  children: <Widget>[
                    Expanded(child: text),
                    const SizedBox(width: 12),
                    trailing,
                  ],
                ),
        );
      },
    );
  }
}
