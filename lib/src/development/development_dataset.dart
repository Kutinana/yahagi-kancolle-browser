import 'dart:collection';
import 'dart:convert';

import 'package:flutter/widgets.dart';

import 'development_resources.dart';

class DevelopmentDataset {
  DevelopmentDataset._({
    required this.generatedAt,
    required this.source,
    required Map<String, DevelopmentPoolRecord> poolsByKey,
    required Map<int, DevelopmentEquipmentRecord> equipment,
    required Map<int, DevelopmentSecretaryRecord> secretaries,
    required Map<String, List<DevelopmentPoolRecord>> poolsByName,
  }) : poolsByKey = UnmodifiableMapView(poolsByKey),
       equipment = UnmodifiableMapView(equipment),
       secretaries = UnmodifiableMapView(secretaries),
       poolsByName = UnmodifiableMapView(
         poolsByName.map(
           (key, value) => MapEntry(key, List.unmodifiable(value)),
         ),
       );

  factory DevelopmentDataset.fromJsonString(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException('Snapshot root must be an object');
    }
    return DevelopmentDataset.fromJson(
      decoded.map((key, value) => MapEntry('$key', value)),
    );
  }

  factory DevelopmentDataset.fromJson(Map<String, Object?> json) {
    if (_integer(json['schema_version'], 'schema_version') != 1) {
      throw const FormatException('Unsupported development snapshot schema');
    }
    final generatedAt = DateTime.tryParse(
      _string(json['generated_at'], 'generated_at'),
    );
    if (generatedAt == null) {
      throw const FormatException('generated_at must be an ISO-8601 timestamp');
    }
    final source = DevelopmentDatasetSource.fromJson(
      _map(json['source'], 'source'),
    );

    final equipment = <int, DevelopmentEquipmentRecord>{};
    for (final raw in _list(json['equipment'], 'equipment')) {
      final item = DevelopmentEquipmentRecord.fromJson(
        _map(raw, 'equipment[]'),
      );
      if (equipment[item.id] != null) {
        throw FormatException('Duplicate equipment id ${item.id}');
      }
      equipment[item.id] = item;
    }
    if (equipment.isEmpty) {
      throw const FormatException('equipment must not be empty');
    }

    final poolsByKey = <String, DevelopmentPoolRecord>{};
    final poolsByName = <String, List<DevelopmentPoolRecord>>{};
    for (final raw in _list(json['pools'], 'pools')) {
      final pool = DevelopmentPoolRecord.fromJson(_map(raw, 'pools[]'));
      if (poolsByKey[pool.key] != null) {
        throw FormatException('Duplicate pool key ${pool.key}');
      }
      for (final equipmentId in pool.dropRates.keys) {
        if (!equipment.containsKey(equipmentId)) {
          throw FormatException(
            '${pool.key} references unknown equipment $equipmentId',
          );
        }
      }
      poolsByKey[pool.key] = pool;
      poolsByName
          .putIfAbsent(pool.name, () => <DevelopmentPoolRecord>[])
          .add(pool);
    }
    if (poolsByKey.isEmpty) {
      throw const FormatException('pools must not be empty');
    }

    final secretaries = <int, DevelopmentSecretaryRecord>{};
    for (final raw in _list(json['secretaries'], 'secretaries')) {
      final secretary = DevelopmentSecretaryRecord.fromJson(
        _map(raw, 'secretaries[]'),
      );
      if (!poolsByKey.containsKey(secretary.poolKey)) {
        throw FormatException(
          'Secretary ${secretary.shipId} references unknown pool ${secretary.poolKey}',
        );
      }
      if (secretaries[secretary.shipId] != null) {
        throw FormatException('Duplicate secretary id ${secretary.shipId}');
      }
      secretaries[secretary.shipId] = secretary;
    }

    return DevelopmentDataset._(
      generatedAt: generatedAt.toUtc(),
      source: source,
      poolsByKey: poolsByKey,
      equipment: equipment,
      secretaries: secretaries,
      poolsByName: poolsByName,
    );
  }

  final DateTime generatedAt;
  final DevelopmentDatasetSource source;
  final Map<String, DevelopmentPoolRecord> poolsByKey;
  final Map<int, DevelopmentEquipmentRecord> equipment;
  final Map<int, DevelopmentSecretaryRecord> secretaries;
  final Map<String, List<DevelopmentPoolRecord>> poolsByName;

  Iterable<DevelopmentPoolRecord> get pools => poolsByKey.values;
  Iterable<DevelopmentPoolRecord> get selectablePools {
    final names = <String>{};
    return pools.where((pool) => pool.isSelectable && names.add(pool.name));
  }

  DevelopmentPoolRecord pool(String key) {
    final value = poolsByKey[key];
    if (value == null) throw StateError('Unknown development pool: $key');
    return value;
  }
}

