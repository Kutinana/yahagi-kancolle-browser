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
}
