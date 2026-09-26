import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_browser_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_frame_refresh_shortcut_action.dart';

void main() {
  test('maps only failed frame reload results to localized messages', () {
    final l10n = lookupAppLocalizations(const Locale('zh'));
    expect(
      gameFrameReloadErrorMessage(l10n, GameFrameReloadResult.reloaded),
      isNull,
    );
    expect(
      gameFrameReloadErrorMessage(
        l10n,
        GameFrameReloadResult.gameFrameNotFound,
      ),
      l10n.gameFrameNotFound,
    );
    expect(
      gameFrameReloadErrorMessage(l10n, GameFrameReloadResult.blocked),
      l10n.gameFrameReloadBlocked,
    );
  });
}
