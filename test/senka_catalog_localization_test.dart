import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/senka/senka_catalog.dart';
import 'package:yahagi_kancolle_browser/src/senka/senka_catalog_localization.dart';

void main() {
  const ja = Locale('ja');
  const hant = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');

  test('Japanese quest labels match bundled original titles by ID', () {
    final catalog =
        jsonDecode(File('assets/data/quests-scn.json').readAsStringSync())
            as Map<String, dynamic>;
    for (final item in senkaQuestCatalog) {
      expect(senkaCatalogLabel(item, ja), catalog['${item.id}']['name']);
      if (item.code != null) {
        expect(senkaCatalogMatrixLabel(item, ja), startsWith('${item.code} '));
      }
    }
  });

  test(
    'all fixed catalog labels localize while the source model stays unchanged',
    () {
      for (final item in [...senkaEoCatalog, ...senkaQuestCatalog]) {
        expect(senkaCatalogLabel(item, const Locale('zh')), item.label);
        expect(
          senkaCatalogMatrixLabel(item, const Locale('zh')),
          item.matrixLabel,
        );
        expect(senkaCatalogLabel(item, hant), isNotEmpty);
        expect(senkaCatalogLabel(item, ja), isNotEmpty);
        if (item.category == SenkaRewardCategory.eo) {
          expect(senkaCatalogLabel(item, ja), contains(item.shortName));
          expect(senkaCatalogMatrixLabel(item, hant), item.matrixLabel);
        }
      }
      expect(senkaCatalogLabel(senkaEoById(35)!, ja), '北方AL海域（3-5）');
      expect(senkaCatalogLabel(senkaQuestById(854)!, hant), '戰果擴張任務！「Z作戰」前段作戰');
      expect(senkaCatalogMatrixLabel(senkaQuestById(854)!, ja), 'Bq2 Z作戦前');
      expect(senkaQuestById(854)!.shortName, 'Z作战前');
    },
  );
}
