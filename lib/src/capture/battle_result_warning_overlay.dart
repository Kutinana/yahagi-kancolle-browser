import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../battle/battle_controller.dart';
import '../battle/battle_damage_alert.dart';
import '../battle/battle_models.dart';
import '../settings/safety_settings_controller.dart';
import '../settings/safety_settings_store.dart';
import 'game_capture_controller.dart';

bool shouldShowPostBattleWarning(LiveBattle? battle) {
  if (battle == null || battle.displayStage != BattleDisplayStage.result) {
    return false;
  }
  final context = battle.context;
  final isBossNode =
      (context.bossNode > 0 && context.node == context.bossNode) ||
      context.nodeTypeLabel == 'Boss 战';
  if (isBossNode) {
    return false;
  }
  return battle.friendShips.any(
    (ship) => !ship.isEscaped && ship.isHeavilyDamaged,
  );
}

class BattleResultWarningOverlay extends StatefulWidget {
  const BattleResultWarningOverlay({
    super.key,
    required this.gameCaptureController,
    required this.battleController,
    required this.safetySettingsController,
    required this.damageAlertPort,
    required this.child,
  });

  final GameCaptureController gameCaptureController;
  final BattleController battleController;
  final SafetySettingsController safetySettingsController;
  final BattleDamageAlertPort damageAlertPort;
  final Widget child;

  @override
  State<BattleResultWarningOverlay> createState() =>
      _BattleResultWarningOverlayState();
}

class _BattleResultWarningOverlayState
    extends State<BattleResultWarningOverlay> {
  @override
  void initState() {
    super.initState();
    widget.gameCaptureController.eventActivity.addListener(
      _onGameCaptureUpdate,
    );
  }

  @override
  void didUpdateWidget(BattleResultWarningOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gameCaptureController != widget.gameCaptureController) {
      oldWidget.gameCaptureController.eventActivity.removeListener(
        _onGameCaptureUpdate,
      );
      widget.gameCaptureController.eventActivity.addListener(
        _onGameCaptureUpdate,
      );
    }
  }

  @override
  void dispose() {
    widget.gameCaptureController.eventActivity.removeListener(
      _onGameCaptureUpdate,
    );
    super.dispose();
  }

  void _onGameCaptureUpdate() {
    final event = widget.gameCaptureController.latestEvent;
    if (event == null || !event.path.endsWith('/battleresult')) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _checkWarning();
    });
  }

  void _checkWarning() {
    final battle = widget.battleController.current;
    if (!shouldShowPostBattleWarning(battle)) return;
    final mode = widget.safetySettingsController.battleWarningMode;
    if (mode == BattleWarningMode.off) return;
    if (widget.safetySettingsController.battleDamageVibrationEnabled) {
      unawaited(
        widget.damageAlertPort
            .alert(BattleDamageAlertSeverity.postBattleWarning)
            .catchError((Object error) {
              debugPrint('战后大破警告震动失败: $error');
            }),
      );
    }
    _showWarningDialog();
  }

  void _showWarningDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final l10n =
            AppLocalizations.of(context) ??
            lookupAppLocalizations(const Locale('zh'));
        return AlertDialog(
          backgroundColor: const Color(0xff122431),
          title: Text(
            l10n.postBattleWarningTitle,
            style: const TextStyle(color: Color(0xffd4a85f)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.postBattleWarningHeadline,
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.postBattleWarningBody,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xff4B9FD5),
              ),
              child: Text(l10n.acknowledgeAndRetreat),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
