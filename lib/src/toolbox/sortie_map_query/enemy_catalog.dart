// ignore_for_file: prefer_initializing_formals

import 'dart:convert';

import 'package:flutter/services.dart';

import 'sortie_map_models.dart';

final class EnemyCatalogData {
  EnemyCatalogData._({
    required this.rawJson,
    required this.schemaVersion,
    required this.dataVersion,
    required this.revision,
    required this.publishedAt,
    required this.source,
    required this.ships,
    required Map<String, String> aliases,
  }) : _aliases = aliases,
       _byKey = {for (final ship in ships) ship.key: ship};

  factory EnemyCatalogData.fromJsonString(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Enemy catalog root must be an object.');
    }
    final rawShips = decoded['ships'];
    final rawAliases = decoded['aliases'];
    if (rawShips is! List ||
        rawAliases is! Map<String, dynamic> ||
        decoded['quality'] is! Map<String, dynamic>) {
      throw const FormatException('Enemy catalog has invalid collections.');
    }
    final ships = rawShips
        .map((value) {
          if (value is! Map<String, dynamic>) {
            throw const FormatException(
              'Enemy catalog ship must be an object.',
            );
          }
          return EnemyConfiguration.fromJson(value);
        })
        .toList(growable: false);
    if (ships.isEmpty || rawAliases.isEmpty) {
      throw const FormatException(
        'Enemy catalog collections must not be empty.',
      );
    }
    final aliases = rawAliases.map((key, value) {
      if (value is! String) {
        throw const FormatException('Enemy catalog alias must be a string.');
      }
      return MapEntry(key, value);
    });
    final keys = ships.map((ship) => ship.key).toSet();
    if (keys.length != ships.length || !aliases.values.every(keys.contains)) {
      throw const FormatException('Enemy catalog contains invalid references.');
    }
    final schemaVersion = _integer(decoded, 'schemaVersion');
    if (schemaVersion != 1) {
      throw FormatException('Unsupported enemy schema: $schemaVersion');
    }
    final revision = _integer(decoded, 'revision');
    final publishedAt = DateTime.tryParse(_string(decoded, 'publishedAt'));
    if (revision <= 0 || publishedAt == null) {
      throw const FormatException('Enemy catalog version is invalid.');
    }
    return EnemyCatalogData._(
      rawJson: source,
      schemaVersion: schemaVersion,
      dataVersion: _string(decoded, 'dataVersion'),
      revision: revision,
      publishedAt: publishedAt.toUtc(),
      source: _string(decoded, 'source'),
      ships: ships,
      aliases: aliases,
    );
  }

  static Future<EnemyCatalogData> loadAsset() async {
    final data = await rootBundle.load('assets/data/enemy_catalog.json');
    return EnemyCatalogData.fromJsonString(
      utf8.decode(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      ),
    );
  }

  final int schemaVersion;
  final String rawJson;
  final String dataVersion;
  final int revision;
  final DateTime publishedAt;
  final String source;
  final List<EnemyConfiguration> ships;
  final Map<String, String> _aliases;
  final Map<String, EnemyConfiguration> _byKey;

  int get aliasCount => _aliases.length;

  EnemyConfiguration? resolve(EnemyShipEntry entry) {
    final alias = '${entry.id}|${normalizeEnemyName(entry.nameJa)}';
    final key = _aliases[alias];
    return key == null ? null : _byKey[key];
  }
}

String normalizeEnemyName(String value) => value
    .replaceAll('（', '(')
    .replaceAll('）', ')')
    .replaceAll(RegExp(r'[\s・･]'), '')
    .toLowerCase();

final class EnemyConfiguration {
  const EnemyConfiguration({
    required this.key,
    required this.id,
    required this.name,
    this.shipType,
    this.level,
    this.hp,
    this.firepower,
    this.torpedo,
    this.antiAir,
    this.armor,
    this.evasion,
    this.antiSub,
    this.search,
    this.luck,
    this.aircraftCapacity,
    this.speed,
    this.range,
    this.nightCutIn,
    this.note,
    this.detailsUrl,
    required this.equipment,
  });

