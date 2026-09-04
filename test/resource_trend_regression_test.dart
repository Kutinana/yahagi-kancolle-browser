import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/fleet/resource_trend_page.dart';
import 'package:yahagi_kancolle_browser/src/fleet/resource_trend_sampler.dart';

Map<String, dynamic> row(DateTime at, int value) => {
  'timestamp': at.millisecondsSinceEpoch,
  for (final key in resourceTrendKeys) key: value,
};

Widget wrap(ResourceTrendLoader loader, DateTime Function() now) => MaterialApp(
  locale: const Locale('zh'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: ThemeData.dark(),
  home: Scaffold(
    body: ResourceTrendPage(loadLogs: loader, now: now),
  ),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('fullscreen retry replaces the error with loading immediately', (
    tester,
  ) async {
    final now = DateTime.parse('2026-09-05T18:00:00+09:00');
    var calls = 0;
    final pending = Completer<List<Map<String, dynamic>>>();
    await tester.pumpWidget(
      wrap((_) {
        calls++;
        if (calls == 1) return Future.value([row(now, 1200)]);
        if (calls == 2) return Future.error(StateError('query unavailable'));
        return pending.future;
      }, () => now),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('resource-trend-expand')),
    );
    await tester.tap(find.byKey(const ValueKey('resource-trend-expand')));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    final retry = find.descendant(
      of: find.byType(Dialog),
      matching: find.byKey(const ValueKey('resource-trend-retry')),
    );
    expect(retry, findsOneWidget);
    await tester.tap(retry);
    await tester.pump();
    expect(retry, findsNothing);
    expect(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    pending.complete([row(now, 1250)]);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('resource-trend-fullscreen')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('parent rebuild safely publishes loading to an open dialog', (
    tester,
  ) async {
    final now = DateTime.parse('2026-09-05T18:00:00+09:00');
    final configuration = ValueNotifier(0);
    final pending = Completer<List<Map<String, dynamic>>>();
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<int>(
          valueListenable: configuration,
          builder: (context, value, child) => Scaffold(
            body: ResourceTrendPage(
              now: () => now,
              loadLogs: (_) =>
                  value == 0 ? Future.value([row(now, 1200)]) : pending.future,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('resource-trend-expand')),
    );
    await tester.tap(find.byKey(const ValueKey('resource-trend-expand')));
    await tester.pumpAndSettle();
    configuration.value = 1;
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    pending.complete([row(now, 1250)]);
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    configuration.dispose();
  });

  testWidgets('accessibility decrease can traverse sparse observations', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final now = DateTime.parse('2026-09-05T18:00:00+09:00');
    final start = DateTime.parse('2026-09-05T00:00:00+09:00');
    await tester.pumpWidget(
      wrap((_) async => [row(start, 1000), row(now, 1200)], () => now),
    );
    await tester.pumpAndSettle();
    final slider = find.byKey(const ValueKey('resource-trend-scrubber'));
    await tester.ensureVisible(slider);
    await tester.pumpAndSettle();
    for (var i = 0; i < 25; i++) {
      SemanticsNode? decreaseNode;
      void visit(SemanticsNode node) {
        if (node.getSemanticsData().hasAction(SemanticsAction.decrease)) {
          decreaseNode = node;
        }
        node.visitChildren((child) {
          visit(child);
          return true;
        });
      }

      visit(
        tester
            .binding
            .renderViews
            .single
            .owner!
            .semanticsOwner!
            .rootSemanticsNode!,
      );
      final node = decreaseNode;
      if (node == null) {
        final tree = tester
            .binding
            .renderViews
            .single
            .owner!
            .semanticsOwner!
            .rootSemanticsNode!
            .toStringDeep();
        semantics.dispose();
        await tester.pumpWidget(const SizedBox());
        fail('No decrease semantics node in tree: $tree');
      }
      tester.binding.performSemanticsAction(
        SemanticsActionEvent(
          viewId: tester.view.viewId,
          nodeId: node.id,
          type: SemanticsAction.decrease,
        ),
      );
      await tester.pump();
    }
    final value = tester.widget<Slider>(slider).value;
    semantics.dispose();
    await tester.pumpWidget(const SizedBox());
    expect(
      value,
      0.0,
      reason: '25 decrease actions must reach the older of two records',
    );
  });

  testWidgets(
    'fullscreen clears old-day chart while midnight reload is pending',
    (tester) async {
      var now = DateTime.parse('2026-09-05T23:59:59+09:00');
      var calls = 0;
      final pending = Completer<List<Map<String, dynamic>>>();
      await tester.pumpWidget(
        wrap((_) {
          calls++;
          return calls == 1 ? Future.value([row(now, 1200)]) : pending.future;
        }, () => now),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('resource-trend-expand')),
      );
      await tester.tap(find.byKey(const ValueKey('resource-trend-expand')));
      await tester.pumpAndSettle();
      now = now.add(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      final oldChartCount = find
          .byKey(const ValueKey('resource-trend-fullscreen'))
          .evaluate()
          .length;
      final spinnerCount = find
          .descendant(
            of: find.byType(Dialog),
            matching: find.byType(CircularProgressIndicator),
          )
          .evaluate()
          .length;
      pending.complete([row(now, 1250)]);
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      expect(calls, 2);
      expect(
        oldChartCount,
        0,
        reason:
            'old day is cleared from page state but dialog also must rebuild',
      );
      expect(spinnerCount, 1);
    },
  );
}
