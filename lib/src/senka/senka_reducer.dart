import '../bridge/captured_api_event.dart';
import '../capture/game_capture_path_catalog.dart';
import '../game_state/game_api_decoder.dart';
import 'senka_catalog.dart';
import 'senka_state.dart';

class SenkaReducer {
  const SenkaReducer();

  static const _rankingPath = GameCapturePathCatalog.senkaRanking;
  static const _magicLeft = [36, 31, 33, 97, 64, 54, 52, 78, 40, 85];
  static const _magicRight = [
    8931,
    1201,
    1156,
    5061,
    4569,
    4732,
    3779,
    4568,
    5695,
    4619,
    4912,
    5669,
    6586,
  ];
  static const _experiencePaths = GameCapturePathCatalog.senkaExperience;

  SenkaState reduce(SenkaState state, CapturedApiEvent event) {
    final monthKey = currentSenkaMonthKey(event.capturedAt);
    final stateMonth = parseSenkaMonthKey(state.monthKey);
    final eventMonth = parseSenkaMonthKey(monthKey)!;
    if (stateMonth != null &&
        (eventMonth.year * 12 + eventMonth.month) <
            (stateMonth.year * 12 + stateMonth.month)) {
      return state;
    }
    var current = migrateSenkaStateToMonth(state, monthKey);
    if (_isSortieLifecyclePath(event.path) &&
        current.latestSortieEventAt != null &&
        event.capturedAt.isBefore(current.latestSortieEventAt!)) {
      return current;
    }
    if (!supportsPath(event.path)) return current;
    if (event.sourceOrigin.isNotEmpty) {
      current = current.copyWith(serverOrigin: event.sourceOrigin);
    }

    final data = GameApiDecoder.decodeEventData(event);
    if (data is! Map) {
      if (_sortieResultPaths.contains(event.path)) {
        final active = current.activeSortie;
        return current.copyWith(
          clearActiveSortie: active?.bossArrived == true,
          latestSortieEventAt: event.capturedAt,
          updatedAt: event.capturedAt,
        );
      }
      if (_clearsActiveSortie(event.path) || event.path == _sortieStartPath) {
        return current.copyWith(
          clearActiveSortie: true,
          latestSortieEventAt: event.capturedAt,
          updatedAt: event.capturedAt,
        );
      }
      if (event.path == '/kcsapi/api_req_map/next') {
        return current.copyWith(
          latestSortieEventAt: event.capturedAt,
          updatedAt: event.capturedAt,
        );
      }
      return current;
    }
    final map = data.cast<Object?, Object?>();

    current = _identity(current, event.path, map);
    if (_experiencePaths.contains(event.path)) {
      current = _experience(current, event.path, map, event.capturedAt);
    }
    if (event.path == '/kcsapi/api_get_member/mapinfo') {
      current = _mapInfo(current, map, event.capturedAt);
    } else if (event.path == _rankingPath) {
      current = _ranking(current, map, event.capturedAt);
    }
    current = _sortie(current, event.path, map, event.capturedAt);
    return current.copyWith(updatedAt: event.capturedAt);
  }

  bool supportsPath(String path) => GameCapturePathCatalog.senka.contains(path);

  SenkaState _identity(
    SenkaState state,
    String path,
    Map<Object?, Object?> data,
  ) {
    Map<Object?, Object?>? basic;
    if (path == '/kcsapi/api_port/port') {
      basic = _map(data['api_basic']);
    } else if (path == '/kcsapi/api_get_member/basic') {
      basic = data;
    }
    if (basic == null) return state;
    return state.copyWith(
      memberId: _int(basic['api_member_id'], state.memberId),
      nickname: '${basic['api_nickname'] ?? state.nickname}',
    );
  }

  SenkaState _sortie(
    SenkaState state,
    String path,
    Map<Object?, Object?> data,
    DateTime capturedAt,
  ) {
    if (_clearsActiveSortie(path)) {
      return state.copyWith(
        clearActiveSortie: true,
        latestSortieEventAt: capturedAt,
      );
    }
    if (path == _sortieStartPath) {
      return _startSortie(state, data, capturedAt);
    }
    if (path == '/kcsapi/api_req_map/next') {
      return _nextNode(state, data, capturedAt);
    }
    if (_sortieResultPaths.contains(path)) {
      return _sortieResult(state, data, capturedAt);
    }
    return state;
  }

