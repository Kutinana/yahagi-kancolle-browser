// Opt-in real Flutter renders: EXP_CALC_PREVIEWS=1 flutter test
// --no-pub test/exp_calc_preview_test.dart --update-goldens
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/exp_calc/exp_calc_page.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/sortie_map_models.dart';
import 'package:yahagi_kancolle_browser/src/widgets/top_notice.dart';
import 'exp_calc_page_test.dart' show FakeExpTrackerStore;

void main() {
  if (Platform.environment['EXP_CALC_PREVIEWS'] != '1') return;
  setUpAll(() async {
    await (FontLoader('HarmonyOS_Sans_SC')..addFont(
          Future.value(
            ByteData.sublistView(
              await File('assets/fonts/HarmonyOS_Sans_SC.ttf').readAsBytes(),
            ),
          ),
        ))
        .load();
    await (FontLoader('monospace')..addFont(
          Future.value(
            ByteData.sublistView(
              await File('assets/fonts/HarmonyOS_Sans_SC.ttf').readAsBytes(),
            ),
          ),
        ))
        .load();
    var directory = File(Platform.resolvedExecutable).parent;
    while (directory.parent.path != directory.path) {
      final font = File(
        '${directory.path}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      );
      if (font.existsSync()) {
        await (FontLoader('MaterialIcons')..addFont(
              Future.value(ByteData.sublistView(await font.readAsBytes())),
            ))
            .load();
        break;
      }
      directory = directory.parent;
    }
  });
  final catalog = SortieMapCatalogData.fromJsonString(
    File('assets/data/sortie_map_catalog.json').readAsStringSync(),
  );
  for (final size in [const Size(390, 1300), const Size(1120, 900)]) {
    testWidgets('experience calculator render $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData.dark().copyWith(
            textTheme: ThemeData.dark().textTheme.apply(
              fontFamily: 'HarmonyOS_Sans_SC',
            ),
          ),
          home: TopNoticeHost(
            child: RepaintBoundary(
              key: const Key('preview'),
              child: ExpCalcPage(
                state: const GameState(
                  memberId: 1,
                  masterShips: {
                    1: MasterShip(id: 1, name: '阿武隈改二', shipTypeId: 3),
                  },
                  ships: {
                    1: OwnedShip(
                      id: 1,
                      masterId: 1,
                      level: 145,
                      experience: 3549747,
                    ),
                  },
                ),
                store: FakeExpTrackerStore(),
                catalogLoader: () async => catalog,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byKey(const Key('exp-calc-add-button')));
      await tester.tap(find.byKey(const Key('exp-calc-add-button')));
      await tester.pumpAndSettle();
      for (final point in ['F', 'K', 'I']) {
        await tester.ensureVisible(
          find.byKey(const Key('exp-calc-add-node-button')),
        );
        await tester.tap(find.byKey(const Key('exp-calc-add-node-button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(Key('exp-calc-add-point-$point')));
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(find.byKey(const Key('exp-calc-add-button')));
      await tester.tap(find.byKey(const Key('exp-calc-add-button')));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(const Key('preview')),
        matchesGoldenFile(
          '../../outputs/exp-calculator-${size.width.toInt()}.png',
        ),
      );
      await tester.tap(find.byKey(const Key('exp-calc-ship-selector')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          '../../outputs/exp-calculator-ship-picker-${size.width.toInt()}.png',
        ),
      );
    });
  }
}
