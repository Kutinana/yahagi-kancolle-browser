import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';
import 'package:yahagi_kancolle_browser/src/fleet/global_game_timer.dart';
import 'package:yahagi_kancolle_browser/src/fleet/timer_mechanics_service.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';

import 'nosaki_sparkle_calculator_test.dart' show buildNosakiTestState;

void main() {
  final startedAt = DateTime.utc(2026, 9, 20, 10);
  final portAt = startedAt.add(const Duration(minutes: 30));

  TimerMechanicsService refresh(GameState before, GameState after) {
    final service = TimerMechanicsService();
    service.nozakiTimer.reset(startedAt);
    service.observe(
      previousState: before,
      nextState: after,
      event: CapturedApiEvent(
        path: '/kcsapi/api_port/port',
        statusCode: 200,
        responseBody: 'svdata={"api_result":1}',
        capturedAt: portAt,
        source: CaptureSource.manual,
      ),
    );
    return service;
  }

  for (final masterId in [996, 1002]) {
    test('resets after Nozaki $masterId raises the last targets to 54', () {
      final before = buildNosakiTestState(
        flagshipMasterId: masterId,
        companionConds: [52, 53, 54, 54, 54],
      );
      final after = buildNosakiTestState(
        flagshipMasterId: masterId,
        companionConds: [54, 54, 54, 54, 54],
      );

      final service = refresh(before, after);

      expect(service.nozakiTimer.anchorAt, portAt);
      expect(
        service.nozakiTimer.lastResetReason,
        NozakiResetReason.portRefreshSuccess.name,
      );
    });
  }

  test(
    'resets after success even when remaining base targets are fatigued',
    () {
      final before = buildNosakiTestState(
        flagshipMasterId: 996,
        companionConds: [52, 40, 40, 40, 40],
      );
      final after = buildNosakiTestState(
        flagshipMasterId: 996,
        companionConds: [54, 40, 40, 40, 40],
      );

      expect(refresh(before, after).nozakiTimer.anchorAt, portAt);
    },
  );

  for (final cond in [54, 70]) {
    test('resets at port with four companions already at cond $cond', () {
      final state = buildNosakiTestState(
        nosakiCond: 49,
        companionConds: [cond, cond, cond, cond],
      );
      final service = refresh(state, state);

      expect(service.nozakiTimer.anchorAt, portAt);
      expect(
        service.nozakiTimer.lastResetReason,
        NozakiResetReason.portRefreshOtherFailure.name,
      );
      for (final minutes in [1, 14, 15, 30]) {
        final at = portAt.add(Duration(minutes: minutes));
        service.onPortRefresh(state, at, previousState: state);
        expect(service.nozakiTimer.anchorAt, minutes < 15 ? portAt : at);
      }
    });
  }

  test('natural morale recovery below 49 does not imply sparkle success', () {
    final before = buildNosakiTestState(
      flagshipMasterId: 996,
      companionConds: [35, 35, 35, 35, 35],
    );
    final after = buildNosakiTestState(
      flagshipMasterId: 996,
      companionConds: [40, 40, 40, 40, 40],
    );

    expect(refresh(before, after).nozakiTimer.anchorAt, startedAt);
  });

  test('morale increase outside the Nozaki fleet does not reset its timer', () {
    GameState state(int cond) {
      final base = buildNosakiTestState(
        flagshipMasterId: 996,
        companionConds: [40, 40, 40, 40, cond],
      );
      return base.copyWith(
        fleets: const [
          Fleet(id: 1, name: 'Nozaki', shipIds: [1, 2, 3, 4, 5]),
          Fleet(id: 2, name: 'Other', shipIds: [6]),
        ],
      );
    }

    expect(refresh(state(52), state(54)).nozakiTimer.anchorAt, startedAt);
  });

  test('Nozaki herself is not evidence of companion sparkle settlement', () {
    final before = buildNosakiTestState(
      flagshipMasterId: 996,
      nosakiCond: 52,
      companionConds: [40, 40, 40, 40, 40],
    );
    final after = buildNosakiTestState(
      flagshipMasterId: 996,
      nosakiCond: 54,
      companionConds: [40, 40, 40, 40, 40],
    );

    expect(refresh(before, after).nozakiTimer.anchorAt, startedAt);
  });

  test(
    'captured port response resets the controller timer on the final tick',
    () async {
      final before = buildNosakiTestState(companionConds: [52, 52, 52, 52, 52]);
      final service = TimerMechanicsService();
      service.nozakiTimer.reset(startedAt);
      final controller = GameStateController(
        initialState: before,
        timerService: service,
      );
      addTearDown(controller.dispose);
      final body =
          'svdata=${jsonEncode({
            'api_result': 1,
            'api_data': {
              'api_ship': [
                for (final ship in before.ships.values) {'api_id': ship.id, 'api_ship_id': ship.masterId, 'api_lv': ship.level, 'api_nowhp': ship.currentHp, 'api_maxhp': ship.maxHp, 'api_fuel': ship.currentFuel, 'api_bull': ship.currentAmmo, 'api_cond': ship.id == 1 ? ship.condition : 54},
              ],
            },
          })}';

      for (final at in [portAt, portAt.add(const Duration(minutes: 1))]) {
        controller.accept(
          CapturedApiEvent(
            path: '/kcsapi/api_port/port',
            statusCode: 200,
            responseBody: body,
            capturedAt: at,
            source: CaptureSource.manual,
          ),
        );
        await controller.idle;

        expect(controller.lastError, isNull);
        expect(controller.state.ships[2]!.condition, 54);
        expect(controller.nosakiSparkleStartedAt, portAt);
        expect(
          service.nozakiTimer.lastResetReason,
          NozakiResetReason.portRefreshSuccess.name,
        );
      }
    },
  );
}
