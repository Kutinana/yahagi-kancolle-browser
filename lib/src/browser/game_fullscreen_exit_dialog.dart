import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localizations.dart';

const exitFullscreenSkipConfirmationKey =
    'game_fullscreen_exit_skip_confirmation';

Future<bool> isExitFullscreenConfirmationSkipped([
  SharedPreferences? preferences,
]) async {
  try {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    return prefs.getBool(exitFullscreenSkipConfirmationKey) ?? false;
  } catch (_) {
    return false;
  }
}

Future<void> setExitFullscreenConfirmationSkipped(
  bool value, [
  SharedPreferences? preferences,
]) async {
  try {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    await prefs.setBool(exitFullscreenSkipConfirmationKey, value);
  } catch (_) {
    // Non-fatal if preference saving fails.
  }
}

Future<bool> confirmGameFullscreenExit({
  required BuildContext context,
  SharedPreferences? preferences,
}) async {
  if (await isExitFullscreenConfirmationSkipped(preferences)) {
    return true;
  }
  if (!context.mounted) return false;
  final l10n =
      AppLocalizations.of(context) ??
      lookupAppLocalizations(const Locale('zh'));
  var skipNextTime = false;
  final confirmed =
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            key: const Key('fullscreen-exit-confirm-dialog'),
            title: Text(l10n.exitFullscreenConfirmTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.exitFullscreenConfirmDescription),
                const SizedBox(height: 16),
                CheckboxListTile(
                  key: const Key('fullscreen-exit-skip-confirmation'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: skipNextTime,
                  title: Text(l10n.exitFullscreenSkipConfirmation),
                  onChanged: (value) =>
                      setState(() => skipNextTime = value ?? false),
                ),
              ],
            ),
            actions: [
              TextButton(
                key: const Key('fullscreen-exit-cancel'),
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                key: const Key('fullscreen-exit-confirm'),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.exitFullscreenConfirmAction),
              ),
            ],
          ),
        ),
      ) ??
      false;
  if (!confirmed) return false;
  if (skipNextTime) {
    await setExitFullscreenConfirmationSkipped(true, preferences);
  }
  return true;
}
