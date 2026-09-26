import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_frame_refresh_shortcut_dialog.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_frame_refresh_shortcut_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<GameFrameRefreshShortcutSettings> pumpHarness(
    WidgetTester tester,
    ValueChanged<bool> onDecision,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final settings = await GameFrameRefreshShortcutSettings.load();
    addTearDown(settings.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => onDecision(
              await confirmGameFrameRefreshShortcut(
                context: context,
                settings: settings,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    return settings;
  }

  testWidgets('cancel discards the checked skip-confirmation choice', (
    tester,
  ) async {
    final decisions = <bool>[];
    final settings = await pumpHarness(tester, decisions.add);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('frame-refresh-skip-confirmation')));
    await tester.tap(find.byKey(const Key('frame-refresh-cancel')));
    await tester.pumpAndSettle();

    expect(decisions, <bool>[false]);
    expect(settings.skipHeaderConfirmation, isFalse);
  });

  testWidgets('confirm persists checked choice and later skips the dialog', (
    tester,
  ) async {
    final decisions = <bool>[];
    final settings = await pumpHarness(tester, decisions.add);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('frame-refresh-skip-confirmation')));
    await tester.tap(find.byKey(const Key('frame-refresh-confirm')));
    await tester.pumpAndSettle();

    expect(decisions, <bool>[true]);
    expect(settings.skipHeaderConfirmation, isTrue);
    await tester.tap(find.text('open'));
    await tester.pump();
    expect(decisions, <bool>[true, true]);
    expect(find.byKey(const Key('frame-refresh-confirm-dialog')), findsNothing);
  });
}
