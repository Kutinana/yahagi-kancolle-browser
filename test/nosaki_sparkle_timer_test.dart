import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';
import 'package:yahagi_kancolle_browser/src/fleet/nosaki_sparkle_timer.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';

import 'nosaki_sparkle_calculator_test.dart' show buildNosakiTestState;

void main() {
  group('NosakiSparkleTimerTracker', () {
    test('starts when an eligible Nosaki fleet becomes available', () {
      final tracker = NosakiSparkleTimerTracker();
      final at = DateTime.utc(2026, 8, 19, 10);

      tracker.observe(
        previousState: buildNosakiTestState(flagshipMasterId: 501),
        nextState: buildNosakiTestState(flagshipMasterId: 602),
        event: _event('/kcsapi/api_get_member/ship_deck', at),
      );

      expect(tracker.startedAt, at);
    });

    test('keeps timer running when no ready Nosaki fleet is present', () {
      final tracker = NosakiSparkleTimerTracker();
      final at = DateTime.utc(2026, 8, 19, 10);

      tracker.observe(
        previousState: buildNosakiTestState(flagshipMasterId: 501),
        nextState: buildNosakiTestState(flagshipMasterId: 602),
        event: _event('/kcsapi/api_get_member/ship_deck', at),
      );
      expect(tracker.startedAt, at);

      tracker.observe(
        previousState: buildNosakiTestState(flagshipMasterId: 602),
        nextState: buildNosakiTestState(flagshipMasterId: 501), // No Nosaki
        event: _event(
          '/kcsapi/api_get_member/ship_deck',
          at.add(const Duration(minutes: 5)),
        ),
      );
      // Preserves timestamp
      expect(tracker.startedAt, at);
    });

    test('formation change on a Nosaki fleet resets the timer', () {
      final tracker = NosakiSparkleTimerTracker();
      final startedAt = DateTime.utc(2026, 8, 19, 10);
      final changedAt = startedAt.add(const Duration(minutes: 5));

      tracker.observe(
        previousState: buildNosakiTestState(flagshipMasterId: 501),
        nextState: buildNosakiTestState(flagshipMasterId: 602),
        event: _event('/kcsapi/api_get_member/ship_deck', startedAt),
      );

      tracker.observe(
        previousState: buildNosakiTestState(flagshipMasterId: 602),
        nextState: buildNosakiTestState(flagshipMasterId: 602),
        event: _event(
          '/kcsapi/api_req_hensei/change',
          changedAt,
          requestParams: const <String, Object?>{'api_id': '1'},
        ),
      );

      expect(tracker.startedAt, changedAt);
    });

    test('preset selection does not reset the timer', () {
      final tracker = NosakiSparkleTimerTracker();
      final startedAt = DateTime.utc(2026, 8, 19, 10);
      tracker.observe(
        previousState: buildNosakiTestState(flagshipMasterId: 501),
        nextState: buildNosakiTestState(flagshipMasterId: 602),
        event: _event('/kcsapi/api_get_member/ship_deck', startedAt),
      );

      final presetAt = startedAt.add(const Duration(minutes: 5));
      tracker.observe(
        previousState: buildNosakiTestState(flagshipMasterId: 602),
        nextState: buildNosakiTestState(flagshipMasterId: 602),
        event: _event(
          '/kcsapi/api_req_hensei/preset_select',
          presetAt,
          requestParams: const <String, Object?>{'api_deck_id': '1'},
        ),
      );

      expect(tracker.startedAt, startedAt);
    });

    test('fleet batch unequip (随伴舰一括解除) does not reset the timer', () {
      final tracker = NosakiSparkleTimerTracker();
      final startedAt = DateTime.utc(2026, 8, 19, 10);
      tracker.observe(
        previousState: buildNosakiTestState(flagshipMasterId: 501),
        nextState: buildNosakiTestState(flagshipMasterId: 602),
        event: _event('/kcsapi/api_get_member/ship_deck', startedAt),
      );

      final unequipAt = startedAt.add(const Duration(minutes: 5));
      tracker.observe(
        previousState: buildNosakiTestState(flagshipMasterId: 602),
        nextState: buildNosakiTestState(flagshipMasterId: 602),
        event: _event(
          '/kcsapi/api_req_hensei/change',
          unequipAt,
          requestParams: const <String, Object?>{
            'api_id': '1',
            'api_ship_idx': '-1',
            'api_ship_id': '-2',
          },
        ),
      );

      expect(tracker.startedAt, startedAt);
    });

    test(
      'formation changes in another fleet with Nosaki reset the shared timer',
      () {
        final tracker = NosakiSparkleTimerTracker();
        final startedAt = DateTime.utc(2026, 8, 19, 10);
        final twoFleetsState = GameState(
          fleets: const [
            Fleet(id: 1, name: '第1舰队', shipIds: [1, 2]),
            Fleet(id: 2, name: '第2舰队', shipIds: [3, 4]),
          ],
          ships: const {
            1: OwnedShip(
              id: 1,
              masterId: 602,
              level: 80,
              currentHp: 42,
              maxHp: 42,
              condition: 49,
              currentFuel: 100,
              currentAmmo: 100,
            ),
            2: OwnedShip(
              id: 2,
              masterId: 501,
              level: 80,
              currentHp: 50,
              maxHp: 50,
              condition: 49,
              currentFuel: 100,
              currentAmmo: 100,
            ),
            3: OwnedShip(
              id: 3,
              masterId: 596,
              level: 80,
              currentHp: 42,
              maxHp: 42,
              condition: 49,
              currentFuel: 100,
              currentAmmo: 100,
            ),
            4: OwnedShip(
              id: 4,
              masterId: 502,
              level: 80,
              currentHp: 50,
              maxHp: 50,
              condition: 49,
              currentFuel: 100,
              currentAmmo: 100,
            ),
          },
          masterShips: const {
            501: MasterShip(
              id: 501,
              name: '吹雪',
              shipTypeId: 1,
              maxFuel: 100,
              maxAmmo: 100,
            ),
            502: MasterShip(
              id: 502,
              name: '白雪',
              shipTypeId: 1,
              maxFuel: 100,
              maxAmmo: 100,
            ),
            596: MasterShip(
              id: 596,
              name: '野埼',
              shipTypeId: 1,
              maxFuel: 100,
              maxAmmo: 100,
            ),
            602: MasterShip(
              id: 602,
              name: '野埼改',
              shipTypeId: 1,
              maxFuel: 100,
              maxAmmo: 100,
            ),
          },
        );

        tracker.observe(
          previousState: twoFleetsState,
          nextState: twoFleetsState,
          event: _event('/kcsapi/api_get_member/ship_deck', startedAt),
        );
        expect(tracker.startedAt, startedAt);

        final changeFleet2At = startedAt.add(const Duration(minutes: 6));
        tracker.observe(
          previousState: twoFleetsState,
          nextState: twoFleetsState,
          event: _event(
            '/kcsapi/api_req_hensei/change',
            changeFleet2At,
            requestParams: const <String, Object?>{
              'api_id': '2',
              'api_ship_idx': '1',
              'api_ship_id': '4',
            },
          ),
        );

        // Shared timer resets to the time of the latest modified fleet
        expect(tracker.startedAt, changeFleet2At);
      },
    );

    test('rolls over timer when port event happens at or after 15 minutes', () {
      final tracker = NosakiSparkleTimerTracker();
      final startedAt = DateTime.utc(2026, 8, 19, 10);
      tracker.observe(
        previousState: buildNosakiTestState(flagshipMasterId: 501),
        nextState: buildNosakiTestState(flagshipMasterId: 602),
        event: _event('/kcsapi/api_get_member/ship_deck', startedAt),
      );

      final portAt = startedAt.add(const Duration(minutes: 16));
      tracker.observe(
        previousState: buildNosakiTestState(flagshipMasterId: 602),
        nextState: buildNosakiTestState(flagshipMasterId: 602),
        event: _event('/kcsapi/api_port/port', portAt),
      );

      expect(tracker.startedAt, portAt);
    });

    test('does not roll over before 15 minutes', () {
      final tracker = NosakiSparkleTimerTracker();
      final startedAt = DateTime.utc(2026, 8, 19, 10);
      tracker.observe(
        previousState: buildNosakiTestState(flagshipMasterId: 501),
        nextState: buildNosakiTestState(flagshipMasterId: 602),
        event: _event('/kcsapi/api_get_member/ship_deck', startedAt),
      );

      final portAt = startedAt.add(const Duration(minutes: 10));
      tracker.observe(
        previousState: buildNosakiTestState(flagshipMasterId: 602),
        nextState: buildNosakiTestState(flagshipMasterId: 602),
        event: _event('/kcsapi/api_port/port', portAt),
      );

      expect(tracker.startedAt, startedAt);
    });
  });
}

CapturedApiEvent _event(
  String path,
  DateTime capturedAt, {
  Map<String, Object?> requestParams = const <String, Object?>{},
}) => CapturedApiEvent(
  path: path,
  statusCode: 200,
  responseBody: 'svdata={"api_result":1}',
  capturedAt: capturedAt,
  requestParams: requestParams,
  source: CaptureSource.manual,
);
