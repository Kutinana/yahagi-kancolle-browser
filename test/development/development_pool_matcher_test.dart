import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/development/development_dataset.dart';
import 'package:yahagi_kancolle_browser/src/development/development_pool_matcher.dart';
import 'package:yahagi_kancolle_browser/src/development/development_resources.dart';

void main() {
  final dataset = DevelopmentDataset.fromJson({
    'schema_version': 1,
    'generated_at': '2026-09-01T00:00:00.000Z',
    'source': {
      'repository': 'https://example.invalid',
      'commit': 'abc',
      'hashes': {'pool': 'hash'},
    },
    'summary': {
      'pool_count': 4,
      'selectable_pool_count': 2,
      'equipment_count': 2,
      'negative_pool_count': 1,
      'minimum_resource_pool_count': 1,
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
        'name': '副炮',
        'type_id': 4,
        'minimum_resources': [10, 10, 10, 10],
      },
    ],
    'pools': [
      _pool('wide#3', 3, [1, 2], {'7': 2, '8': 1}),
      _pool('base#3', 3, [1], {'8': 2}),
      _pool('negative#-3', -3, [1, 2], {'7': -2}, minimum: [20, 20, 20, 20]),
      _pool('bauxite#1', 1, [1], {'7': 9}),
    ],
    'secretaries': [
      {'ship_id': 1, 'pool_key': 'base#3'},
    ],
  });

  test('pool type uses strict comparisons and documented tie order', () {
    expect(
      selectDevelopmentPoolType(const DevelopmentResources(10, 10, 10, 11)),
      DevelopmentPoolType.bauxite,
    );
    expect(
      selectDevelopmentPoolType(const DevelopmentResources(10, 11, 10, 11)),
      DevelopmentPoolType.ammunition,
    );
    expect(
      selectDevelopmentPoolType(const DevelopmentResources(11, 11, 11, 11)),
      DevelopmentPoolType.fuelSteel,
    );
  });

  test('forward calculation preserves replacement details', () {
    final result = calculateDevelopmentRates(
      dataset,
      dataset.pool('base#3'),
      const DevelopmentResources(20, 20, 20, 20),
    );

    expect(result.compatiblePools.map((pool) => pool.key), [
      'wide#3',
      'negative#-3',
      'base#3',
    ]);
    expect(result.details[7], [2, -2]);
    expect(result.totals[7], 0);
    expect(result.details[8], [1, 2]);
    expect(result.totals[8], 3);
  });

  test('forward calculation filters pools above the current resources', () {
    final result = calculateDevelopmentRates(
      dataset,
      dataset.pool('base#3'),
      const DevelopmentResources(10, 10, 10, 10),
    );

    expect(result.compatiblePools.map((pool) => pool.key), [
      'wide#3',
      'base#3',
    ]);
    expect(result.totals[7], 2);
  });

  test('negative pools register zero unless equipment 168 is targeted', () {
    final compatible = findCompatibleDevelopmentPools(
      dataset.pools,
      dataset.pool('base#3'),
      DevelopmentPoolType.fuelSteel,
    );

    expect(mergeDevelopmentDropRates(compatible, includeNegative: false)[7], 2);
    expect(mergeDevelopmentDropRates(compatible, includeNegative: true)[7], 0);
  });
}

Map<String, Object?> _pool(
  String key,
  int id,
  List<int> ships,
  Map<String, num> rates, {
  List<int>? minimum,
}) => <String, Object?>{
  'pool_key': key,
  'name': key.split('#').first,
  'labels': {'zh': key, 'zh_Hant': key, 'ja': key},
  'pool_id': id,
  'ship_ids': ships,
  'minimum_resources': ?minimum,
  'drop_rates': rates,
  'criteria': {
    'ship_types': <Object?>[],
    'class_types': <Object?>[],
    'ship_names': <Object?>[],
    'ship_ids': <Object?>[],
    'excluded_ship_ids': <Object?>[],
  },
};
