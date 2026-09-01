class DevelopmentSourceMetadata {
  const DevelopmentSourceMetadata({
    required this.repository,
    required this.commit,
    required this.hashes,
  });

  final String repository;
  final String commit;
  final Map<String, String> hashes;
}

const _shipTypeIds = <String, int>{
  'NULL': 0,
  'DE': 1,
  'DD': 2,
  'CL': 3,
  'CLT': 4,
  'CA': 5,
  'CAV': 6,
  'CVL': 7,
  'FBB': 8,
  'BB': 9,
  'BBV': 10,
  'CV': 11,
  '超弩级战列舰': 12,
  'SS': 13,
  'SSV': 14,
  '敌AO': 15,
  'AV': 16,
  'LHA': 17,
  'CVB': 18,
  'AR': 19,
  'AS': 20,
  'CT': 21,
  'AO': 22,
};

Map<String, Object?> buildDevelopmentSnapshot({
  required List<Object?> pools,
  required Map<String, Object?> start2,
  required Map<String, String> ctypeNames,
  required Map<String, Map<String, String>> poolLabels,
  required DevelopmentSourceMetadata source,
  required DateTime generatedAt,
}) {
  if (pools.isEmpty) {
    throw const FormatException('DevelopmentPool.json must not be empty');
  }

  final ships = _parseShips(start2['api_mst_ship']);
  final equipment = _parseEquipment(start2['api_mst_slotitem']);
  final shipOrder = ships.keys.toList(growable: false);
  final chains = _buildShipChains(ships, shipOrder);
  final ctypeIds = <String, int>{};
  for (final entry in ctypeNames.entries) {
    final id = int.tryParse(entry.key);
    if (id != null) ctypeIds.putIfAbsent(entry.value, () => id);
  }

  final outputPools = <Map<String, Object?>>[];
  final poolKeys = <String>{};
  final referencedEquipment = <int>{};

  for (var index = 0; index < pools.length; index++) {
    final raw = _objectMap(pools[index], 'pools[$index]');
    final name = _requiredString(raw, '开发池名称', 'pools[$index]');
    final poolId = _requiredInt(raw, '开发池ID', 'pools[$index]');
    final labels = poolLabels[name];
    if (labels == null ||
        !const {
          'zh',
          'zh_Hant',
          'ja',
        }.every((locale) => labels[locale]?.isNotEmpty == true)) {
      throw FormatException('Missing zh/zh_Hant/ja labels for pool "$name"');
    }

    final key = '$name#$poolId';
    if (!poolKeys.add(key)) {
      throw FormatException('Duplicate development pool key: $key');
    }

    final minimum = _optionalIntList(raw['最低资源'], '最低资源');
    if (minimum != null && minimum.length != 4) {
      throw FormatException(
        '$key has a minimum resource array of length ${minimum.length}',
      );
    }

    final dropRaw = _objectMap(raw['出货率'], '$key.出货率');
    final dropRates = <String, num>{};
    final dropKeys = dropRaw.keys.toList()..sort(_numericStringCompare);
    for (final equipmentKey in dropKeys) {
      final id = int.tryParse(equipmentKey);
      final rate = dropRaw[equipmentKey];
      if (id == null || !equipment.containsKey(id)) {
        throw FormatException(
          '$key references unknown equipment $equipmentKey',
        );
      }
      if (rate is! num || !rate.isFinite) {
        throw FormatException(
          '$key has an invalid rate for equipment $equipmentKey',
        );
      }
      referencedEquipment.add(id);
      dropRates[equipmentKey] = rate;
    }

    final stypes = _optionalStringList(raw['舰种'], '舰种');
    final ctypes = _optionalStringList(raw['舰型'], '舰型');
    final shipNames = _optionalStringList(raw['舰名'], '舰名');
    final directIds = _optionalIntList(raw['舰ID'], '舰ID') ?? <int>[];
    final excludedIds = _optionalIntList(raw['不包含舰ID'], '不包含舰ID') ?? <int>[];
    final expandedIds = <int>[...directIds];

    if (stypes.isNotEmpty) {
      final wanted = stypes
          .map((name) => _shipTypeIds[name])
          .whereType<int>()
          .toSet();
      for (final ship in ships.values) {
        if (ship.id < 1500 && wanted.contains(ship.stype)) {
          expandedIds.add(ship.id);
        }
      }
    }
    if (ctypes.isNotEmpty) {
      final wanted = <int>{};
      for (final value in ctypes) {
        final parsed = int.tryParse(value);
        if (parsed != null) {
          wanted.add(parsed);
        } else if (ctypeIds[value] case final id?) {
          wanted.add(id);
        }
      }
      for (final ship in ships.values) {
        if (ship.id < 1500 && wanted.contains(ship.ctype)) {
          expandedIds.add(ship.id);
        }
      }
    }
    for (final shipName in shipNames) {
      final hit = shipOrder.cast<int?>().firstWhere(
        (id) => id != null && ships[id]?.name == shipName,
        orElse: () => null,
      );
      if (hit == null) break;
      final chain = chains[hit];
      if (chain == null) continue;
      final position = chain.indexOf(hit);
      expandedIds.addAll(chain.skip(position));
    }
    for (final id in excludedIds) {
      expandedIds.remove(id);
    }

    outputPools.add(<String, Object?>{
      'pool_key': key,
      'name': name,
      'labels': _sortedStringMap(labels),
      'pool_id': poolId,
      'ship_ids': expandedIds,
      'minimum_resources': ?minimum,
      'drop_rates': dropRates,
      'criteria': <String, Object?>{
        'ship_types': stypes,
        'class_types': ctypes,
        'ship_names': shipNames,
        'ship_ids': directIds,
        'excluded_ship_ids': excludedIds,
      },
    });
  }

  final compactEquipment = referencedEquipment.toList()..sort();
  final equipmentOutput = compactEquipment
      .map((id) {
        final item = equipment[id]!;
        return <String, Object?>{
          'id': id,
          'name': item.name,
          'type_id': item.typeId,
          'icon_id': item.iconId,
          'minimum_resources': item.broken.map((value) => value * 10).toList(),
        };
      })
      .toList(growable: false);

  final selectable = <Map<String, Object?>>[];
  final seenNames = <String>{};
  for (final pool in outputPools) {
    if ((pool['pool_id'] as int) >= 0 &&
        !pool.containsKey('minimum_resources') &&
        seenNames.add(pool['name']! as String)) {
      selectable.add(pool);
    }
  }
  final secretaries = <Map<String, Object?>>[];
  for (final ship in ships.values.where((ship) => ship.id < 1500)) {
    final matches =
        selectable
            .where((pool) => (pool['ship_ids']! as List<int>).contains(ship.id))
            .toList()
          ..sort((a, b) {
            final byWidth = (a['ship_ids']! as List<int>).length.compareTo(
              (b['ship_ids']! as List<int>).length,
            );
            return byWidth != 0
                ? byWidth
                : (a['pool_key']! as String).compareTo(
                    b['pool_key']! as String,
                  );
          });
    if (matches.isNotEmpty) {
      secretaries.add(<String, Object?>{
        'ship_id': ship.id,
        'pool_key': matches.first['pool_key'],
      });
    }
  }

  final hashes = _sortedStringMap(source.hashes);
  return <String, Object?>{
    'schema_version': 1,
    'generated_at': generatedAt.toUtc().toIso8601String(),
    'source': <String, Object?>{
      'repository': source.repository,
      'commit': source.commit,
      'hashes': hashes,
    },
    'summary': <String, Object?>{
      'pool_count': outputPools.length,
      'selectable_pool_count': selectable.length,
      'equipment_count': equipmentOutput.length,
      'negative_pool_count': outputPools
          .where((p) => (p['pool_id'] as int) < 0)
          .length,
      'minimum_resource_pool_count': outputPools
          .where((p) => p.containsKey('minimum_resources'))
          .length,
    },
    'pools': outputPools,
    'equipment': equipmentOutput,
    'secretaries': secretaries,
  };
}

