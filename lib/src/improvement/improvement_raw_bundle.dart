import 'dart:convert';

import 'improvement_dataset.dart';

class ImprovementRawBundle {
  ImprovementRawBundle._(this._files, this._manifest, this.commitSha);

  static const List<String> dataFiles = <String>[
    'equip_base_cost.json',
    'equipment_upgrade_path.json',
    'improvement_arrangement.json',
    'improvement_consume_item.json',
    'improvement_consume_step.json',
    'improvement_upgrade_cost.json',
    'improvement_upgrade_target.json',
    'material.json',
  ];
  static const Set<String> allowedFiles = <String>{
    'data_manifest.json',
    ...dataFiles,
  };

  final Map<String, Object?> _files;
  final Map<String, Object?> _manifest;
  final String commitSha;

  static ImprovementRawBundle parse(
    Map<String, String> source, {
    String commitSha = '',
  }) {
    if (source.keys.toSet().difference(allowedFiles).isNotEmpty ||
        !allowedFiles.every(source.containsKey)) {
      throw const FormatException('改修资料文件清单不符合预期');
    }
    if (commitSha.isNotEmpty &&
        !RegExp(r'^[0-9a-f]{40}$').hasMatch(commitSha)) {
      throw const FormatException('提交号格式错误');
    }
    final decoded = <String, Object?>{};
    for (final entry in source.entries) {
      try {
        decoded[entry.key] = jsonDecode(entry.value);
      } on FormatException {
        throw FormatException('${entry.key} 不是有效 JSON');
      }
    }
    final manifest = _map(decoded['data_manifest.json'], 'data_manifest.json');
    if (manifest['version_complete'] != true) {
      throw const FormatException('远程资料版本尚未完成');
    }
    final files = _list(
      manifest['files'],
      'manifest.files',
    ).map((value) => value.toString()).toList();
    if (files.length != dataFiles.length ||
        files.toSet().length != dataFiles.length ||
        !dataFiles.every(files.contains)) {
      throw const FormatException('manifest 文件白名单不匹配');
    }
    final bundle = ImprovementRawBundle._(decoded, manifest, commitSha);
    bundle._validate();
    return bundle;
  }

