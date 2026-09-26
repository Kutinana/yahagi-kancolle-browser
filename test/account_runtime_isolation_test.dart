import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/account/account_session.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_controller.dart';
import 'package:yahagi_kancolle_browser/src/battle/prediction/battle_prediction_engine.dart';
import 'package:yahagi_kancolle_browser/src/battle/prediction/battle_prediction_executor.dart';
import 'package:yahagi_kancolle_browser/src/fleet/timer_mechanics_service.dart';
import 'package:yahagi_kancolle_browser/src/fleet/morale_recovery_timer_controller.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_reducer.dart';
import 'fixtures/kcsapi_fixtures.dart';
import 'anchorage_repair_calculator_test.dart' show buildAnchorageTestState;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('account change starts fresh global timer anchors', () {
    final service = TimerMechanicsService();
    final old = buildAnchorageTestState(facilities: 1).copyWith(memberId: 1001);
    final next = old.copyWith(memberId: 2002);
    final start = DateTime.utc(2026, 9, 12, 1);
    service.akashiTimer.reset(start);
    service.nozakiTimer.reset(start);
    final switchedAt = start.add(const Duration(minutes: 5));
    service.observe(
      previousState: old,
      nextState: next,
      event: kcsapiEvent('/kcsapi/api_port/port', {}, capturedAt: switchedAt),
    );
    expect(service.akashiTimer.anchorAt, switchedAt);
    expect(service.nozakiTimer.anchorAt, switchedAt);
  });

  test('same fleet IDs and morale cannot reuse another account target', () {
    final timer = MoraleRecoveryTimerController();
    addTearDown(timer.dispose);
    final first = buildAnchorageTestState(
      facilities: 1,
    ).copyWith(memberId: 1001, updatedAt: DateTime.utc(2026, 9, 12, 1));
    final ships = {
      for (final ship in first.ships.values)
        ship.id: OwnedShip(
          id: ship.id,
          masterId: ship.masterId,
          level: 1,
          currentHp: 10,
          maxHp: 10,
          condition: 40,
          currentFuel: 1,
          currentAmmo: 1,
          slotIds: const [],
        ),
    };
    final old = first.copyWith(ships: ships);
    timer.reconcile(old);
    final oldTarget = timer.targetForFleet(1)!;
    timer.reconcile(
      old.copyWith(
        memberId: 2002,
        updatedAt: old.updatedAt!.add(const Duration(minutes: 5)),
      ),
    );
    expect(timer.targetForFleet(1), oldTarget.add(const Duration(minutes: 5)));
  });

  test('login clears battle records from the previous account', () async {
    final reducer = GameStateReducer();
    var state = reducer.reduce(GameState.empty, start2Event);
    state = reducer.reduce(state, portEvent).copyWith(memberId: 1001);
    final battle = BattleController(gameState: () => state);
    addTearDown(battle.dispose);
    battle
      ..accept(mapStartEvent)
      ..accept(dayBattleEvent)
      ..accept(battleResultEvent);
    await battle.idle;
    expect(battle.records, isNotEmpty);
    state = reducer.reduce(state, start2Event);
    battle.accept(kcsapiEvent('/kcsapi/api_start2/getData', {}, sequence: 999));
    await battle.idle;
    expect(battle.records, isEmpty);
    expect(battle.recentSessions, isEmpty);
  });

  test(
    'switching accounts synchronously clears battle and restores own history',
    () async {
      final reducer = GameStateReducer();
      var state = reducer
          .reduce(reducer.reduce(GameState.empty, start2Event), portEvent)
          .copyWith(memberId: 1001);
      final session = AccountSession(initialMemberId: 1001);
      final battle = BattleController(
        gameState: () => state,
        accountSession: session,
      );
      addTearDown(battle.dispose);
      addTearDown(session.dispose);
      battle
        ..accept(mapStartEvent)
        ..accept(dayBattleEvent)
        ..accept(battleResultEvent);
      await battle.idle;
      final record = battle.records.single;
      session.selectMember(2002);
      expect(battle.current, isNull);
      expect(battle.records, isEmpty);
      expect(battle.recentSessions, isEmpty);
      state = state.copyWith(memberId: 2002);
      session.selectMember(1001);
      expect(battle.records, [record]);
      expect(battle.current, isNull);
      expect(battle.session, isNull);
    },
  );

  test('old prediction cannot update new-account HP after an await', () async {
    final reducer = GameStateReducer();
    var state = reducer
        .reduce(reducer.reduce(GameState.empty, start2Event), portEvent)
        .copyWith(memberId: 1001);
    final session = AccountSession(initialMemberId: 1001);
    final executor = _DelayedPredictionExecutor();
    final hpUpdates = <Map<int, int>>[];
    final battle = BattleController(
      gameState: () => state,
      accountSession: session,
      predictionExecutor: executor,
      onFriendlyHpUpdated: (hp, _) => hpUpdates.add(hp),
    );
    addTearDown(battle.dispose);
    addTearDown(session.dispose);
    battle
      ..accept(mapStartEvent)
      ..accept(dayBattleEvent);
    await executor.started.future;
    hpUpdates.clear();
    session.selectMember(2002);
    state = state.copyWith(memberId: 2002);
    executor.release.complete();
    await battle.idle;
    expect(hpUpdates, isEmpty);
    expect(battle.current, isNull);
    expect(battle.session, isNull);
    expect(battle.lastError, isNull);
  });
}

final class _DelayedPredictionExecutor implements BattlePredictionExecutor {
  final started = Completer<void>();
  final release = Completer<void>();
  @override
  Future<BattlePredictionAppendResult> append({
    required BattlePredictionEngine engine,
    required String path,
    required Map<String, Object?> data,
  }) async {
    started.complete();
    await release.future;
    return (engine: engine, prediction: engine.append(path: path, data: data));
  }
}
