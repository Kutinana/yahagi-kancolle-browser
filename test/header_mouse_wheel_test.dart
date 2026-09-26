import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/fleet/resource_grid.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';

void main() {
  testWidgets('wheel scrolls header horizontally only inside the header', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              SizedBox(
                width: 300,
                child: CompactResourceBar(state: GameState()),
              ),
              SizedBox(height: 200, width: 300, key: Key('outside')),
            ],
          ),
        ),
      ),
    );
    final header = find.byKey(const Key('header-resource-list'));
    final scroll = tester
        .state<ScrollableState>(
          find.descendant(of: header, matching: find.byType(Scrollable)),
        )
        .position;
    Future<void> wheel(Offset position, Offset delta) async {
      await tester.sendEventToBinding(
        PointerScrollEvent(
          kind: PointerDeviceKind.mouse,
          position: position,
          scrollDelta: delta,
        ),
      );
      await tester.pump();
    }

    await wheel(tester.getCenter(header), const Offset(0, 100));
    expect(scroll.pixels, 100);
    await wheel(
      tester.getCenter(find.byKey(const Key('outside'))),
      const Offset(0, 100),
    );
    expect(scroll.pixels, 100);
    await wheel(tester.getCenter(header), const Offset(0, -50));
    expect(scroll.pixels, 50);
    await wheel(tester.getCenter(header), const Offset(40, 0));
    expect(scroll.pixels, 90);
    await wheel(tester.getCenter(header), const Offset(0, -1000));
    expect(scroll.pixels, 0);
    await wheel(tester.getCenter(header), const Offset(0, 10000));
    // Lazy list extent estimates settle after the final items are laid out.
    await tester.pumpAndSettle();
    expect(scroll.pixels, scroll.maxScrollExtent);
  });
}
