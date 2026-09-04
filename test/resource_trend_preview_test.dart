// Opt-in real Flutter renders, deliberately kept out of the ordinary test run.
// RESOURCE_TREND_PREVIEWS=1 flutter test test/resource_trend_preview_test.dart --update-goldens
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/fleet/resource_trend_page.dart';

void main() {
  if (Platform.environment['RESOURCE_TREND_PREVIEWS'] != '1') return;
  setUpAll(() async {
    await (FontLoader('HarmonyOS_Sans_SC')..addFont(
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
  final now = DateTime.parse('2026-09-05T18:30:00+09:00');
  final start = DateTime.parse('2026-09-05T00:00:00+09:00');
  const resources = {
    'fuel': (186420, 2480),
    'ammo': (172650, -1760),
    'steel': (241300, 920),
    'bauxite': (98740, 1210),
    'blowtorch': (482, 3),
    'bucket': (1268, -12),
    'devmat': (1832, 18),
    'screw': (146, -6),
  };
  final rows = List.generate(37, (i) {
    final t = i / 36;
    return <String, dynamic>{
      'timestamp': start
          .add(Duration(seconds: (now.difference(start).inSeconds * t).round()))
          .millisecondsSinceEpoch,
      for (final r in resources.entries)
        r.key:
            (r.value.$1 -
                    r.value.$2 +
                    r.value.$2 * t +
                    (math.sin(t * 18) + math.sin(t * 45) * .32) *
                        math.sin(math.pi * t) *
                        math.max(r.value.$2.abs() * .8, r.value.$1 * .002))
                .round(),
    };
  });
  for (final size in [
    const Size(390, 844),
    const Size(720, 840),
    const Size(840, 720),
    const Size(844, 390),
    const Size(768, 1024),
    const Size(1180, 820),
  ]) {
    testWidgets('actual resource page at $size', (tester) async {
      SharedPreferences.setMockInitialValues({});
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
          home: Scaffold(
            backgroundColor: const Color(0xff091b28),
            body: RepaintBoundary(
              key: const ValueKey('preview'),
              child: ResourceTrendPage(
                now: () => now,
                loadLogs: (_) async => rows,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final prefix =
          '../.codex-work/resource-previews/${size.width.toInt()}x${size.height.toInt()}';
      await expectLater(
        find.byKey(const ValueKey('preview')),
        matchesGoldenFile('$prefix.png'),
      );
      if (size.width == 390) {
        await tester.ensureVisible(
          find.byKey(const ValueKey('resource-trend-expand')),
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byKey(const ValueKey('preview')),
          matchesGoldenFile('$prefix-chart.png'),
        );
      }
      await tester.ensureVisible(
        find.byKey(const ValueKey('resource-trend-expand')),
      );
      await tester.tap(find.byKey(const ValueKey('resource-trend-expand')));
      await tester.pumpAndSettle();
      final canvas = find.byKey(const ValueKey('resource-trend-canvas')).last;
      await tester.tapAt(tester.getCenter(canvas));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(Dialog),
        matchesGoldenFile('$prefix-expanded.png'),
      );
      await tester.tap(find.byTooltip('关闭'));
      await tester.pumpAndSettle();
    });
  }
}
