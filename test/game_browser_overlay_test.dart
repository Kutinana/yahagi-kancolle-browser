import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_browser_overlay.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_toolbar_controller.dart';

void main() {
  testWidgets('game browser overlay renders game surface cleanly', (
    tester,
  ) async {
    final controller = GameToolbarController();
    var taps = 0;

    await tester.pumpWidget(
      _TestApp(controller: controller, onGameTap: () => taps++),
    );

    expect(find.byKey(const Key('game-browser-overlay')), findsOneWidget);
    expect(find.byKey(const Key('fake-game-surface')), findsOneWidget);
    await tester.tapAt(const Offset(80, 20));
    expect(taps, 1);
    controller.dispose();
  });

  testWidgets('game surface element remains stable across controller events', (
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
          ),
        ),
      ),
    );
  }
}
