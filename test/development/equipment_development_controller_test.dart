import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/development/development_repository.dart';
import 'package:yahagi_kancolle_browser/src/development/development_resources.dart';
import 'package:yahagi_kancolle_browser/src/development/equipment_development_controller.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';

void main() {
  test(
    'initializes from fleet 1 flagship and preserves manual pool selection',
    () async {
      final controller = EquipmentDevelopmentController(
        repository: _repository(),
      );
      await controller.initialize(_stateWithFlagship(101));
      expect(controller.selectedPoolKey, 'carrier-akagi#1');

      controller.selectPool('gunnery-other#3');
      controller.updateGameState(_stateWithFlagship(202));
      expect(controller.selectedPoolKey, 'gunnery-other#3');

      controller.useCurrentFlagship();
      expect(controller.selectedPoolKey, 'torpedo-sendai#2');
    },
  );

  test('invalid resources do not replace the committed recipe', () async {
    final controller = EquipmentDevelopmentController(
      repository: _repository(),
    );
    await controller.initialize(_stateWithFlagship(101));

    controller.commitResources(const DevelopmentResources(20, 30, 40, 50));
    controller.commitResources(const DevelopmentResources(9, 30, 40, 50));
    expect(controller.resources, const DevelopmentResources(20, 30, 40, 50));
  });

  test('target selection and search update the derived picker state', () async {
    final controller = EquipmentDevelopmentController(
      repository: _repository(),
    );
    await controller.initialize(_stateWithFlagship(101));

    expect(controller.filteredEquipment.map((item) => item.id), contains(7));
    controller.toggleTarget(7);
    expect(controller.targets, {7});
    expect(controller.recipes, isNotEmpty);

    controller.setEquipmentSearch('雷达');
    expect(controller.filteredEquipment.map((item) => item.id), [8]);
    controller.setEquipmentTypeFilter(1);
    expect(controller.filteredEquipment, isEmpty);
  });

  test('repository failure leaves a retryable error state', () async {
    var calls = 0;
    final repository = DevelopmentRepository(
      loadString: (_) async {
        calls++;
        if (calls == 1) throw StateError('temporary');
        return jsonEncode(_snapshot());
      },
    );
    final controller = EquipmentDevelopmentController(repository: repository);

    await controller.initialize(_stateWithFlagship(101));
    expect(controller.error, isNotNull);
    await controller.retry();
    expect(controller.error, isNull);
    expect(controller.selectedPoolKey, 'carrier-akagi#1');
  });
}

DevelopmentRepository _repository() =>
    DevelopmentRepository(loadString: (_) async => jsonEncode(_snapshot()));

GameState _stateWithFlagship(int masterId) => GameState(
  hasPortData: true,
  ships: {1: OwnedShip(id: 1, masterId: masterId, level: 1)},
  fleets: const [
    Fleet(id: 1, name: '第一舰队', shipIds: [1]),
  ],
  masterShips: {
    masterId: MasterShip(id: masterId, name: '旗舰$masterId', shipTypeId: 2),
  },
  masterSlotItems: const {
    7: MasterSlotItem(id: 7, name: '测试主炮', type: [0, 0, 1]),
    8: MasterSlotItem(id: 8, name: '测试雷达', type: [0, 0, 12]),
  },
);

Map<String, Object?> _snapshot() => {
  'schema_version': 1,
  'generated_at': '2026-09-01T00:00:00.000Z',
  'source': {
    'repository': 'https://example.invalid',
    'commit': 'abc',
    'hashes': {'pool': 'hash'},
  },
  'summary': {
    'pool_count': 3,
    'selectable_pool_count': 3,
    'equipment_count': 2,
    'negative_pool_count': 0,
    'minimum_resource_pool_count': 0,
  },
  'equipment': [
    {
      'id': 7,
      'name': '主炮',
      'type_id': 1,
      'minimum_resources': [10, 10, 10, 10],
    },
    {
      'id': 8,
      'name': '雷达',
      'type_id': 12,
      'minimum_resources': [10, 10, 10, 10],
    },
  ],
  'pools': [
    _pool('carrier-akagi#1', 'carrier-akagi', 1, [101], {'7': 2, '8': 1}),
    _pool('torpedo-sendai#2', 'torpedo-sendai', 2, [202], {'7': 2, '8': 1}),
    _pool('gunnery-other#3', 'gunnery-other', 3, [101, 202], {'7': 2, '8': 1}),
  ],
  'secretaries': [
    {'ship_id': 101, 'pool_key': 'carrier-akagi#1'},
    {'ship_id': 202, 'pool_key': 'torpedo-sendai#2'},
  ],
};

Map<String, Object?> _pool(
  String key,
  String name,
  int id,
  List<int> ships,
  Map<String, num> rates,
) => {
  'pool_key': key,
  'name': name,
  'labels': {'zh': name, 'zh_Hant': name, 'ja': name},
  'pool_id': id,
  'ship_ids': ships,
  'drop_rates': rates,
  'criteria': {
    'ship_types': <Object?>[],
    'class_types': <Object?>[],
    'ship_names': <Object?>[],
    'ship_ids': <Object?>[],
    'excluded_ship_ids': <Object?>[],
  },
};
