import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/development/development_dataset.dart';
import 'package:yahagi_kancolle_browser/src/development/development_repository.dart';
import 'package:yahagi_kancolle_browser/src/development/development_resources.dart';

void main() {
  Map<String, Object?> snapshot({bool unknownEquipment = false}) =>
      <String, Object?>{
        'schema_version': 1,
        'generated_at': '2026-09-01T00:00:00.000Z',
        'source': {
          'repository': 'https://example.invalid/source',
          'commit': 'abc1234',
          'hashes': {'DevelopmentPool.json': 'hash'},
        },
        'summary': {
          'pool_count': 1,
          'selectable_pool_count': 1,
          'equipment_count': 1,
          'negative_pool_count': 0,
          'minimum_resource_pool_count': 0,
        },
        'pools': [
          {
            'pool_key': 'carrier-other#1',
            'name': '空母系-其它',
            'labels': {'zh': '空母系-其它', 'zh_Hant': '空母系-其它', 'ja': '空母系-その他'},
            'pool_id': 1,
            'ship_ids': [1, 1, 2],
            'drop_rates': {unknownEquipment ? '999' : '20': 2},
            'criteria': {
              'ship_types': ['CV'],
              'class_types': <Object?>[],
              'ship_names': <Object?>[],
              'ship_ids': <Object?>[],
              'excluded_ship_ids': <Object?>[],
            },
          },
        ],
        'equipment': [
          {
            'id': 20,
            'name': '九七式艦攻',
            'type_id': 8,
            'minimum_resources': [10, 20, 30, 40],
          },
        ],
        'secretaries': [
          {'ship_id': 1, 'pool_key': 'carrier-other#1'},
        ],
      };

  test('dataset parses localized labels and validates references', () {
    final dataset = DevelopmentDataset.fromJson(snapshot());

    expect(
      dataset.pool('carrier-other#1').label(const Locale('ja')),
      '空母系-その他',
    );
    expect(dataset.poolsByName['空母系-其它'], hasLength(1));
    expect(dataset.pool('carrier-other#1').shipIds, [1, 1, 2]);
    expect(dataset.pool('carrier-other#1').shipIdSet, {1, 2});
    expect(
      dataset.equipment[20]!.minimumResources,
      const DevelopmentResources(10, 20, 30, 40),
    );
    expect(dataset.secretaries[1]!.poolKey, 'carrier-other#1');
  });

  test('dataset rejects a drop rate for unknown equipment', () {
    expect(
      () => DevelopmentDataset.fromJson(snapshot(unknownEquipment: true)),
      throwsFormatException,
    );
  });

  test(
    'bundled snapshot loads with the expected authoritative counts',
    () async {
      final dataset = DevelopmentDataset.fromJsonString(
        await File(
          'assets/data/development/development_snapshot.json',
        ).readAsString(),
      );

      expect(dataset.poolsByKey, hasLength(99));
      expect(dataset.selectablePools, hasLength(45));
      expect(dataset.equipment, hasLength(102));
      expect(dataset.source.commit, 'd065120');
    },
  );

  test('resources normalize to the game recipe limits', () {
    expect(
      const DevelopmentResources(0, 10, 301, 99).normalized(),
      const DevelopmentResources(10, 10, 300, 99),
    );
  });

  test(
    'repository caches success and retries after a loading failure',
    () async {
      var calls = 0;
      final encoded = jsonEncode(snapshot());
      final repository = DevelopmentRepository(
        loadString: (_) async {
          calls++;
          if (calls == 1) throw StateError('temporary');
          return encoded;
        },
      );

      await expectLater(repository.load(), throwsStateError);
      final first = await repository.load();
      final second = await repository.load();
      expect(identical(first, second), isTrue);
      expect(calls, 2);
    },
  );
}
