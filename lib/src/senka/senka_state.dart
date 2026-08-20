import 'senka_catalog.dart';

const int currentSenkaExperienceTrackingVersion = 1;

enum SenkaRankDirection { up, down, same, unknown }

String senkaMapKey(int areaId, int mapNo) => '$areaId-$mapNo';

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

  String get mapKey => senkaMapKey(areaId, mapNo);

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

class SenkaActiveSortie {
  SenkaActiveSortie({
    required this.areaId,
    required this.mapNo,
    required DateTime startedAt,
    required DateTime lastEventAt,
    this.bossCellNo,
    this.bossArrived = false,
  }) : startedAt = startedAt.toUtc(),
       lastEventAt = lastEventAt.toUtc();

  final int areaId;
  final int mapNo;
  final int? bossCellNo;
  final bool bossArrived;
  final DateTime startedAt;
  final DateTime lastEventAt;

  String get mapKey => senkaMapKey(areaId, mapNo);

  SenkaActiveSortie copyWith({
    int? bossCellNo,
    bool? bossArrived,
    DateTime? lastEventAt,
  }) => SenkaActiveSortie(
    areaId: areaId,
    mapNo: mapNo,
    bossCellNo: bossCellNo ?? this.bossCellNo,
    bossArrived: bossArrived ?? this.bossArrived,
    startedAt: startedAt,
    lastEventAt: lastEventAt ?? this.lastEventAt,
  );

  Map<String, Object?> toJson() => {
    'areaId': areaId,
    'mapNo': mapNo,
    'bossCellNo': bossCellNo,
    'bossArrived': bossArrived,
    'startedAt': startedAt.toIso8601String(),
    'lastEventAt': lastEventAt.toIso8601String(),
  };

