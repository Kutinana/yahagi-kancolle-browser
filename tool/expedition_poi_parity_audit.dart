import 'dart:convert';
import 'dart:io';

import 'package:yahagi_kancolle_browser/src/expedition/expedition_evaluator.dart';
import 'package:yahagi_kancolle_browser/src/expedition/expedition_rule_catalog.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';

final class ExpeditionParityEntry {
  const ExpeditionParityEntry({
    required this.id,
    required this.displayId,
    required this.poiNormalRules,
    required this.localNormalRules,
    required this.poiGreatSuccessStrategy,
    required this.localGreatSuccessStrategy,
    required this.issueCodes,
  });

  final int id;
  final String displayId;
  final List<String> poiNormalRules;
  final List<String> localNormalRules;
  final String poiGreatSuccessStrategy;
  final String localGreatSuccessStrategy;
  final List<String> issueCodes;

  bool get normalRuleMatchesPoi =>
      _sameValues(poiNormalRules, localNormalRules);
  bool get greatSuccessStrategyMatchesPoi =>
      poiGreatSuccessStrategy == localGreatSuccessStrategy;
}

final class ExpeditionParityIssue {
  const ExpeditionParityIssue({
    required this.code,
    required this.summary,
    required this.detail,
    required this.affectedMissionIds,
  });

  final String code;
  final String summary;
  final String detail;
  final Set<int> affectedMissionIds;
}

final class ExpeditionPoiParityAudit {
  ExpeditionPoiParityAudit._({
    required this.referenceRepository,
    required this.referenceCommit,
    required this.referenceVersion,
    required this.entries,
    required List<ExpeditionParityIssue> issues,
    required this.missingLocalIds,
    required this.extraLocalIds,
  }) : _issues = {for (final issue in issues) issue.code: issue};

  factory ExpeditionPoiParityAudit.load(String referencePath) {
    final root = jsonDecode(File(referencePath).readAsStringSync()) as Map;
    final source = Map<String, Object?>.from(root['source'] as Map);
    final rows = (root['missions'] as List)
        .map((value) => Map<String, Object?>.from(value as Map))
        .toList(growable: false);
    final referenceIds = rows.map((row) => row['id']! as int).toSet();
    final localIds = expeditionRules.keys.toSet();
    final issues = _buildIssues();

    final entries = <ExpeditionParityEntry>[
      for (final row in rows)
        _entryFromReference(
          row,
          issues.where(
            (issue) => issue.affectedMissionIds.contains(row['id']! as int),
          ),
        ),
    ]..sort((left, right) => left.id.compareTo(right.id));

    return ExpeditionPoiParityAudit._(
      referenceRepository: source['repository']! as String,
      referenceCommit: source['commit']! as String,
      referenceVersion: source['version']! as String,
      entries: entries,
      issues: issues,
      missingLocalIds: referenceIds.difference(localIds),
      extraLocalIds: localIds.difference(referenceIds),
    );
  }

  final String referenceRepository;
  final String referenceCommit;
  final String referenceVersion;
  final List<ExpeditionParityEntry> entries;
  final Map<String, ExpeditionParityIssue> _issues;
  final Set<int> missingLocalIds;
  final Set<int> extraLocalIds;

  List<ExpeditionParityIssue> get issues =>
      _issues.values.toList(growable: false);

  ExpeditionParityIssue issue(String code) => _issues[code]!;

