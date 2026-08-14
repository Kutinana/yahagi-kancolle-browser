import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_browser_overlay.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_toolbar_controller.dart';

void main() {
  testWidgets(
    'hidden toolbar does not place a blocking layer over the game',
    (tester) async {
      final controller = GameToolbarController();
      controller.collapse();
      var taps = 0;

      await tester.pumpWidget(
        _TestApp(controller: controller, onGameTap: () => taps++),
      );

      expect(find.byKey(const Key('game-browser-overlay')), findsOneWidget);
      expect(find.byKey(const Key('game-toolbar-swipe-zone')), findsNothing);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);
      await tester.tapAt(const Offset(80, 20));
      expect(taps, 1);
      controller.dispose();
    },
  );

  testWidgets(
    'auto-hide toolbar does not register a competing pan recognizer over game',
    (tester) async {
      final controller = GameToolbarController();
      controller.collapse();

      await tester.pumpWidget(_TestApp(controller: controller));

      final inputSurface = tester.widget<Widget>(
        find.byKey(const Key('game-toolbar-gesture-surface')),
      );
      expect(inputSurface, isA<Listener>());
      controller.dispose();
    },
  );

  testWidgets('reveals only after a sufficiently long downward swipe', (
    tester,
  ) async {
    final controller = GameToolbarController();
    controller.collapse();

    await tester.pumpWidget(_TestApp(controller: controller));

    final game = find.byKey(const Key('game-toolbar-gesture-surface'));
    final topEdge = tester.getTopLeft(game) + const Offset(100, 8);
    await tester.dragFrom(topEdge, const Offset(0, 20));
    await tester.pumpAndSettle();
    expect(controller.isVisible, isFalse);

    await tester.dragFrom(topEdge, const Offset(0, 40));
    await tester.pumpAndSettle();
    expect(controller.isVisible, isTrue);
    controller.dispose();
  });

  testWidgets('downward drag inside game does not reveal auto-hide toolbar', (
    tester,
  ) async {
    final controller = GameToolbarController();
    controller.collapse();

    await tester.pumpWidget(_TestApp(controller: controller));
    final game = find.byKey(const Key('game-toolbar-gesture-surface'));
    final interior = tester.getCenter(game);

    await tester.dragFrom(interior, const Offset(0, 80));
    await tester.pumpAndSettle();

    expect(controller.isVisible, isFalse);
    controller.dispose();
  });

  testWidgets('rejects a swipe with excessive horizontal movement', (
    tester,
  ) async {
    final controller = GameToolbarController();
    controller.collapse();

    await tester.pumpWidget(_TestApp(controller: controller));

    await tester.drag(
      find.byKey(const Key('game-toolbar-gesture-surface')),
      const Offset(60, 40),
    );
    await tester.pumpAndSettle();

    expect(controller.isVisible, isFalse);
    controller.dispose();
  });

  testWidgets('overlay visibility never changes the game surface size', (
    tester,
  ) async {
    final controller = GameToolbarController();
    controller.collapse();

    await tester.pumpWidget(_TestApp(controller: controller));
    final gameFinder = find.byKey(const Key('fake-game-surface'));
    final hiddenSize = tester.getSize(gameFinder);

    controller.reveal();
    await tester.pumpAndSettle();

    expect(tester.getSize(gameFinder), hiddenSize);
    controller.dispose();
  });

  testWidgets('removes the hidden toolbar after its exit animation', (
    tester,
  ) async {
    final controller = GameToolbarController();

    await tester.pumpWidget(_TestApp(controller: controller));
    expect(find.byKey(const Key('fake-toolbar')), findsOneWidget);

    controller.collapse();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('fake-toolbar')), findsNothing);
    expect(find.byKey(const Key('game-toolbar-swipe-zone')), findsNothing);
    controller.dispose();
  });

  testWidgets('toolbar changes keep the game surface element stable', (
    tester,
  ) async {
    final controller = GameToolbarController();

    await tester.pumpWidget(_TestApp(controller: controller));
    final before = tester.element(find.byKey(const Key('fake-game-surface')));

    controller.collapse();
    await tester.pumpAndSettle();
    controller.reveal();
    await tester.pumpAndSettle();

    final after = tester.element(find.byKey(const Key('fake-game-surface')));
    expect(identical(before, after), isTrue);
    controller.dispose();
  });

  testWidgets('switching persistent mode keeps the game surface element stable', (
    tester,
  ) async {
    final controller = GameToolbarController();

    await tester.pumpWidget(_TestApp(controller: controller));
    final before = tester.element(find.byKey(const Key('fake-game-surface')));

    await tester.pumpWidget(
      _TestApp(controller: controller, persistent: true),
    );
    await tester.pump();

    expect(
      tester.element(find.byKey(const Key('fake-game-surface'))),
      same(before),
    );
    expect(find.byKey(const Key('persistent-game-toolbar-layout')), findsOneWidget);
    controller.dispose();
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({
    required this.controller,
    this.persistent = false,
    this.onGameTap,
  });

  final GameToolbarController controller;
  final bool persistent;
  final VoidCallback? onGameTap;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 800,
          height: 600,
          child: GameBrowserOverlay(
            controller: controller,
            persistent: persistent,
            gameSurface: GestureDetector(
              key: const Key('fake-game-surface'),
              behavior: HitTestBehavior.opaque,
              onTap: onGameTap,
              child: const ColoredBox(color: Colors.black),
            ),
            toolbar: const ColoredBox(
              key: Key('fake-toolbar'),
              color: Colors.blue,
              child: SizedBox(height: 48),
            ),
          ),
        ),
      ),
    );
  }
}
