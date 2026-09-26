import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_serializer.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'startup never treats the previous cached account as logged in',
    () async {
      SharedPreferences.setMockInitialValues({
        'yahagi_kancolle_browser_game_state': GameStateSerializer.serialize(
          const GameState(
            memberId: 1001,
            hasMasterData: true,
            hasPortData: true,
            masterShips: {7: MasterShip(id: 7, name: '三日月', shipTypeId: 2)},
            ships: {1: OwnedShip(id: 1, masterId: 7, level: 1)},
          ),
        ),
      });
      final restored = await GameStateStore().load();
      expect(restored.memberId, 0);
      expect(restored.ships, isEmpty);
      expect(restored.hasPortData, isFalse);
      expect(restored.masterShips[7]?.name, '三日月');
      expect((await GameStateStore().loadForAccount(1001)).ships.keys, [1]);
      expect((await GameStateStore().loadForAccount(2002)).ships, isEmpty);
    },
  );

  test(
    'debounced writes keep both accounts and share only master data',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = GameStateStore(saveDelay: const Duration(hours: 1));
      store.save(
        const GameState(
          memberId: 1001,
          masterShips: {7: MasterShip(id: 7, name: '三日月', shipTypeId: 2)},
          resources: {GameResourceType.fuel: 100},
          ships: {1: OwnedShip(id: 1, masterId: 7, level: 1)},
        ),
      );
      store.save(
        const GameState(
          memberId: 2002,
          resources: {GameResourceType.fuel: 200},
        ),
      );
      await store.flush();
      expect(
        (await store.loadForAccount(1001)).resource(GameResourceType.fuel),
        100,
      );
      expect(
        (await store.loadForAccount(2002)).resource(GameResourceType.fuel),
        200,
      );
      expect((await store.loadForAccount(2002)).ships, isEmpty);
      expect((await store.loadForAccount(2002)).masterShips[7]?.name, '三日月');
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('account.1001.game_state.v1'),
        isNot(contains('masterShips')),
      );
      expect((await store.load()).ships, isEmpty);
    },
  );
}
