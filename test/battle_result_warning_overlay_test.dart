import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_models.dart';
import 'package:yahagi_kancolle_browser/src/capture/battle_result_warning_overlay.dart';

BattleShipSnapshot _heavyDamageShip() {
  return const BattleShipSnapshot(
    masterId: 1,
    name: 'test',
    side: BattleSide.friend,
    fleetRole: BattleFleetRole.main,
    position: 1,
    initialHp: 20,
    maxHp: 20,
    currentHp: 5,
  );
}

void main() {
  test('boss result has no retreat risk even with a heavily damaged ship', () {
    final battle = LiveBattle(
      context: const BattleContext(node: 5, bossNode: 5),
      friendMain: <BattleShipSnapshot>[_heavyDamageShip()],
      displayStage: BattleDisplayStage.result,
    );

    expect(shouldShowPostBattleWarning(battle), isFalse);
  });

  test('non-boss result keeps the heavily damaged retreat warning', () {
    final battle = LiveBattle(
      context: const BattleContext(node: 4, bossNode: 5),
      friendMain: <BattleShipSnapshot>[_heavyDamageShip()],
      displayStage: BattleDisplayStage.result,
    );

    expect(shouldShowPostBattleWarning(battle), isTrue);
  });
}