Map<int, _Ship> _parseShips(Object? raw) {
  if (raw is! List) {
    throw const FormatException('start2.api_mst_ship must be a list');
  }
  final result = <int, _Ship>{};
  for (var index = 0; index < raw.length; index++) {
    final map = _objectMap(raw[index], 'api_mst_ship[$index]');
    final id = _requiredInt(map, 'api_id', 'api_mst_ship[$index]');
    final afterRaw = map['api_aftershipid'];
    final afterId = afterRaw is int ? afterRaw : int.tryParse('$afterRaw') ?? 0;
    result[id] = _Ship(
      id: id,
      name: _requiredString(map, 'api_name', 'api_mst_ship[$index]'),
      stype: _requiredInt(map, 'api_stype', 'api_mst_ship[$index]'),
      ctype: _requiredInt(map, 'api_ctype', 'api_mst_ship[$index]'),
      afterId: afterId,
    );
  }
  return result;
}

Map<int, _Equipment> _parseEquipment(Object? raw) {
  if (raw is! List) {
    throw const FormatException('start2.api_mst_slotitem must be a list');
  }
  final result = <int, _Equipment>{};
  for (var index = 0; index < raw.length; index++) {
    final map = _objectMap(raw[index], 'api_mst_slotitem[$index]');
    final id = _requiredInt(map, 'api_id', 'api_mst_slotitem[$index]');
    final types =
        _optionalIntList(map['api_type'], 'api_type') ?? const <int>[];
    final broken = _optionalIntList(map['api_broken'], 'api_broken');
    if (broken == null || broken.length != 4) {
      throw FormatException('Equipment $id must have four api_broken values');
    }
    result[id] = _Equipment(
      name: _requiredString(map, 'api_name', 'api_mst_slotitem[$index]'),
      typeId: types.length > 2 ? types[2] : 0,
      iconId: types.length > 3 ? types[3] : 0,
      broken: broken,
    );
  }
  return result;
}

