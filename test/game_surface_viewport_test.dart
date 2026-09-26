import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_surface_viewport.dart';
import 'package:yahagi_kancolle_browser/src/settings/display_mode_store.dart';

void main() {
  group('GameSurfaceViewport decision logic', () {
    test('uses width-priority for vertical layout and mobile split-screen', () {
      // Mobile portrait full-screen (412 x 915)
      expect(
        GameSurfaceViewport.shouldUseWidthPriority(
          width: 412,
          height: 915,
          isLandscape: false,
        ),
        isTrue,
      );

      // Split-screen window on phone (456 x 326, user reported issue)
      expect(
        GameSurfaceViewport.shouldUseWidthPriority(
          width: 456,
          height: 326,
          isLandscape: true, // Even if aspect ratio exceeds 1.35
          fullscreen: true,
        ),
        isTrue,
      );

      // Compact split-screen window (412 x 300)
      expect(
        GameSurfaceViewport.shouldUseWidthPriority(
          width: 412,
          height: 300,
          isLandscape: false,
        ),
        isTrue,
      );

      // Forced portrait mode
      expect(
        GameSurfaceViewport.shouldUseWidthPriority(
          width: 1280,
          height: 800,
          isLandscape: true,
          displayMode: DisplayMode.portrait,
        ),
        isTrue,
      );

      // Foldable unfolded split-screen (768 x 380, 800 x 400, 1024 x 500)
      for (final size in [
        const Size(768, 380),
        const Size(800, 400),
        const Size(1024, 500),
      ]) {
        expect(
          GameSurfaceViewport.shouldUseWidthPriority(
            width: size.width,
            height: size.height,
            isLandscape: true,
            displayMode: DisplayMode.auto,
          ),
          isTrue,
          reason:
              'Foldable split-screen $size must use width-priority in auto mode',
        );
        expect(
          GameSurfaceViewport.shouldUseWidthPriority(
            width: size.width,
            height: size.height,
            isLandscape: true,
            displayMode: DisplayMode.landscape,
          ),
          isTrue,
          reason:
              'Foldable split-screen $size must use width-priority in landscape mode',
        );
      }
    });

    test('uses contain mode for widescreen landscape displays', () {
      // Standard phone landscape gaming (915 x 412)
      expect(
        GameSurfaceViewport.shouldUseWidthPriority(
          width: 915,
          height: 412,
          isLandscape: true,
          displayMode: DisplayMode.auto,
        ),
        isFalse,
      );

      // Tablet / Desktop widescreen (1280 x 800)
      expect(
        GameSurfaceViewport.shouldUseWidthPriority(
          width: 1280,
          height: 800,
          isLandscape: true,
          displayMode: DisplayMode.auto,
        ),
        isFalse,
      );
    });
  });

  group('GameSurfaceViewport geometry calculation', () {
    test(
      'width-priority rect occupies 100% width with 0 horizontal borders',
      () {
        const containerWidth = 456.0;
        const containerHeight = 326.0;
        const ratio = 1200.0 / 720.0;
        const padding = EdgeInsets.only(top: 48, bottom: 16);

        final rect = GameSurfaceViewport.computeWidthPriorityGameRect(
          containerWidth: containerWidth,
          containerHeight: containerHeight,
          aspectRatio: ratio,
          padding: padding,
        );

        // Zero horizontal black borders: starts at 0 and spans entire width
        expect(rect.left, 0.0);
        expect(rect.width, containerWidth);
        expect(rect.right, containerWidth);

        // Aspect ratio strictly preserved
        expect(rect.width / rect.height, closeTo(ratio, 0.0001));

        // Required height for 456 is 273.6
        expect(rect.height, closeTo(273.6, 0.01));

        // Centered within safe height: safe height = 326 - 64 = 262.
        // Since 262 < 273.6, centered in container: (326 - 273.6) / 2 = 26.2
        expect(rect.top, closeTo((containerHeight - 273.6) / 2, 0.01));
      },
    );

    test('centers within safe area when safe height is sufficient', () {
      const containerWidth = 400.0;
      const containerHeight = 400.0;
      const ratio = 1200.0 / 720.0;
      const padding = EdgeInsets.only(top: 40, bottom: 20);

      final rect = GameSurfaceViewport.computeWidthPriorityGameRect(
        containerWidth: containerWidth,
        containerHeight: containerHeight,
        aspectRatio: ratio,
        padding: padding,
      );

      expect(rect.left, 0.0);
      expect(rect.width, containerWidth);
      expect(rect.height, closeTo(400.0 * 720 / 1200, 0.01)); // 240.0

      // Safe height = 400 - 60 = 340. 340 >= 240.
      // topOffset = 40 + (340 - 240) / 2 = 90.0
      expect(rect.top, closeTo(90.0, 0.01));
      expect(rect.bottom, closeTo(330.0, 0.01));
      // Completely clears safe insets:
      expect(rect.top, greaterThanOrEqualTo(padding.top));
      expect(rect.bottom, lessThanOrEqualTo(containerHeight - padding.bottom));
    });
  });

  group('GameSurfaceViewport widget rendering', () {
    testWidgets(
      'renders 100% width with 0 horizontal borders in split-screen fullscreen',
      (tester) async {
        const windowSize = Size(456, 326);
        const padding = EdgeInsets.only(top: 48, bottom: 16);
        tester.view.physicalSize = windowSize;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(size: windowSize, viewPadding: padding),
            child: const Directionality(
              textDirection: TextDirection.ltr,
              child: GameSurfaceViewport(
                aspectRatio: 1200 / 720,
                fullscreen: true,
                isLandscape: true, // Split-screen window
                child: SizedBox.expand(key: Key('test-game-surface')),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final gameRect = tester.getRect(
          find.byKey(const Key('test-game-surface')),
        );

        // Width must be exactly 456.0 with zero horizontal borders
        expect(gameRect.left, 0.0);
        expect(gameRect.width, 456.0);
        expect(gameRect.right, 456.0);

        // Aspect ratio must be exact 1200:720
        expect(gameRect.width / gameRect.height, closeTo(1200 / 720, 0.001));
      },
    );

    testWidgets(
      'renders contain mode in normal widescreen landscape without cropping',
      (tester) async {
        const windowSize = Size(915, 412);
        const padding = EdgeInsets.only(left: 48, right: 16);
        tester.view.physicalSize = windowSize;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(size: windowSize, viewPadding: padding),
            child: const Directionality(
              textDirection: TextDirection.ltr,
              child: GameSurfaceViewport(
                aspectRatio: 1200 / 720,
                fullscreen: true,
                isLandscape: true, // Standard widescreen landscape
                child: SizedBox.expand(key: Key('test-game-surface')),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final gameRect = tester.getRect(
          find.byKey(const Key('test-game-surface')),
        );

        // Standard contain behavior: aspect ratio preserved, within bounds
        expect(gameRect.width / gameRect.height, closeTo(1200 / 720, 0.001));
        expect(gameRect.top, greaterThanOrEqualTo(0.0));
        expect(gameRect.bottom, lessThanOrEqualTo(412.0));
        expect(gameRect.left, greaterThanOrEqualTo(padding.left));
      },
    );

    testWidgets(
      'dragging split divider (height varies from 200 to 600) keeps 100% width and 0 horizontal borders',
      (tester) async {
        const windowWidth = 456.0;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // Test various split-screen heights as the user drags the divider
        for (final height in [200.0, 250.0, 273.6, 326.0, 450.0, 600.0]) {
          final windowSize = Size(windowWidth, height);
          tester.view.physicalSize = windowSize;

          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(
                size: windowSize,
                viewPadding: const EdgeInsets.only(top: 48, bottom: 16),
              ),
              child: const Directionality(
                textDirection: TextDirection.ltr,
                child: GameSurfaceViewport(
                  aspectRatio: 1200 / 720,
                  fullscreen: true,
                  isLandscape: true,
                  child: SizedBox.expand(key: Key('test-game-surface')),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final gameRect = tester.getRect(
            find.byKey(const Key('test-game-surface')),
          );

          // Game width MUST always be 100% of container width (no left/right black borders)
          expect(gameRect.left, 0.0);
          expect(gameRect.width, windowWidth);
          expect(gameRect.right, windowWidth);

          // Aspect ratio MUST always be exact 1200:720 (no distortion/stretching)
          expect(gameRect.width / gameRect.height, closeTo(1200 / 720, 0.001));
        }
      },
    );

    testWidgets(
      'split-screen: toggling forced portrait, landscape, and auto maintains 100% width and element identity',
      (tester) async {
        const windowSize = Size(456, 326);
        const padding = EdgeInsets.only(top: 48, bottom: 16);
        tester.view.physicalSize = windowSize;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        for (final mode in [
          DisplayMode.auto,
          DisplayMode.portrait,
          DisplayMode.landscape,
          DisplayMode.portrait,
          DisplayMode.auto,
        ]) {
          await tester.pumpWidget(
            MediaQuery(
              data: const MediaQueryData(
                size: windowSize,
                viewPadding: padding,
              ),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: GameSurfaceViewport(
                  aspectRatio: 1200 / 720,
                  fullscreen: true,
                  isLandscape: mode == DisplayMode.landscape,
                  displayMode: mode,
                  child: const SizedBox.expand(key: Key('test-game-surface')),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final gameRect = tester.getRect(
            find.byKey(const Key('test-game-surface')),
          );

          // Game width MUST always be 100% of container width (no left/right black borders)
          expect(gameRect.left, 0.0);
          expect(gameRect.width, 456.0);
          expect(gameRect.right, 456.0);

          // Aspect ratio MUST always be exact 1200:720
          expect(gameRect.width / gameRect.height, closeTo(1200 / 720, 0.001));
        }
      },
    );

    testWidgets(
      'foldable unfolded split-screen (768x380, 800x400, 1024x500) renders 100% width with zero horizontal black borders',
      (tester) async {
        for (final size in [
          const Size(768, 380),
          const Size(800, 400),
          const Size(1024, 500),
        ]) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(size: size),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: GameSurfaceViewport(
                  aspectRatio: 1200 / 720,
                  fullscreen: true,
                  isLandscape: true,
                  displayMode: DisplayMode.auto,
                  child: const SizedBox.expand(key: Key('test-game-surface')),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final gameRect = tester.getRect(
            find.byKey(const Key('test-game-surface')),
          );

          // Zero horizontal pillarboxing: spans full width exactly from left 0 to size.width
          expect(gameRect.left, 0.0, reason: 'Must align to left 0 for $size');
          expect(
            gameRect.width,
            size.width,
            reason: 'Must occupy 100% width for $size',
          );
          expect(
            gameRect.right,
            size.width,
            reason: 'Must reach right edge for $size',
          );

          // Aspect ratio strictly preserved at 1200:720 with zero distortion
          expect(
            gameRect.width / gameRect.height,
            closeTo(1200 / 720, 0.001),
            reason: 'Aspect ratio must be exactly 1200:720 for $size',
          );
        }
      },
    );

    testWidgets(
      'high-DPI float subpixels (dpr 2.75, 3.5) preserve 100% width and exact aspect ratio without pixel gaps',
      (tester) async {
        for (final dpr in [2.75, 3.5]) {
          // Floating point logical sizes resulting from physical pixel rounding
          const logicalWidth = 411.4285714;
          const logicalHeight = 326.1234567;
          final physicalSize = Size(logicalWidth * dpr, logicalHeight * dpr);

          tester.view.physicalSize = physicalSize;
          tester.view.devicePixelRatio = dpr;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(
                size: const Size(logicalWidth, logicalHeight),
                devicePixelRatio: dpr,
              ),
              child: const Directionality(
                textDirection: TextDirection.ltr,
                child: GameSurfaceViewport(
                  aspectRatio: 1200 / 720,
                  fullscreen: true,
                  isLandscape: true,
                  child: SizedBox.expand(key: Key('test-game-surface')),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final gameRect = tester.getRect(
            find.byKey(const Key('test-game-surface')),
          );

          expect(gameRect.left, 0.0);
          expect(gameRect.width, closeTo(logicalWidth, 0.001));
          expect(gameRect.right, closeTo(logicalWidth, 0.001));
          expect(gameRect.width / gameRect.height, closeTo(1200 / 720, 0.001));
        }
      },
    );
  });
}
