import 'senka_catalog.dart';

enum SenkaRankDirection { up, down, same, unknown }

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
    this.completedEoIds = const {},
    this.completedQuestIds = const {},
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
  final Set<int> completedEoIds;
  final Set<int> completedQuestIds;
  final Map<String, List<SenkaRankingSnapshot>> rankingHistory;
  final DateTime? rankingUpdatedAt;
  final DateTime? updatedAt;

  SenkaDayRecord day(DateTime date) =>
      days[dateKey(date)] ?? const SenkaDayRecord();

  double get monthRecorded =>
      days.values.fold(0, (sum, record) => sum + record.total);

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
    Set<int>? completedEoIds,
    Set<int>? completedQuestIds,
    Map<String, List<SenkaRankingSnapshot>>? rankingHistory,
    DateTime? rankingUpdatedAt,
    DateTime? updatedAt,
  }) => SenkaState(
    monthKey: monthKey ?? this.monthKey,
    memberId: memberId ?? this.memberId,
    nickname: nickname ?? this.nickname,
    magic: magic ?? this.magic,
    latestExperience: clearLatestExperience
        ? null
        : latestExperience ?? this.latestExperience,
    days: days ?? this.days,
    completedEoIds: completedEoIds ?? this.completedEoIds,
    completedQuestIds: completedQuestIds ?? this.completedQuestIds,
    rankingHistory: rankingHistory ?? this.rankingHistory,
    rankingUpdatedAt: rankingUpdatedAt ?? this.rankingUpdatedAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, Object?> toJson() => {
    'monthKey': monthKey,
    'memberId': memberId,
    'nickname': nickname,
    'magic': magic,
    'latestExperience': latestExperience,
    'days': days.map((key, value) => MapEntry(key, value.toJson())),
    'completedEoIds': completedEoIds.toList(),
    'completedQuestIds': completedQuestIds.toList(),
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
      completedEoIds: _intSet(value['completedEoIds']),
      completedQuestIds: _intSet(value['completedQuestIds']),
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
