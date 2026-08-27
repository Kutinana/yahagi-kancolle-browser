import 'battle_models.dart';

final class DamageControlEquipmentRef {
  const DamageControlEquipmentRef({
    required this.instanceId,
    required this.masterId,
  });

  final int instanceId;
  final int masterId;
}

final class SortieDamageControlLedger {
  final Map<int, List<DamageControlEquipmentRef>> _consumed =
      <int, List<DamageControlEquipmentRef>>{};
  bool _active = false;
  bool _trusted = true;
  String? _untrustedReason;

  bool get isActive => _active;
  bool get isTrusted => _trusted;
  String? get untrustedReason => _untrustedReason;

  void beginSortie({bool trusted = true, String? reason}) {
    _consumed.clear();
    _active = true;
    _trusted = trusted;
    _untrustedReason = trusted
        ? null
        : (reason ?? 'cross-node damage-control state is unknown');
  }

  void endSortie() {
    _consumed.clear();
    _active = false;
    _trusted = true;
    _untrustedReason = null;
  }

  void markUntrusted(String reason) {
    if (!_active) return;
    _trusted = false;
    _untrustedReason ??= reason;
  }

  List<int> usedMasterIdsForShip(int shipId) => List<int>.unmodifiable(
    (_consumed[shipId] ?? const <DamageControlEquipmentRef>[]).map(
      (item) => item.masterId,
    ),
  );

  List<DamageControlEquipmentRef> consumptionsForShip(int shipId) =>
      List<DamageControlEquipmentRef>.unmodifiable(
        _consumed[shipId] ?? const <DamageControlEquipmentRef>[],
      );

  List<BattleShipSnapshot> seedFleet(List<BattleShipSnapshot> ships) {
    var changed = false;
    final result = <BattleShipSnapshot>[];
    for (final ship in ships) {
      final shipId = ship.ownedShipId;
      final used = shipId == null
          ? const <int>[]
          : usedMasterIdsForShip(shipId);
      if (used.isEmpty) {
        result.add(ship);
      } else {
        changed = true;
        result.add(ship.copyWith(usedDamageControlItemIds: used));
      }
    }
    return changed ? List.unmodifiable(result) : ships;
  }

  void synchronize({
    required Iterable<BattleShipSnapshot> ships,
    required Map<int, List<DamageControlEquipmentRef>> equipmentByShipId,
  }) {
    if (!_active || !_trusted) return;
    final pending = <int, List<DamageControlEquipmentRef>>{
      for (final entry in _consumed.entries)
        entry.key: List<DamageControlEquipmentRef>.from(entry.value),
    };
    for (final ship in ships) {
      final output = ship.usedDamageControlItemIds;
      if (output.isEmpty) continue;
      final shipId = ship.ownedShipId;
      if (shipId == null) {
        markUntrusted(
          'predicted damage-control consumption has no owned ship ID',
        );
        return;
      }
      final existing = pending.putIfAbsent(
        shipId,
        () => <DamageControlEquipmentRef>[],
      );
      if (!_matchesPrefix(existing, output)) {
        markUntrusted(
          'predicted damage-control sequence conflicts with previous nodes',
        );
        return;
      }
      final equipment =
          equipmentByShipId[shipId] ?? const <DamageControlEquipmentRef>[];
      for (var index = existing.length; index < output.length; index++) {
        final masterId = output[index];
        if (masterId != 42 && masterId != 43) {
          markUntrusted(
            'predicted consumption includes a non-damage-control item',
          );
          return;
        }
        final match = equipment
            .where(
              (item) =>
                  item.masterId == masterId &&
                  !existing.any((used) => used.instanceId == item.instanceId),
            )
            .firstOrNull;
        if (match == null) {
          markUntrusted(
            'no equipment instance matches predicted damage-control consumption',
          );
          return;
        }
        existing.add(match);
      }
    }
    _consumed
      ..clear()
      ..addAll(pending);
  }

  bool _matchesPrefix(
    List<DamageControlEquipmentRef> existing,
    List<int> output,
  ) {
    if (existing.length > output.length) return false;
    for (var index = 0; index < existing.length; index++) {
      if (existing[index].masterId != output[index]) return false;
    }
    return true;
  }
}
