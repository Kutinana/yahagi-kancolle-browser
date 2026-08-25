import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/new_ship/new_ship_reminder_controller.dart';
import 'package:yahagi_kancolle_browser/src/new_ship/new_ship_reminder_store.dart';

import '../fixtures/kcsapi_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameState state;
  late NewShipReminderStore store;
  late List<NewShipAlert> published;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    store = NewShipReminderStore(await SharedPreferences.getInstance());
    published = <NewShipAlert>[];
    state = const GameState(
      memberId: 1001,
      masterShips: <int, MasterShip>{
        1: MasterShip(
          id: 1,
          name: '一号',
          shipTypeId: 2,
          sortNo: 1,
          afterShipId: 2,
        ),
        2: MasterShip(id: 2, name: '一号改', shipTypeId: 2, sortNo: 2),
        4: MasterShip(id: 4, name: '四号', shipTypeId: 2, sortNo: 4),
      },
      ships: <int, OwnedShip>{10: OwnedShip(id: 10, masterId: 2, level: 30)},
    );
  });

  test('battle drop waits for port before publishing', () async {
    final controller = NewShipReminderController(
      stateProvider: () => state,
      store: store,
      onPublish: published.add,
    );

    controller.accept(
      kcsapiEvent('/kcsapi/api_req_sortie/battleresult', <String, Object?>{
        'api_get_ship': <String, Object?>{'api_ship_id': 4},
      }, sequence: 42),
    );
    await controller.idle;
    expect(published, isEmpty);

    controller.accept(
      kcsapiEvent('/kcsapi/api_port/port', <String, Object?>{}, sequence: 43),
    );
    await controller.idle;
    expect(published.single.masterIds, <int>[4]);
  });

  test('owned family and excluded family do not publish', () async {
    await store.saveExcludedFamilyIds(1001, <int>{4});
    final controller = NewShipReminderController(
      stateProvider: () => state,
      store: store,
      onPublish: published.add,
    );

    controller.accept(
      kcsapiEvent('/kcsapi/api_req_kousyou/getship', <String, Object?>{
        'api_ship': <String, Object?>{'api_ship_id': 1},
      }, sequence: 50),
    );
    controller.accept(
      kcsapiEvent('/kcsapi/api_req_kousyou/getship', <String, Object?>{
        'api_ship': <String, Object?>{'api_ship_id': 4},
      }, sequence: 51),
    );
    await controller.idle;

    expect(published, isEmpty);
  });

  test('construction publishes an absent family immediately', () async {
    final controller = NewShipReminderController(
      stateProvider: () => state,
      store: store,
      onPublish: published.add,
    );

    controller.accept(
      kcsapiEvent('/kcsapi/api_req_kousyou/getship', <String, Object?>{
        'api_ship': <String, Object?>{'api_ship_id': 4},
      }, sequence: 52),
    );
    await controller.idle;

    expect(published.single.masterIds, <int>[4]);
    expect(published.single.sources, <NewShipAcquisitionSource>{
      NewShipAcquisitionSource.construction,
    });
  });
}
