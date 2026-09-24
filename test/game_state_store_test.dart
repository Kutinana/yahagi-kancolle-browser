import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_store.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_serializer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('flush persists a pending debounced game state', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = GameStateStore(saveDelay: const Duration(hours: 1));
    store.save(
      GameState(
        memberId: 1001,
        resources: const <GameResourceType, int>{GameResourceType.fuel: 321},
        updatedAt: DateTime.utc(2026),
      ),
    );

    await store.flush();

    final restored = await GameStateStore().loadForAccount(1001);
    expect(restored.resource(GameResourceType.fuel), 321);
  });

  test('failed write remains pending for a later flush', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    var failNext = true;
    final store = GameStateStore(
      saveDelay: const Duration(hours: 1),
      writeString: (prefs, key, value) async {
        if (key.contains('account.1001') && failNext) {
          failNext = false;
          return false;
        }
        return prefs.setString(key, value);
      },
    );
    store.save(
      const GameState(memberId: 1001, resources: {GameResourceType.fuel: 321}),
    );
    await store.flush();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('account.1001.game_state.v1'), isNull);
    await store.flush();
    expect(
      (await GameStateStore().loadForAccount(
        1001,
      )).resource(GameResourceType.fuel),
      321,
    );
  });

  test('an older failed snapshot never overwrites a newer save', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    var failNext = true;
    final store = GameStateStore(
      saveDelay: const Duration(hours: 1),
      writeString: (prefs, key, value) async {
        if (key.contains('account.1001') && failNext) {
          failNext = false;
          return false;
        }
        return prefs.setString(key, value);
      },
    );
    store.save(
      const GameState(memberId: 1001, resources: {GameResourceType.fuel: 100}),
    );
    await store.flush();
    store.save(
      const GameState(memberId: 1001, resources: {GameResourceType.fuel: 200}),
    );
    await store.flush();
    await store.flush();
    expect(
      (await GameStateStore().loadForAccount(
        1001,
      )).resource(GameResourceType.fuel),
      200,
    );
  });

  test('pending snapshot is returned while disk writes still fail', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = GameStateStore(
      saveDelay: const Duration(hours: 1),
      writeString: (prefs, key, value) async => false,
    );
    store.save(
      const GameState(memberId: 1001, resources: {GameResourceType.fuel: 444}),
    );
    expect(
      (await store.loadForAccount(1001)).resource(GameResourceType.fuel),
      444,
    );
  });

  test(
    'failed migration does not set marker and retries on next load',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'yahagi_kancolle_browser_game_state': GameStateSerializer.serialize(
          const GameState(
            memberId: 1001,
            resources: {GameResourceType.fuel: 777},
          ),
        ),
      });
      var failOnce = true;
      final store = GameStateStore(
        writeString: (prefs, key, value) async {
          if (key == 'account.1001.game_state.v1' && failOnce) {
            failOnce = false;
            return false;
          }
          return prefs.setString(key, value);
        },
      );
      expect((await store.loadForAccount(1001)).memberId, 0);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('game_state.legacy_migrated.v1'), isNot(true));
      expect(
        (await store.loadForAccount(1001)).resource(GameResourceType.fuel),
        777,
      );
      expect(prefs.getBool('game_state.legacy_migrated.v1'), isTrue);
    },
  );
}
