import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import '../../tool/development_data/development_snapshot_builder.dart';

void main() {
  const source = DevelopmentSourceMetadata(
    repository: 'https://github.com/SkywalkerJi/kc-development-tools',
    commit: 'd065120',
    hashes: {'DevelopmentPool.json': 'abc'},
  );

  final start2 = <String, Object?>{
    'api_mst_ship': <Object?>[
      {
        'api_id': 1,
        'api_name': '一号',
        'api_stype': 2,
        'api_ctype': 1,
        'api_aftershipid': '2',
      },
      {
        'api_id': 2,
        'api_name': '二号',
        'api_stype': 2,
        'api_ctype': 1,
        'api_aftershipid': '0',
      },
      {
        'api_id': 3,
        'api_name': '三号',
        'api_stype': 3,
        'api_ctype': 2,
        'api_aftershipid': '0',
      },
    ],
    'api_mst_slotitem': <Object?>[
      {
        'api_id': 7,
        'api_name': '测试主炮',
        'api_type': [0, 0, 1, 0, 0],
        'api_broken': [1, 2, 3, 4],
      },
      {
        'api_id': 8,
        'api_name': '测试雷达',
        'api_type': [0, 0, 12, 0, 0],
        'api_broken': [1, 1, 1, 1],
      },
    ],
  };

  Map<String, Object?> build({List<Object?>? pools}) =>
      buildDevelopmentSnapshot(
        pools:
            pools ??
            <Object?>[
              {
                '开发池名称': '水雷系-测试',
                '开发池ID': 2,
                '舰种': ['DD'],
                '舰型': ['绫波型'],
                '舰名': ['一号'],
                '舰ID': [3],
                '不包含舰ID': [3, 1],
                '出货率': {'7': 2, '8': 0},
              },
              {
                '开发池名称': '水雷系-测试-门槛',
                '开发池ID': -2,
                '舰ID': [2],
                '最低资源': [20, 30, 40, 50],
                '出货率': {'7': -1},
              },
            ],
        start2: start2,
        ctypeNames: const {'1': '绫波型', '2': '球磨型'},
        poolLabels: const {
          '水雷系-测试': {'zh': '水雷系-测试', 'zh_Hant': '水雷系-測試', 'ja': '水雷系-テスト'},
          '水雷系-测试-门槛': {
            'zh': '水雷系-测试-门槛',
            'zh_Hant': '水雷系-測試-門檻',
            'ja': '水雷系-テスト-門限',
          },
        },
        source: source,
        generatedAt: DateTime.utc(2026, 9, 1),
      );

  test('builder expands selectors and emits deterministic records', () {
    final output = build();

    expect(output['schema_version'], 1);
    expect(output['generated_at'], '2026-09-01T00:00:00.000Z');
    final pools = output['pools']! as List<Object?>;
    final first = pools.first as Map<String, Object?>;
    // DD -> [1,2], ctype -> [1,2], name chain -> [1,2], direct [3],
    // then exclusions remove only the first 3 and first 1.
    expect(first['ship_ids'], [2, 1, 2, 1, 2]);
    expect(first['pool_key'], '水雷系-测试#2');
    expect(jsonEncode(output), jsonEncode(build()));
  });

  test('builder includes compact equipment and secretary indexes', () {
    final output = build();
    final equipment = output['equipment']! as List<Object?>;
    expect(equipment, hasLength(2));
    expect(
      equipment.first,
      containsPair('minimum_resources', [10, 20, 30, 40]),
    );

    final secretaries = output['secretaries']! as List<Object?>;
    expect(
      secretaries,
      contains(
        allOf(containsPair('ship_id', 1), containsPair('pool_key', '水雷系-测试#2')),
      ),
    );
  });

  test('builder rejects malformed or unresolved source data', () {
    expect(() => build(pools: const []), throwsA(isA<FormatException>()));
    expect(
      () => build(
        pools: const [
          {
            '开发池名称': '水雷系-测试',
            '开发池ID': 2,
            '出货率': {'999': 1},
          },
        ],
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => build(
        pools: const [
          {
            '开发池名称': '水雷系-测试',
            '开发池ID': 2,
            '最低资源': [10],
            '出货率': {'7': 1},
          },
        ],
      ),
      throwsA(isA<FormatException>()),
    );
  });
}
