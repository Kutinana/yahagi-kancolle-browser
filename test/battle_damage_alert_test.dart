import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_damage_alert.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_models.dart';

void main() {
  test('alerts only when friendly hp newly crosses a damage threshold', () {
    expect(
      detectFriendlyDamageAlert(
        before: <BattleShipSnapshot>[_ship(hp: 30)],
        after: <BattleShipSnapshot>[_ship(hp: 20)],
      ),
      isNull,
    );
    expect(
      detectFriendlyDamageAlert(
        before: <BattleShipSnapshot>[_ship(hp: 20)],
        after: <BattleShipSnapshot>[_ship(hp: 15)],
      ),
      BattleDamageAlertSeverity.moderate,
    );
    expect(
      detectFriendlyDamageAlert(
        before: <BattleShipSnapshot>[_ship(hp: 15)],
        after: <BattleShipSnapshot>[_ship(hp: 7)],
      ),
      BattleDamageAlertSeverity.heavy,
    );
    expect(
      detectFriendlyDamageAlert(
        before: <BattleShipSnapshot>[_ship(hp: 14)],
        after: <BattleShipSnapshot>[_ship(hp: 10)],
      ),
      isNull,
    );
  });

  test('uses one strongest alert when several ships cross at once', () {
    expect(
      detectFriendlyDamageAlert(
        before: <BattleShipSnapshot>[
          _ship(id: 1, hp: 30),
          _ship(id: 2, hp: 30),
        ],
        after: <BattleShipSnapshot>[_ship(id: 1, hp: 15), _ship(id: 2, hp: 7)],
      ),
      BattleDamageAlertSeverity.heavy,
    );
  });
}

BattleShipSnapshot _ship({int id = 1, required int hp}) => BattleShipSnapshot(
  masterId: id,
  ownedShipId: id,
  name: 'ship-$id',
  side: BattleSide.friend,
  fleetRole: BattleFleetRole.main,
  position: id - 1,
  initialHp: 30,
  maxHp: 30,
  currentHp: hp,
);
