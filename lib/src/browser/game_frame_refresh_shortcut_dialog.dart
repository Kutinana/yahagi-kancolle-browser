import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../settings/game_frame_refresh_shortcut_settings.dart';

Future<bool> confirmGameFrameRefreshShortcut({
  required BuildContext context,
  required GameFrameRefreshShortcutSettings settings,
}) async {
  if (settings.skipHeaderConfirmation) return true;
  final l10n =
      AppLocalizations.of(context) ??
      lookupAppLocalizations(const Locale('zh'));
  var skipNextTime = false;
  final confirmed =
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            key: const Key('frame-refresh-confirm-dialog'),
            title: Text(l10n.frameRefreshShortcutConfirmTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.frameRefreshShortcutConfirmDescription),
                const SizedBox(height: 16),
                CheckboxListTile(
                  key: const Key('frame-refresh-skip-confirmation'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: skipNextTime,
                  title: Text(l10n.frameRefreshShortcutSkipConfirmation),
                  onChanged: (value) =>
                      setState(() => skipNextTime = value ?? false),
                ),
              ],
            ),
            actions: [
              TextButton(
                key: const Key('frame-refresh-cancel'),
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                key: const Key('frame-refresh-confirm'),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.frameRefreshShortcutConfirmAction),
              ),
            ],
          ),
        ),
      ) ??
      false;
  if (!confirmed) return false;
  if (skipNextTime) await settings.setSkipHeaderConfirmation(true);
  return true;
}
