import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/src/battle/formation_memory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('shared preferences store defaults to empty memory', () async {
    final values = await SharedPreferencesFormationMemoryStore().load();

    expect(values, isEmpty);
  });

  test('shared preferences store ignores invalid entries', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'battle.formationMemory':
          '{"1-1-3":5,"bad":5,"1-1-4":99,"0-1-4":1,"2-3-4":"5"}',
    });

    final values = await SharedPreferencesFormationMemoryStore().load();

    expect(values, <String, int>{'1-1-3': 5});
  });

  test('shared preferences store tolerates malformed json', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'battle.formationMemory': '{broken',
    });

    final values = await SharedPreferencesFormationMemoryStore().load();

    expect(values, isEmpty);
  });

  test('shared preferences store round trips formation memory', () async {
    final store = SharedPreferencesFormationMemoryStore();

    await store.save(<String, int>{'1-1-3': 5, '62-4-21': 14});

    expect(await store.load(), <String, int>{'1-1-3': 5, '62-4-21': 14});
  });

  test('controller isolates nodes and skips duplicate saves', () async {
    final store = MemoryFormationMemoryStore(<String, int>{'1-1-3': 5});
    final controller = await FormationMemoryController.load(store);

    expect(controller.formationFor(mapAreaId: 1, mapInfoNo: 1, node: 3), 5);
    expect(
      controller.formationFor(mapAreaId: 1, mapInfoNo: 1, node: 4),
      isNull,
    );

    await controller.remember(
      mapAreaId: 1,
      mapInfoNo: 1,
      node: 3,
      formation: 5,
    );

    expect(store.saveCount, 0);
  });

  test(
    'controller persists a valid formation and rejects invalid input',
    () async {
      final store = MemoryFormationMemoryStore();
      final controller = await FormationMemoryController.load(store);

      await controller.remember(
        mapAreaId: 62,
        mapInfoNo: 4,
        node: 21,
        formation: 14,
      );
      await controller.remember(
        mapAreaId: 62,
        mapInfoNo: 4,
        node: 22,
        formation: 99,
      );
      await controller.remember(
        mapAreaId: 0,
        mapInfoNo: 4,
        node: 23,
        formation: 1,
      );

      expect(store.values, <String, int>{'62-4-21': 14});
      expect(store.saveCount, 1);
    },
  );
}
