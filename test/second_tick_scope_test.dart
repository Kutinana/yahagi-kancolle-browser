import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/performance/second_tick_scope.dart';

void main() {
  testWidgets('one scope drives multiple second-tick builders', (tester) async {
    final timers = <Timer>[];
    var firstBuilds = 0;
    var secondBuilds = 0;

    await runZoned(
      () async {
        await tester.pumpWidget(
          MaterialApp(
            home: SecondTickScope(
              child: Column(
                children: [
                  SecondTickBuilder(
                    builder: (context, now, child) {
                      firstBuilds += 1;
                      return Text('first-${now.second}');
                    },
                  ),
                  SecondTickBuilder(
                    builder: (context, now, child) {
                      secondBuilds += 1;
                      return Text('second-${now.second}');
                    },
                  ),
                ],
              ),
            ),
          ),
        );

        expect(timers.where((timer) => timer.isActive), hasLength(1));
        final firstBefore = firstBuilds;
        final secondBefore = secondBuilds;
        await tester.pump(const Duration(seconds: 1));
        expect(firstBuilds, greaterThan(firstBefore));
        expect(secondBuilds, greaterThan(secondBefore));

        await tester.pumpWidget(const SizedBox.shrink());
        expect(timers.where((timer) => timer.isActive), isEmpty);
      },
      zoneSpecification: ZoneSpecification(
        createPeriodicTimer: (self, parent, zone, duration, callback) {
          final timer = parent.createPeriodicTimer(zone, duration, callback);
          timers.add(timer);
          return timer;
        },
      ),
    );
  });

  testWidgets('builder keeps a local fallback outside a scope', (tester) async {
    final timers = <Timer>[];
    await runZoned(
      () async {
        await tester.pumpWidget(
          MaterialApp(
            home: SecondTickBuilder(
              builder: (context, now, child) => Text('${now.second}'),
            ),
          ),
        );
        expect(timers.where((timer) => timer.isActive), hasLength(1));
        await tester.pumpWidget(const SizedBox.shrink());
        expect(timers.where((timer) => timer.isActive), isEmpty);
      },
      zoneSpecification: ZoneSpecification(
        createPeriodicTimer: (self, parent, zone, duration, callback) {
          final timer = parent.createPeriodicTimer(zone, duration, callback);
          timers.add(timer);
          return timer;
        },
      ),
    );
  });

  testWidgets('disabled ticker mode stops hidden second-tick rebuilds', (
    tester,
  ) async {
    var builds = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: SecondTickScope(
          child: TickerMode(
            enabled: false,
            child: SecondTickBuilder(
              builder: (context, now, child) {
                builds += 1;
                return Text('${now.second}');
              },
            ),
          ),
        ),
      ),
    );

    final before = builds;
    await tester.pump(const Duration(seconds: 2));
    expect(builds, before);
  });

  testWidgets('disabled builder unsubscribes and can resume ticking', (
    tester,
  ) async {
    final enabled = ValueNotifier<bool>(true);
    addTearDown(enabled.dispose);
    var now = DateTime.utc(2026, 8, 13, 10);
    var builds = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: SecondTickScope(
          now: () => now,
          child: ValueListenableBuilder<bool>(
            valueListenable: enabled,
            builder: (context, value, child) => SecondTickBuilder(
              enabled: value,
              builder: (context, now, child) {
                builds += 1;
                return Text('${now.second}');
              },
            ),
          ),
        ),
      ),
    );

    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    enabled.value = false;
    await tester.pump();
    final buildsWhileDisabled = builds;
    now = now.add(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    expect(builds, buildsWhileDisabled);

    enabled.value = true;
    await tester.pump();
    final buildsBeforeResume = builds;
    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(builds, greaterThan(buildsBeforeResume));
  });

  testWidgets('builder unsubscribes after its stop time', (tester) async {
    var now = DateTime.utc(2026, 8, 13, 10);
    final stopAt = now.add(const Duration(seconds: 2));
    var builds = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: SecondTickScope(
          now: () => now,
          child: SecondTickBuilder(
            stopAt: stopAt,
            builder: (context, tick, child) {
              builds += 1;
              return Text(tick.toIso8601String());
            },
          ),
        ),
      ),
    );

    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(builds, 2);

    now = stopAt;
    await tester.pump(const Duration(seconds: 1));
    expect(builds, 3);

    final buildsAfterCompletion = builds;
    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(builds, buildsAfterCompletion);
  });
}
