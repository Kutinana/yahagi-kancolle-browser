import 'dart:convert';

const int currentImprovementDatasetSchemaVersion = 2;

class ImprovementDatasetVersion {
  const ImprovementDatasetVersion({
    required this.dataVersion,
    required this.commitSha,
  });

  final String dataVersion;
  final String commitSha;

  Map<String, Object> toJson() => <String, Object>{
    'data_version': dataVersion,
    'commit_sha': commitSha,
  };
}

class ImprovementResourceCost {
  const ImprovementResourceCost({
    required this.fuel,
    required this.ammo,
    required this.steel,
    required this.bauxite,
  });

  final int fuel;
  final int ammo;
  final int steel;
  final int bauxite;

  Map<String, Object> toJson() => <String, Object>{
    'fuel': fuel,
    'ammo': ammo,
    'steel': steel,
    'bauxite': bauxite,
  };
}

class ImprovementConsumeItem {
  const ImprovementConsumeItem({
    this.equipmentId,
    this.materialKey,
    this.materialName,
    required this.count,
    this.starFrom,
    this.starTo,
  });

  final int? equipmentId;
  final String? materialKey;
  final String? materialName;
  final int count;
  final int? starFrom;
  final int? starTo;

  bool get isEveryAttempt => starFrom == null && starTo == null;

  Map<String, Object?> toJson() => <String, Object?>{
    'equipment_id': equipmentId,
    'material_key': materialKey,
    'material_name': materialName,
    'count': count,
    'star_from': starFrom,
    'star_to': starTo,
  };
}

class ImprovementStageCost {
  const ImprovementStageCost({
    required this.developmentMin,
    required this.developmentMax,
    required this.improvementMin,
    required this.improvementMax,
    required this.items,
  });

  const ImprovementStageCost.legacy(this.items)
    : developmentMin = 0,
      developmentMax = 0,
      improvementMin = 0,
      improvementMax = 0;

  final int developmentMin;
  final int developmentMax;
  final int improvementMin;
  final int improvementMax;
  final List<ImprovementConsumeItem> items;

  Map<String, Object> toJson() => <String, Object>{
    'development_min': developmentMin,
    'development_max': developmentMax,
    'improvement_min': improvementMin,
    'improvement_max': improvementMax,
    'items': items.map((item) => item.toJson()).toList(),
  };
}

class ImprovementArrangement {
  const ImprovementArrangement({
    required this.secretaryId,
    required this.secretaryLabel,
    required this.weekdays,
    this.routeKind,
    this.note,
  });

  final int? secretaryId;
  final String secretaryLabel;
  final Set<int> weekdays;
  final String? routeKind;
  final String? note;

  Map<String, Object?> toJson() => <String, Object?>{
    'secretary_id': secretaryId,
    'secretary_label': secretaryLabel,
    'weekdays': weekdays.toList()..sort(),
    'route_kind': routeKind,
    'note': note,
  };
}

class ImprovementUpgrade {
  const ImprovementUpgrade({
    required this.targetEquipmentId,
    required this.developmentMin,
    required this.developmentMax,
    required this.improvementMin,
    required this.improvementMax,
    required this.items,
    this.routeKind,
  });

  final int targetEquipmentId;
  final int developmentMin;
  final int developmentMax;
  final int improvementMin;
  final int improvementMax;
  final List<ImprovementConsumeItem> items;
  final String? routeKind;

  Map<String, Object?> toJson() => <String, Object?>{
    'target_equipment_id': targetEquipmentId,
    'development_min': developmentMin,
    'development_max': developmentMax,
    'improvement_min': improvementMin,
    'improvement_max': improvementMax,
    'items': items.map((item) => item.toJson()).toList(),
    'route_kind': routeKind,
  };
}

class ImprovementEntry {
  const ImprovementEntry({
    required this.equipmentId,
    required this.baseCost,
    required this.arrangements,
    required this.stage0,
    required this.stage1,
    required this.upgrades,
  });

  final int equipmentId;
  final ImprovementResourceCost baseCost;
  final List<ImprovementArrangement> arrangements;
  final ImprovementStageCost stage0;
  final ImprovementStageCost stage1;
  final List<ImprovementUpgrade> upgrades;

  Map<String, Object> toJson() => <String, Object>{
    'equipment_id': equipmentId,
    'base_cost': baseCost.toJson(),
    'arrangements': arrangements.map((value) => value.toJson()).toList(),
    'stage0': stage0.toJson(),
    'stage1': stage1.toJson(),
    'upgrades': upgrades.map((value) => value.toJson()).toList(),
  };
}

