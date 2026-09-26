import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/hd_layout_settings_section.dart';

void main() {
  for (final locale in [
    const Locale('zh'),
    const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    const Locale('ja'),
  ]) {
    testWidgets(
      'HD settings toggle, select modules and preserve options: $locale',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(360, 850);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final controller = await LayoutSettingsController.load(
          SharedPreferencesLayoutSettingsStore(),
        );
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: HdLayoutSettingsSection(controller: controller),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(controller.hdSettings.enabled, isFalse);
        expect(find.byKey(const Key('hd-layout-split')), findsNothing);
        await tester.tap(find.byKey(const Key('settings-hd-mode')));
        await tester.pumpAndSettle();
        expect(controller.hdSettings.enabled, isTrue);
        expect(find.byType(ChoiceChip), findsNothing);
        expect(find.byType(DropdownButton<String>), findsNothing);
        await controller.setHdModule('wide', 'quests');
        await tester.tap(find.byKey(const Key('settings-hd-mode')));
        await tester.pumpAndSettle();
        expect(controller.hdSettings.enabled, isFalse);
        expect(controller.hdSettings.wideModule, 'quests');
        expect(tester.takeException(), isNull);
      },
    );
  }
}