  factory SenkaActiveSortie.fromJson(Object? value) {
    final map = value is Map ? value : const {};
    return SenkaActiveSortie(
      areaId: _int(map['areaId']),
      mapNo: _int(map['mapNo']),
      bossCellNo: map['bossCellNo'] == null ? null : _int(map['bossCellNo']),
      bossArrived: map['bossArrived'] == true,
      startedAt: _storedDateTime(map['startedAt']),
      lastEventAt: _storedDateTime(map['lastEventAt']),
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
  SenkaState({
    required this.monthKey,
    this.experienceTrackingVersion = currentSenkaExperienceTrackingVersion,
    this.serverOrigin = '',
    this.memberId = 0,
    this.nickname = '',
    this.magic = 0,
    this.latestExperience,
    Map<String, SenkaDayRecord> days = const {},
    Map<int, SenkaRewardStatus> eoStatuses = const {},
    Map<int, SenkaRewardStatus> questStatuses = const {},
    this.targetSenka = 0,
    this.calculatorCurrentSenka = 0,
    Map<String, SenkaSortieStats> sortieStats = const {},
    this.activeSortie,
    DateTime? latestSortieEventAt,
    DateTime? lastSortieStartAt,
    this.lastSortieStartMapKey,
    Set<String> favoriteSortieMapKeys = const {},
    Set<String> hiddenSortieMapKeys = const {},
    Map<String, List<SenkaRankingSnapshot>> rankingHistory = const {},
    this.rankingUpdatedAt,
    this.updatedAt,
  }) : days = Map.unmodifiable(Map.of(days)),
       eoStatuses = Map.unmodifiable(Map.of(eoStatuses)),
       questStatuses = Map.unmodifiable(Map.of(questStatuses)),
       sortieStats = Map.unmodifiable(
         _normalizedSortieStats(sortieStats.values),
       ),
       latestSortieEventAt = latestSortieEventAt?.toUtc(),
       lastSortieStartAt = lastSortieStartAt?.toUtc(),
       favoriteSortieMapKeys = Set.unmodifiable(
         _normalizedMapKeys(favoriteSortieMapKeys),
       ),
       hiddenSortieMapKeys = Set.unmodifiable(
         _normalizedMapKeys(hiddenSortieMapKeys),
       ),
       rankingHistory = Map<String, List<SenkaRankingSnapshot>>.unmodifiable({
         for (final entry in rankingHistory.entries)
           entry.key: List<SenkaRankingSnapshot>.unmodifiable(entry.value),
       });

  factory SenkaState.forMonth(String monthKey) =>
      SenkaState(monthKey: monthKey);

  final String monthKey;
  final int experienceTrackingVersion;
  final String serverOrigin;
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
  final SenkaActiveSortie? activeSortie;
  final DateTime? latestSortieEventAt;
  final DateTime? lastSortieStartAt;
  final String? lastSortieStartMapKey;
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
    int? experienceTrackingVersion,
    String? serverOrigin,
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
    SenkaActiveSortie? activeSortie,
    bool clearActiveSortie = false,
    DateTime? latestSortieEventAt,
    DateTime? lastSortieStartAt,
    String? lastSortieStartMapKey,
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
      experienceTrackingVersion:
          experienceTrackingVersion ?? this.experienceTrackingVersion,
      serverOrigin: serverOrigin ?? this.serverOrigin,
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
      activeSortie: clearActiveSortie
          ? null
          : activeSortie ?? this.activeSortie,
      latestSortieEventAt: latestSortieEventAt ?? this.latestSortieEventAt,
      lastSortieStartAt: lastSortieStartAt ?? this.lastSortieStartAt,
      lastSortieStartMapKey:
          lastSortieStartMapKey ?? this.lastSortieStartMapKey,
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
    'experienceTrackingVersion': experienceTrackingVersion,
    'serverOrigin': serverOrigin,
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
    'activeSortie': activeSortie?.toJson(),
    'latestSortieEventAt': latestSortieEventAt?.toIso8601String(),
    'lastSortieStartAt': lastSortieStartAt?.toIso8601String(),
    'lastSortieStartMapKey': lastSortieStartMapKey,
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
    final storedMonthKey = '${value['monthKey'] ?? ''}';
    final storedMonth = parseSenkaMonthKey(storedMonthKey);
    final monthKey = storedMonth == null
        ? currentSenkaMonthKey()
        : storedMonthKey;
    final rawDays = value['days'];
    final rawRanking = value['rankingHistory'];
    final rawSortieStats = value['sortieStats'];
    final sortieStats = _sortieStatsMap(rawSortieStats);
    final latestSortieEventAt = _parsedUtcDateTime(
      value['latestSortieEventAt'],
    );
    final rawLastSortieStartAt = _parsedUtcDateTime(value['lastSortieStartAt']);
    final rawLastSortieStartMapKey = _validMapKey(
      value['lastSortieStartMapKey'],
    );
    final hasStoredStartIdentity =
        value['lastSortieStartAt'] != null ||
        value['lastSortieStartMapKey'] != null;
    final lastStartStats = rawLastSortieStartMapKey == null
        ? null
        : sortieStats[rawLastSortieStartMapKey];
    final hasValidStartIdentity =
        rawLastSortieStartAt != null &&
        rawLastSortieStartMapKey != null &&
        latestSortieEventAt != null &&
        !rawLastSortieStartAt.isAfter(latestSortieEventAt) &&
        lastStartStats != null &&
        lastStartStats.sorties > 0;
    final hasValidLifecycleMetadata =
        !hasStoredStartIdentity || hasValidStartIdentity;
    final validLatestSortieEventAt = hasValidLifecycleMetadata
        ? latestSortieEventAt
        : null;
    final hasEoStatuses = value.containsKey('eoStatuses');
    final hasQuestStatuses = value.containsKey('questStatuses');
    final eoStatuses = _statusMap(value['eoStatuses']);
    final questStatuses = _statusMap(value['questStatuses']);
    if (!hasEoStatuses) {
      for (final id in _intSet(value['completedEoIds'])) {
        eoStatuses[id] = SenkaRewardStatus.completed;
      }
    }
    if (!hasQuestStatuses) {
      for (final id in _intSet(value['completedQuestIds'])) {
        questStatuses[id] = SenkaRewardStatus.completed;
      }
    }
    final restored = SenkaState(
      monthKey: monthKey,
      experienceTrackingVersion: _int(value['experienceTrackingVersion']),
      serverOrigin: '${value['serverOrigin'] ?? ''}',
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
      sortieStats: sortieStats,
      activeSortie: _activeSortie(
        value['activeSortie'],
        sortieStats,
        validLatestSortieEventAt,
        hasValidStartIdentity ? rawLastSortieStartAt : null,
        hasValidStartIdentity ? rawLastSortieStartMapKey : null,
      ),
      latestSortieEventAt: validLatestSortieEventAt,
      lastSortieStartAt: hasValidStartIdentity ? rawLastSortieStartAt : null,
      lastSortieStartMapKey: hasValidStartIdentity
          ? rawLastSortieStartMapKey
          : null,
      favoriteSortieMapKeys: _mapKeySet(value['favoriteSortieMapKeys']),
      hiddenSortieMapKeys: _mapKeySet(value['hiddenSortieMapKeys']),
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
    if (storedMonth != null) return restored;
    return SenkaState.forMonth(monthKey).copyWith(
      serverOrigin: restored.serverOrigin,
      memberId: restored.memberId,
      nickname: restored.nickname,
      magic: restored.magic,
      questStatuses: {
        for (final entry in restored.questStatuses.entries)
          if (senkaQuestById(entry.key)?.category ==
              SenkaRewardCategory.oneTime)
            entry.key: entry.value,
      },
      favoriteSortieMapKeys: restored.favoriteSortieMapKeys,
      hiddenSortieMapKeys: restored.hiddenSortieMapKeys,
    );
  }
}

SenkaState migrateSenkaExperienceTracking(SenkaState state) {
  if (state.experienceTrackingVersion >=
      currentSenkaExperienceTrackingVersion) {
    return state;
  }
  return state.copyWith(
    experienceTrackingVersion: currentSenkaExperienceTrackingVersion,
    clearLatestExperience: true,
    days: {
      for (final entry in state.days.entries)
        entry.key: SenkaDayRecord(eo: entry.value.eo, quest: entry.value.quest),
    },
  );
}

SenkaState migrateSenkaStateToMonth(SenkaState state, String monthKey) {
  final next = parseSenkaMonthKey(monthKey);
  if (next == null) return state;
  final previous = parseSenkaMonthKey(state.monthKey);
  if (previous != null && _compareSenkaMonths(next, previous) <= 0) {
    return state;
  }
  final sameQuarter =
      senkaQuarterlyCycleKey(state.monthKey) ==
      senkaQuarterlyCycleKey(monthKey);
  final sameAnnual =
      senkaAnnualCycleKey(state.monthKey) == senkaAnnualCycleKey(monthKey);
  final questStatuses = <int, SenkaRewardStatus>{};
  for (final entry in state.questStatuses.entries) {
    final item = senkaQuestById(entry.key);
    if (item == null) continue;
    final keep = switch (item.category) {
      SenkaRewardCategory.eo => false,
      SenkaRewardCategory.quarterly => sameQuarter,
      SenkaRewardCategory.annual => sameAnnual,
      SenkaRewardCategory.oneTime => true,
    };
    if (keep) questStatuses[entry.key] = entry.value;
  }
  return SenkaState.forMonth(monthKey).copyWith(
    serverOrigin: state.serverOrigin,
    memberId: state.memberId,
    nickname: state.nickname,
    magic: state.magic,
    questStatuses: questStatuses,
    favoriteSortieMapKeys: state.favoriteSortieMapKeys,
    hiddenSortieMapKeys: state.hiddenSortieMapKeys,
  );
}

({int year, int month})? parseSenkaMonthKey(String value) {
  final match = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(value);
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  return month >= 1 && month <= 12 ? (year: year, month: month) : null;
}

String? senkaQuarterlyCycleKey(String monthKey) {
  final month = parseSenkaMonthKey(monthKey);
  if (month == null) return null;
  final (year, startMonth) = switch (month.month) {
    1 || 2 => (month.year - 1, 12),
    >= 3 && <= 5 => (month.year, 3),
    >= 6 && <= 8 => (month.year, 6),
    >= 9 && <= 11 => (month.year, 9),
    _ => (month.year, 12),
  };
  return '${year.toString().padLeft(4, '0')}-${startMonth.toString().padLeft(2, '0')}';
}

String? senkaAnnualCycleKey(String monthKey) {
  final month = parseSenkaMonthKey(monthKey);
  if (month == null) return null;
  final startYear = month.month >= 6 ? month.year : month.year - 1;
  return '${startYear.toString().padLeft(4, '0')}-06';
}

int _compareSenkaMonths(
  ({int year, int month}) left,
  ({int year, int month}) right,
) => (left.year * 12 + left.month).compareTo(right.year * 12 + right.month);

SenkaActiveSortie? _activeSortie(
  Object? value,
  Map<String, SenkaSortieStats> sortieStats,
  DateTime? latestSortieEventAt,
  DateTime? lastSortieStartAt,
  String? lastSortieStartMapKey,
) {
  if (value is! Map) return null;
  if (lastSortieStartAt == null || lastSortieStartMapKey == null) return null;
  final startedAt = DateTime.tryParse('${value['startedAt'] ?? ''}');
  final lastEventAt = DateTime.tryParse('${value['lastEventAt'] ?? ''}');
  if (startedAt == null ||
      lastEventAt == null ||
      lastEventAt.isBefore(startedAt)) {
    return null;
  }
  if (latestSortieEventAt == null || lastEventAt.isAfter(latestSortieEventAt)) {
    return null;
  }
  final sortie = SenkaActiveSortie.fromJson(value);
  if (sortie.areaId <= 0 || sortie.mapNo <= 0) return null;
  if (sortie.mapKey != lastSortieStartMapKey ||
      sortie.startedAt != lastSortieStartAt) {
    return null;
  }
  if (sortie.bossCellNo != null && sortie.bossCellNo! <= 0) return null;
  if (sortie.bossArrived && sortie.bossCellNo == null) return null;
  final stats = sortieStats[sortie.mapKey];
  if (stats == null || stats.sorties <= 0) return null;
  if (sortie.bossArrived && stats.bossArrivals <= 0) return null;
  return sortie;
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

DateTime _storedDateTime(Object? value) =>
    DateTime.tryParse('${value ?? ''}')?.toUtc() ??
    DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

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

Map<String, SenkaSortieStats> _sortieStatsMap(Object? value) {
  if (value is! Map) return <String, SenkaSortieStats>{};
  return _normalizedSortieStats(value.values.map(_validSortieStats).nonNulls);
}

SenkaSortieStats? _validSortieStats(Object? value) {
  if (value is! Map) return null;
  final areaId = _strictInt(value['areaId'], minimum: 1);
  final mapNo = _strictInt(value['mapNo'], minimum: 1);
  final sorties = _strictCount(value['sorties']);
  final bossArrivals = _strictCount(value['bossArrivals']);
  final sWins = _strictCount(value['sWins']);
  final aWins = _strictCount(value['aWins']);
  if (areaId == null ||
      mapNo == null ||
      sorties == null ||
      bossArrivals == null ||
      sWins == null ||
      aWins == null ||
      bossArrivals > sorties ||
      sWins + aWins > bossArrivals) {
    return null;
  }
  return SenkaSortieStats(
    areaId: areaId,
    mapNo: mapNo,
    sorties: sorties,
    bossArrivals: bossArrivals,
    sWins: sWins,
    aWins: aWins,
  );
}

Map<String, SenkaSortieStats> _normalizedSortieStats(
  Iterable<SenkaSortieStats> values,
) {
  final result = <String, SenkaSortieStats>{};
  for (final stats in values) {
    if (stats.areaId > 0 && stats.mapNo > 0) {
      result[stats.mapKey] = stats;
    }
  }
  return result;
}

Set<String> _mapKeySet(Object? value) {
  if (value is! List) return <String>{};
  return _normalizedMapKeys(value);
}

Set<String> _normalizedMapKeys(Iterable<Object?> values) {
  final result = <String>{};
  for (final raw in values) {
    final match = RegExp(r'^(\d+)-(\d+)$').firstMatch('$raw');
    if (match == null) continue;
    final areaId = int.tryParse(match.group(1)!);
    final mapNo = int.tryParse(match.group(2)!);
    if (areaId == null || mapNo == null || areaId <= 0 || mapNo <= 0) {
      continue;
    }
    result.add(senkaMapKey(areaId, mapNo));
  }
  return result;
}

int? _strictInt(Object? value, {required int minimum}) {
  if (value is! num || !value.isFinite) return null;
  final result = value.toInt();
  return value == result && result >= minimum ? result : null;
}

int? _strictCount(Object? value) =>
    value == null ? 0 : _strictInt(value, minimum: 0);

DateTime? _parsedUtcDateTime(Object? value) =>
    DateTime.tryParse('${value ?? ''}')?.toUtc();

String? _validMapKey(Object? value) {
  final match = RegExp(r'^(\d+)-(\d+)$').firstMatch('$value');
  if (match == null) return null;
  final areaId = int.tryParse(match.group(1)!);
  final mapNo = int.tryParse(match.group(2)!);
  if (areaId == null || mapNo == null || areaId <= 0 || mapNo <= 0) {
    return null;
  }
  return senkaMapKey(areaId, mapNo);
}