class ImprovementDataset {
  const ImprovementDataset({
    this.schemaVersion = currentImprovementDatasetSchemaVersion,
    required this.version,
    required this.entries,
  });

  factory ImprovementDataset.parse(String source) {
    final root = _jsonMap(jsonDecode(source), 'root');
    final schemaVersion = root['schema_version'] as int? ?? 1;
    final versionJson = _jsonMap(root['version'], 'version');
    final entries = _jsonList(root['entries'], 'entries')
        .map((value) {
          final row = _jsonMap(value, 'entry');
          final base = _jsonMap(row['base_cost'], 'base_cost');
          ImprovementConsumeItem consume(Object? value) {
            final item = _jsonMap(value, 'consume_item');
            return ImprovementConsumeItem(
              equipmentId: item['equipment_id'] as int?,
              materialKey: item['material_key'] as String?,
              materialName: item['material_name'] as String?,
              count: item['count'] as int,
              starFrom: item['star_from'] as int?,
              starTo: item['star_to'] as int?,
            );
          }

          ImprovementStageCost stage(Object? value, String label) {
            if (value is List) {
              return ImprovementStageCost.legacy(
                value.map(consume).toList(growable: false),
              );
            }
            final stage = _jsonMap(value, label);
            return ImprovementStageCost(
              developmentMin: stage['development_min'] as int,
              developmentMax: stage['development_max'] as int,
              improvementMin: stage['improvement_min'] as int,
              improvementMax: stage['improvement_max'] as int,
              items: _jsonList(
                stage['items'],
                '$label.items',
              ).map(consume).toList(growable: false),
            );
          }

          return ImprovementEntry(
            equipmentId: row['equipment_id'] as int,
            baseCost: ImprovementResourceCost(
              fuel: base['fuel'] as int,
              ammo: base['ammo'] as int,
              steel: base['steel'] as int,
              bauxite: base['bauxite'] as int,
            ),
            arrangements: _jsonList(row['arrangements'], 'arrangements')
                .map((value) {
                  final arrangement = _jsonMap(value, 'arrangement');
                  return ImprovementArrangement(
                    secretaryId: arrangement['secretary_id'] as int?,
                    secretaryLabel: arrangement['secretary_label'] as String,
                    weekdays: Set<int>.unmodifiable(
                      _jsonList(
                        arrangement['weekdays'],
                        'weekdays',
                      ).cast<int>(),
                    ),
                    routeKind: arrangement['route_kind'] as String?,
                    note: arrangement['note'] as String?,
                  );
                })
                .toList(growable: false),
            stage0: stage(row['stage0'], 'stage0'),
            stage1: stage(row['stage1'], 'stage1'),
            upgrades: _jsonList(row['upgrades'], 'upgrades')
                .map((value) {
                  final upgrade = _jsonMap(value, 'upgrade');
                  return ImprovementUpgrade(
                    targetEquipmentId: upgrade['target_equipment_id'] as int,
                    developmentMin: upgrade['development_min'] as int,
                    developmentMax: upgrade['development_max'] as int,
                    improvementMin: upgrade['improvement_min'] as int,
                    improvementMax: upgrade['improvement_max'] as int,
                    items: _jsonList(
                      upgrade['items'],
                      'upgrade.items',
                    ).map(consume).toList(growable: false),
                    routeKind: upgrade['route_kind'] as String?,
                  );
                })
                .toList(growable: false),
          );
        })
        .toList(growable: false);
    return ImprovementDataset(
      schemaVersion: schemaVersion,
      version: ImprovementDatasetVersion(
        dataVersion: versionJson['data_version'] as String,
        commitSha: versionJson['commit_sha'] as String,
      ),
      entries: entries,
    );
  }

  final int schemaVersion;
  final ImprovementDatasetVersion version;
  final List<ImprovementEntry> entries;

  String encode() => jsonEncode(<String, Object>{
    'schema_version': schemaVersion,
    'version': version.toJson(),
    'entries': entries.map((entry) => entry.toJson()).toList(),
  });
}

Map<String, Object?> _jsonMap(Object? value, String label) {
  if (value is! Map) throw FormatException('$label 必须是对象');
  return value.map((key, value) => MapEntry(key.toString(), value));
}

List<Object?> _jsonList(Object? value, String label) {
  if (value is! List) throw FormatException('$label 必须是数组');
  return value;
}
