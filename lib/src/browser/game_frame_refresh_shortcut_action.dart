import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../widgets/top_notice.dart';
import 'game_browser_controller.dart';

String? gameFrameReloadErrorMessage(
  AppLocalizations l10n,
  GameFrameReloadResult result,
) => switch (result) {
  GameFrameReloadResult.gameFrameNotFound => l10n.gameFrameNotFound,
  GameFrameReloadResult.htmlWrapNotFound => l10n.gameHtmlWrapNotFound,
  GameFrameReloadResult.blocked => l10n.gameFrameReloadBlocked,
  GameFrameReloadResult.unsupported => l10n.gameFrameReloadUnsupported,
  GameFrameReloadResult.reloaded => null,
};

Future<GameFrameReloadResult> runGameFrameRefreshShortcut({
  required BuildContext context,
  required Future<GameFrameReloadResult> Function() reload,
}) async {
  GameFrameReloadResult result;
  try {
    result = await reload();
  } catch (_) {
    result = GameFrameReloadResult.blocked;
  }
  if (!context.mounted) return result;
  final l10n =
      AppLocalizations.of(context) ??
      lookupAppLocalizations(const Locale('zh'));
  final message = gameFrameReloadErrorMessage(l10n, result);
  if (message != null) {
    TopNotice.show(context, message: message, tone: TopNoticeTone.error);
  }
  return result;
}