  ImprovementDataset normalize() {
    final baseRows = _rows('equip_base_cost.json');
    final arrangementRows = _rows('improvement_arrangement.json');
    final stepRows = _rows('improvement_consume_step.json');
    final itemRows = _rows('improvement_consume_item.json');
    final targetRows = _rows('improvement_upgrade_target.json');
    final upgradeCostRows = _rows('improvement_upgrade_cost.json');
    final materialNames = <String, String>{
      for (final row in _rows('material.json'))
        _string(row, 'key'): _string(row, 'name'),
    };

    final itemsByStep = <String, List<ImprovementConsumeItem>>{};
    for (final row in itemRows) {
      itemsByStep
          .putIfAbsent(
            _string(row, 'step_id'),
            () => <ImprovementConsumeItem>[],
          )
          .add(_consumeItem(row, materialNames));
    }
    final stageItems = <int, Map<int, List<ImprovementConsumeItem>>>{};
    for (final row in stepRows) {
      final equipmentId = _positiveInt(row, 'equipment_id');
      final step = _nonNegativeInt(row, 'step_id');
      stageItems.putIfAbsent(
        equipmentId,
        () => <int, List<ImprovementConsumeItem>>{},
      )[step] = List<ImprovementConsumeItem>.unmodifiable(
        itemsByStep[_string(row, 'id')] ?? const <ImprovementConsumeItem>[],
      );
    }
    final arrangements = <int, List<ImprovementArrangement>>{};
    for (final row in arrangementRows) {
      final weekdays = <int>{
        if (_bool(row, 'monday')) DateTime.monday,
        if (_bool(row, 'tuesday')) DateTime.tuesday,
        if (_bool(row, 'wednesday')) DateTime.wednesday,
        if (_bool(row, 'thursday')) DateTime.thursday,
        if (_bool(row, 'friday')) DateTime.friday,
        if (_bool(row, 'saturday')) DateTime.saturday,
        if (_bool(row, 'sunday')) DateTime.sunday,
      };
      arrangements
          .putIfAbsent(
            _positiveInt(row, 'equipment_id'),
            () => <ImprovementArrangement>[],
          )
          .add(
            ImprovementArrangement(
              secretaryId: _nullableInt(row['secretary_id']),
              secretaryLabel:
                  _nullableString(row['secretary_label']) ??
                  (_nullableInt(row['secretary_id']) == null
                      ? '—'
                      : '#${_nullableInt(row['secretary_id'])}'),
              weekdays: Set<int>.unmodifiable(weekdays),
              routeKind: _nullableString(row['route_kind']),
              note: _nullableString(row['note']),
            ),
          );
    }
    final costsByUpgrade = <String, List<ImprovementConsumeItem>>{};
    for (final row in upgradeCostRows) {
      costsByUpgrade
          .putIfAbsent(_upgradeKey(row), () => <ImprovementConsumeItem>[])
          .add(_consumeItem(row, materialNames));
    }
    final upgrades = <int, List<ImprovementUpgrade>>{};
    for (final row in targetRows) {
      final equipmentId = _positiveInt(row, 'equipment_id');
      upgrades
          .putIfAbsent(equipmentId, () => <ImprovementUpgrade>[])
          .add(
            ImprovementUpgrade(
              targetEquipmentId: _positiveInt(row, 'upgrade_id'),
              developmentMin: _nonNegativeInt(row, 'consume_development_min'),
              developmentMax: _nonNegativeInt(row, 'consume_development_max'),
              improvementMin: _nonNegativeInt(row, 'consume_improvement_min'),
              improvementMax: _nonNegativeInt(row, 'consume_improvement_max'),
              items: List<ImprovementConsumeItem>.unmodifiable(
                costsByUpgrade[_upgradeKey(row)] ??
                    const <ImprovementConsumeItem>[],
              ),
              routeKind: _nullableString(row['route_kind']),
            ),
          );
    }
    final entries = <ImprovementEntry>[
      for (final row in baseRows)
        ImprovementEntry(
          equipmentId: _positiveInt(row, 'id'),
          baseCost: ImprovementResourceCost(
            fuel: _nonNegativeInt(row, 'consume_fuel'),
            ammo: _nonNegativeInt(row, 'consume_ammo'),
            steel: _nonNegativeInt(row, 'consume_steel'),
            bauxite: _nonNegativeInt(row, 'consume_bauxite'),
          ),
          arrangements: List<ImprovementArrangement>.unmodifiable(
            arrangements[_positiveInt(row, 'id')] ??
                const <ImprovementArrangement>[],
          ),
          stage0:
              stageItems[_positiveInt(row, 'id')]?[0] ??
              const <ImprovementConsumeItem>[],
          stage1:
              stageItems[_positiveInt(row, 'id')]?[1] ??
              const <ImprovementConsumeItem>[],
          upgrades: List<ImprovementUpgrade>.unmodifiable(
            upgrades[_positiveInt(row, 'id')] ?? const <ImprovementUpgrade>[],
          ),
        ),
    ]..sort((a, b) => a.equipmentId.compareTo(b.equipmentId));
    return ImprovementDataset(
      version: ImprovementDatasetVersion(
        dataVersion: _string(_manifest, 'data_version'),
        commitSha: commitSha,
      ),
      entries: List<ImprovementEntry>.unmodifiable(entries),
    );
  }

