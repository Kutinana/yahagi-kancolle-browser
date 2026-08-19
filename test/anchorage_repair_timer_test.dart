import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';
import 'package:yahagi_kancolle_browser/src/fleet/anchorage_repair_timer.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_reducer.dart';

import 'anchorage_repair_calculator_test.dart' show buildAnchorageTestState;

void main() {
  group('AnchorageRepairTimerTracker', () {
    test('starts when an eligible damaged fleet becomes available', () {
      final tracker = AnchorageRepairTimerTracker();
      final at = DateTime.utc(2026, 8, 6, 10);

      tracker.observe(
        previousState: buildAnchorageTestState(
          facilities: 3,
          flagshipMasterId: 501,
        ),
        nextState: buildAnchorageTestState(facilities: 3),
        event: _event('/kcsapi/api_get_member/ship_deck', at),
      );

      expect(tracker.startedAt, at);
    });

    test('starts when a ready repair fleet is already at full HP', () {
      final tracker = AnchorageRepairTimerTracker();
      final at = DateTime.utc(2026, 8, 6, 10);

      tracker.observe(
        previousState: buildAnchorageTestState(
          facilities: 3,
          flagshipMasterId: 501,
        ),
        nextState: buildAnchorageTestState(facilities: 3, allShipsFull: true),
        event: _event('/kcsapi/api_get_member/ship_deck', at),
      );

      expect(tracker.startedAt, at);
    });

    test('starts for an eligible Asahi Kai repair fleet', () {
      final tracker = AnchorageRepairTimerTracker();
      final at = DateTime.utc(2026, 8, 6, 10);

      tracker.observe(
        previousState: buildAnchorageTestState(
          facilities: 3,
          flagshipMasterId: 501,
        ),
        nextState: buildAnchorageTestState(
          facilities: 1,
          flagshipMasterId: 958,
        ),
        event: _event('/kcsapi/api_get_member/ship_deck', at),
      );

      expect(tracker.startedAt, at);
    });

    test('normal formation change resets the shared timer', () {
      final tracker = AnchorageRepairTimerTracker();
      final startedAt = DateTime.utc(2026, 8, 6, 10);
      final changedAt = startedAt.add(const Duration(minutes: 5));
      tracker.observe(
        previousState: buildAnchorageTestState(
          facilities: 3,
          flagshipMasterId: 501,
        ),
        nextState: buildAnchorageTestState(facilities: 3),
        event: _event('/kcsapi/api_get_member/ship_deck', startedAt),
      );

      tracker.observe(
        previousState: buildAnchorageTestState(facilities: 3),
        nextState: buildAnchorageTestState(facilities: 3),
        event: _event(
          '/kcsapi/api_req_hensei/change',
          changedAt,
          requestParams: const <String, Object?>{'api_id': '1'},
        ),
      );

      expect(tracker.startedAt, changedAt);
    });

    test('formation preset selection does not reset the timer', () {
      final tracker = AnchorageRepairTimerTracker();
      final startedAt = DateTime.utc(2026, 8, 6, 10);
      tracker.observe(
        previousState: buildAnchorageTestState(
          facilities: 3,
          flagshipMasterId: 501,
        ),
        nextState: buildAnchorageTestState(facilities: 3),
        event: _event('/kcsapi/api_get_member/ship_deck', startedAt),
      );

      tracker.observe(
        previousState: buildAnchorageTestState(facilities: 3),
        nextState: buildAnchorageTestState(facilities: 3),
        event: _event(
          '/kcsapi/api_req_hensei/preset_select',
          startedAt.add(const Duration(minutes: 8)),
        ),
      );

      expect(tracker.startedAt, startedAt);
    });

    test('equipment changes do not reset the shared timer', () {
      final tracker = AnchorageRepairTimerTracker();
      final startedAt = DateTime.utc(2026, 8, 6, 10);
      tracker.observe(
        previousState: buildAnchorageTestState(
          facilities: 3,
          flagshipMasterId: 501,
        ),
        nextState: buildAnchorageTestState(facilities: 3),
        event: _event('/kcsapi/api_get_member/ship_deck', startedAt),
      );

      tracker.observe(
        previousState: buildAnchorageTestState(facilities: 3),
        nextState: buildAnchorageTestState(facilities: 3),
        event: _event(
          '/kcsapi/api_req_kaisou/slotset',
          startedAt.add(const Duration(minutes: 8)),
          requestParams: const <String, Object?>{'api_id': '1'},
        ),
      );

      expect(tracker.startedAt, startedAt);
    });

    test('formation changes in another fleet reset the shared global timer', () {
      final tracker = AnchorageRepairTimerTracker();
      final startedAt = DateTime.utc(2026, 8, 6, 10);
      final changedAt = startedAt.add(const Duration(minutes: 7));
      final base = buildAnchorageTestState(facilities: 3);
      final state = base.copyWith(
        fleets: <Fleet>[
          ...base.fleets,
          const Fleet(id: 2, name: '第二舰队', shipIds: <int>[]),
        ],
      );
      tracker.observe(
        previousState: buildAnchorageTestState(
          facilities: 3,
          flagshipMasterId: 501,
        ),
        nextState: state,
        event: _event('/kcsapi/api_get_member/ship_deck', startedAt),
      );

      tracker.observe(
        previousState: state,
        nextState: state,
        event: _event(
          '/kcsapi/api_req_hensei/change',
          changedAt,
          requestParams: const <String, Object?>{
            'api_id': '2',
            'api_ship_idx': '0',
            'api_ship_id': '501',
          },
        ),
      );

      expect(tracker.startedAt, changedAt);
    });

    test('fleet batch unequip (随伴舰一括解除) does not reset the timer', () {
      final tracker = AnchorageRepairTimerTracker();
      final startedAt = DateTime.utc(2026, 8, 6, 10);
      tracker.observe(
        previousState: buildAnchorageTestState(
          facilities: 3,
          flagshipMasterId: 501,
        ),
        nextState: buildAnchorageTestState(facilities: 3),
        event: _event('/kcsapi/api_get_member/ship_deck', startedAt),
      );

      tracker.observe(
        previousState: buildAnchorageTestState(facilities: 3),
        nextState: buildAnchorageTestState(facilities: 3),
        event: _event(
          '/kcsapi/api_req_hensei/change',
          startedAt.add(const Duration(minutes: 8)),
          requestParams: const <String, Object?>{
            'api_id': '1',
            'api_ship_idx': '-1',
            'api_ship_id': '-2',
          },
        ),
      );

      expect(tracker.startedAt, startedAt);
    });

    test('port confirmation after twenty minutes starts the next cycle', () {
      final tracker = AnchorageRepairTimerTracker();
      final startedAt = DateTime.utc(2026, 8, 6, 10);
      final confirmedAt = startedAt.add(const Duration(minutes: 26));
      tracker.observe(
        previousState: buildAnchorageTestState(
          facilities: 3,
          flagshipMasterId: 501,
        ),
        nextState: buildAnchorageTestState(facilities: 3),
        event: _event('/kcsapi/api_get_member/ship_deck', startedAt),
      );

      tracker.observe(
        previousState: buildAnchorageTestState(facilities: 3),
        nextState: buildAnchorageTestState(facilities: 3),
        event: _event('/kcsapi/api_port/port', confirmedAt),
      );

      expect(tracker.startedAt, confirmedAt);
    });

    test('port confirmation keeps timing when every ship is repaired', () {
      final tracker = AnchorageRepairTimerTracker();
      final startedAt = DateTime.utc(2026, 8, 6, 10);
      final confirmedAt = startedAt.add(const Duration(minutes: 26));
      tracker.observe(
        previousState: buildAnchorageTestState(
          facilities: 3,
          flagshipMasterId: 501,
        ),
        nextState: buildAnchorageTestState(facilities: 3),
        event: _event('/kcsapi/api_get_member/ship_deck', startedAt),
      );

      tracker.observe(
        previousState: buildAnchorageTestState(facilities: 3),
        nextState: buildAnchorageTestState(facilities: 3, allShipsFull: true),
        event: _event('/kcsapi/api_port/port', confirmedAt),
      );

      expect(tracker.startedAt, confirmedAt);
    });

    test('clears when no eligible damaged repair fleet remains', () {
      final tracker = AnchorageRepairTimerTracker();
      final startedAt = DateTime.utc(2026, 8, 6, 10);
      tracker.observe(
        previousState: buildAnchorageTestState(
          facilities: 3,
          flagshipMasterId: 501,
        ),
        nextState: buildAnchorageTestState(facilities: 3),
        event: _event('/kcsapi/api_get_member/ship_deck', startedAt),
      );

      tracker.observe(
        previousState: buildAnchorageTestState(facilities: 3),
        nextState: buildAnchorageTestState(
          facilities: 3,
          flagshipMasterId: 501,
        ),
        event: _event(
          '/kcsapi/api_req_hensei/change',
          startedAt.add(const Duration(minutes: 2)),
          requestParams: const <String, Object?>{'api_id': '1'},
        ),
      );

      expect(tracker.startedAt, isNull);
    });
  });

  test('GameStateController exposes the tracked repair start time', () async {
    GameStateController.disableTimerForTest = true;
    final at = DateTime.utc(2026, 8, 6, 10);
    final controller = GameStateController(
      reducer: _StaticReducer(buildAnchorageTestState(facilities: 3)),
    );
    addTearDown(controller.dispose);

    controller.accept(_event('/kcsapi/api_get_member/ship_deck', at));
    await controller.idle;

    expect(controller.anchorageRepairStartedAt, at);
  });
}

CapturedApiEvent _event(
  String path,
  DateTime capturedAt, {
  Map<String, Object?> requestParams = const <String, Object?>{},
}) => CapturedApiEvent(
  path: path,
  requestParams: requestParams,
  responseBody: '{"api_result":1,"api_data":{}}',
  source: CaptureSource.manual,
  capturedAt: capturedAt,
);

class _StaticReducer extends GameStateReducer {
  _StaticReducer(this.nextState);

  final GameState nextState;

  @override
  GameState reduce(GameState state, CapturedApiEvent event) => nextState;
}