  String renderMarkdown() {
    final normalMatches = entries
        .where((entry) => entry.normalRuleMatchesPoi)
        .length;
    final greatMatches = entries
        .where((entry) => entry.greatSuccessStrategyMatchesPoi)
        .length;
    final buffer = StringBuffer()
      ..writeln('# Poi EZ Exped 逐远征差分审计表')
      ..writeln()
      ..writeln('- 基准仓库：[$referenceRepository]($referenceRepository)')
      ..writeln('- 基准版本：`$referenceVersion`')
      ..writeln('- 基准提交：`$referenceCommit`')
      ..writeln('- 远征覆盖：`${entries.length}`')
      ..writeln('- 普通规则结构一致：`$normalMatches/${entries.length}`')
      ..writeln('- 大成功策略分组一致：`$greatMatches/${entries.length}`')
      ..writeln()
      ..writeln('## 跨远征判定差异')
      ..writeln();
    for (final issue in issues) {
      buffer
        ..writeln(
          '- `${issue.code}`（${issue.affectedMissionIds.length} 个远征）：${issue.summary}',
        )
        ..writeln('  ${issue.detail}');
    }
    if (issues.isEmpty) {
      buffer.writeln('- 未发现已知判定差异。');
    }
    buffer
      ..writeln()
      ..writeln('## 逐远征人工复核')
      ..writeln()
      ..writeln('| 显示编号 | 内部 ID | 普通规则 | 大成功分组 | 受影响的判定差异 | 人工复核 |')
      ..writeln('|---|---:|---|---|---|---|');
    for (final entry in entries) {
      final normal = entry.normalRuleMatchesPoi ? '一致' : '不一致';
      final great = entry.greatSuccessStrategyMatchesPoi ? '一致' : '不一致';
      final issueText = entry.issueCodes.isEmpty
          ? '无'
          : entry.issueCodes.join('、');
      buffer.writeln(
        '| ${entry.displayId} | ${entry.id} | $normal | $great | $issueText | ☐ |',
      );
      if (!entry.normalRuleMatchesPoi) {
        buffer
          ..writeln()
          ..writeln('  - Poi：`${entry.poiNormalRules.join('；')}`')
          ..writeln('  - 本项目：`${entry.localNormalRules.join('；')}`')
          ..writeln();
      }
    }
    return buffer.toString();
  }

  String renderCsv() {
    final rows = <List<String>>[
      <String>[
        '显示编号',
        '内部ID',
        '普通规则一致',
        '大成功分组一致',
        'Poi普通规则',
        '本项目普通规则',
        'Poi大成功策略',
        '本项目大成功策略',
        '受影响的判定差异',
        '人工复核',
      ],
      for (final entry in entries)
        <String>[
          entry.displayId,
          '${entry.id}',
          entry.normalRuleMatchesPoi ? '是' : '否',
          entry.greatSuccessStrategyMatchesPoi ? '是' : '否',
          entry.poiNormalRules.join('；'),
          entry.localNormalRules.join('；'),
          entry.poiGreatSuccessStrategy,
          entry.localGreatSuccessStrategy,
          entry.issueCodes.join('；'),
          '',
        ],
    ];
    return '${rows.map((row) => row.map(_csvCell).join(',')).join('\n')}\n';
  }

  void writeReports({required String markdownPath, required String csvPath}) {
    File(markdownPath).writeAsStringSync(renderMarkdown());
    File(csvPath).writeAsStringSync('\ufeff${renderCsv()}');
  }
}

ExpeditionParityEntry _entryFromReference(
  Map<String, Object?> row,
  Iterable<ExpeditionParityIssue> issues,
) {
  final id = row['id']! as int;
  return ExpeditionParityEntry(
    id: id,
    displayId: row['displayId']! as String,
    poiNormalRules: List<String>.from(row['normal']! as List),
    localNormalRules: _normalRulesFor(id),
    poiGreatSuccessStrategy: row['greatSuccess']! as String,
    localGreatSuccessStrategy: _greatSuccessStrategyFor(id),
    issueCodes: issues.map((issue) => issue.code).toList(growable: false),
  );
}

List<ExpeditionParityIssue> _buildIssues() {
  return const <ExpeditionParityIssue>[];
}

List<String> _normalRulesFor(int id) {
  final rule = expeditionRules[id];
  if (rule == null) return const <String>[];
  final result = <String>[];
  for (final requirement in rule.requirements) {
    switch (requirement.type) {
      case ExpeditionRequirementType.flagshipLevel:
        result.add('FSLevel=${requirement.value}');
      case ExpeditionRequirementType.shipCount:
        result.add('ShipCount=${requirement.value}');
      case ExpeditionRequirementType.composition:
        final variants = requirement.compositions.map(_composition).join('|');
        result.add(
          '${requirement.compositions.length == 1 ? 'FleetCompo' : 'AnyFleetCompo'}=$variants',
        );
      case ExpeditionRequirementType.flagshipType:
        result.add('FSType=${_shipTypeName(requirement.value)}');
      case ExpeditionRequirementType.levelSum:
        result.add('LevelSum=${requirement.value}');
      case ExpeditionRequirementType.morale:
        result.add('Morale=${requirement.value}');
      case ExpeditionRequirementType.drumCount:
        result.add('DrumCount=${requirement.value}');
      case ExpeditionRequirementType.drumCarrierCount:
        result.add('DrumCarrierCount=${requirement.value}');
      case ExpeditionRequirementType.firepower:
        final stats = requirement.compositions.isEmpty
            ? const <String, int>{}
            : requirement.compositions.first;
        if (requirement.value > 0) {
          result.add('TotalFirepower=${requirement.value}');
        }
        if ((stats['aa'] ?? 0) > 0) {
          result.add('TotalAntiAir=${stats['aa']}');
        }
        if ((stats['asw'] ?? 0) > 0) {
          result.add('TotalAsw=${stats['asw']}');
        }
        if ((stats['los'] ?? 0) > 0) {
          result.add('TotalLos=${stats['los']}');
        }
      case ExpeditionRequirementType.antiAir:
      case ExpeditionRequirementType.antiSub:
      case ExpeditionRequirementType.lineOfSight:
        break;
    }
  }
  return result;
}

