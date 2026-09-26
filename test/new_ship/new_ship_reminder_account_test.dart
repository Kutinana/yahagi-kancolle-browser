import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/src/account/account_session.dart';
import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_api_event_pipeline.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_reducer.dart';
import 'package:yahagi_kancolle_browser/src/new_ship/new_ship_reminder_controller.dart';
import 'package:yahagi_kancolle_browser/src/new_ship/new_ship_reminder_store.dart';

import '../fixtures/kcsapi_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences preferences;
  late NewShipReminderStore store;
  late _ReducerConsumer game;
  late List<NewShipAlert> published;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    preferences = await SharedPreferences.getInstance();
    store = NewShipReminderStore(preferences);
    game = _ReducerConsumer(_accountState(1001));
    published = <NewShipAlert>[];
  });

  NewShipReminderController reminder({NewShipReminderStore? storage}) {
    final controller = NewShipReminderController(
      stateProvider: () => game.state,
      waitForGameState: () => game.idle,
      store: storage ?? store,
      onPublish: published.add,
    );
    addTearDown(controller.dispose);
    return controller;
  }

  test(
    'logout clears the alert without waiting for another game response',
    () async {
      final session = AccountSession(initialMemberId: 1001);
      final controller = NewShipReminderController(
        accountSession: session,
        stateProvider: () => game.state,
        store: store,
        onPublish: published.add,
      );
      addTearDown(session.dispose);
      addTearDown(controller.dispose);
      controller.accept(_construction(sequence: 109));
      await controller.idle;
      expect(controller.currentAlert, isNotNull);
      session.reset();
      expect(controller.currentAlert, isNull);
      expect(controller.excludedFamilyIds, isEmpty);
      controller.accept(_construction(sequence: 110));
      await controller.idle;
      expect(published, hasLength(1));
    },
  );

  GameApiEventPipeline pipeline(NewShipReminderController controller) =>
      GameApiEventPipeline(
        consumers: <GameApiEventConsumer>[game, controller],
        settleGameState: () => game.idle,
      );

  test(
    'first port for another account preserves the old account pending',
    () async {
      await store.savePending(1001, <PendingNewShipAcquisition>[
        PendingNewShipAcquisition(
          key: 'old-account-battle',
          masterIds: <int>[4],
          source: NewShipAcquisitionSource.battle,
          occurredAt: DateTime.utc(2026, 9, 12),
        ),
      ]);
      final controller = reminder();
      final events = pipeline(controller);

      events.add(_portFor(2002, sequence: 101));
      await events.idle;

      expect(game.state.memberId, 2002);
      expect(game.state.ships, isEmpty);
      expect(published, isEmpty);
      expect(controller.currentAlert, isNull);
      expect(
        (await store.loadPending(1001)).map((pending) => pending.key),
        <String>['old-account-battle'],
      );
      expect(await store.loadPending(2002), isEmpty);
    },
  );

  test('account switch clears an already visible alert', () async {
    final controller = reminder();
    final events = pipeline(controller);
    events.add(_construction(sequence: 110));
    await events.idle;
    expect(controller.currentAlert, isNotNull);
    expect(published, hasLength(1));

    events.add(_portFor(2002, sequence: 111));
    await events.idle;

    expect(controller.currentAlert, isNull);
    expect(published, hasLength(1));
  });

  test(
    'new login invalidates an alert before the next identity arrives',
    () async {
      final controller = reminder();
      final events = pipeline(controller);
      events.add(_construction(sequence: 120));
      await events.idle;
      expect(controller.currentAlert, isNotNull);

      events.add(
        kcsapiEvent('/kcsapi/api_start2/getData', <String, Object?>{
          'api_mst_ship': <Object?>[],
        }, sequence: 121),
      );
      await events.idle;

      expect(game.state.memberId, 0);
      expect(controller.currentAlert, isNull);
    },
  );

  test(
    'queued acquisition cannot publish after the account has changed',
    () async {
      await store.saveExcludedFamilyIds(2002, <int>{5});
      final delayedStore = _DelayedAccountStore(preferences);
      final controller = reminder(storage: delayedStore);
      final events = pipeline(controller);
      events.add(_construction(sequence: 130));
      await delayedStore.started.future;

      events.add(
        kcsapiEvent('/kcsapi/api_get_member/basic', <String, Object?>{
          'api_member_id': '2002',
          'api_level': 1,
        }, sequence: 131),
      );
      await events.dispatchIdle;
      expect(game.state.memberId, 2002);
      delayedStore.release.complete();
      await events.idle;

      expect(published, isEmpty);
      expect(controller.currentAlert, isNull);
      expect(controller.excludedFamilyIds, <int>{5});
      expect(await store.loadPending(2002), isEmpty);
    },
  );

  test(
    'account switch during pending load does not consume old pending',
    () async {
      await store.savePending(1001, <PendingNewShipAcquisition>[
        PendingNewShipAcquisition(
          key: 'old-account-pending-load',
          masterIds: <int>[4],
          source: NewShipAcquisitionSource.battle,
          occurredAt: DateTime.utc(2026, 9, 12),
        ),
      ]);
      final delayedStore = _DelayedPendingStore(preferences);
      final controller = reminder(storage: delayedStore);
      final events = pipeline(controller);
      events.add(_portFor(1001, sequence: 135));
      await delayedStore.started.future;

      events.add(
        kcsapiEvent('/kcsapi/api_get_member/basic', <String, Object?>{
          'api_member_id': '2002',
          'api_level': 1,
        }, sequence: 136),
      );
      await events.dispatchIdle;
      expect(game.state.memberId, 2002);
      delayedStore.release.complete();
      await events.idle;

      expect(
        (await store.loadPending(1001)).map((pending) => pending.key),
        <String>['old-account-pending-load'],
      );
      expect(published, isEmpty);
      expect(controller.currentAlert, isNull);
      expect(await store.loadPending(2002), isEmpty);
    },
  );

  test(
    'port switch loads the new exclusion list without changing the old one',
    () async {
      await store.saveExcludedFamilyIds(1001, <int>{4});
      await store.saveExcludedFamilyIds(2002, <int>{5});
      final controller = reminder();
      final events = pipeline(controller);
      events.add(_portFor(2002, sequence: 140));
      await events.idle;

      expect(controller.excludedFamilyIds, <int>{5});
      expect(await store.loadExcludedFamilyIds(1001), <int>{4});
      expect(await store.loadExcludedFamilyIds(2002), <int>{5});

      await controller.setFamilyExcluded(5, false);
      expect(await store.loadExcludedFamilyIds(1001), <int>{4});
      expect(await store.loadExcludedFamilyIds(2002), isEmpty);
    },
  );

  test(
    'new login to the same account invalidates the previous queue',
    () async {
      final delayedStore = _DelayedAccountStore(preferences);
      final controller = reminder(storage: delayedStore);
      final events = pipeline(controller);
      events.add(_construction(sequence: 150));
      await delayedStore.started.future;

      events.add(
        kcsapiEvent('/kcsapi/api_start2/getData', <String, Object?>{
          'api_mst_ship': <Object?>[
            <String, Object?>{'api_id': 4, 'api_name': '三日月', 'api_stype': 2},
          ],
        }, sequence: 151),
      );
      events.add(_portFor(1001, sequence: 152));
      await events.dispatchIdle;
      expect(game.state.memberId, 1001);
      delayedStore.release.complete();
      await events.idle;

      expect(published, isEmpty);
      expect(controller.currentAlert, isNull);

      events.add(_construction(sequence: 150));
      await events.idle;
      expect(published, hasLength(1));
    },
  );

  test(
    'the same event sequence can alert independently in two accounts',
    () async {
      final controller = reminder();
      final events = pipeline(controller);
      events.add(_construction(sequence: 160));
      await events.idle;
      expect(published, hasLength(1));
      final firstKey = published.single.key;

      events.add(_portFor(2002, sequence: 161));
      events.add(_construction(sequence: 160));
      await events.idle;

      expect(published, hasLength(2));
      expect(published.last.masterIds, <int>[4]);
      expect(published.last.key, isNot(firstKey));
    },
  );

  test(
    'port waits for delayed reducer identity before publishing that account pending',
    () async {
      await store.savePending(2002, <PendingNewShipAcquisition>[
        PendingNewShipAcquisition(
          key: 'new-account-battle',
          masterIds: <int>[4],
          source: NewShipAcquisitionSource.battle,
          occurredAt: DateTime.utc(2026, 9, 12),
        ),
      ]);
      final started = Completer<void>();
      final release = Completer<void>();
      game.beforeReduce = (event) async {
        if (event.path == '/kcsapi/api_port/port') {
          started.complete();
          await release.future;
        }
      };
      final controller = reminder();
      final events = pipeline(controller);
      events.add(
        kcsapiEvent('/kcsapi/api_port/port', <String, Object?>{
          'api_basic': <String, Object?>{
            'api_member_id': '2002',
            'api_level': 1,
          },
          'api_ship': <Object?>[
            <String, Object?>{'api_id': 401, 'api_ship_id': 4, 'api_lv': 1},
          ],
        }, sequence: 170),
      );
      await started.future;
      await Future<void>.delayed(Duration.zero);
      expect(game.state.memberId, 1001);
      expect(published, isEmpty);
      expect(await store.loadPending(2002), hasLength(1));

      release.complete();
      await events.idle;

      expect(game.state.memberId, 2002);
      expect(published.single.masterIds, <int>[4]);
      expect(await store.loadPending(2002), isEmpty);
    },
  );
}

