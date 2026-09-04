import 'dart:convert';

typedef LandBaseRaidHp = ({int baseId, int maxHp, int currentHp, int damage});
typedef LandBaseRaidUpdate = ({int airSuperiority, List<LandBaseRaidHp> bases});

/// Both the fleet store and prophet consume the same ordered raid updates.
/// POI prophet accepts an object or an array, and a JSON-encoded air_base_attack.
List<LandBaseRaidUpdate> parseLandBaseRaids(Map<String, Object?> data) {
  final raw = data['api_destruction_battle'];
  final packets = raw is List ? raw : [raw];
  final result = <LandBaseRaidUpdate>[];
  for (final packet in packets) {
    if (packet is! Map) continue;
    Object? attack = packet['api_air_base_attack'];
    if (attack is String) {
      try {
        attack = jsonDecode(attack);
      } on FormatException {
        continue;
      }
    }
    if (attack is! Map) continue;
    final maximum = packet['api_f_maxhps'];
    final initial = packet['api_f_nowhps'];
    if (maximum is! List || initial is! List) continue;
    final stage3 = attack['api_stage3'];
    final rawDamage = stage3 is Map ? stage3['api_fdam'] : null;
    var damage = rawDamage is List ? rawDamage : const [];
    if (damage.length > maximum.length && _number(damage.first) < 0) {
      damage = damage.sublist(1);
    }
    final bases = <LandBaseRaidHp>[];
    for (
      var index = 0;
      index < maximum.length && index < initial.length;
      index++
    ) {
      final maxHp = _number(maximum[index]);
      final nowHp = _number(initial[index], fallback: -1);
      if (maxHp <= 0 || nowHp < 0) continue;
      final lost = index < damage.length
          ? _number(damage[index]).clamp(0, 1 << 30)
          : 0;
      bases.add((
        baseId: index + 1,
        maxHp: maxHp,
        currentHp: (nowHp - lost).clamp(0, maxHp),
        damage: lost,
      ));
    }
    final stage1 = attack['api_stage1'];
    if (bases.isNotEmpty) {
      result.add((
        airSuperiority: _number(
          stage1 is Map ? stage1['api_disp_seiku'] : null,
          fallback: -1,
        ),
        bases: List.unmodifiable(bases),
      ));
    }
  }
  return List.unmodifiable(result);
}

int _number(Object? value, {int fallback = 0}) {
  final number = value is num ? value : num.tryParse(value?.toString() ?? '');
  return number != null && number.isFinite ? number.toInt() : fallback;
}
