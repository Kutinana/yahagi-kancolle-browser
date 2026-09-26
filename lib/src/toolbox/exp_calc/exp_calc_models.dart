import 'dart:math' as math;

import '../../game_state/game_state.dart';
import 'ship_exp_table.dart';

/// Groups consecutive battles in the same sea without changing route order.
String compactRouteSummary(String summary) {
  final groups = <(String, String)>[];
  for (final part in summary.split(RegExp(r'\s+\+\s+'))) {
    final match = RegExp(
      r'^([^()（）]+)[(（]([^()（）]+)[)）]$',
    ).firstMatch(part.trim());
    if (match == null) return summary;
    final map = match.group(1)!.trim();
    final points = match.group(2)!;
    if (groups.isNotEmpty && groups.last.$1 == map) {
      final previous = groups.removeLast();
      groups.add((map, '${previous.$2}+$points'));
    } else {
      groups.add((map, points));
    }
  }
  return groups.map((group) => '${group.$1}（${group.$2}）').join(' + ');
}

/// Battle result rank used for experience calculation.
enum BattleRank {
  s('S'),
  a('A'),
  b('B'),
  c('C'),
  d('D');

  const BattleRank(this.label);

  final String label;

  /// Applies rank modifier to [exp] using integer arithmetic matching kcanotify.
  int apply(num exp) => switch (this) {
    BattleRank.s => (exp * 6) ~/ 5,
    BattleRank.a || BattleRank.b => exp.floor(),
    BattleRank.c => (exp * 8) ~/ 10,
    BattleRank.d => (exp * 7) ~/ 10,
  };
}

/// Computes the single-battle gained experience for a ship based on:
/// - [baseExp]: Base map experience
/// - [rank]: Battle result rank (S, A, B, C, D)
/// - [isFlagship]: Whether the ship is the flagship (1.5x)
/// - [isMvp]: Whether the ship got MVP (2.0x)
int computeMapExp({
  required num baseExp,
  required BattleRank rank,
  required bool isFlagship,
  required bool isMvp,
}) {
  var exp = math.max(0, baseExp);
  if (isMvp) exp *= 2;
  if (isFlagship) exp = (exp * 3) ~/ 2;
  return rank.apply(exp);
}

/// Computes the required battles to bridge [remainExp] with [mapExp] per battle.
int computeBattleCount({required int remainExp, required int mapExp}) {
  if (remainExp <= 0) return 0;
  final effectiveMapExp = math.max(1, mapExp);
  return (remainExp / effectiveMapExp).ceil();
}

/// Preset single node definition.
class MapNodePreset {
  const MapNodePreset({
    required this.id,
    required this.name,
    required this.baseExp,
    this.knownCount = 0,
    this.totalCount = 0,
  });

  final String id;
  final String name;
  final num? baseExp;
  final int knownCount;
  final int totalCount;
}

/// Preset sortie map definition containing specific nodes.
class SortieMapPreset {
  const SortieMapPreset({
    required this.id,
    required this.name,
    required this.nodes,
  });

  final String id;
  final String name;
  final List<MapNodePreset> nodes;
}

/// A planned battle node in a multi-node sortie route.
class SortieNodePlan {
  SortieNodePlan({
    required this.id,
    required this.mapId,
    required this.nodeId,
    required this.baseExp,
    this.rank = BattleRank.s,
    this.isFlagship = true,
    this.isMvp = false,
  });

  final String id;
  String mapId;
  String nodeId;
  int baseExp;
  BattleRank rank;
  bool isFlagship;
  bool isMvp;

  int computeExp() => computeMapExp(
    baseExp: baseExp,
    rank: rank,
    isFlagship: isFlagship,
    isMvp: isMvp,
  );
}

/// An entry in the user's leveling tracker list.
class ExpCalcTrackItem {
  const ExpCalcTrackItem({
    required this.id,
    required this.shipInstanceId,
    required this.shipMasterId,
    required this.shipName,
    required this.targetLevel,
    required this.targetExp,
    required this.map,
    required this.rank,
    required this.isFlagship,
    required this.isMvp,
    required this.baseExp,
    required this.mapExp,
    required this.recordedLevel,
    required this.recordedExp,
    this.routeSummary,
    this.totalSortieExp,
    this.createdAt,
  });

