enum ShipDamageLevel { none, healthy, minor, moderate, heavy }

ShipDamageLevel shipDamageLevel({required int currentHp, required int maxHp}) {
  if (currentHp <= 0 || maxHp <= 0) {
    return ShipDamageLevel.none;
  }
  if (currentHp * 4 <= maxHp) {
    return ShipDamageLevel.heavy;
  }
  if (currentHp * 2 <= maxHp) {
    return ShipDamageLevel.moderate;
  }
  if (currentHp * 4 <= maxHp * 3) {
    return ShipDamageLevel.minor;
  }
  return ShipDamageLevel.healthy;
}
