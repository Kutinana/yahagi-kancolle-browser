import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/audio/game_audio_controller.dart';
import 'package:yahagi_kancolle_browser/src/audio/game_audio_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/sound_settings_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sound settings cannot disable background game execution', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final controller = await GameAudioController.load(
      SharedPreferencesGameAudioStore(),
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
        home: SoundSettingsPage(audioController: controller),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Switch), findsOneWidget);
    expect(find.text('后台声音'), findsNothing);
  });
}
