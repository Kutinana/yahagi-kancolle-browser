import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/new_ship/new_ship_reminder_controller.dart';
import 'package:yahagi_kancolle_browser/src/new_ship/new_ship_reminder_store.dart';
import '../fixtures/kcsapi_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late NewShipReminderStore store;
  late List<NewShipAlert> alerts;
  late NewShipReminderController controller;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = NewShipReminderStore(await SharedPreferences.getInstance());
    alerts = [];
    controller = NewShipReminderController(
      stateProvider: () => const GameState(
        memberId: 1001,
        masterShips: {7: MasterShip(id: 7, name: '三日月', shipTypeId: 2)},
      ),
      store: store,
      onPublish: alerts.add,
    );
    addTearDown(controller.dispose);
  });

  test(
    'map payload cannot turn arbitrary reward IDs into ship acquisitions',
    () async {
      controller.accept(
        kcsapiEvent('/kcsapi/api_req_map/next', {
          'api_itemget': {
            'api_type': 1,
            'api_item': {'api_id': 7},
          },
          'api_unrelated': {'api_ship_id': 7},
        }),
      );
      await controller.idle;
      expect(alerts, isEmpty);
    },
  );

  for (final locked in [false, true]) {
    test(
      'pending reminder is discarded when ship is ${locked ? 'already locked' : 'no longer owned'}',
      () async {
        await store.savePending(1001, [
          PendingNewShipAcquisition(
            key: 'old-drop',
            masterIds: [7],
            source: NewShipAcquisitionSource.battle,
            occurredAt: DateTime.utc(2026, 9, 1),
          ),
        ]);
        controller.accept(
          kcsapiEvent('/kcsapi/api_port/port', {
            'api_ship': [
              if (locked) {'api_ship_id': 7, 'api_locked': 1},
            ],
          }),
        );
        await controller.idle;
        expect(alerts, isEmpty);
        expect(await store.loadPending(1001), isEmpty);
      },
    );
  }

  test(
    'event ship reward uses type 2 and waits for its unlocked port inventory',
    () async {
      controller.accept(
        kcsapiEvent('/kcsapi/api_req_sortie/battleresult', {
          'api_get_eventitem': [
            {'api_type': 1, 'api_id': 7},
            {'api_type': 2, 'api_id': 7},
            {'api_type': 3, 'api_id': 7},
          ],
        }, sequence: 1),
      );
      await controller.idle;
      expect(alerts, isEmpty);
      controller.accept(
        kcsapiEvent('/kcsapi/api_port/port', {
          'api_ship': [
            {'api_ship_id': 7, 'api_locked': 0},
          ],
        }, sequence: 2),
      );
      await controller.idle;
      expect(alerts.single.masterIds, [7]);
      expect(alerts.single.sources, {NewShipAcquisitionSource.eventReward});
    },
  );
}
