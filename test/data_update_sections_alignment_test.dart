import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/battle/fcd_map_controller.dart';
import 'package:yahagi_kancolle_browser/src/battle/fcd_map_dataset.dart';
import 'package:yahagi_kancolle_browser/src/battle/fcd_map_update_service.dart';
import 'package:yahagi_kancolle_browser/src/improvement/improvement_dataset.dart';
import 'package:yahagi_kancolle_browser/src/improvement/improvement_dataset_update_section.dart';
import 'package:yahagi_kancolle_browser/src/improvement/improvement_planner_controller.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_catalog_controller.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_catalog_dataset.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_catalog_update_service.dart';
import 'package:yahagi_kancolle_browser/src/settings/fcd_map_update_section.dart';
import 'package:yahagi_kancolle_browser/src/settings/quest_catalog_update_section.dart';

void main() {
  testWidgets('all data update titles and metadata share the section left edge', (
    tester,
  ) async {
    final fcd = FcdMapController(
      dataset: FcdMapDataset.parse(
        '{"meta":{"name":"map","version":"2026/08/01/01"},"data":{"1-1":{"route":{"1":["A","B"]}}}}',
        minimumMapCount: 1,
      ),
      updater: const _FcdUpdater(),
    );
    final quests = QuestCatalogController(
      dataset: _questDataset(),
      updater: const _QuestUpdater(),
    );
    final improvements = ImprovementPlannerController(
      dataset: const ImprovementDataset(
        version: ImprovementDatasetVersion(
          dataVersion: '2026-08-01',
          commitSha: 'test',
        ),
        entries: <ImprovementEntry>[],
      ),
    );
    addTearDown(fcd.dispose);
    addTearDown(quests.dispose);
    addTearDown(improvements.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Text('数据更新'),
              ),
              ListTileTheme(
                data: const ListTileThemeData(
                  contentPadding: EdgeInsets.symmetric(horizontal: 16),
                  minLeadingWidth: 0,
                ),
                child: Column(
                  children: [
                    FcdMapUpdateSection(controller: fcd),
                    QuestCatalogUpdateSection(controller: quests),
                    ImprovementDatasetUpdateSection(controller: improvements),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final sectionDx = tester.getTopLeft(find.text('数据更新')).dx;
    final titleFinders = <Finder>[
      find.text('未卜先知数据'),
      find.text('任务资料'),
      find.text('改修规划资料'),
    ];
    final titleDx = <double>[
      for (final finder in titleFinders) tester.getTopLeft(finder).dx,
    ];
    expect(titleDx.toSet(), hasLength(1));
    expect(titleDx.first, sectionDx);

    for (final titleFinder in titleFinders) {
      final tileFinder = find.ancestor(
        of: titleFinder,
        matching: find.byType(ListTile),
      );
      final tile = tester.widget<ListTile>(tileFinder);
      expect(tile.contentPadding, const EdgeInsets.only(left: 4, right: 16));
      expect(tile.minLeadingWidth, 0);
      expect(tile.horizontalTitleGap, 0);

      final subtitleTexts = find.descendant(
        of: tileFinder,
        matching: find.byType(Text),
      );
      expect(tester.getTopLeft(subtitleTexts.at(1)).dx, sectionDx);
    }
  });
}

QuestCatalogDataset _questDataset() {
  final raw = jsonEncode(<String, Object?>{
    '1': <String, Object?>{'code': 'A1', 'name': 'test', 'desc': ''},
  });
  return QuestCatalogDataset.parse(
    rawJson: raw,
    version: QuestCatalogVersion(
      committedAt: DateTime.utc(2026, 8, 1),
      commitSha: '1'.padLeft(40, '0'),
      sha256: sha256.convert(utf8.encode(raw)).toString(),
    ),
    minimumQuestCount: 1,
  );
}

final class _FcdUpdater implements FcdMapUpdateClient {
  const _FcdUpdater();

  @override
  Future<FcdMapUpdateResult> checkAndUpdate({required FcdMapDataset current}) =>
      Future.value(FcdMapUpToDate(current.version));
}

final class _QuestUpdater implements QuestCatalogUpdateClient {
  const _QuestUpdater();

  @override
  Future<QuestCatalogUpdateResult> checkAndUpdate({
    required QuestCatalogDataset current,
  }) => Future.value(QuestCatalogUpToDate(current.version));
}
