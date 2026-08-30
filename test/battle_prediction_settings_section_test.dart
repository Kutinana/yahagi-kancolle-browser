import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/settings/battle_prediction_settings.dart';
import 'package:yahagi_kancolle_browser/src/settings/battle_prediction_settings_section.dart';

void main() {
  testWidgets('defaults to POI and persists a Yahagi selection', (
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

    final segmented = tester.widget<SegmentedButton<BattlePredictionMethod>>(
      find.byKey(const Key('battle-prediction-method')),
    );
    expect(segmented.selected, <BattlePredictionMethod>{
      BattlePredictionMethod.poi,
    });
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
    expect(
      find.text('按战斗模拟规则完整复演，预测更精确，但性能开销更高。切换从下一场战斗开始生效。'),
      findsOneWidget,
    );

    await tester.tap(find.text('轻量模式'));
    await tester.pump();

    expect(controller.method, BattlePredictionMethod.yahagi);
    expect(await store.load(), BattlePredictionMethod.yahagi);
    expect(find.text('使用轻量化预测逻辑，性能开销更低。切换从下一场战斗开始生效。'), findsOneWidget);

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
