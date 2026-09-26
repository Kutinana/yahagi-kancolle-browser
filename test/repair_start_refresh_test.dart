import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/fleet/anchorage_repair_view.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';

import 'fixtures/kcsapi_fixtures.dart';

void main() {
  for (final scenario in [
    'existing dock',
    'missing dock',
    'unknown duration',
    'instant repair',
  ]) {
    testWidgets('new repair refreshes visible page: $scenario', (tester) async {
      final controller = GameStateController();
      addTearDown(controller.dispose);
      controller.accept(
        kcsapiEvent('/kcsapi/api_port/port', {
          'api_ship': [
            {
              'api_id': 1001,
              'api_ship_id': 101,
              'api_lv': 10,
              'api_nowhp': 4,
              'api_maxhp': 39,
              'api_ndock_time': 60000,
            },
            {
              'api_id': 1002,
              'api_ship_id': 102,
              'api_lv': 20,
              'api_nowhp': 13,
              'api_maxhp': 49,
              if (scenario != 'unknown duration') 'api_ndock_time': 120000,
            },
          ],
          'api_ndock': [
            if (scenario != 'missing dock')
              {
                'api_id': 1,
                'api_state': 1,
                'api_ship_id': 1001,
                'api_complete_time': DateTime.now()
                    .add(const Duration(minutes: 1))
                    .millisecondsSinceEpoch,
              },
            {'api_id': 2, 'api_state': 0},
          ],
        }),
      );
      await controller.idle;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: RepairCenterView(controller: controller)),
        ),
      );
      if (scenario != 'missing dock') {
        expect(find.text('HP 4/39'), findsOneWidget);
      }

      controller.accept(
        kcsapiEvent(
          '/kcsapi/api_req_nyukyo/start',
          null,
          includeApiData: false,
          capturedAt: DateTime.now().toUtc(),
          requestParams: {
            'api_ndock_id': '1',
            'api_ship_id': '1002',
            'api_highspeed': scenario == 'instant repair' ? '1' : '0',
          },
        ),
      );
      await controller.idle;
      await tester.pump();
      expect(controller.lastError, isNull);
      expect(find.text('HP 4/39'), findsNothing);
      if (scenario == 'instant repair') {
        expect(find.text('HP 13/49'), findsNothing);
        expect(controller.state.ships[1002]!.currentHp, 49);
        expect(
          controller.state.repairDocks
              .where((dock) => dock.id == 1)
              .single
              .isRepairing,
          isFalse,
        );
      } else {
        expect(find.text('HP 13/49'), findsOneWidget);
        expect(
          controller.state.repairDocks
              .where((dock) => dock.id == 1)
              .single
              .shipId,
          1002,
        );
      }

      // A later authoritative dock snapshot still clears the displayed ship.
      controller.accept(
        kcsapiEvent('/kcsapi/api_get_member/ndock', [
          {'api_id': 1, 'api_state': 0, 'api_ship_id': 0},
          {'api_id': 2, 'api_state': 0, 'api_ship_id': 0},
        ]),
      );
      await controller.idle;
      await tester.pump();
      expect(find.text('HP 13/49'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
