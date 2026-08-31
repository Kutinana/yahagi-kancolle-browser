import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/src/settings/battle_prediction_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('loading settings removes the legacy prediction method', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'battle.predictionMethod': 'yahagi',
    });
    final store = SharedPreferencesBattlePredictionSettingsStore();
    final controller = await BattlePredictionSettingsController.load(store);
    addTearDown(controller.dispose);

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey('battle.predictionMethod'), isFalse);
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

  test('legacy cleanup failure does not block display settings', () async {
    final controller = await BattlePredictionSettingsController.load(
      _FailingLegacyCleanupStore(),
    );
    addTearDown(controller.dispose);

    expect(controller.enemyPortraitsEnabled, isFalse);
    expect(controller.lastFormationHintEnabled, isFalse);
  });
}

final class _FailingLegacyCleanupStore
    implements BattlePredictionSettingsStore {
  @override
  Future<void> initialize() async {
    throw StateError('legacy cleanup failed');
  }

  @override
  Future<bool> loadEnemyPortraitsEnabled() async => false;

  @override
  Future<bool> loadLastFormationHintEnabled() async => false;

  @override
  Future<void> saveEnemyPortraitsEnabled(bool enabled) async {}

  @override
  Future<void> saveLastFormationHintEnabled(bool enabled) async {}
}