GameState _accountState(int memberId) => GameState(
  memberId: memberId,
  hasMasterData: true,
  hasPortData: true,
  masterShips: const <int, MasterShip>{
    4: MasterShip(id: 4, name: '三日月', shipTypeId: 2, sortNo: 4),
    5: MasterShip(id: 5, name: '五月雨', shipTypeId: 2, sortNo: 5),
  },
);

CapturedApiEvent _portFor(int memberId, {required int sequence}) =>
    kcsapiEvent('/kcsapi/api_port/port', <String, Object?>{
      'api_basic': <String, Object?>{
        'api_member_id': '$memberId',
        'api_level': 1,
      },
      'api_ship': <Object?>[],
    }, sequence: sequence);

CapturedApiEvent _construction({required int sequence}) =>
    kcsapiEvent('/kcsapi/api_req_kousyou/getship', <String, Object?>{
      'api_ship': <String, Object?>{
        'api_id': 401,
        'api_ship_id': 4,
        'api_lv': 1,
        'api_locked': 0,
      },
    }, sequence: sequence);

/// Mirrors the controller queue and uses the production reducer, without
/// invoking the controller's database recorder or resource snapshot writer.
final class _ReducerConsumer implements GameApiEventConsumer {
  _ReducerConsumer(this.state);