String _greatSuccessStrategyFor(int missionId) {
  final empty = const Fleet(id: 2, name: 'audit', shipIds: <int>[]);
  final result = const ExpeditionEvaluator().evaluate(
    state: GameState.empty,
    fleet: empty,
    missionId: missionId,
  );
  final kinds = result.greatSuccessConditions.map((item) => item.kind).toSet();
  if (kinds.contains(ExpeditionConditionKind.drumCount)) {
    final required = _requiredValue(
      result.greatSuccessConditions
          .firstWhere((item) => item.kind == ExpeditionConditionKind.drumCount)
          .actual,
    );
    final thresholds = _drumRateThresholds(missionId);
    return 'drum:${thresholds.$1}:${thresholds.$2}:$required';
  }
  final flagshipProbe = const ExpeditionEvaluator().evaluate(
    state: const GameState(
      ships: <int, OwnedShip>{
        1: OwnedShip(id: 1, masterId: 1, level: 1, condition: 49),
      },
    ),
    fleet: const Fleet(id: 2, name: 'audit', shipIds: <int>[1]),
    missionId: missionId,
  );
  if (flagshipProbe.greatSuccessRate > 0) {
    return 'flagship';
  }
  return 'standard';
}

(int, int) _drumRateThresholds(int missionId) {
  var min = -1;
  var max = -1;
  for (var drumCount = 0; drumCount <= 12; drumCount++) {
    final rate = _greatSuccessRateWithDrums(missionId, drumCount);
    if (min < 0 && rate > 0) min = drumCount;
    if (max < 0 && rate >= 40) max = drumCount;
  }
  return (min, max);
}

double _greatSuccessRateWithDrums(int missionId, int drumCount) {
  final slotIds = <int>[for (var index = 1; index <= drumCount; index++) index];
  final ship = OwnedShip(
    id: 1,
    masterId: 1,
    level: 1,
    condition: 0,
    slotIds: slotIds,
  );
  final state = GameState(
    masterShips: const <int, MasterShip>{
      1: MasterShip(id: 1, name: 'audit', shipTypeId: 2),
    },
    ships: <int, OwnedShip>{1: ship},
    slotItems: <int, OwnedSlotItem>{
      for (final id in slotIds) id: OwnedSlotItem(id: id, masterId: 75),
    },
  );
  return const ExpeditionEvaluator()
      .evaluate(
        state: state,
        fleet: const Fleet(id: 2, name: 'audit', shipIds: <int>[1]),
        missionId: missionId,
      )
      .greatSuccessRate;
}

int _requiredValue(String actual) => int.parse(actual.split('/').last.trim());

String _composition(Map<String, int> composition) =>
    composition.entries.map((entry) => '${entry.key}:${entry.value}').join('+');

String _shipTypeName(int id) => switch (id) {
  3 => 'CL',
  5 => 'CA',
  7 => 'CVL',
  16 => 'AV',
  20 => 'AS',
  21 => 'CT',
  _ => 'stype:$id',
};

bool _sameValues(List<String> left, List<String> right) {
  final sortedLeft = left.toSet().toList()..sort();
  final sortedRight = right.toSet().toList()..sort();
  if (sortedLeft.length != sortedRight.length) return false;
  for (var index = 0; index < sortedLeft.length; index++) {
    if (sortedLeft[index] != sortedRight[index]) return false;
  }
  return true;
}

String _csvCell(String value) =>
    '"${value.replaceAll('"', '""').replaceAll('\r', ' ').replaceAll('\n', ' ')}"';
