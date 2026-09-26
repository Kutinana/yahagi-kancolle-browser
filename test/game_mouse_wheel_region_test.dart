import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_mouse_wheel_region.dart';

void main() {
  testWidgets('wheel on neighboring panel scrolls only that panel', (
    tester,
  ) async {
    final events = <GameMouseWheelInput>[];
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Row(
          children: [
            Expanded(
              child: GameMouseWheelRegion(
                enabled: true,
                onScroll: events.add,
                child: const ColoredBox(color: Colors.black),
              ),
            ),
            Expanded(
              child: ListView(
                key: const Key('panel'),
                controller: scroll,
                children: List.generate(
                  40,
                  (index) => SizedBox(height: 60, child: Text('$index')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(find.byKey(const Key('panel'))),
        scrollDelta: const Offset(0, 100),
        kind: PointerDeviceKind.mouse,
      ),
    );
    await tester.pumpAndSettle();
    expect(scroll.offset, greaterThan(0));
    expect(events, isEmpty);
  });

  testWidgets('enabled compatibility leaves mouse and finger clicks intact', (
    tester,
  ) async {
    var taps = 0;
    final events = <GameMouseWheelInput>[];
    await tester.pumpWidget(
      MaterialApp(
        home: GameMouseWheelRegion(
          enabled: true,
          onScroll: events.add,
          child: GestureDetector(
            key: const Key('game-content'),
            onTap: () => taps++,
            child: const ColoredBox(color: Colors.black),
          ),
        ),
      ),
    );
    await tester.tap(
      find.byKey(const Key('game-content')),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('game-content')),
      kind: PointerDeviceKind.touch,
    );
    await tester.pump();
    expect(taps, 2);
    expect(events, isEmpty);
  });

  for (final enabled in [false, true]) {
    testWidgets('mouse wheel forwarding enabled=$enabled', (tester) async {
      final events = <GameMouseWheelInput>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 200,
              height: 100,
              child: GameMouseWheelRegion(
                enabled: enabled,
                onScroll: events.add,
                child: const ColoredBox(color: Colors.black),
              ),
            ),
          ),
        ),
      );
      final rect = tester.getRect(find.byType(GameMouseWheelRegion));
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: rect.topLeft + const Offset(50, 25),
          scrollDelta: const Offset(0, 48),
          kind: PointerDeviceKind.mouse,
        ),
      );
      expect(events.length, enabled ? 1 : 0);
      if (enabled) {
        expect(events.single.xRatio, .25);
        expect(events.single.yRatio, .25);
        expect(events.single.deltaY, 48);
      }
    });
  }

  testWidgets('overlay and touch signals do not reach the game', (
    tester,
  ) async {
    final events = <GameMouseWheelInput>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            Positioned.fill(
              child: GameMouseWheelRegion(
                enabled: true,
                onScroll: events.add,
                child: const ColoredBox(color: Colors.black),
              ),
            ),
            const Positioned.fill(
              child: Listener(
                behavior: HitTestBehavior.opaque,
                child: ColoredBox(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.sendEventToBinding(
      const PointerScrollEvent(
        position: Offset(50, 50),
        scrollDelta: Offset(0, 48),
        kind: PointerDeviceKind.mouse,
      ),
    );
    expect(events, isEmpty);
    await tester.pumpWidget(
      MaterialApp(
        home: GameMouseWheelRegion(
          enabled: true,
          onScroll: events.add,
          child: const ColoredBox(color: Colors.black),
        ),
      ),
    );
    await tester.sendEventToBinding(
      const PointerScrollEvent(
        position: Offset(50, 50),
        scrollDelta: Offset(0, 48),
        kind: PointerDeviceKind.touch,
      ),
    );
    expect(events, isEmpty);
  });
}
