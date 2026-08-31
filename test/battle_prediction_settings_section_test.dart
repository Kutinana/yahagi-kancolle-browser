import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/settings/battle_prediction_settings.dart';
import 'package:yahagi_kancolle_browser/src/settings/battle_prediction_settings_section.dart';

void main() {
  testWidgets('shows only POI display options and persists both switches', (
    tester,
  ) async {
    final store = MemoryBattlePredictionSettingsStore();
    final controller = await BattlePredictionSettingsController.load(store);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BattlePredictionSettingsSection(controller: controller),
        ),
      ),
    );

    expect(find.byType(SegmentedButton), findsNothing);
    expect(find.text('增强模式'), findsNothing);
    expect(find.text('轻量模式'), findsNothing);
    expect(find.byType(Switch), findsNWidgets(2));
    expect(
      tester
          .widget<Switch>(
            find.byKey(const Key('battle-enemy-preview-portraits')),
          )
          .value,
      isTrue,
    );
    expect(
      tester
          .widget<Switch>(find.byKey(const Key('battle-last-formation-hint')))
          .value,
      isTrue,
    );
    expect(find.text('在未卜先知中显示战前敌方立绘。'), findsOneWidget);

    await tester.tap(find.byKey(const Key('battle-enemy-preview-portraits')));
    await tester.pump();

    expect(controller.enemyPortraitsEnabled, isFalse);
    expect(await store.loadEnemyPortraitsEnabled(), isFalse);

    await tester.tap(find.byKey(const Key('battle-last-formation-hint')));
    await tester.pump();

    expect(controller.lastFormationHintEnabled, isFalse);
    expect(await store.loadLastFormationHintEnabled(), isFalse);
  });
}
