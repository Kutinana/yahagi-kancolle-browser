import 'dart:convert';

import 'sortie_map_catalog_manifest.dart';

class SortieMapCatalogData {
  const SortieMapCatalogData({
    required this.version,
    this.schemaVersion = 1,
    this.dataVersion = 'bundled',
    this.revision = 1,
    this.publishedAt,
    required this.source,
    required this.maps,
  });

  factory SortieMapCatalogData.fromJsonString(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Sortie map catalog root must be an object.');
    }
    return SortieMapCatalogData.fromJson(decoded);
  }

  factory SortieMapCatalogData.fromJson(Map<String, dynamic> json) {
    return SortieMapCatalogData(
      version: _requiredInt(json, 'version'),
      schemaVersion: _optionalInt(json, 'schemaVersion') ?? 1,
      dataVersion: _optionalString(json, 'dataVersion') ?? 'bundled',
      revision: _optionalInt(json, 'revision') ?? 1,
      publishedAt: _optionalDate(json, 'publishedAt'),
      source: _requiredString(json, 'source'),
      maps: _objectList(json, 'maps').map(SortieMapInfo.fromJson).toList(),
    );
  }

  final int version;
  final int schemaVersion;
  final String dataVersion;
  final int revision;
  final DateTime? publishedAt;
  final String source;
  final List<SortieMapInfo> maps;

  SortieMapCatalogVersion get versionInfo => SortieMapCatalogVersion(
    label: dataVersion,
    revision: revision,
    publishedAt: publishedAt,
  );
}

class SortieMapInfo {
  const SortieMapInfo({
    required this.id,
    required this.nameJa,
    required this.difficulty,
    required this.coverAsset,
    required this.mapAsset,
    this.mapAspectRatio = 5 / 3,
    required this.source,
    required this.nodes,
  });

  factory SortieMapInfo.fromJson(Map<String, dynamic> json) {
    return SortieMapInfo(
      id: _requiredString(json, 'id'),
      nameJa: _requiredString(json, 'nameJa'),
      difficulty: _requiredInt(json, 'difficulty'),
      coverAsset: _requiredString(json, 'coverAsset'),
      mapAsset: _requiredString(json, 'mapAsset'),
      mapAspectRatio: _optionalPositiveDouble(json, 'mapAspectRatio') ?? 5 / 3,
      source: _optionalString(json, 'source'),
      nodes: _objectList(json, 'nodes').map(SortieMapNode.fromJson).toList(),
    );
  }

  final String id;
  final String nameJa;
  final int difficulty;
  final String coverAsset;
  final String mapAsset;
  final double mapAspectRatio;
  final String? source;
  final List<SortieMapNode> nodes;
}

class SortieMapNode {
  const SortieMapNode({
    required this.point,
    required this.kind,
    required this.typeLabel,
    required this.battleTypeLabel,
    required this.nameJa,
    required this.reward,
    required this.formations,
  });

  factory SortieMapNode.fromJson(Map<String, dynamic> json) {
    return SortieMapNode(
      point: _requiredString(json, 'point'),
      kind: _requiredString(json, 'kind'),
      typeLabel: _requiredString(json, 'typeLabel'),
      battleTypeLabel: _requiredString(json, 'battleTypeLabel'),
      nameJa: _optionalString(json, 'nameJa'),
      reward: _optionalString(json, 'reward'),
      formations: _objectList(
        json,
        'formations',
      ).map(EnemyFormation.fromJson).toList(),
    );
  }

  final String point;
  final String kind;
  final String typeLabel;
  final String battleTypeLabel;
  final String? nameJa;
  final String? reward;
  final List<EnemyFormation> formations;

  bool get isBoss => kind == 'boss';
}

class EnemyFormation {
  const EnemyFormation({
    required this.variant,
    required this.isFinal,
    required this.formation,
    required this.experience,
    required this.airPower,
    this.airSuperiority,
    this.airSupremacy,
    required this.fleetGroups,
    required this.note,
  });

  factory EnemyFormation.fromJson(Map<String, dynamic> json) {
    final rawGroups = json['fleetGroups'];
    if (rawGroups is! List) {
      throw const FormatException('fleetGroups must be a list.');
    }
    final groups = rawGroups.map((rawGroup) {
      if (rawGroup is! List) {
        throw const FormatException('Each fleet group must be a list.');
      }
      return rawGroup.map((rawShip) {
        if (rawShip is! Map<String, dynamic>) {
          throw const FormatException('Each enemy ship must be an object.');
        }
        return EnemyShipEntry.fromJson(rawShip);
      }).toList();
    }).toList();

    return EnemyFormation(
      variant: _requiredInt(json, 'variant'),
      isFinal: json['final'] == true,
      formation: _optionalString(json, 'formation'),
      experience: _optionalInt(json, 'experience'),
      airPower: _optionalInt(json, 'airPower'),
      airSuperiority: _optionalInt(json, 'airSuperiority'),
      airSupremacy: _optionalInt(json, 'airSupremacy'),
      fleetGroups: groups,
      note: _optionalString(json, 'note'),
    );
  }

  final int variant;
  final bool isFinal;
  final String? formation;
  final int? experience;
  final int? airPower;
  final int? airSuperiority;
  final int? airSupremacy;
  final List<List<EnemyShipEntry>> fleetGroups;
  final String? note;

  bool get hasShips => fleetGroups.any((group) => group.isNotEmpty);
}

class EnemyShipEntry {
  const EnemyShipEntry({
    required this.id,
    required this.nameJa,
    required this.nameZh,
  });

  factory EnemyShipEntry.fromJson(Map<String, dynamic> json) {
    return EnemyShipEntry(
      id: _requiredInt(json, 'id'),
      nameJa: _requiredString(json, 'nameJa'),
      nameZh: _optionalString(json, 'nameZh'),
    );
  }

  final int id;
  final String nameJa;
  final String? nameZh;

  String get displayName =>
      nameZh == null || nameZh!.isEmpty ? nameJa : nameZh!;
}

List<Map<String, dynamic>> _objectList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) {
    throw FormatException('$key must be a list.');
  }
  return value.map((item) {
    if (item is! Map<String, dynamic>) {
      throw FormatException('$key must contain objects.');
    }
    return item;
  }).toList();
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw FormatException('$key must be a string.');
  }
  return value;
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) {
    throw FormatException('$key must be a string or null.');
  }
  return value;
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int) {
    throw FormatException('$key must be an integer.');
  }
  return value;
}

int? _optionalInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! int) {
    throw FormatException('$key must be an integer or null.');
  }
  return value;
}

double? _optionalPositiveDouble(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! num) {
    throw FormatException('$key must be a number or null.');
  }
  final parsed = value.toDouble();
  return parsed.isFinite && parsed > 0 ? parsed : null;
}

DateTime? _optionalDate(Map<String, dynamic> json, String key) {
  final value = _optionalString(json, key);
  if (value == null) return null;
  final parsed = DateTime.tryParse(value)?.toUtc();
  if (parsed == null) throw FormatException('$key must be an ISO-8601 date.');
  return parsed;
}
