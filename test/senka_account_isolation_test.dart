import 'dart:convert';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/src/account/account_session.dart';
import 'package:yahagi_kancolle_browser/src/senka/senka_controller.dart';
import 'package:yahagi_kancolle_browser/src/senka/senka_reducer.dart';
import 'package:yahagi_kancolle_browser/src/senka/senka_state.dart';
import 'package:yahagi_kancolle_browser/src/senka/senka_store.dart';

import 'fixtures/kcsapi_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'new identity replaces the old experience baseline and reward ledger',
    () {
      final before = SenkaState.forMonth('2026-08').copyWith(
        memberId: 1001,
        latestExperience: 100000,
        targetSenka: 3500,
        days: const {'2026-08-18': SenkaDayRecord(experience: 123)},
        recordedQuestIds: const {947},
        questStatuses: const {947: SenkaRewardStatus.completed},
      );
      final next = const SenkaReducer().reduce(
        before,
        kcsapiEvent('/kcsapi/api_get_member/basic', <String, Object?>{
          'api_member_id': '2002',
          'api_experience': 1000,
        }, capturedAt: DateTime.utc(2026, 8, 18, 12)),
      );

      expect(next.memberId, 2002);
      expect(next.latestExperience, 1000);
      expect(next.days.values.every((day) => day.experience == 0), isTrue);
      expect(next.recordedQuestIds, isEmpty);
      expect(next.targetSenka, 0);
    },
  );

  test('saving two members retains a separate archive for each', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    final store = SharedPreferencesSenkaStore(preferences);
    await store.save(
      SenkaState.forMonth(
        '2026-08',
      ).copyWith(memberId: 1001, targetSenka: 3500),
    );
    await store.save(
      SenkaState.forMonth('2026-08').copyWith(memberId: 2002, targetSenka: 500),
    );

    final first = preferences.getString('account.1001.senka.archive.v1');
    final second = preferences.getString('account.2002.senka.archive.v1');
    expect(first, isNotNull);
    expect(second, isNotNull);
    expect((jsonDecode(first!) as Map)['targetSenka'], 3500);
    expect((jsonDecode(second!) as Map)['targetSenka'], 500);
  });

  test(
    'startup waits for identity and switching back restores only that member',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final session = AccountSession();
      final store = SharedPreferencesSenkaStore(
        await SharedPreferences.getInstance(),
        accountSession: session,
      );
      await store.save(
        SenkaState.forMonth(
          '2026-08',
        ).copyWith(memberId: 1001, targetSenka: 3500),
      );
      await store.save(
        SenkaState.forMonth(
          '2026-08',
        ).copyWith(memberId: 2002, targetSenka: 500),
      );
      final controller = SenkaController(
        store: store,
        accountSession: session,
        now: () => DateTime.utc(2026, 8, 18),
      );
      addTearDown(controller.dispose);
      addTearDown(session.dispose);
      await controller.initialize();
      expect(controller.state.memberId, 0);
      expect(controller.state.targetSenka, 0);

      session.selectMember(1001);
      await controller.idle;
      expect(controller.state.targetSenka, 3500);
      session.selectMember(2002);
      expect(controller.state.targetSenka, 0);
      await controller.idle;
      expect(controller.state.targetSenka, 500);
      controller.setTargetSenka(600);
      await controller.idle;
      session.reset();
      expect(controller.state.memberId, 0);
      expect(controller.state.targetSenka, 0);
      session.selectMember(1001);
      await controller.idle;
      expect(controller.state.targetSenka, 3500);
      expect((await store.loadForAccount(2002))!.targetSenka, 600);
    },
  );

  test(
    'an old member restore completing late cannot replace the next member',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final session = AccountSession(initialMemberId: 1001);
      final store = _DelayedSenkaAccountStore(
        await SharedPreferences.getInstance(),
        session,
      );
      await store.save(
        SenkaState.forMonth(
          '2026-08',
        ).copyWith(memberId: 1001, targetSenka: 3500),
      );
      await store.save(
        SenkaState.forMonth(
          '2026-08',
        ).copyWith(memberId: 2002, targetSenka: 500),
      );
      final controller = SenkaController(
        store: store,
        accountSession: session,
        now: () => DateTime.utc(2026, 8, 18),
      );
      addTearDown(controller.dispose);
      addTearDown(session.dispose);
      final initialization = controller.initialize();
      await store.started.future;
      session.selectMember(2002);
      expect(controller.state.memberId, 2002);
      store.release.complete();
      await initialization;
      await controller.idle;
      expect(controller.state.memberId, 2002);
      expect(controller.state.targetSenka, 500);
    },
  );

  test('a legacy archive migrates only to its recorded owner', () async {
    final raw = jsonEncode(
      SenkaState.forMonth(
        '2026-08',
      ).copyWith(memberId: 1001, targetSenka: 3500).toJson(),
    );
    SharedPreferences.setMockInitialValues(<String, Object>{
      'senka.archive.v1': raw,
    });
    final preferences = await SharedPreferences.getInstance();
    final store = SharedPreferencesSenkaStore(preferences);
    expect(await store.loadForAccount(2002), isNull);
    expect((await store.loadForAccount(1001))!.targetSenka, 3500);
    expect(preferences.getString('senka.archive.v1'), raw);
    expect(preferences.getString('account.1001.senka.archive.v1'), raw);
    expect(preferences.getString('account.2002.senka.archive.v1'), isNull);
  });

  test(
    'switching away before the save queue runs preserves the last accepted owner edit',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final session = AccountSession(initialMemberId: 1001);
      final store = SharedPreferencesSenkaStore(
        await SharedPreferences.getInstance(),
        accountSession: session,
      );
      await store.save(
        SenkaState.forMonth(
          '2026-08',
        ).copyWith(memberId: 1001, targetSenka: 1000),
      );
      final controller = SenkaController(
        store: store,
        accountSession: session,
        now: () => DateTime.utc(2026, 8, 18),
      );
      addTearDown(() {
        controller.dispose();
        session.dispose();
      });
      await controller.initialize();

      controller.setTargetSenka(3500);
      session.selectMember(2002);
      session.selectMember(1001);
      await controller.idle;

      expect((await store.loadForAccount(1001))!.targetSenka, 3500);
      expect(controller.state.targetSenka, 3500);
      expect(await store.loadForAccount(2002), isNull);
    },
  );

  test(
    'queued saves coalesce within each owner and retain both owners latest edit',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final session = AccountSession(initialMemberId: 1001);
      final store = _CountingSenkaStore(
        await SharedPreferences.getInstance(),
        session,
      );
      final controller = SenkaController(
        store: store,
        accountSession: session,
        now: () => DateTime.utc(2026, 8, 18),
      );
      addTearDown(() {
        controller.dispose();
        session.dispose();
      });
      await controller.initialize();

      controller.setTargetSenka(100);
      controller.setTargetSenka(200);
      session.selectMember(2002);
      controller.setTargetSenka(300);
      controller.setTargetSenka(400);
      session.selectMember(1001);
      await controller.idle;

      expect((await store.loadForAccount(1001))!.targetSenka, 200);
      expect((await store.loadForAccount(2002))!.targetSenka, 400);
      expect(store.writtenOwners, <int>[1001, 2002]);
      expect(controller.state.memberId, 1001);
      expect(controller.state.targetSenka, 200);
    },
  );
}

class _DelayedSenkaAccountStore extends SharedPreferencesSenkaStore {
  _DelayedSenkaAccountStore(super.preferences, AccountSession session)
    : super(accountSession: session);
  final started = Completer<void>();
  final release = Completer<void>();
  @override
  Future<SenkaState?> loadForAccount(int memberId) async {
    if (memberId == 1001 && !started.isCompleted) {
      started.complete();
      await release.future;
    }
    return super.loadForAccount(memberId);
  }
}

class _CountingSenkaStore extends SharedPreferencesSenkaStore {
  _CountingSenkaStore(super.preferences, AccountSession session)
    : super(accountSession: session);
  final writtenOwners = <int>[];
  @override
  Future<void> save(SenkaState state) async {
    writtenOwners.add(state.memberId);
    await super.save(state);
  }
}
