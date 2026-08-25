import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/audio/game_audio_controller.dart';
import 'package:yahagi_kancolle_browser/src/audio/game_audio_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/background_game_retention_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/display_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/display_mode_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/screen_settings_page.dart';

void main() {
  testWidgets(
    'background game retention appears after background audio and defaults on',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final layoutController = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      final displayController = await DisplayModeController.load(
        MemoryDisplayModeStore(),
      );
      final audioController = await GameAudioController.load(
        SharedPreferencesGameAudioStore(),
      );
      final retentionController = await BackgroundGameRetentionController.load(
        SharedPreferencesBackgroundGameRetentionStore(),
      );

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: ScreenSettingsPage(
            layoutSettingsController: layoutController,
            displayModeController: displayController,
            audioController: audioController,
            backgroundGameRetentionController: retentionController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final backgroundAudio = find.byKey(
        const Key('settings-background-audio'),
      );
      final retention = find.byKey(
        const Key('settings-background-game-retention'),
      );
      await tester.ensureVisible(retention);

      expect(retention, findsOneWidget);
      expect(find.text('后台保持游戏'), findsOneWidget);
      expect(find.text('进入后台时显示常驻通知以降低游戏会话被系统回收的概率，可能增加耗电。'), findsOneWidget);
      expect(
        tester.getTopLeft(retention).dy,
        greaterThan(tester.getTopLeft(backgroundAudio).dy),
      );
      expect(retentionController.enabled, isTrue);

      final row = find
          .ancestor(of: retention, matching: find.byType(Row))
          .first;
      await tester.tap(find.descendant(of: row, matching: find.byType(Switch)));
      await tester.pump();

      expect(retentionController.enabled, isFalse);
    },
  );
}