  SenkaState _startSortie(
    SenkaState state,
    Map<Object?, Object?> data,
    DateTime capturedAt,
  ) {
    final areaId = _positiveInt(data['api_maparea_id']);
    final mapNo = _positiveInt(data['api_mapinfo_no']);
    if (areaId == null || mapNo == null) {
      return state.copyWith(
        clearActiveSortie: true,
        latestSortieEventAt: capturedAt,
      );
    }
    final nodeNo = _positiveInt(data['api_no']);
    final bossCellNo = _positiveInt(data['api_bosscell_no']);
    final arrived = nodeNo != null && nodeNo == bossCellNo;
    final mapKey = senkaMapKey(areaId, mapNo);
    if (state.lastSortieStartAt == capturedAt.toUtc() &&
        state.lastSortieStartMapKey == mapKey) {
      return state.copyWith(latestSortieEventAt: capturedAt);
    }
    final active = SenkaActiveSortie(
      areaId: areaId,
      mapNo: mapNo,
      bossCellNo: bossCellNo,
      bossArrived: arrived,
      startedAt: capturedAt,
      lastEventAt: capturedAt,
    );
    final stats = _updatedSortieStats(
      state,
      active,
      sorties: 1,
      bossArrivals: arrived ? 1 : 0,
    );
    return state.copyWith(
      sortieStats: stats,
      activeSortie: active,
      latestSortieEventAt: capturedAt,
      lastSortieStartAt: capturedAt,
      lastSortieStartMapKey: mapKey,
    );
  }

  SenkaState _nextNode(
    SenkaState state,
    Map<Object?, Object?> data,
    DateTime capturedAt,
  ) {
    final active = state.activeSortie;
    if (active == null) {
      return state.copyWith(latestSortieEventAt: capturedAt);
    }
    final nodeNo = _positiveInt(data['api_no']);
    final responseBossCellNo = _positiveInt(data['api_bosscell_no']);
    final arrived =
        nodeNo != null &&
        (nodeNo == active.bossCellNo || nodeNo == responseBossCellNo);
    final nextActive = active.copyWith(
      bossCellNo: responseBossCellNo,
      lastEventAt: capturedAt,
    );
    if (!arrived || active.bossArrived) {
      return state.copyWith(
        activeSortie: nextActive,
        latestSortieEventAt: capturedAt,
      );
    }
    return state.copyWith(
      sortieStats: _updatedSortieStats(state, active, bossArrivals: 1),
      activeSortie: nextActive.copyWith(bossArrived: true),
      latestSortieEventAt: capturedAt,
    );
  }

  SenkaState _sortieResult(
    SenkaState state,
    Map<Object?, Object?> data,
    DateTime capturedAt,
  ) {
    final active = state.activeSortie;
    if (active == null) {
      return state.copyWith(latestSortieEventAt: capturedAt);
    }
    if (!active.bossArrived) {
      return state.copyWith(
        activeSortie: active.copyWith(lastEventAt: capturedAt),
        latestSortieEventAt: capturedAt,
      );
    }
    final rank = '${data['api_win_rank'] ?? ''}'.toUpperCase();
    final stats = switch (rank) {
      'S' || 'SS' => _updatedSortieStats(state, active, sWins: 1),
      'A' => _updatedSortieStats(state, active, aWins: 1),
      _ => state.sortieStats,
    };
    return state.copyWith(
      sortieStats: stats,
      clearActiveSortie: true,
      latestSortieEventAt: capturedAt,
    );
  }

  Map<String, SenkaSortieStats> _updatedSortieStats(
    SenkaState state,
    SenkaActiveSortie active, {
    int sorties = 0,
    int bossArrivals = 0,
    int sWins = 0,
    int aWins = 0,
  }) {
    final result = Map<String, SenkaSortieStats>.of(state.sortieStats);
    final current =
        result[active.mapKey] ??
        SenkaSortieStats(areaId: active.areaId, mapNo: active.mapNo);
    result[active.mapKey] = current.copyWith(
      sorties: current.sorties + sorties,
      bossArrivals: current.bossArrivals + bossArrivals,
      sWins: current.sWins + sWins,
      aWins: current.aWins + aWins,
    );
    return result;
  }

  SenkaState _experience(
    SenkaState state,
    String path,
    Map<Object?, Object?> data,
    DateTime capturedAt,
  ) {
    final experience = switch (path) {
      '/kcsapi/api_port/port' => _int(
        _map(data['api_basic'])?['api_experience'],
      ),
      '/kcsapi/api_get_member/record' => _firstInt(data['api_experience']),
      '/kcsapi/api_get_member/basic' => _int(data['api_experience']),
      _ => _int(data['api_member_exp']),
    };
    if (experience <= 0) return state;
    final previous = state.latestExperience;
    if (previous == null || experience <= previous) {
      return state.copyWith(latestExperience: experience);
    }
    final gained = (experience - previous) * experienceToSenkaRate;
    return _addDay(
      state.copyWith(latestExperience: experience),
      capturedAt,
      experience: gained,
    );
  }

  SenkaState _mapInfo(
    SenkaState state,
    Map<Object?, Object?> data,
    DateTime capturedAt,
  ) {
    final values = data['api_map_info'];
    if (values is! List) return state;
    final cleared = <int>{};
    final known = <int>{};
    for (final value in values) {
      final map = _map(value);
      if (map == null) continue;
      final id = _int(map['api_id']);
      if (senkaEoById(id) == null) continue;
      known.add(id);
      if (_int(map['api_cleared']) > 0) cleared.add(id);
    }
    if (known.isEmpty) return state;
    final completed = Set<int>.of(state.completedEoIds)
      ..removeAll(known)
      ..addAll(cleared);
    final newlyCleared = cleared.difference(state.completedEoIds);
    final gained = newlyCleared.fold<double>(
      0,
      (sum, id) => sum + (senkaEoById(id)?.senka ?? 0),
    );
    final next = state.copyWith(completedEoIds: completed);
    return gained == 0 ? next : _addDay(next, capturedAt, eo: gained);
  }