  GameState state;
  Future<void> Function(CapturedApiEvent event)? beforeReduce;
  final GameStateReducer _reducer = GameStateReducer();
  Future<void> _queue = Future<void>.value();

  @override
  bool supportsPath(String path) => _reducer.supportsPath(path);

  @override
  void accept(CapturedApiEvent event) {
    _queue = _queue.then((_) async {
      if (beforeReduce case final wait?) await wait(event);
      state = _reducer.reduce(state, event);
    });
  }

  @override
  Future<void> get idle => _queue;
}

class _DelayedAccountStore extends NewShipReminderStore {
  _DelayedAccountStore(super.preferences);

  final Completer<void> started = Completer<void>();
  final Completer<void> release = Completer<void>();

  @override
  Future<Set<int>> loadExcludedFamilyIds(int memberId) async {
    if (memberId == 1001 && !started.isCompleted) {
      started.complete();
      await release.future;
    }
    return super.loadExcludedFamilyIds(memberId);
  }
}

class _DelayedPendingStore extends NewShipReminderStore {
  _DelayedPendingStore(super.preferences);

  final Completer<void> started = Completer<void>();
  final Completer<void> release = Completer<void>();

  @override
  Future<List<PendingNewShipAcquisition>> loadPending(int memberId) async {
    if (memberId == 1001 && !started.isCompleted) {
      started.complete();
      await release.future;
    }
    return super.loadPending(memberId);
  }
}
