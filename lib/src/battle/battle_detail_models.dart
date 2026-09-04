/// NPC reinforcements share our attack direction, but never our ship identity.
enum BattleDetailSide { friend, enemy, npc }

enum BattleDetailFleetRole { main, escort }

enum BattleDetailHitKind { miss, hit, critical }

T _enumValue<T extends Enum>(List<T> values, Object? raw, T fallback) {
  final name = raw?.toString();
  return values.where((value) => value.name == name).firstOrNull ?? fallback;
}

int _int(Object? value, [int fallback = 0]) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? fallback;

String _string(Object? value, [String fallback = '']) =>
    value == null ? fallback : value.toString();

Map<String, Object?> _map(Object? value) => value is Map
    ? value.map((key, child) => MapEntry(key.toString(), child))
    : const <String, Object?>{};

List<Object?> _list(Object? value) => value is List ? value : const <Object?>[];

final class BattleDetailEquipment {
  const BattleDetailEquipment({
    required this.masterId,
    required this.name,
    this.improvement = 0,
    this.proficiency = 0,
  });

  final int masterId;
  final String name;
  final int improvement;
  final int proficiency;

  Map<String, Object?> toJson() => <String, Object?>{
    'masterId': masterId,
    'name': name,
    'improvement': improvement,
    'proficiency': proficiency,
  };

  factory BattleDetailEquipment.fromJson(Map<String, Object?> json) =>
      BattleDetailEquipment(
        masterId: _int(json['masterId']),
        name: _string(json['name']),
        improvement: _int(json['improvement']),
        proficiency: _int(json['proficiency']),
      );
}

final class BattleDetailShip {
  const BattleDetailShip({
    required this.name,
    required this.side,
    required this.role,
    required this.position,
    required this.initialHp,
    required this.maxHp,
    required this.finalHp,
    this.masterId = 0,
    this.level,
    this.damageDealt = 0,
    this.damageReceived = 0,
    this.equipment = const <BattleDetailEquipment>[],
    this.escaped = false,
    this.hpUnknown = false,
  });

  final int masterId;
  final String name;
  final BattleDetailSide side;
  final BattleDetailFleetRole role;
  final int position;
  final int? level;
  final int initialHp;
  final int maxHp;
  final int finalHp;
  final int damageDealt;
  final int damageReceived;
  final List<BattleDetailEquipment> equipment;
  final bool escaped;
  final bool hpUnknown;

  Map<String, Object?> toJson() => <String, Object?>{
    'masterId': masterId,
    'name': name,
    'side': side.name,
    'role': role.name,
    'position': position,
    if (level != null) 'level': level,
    'initialHp': initialHp,
    'maxHp': maxHp,
    'finalHp': finalHp,
    'damageDealt': damageDealt,
    'damageReceived': damageReceived,
    'equipment': equipment.map((item) => item.toJson()).toList(),
    'escaped': escaped,
    'hpUnknown': hpUnknown,
  };

  factory BattleDetailShip.fromJson(Map<String, Object?> json) =>
      BattleDetailShip(
        masterId: _int(json['masterId']),
        name: _string(json['name'], '未知舰船'),
        side: _enumValue(
          BattleDetailSide.values,
          json['side'],
          BattleDetailSide.friend,
        ),
        role: _enumValue(
          BattleDetailFleetRole.values,
          json['role'],
          BattleDetailFleetRole.main,
        ),
        position: _int(json['position']),
        level: json['level'] == null ? null : _int(json['level']),
        initialHp: _int(json['initialHp']),
        maxHp: _int(json['maxHp']),
        finalHp: _int(json['finalHp']),
        damageDealt: _int(json['damageDealt']),
        damageReceived: _int(json['damageReceived']),
        equipment: List<BattleDetailEquipment>.unmodifiable(
          _list(
            json['equipment'],
          ).map((item) => BattleDetailEquipment.fromJson(_map(item))),
        ),
        escaped: json['escaped'] == true,
        hpUnknown: json['hpUnknown'] == true,
      );
}