  void _validate() {
    for (final file in dataFiles) {
      final rows = _rows(file);
      final keys = <String>{};
      for (final row in rows) {
        final keyName = file == 'material.json' ? 'key' : 'id';
        final key = row[keyName]?.toString() ?? '';
        if (key.isEmpty || !keys.add(key)) {
          throw FormatException('$file 存在空白或重复主键');
        }
      }
    }
    final baseIds = _rows(
      'equip_base_cost.json',
    ).map((row) => _positiveInt(row, 'id')).toSet();
    final stepIds = _rows(
      'improvement_consume_step.json',
    ).map((row) => _string(row, 'id')).toSet();
    final materialKeys = _rows(
      'material.json',
    ).map((row) => _string(row, 'key')).toSet();
    for (final file in <String>[
      'improvement_arrangement.json',
      'improvement_consume_step.json',
      'improvement_upgrade_target.json',
    ]) {
      for (final row in _rows(file)) {
        if (!baseIds.contains(_positiveInt(row, 'equipment_id'))) {
          throw FormatException('$file 引用了不存在的装备');
        }
      }
    }
    for (final row in _rows('improvement_consume_item.json')) {
      if (!stepIds.contains(_string(row, 'step_id'))) {
        throw const FormatException('改修阶段消耗引用了不存在的阶段');
      }
      _validateConsumeItem(row, materialKeys);
    }
    final targets = _rows(
      'improvement_upgrade_target.json',
    ).map(_upgradeKey).toSet();
    for (final row in _rows('improvement_upgrade_cost.json')) {
      if (!targets.contains(_upgradeKey(row))) {
        throw const FormatException('进化消耗引用了不存在的进化路线');
      }
      _validateConsumeItem(row, materialKeys);
    }
    for (final row in _rows('equip_base_cost.json')) {
      for (final field in <String>[
        'consume_fuel',
        'consume_ammo',
        'consume_steel',
        'consume_bauxite',
      ]) {
        _nonNegativeInt(row, field);
      }
    }
  }

  void _validateConsumeItem(Map<String, Object?> row, Set<String> materials) {
    final equipmentId = _nullableInt(row['item_equipment_id']);
    final materialKey = _nullableString(row['item_material_key']);
    if ((equipmentId == null) == (materialKey == null)) {
      throw const FormatException('消耗项目必须且只能指定装备或资材');
    }
    if (equipmentId != null && equipmentId <= 0) {
      throw const FormatException('装备 ID 无效');
    }
    if (materialKey != null && !materials.contains(materialKey)) {
      throw const FormatException('资材外键无效');
    }
    _nonNegativeInt(row, 'count');
  }

  ImprovementConsumeItem _consumeItem(
    Map<String, Object?> row,
    Map<String, String> materialNames,
  ) => ImprovementConsumeItem(
    equipmentId: _nullableInt(row['item_equipment_id']),
    materialKey: _nullableString(row['item_material_key']),
    materialName: materialNames[_nullableString(row['item_material_key'])],
    count: _nonNegativeInt(row, 'count'),
  );

  List<Map<String, Object?>> _rows(String file) =>
      _list(_files[file], file).map((value) => _map(value, file)).toList();
  static String _upgradeKey(Map<String, Object?> row) =>
      '${_positiveInt(row, 'equipment_id')}|${_positiveInt(row, 'upgrade_id')}';
}

Map<String, Object?> _map(Object? value, String label) {
  if (value is! Map) throw FormatException('$label 必须是对象');
  return value.map((key, value) => MapEntry(key.toString(), value));
}

List<Object?> _list(Object? value, String label) {
  if (value is! List) throw FormatException('$label 必须是数组');
  return value;
}

String _string(Map<String, Object?> row, String key) {
  final value = row[key];
  if (value is! String || value.isEmpty) throw FormatException('$key 必须是非空字符串');
  return value;
}

String? _nullableString(Object? value) => value?.toString();
int? _nullableInt(Object? value) => value == null
    ? null
    : value is int
    ? value
    : int.tryParse(value.toString());
int _positiveInt(Map<String, Object?> row, String key) {
  final value = _nullableInt(row[key]);
  if (value == null || value <= 0) throw FormatException('$key 必须是正整数');
  return value;
}

int _nonNegativeInt(Map<String, Object?> row, String key) {
  final value = _nullableInt(row[key]);
  if (value == null || value < 0) throw FormatException('$key 必须是非负整数');
  return value;
}

bool _bool(Map<String, Object?> row, String key) {
  final value = row[key];
  if (value is! bool) throw FormatException('$key 必须是布尔值');
  return value;
}
