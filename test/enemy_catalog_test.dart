import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/enemy_catalog.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/sortie_enemy_details.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/sortie_map_models.dart';

void main() {
  test('parses configurations and resolves a precise sortie alias', () {
    final catalog = EnemyCatalogData.fromJsonString(enemyCatalogFixture);

    final details = catalog.resolve(
      const EnemyShipEntry(id: 1523, nameJa: '軽母ヌ級elite(艦載機黒)', nameZh: null),
    );

    expect(details, isNotNull);
    expect(details!.id, 1777);
    expect(details.hp, 48);
    expect(details.firepower?.base, 10);
    expect(details.firepower?.equipped, 18);
    expect(details.equipment.single.name, '5inch単装砲');
    expect(details.equipment.single.stats?.firepower, 1);
  });

  test('rejects aliases that point to a missing configuration', () {
    expect(
      () => EnemyCatalogData.fromJsonString(
        enemyCatalogFixture.replaceFirst('1777@black', 'missing'),
      ),
      throwsFormatException,
    );
  });

  test('does not guess a configuration when the precise alias is missing', () {
    final catalog = EnemyCatalogData.fromJsonString(enemyCatalogFixture);

    expect(
      catalog.resolve(
        const EnemyShipEntry(id: 1777, nameJa: '未知の新バリアント', nameZh: null),
      ),
      isNull,
    );
  });

  test(
    'rejects invalid version, timestamp, collections, and equipment fields',
    () {
      final invalid = <String>[
        enemyCatalogFixture.replaceFirst('"revision": 7', '"revision": 0'),
        enemyCatalogFixture.replaceFirst(
          '2026-09-20T00:00:00Z',
          'not-a-timestamp',
        ),
        enemyCatalogFixture.replaceFirst(
          '"ships": [{',
          '"ships": [], "unused": [{',
        ),
        enemyCatalogFixture.replaceFirst('"matched": true', '"matched": "yes"'),
        enemyCatalogFixture.replaceFirst(
          '"stats": {"key"',
          '"stats": "broken", "unusedStats": {"key"',
        ),
      ];

      for (final raw in invalid) {
        expect(
          () => EnemyCatalogData.fromJsonString(raw),
          throwsFormatException,
        );
      }
    },
  );

  testWidgets('details card shows the resolved configuration id', (
    tester,
  ) async {
    final catalog = EnemyCatalogData.fromJsonString(enemyCatalogFixture);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showSortieEnemyDetails(
              context,
              entry: const EnemyShipEntry(
                id: 1523,
                nameJa: '軽母ヌ級elite(艦載機黒)',
                nameZh: null,
              ),
              state: const GameState(),
              catalog: catalog,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('ID 1777'), findsOneWidget);
    expect(find.text('軽母ヌ級elite(艦載機黒)'), findsOneWidget);
  });
}

const enemyCatalogFixture = r'''
{
  "schemaVersion": 1,
  "dataVersion": "2026.09.20",
  "revision": 7,
  "publishedAt": "2026-09-20T00:00:00Z",
  "source": "test",
  "ships": [{
    "key": "1777@black",
    "id": 1777,
    "name": "軽母ヌ級 elite",
    "shipType": "軽空母",
    "level": 1,
    "hp": 48,
    "firepower": {"base": 10, "equipped": 18},
    "torpedo": null,
    "antiAir": {"base": 20},
    "armor": {"base": 25},
    "evasion": 10,
    "antiSub": 0,
    "search": 10,
    "luck": 1,
    "aircraftCapacity": 18,
    "speed": "低速",
    "range": "中",
    "nightCutIn": null,
    "note": "艦載機黒",
    "detailsUrl": null,
    "equipment": [{
      "slot": 1,
      "key": "5inch",
      "name": "5inch単装砲",
      "type": "小口径主砲",
      "matched": true,
      "stats": {"key":"5inch","name":"5inch単装砲","type":"小口径主砲","firepower":1}
    }]
  }],
  "aliases": {"1523|軽母ヌ級elite(艦載機黒)": "1777@black"},
  "quality": {"shipCount":1,"mapAliasCount":1}
}
''';
