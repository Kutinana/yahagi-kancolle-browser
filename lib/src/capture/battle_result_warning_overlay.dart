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
  bool _pendingAdvanceWarning = false;
  bool _warningDialogVisible = false;

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
    if (event == null || event.apiResult != 1) return;

    if (event.path.endsWith('/battleresult')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _pendingAdvanceWarning = shouldShowPostBattleWarning(
          widget.battleController.current,
        );
      });
      return;
    }

    if (_isRetreatOrPortPath(event.path)) {
      _pendingAdvanceWarning = false;
      return;
    }

    if (event.path != '/kcsapi/api_req_map/next' || !_pendingAdvanceWarning) {
      return;
    }

    _pendingAdvanceWarning = false;
    if (mounted) _showPendingWarning();
  }

  bool _isRetreatOrPortPath(String path) =>
      path == '/kcsapi/api_req_sortie/goback_port' ||
      path == '/kcsapi/api_req_combined_battle/goback_port' ||
      path == '/kcsapi/api_port/port';

  void _showPendingWarning() {
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
    if (_warningDialogVisible) return;
    _warningDialogVisible = true;
    unawaited(
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
      ).whenComplete(() {
        _warningDialogVisible = false;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
