import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/composition_image_page.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';

import 'fixtures/composition_image_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    for (final family in [
      'HarmonyOS_Sans_SC',
      'HarmonyOS_Sans_TC',
      'HarmonyOS_Sans',
    ]) {
      await (FontLoader(
        family,
      )..addFont(rootBundle.load('assets/fonts/$family.ttf'))).load();
    }
  });

  testWidgets(
    'phone preview exports all four fleets and three bases beyond the viewport',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final viewportKey = GlobalKey();
      await tester.pumpWidget(_app(compositionImageFixture(), viewportKey));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final card = find.byKey(const Key('composition-image-card'));
      final textElements = tester.elementList(
        find.descendant(of: card, matching: find.byType(Text)),
      );
      expect(textElements, isNotEmpty);
      for (final element in textElements) {
        final text = element.widget as Text;
        final inherited = DefaultTextStyle.of(element).style;
        expect(
          text.style?.fontFamily ?? inherited.fontFamily,
          'HarmonyOS_Sans_SC',
        );
        expect(text.style?.fontFamilyFallback ?? inherited.fontFamilyFallback, [
          'HarmonyOS_Sans_TC',
          'HarmonyOS_Sans',
        ]);
      }
      final capture = find
          .ancestor(of: card, matching: find.byType(RepaintBoundary))
          .first;
      final boundary = tester.renderObject<RenderRepaintBoundary>(capture);
      expect(boundary.size.width, 1200);
      expect(boundary.size.height, greaterThan(2400));
      await tester.runAsync(() async {
        final bytes = await captureCompositionPng(boundary);
        expect(bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        expect(frame.image.width, greaterThan(1000));
        expect(frame.image.height, greaterThan(2400));
        expect(frame.image.width * frame.image.height, lessThan(12100000));
        // The bottom footer is painted even though it lies outside the phone viewport.
        final rgba = (await frame.image.toByteData())!;
        final pixel = ((frame.image.height - 10) * frame.image.width + 10) * 4;
        expect(rgba.getUint8(pixel + 3), 255);
        final output = Platform.environment['COMPOSITION_PREVIEW_DIR'];
        if (output != null) {
          await Directory(output).create(recursive: true);
          await File('$output/composition-full.png').writeAsBytes(bytes);
          final viewport =
              viewportKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          await File(
            '$output/composition-phone.png',
          ).writeAsBytes(await captureCompositionPng(viewport));
        }
        frame.image.dispose();
        codec.dispose();
      });
      final output = Platform.environment['COMPOSITION_PREVIEW_DIR'];
      if (output != null) {
        final fixture = compositionImageFixture();
        tester.view.physicalSize = const Size(1280, 800);
        await tester.pumpWidget(
          _app(
            fixture.copyWith(
              fleets: [
                Fleet(
                  id: 1,
                  name: '第一舰队 · 编成示例',
                  shipIds: fixture.fleets.first.shipIds.take(6).toList(),
                ),
              ],
            ),
            viewportKey,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final viewport =
              viewportKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          await File(
            '$output/composition-tablet.png',
          ).writeAsBytes(await captureCompositionPng(viewport));
          final cardBoundary = tester.renderObject<RenderRepaintBoundary>(
            find
                .ancestor(
                  of: find.byKey(const Key('composition-image-card')),
                  matching: find.byType(RepaintBoundary),
                )
                .first,
          );
          await File(
            '$output/composition-sample.png',
          ).writeAsBytes(await captureCompositionPng(cardBoundary));
        });
      }
    },
  );
}

Widget _app(GameState state, GlobalKey viewportKey) => MaterialApp(
  theme: ThemeData(
    brightness: Brightness.dark,
    colorSchemeSeed: const Color(0xffd4a85f),
    fontFamily: 'HarmonyOS_Sans_SC',
    fontFamilyFallback: const ['HarmonyOS_Sans_TC', 'HarmonyOS_Sans'],
    scaffoldBackgroundColor: const Color(0xff0a1823),
  ),
  locale: const Locale('zh'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: RepaintBoundary(
    key: viewportKey,
    child: Scaffold(
      body: CompositionImagePage(state: state, initiallyShowSaved: false),
    ),
  ),
);
