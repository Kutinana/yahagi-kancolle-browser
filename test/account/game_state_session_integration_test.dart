import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/src/account/account_session.dart';
import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_store.dart';
import 'package:yahagi_kancolle_browser/src/performance/frame_notification_coalescer.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_progress_engine.dart';
import 'package:yahagi_kancolle_browser/src/quest/shared_preferences_quest_store.dart';

import '../fixtures/kcsapi_fixtures.dart';

final _now = DateTime.utc(2026, 9, 12, 9);
const _masters = <int, MasterShip>{
  7: MasterShip(id: 7, name: '三日月', shipTypeId: 2),
  8: MasterShip(id: 8, name: '五月雨', shipTypeId: 2),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late bool previousTimerSetting;

  setUp(() async {
    previousTimerSetting = GameStateController.disableTimerForTest;
    GameStateController.disableTimerForTest = true;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await _seedAccounts();
  });
  tearDown(() {
    GameStateController.disableTimerForTest = previousTimerSetting;
  });

  test(
    'A to B to A restores owned task caches without reviving cached inventory',
    () async {
      final harness = await _Harness.create();
      expect(harness.controller.state.memberId, 0);
      expect(harness.controller.state.quests, isEmpty);
      expect(harness.controller.state.ships, isEmpty);
      expect(
        harness.controller.state.masterShips.keys,
        containsAll(<int>[7, 8]),
      );

      await harness.login(1001);
      expect(harness.controller.state.quests.keys, <int>[201]);
      expect(harness.controller.state.ships, isEmpty);
      await harness.send(_ships(71, 7));
      expect(harness.controller.state.ships.keys, <int>[71]);

      await harness.login(2002);
      expect(harness.controller.state.quests.keys, <int>[202]);
      expect(harness.controller.state.ships, isEmpty);
      await harness.send(_ships(81, 8));
      expect(harness.controller.state.ships.keys, <int>[81]);

      await harness.login(1001);
      expect(harness.controller.state.quests.keys, <int>[201]);
      expect(harness.controller.state.quests[201]!.title, 'Account 1001 task');
      expect(harness.controller.state.ships, isEmpty);
      expect(harness.controller.state.hasPortData, isFalse);
      expect(
        harness.controller.state.masterShips.keys,
        containsAll(<int>[7, 8]),
      );
      expect(harness.controller.lastError, isNull);
    },
  );

  test(
    'logout and start2 synchronously clear personal state and retain shared definitions',
    () async {
      await _seedLedgers();
      final harness = await _Harness.create();
      await harness.login(1001);
      await harness.send(_ships(71, 7));
      expect(harness.controller.completedQuestIds, <int>{901});

      harness.session.reset();
      expect(harness.controller.state.memberId, 0);
      expect(harness.controller.state.ships, isEmpty);
      expect(harness.controller.state.quests, isEmpty);
      expect(harness.controller.completedQuestIds, isEmpty);
      expect(
        harness.controller.state.masterShips.keys,
        containsAll(<int>[7, 8]),
      );

      await harness.login(1001);
      expect(harness.controller.completedQuestIds, <int>{901});
      final start = kcsapiEvent('/kcsapi/api_start2/getData', <String, Object?>{
        'api_mst_ship': <Object?>[
          for (final master in _masters.values)
            <String, Object?>{
              'api_id': master.id,
              'api_name': master.name,
              'api_stype': 2,
            },
        ],
      }, capturedAt: _now);
      harness.dispatch(start);
      expect(harness.controller.state.memberId, 0);
      expect(harness.controller.state.quests, isEmpty);
      expect(harness.controller.completedQuestIds, isEmpty);
      expect(
        harness.controller.state.masterShips.keys,
        containsAll(<int>[7, 8]),
      );
      await harness.controller.idle;
      expect(
        harness.controller.state.masterShips.keys,
        containsAll(<int>[7, 8]),
      );
      expect(
        await PreferencesQuestProgressStorage().read(1001),
        contains('901'),
      );
    },
  );

  test(
    'a delayed account snapshot cannot publish after identity switches',
    () async {
      final cache = _DelayedAccountCache();
      final harness = await _Harness.create(cache: cache);
      addTearDown(() {
        if (!cache.release.isCompleted) cache.release.complete();
      });
      harness.dispatch(_basic(1001));
      await cache.started.future;
      harness.dispatch(_basic(2002));
      expect(harness.controller.state.memberId, isNot(1001));
      cache.release.complete();
      await harness.controller.idle;

      expect(harness.controller.state.memberId, 2002);
      expect(harness.controller.state.quests.keys, <int>[202]);
      expect(harness.controller.state.ships, isEmpty);
      expect(harness.controller.lastError, isNull);
    },
  );

  test(
    'a delayed owner ledger cannot replace the next owner active or claimed tasks',
    () async {
      await _seedLedgers();
      final ledger = _DelayedLedger();
      final harness = await _Harness.create(ledger: ledger);
      addTearDown(() {
        if (!ledger.release.isCompleted) ledger.release.complete();
      });
      harness.dispatch(_basic(1001));
      await ledger.started.future;
      harness.dispatch(_basic(2002));
      expect(harness.controller.completedQuestIds, isEmpty);
      ledger.release.complete();
      await harness.controller.idle;

      expect(harness.controller.state.memberId, 2002);
      expect(harness.controller.state.quests.keys, <int>[202]);
      expect(harness.controller.completedQuestIds, <int>{902});
      expect(harness.controller.lastError, isNull);
      await harness.login(1001);
      expect(harness.controller.state.quests.keys, <int>[201]);
      expect(harness.controller.completedQuestIds, <int>{901});
    },
  );

  test(
    'an old queued inventory event is discarded when the scope changes before reduction',
    () async {
      final harness = await _Harness.create();
      await harness.login(1001);
      harness.controller.accept(_ships(799, 7));
      harness.dispatch(_basic(2002));
      await harness.controller.idle;

      expect(harness.controller.state.memberId, 2002);
      expect(harness.controller.state.ships, isEmpty);
      expect(harness.controller.state.quests.keys, <int>[202]);
      expect(
        harness.controller.lastUpdatedPath,
        '/kcsapi/api_get_member/basic',
      );
    },
  );
}

