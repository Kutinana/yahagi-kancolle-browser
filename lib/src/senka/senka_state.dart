import 'senka_catalog.dart';

enum SenkaRankDirection { up, down, same, unknown }

enum SenkaRewardStatus {
  deferred,
  planned,
  completed;

  static SenkaRewardStatus fromStorage(Object? value) {
    final stored = '$value';
    for (final status in values) {
      if (status.name == stored) return status;
    }
    return deferred;
  }

  SenkaRewardStatus get next => switch (this) {
    deferred => planned,
    planned => completed,
    completed => deferred,
  };
}

class SenkaSortieStats {
  const SenkaSortieStats({
    required this.areaId,
    required this.mapNo,
    this.sorties = 0,
    this.bossArrivals = 0,
    this.sWins = 0,
    this.aWins = 0,
  });

  final int areaId;
  final int mapNo;
  final int sorties;
  final int bossArrivals;
  final int sWins;
  final int aWins;

  SenkaSortieStats copyWith({
    int? areaId,
    int? mapNo,
    int? sorties,
    int? bossArrivals,
    int? sWins,
    int? aWins,
  }) => SenkaSortieStats(
    areaId: areaId ?? this.areaId,
    mapNo: mapNo ?? this.mapNo,
    sorties: sorties ?? this.sorties,
    bossArrivals: bossArrivals ?? this.bossArrivals,
    sWins: sWins ?? this.sWins,
    aWins: aWins ?? this.aWins,
  );

  Map<String, Object?> toJson() => {
    'areaId': areaId,
    'mapNo': mapNo,
    'sorties': sorties,
    'bossArrivals': bossArrivals,
    'sWins': sWins,
    'aWins': aWins,
  };

  factory SenkaSortieStats.fromJson(Object? value) {
    final map = value is Map ? value : const {};
    return SenkaSortieStats(
      areaId: _int(map['areaId']),
      mapNo: _int(map['mapNo']),
      sorties: _int(map['sorties']),
      bossArrivals: _int(map['bossArrivals']),
      sWins: _int(map['sWins']),
      aWins: _int(map['aWins']),
    );
  }
}

class SenkaDayRecord {
  const SenkaDayRecord({this.experience = 0, this.eo = 0, this.quest = 0});

  final double experience;
  final double eo;
  final double quest;
  double get total => experience + eo + quest;

  SenkaDayRecord add({
    double experience = 0,
    double eo = 0,
    double quest = 0,
  }) => SenkaDayRecord(
    experience: this.experience + experience,
    eo: this.eo + eo,
    quest: this.quest + quest,
  );

  Map<String, Object?> toJson() => {
    'experience': experience,
    'eo': eo,
    'quest': quest,
  };

  factory SenkaDayRecord.fromJson(Object? value) {
    final map = value is Map ? value : const {};
    return SenkaDayRecord(
      experience: _double(map['experience']),
      eo: _double(map['eo']),
      quest: _double(map['quest']),
    );
  }
}

class SenkaRankingSnapshot {
  const SenkaRankingSnapshot({
    required this.rank,
    required this.senka,
    required this.capturedAt,
    required this.localSenkaAtCapture,
  });

  final int rank;
  final double senka;
  final DateTime capturedAt;
  final double localSenkaAtCapture;

  Map<String, Object?> toJson() => {
    'rank': rank,
    'senka': senka,
    'capturedAt': capturedAt.toIso8601String(),
    'localSenkaAtCapture': localSenkaAtCapture,
  };

  factory SenkaRankingSnapshot.fromJson(Object? value) {
    final map = value is Map ? value : const {};
    return SenkaRankingSnapshot(
      rank: _int(map['rank']),
      senka: _double(map['senka']),
      capturedAt:
          DateTime.tryParse('${map['capturedAt'] ?? ''}')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      localSenkaAtCapture: _double(map['localSenkaAtCapture']),
    );
  }
}

