import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_fullscreen_controls.dart';

void main() {
  const channel = MethodChannel('app.yahagi.kancollebrowser/game_fullscreen');

  Future<void> nativeEvent(
    WidgetTester tester,
    String method, [
    Object? args,
  ]) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(MethodCall(method, args)),
      (_) {},
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'native overlay receives safe bounds, saves drag, exits and hides',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final configs = <Map>[];
      final active = ValueNotifier(true);
      addTearDown(active.dispose);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        configs.add(call.arguments as Map);
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<bool>(
            valueListenable: active,
            builder: (context, value, child) => GameFullscreenControls(
              active: value,
              useNativeOverlay: true,
              onExit: () => active.value = false,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(configs.last['active'], true);
      expect(configs.last['width'], 34);
      expect(configs.last['height'], 34);
      expect(
        find.byKey(const Key('game-exit-fullscreen')),
        findsNothing,
        reason: 'Flutter controls would be covered by an Activity WebView',
      );
      await nativeEvent(tester, 'moved', {'x': -200.0, 'y': 300.0});
      expect(active.value, true);
      expect(configs.last['x'], configs.last['minX']);
      expect(
        (await SharedPreferences.getInstance())
            .getStringList('game_fullscreen_exit_position')!
            .first,
        '0.0',
      );
      await nativeEvent(tester, 'exit');
      expect(
        find.byKey(const Key('fullscreen-exit-confirm-dialog')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('fullscreen-exit-confirm')));
      await tester.pumpAndSettle();
      expect(active.value, false);
      expect(configs.last['active'], false);
      final callsAfterExit = configs.length;
      await nativeEvent(tester, 'moved', {'x': 200.0, 'y': 300.0});
      expect(
        configs.length,
        callsAfterExit,
        reason: 'ignore late drag events after exiting',
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(configs.last['active'], false);
    },
  );

  testWidgets(
    'unavailable native exit control immediately restores normal mode',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final active = ValueNotifier(true);
      addTearDown(active.dispose);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        throw PlatformException(code: 'fullscreen_control_unavailable');
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<bool>(
            valueListenable: active,
            builder: (context, value, child) => GameFullscreenControls(
              active: value,
              useNativeOverlay: true,
              onExit: () => active.value = false,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(active.value, false);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  test('exit target stays within safe edges and prefers letterboxing', () {
    for (final size in [
      const Size(1200, 700),
      const Size(400, 900),
      const Size(1800, 700),
    ]) {
      const insets = EdgeInsets.only(left: 30, right: 20, bottom: 24);
      final area = fullscreenExitArea(size, insets);
      final rect = fullscreenExitRect(area, null);
      expect(rect.width, greaterThanOrEqualTo(34));
      expect(rect.height, greaterThanOrEqualTo(34));
      expect(rect.left, greaterThanOrEqualTo(insets.left));
      expect(rect.right, lessThanOrEqualTo(size.width - insets.right));
      expect(rect.bottom, lessThanOrEqualTo(size.height - insets.bottom));
      final fitted = applyBoxFit(
        BoxFit.contain,
        const Size(1200, 720),
        Size(size.width - 50, size.height - 24),
      ).destination;
      final game = Alignment.center.inscribe(
        fitted,
        Rect.fromLTWH(30, 0, size.width - 50, size.height - 24),
      );
      if (size.height > size.width || size.width == 1800) {
        expect(rect.overlaps(game), isFalse);
      }
      final dragged = fullscreenExitRect(
        area,
        snapFullscreenExit(area, const Offset(-100, 9999)),
      );
      expect(dragged.left, inInclusiveRange(area.left, area.right));
      expect(dragged.top, inInclusiveRange(area.top, area.bottom));
      expect(dragged.bottom, lessThanOrEqualTo(area.bottom + 34));
    }
  });

  testWidgets(
    'dragging does not exit, position survives remount and rotation, tap exits',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 700);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      var exits = 0;
      Widget app() => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: GameFullscreenControls(
          active: true,
          onExit: () => exits++,
          child: const SizedBox.expand(),
        ),
      );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      final button = find.byKey(const Key('game-exit-fullscreen'));
      await tester.drag(button, const Offset(-2000, 400));
      await tester.pumpAndSettle();
      expect(exits, 0);
      final position = tester.getTopLeft(button);
      expect(position.dx, 0.0);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(button), position);
      tester.view.physicalSize = const Size(400, 900);
      await tester.pumpAndSettle();
      expect(tester.getRect(button).right, lessThanOrEqualTo(400));
      expect(tester.getRect(button).bottom, lessThanOrEqualTo(900));
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('fullscreen-exit-confirm-dialog')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('fullscreen-exit-confirm')));
      await tester.pumpAndSettle();
      expect(exits, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'exit button respects notch viewPadding and keyboard viewInsets, clamps drag safely and remains clickable',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      const windowSize = Size(412, 800);
      const safePadding = EdgeInsets.fromLTRB(48, 36, 40, 28);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = windowSize;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      var exits = 0;
      final keyboardNotifier = ValueNotifier<double>(0.0);
      addTearDown(keyboardNotifier.dispose);

      Widget buildTestHarness() => ValueListenableBuilder<double>(
        valueListenable: keyboardNotifier,
        builder: (context, keyboardHeight, _) => MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: MediaQuery(
            data: MediaQueryData(
              size: windowSize,
              viewPadding: safePadding,
              viewInsets: EdgeInsets.only(bottom: keyboardHeight),
            ),
            child: GameFullscreenControls(
              active: true,
              onExit: () => exits++,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );

      await tester.pumpWidget(buildTestHarness());
      await tester.pumpAndSettle();

      final button = find.byKey(const Key('game-exit-fullscreen'));
      expect(button, findsOneWidget);

      // Initial position must be inside safe padding bounds
      var buttonRect = tester.getRect(button);
      expect(buttonRect.left, greaterThanOrEqualTo(safePadding.left));
      expect(buttonRect.top, greaterThanOrEqualTo(safePadding.top));
      expect(
        buttonRect.right,
        lessThanOrEqualTo(windowSize.width - safePadding.right),
      );
      expect(
        buttonRect.bottom,
        lessThanOrEqualTo(windowSize.height - safePadding.bottom),
      );

      // Drag button all the way towards top-left (attempting to enter notch area)
      await tester.drag(button, const Offset(-2000, -2000));
      await tester.pumpAndSettle();
      buttonRect = tester.getRect(button);
      expect(
        buttonRect.left,
        closeTo(safePadding.left, 0.01),
        reason: 'Must clamp to safe left',
      );
      expect(
        buttonRect.top,
        closeTo(safePadding.top, 0.01),
        reason: 'Must clamp to safe top',
      );

      // Drag button all the way towards bottom-right
      await tester.drag(button, const Offset(2000, 2000));
      await tester.pumpAndSettle();
      buttonRect = tester.getRect(button);
      expect(
        buttonRect.right,
        closeTo(windowSize.width - safePadding.right, 0.01),
      );
      expect(
        buttonRect.bottom,
        closeTo(windowSize.height - safePadding.bottom, 0.01),
      );

      // Simulate soft keyboard (IME) popup in split-screen: 320dp height occupied by keyboard
      keyboardNotifier.value = 320.0;
      await tester.pumpAndSettle();
      buttonRect = tester.getRect(button);

      // Button must NOT be obscured by keyboard; must be clamped above the keyboard
      expect(
        buttonRect.bottom,
        lessThanOrEqualTo(windowSize.height - 320.0),
        reason: 'Button must stay above soft keyboard',
      );
      expect(buttonRect.left, greaterThanOrEqualTo(safePadding.left));
      expect(
        buttonRect.right,
        lessThanOrEqualTo(windowSize.width - safePadding.right),
      );

      // Click button while keyboard is visible to verify interaction
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('fullscreen-exit-confirm-dialog')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('fullscreen-exit-confirm')));
      await tester.pumpAndSettle();
      expect(exits, 1);

      // Keyboard retracts
      keyboardNotifier.value = 0.0;
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    },
  );
}