final class BattleDetailFleet {
  const BattleDetailFleet({
    required this.side,
    required this.role,
    this.ships = const <BattleDetailShip>[],
  });

  final BattleDetailSide side;
  final BattleDetailFleetRole role;
  final List<BattleDetailShip> ships;

  Map<String, Object?> toJson() => <String, Object?>{
    'side': side.name,
    'role': role.name,
    'ships': ships.map((ship) => ship.toJson()).toList(),
  };

  factory BattleDetailFleet.fromJson(Map<String, Object?> json) =>
      BattleDetailFleet(
        side: _enumValue(
          BattleDetailSide.values,
          json['side'],
          BattleDetailSide.friend,
        ),
        role: _enumValue(
          BattleDetailFleetRole.values,
          json['role'],
          BattleDetailFleetRole.main,
        ),
        ships: List<BattleDetailShip>.unmodifiable(
          _list(
            json['ships'],
          ).map((ship) => BattleDetailShip.fromJson(_map(ship))),
        ),
      );
}

final class BattleDetailHit {
  const BattleDetailHit({
    required this.damage,
    required this.kind,
    required this.hpAfter,
  });

  final int damage;
  final BattleDetailHitKind kind;
  final int hpAfter;

  Map<String, Object?> toJson() => <String, Object?>{
    'damage': damage,
    'kind': kind.name,
    'hpAfter': hpAfter,
  };

  factory BattleDetailHit.fromJson(Map<String, Object?> json) =>
      BattleDetailHit(
        damage: _int(json['damage']),
        kind: _enumValue(
          BattleDetailHitKind.values,
          json['kind'],
          BattleDetailHitKind.hit,
        ),
        hpAfter: _int(json['hpAfter']),
      );
}

final class BattleDetailAttack {
  const BattleDetailAttack({
    required this.attackerSide,
    required this.attackerName,
    required this.defenderSide,
    required this.defenderName,
    required this.attackType,
    required this.defenderHpBefore,
    required this.defenderHpAfter,
    this.attackerRole,
    this.attackerPosition,
    this.defenderRole,
    this.defenderPosition,
    this.hits = const <BattleDetailHit>[],
    this.damageControlName,
    this.attackTypeCode = 'Normal',
  });

  final BattleDetailSide attackerSide;
  final BattleDetailFleetRole? attackerRole;
  final int? attackerPosition;
  final String attackerName;
  final BattleDetailSide defenderSide;
  final BattleDetailFleetRole? defenderRole;
  final int? defenderPosition;
  final String defenderName;
  final String attackType;

  /// Stable POI type independent of the display language.
  final String attackTypeCode;
  final int defenderHpBefore;
  final int defenderHpAfter;
  final List<BattleDetailHit> hits;
  final String? damageControlName;

  int get totalDamage => hits.fold(0, (total, hit) => total + hit.damage);

  Map<String, Object?> toJson() => <String, Object?>{
    'attackerSide': attackerSide.name,
    if (attackerRole != null) 'attackerRole': attackerRole!.name,
    if (attackerPosition != null) 'attackerPosition': attackerPosition,
    'attackerName': attackerName,
    'defenderSide': defenderSide.name,
    if (defenderRole != null) 'defenderRole': defenderRole!.name,
    if (defenderPosition != null) 'defenderPosition': defenderPosition,
    'defenderName': defenderName,
    'attackType': attackType,
    'attackTypeCode': attackTypeCode,
    'defenderHpBefore': defenderHpBefore,
    'defenderHpAfter': defenderHpAfter,
    'hits': hits.map((hit) => hit.toJson()).toList(),
    if (damageControlName != null) 'damageControlName': damageControlName,
  };