  final String id;
  final int shipInstanceId;
  final int shipMasterId;
  final String shipName;
  final int targetLevel;
  final int targetExp;
  final String map;
  final BattleRank rank;
  final bool isFlagship;
  final bool isMvp;
  final num baseExp;
  final int mapExp;
  final int recordedLevel;
  final int recordedExp;
  final String? routeSummary;
  final int? totalSortieExp;
  final DateTime? createdAt;

  /// Effective experience gained per single sortie (combined across all planned nodes).
  int get effectiveSortieExp => (totalSortieExp != null && totalSortieExp! > 0)
      ? totalSortieExp!
      : mapExp;

  /// Resolves the latest ship level from the current [state].
  /// Falls back to [recordedLevel] if ship is not found.
  int resolveCurrentLevel(GameState state) {
    if (shipInstanceId > 0 && state.ships.containsKey(shipInstanceId)) {
      return state.ships[shipInstanceId]!.level;
    }
    return recordedLevel;
  }

  /// Resolves the latest ship cumulative experience from the current [state].
  /// Falls back to [recordedExp] if ship is not found.
  int resolveCurrentExp(GameState state) {
    if (shipInstanceId > 0 && state.ships.containsKey(shipInstanceId)) {
      return state.ships[shipInstanceId]!.experience;
    }
    return recordedExp;
  }

  /// Calculates the dynamic remaining experience required to hit [targetLevel].
  int resolveRemainExp(GameState state) {
    final currentExp = resolveCurrentExp(state);
    return math.max(0, targetExp - currentExp);
  }

  /// Calculates the dynamic remaining battle/sortie count to hit [targetLevel].
  int resolveBattleCount(GameState state) {
    final remain = resolveRemainExp(state);
    return computeBattleCount(remainExp: remain, mapExp: effectiveSortieExp);
  }

  /// Whether the leveling goal has been reached.
  bool isCompleted(GameState state) => resolveRemainExp(state) == 0;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'shipInstanceId': shipInstanceId,
    'shipMasterId': shipMasterId,
    'shipName': shipName,
    'targetLevel': targetLevel,
    'targetExp': targetExp,
    'map': map,
    'rank': rank.name,
    'isFlagship': isFlagship,
    'isMvp': isMvp,
    'baseExp': baseExp,
    'mapExp': mapExp,
    'recordedLevel': recordedLevel,
    'recordedExp': recordedExp,
    if (routeSummary != null) 'routeSummary': routeSummary,
    if (totalSortieExp != null) 'totalSortieExp': totalSortieExp,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
  };

  factory ExpCalcTrackItem.fromJson(Map<String, dynamic> json) {
    final rankName = json['rank'] as String? ?? 's';
    final rank = BattleRank.values.firstWhere(
      (r) => r.name.toLowerCase() == rankName.toLowerCase(),
      orElse: () => BattleRank.s,
    );
    final targetLevel = (json['targetLevel'] as num?)?.toInt() ?? 1;
    final targetExp =
        (json['targetExp'] as num?)?.toInt() ?? shipCumulativeExp(targetLevel);
    final recordedLevel =
        (json['recordedLevel'] as num?)?.toInt() ??
        (json['current_lv'] as num?)?.toInt() ??
        1;
    final recordedExp =
        (json['recordedExp'] as num?)?.toInt() ??
        (json['current_exp'] as num?)?.toInt() ??
        shipCumulativeExp(recordedLevel);

    return ExpCalcTrackItem(
      id:
          json['id'] as String? ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      shipInstanceId:
          (json['shipInstanceId'] as num?)?.toInt() ??
          (json['api_id'] as num?)?.toInt() ??
          -1,
      shipMasterId:
          (json['shipMasterId'] as num?)?.toInt() ??
          (json['api_ship_id'] as num?)?.toInt() ??
          -1,
      shipName: json['shipName'] as String? ?? '???',
      targetLevel: targetLevel,
      targetExp: targetExp,
      map: json['map'] as String? ?? '5-2',
      rank: rank,
      isFlagship:
          json['isFlagship'] as bool? ?? json['is_flagship'] as bool? ?? false,
      isMvp: json['isMvp'] as bool? ?? json['is_mvp'] as bool? ?? false,
      baseExp: json['baseExp'] as num? ?? 1,
      mapExp:
          (json['mapExp'] as num?)?.toInt() ??
          (json['mapexp'] as num?)?.toInt() ??
          1,
      recordedLevel: recordedLevel,
      recordedExp: recordedExp,
      routeSummary: json['routeSummary'] as String?,
      totalSortieExp: (json['totalSortieExp'] as num?)?.toInt(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }
}
