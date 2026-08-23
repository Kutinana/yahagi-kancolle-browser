import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/fleet/morale_recovery_display.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';

void main() {
  final now = DateTime.utc(2026, 8, 23, 12);

  test('formats countdowns, recovered fleets, and unavailable data', () {
    GameState state({int condition = 40, List<int> shipIds = const [1]}) =>
        GameState(
          fleets: [Fleet(id: 1, name: '第一舰队', shipIds: shipIds)],
          ships: {
            1: OwnedShip(id: 1, masterId: 1, level: 1, condition: condition),
          },
        );

    expect(
      fleetMoraleRecoveryDisplay(
        state: state(),
        fleetId: 1,
        targetAt: now.add(const Duration(minutes: 8, seconds: 42)),
        now: now,
        recoveredLabel: '已恢复',
        noValueLabel: '—',
      ),
      '08:42',
    );
    expect(
      fleetMoraleRecoveryDisplay(
        state: state(),
        fleetId: 1,
        targetAt: now.add(const Duration(hours: 1, minutes: 2, seconds: 3)),
        now: now,
        recoveredLabel: '已恢复',
        noValueLabel: '—',
      ),
      '1:02:03',
    );
    expect(
      fleetMoraleRecoveryDisplay(
        state: state(condition: 49),
        fleetId: 1,
        targetAt: null,
        now: now,
        recoveredLabel: '已恢复',
        noValueLabel: '—',
      ),
      '已恢复',
    );
    expect(
      fleetMoraleRecoveryDisplay(
        state: state(),
        fleetId: 1,
        targetAt: now,
        now: now,
        recoveredLabel: '已恢复',
        noValueLabel: '—',
      ),
      '已恢复',
    );
    expect(
      fleetMoraleRecoveryDisplay(
        state: state(shipIds: const [1, 2]),
        fleetId: 1,
        targetAt: now.add(const Duration(minutes: 9)),
        now: now,
        recoveredLabel: '已恢复',
        noValueLabel: '—',
      ),
      '—',
    );
  });
}
