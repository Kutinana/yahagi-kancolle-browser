import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/performance/second_tick_scope.dart';
import 'package:yahagi_kancolle_browser/src/widgets/lazy_indexed_stack.dart';

void main() {
  testWidgets('tabs initialize once, retain state, and stop hidden ticks', (
    tester,
  ) async {
    final builds = [0, 0];
    Widget app(int index, String text) => MaterialApp(
      home: LazyIndexedStack(
        index: index,
        children: [
          SecondTickBuilder(
            builder: (context, now, _) {
              builds[0]++;
              return Text(text);
            },
          ),
          SecondTickBuilder(
            builder: (context, now, _) {
              builds[1]++;
              return const Text('second');
            },
          ),
        ],
      ),
    );
    await tester.pumpWidget(app(0, 'first'));
    expect(builds[1], 0);
    final firstState = tester.state(find.byType(SecondTickBuilder));
    await tester.pump(const Duration(seconds: 1));
    expect(builds[0], 2);
    await tester.pumpWidget(app(1, 'updated'));
    final hiddenBuilds = builds[0];
    final activeBuilds = builds[1];
    await tester.pump(const Duration(seconds: 1));
    expect(builds[0], hiddenBuilds);
    expect(builds[1], activeBuilds + 1);
    await tester.pumpWidget(app(0, 'updated'));
    expect(tester.state(find.byType(SecondTickBuilder)), same(firstState));
    expect(find.text('updated'), findsOneWidget);
    final resumedBuilds = builds[0];
    await tester.pump(const Duration(seconds: 1));
    expect(builds[0], resumedBuilds + 1);
  });
}
