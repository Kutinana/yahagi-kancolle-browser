import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/fleet/anchorage_repair_view.dart';
import 'package:yahagi_kancolle_browser/src/fleet/nosaki_sparkle_view.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_reducer.dart';

import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';

import 'nosaki_sparkle_calculator_test.dart' show buildNosakiTestState;

void main() {
  setUp(() => GameStateController.disableTimerForTest = true);

  testWidgets('renders 3-mode repair tabs and switches to NosakiSparkleView', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final controller = await _controller(
      buildNosakiTestState(flagshipMasterId: 602),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: RepairCenterView(controller: controller)),
      ),
    );

    expect(find.byKey(const Key('repair-mode-dock')), findsOneWidget);
    expect(find.byKey(const Key('repair-mode-anchorage')), findsOneWidget);
    expect(find.byKey(const Key('repair-mode-nosaki')), findsOneWidget);

    // Switch to Nosaki mode
    await tester.tap(find.byKey(const Key('repair-mode-nosaki')));
    await tester.pump();

    expect(find.byType(NosakiSparkleView), findsOneWidget);
    expect(find.byKey(const Key('nosaki-summary-status')), findsOneWidget);
    expect(find.byKey(const Key('nosaki-summary-elapsed')), findsOneWidget);
    expect(find.byKey(const Key('nosaki-summary-capacity')), findsOneWidget);
    expect(find.byKey(const Key('nosaki-sparkle-table')), findsOneWidget);

    expect(find.text('母港给粮就绪中'), findsOneWidget);
    expect(find.text('野埼改'), findsOneWidget);
  });

  testWidgets('renders unready state correctly in NosakiSparkleView', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final controller = await _controller(
      buildNosakiTestState(
        flagshipMasterId: 602,
        nosakiFuel: 70, // Not supplied
      ),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RepairCenterView(
            controller: controller,
            mode: RepairCenterMode.nosaki,
          ),
        ),
      ),
    );

    expect(find.byType(NosakiSparkleView), findsOneWidget);
    expect(find.textContaining('未满补给'), findsWidgets);
  });
}

Future<GameStateController> _controller(GameState state) async {
  final controller = GameStateController(reducer: _StaticReducer(state));
  controller.accept(
    CapturedApiEvent(
      path: '/kcsapi/api_port/port',
      statusCode: 200,
      responseBody: 'svdata={"api_result":1}',
      capturedAt: DateTime.utc(2026, 8, 19, 10),
      source: CaptureSource.manual,
    ),
  );
  await controller.idle;
  return controller;
}

class _StaticReducer extends GameStateReducer {
  _StaticReducer(this.nextState);

  final GameState nextState;

  @override
  GameState reduce(GameState state, CapturedApiEvent event) => nextState;
}
