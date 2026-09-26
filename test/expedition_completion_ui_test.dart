import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/expedition/expedition_completion_estimate.dart';
import 'package:yahagi_kancolle_browser/src/fleet/operation_status_views.dart';
import 'package:yahagi_kancolle_browser/src/fleet/operation_progress.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/performance/second_tick_scope.dart';

import 'fixtures/kcsapi_fixtures.dart';

void main() {
  testWidgets('远征进度条下显示设备本地完成时刻且保留倒计时', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1180, 720);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final completion = DateTime.now().add(const Duration(hours: 1));
    final port =
        (jsonDecode(portEvent.responseBody) as Map)['api_data']
            as Map<String, dynamic>;
    final fleets = port['api_deck_port'] as List;
    (fleets[1]['api_mission'] as List)[2] = completion.millisecondsSinceEpoch;
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(start2Event)
      ..accept(kcsapiEvent('/kcsapi/api_port/port', port));
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ExpeditionStatusView(state: controller.state)),
      ),
    );

    final progress = find.byKey(const Key('expedition-progress-2'));
    final completionLabel = find.byKey(
      const Key('expedition-progress-completion-2'),
    );
    expect(progress, findsOneWidget);
    expect(completionLabel, findsOneWidget);
    expect(
      tester.getTopLeft(completionLabel).dy,
      greaterThan(
        tester
            .getBottomLeft(
              find.descendant(
                of: progress,
                matching: find.byType(LinearProgressIndicator),
              ),
            )
            .dy,
      ),
    );
    expect(
      find.descendant(
        of: completionLabel,
        matching: find.textContaining(
          formatExpeditionCompletionTime(completion, now: DateTime.now()),
        ),
      ),
      findsOneWidget,
    );
    expect(find.byType(OperationCountdownText), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('远征完成后跨日时进度页补上完成日期', (tester) async {
    final today = DateTime.now();
    final completion = DateTime(
      today.year,
      today.month,
      today.day + 10,
      23,
      59,
    );
    var now = completion.subtract(const Duration(minutes: 1));
    final port =
        (jsonDecode(portEvent.responseBody) as Map)['api_data']
            as Map<String, dynamic>;
    final fleets = port['api_deck_port'] as List;
    (fleets[1]['api_mission'] as List)[2] = completion.millisecondsSinceEpoch;
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(start2Event)
      ..accept(kcsapiEvent('/kcsapi/api_port/port', port));
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: SecondTickScope(
          now: () => now,
          child: Scaffold(body: ExpeditionStatusView(state: controller.state)),
        ),
      ),
    );
    final completionLabel = find.byKey(
      const Key('expedition-progress-completion-2'),
    );
    expect(
      find.descendant(
        of: completionLabel,
        matching: find.textContaining('23:59'),
      ),
      findsOneWidget,
    );

    now = completion;
    await tester.pump(const Duration(seconds: 1));
    now = completion.add(const Duration(minutes: 1));
    await tester.pump(const Duration(seconds: 1));
    final expected = formatExpeditionCompletionTime(completion, now: now);
    expect(expected, contains('/'));
    expect(
      find.descendant(
        of: completionLabel,
        matching: find.textContaining(expected),
      ),
      findsOneWidget,
    );
  });
}