Future<void> _seedAccounts() async {
  final cache = GameStateStore(saveDelay: const Duration(hours: 1));
  for (final account in <(int, int, int)>[(1001, 201, 7), (2002, 202, 8)]) {
    final (memberId, questId, masterId) = account;
    final quest = _quest(memberId, questId);
    await SharedPreferencesQuestStore(
      memberId: memberId,
    ).saveQuests(<int, GameQuest>{questId: quest});
    cache.save(
      GameState(
        memberId: memberId,
        hasPortData: true,
        hasMasterData: true,
        masterShips: _masters,
        ships: <int, OwnedShip>{
          memberId: OwnedShip(id: memberId, masterId: masterId, level: 1),
        },
        quests: <int, GameQuest>{questId: quest},
      ),
    );
  }
  await cache.flush();
}

GameQuest _quest(int memberId, int id) => GameQuest(
  id: id,
  title: 'Account $memberId task',
  detail: '',
  category: 2,
  type: 4,
  state: 2,
  progressFlag: 0,
  updatedAt: _now,
);

Future<void> _seedLedgers() async {
  final storage = PreferencesQuestProgressStorage();
  for (final account in <(int, int, int)>[(1001, 201, 901), (2002, 202, 902)]) {
    final (memberId, questId, completedId) = account;
    await storage.write(
      memberId,
      jsonEncode(<String, Object?>{
        'account': memberId,
        'records': <String, Object?>{
          '$completedId': <String, Object?>{
            'period': 'once',
            'type': 4,
            'claimed': true,
          },
        },
        'active': <Object?>[
          <String, Object?>{
            'id': questId,
            'title': 'Account $memberId ledger task',
            'detail': '',
            'category': 2,
            'type': 4,
            'state': 2,
            'flag': 0,
            'updated': _now.toIso8601String(),
          },
        ],
      }),
    );
  }
}

CapturedApiEvent _basic(int memberId) => kcsapiEvent(
  '/kcsapi/api_get_member/basic',
  <String, Object?>{'api_member_id': '$memberId', 'api_level': 1},
  capturedAt: _now,
);

CapturedApiEvent _ships(int ownedId, int masterId) =>
    kcsapiEvent('/kcsapi/api_get_member/ship2', <Object?>[
      <String, Object?>{
        'api_id': ownedId,
        'api_ship_id': masterId,
        'api_lv': 1,
        'api_nowhp': 10,
        'api_maxhp': 10,
      },
    ], capturedAt: _now);

class _Harness {
  _Harness(this.session, this.controller);
  final AccountSession session;
  final GameStateController controller;

  static Future<_Harness> create({
    GameStateStore? cache,
    QuestProgressStorage? ledger,
  }) async {
    final session = AccountSession();
    final store = cache ?? GameStateStore(saveDelay: const Duration(hours: 1));
    final controller = GameStateController(
      accountSession: session,
      questStore: SharedPreferencesQuestStore(accountSession: session),
      questProgress: QuestProgressEngine(
        goals: const {},
        storage: ledger ?? PreferencesQuestProgressStorage(),
      ),
      gameStateStore: store,
      captureNotifications: FrameNotificationCoalescer(
        scheduleFrame: scheduleMicrotask,
      ),
    );
    addTearDown(() async {
      await controller.idle;
      controller.dispose();
      await store.flush();
      session.dispose();
    });
    await controller.initialize();
    return _Harness(session, controller);
  }

  void dispatch(CapturedApiEvent event) {
    session.accept(event);
    controller.accept(event);
  }

  Future<void> send(CapturedApiEvent event) async {
    dispatch(event);
    await controller.idle;
  }

  Future<void> login(int memberId) => send(_basic(memberId));
}

class _DelayedAccountCache extends GameStateStore {
  final started = Completer<void>();
  final release = Completer<void>();
  @override
  Future<GameState> loadForAccount(int memberId) async {
    if (memberId == 1001 && !started.isCompleted) {
      started.complete();
      await release.future;
    }
    return super.loadForAccount(memberId);
  }
}

class _DelayedLedger extends PreferencesQuestProgressStorage {
  final started = Completer<void>();
  final release = Completer<void>();
  @override
  Future<String?> read(int account) async {
    if (account == 1001 && !started.isCompleted) {
      started.complete();
      await release.future;
    }
    return super.read(account);
  }
}
