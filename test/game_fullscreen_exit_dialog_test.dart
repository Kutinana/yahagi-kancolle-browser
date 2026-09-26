import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_fullscreen_exit_dialog.dart';

void main() {
  Widget buildHost({required Widget child}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('zh'),
      home: Scaffold(body: child),
    );
  }

  testWidgets(
    'shows confirmation dialog, cancel returns false and does not set preference',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      bool? result;
      await tester.pumpWidget(
        buildHost(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await confirmGameFullscreenExit(context: context);
              },
              child: const Text('Exit'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Exit'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('fullscreen-exit-confirm-dialog')),
        findsOneWidget,
      );
      expect(find.text('确定退出游戏全屏？'), findsOneWidget);
      expect(find.text('退出全屏后将恢复控制台与工具栏显示。'), findsOneWidget);

      // Check skip next time checkbox
      await tester.tap(
        find.byKey(const Key('fullscreen-exit-skip-confirmation')),
      );
      await tester.pumpAndSettle();

      // Tap cancel
      await tester.tap(find.byKey(const Key('fullscreen-exit-cancel')));
      await tester.pumpAndSettle();

      expect(result, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(exitFullscreenSkipConfirmationKey), isNull);
    },
  );

  testWidgets(
    'confirming with skip checkbox sets preference and future calls skip dialog',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      bool? result;
      await tester.pumpWidget(
        buildHost(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await confirmGameFullscreenExit(context: context);
              },
              child: const Text('Exit'),
            ),
          ),
        ),
      );

      // First exit: check skip and confirm
      await tester.tap(find.text('Exit'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('fullscreen-exit-skip-confirmation')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('fullscreen-exit-confirm')));
      await tester.pumpAndSettle();

      expect(result, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(exitFullscreenSkipConfirmationKey), isTrue);

      // Second exit: should skip immediately
      result = null;
      await tester.tap(find.text('Exit'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
      expect(
        find.byKey(const Key('fullscreen-exit-confirm-dialog')),
        findsNothing,
      );
    },
  );
}