  factory BattleDetailAttack.fromJson(Map<String, Object?> json) =>
      BattleDetailAttack(
        attackerSide: _enumValue(
          BattleDetailSide.values,
          json['attackerSide'],
          BattleDetailSide.friend,
        ),
        attackerRole: json['attackerRole'] == null
            ? null
            : _enumValue(
                BattleDetailFleetRole.values,
                json['attackerRole'],
                BattleDetailFleetRole.main,
              ),
        attackerPosition: json['attackerPosition'] == null
            ? null
            : _int(json['attackerPosition']),
        attackerName: _string(json['attackerName'], '未知攻击方'),
        defenderSide: _enumValue(
          BattleDetailSide.values,
          json['defenderSide'],
          BattleDetailSide.enemy,
        ),
        defenderRole: json['defenderRole'] == null
            ? null
            : _enumValue(
                BattleDetailFleetRole.values,
                json['defenderRole'],
                BattleDetailFleetRole.main,
              ),
        defenderPosition: json['defenderPosition'] == null
            ? null
            : _int(json['defenderPosition']),
        defenderName: _string(json['defenderName'], '未知目标'),
        attackType: _string(json['attackType'], '攻击'),
        attackTypeCode: _string(json['attackTypeCode'], 'Normal'),
        defenderHpBefore: _int(json['defenderHpBefore']),
        defenderHpAfter: _int(json['defenderHpAfter']),
        hits: List<BattleDetailHit>.unmodifiable(
          _list(json['hits']).map((hit) => BattleDetailHit.fromJson(_map(hit))),
        ),
        damageControlName: json['damageControlName']?.toString(),
      );
}

final class BattleDetailStage {
  const BattleDetailStage({
    required this.keyName,
    required this.title,
    this.attacks = const <BattleDetailAttack>[],
  });

  final String keyName;
  final String title;
  final List<BattleDetailAttack> attacks;

  Map<String, Object?> toJson() => <String, Object?>{
    'key': keyName,
    'title': title,
    'attacks': attacks.map((attack) => attack.toJson()).toList(),
  };

  factory BattleDetailStage.fromJson(Map<String, Object?> json) =>
      BattleDetailStage(
        keyName: _string(json['key']),
        title: _string(json['title'], '战斗阶段'),
        attacks: List<BattleDetailAttack>.unmodifiable(
          _list(
            json['attacks'],
          ).map((attack) => BattleDetailAttack.fromJson(_map(attack))),
        ),
      );
}

final class BattleDetailSnapshot {
  const BattleDetailSnapshot({
    this.schemaVersion = 1,
    required this.completedAtMillis,
    required this.mapLabel,
    required this.nodeLabel,
    required this.rank,
    required this.enemyFleetName,
    this.fleets = const <BattleDetailFleet>[],
    this.stages = const <BattleDetailStage>[],
  });

  final int schemaVersion;
  final int completedAtMillis;
  final String mapLabel;
  final String nodeLabel;
  final String rank;
  final String enemyFleetName;
  final List<BattleDetailFleet> fleets;
  final List<BattleDetailStage> stages;

  BattleDetailFleet? fleet(BattleDetailSide side, BattleDetailFleetRole role) =>
      fleets
          .where((fleet) => fleet.side == side && fleet.role == role)
          .firstOrNull;

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'completedAtMillis': completedAtMillis,
    'mapLabel': mapLabel,
    'nodeLabel': nodeLabel,
    'rank': rank,
    'enemyFleetName': enemyFleetName,
    'fleets': fleets.map((fleet) => fleet.toJson()).toList(),
    'stages': stages.map((stage) => stage.toJson()).toList(),
  };

  factory BattleDetailSnapshot.fromJson(Map<String, Object?> json) =>
      BattleDetailSnapshot(
        schemaVersion: _int(json['schemaVersion'], 1),
        completedAtMillis: _int(json['completedAtMillis']),
        mapLabel: _string(json['mapLabel'], '未知海域'),
        nodeLabel: _string(json['nodeLabel'], '节点未知'),
        rank: _string(json['rank'], '—'),
        enemyFleetName: _string(json['enemyFleetName']),
        fleets: List<BattleDetailFleet>.unmodifiable(
          _list(
            json['fleets'],
          ).map((fleet) => BattleDetailFleet.fromJson(_map(fleet))),
        ),
        stages: List<BattleDetailStage>.unmodifiable(
          _list(
            json['stages'],
          ).map((stage) => BattleDetailStage.fromJson(_map(stage))),
        ),
      );
}