  factory EnemyConfiguration.fromJson(Map<String, dynamic> json) {
    final id = _integer(json, 'id');
    if (id <= 0) throw const FormatException('Enemy id must be positive.');
    final equipment = _objectList(
      json['equipment'],
    ).map(EnemyEquipment.fromJson).toList(growable: false);
    final slots = equipment.map((item) => item.slot).toSet();
    if (slots.length != equipment.length ||
        slots.any((slot) => slot < 1 || slot > 5)) {
      throw const FormatException('Enemy equipment slots are invalid.');
    }
    return EnemyConfiguration(
      key: _string(json, 'key'),
      id: id,
      name: _string(json, 'name'),
      shipType: _nullableString(json['shipType']),
      level: _nullableNumber(json['level']),
      hp: _nullableNumber(json['hp']),
      firepower: EnemyStat.fromJson(json['firepower']),
      torpedo: EnemyStat.fromJson(json['torpedo']),
      antiAir: EnemyStat.fromJson(json['antiAir']),
      armor: EnemyStat.fromJson(json['armor']),
      evasion: _nullableNumber(json['evasion']),
      antiSub: _nullableNumber(json['antiSub']),
      search: _nullableNumber(json['search']),
      luck: _nullableNumber(json['luck']),
      aircraftCapacity: _nullableNumber(json['aircraftCapacity']),
      speed: _nullableString(json['speed']),
      range: _nullableString(json['range']),
      nightCutIn: _nullableString(json['nightCutIn']),
      note: _nullableString(json['note']),
      detailsUrl: _nullableString(json['detailsUrl']),
      equipment: equipment,
    );
  }

  final String key;
  final int id;
  final String name;
  final String? shipType;
  final num? level;
  final num? hp;
  final EnemyStat? firepower;
  final EnemyStat? torpedo;
  final EnemyStat? antiAir;
  final EnemyStat? armor;
  final num? evasion;
  final num? antiSub;
  final num? search;
  final num? luck;
  final num? aircraftCapacity;
  final String? speed;
  final String? range;
  final String? nightCutIn;
  final String? note;
  final String? detailsUrl;
  final List<EnemyEquipment> equipment;
}

final class EnemyStat {
  const EnemyStat({required this.base, this.equipped});

  static EnemyStat? fromJson(Object? value) {
    if (value == null) return null;
    if (value is! Map<String, dynamic> || value['base'] is! num) {
      throw const FormatException('Enemy stat must contain a numeric base.');
    }
    return EnemyStat(
      base: value['base'] as num,
      equipped: _nullableNumber(value['equipped']),
    );
  }

  final num base;
  final num? equipped;
}

final class EnemyEquipment {
  const EnemyEquipment({
    required this.slot,
    this.key,
    required this.name,
    this.type,
    required this.matched,
    this.stats,
  });

  factory EnemyEquipment.fromJson(Map<String, dynamic> json) {
    final matched = json['matched'];
    final rawStats = json['stats'];
    if (matched is! bool ||
        (rawStats != null && rawStats is! Map<String, dynamic>)) {
      throw const FormatException('Enemy equipment fields are invalid.');
    }
    return EnemyEquipment(
      slot: _integer(json, 'slot'),
      key: _nullableString(json['key']),
      name: _string(json, 'name'),
      type: _nullableString(json['type']),
      matched: matched,
      stats: rawStats is Map<String, dynamic>
          ? EnemyEquipmentStats.fromJson(rawStats)
          : null,
    );
  }

  final int slot;
  final String? key;
  final String name;
  final String? type;
  final bool matched;
  final EnemyEquipmentStats? stats;
}

final class EnemyEquipmentStats {
  const EnemyEquipmentStats({
    this.firepower,
    this.torpedo,
    this.bombing,
    this.antiAir,
    this.antiSub,
    this.search,
    this.accuracy,
    this.evasion,
    this.armor,
    this.range,
  });

  factory EnemyEquipmentStats.fromJson(Map<String, dynamic> json) =>
      EnemyEquipmentStats(
        firepower: _nullableNumber(json['firepower']),
        torpedo: _nullableNumber(json['torpedo']),
        bombing: _nullableNumber(json['bombing']),
        antiAir: _nullableNumber(json['antiAir']),
        antiSub: _nullableNumber(json['antiSub']),
        search: _nullableNumber(json['search']),
        accuracy: _nullableNumber(json['accuracy']),
        evasion: _nullableNumber(json['evasion']),
        armor: _nullableNumber(json['armor']),
        range: _nullableString(json['range']),
      );

  final num? firepower;
  final num? torpedo;
  final num? bombing;
  final num? antiAir;
  final num? antiSub;
  final num? search;
  final num? accuracy;
  final num? evasion;
  final num? armor;
  final String? range;
}

List<Map<String, dynamic>> _objectList(Object? value) {
  if (value is! List) throw const FormatException('Expected a list.');
  return value
      .map((item) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException('Expected an object list.');
        }
        return item;
      })
      .toList(growable: false);
}

String _string(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('$key must be a non-empty string.');
  }
  return value;
}

int _integer(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int) throw FormatException('$key must be an integer.');
  return value;
}

String? _nullableString(Object? value) => value is String && value.isNotEmpty
    ? value
    : value == null || value == ''
    ? null
    : throw const FormatException('Expected a nullable string.');

num? _nullableNumber(Object? value) => value is num
    ? value
    : value == null || value == ''
    ? null
    : throw const FormatException('Expected a nullable number.');
