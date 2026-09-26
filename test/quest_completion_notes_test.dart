import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_catalog.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_catalog_merger.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_catalog_dataset.dart';

void main() {
  test(
    'merge retains completion notes and cached entries use bundled fallback',
    () {
      final raw = mergeQuestCatalogJson(
        japaneseJson: jsonEncode({
          '977': {'code': 'B182', 'name': 'name', 'desc': 'desc'},
        }),
        relationJson: jsonEncode({
          '977': {'memo2': '4-5、5-3、7-2P2、6-5 各S胜一次'},
        }),
      );
      final entry = QuestCatalogEntry.fromJson(
        977,
        Map<String, Object?>.from(jsonDecode(raw)['977']),
      );
      expect(entry.memo, contains('7-2P2'));
      final cached = QuestCatalog([
        QuestCatalogEntry.fromJson(977, {'code': 'B182', 'memo2': ''}),
      ]);
      expect(
        cached
            .withTranslationFallbackFrom(QuestCatalog([entry]))
            .byGameId(977)!
            .memo,
        entry.memo,
      );
      expect(
        QuestCatalog([
          entry,
        ]).withTranslationFallbackFrom(cached).byGameId(977)!.memo,
        entry.memo,
      );
    },
  );
  test('bundled notes have valid metadata and Yamato map requirements', () {
    final data = QuestCatalogDataset.parse(
      rawJson: File('assets/data/quests-scn.json').readAsStringSync(),
      version: QuestCatalogVersion.fromJson(
        File('assets/data/quests-meta.json').readAsStringSync(),
      ),
    );
    expect(
      data.catalog.entries.where((e) => e.memo.isNotEmpty).length,
      greaterThanOrEqualTo(561),
    );
    final memo = data.catalog.byCode('B182')!.memo;
    for (final map in ['4-5', '5-3', '7-2P2', '6-5']) {
      expect(memo, contains(map));
    }
  });
}
