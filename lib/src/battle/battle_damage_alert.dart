import 'package:flutter/services.dart';

import 'battle_models.dart';

enum BattleDamageAlertSeverity { moderate, heavy, postBattleWarning }

abstract interface class BattleDamageAlertPort {
  Future<void> alert(BattleDamageAlertSeverity severity);
}

final class MethodChannelBattleDamageAlertPort
    implements BattleDamageAlertPort {
  const MethodChannelBattleDamageAlertPort([
    this._channel = const MethodChannel(
      'app.yahagi.kancollebrowser/battle_damage_alert',
    ),
  ]);

  final MethodChannel _channel;

  @override
  Future<void> alert(BattleDamageAlertSeverity severity) =>
      _channel.invokeMethod<void>('alert', <String, Object?>{
        'severity': severity.name,
      });
}

BattleDamageAlertSeverity? detectFriendlyDamageAlert({
  required List<BattleShipSnapshot> before,
  required List<BattleShipSnapshot> after,
}) {
  final beforeByKey = <(BattleFleetRole, int), BattleShipSnapshot>{
    for (final ship in before) (ship.fleetRole, ship.position): ship,
  };
  BattleDamageAlertSeverity? strongest;
  for (final ship in after) {
    if (ship.isEscaped) continue;
    final previous = beforeByKey[(ship.fleetRole, ship.position)];
    if (previous == null || ship.currentHp >= previous.currentHp) continue;
    final previousBand = _damageBand(previous.currentHp, previous.maxHp);
    final currentBand = _damageBand(ship.currentHp, ship.maxHp);
    if (currentBand.index <= previousBand.index ||
        currentBand.index < _DamageBand.moderate.index) {
      continue;
    }
    final alert = currentBand == _DamageBand.heavy
        ? BattleDamageAlertSeverity.heavy
        : BattleDamageAlertSeverity.moderate;
    if (alert == BattleDamageAlertSeverity.heavy) return alert;
    strongest = alert;
  }
  return strongest;
}

enum _DamageBand { healthyOrMinor, moderate, heavy }

_DamageBand _damageBand(int currentHp, int maxHp) {
  if (maxHp <= 0) return _DamageBand.healthyOrMinor;
  if (currentHp * 4 <= maxHp) return _DamageBand.heavy;
  if (currentHp * 2 <= maxHp) return _DamageBand.moderate;
  return _DamageBand.healthyOrMinor;
}