Map<int, List<int>> _buildShipChains(Map<int, _Ship> ships, List<int> order) {
  final players = <int, _Ship>{
    for (final id in order)
      if (id < 1500) id: ships[id]!,
  };
  final successors = players.values
      .where((s) => s.afterId != 0)
      .map((s) => s.afterId)
      .toSet();
  final processed = <int>{};
  final chains = <List<int>>[];

  void walk(int current, List<int> chain, Set<int> visited) {
    if (visited.contains(current) ||
        processed.contains(current) ||
        !players.containsKey(current)) {
      return;
    }
    chain.add(current);
    visited.add(current);
    processed.add(current);
    final next = players[current]!.afterId;
    if (next != 0) walk(next, chain, visited);
  }

  for (final id in players.keys) {
    if (successors.contains(id) || processed.contains(id)) {
      continue;
    }
    final chain = <int>[];
    walk(id, chain, <int>{});
    chains.add(chain);
  }
  while (processed.length < players.length) {
    final start = players.keys.firstWhere((id) => !processed.contains(id));
    final cycle = <int>[];
    final seen = <int>{};
    var current = start;
    while (players.containsKey(current) && seen.add(current)) {
      cycle.add(current);
      current = players[current]!.afterId;
    }
    if (cycle.isEmpty) {
      throw FormatException('Unable to expand ship remodel cycle at $start');
    }
    final head = cycle.reduce((a, b) => a > b ? a : b);
    final cycleSet = cycle.toSet();
    final chain = <int>[];
    var cursor = head;
    while (cycleSet.contains(cursor) && !chain.contains(cursor)) {
      chain.add(cursor);
      processed.add(cursor);
      cursor = players[cursor]!.afterId;
    }
    chains.add(chain);
  }
  return <int, List<int>>{
    for (final chain in chains)
      for (final id in chain) id: chain,
  };
}

Map<String, Object?> _objectMap(Object? value, String path) {
  if (value is! Map) throw FormatException('$path must be an object');
  return value.map((key, value) => MapEntry('$key', value));
}

String _requiredString(Map<String, Object?> map, String key, String path) {
  final value = map[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('$path.$key must be a non-empty string');
  }
  return value;
}

int _requiredInt(Map<String, Object?> map, String key, String path) {
  final value = map[key];
  if (value is! int) throw FormatException('$path.$key must be an integer');
  return value;
}

List<int>? _optionalIntList(Object? value, String path) {
  if (value == null) return null;
  if (value is! List || value.any((item) => item is! int)) {
    throw FormatException('$path must be an integer array');
  }
  return value.cast<int>().toList();
}

List<String> _optionalStringList(Object? value, String path) {
  if (value == null) return <String>[];
  if (value is! List || value.any((item) => item is! String)) {
    throw FormatException('$path must be a string array');
  }
  return value.cast<String>().toList();
}

Map<String, String> _sortedStringMap(Map<String, String> input) {
  final keys = input.keys.toList()..sort();
  return <String, String>{for (final key in keys) key: input[key]!};
}

int _numericStringCompare(String a, String b) {
  final left = int.tryParse(a);
  final right = int.tryParse(b);
  if (left != null && right != null) return left.compareTo(right);
  return a.compareTo(b);
}

class _Ship {
  const _Ship({
    required this.id,
    required this.name,
    required this.stype,
    required this.ctype,
    required this.afterId,
  });
  final int id;
  final String name;
  final int stype;
  final int ctype;
  final int afterId;
}

class _Equipment {
  const _Equipment({
    required this.name,
    required this.typeId,
    required this.iconId,
    required this.broken,
  });
  final String name;
  final int typeId;
  final int iconId;
  final List<int> broken;
}
