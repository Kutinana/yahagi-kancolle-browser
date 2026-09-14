import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'game_browser_controller.dart';
import 'game_frame_refresh_shortcut_action.dart';

Future<void> showGameRefreshDialog({
  required BuildContext context,
  required Future<void> Function() onRefreshPage,
  required Future<GameFrameReloadResult> Function() onReloadGame,
}) {
  final l10n =
      AppLocalizations.of(context) ??
      lookupAppLocalizations(const Locale('zh'));
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.confirmGameRefreshTitle),
      content: Text(l10n.gameRefreshDialogDescription),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(l10n.cancel),
        ),
        OutlinedButton(
          key: const Key('refresh-full-page'),
          onPressed: () async {
            Navigator.of(dialogContext).pop();
            await onRefreshPage();
          },
          child: Text(l10n.refreshGamePage),
        ),
        FilledButton(
          key: const Key('reload-game-frame'),
          onPressed: () async {
            Navigator.of(dialogContext).pop();
            await runGameFrameRefreshShortcut(
              context: context,
              reload: onReloadGame,
            );
          },
          child: Text(l10n.reloadGame),
        ),
      ],
    ),
  );
}
