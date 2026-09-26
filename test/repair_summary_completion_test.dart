import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/fleet/operation_progress.dart';
import 'package:yahagi_kancolle_browser/src/fleet/repair_summary_card.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/performance/second_tick_scope.dart';

import 'fixtures/kcsapi_fixtures.dart';

void main() {
  for (final showEmpty in [true, false]) {
    testWidgets(
      'summary clears expired repair and displays replacement (empty=$showEmpty)',
      (tester) async {
        var now = DateTime.utc(2030);
        final end = now.add(const Duration(seconds: 2));
        final controller = GameStateController();
        addTearDown(controller.dispose);
        controller
          ..accept(start2Event)
          ..accept(portEvent)
          ..accept(
            kcsapiEvent('/kcsapi/api_get_member/ndock', [
              {
                'api_id': 1,
                'api_state': 1,
                'api_ship_id': 9002,
                'api_complete_time': end.millisecondsSinceEpoch,
              },
            ]),
          );
        await controller.idle;
        await tester.pumpWidget(
          MaterialApp(
            home: SecondTickScope(
              now: () => now,
              child: Scaffold(
                body: RepairSummaryCard(
                  controller: controller,
                  collapsed: false,
                  visible: {'portrait', if (showEmpty) 'empty'},
                  onToggleCollapse: () {},
                  onOpenRepair: (_) {},
                ),
              ),
            ),
          ),
        );
        expect(find.byType(OperationCountdownText), findsOneWidget);
        now = end;
        await tester.pump(const Duration(seconds: 2));
        expect(find.byType(OperationCountdownText), findsNothing);
        expect(find.text('已完成'), findsNothing);
        expect(
          find.byKey(const Key('repair-summary-dock-slot-1')),
          showEmpty ? findsOneWidget : findsNothing,
        );
        expect(controller.state.repairDocks.single.isRepairing, isTrue);

        controller.accept(
          kcsapiEvent('/kcsapi/api_get_member/ship2', [
            {'api_id': 9001, 'api_nowhp': 10, 'api_ndock_time': 60000},
          ]),
        );
        controller.accept(
          kcsapiEvent(
            '/kcsapi/api_req_nyukyo/start',
            null,
            includeApiData: false,
            capturedAt: now,
            requestParams: const {
              'api_ndock_id': '1',
              'api_ship_id': '9001',
              'api_highspeed': '0',
            },
          ),
        );
        await controller.idle;
        await tester.pump();
        expect(controller.state.repairDocks.single.shipId, 9001);
        expect(find.byType(OperationCountdownText), findsOneWidget);
        expect(
          find.byKey(const Key('repair-summary-dock-slot-1')),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
