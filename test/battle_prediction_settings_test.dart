import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/src/settings/battle_prediction_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('missing prediction setting defaults to POI', () async {
    final store = SharedPreferencesBattlePredictionSettingsStore();

    expect(await store.load(), BattlePredictionMethod.poi);
  });

  test('unknown prediction setting defaults to POI', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'battle.predictionMethod': 'future-engine',
    });
    final store = SharedPreferencesBattlePredictionSettingsStore();

    expect(await store.load(), BattlePredictionMethod.poi);
  });

  test('missing enemy portrait setting defaults to enabled', () async {
    final store = SharedPreferencesBattlePredictionSettingsStore();

    expect(await store.loadEnemyPortraitsEnabled(), isTrue);
  });

  test('enemy portrait setting loads a saved disabled value', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'battle.enemyPreviewPortraitsEnabled': false,
    });
    final store = SharedPreferencesBattlePredictionSettingsStore();

    expect(await store.loadEnemyPortraitsEnabled(), isFalse);
  });

  test('missing last formation hint setting defaults to enabled', () async {
    final store = SharedPreferencesBattlePredictionSettingsStore();

    expect(await store.loadLastFormationHintEnabled(), isTrue);
  });

  test('last formation hint setting loads a saved disabled value', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'battle.lastFormationHintEnabled': false,
    });
    final store = SharedPreferencesBattlePredictionSettingsStore();

    expect(await store.loadLastFormationHintEnabled(), isFalse);
  });

  test('controller persists both prediction methods', () async {
    final store = MemoryBattlePredictionSettingsStore();
    final controller = await BattlePredictionSettingsController.load(store);
    addTearDown(controller.dispose);

    expect(controller.method, BattlePredictionMethod.poi);

    await controller.setMethod(BattlePredictionMethod.yahagi);
    expect(controller.method, BattlePredictionMethod.yahagi);
    expect(await store.load(), BattlePredictionMethod.yahagi);

    await controller.setMethod(BattlePredictionMethod.poi);
    expect(controller.method, BattlePredictionMethod.poi);
    expect(await store.load(), BattlePredictionMethod.poi);
  });

  test('controller persists enemy portrait visibility', () async {
    final store = MemoryBattlePredictionSettingsStore();
    final controller = await BattlePredictionSettingsController.load(store);
    addTearDown(controller.dispose);

    expect(controller.enemyPortraitsEnabled, isTrue);

    await controller.setEnemyPortraitsEnabled(false);
    expect(controller.enemyPortraitsEnabled, isFalse);
    expect(await store.loadEnemyPortraitsEnabled(), isFalse);

    await controller.setEnemyPortraitsEnabled(true);
    expect(controller.enemyPortraitsEnabled, isTrue);
    expect(await store.loadEnemyPortraitsEnabled(), isTrue);
  });

  test('controller persists last formation hint visibility', () async {
    final store = MemoryBattlePredictionSettingsStore();
    final controller = await BattlePredictionSettingsController.load(store);
    addTearDown(controller.dispose);

    expect(controller.lastFormationHintEnabled, isTrue);

    await controller.setLastFormationHintEnabled(false);
    expect(controller.lastFormationHintEnabled, isFalse);
    expect(await store.loadLastFormationHintEnabled(), isFalse);

    await controller.setLastFormationHintEnabled(true);
    expect(controller.lastFormationHintEnabled, isTrue);
    expect(await store.loadLastFormationHintEnabled(), isTrue);
  });
}
