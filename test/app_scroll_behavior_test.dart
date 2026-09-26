import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/widgets/app_scroll_behavior.dart';

void main() {
  testWidgets('mouse long press can still reorder instead of scrolling', (
    tester,
  ) async {
    final order = List.generate(12, (index) => index);
    var reordered = false;
    await tester.pumpWidget(
      MaterialApp(
        scrollBehavior: const AppScrollBehavior(),
        home: StatefulBuilder(
          builder: (context, setState) => ReorderableListView(
            buildDefaultDragHandles: false,
            onReorderItem: (oldIndex, newIndex) => setState(() {
              reordered = true;
              order.insert(newIndex, order.removeAt(oldIndex));
            }),
            children: [
              for (var index = 0; index < order.length; index++)
                ReorderableDelayedDragStartListener(
                  key: ValueKey(order[index]),
                  index: index,
                  child: SizedBox(
                    height: 80,
                    child: Text('item ${order[index]}'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey(0))),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await gesture.moveBy(const Offset(0, 150));
    await tester.pump(const Duration(milliseconds: 500));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(reordered, isTrue);
    expect(order.first, isNot(0));
  });

  for (final kind in [PointerDeviceKind.mouse, PointerDeviceKind.touch]) {
    for (final axis in Axis.values) {
      testWidgets('$kind can drag a $axis list without tapping a row', (
        tester,
      ) async {
        final scroll = ScrollController();
        var taps = 0;
        addTearDown(scroll.dispose);
        await tester.pumpWidget(
          MaterialApp(
            scrollBehavior: const AppScrollBehavior(),
            home: ListView.builder(
              controller: scroll,
              scrollDirection: axis,
              itemExtent: 100,
              itemCount: 40,
              itemBuilder: (_, index) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => taps++,
                child: Text('row $index'),
              ),
            ),
          ),
        );
        final gesture = await tester.startGesture(
          const Offset(200, 200),
          kind: kind,
        );
        await gesture.moveBy(
          axis == Axis.vertical ? const Offset(0, -30) : const Offset(-30, 0),
        );
        await gesture.moveBy(
          axis == Axis.vertical ? const Offset(0, -100) : const Offset(-100, 0),
        );
        await gesture.up();
        await tester.pumpAndSettle();
        expect(scroll.offset, greaterThan(50));
        expect(taps, 0);
      });
    }
  }

  testWidgets('mouse click and wheel still work on the same list', (
    tester,
  ) async {
    var taps = 0;
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      MaterialApp(
        scrollBehavior: const AppScrollBehavior(),
        home: ListView(
          controller: scroll,
          children: [
            TextButton(onPressed: () => taps++, child: const Text('open')),
            const SizedBox(height: 2000),
          ],
        ),
      ),
    );
    await tester.tap(find.text('open'), kind: PointerDeviceKind.mouse);
    await tester.pump();
    expect(taps, 1);
    await tester.sendEventToBinding(
      const PointerScrollEvent(
        kind: PointerDeviceKind.mouse,
        position: Offset(200, 200),
        scrollDelta: Offset(0, 120),
      ),
    );
    await tester.pumpAndSettle();
    expect(scroll.offset, greaterThan(0));
  });
}