class SenkaRankingRow {
  const SenkaRankingRow({
    this.rank,
    this.senka,
    this.senkaDelta,
    this.rankDelta,
    this.rankDirection = SenkaRankDirection.unknown,
    this.updatedAt,
  });

  final int? rank;
  final double? senka;
  final double? senkaDelta;
  final int? rankDelta;
  final SenkaRankDirection rankDirection;
  final DateTime? updatedAt;
}

class SenkaState {
  const SenkaState({
    required this.monthKey,
    this.memberId = 0,
    this.nickname = '',
    this.magic = 0,
    this.latestExperience,
    this.days = const {},
    this.eoStatuses = const {},
    this.questStatuses = const {},
    this.targetSenka = 0,
    this.calculatorCurrentSenka = 0,
    this.sortieStats = const {},
    this.favoriteSortieMapKeys = const {},
    this.hiddenSortieMapKeys = const {},
    this.rankingHistory = const {},
    this.rankingUpdatedAt,
    this.updatedAt,
  });

  factory SenkaState.forMonth(String monthKey) =>
      SenkaState(monthKey: monthKey);

  final String monthKey;
  final int memberId;
  final String nickname;
  final int magic;
  final int? latestExperience;
  final Map<String, SenkaDayRecord> days;
  final Map<int, SenkaRewardStatus> eoStatuses;
  final Map<int, SenkaRewardStatus> questStatuses;
  final double targetSenka;
  final double calculatorCurrentSenka;
  final Map<String, SenkaSortieStats> sortieStats;
  final Set<String> favoriteSortieMapKeys;
  final Set<String> hiddenSortieMapKeys;
  final Map<String, List<SenkaRankingSnapshot>> rankingHistory;
  final DateTime? rankingUpdatedAt;
  final DateTime? updatedAt;

  SenkaDayRecord day(DateTime date) =>
      days[dateKey(date)] ?? const SenkaDayRecord();

  double get monthRecorded =>
      days.values.fold(0, (sum, record) => sum + record.total);

  Set<int> get completedEoIds => {
    for (final entry in eoStatuses.entries)
      if (entry.value == SenkaRewardStatus.completed) entry.key,
  };

  Set<int> get completedQuestIds => {
    for (final entry in questStatuses.entries)
      if (entry.value == SenkaRewardStatus.completed) entry.key,
  };

  int get completedSenka {
    var total = 0;
    for (final item in senkaEoCatalog) {
      if (completedEoIds.contains(item.id)) total += item.senka;
    }
    for (final item in senkaQuestCatalog) {
      if (completedQuestIds.contains(item.id)) total += item.senka;
    }
    return total;
  }

  DateTime? get latestRankingUpdatedAt {
    if (rankingUpdatedAt != null) return rankingUpdatedAt;
    DateTime? latest;
    for (final history in rankingHistory.values) {
      for (final snapshot in history) {
        if (latest == null || snapshot.capturedAt.isAfter(latest)) {
          latest = snapshot.capturedAt;
        }
      }
    }
    return latest;
  }

  SenkaRankingRow rankingRow(int rank) => _rankingRow('$rank');

  SenkaRankingRow get playerRankingRow {
    final history = rankingHistory['player'] ?? const [];
    if (history.isEmpty) return const SenkaRankingRow();
    final current = history.last;
    final previous = history.length > 1 ? history[history.length - 2] : null;
    final difference = previous == null ? null : previous.rank - current.rank;
    return SenkaRankingRow(
      rank: current.rank,
      senka: current.senka,
      senkaDelta: monthRecorded - current.localSenkaAtCapture,
      rankDelta: difference?.abs(),
      rankDirection: difference == null
          ? SenkaRankDirection.unknown
          : difference > 0
          ? SenkaRankDirection.up
          : difference < 0
          ? SenkaRankDirection.down
          : SenkaRankDirection.same,
      updatedAt: current.capturedAt,
    );
  }