  SenkaState _ranking(
    SenkaState state,
    Map<Object?, Object?> data,
    DateTime capturedAt,
  ) {
    final rawList = data['api_list'];
    if (rawList is! List) return state;
    final refreshed = state.copyWith(rankingUpdatedAt: capturedAt);
    if (state.memberId <= 0) return refreshed;
    final rows = rawList.map(_map).whereType<Map<Object?, Object?>>().toList();
    if (rows.isEmpty) return refreshed;
    final inferredMagic = _inferMagic(rows);
    final decryptState = inferredMagic == null
        ? refreshed
        : refreshed.copyWith(magic: inferredMagic);
    final history = <String, List<SenkaRankingSnapshot>>{
      for (final entry in state.rankingHistory.entries)
        entry.key: List<SenkaRankingSnapshot>.of(entry.value),
    };
    final page = _int(data['api_disp_page']);
    double? playerSenka;
    for (final raw in rows) {
      final rank = _int(raw['api_mxltvkpyuklh']);
      final encrypted = _int(raw['api_wuhnhojjxmke']);
      if (rank <= 0 || encrypted <= 0) continue;
      final senka = _decrypt(decryptState, rank, encrypted);
      String? key;
      if (const {5, 20, 100, 501}.contains(rank) &&
          page == (rank / 10).ceil()) {
        key = '$rank';
      }
      if ('${raw['api_mtjmdcwtvhdr'] ?? ''}' == state.nickname) {
        key = 'player';
        playerSenka = senka;
      }
      if (key == null) continue;
      final snapshots = history.putIfAbsent(key, () => []);
      snapshots.add(
        SenkaRankingSnapshot(
          rank: rank,
          senka: senka,
          capturedAt: capturedAt,
          localSenkaAtCapture: state.monthRecorded,
        ),
      );
      if (snapshots.length > 2) snapshots.removeAt(0);
    }
    return decryptState.copyWith(
      rankingHistory: history,
      calculatorCurrentSenka: playerSenka,
    );
  }

  double _decrypt(SenkaState state, int rank, int encrypted) {
    final magic = state.magic > 9
        ? state.magic
        : _magicLeft[state.memberId % 10];
    final value = encrypted / _magicRight[rank % 13] / magic - 73 - 18;
    return value > 0 ? value : 0;
  }

  int? _inferMagic(List<Map<Object?, Object?>> rows) {
    if (rows.length < 2) return null;
    final factors = <int>[];
    for (final row in rows) {
      final rank = _int(row['api_mxltvkpyuklh']);
      final encrypted = _int(row['api_wuhnhojjxmke']);
      if (rank <= 0 || encrypted <= 0) return null;
      final right = _magicRight[rank % 13];
      if (encrypted % right != 0) return null;
      factors.add(encrypted ~/ right);
    }
    var divisor = factors.first;
    for (final factor in factors.skip(1)) {
      divisor = _gcd(divisor, factor);
    }
    if (divisor > 9 && divisor < 99) return divisor;
    for (var candidate = 99; candidate > 9; candidate--) {
      if (divisor % candidate == 0) return candidate;
    }
    return null;
  }

  SenkaState _addDay(
    SenkaState state,
    DateTime capturedAt, {
    double experience = 0,
    double eo = 0,
    double quest = 0,
  }) {
    final businessDate = senkaBusinessDate(capturedAt);
    final key = dateKey(businessDate);
    final days = Map<String, SenkaDayRecord>.of(state.days);
    days[key] = (days[key] ?? const SenkaDayRecord()).add(
      experience: experience,
      eo: eo,
      quest: quest,
    );
    return state.copyWith(days: days);
  }
}

const _sortieStartPath = '/kcsapi/api_req_map/start';
const _sortieResultPaths = <String>{
  '/kcsapi/api_req_sortie/battleresult',
  '/kcsapi/api_req_combined_battle/battleresult',
};

bool _clearsActiveSortie(String path) =>
    path == '/kcsapi/api_port/port' ||
    path == '/kcsapi/api_req_sortie/goback_port' ||
    path == '/kcsapi/api_req_combined_battle/goback_port';

bool _isSortieLifecyclePath(String path) =>
    path == _sortieStartPath ||
    path == '/kcsapi/api_req_map/next' ||
    _sortieResultPaths.contains(path) ||
    _clearsActiveSortie(path);

Map<Object?, Object?>? _map(Object? value) =>
    value is Map ? value.cast<Object?, Object?>() : null;

int _int(Object? value, [int fallback = 0]) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? fallback;

int _firstInt(Object? value) =>
    value is List && value.isNotEmpty ? _int(value.first) : _int(value);

int? _positiveInt(Object? value) {
  if (value is! num || !value.isFinite) return null;
  final result = value.toInt();
  return result > 0 && value == result ? result : null;
}

int _gcd(int left, int right) => right == 0 ? left : _gcd(right, left % right);