class DevelopmentDatasetSource {
  DevelopmentDatasetSource({
    required this.repository,
    required this.commit,
    required Map<String, String> hashes,
  }) : hashes = UnmodifiableMapView(hashes);

  factory DevelopmentDatasetSource.fromJson(Map<String, Object?> json) {
    final hashes = <String, String>{};
    for (final entry in _map(json['hashes'], 'source.hashes').entries) {
      hashes[entry.key] = _string(entry.value, 'source.hashes.${entry.key}');
    }
    return DevelopmentDatasetSource(
      repository: _string(json['repository'], 'source.repository'),
      commit: _string(json['commit'], 'source.commit'),
      hashes: hashes,
    );
  }

  final String repository;
  final String commit;
  final Map<String, String> hashes;
}

class DevelopmentPoolRecord {
  DevelopmentPoolRecord({
    required this.key,
    required this.name,
    required Map<String, String> labels,
    required this.poolId,
    required List<int> shipIds,
    required this.minimumResources,
    required Map<int, double> dropRates,
    required this.criteria,
  }) : labels = UnmodifiableMapView(labels),
       shipIds = List.unmodifiable(shipIds),
       shipIdSet = Set.unmodifiable(shipIds),
       dropRates = UnmodifiableMapView(dropRates);

  factory DevelopmentPoolRecord.fromJson(Map<String, Object?> json) {
    final labels = <String, String>{};
    for (final entry in _map(json['labels'], 'pool.labels').entries) {
      labels[entry.key] = _string(entry.value, 'pool.labels.${entry.key}');
    }
    for (final locale in const ['zh', 'zh_Hant', 'ja']) {
      if (labels[locale]?.isNotEmpty != true) {
        throw FormatException('Pool is missing label $locale');
      }
    }
    final minimumRaw = json['minimum_resources'];
    return DevelopmentPoolRecord(
      key: _string(json['pool_key'], 'pool.pool_key'),
      name: _string(json['name'], 'pool.name'),
      labels: labels,
      poolId: _integer(json['pool_id'], 'pool.pool_id'),
      shipIds: _integerList(json['ship_ids'], 'pool.ship_ids'),
      minimumResources: minimumRaw == null
          ? null
          : _resources(minimumRaw, 'pool.minimum_resources'),
      dropRates: _rates(json['drop_rates']),
      criteria: DevelopmentPoolCriteria.fromJson(
        _map(json['criteria'], 'pool.criteria'),
      ),
    );
  }

  final String key;
  final String name;
  final Map<String, String> labels;
  final int poolId;
  final List<int> shipIds;
  final Set<int> shipIdSet;
  final DevelopmentResources? minimumResources;
  final Map<int, double> dropRates;
  final DevelopmentPoolCriteria criteria;

  bool get isSelectable => poolId >= 0 && minimumResources == null;

  String label(Locale locale) {
    if (locale.languageCode == 'ja') return labels['ja']!;
    final traditional =
        locale.languageCode == 'zh' &&
        (locale.scriptCode == 'Hant' ||
            const {'TW', 'HK', 'MO'}.contains(locale.countryCode));
    return labels[traditional ? 'zh_Hant' : 'zh']!;
  }
}