  SenkaRankingRow _rankingRow(String key) {
    final history = rankingHistory[key] ?? const [];
    if (history.isEmpty) return const SenkaRankingRow();
    final current = history.last;
    final previous = history.length > 1 ? history[history.length - 2] : null;
    return SenkaRankingRow(
      rank: current.rank,
      senka: current.senka,
      senkaDelta: previous == null ? null : current.senka - previous.senka,
      updatedAt: current.capturedAt,
    );
  }

  SenkaState copyWith({
    String? monthKey,
    int? memberId,
    String? nickname,
    int? magic,
    int? latestExperience,
    bool clearLatestExperience = false,
    Map<String, SenkaDayRecord>? days,
    Map<int, SenkaRewardStatus>? eoStatuses,
    Map<int, SenkaRewardStatus>? questStatuses,
    Set<int>? completedEoIds,
    Set<int>? completedQuestIds,
    double? targetSenka,
    double? calculatorCurrentSenka,
    Map<String, SenkaSortieStats>? sortieStats,
    Set<String>? favoriteSortieMapKeys,
    Set<String>? hiddenSortieMapKeys,
    Map<String, List<SenkaRankingSnapshot>>? rankingHistory,
    DateTime? rankingUpdatedAt,
    DateTime? updatedAt,
  }) {
    final nextEoStatuses =
        eoStatuses ??
        (completedEoIds == null
            ? this.eoStatuses
            : _replaceCompleted(this.eoStatuses, completedEoIds));
    final nextQuestStatuses =
        questStatuses ??
        (completedQuestIds == null
            ? this.questStatuses
            : _replaceCompleted(this.questStatuses, completedQuestIds));
    return SenkaState(
      monthKey: monthKey ?? this.monthKey,
      memberId: memberId ?? this.memberId,
      nickname: nickname ?? this.nickname,
      magic: magic ?? this.magic,
      latestExperience: clearLatestExperience
          ? null
          : latestExperience ?? this.latestExperience,
      days: days ?? this.days,
      eoStatuses: nextEoStatuses,
      questStatuses: nextQuestStatuses,
      targetSenka: targetSenka ?? this.targetSenka,
      calculatorCurrentSenka:
          calculatorCurrentSenka ?? this.calculatorCurrentSenka,
      sortieStats: sortieStats ?? this.sortieStats,
      favoriteSortieMapKeys:
          favoriteSortieMapKeys ?? this.favoriteSortieMapKeys,
      hiddenSortieMapKeys: hiddenSortieMapKeys ?? this.hiddenSortieMapKeys,
      rankingHistory: rankingHistory ?? this.rankingHistory,
      rankingUpdatedAt: rankingUpdatedAt ?? this.rankingUpdatedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() => {
    'monthKey': monthKey,
    'memberId': memberId,
    'nickname': nickname,
    'magic': magic,
    'latestExperience': latestExperience,
    'days': days.map((key, value) => MapEntry(key, value.toJson())),
    'eoStatuses': eoStatuses.map((key, value) => MapEntry('$key', value.name)),
    'questStatuses': questStatuses.map(
      (key, value) => MapEntry('$key', value.name),
    ),
    'completedEoIds': completedEoIds.toList(),
    'completedQuestIds': completedQuestIds.toList(),
    'targetSenka': targetSenka,
    'calculatorCurrentSenka': calculatorCurrentSenka,
    'sortieStats': sortieStats.map(
      (key, value) => MapEntry(key, value.toJson()),
    ),
    'favoriteSortieMapKeys': favoriteSortieMapKeys.toList(),
    'hiddenSortieMapKeys': hiddenSortieMapKeys.toList(),
    'rankingHistory': rankingHistory.map(
      (key, value) =>
          MapEntry(key, value.map((item) => item.toJson()).toList()),
    ),
    'rankingUpdatedAt': rankingUpdatedAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  factory SenkaState.fromJson(Object? value) {
    if (value is! Map) return SenkaState.forMonth(currentSenkaMonthKey());
    final rawDays = value['days'];
    final rawRanking = value['rankingHistory'];
    final rawSortieStats = value['sortieStats'];
    final eoStatuses = _statusMap(value['eoStatuses']);
    final questStatuses = _statusMap(value['questStatuses']);
    for (final id in _intSet(value['completedEoIds'])) {
      eoStatuses[id] = SenkaRewardStatus.completed;
    }
    for (final id in _intSet(value['completedQuestIds'])) {
      questStatuses[id] = SenkaRewardStatus.completed;
    }
    return SenkaState(
      monthKey: '${value['monthKey'] ?? currentSenkaMonthKey()}',
      memberId: _int(value['memberId']),
      nickname: '${value['nickname'] ?? ''}',
      magic: _int(value['magic']),
      latestExperience: value['latestExperience'] == null
          ? null
          : _int(value['latestExperience']),
      days: rawDays is Map
          ? {
              for (final entry in rawDays.entries)
                '${entry.key}': SenkaDayRecord.fromJson(entry.value),
            }
          : const {},
      eoStatuses: eoStatuses,
      questStatuses: questStatuses,
      targetSenka: _double(value['targetSenka']),
      calculatorCurrentSenka: _double(value['calculatorCurrentSenka']),
      sortieStats: rawSortieStats is Map
          ? {
              for (final entry in rawSortieStats.entries)
                '${entry.key}': SenkaSortieStats.fromJson(entry.value),
            }
          : const {},
      favoriteSortieMapKeys: _stringSet(value['favoriteSortieMapKeys']),
      hiddenSortieMapKeys: _stringSet(value['hiddenSortieMapKeys']),
      rankingHistory: rawRanking is Map
          ? {
              for (final entry in rawRanking.entries)
                '${entry.key}': entry.value is List
                    ? [
                        for (final item in entry.value as List)
                          SenkaRankingSnapshot.fromJson(item),
                      ]
                    : <SenkaRankingSnapshot>[],
            }
          : const {},
      rankingUpdatedAt: DateTime.tryParse(
        '${value['rankingUpdatedAt'] ?? ''}',
      )?.toUtc(),
      updatedAt: DateTime.tryParse('${value['updatedAt'] ?? ''}')?.toUtc(),
    );
  }
}

DateTime toJst(DateTime value) => value.toUtc().add(const Duration(hours: 9));

DateTime senkaBusinessDate(DateTime value) =>
    toJst(value).subtract(const Duration(hours: 2));

String currentSenkaMonthKey([DateTime? now]) {
  final date = senkaBusinessDate(now ?? DateTime.now().toUtc());
  return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';
}

String dateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

int _int(Object? value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;

double _double(Object? value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

Set<int> _intSet(Object? value) =>
    value is List ? value.map(_int).where((item) => item > 0).toSet() : <int>{};

Map<int, SenkaRewardStatus> _statusMap(Object? value) {
  if (value is! Map) return <int, SenkaRewardStatus>{};
  return {
    for (final entry in value.entries)
      if (_int(entry.key) > 0)
        _int(entry.key): SenkaRewardStatus.fromStorage(entry.value),
  };
}

Map<int, SenkaRewardStatus> _replaceCompleted(
  Map<int, SenkaRewardStatus> statuses,
  Set<int> completedIds,
) {
  final result = Map<int, SenkaRewardStatus>.of(statuses)
    ..removeWhere((_, status) => status == SenkaRewardStatus.completed);
  for (final id in completedIds) {
    result[id] = SenkaRewardStatus.completed;
  }
  return result;
}

Set<String> _stringSet(Object? value) => value is List
    ? value.map((item) => '$item').where((item) => item.isNotEmpty).toSet()
    : <String>{};