class DevelopmentPoolCriteria {
  DevelopmentPoolCriteria({
    required List<String> shipTypes,
    required List<String> classTypes,
    required List<String> shipNames,
    required List<int> shipIds,
    required List<int> excludedShipIds,
  }) : shipTypes = List.unmodifiable(shipTypes),
       classTypes = List.unmodifiable(classTypes),
       shipNames = List.unmodifiable(shipNames),
       shipIds = List.unmodifiable(shipIds),
       excludedShipIds = List.unmodifiable(excludedShipIds);

  factory DevelopmentPoolCriteria.fromJson(Map<String, Object?> json) =>
      DevelopmentPoolCriteria(
        shipTypes: _stringList(json['ship_types'], 'criteria.ship_types'),
        classTypes: _stringList(json['class_types'], 'criteria.class_types'),
        shipNames: _stringList(json['ship_names'], 'criteria.ship_names'),
        shipIds: _integerList(json['ship_ids'], 'criteria.ship_ids'),
        excludedShipIds: _integerList(
          json['excluded_ship_ids'],
          'criteria.excluded_ship_ids',
        ),
      );

  final List<String> shipTypes;
  final List<String> classTypes;
  final List<String> shipNames;
  final List<int> shipIds;
  final List<int> excludedShipIds;
}

class DevelopmentEquipmentRecord {
  const DevelopmentEquipmentRecord({
    required this.id,
    required this.name,
    required this.typeId,
    this.iconId = 0,
    required this.minimumResources,
  });

  factory DevelopmentEquipmentRecord.fromJson(Map<String, Object?> json) =>
      DevelopmentEquipmentRecord(
        id: _integer(json['id'], 'equipment.id'),
        name: _string(json['name'], 'equipment.name'),
        typeId: _integer(json['type_id'], 'equipment.type_id'),
        iconId: json['icon_id'] == null
            ? _integer(json['type_id'], 'equipment.type_id')
            : _integer(json['icon_id'], 'equipment.icon_id'),
        minimumResources: _resources(
          json['minimum_resources'],
          'equipment.minimum_resources',
        ),
      );

  final int id;
  final String name;
  final int typeId;
  final int iconId;
  final DevelopmentResources minimumResources;
}

class DevelopmentSecretaryRecord {
  const DevelopmentSecretaryRecord({
    required this.shipId,
    required this.poolKey,
  });

  factory DevelopmentSecretaryRecord.fromJson(Map<String, Object?> json) =>
      DevelopmentSecretaryRecord(
        shipId: _integer(json['ship_id'], 'secretary.ship_id'),
        poolKey: _string(json['pool_key'], 'secretary.pool_key'),
      );

  final int shipId;
  final String poolKey;
}

Map<int, double> _rates(Object? raw) {
  final result = <int, double>{};
  for (final entry in _map(raw, 'pool.drop_rates').entries) {
    final id = int.tryParse(entry.key);
    final value = entry.value;
    if (id == null || value is! num || !value.isFinite) {
      throw FormatException('Invalid drop rate ${entry.key}: $value');
    }
    result[id] = value.toDouble();
  }
  return result;
}

DevelopmentResources _resources(Object? raw, String path) {
  final values = _integerList(raw, path);
  if (values.length != 4) {
    throw FormatException('$path must contain four values');
  }
  if (values.any((value) => value < 0)) {
    throw FormatException('$path must not contain negative values');
  }
  return DevelopmentResources(values[0], values[1], values[2], values[3]);
}

Map<String, Object?> _map(Object? raw, String path) {
  if (raw is! Map) throw FormatException('$path must be an object');
  return raw.map((key, value) => MapEntry('$key', value));
}

List<Object?> _list(Object? raw, String path) {
  if (raw is! List) throw FormatException('$path must be an array');
  return raw.cast<Object?>();
}

List<int> _integerList(Object? raw, String path) =>
    _list(raw, path).map((value) => _integer(value, '$path[]')).toList();

List<String> _stringList(Object? raw, String path) =>
    _list(raw, path).map((value) => _string(value, '$path[]')).toList();

String _string(Object? raw, String path) {
  if (raw is! String || raw.isEmpty) {
    throw FormatException('$path must be a non-empty string');
  }
  return raw;
}

int _integer(Object? raw, String path) {
  if (raw is! int) throw FormatException('$path must be an integer');
  return raw;
}
