import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';
import 'package:yahagi_kancolle_browser/src/senka/senka_catalog.dart';
import 'package:yahagi_kancolle_browser/src/senka/senka_reducer.dart';
import 'package:yahagi_kancolle_browser/src/senka/senka_state.dart';

void main() {
  const reducer = SenkaReducer();

  test('经验差按 7/10000 计入捕获日战果', () {
    var state = SenkaState.forMonth('2026-08');
    state = reducer.reduce(
      state,
      apiEvent('/kcsapi/api_port/port', {
        'api_basic': {
          'api_member_id': 123,
          'api_nickname': '矢矧',
          'api_experience': 100000,
        },
      }, atJst: DateTime(2026, 8, 10, 3)),
    );
    state = reducer.reduce(
      state,
      apiEvent('/kcsapi/api_req_sortie/battleresult', {
        'api_member_exp': 105500,
      }, atJst: DateTime(2026, 8, 10, 12)),
    );

    expect(state.day(DateTime(2026, 8, 10)).experience, 3.85);
    expect(state.monthRecorded, 3.85);
  });

  test('地图信息自动同步九个 EO 并记录新增战果', () {
    var state = SenkaState.forMonth('2026-08');
    state = reducer.reduce(
      state,
      apiEvent('/kcsapi/api_get_member/mapinfo', {
        'api_map_info': [
          {'api_id': 15, 'api_cleared': 1},
          {'api_id': 56, 'api_cleared': 1},
          {'api_id': 75, 'api_cleared': 0},
        ],
      }, atJst: DateTime(2026, 8, 10, 9)),
    );

    expect(state.completedEoIds, {15, 56});
    expect(state.completedSenka, 300);
    expect(state.day(DateTime(2026, 8, 10)).eo, 300);
    expect(senkaEoCatalog.map((item) => item.id), containsAll([15, 56, 75]));
  });

  test('战果任务接口不自动改变玩家手动状态', () {
    var state = SenkaState.forMonth('2026-08');
    for (final quest in senkaQuestCatalog) {
      state = reducer.reduce(
        state,
        apiEvent(
          '/kcsapi/api_req_quest/clearitemget',
          const {},
          params: {'api_quest_id': '${quest.id}'},
          atJst: DateTime(2026, 8, 11, 8),
        ),
      );
    }

    expect(state.completedQuestIds, isEmpty);
    expect(state.day(DateTime(2026, 8, 11)).quest, 0);
  });

  test('排名响应解密锚点和当前玩家并保留两次快照的变化', () {
    var state = SenkaState.forMonth(
      '2026-08',
    ).copyWith(memberId: 123, nickname: '矢矧');
    state = reducer.reduce(
      state,
      rankingEvent(
        page: 1,
        rows: [rankingRow(rank: 5, senka: 4755, nickname: '五位')],
        atJst: DateTime(2026, 8, 10, 3, 5),
      ),
    );
    state = reducer.reduce(
      state,
      rankingEvent(
        page: 1,
        rows: [rankingRow(rank: 5, senka: 4828, nickname: '五位')],
        atJst: DateTime(2026, 8, 10, 15, 5),
      ),
    );
    state = reducer.reduce(
      state,
      rankingEvent(
        page: 388,
        rows: [rankingRow(rank: 3874, senka: 108, nickname: '矢矧')],
        atJst: DateTime(2026, 8, 10, 15, 6),
      ),
    );
    state = reducer.reduce(
      state,
      rankingEvent(
        page: 384,
        rows: [rankingRow(rank: 3832, senka: 112, nickname: '矢矧')],
        atJst: DateTime(2026, 8, 11, 3, 6),
      ),
    );

    final rank5 = state.rankingRow(5);
    final player = state.playerRankingRow;
    expect(rank5.senka, 4828);
    expect(rank5.senkaDelta, 73);
    expect(player.rank, 3832);
    expect(player.rankDelta, 42);
    expect(player.rankDirection, SenkaRankDirection.up);
    expect(player.senka, 112);
  });

  test('排名页自动推导变化后的解密系数，不需要手动校准', () {
    var state = SenkaState.forMonth(
      '2026-08',
    ).copyWith(memberId: 123, nickname: '矢矧');
    state = reducer.reduce(
      state,
      rankingEvent(
        page: 1,
        rows: [
          rankingRow(rank: 1, senka: 1000, nickname: '一位', magic: 61),
          rankingRow(rank: 2, senka: 1001, nickname: '二位', magic: 61),
          rankingRow(rank: 5, senka: 4755, nickname: '五位', magic: 61),
        ],
        atJst: DateTime(2026, 8, 10, 15),
      ),
    );

    expect(state.magic, 61);
    expect(state.rankingRow(5).senka, 4755);
  });

  test('当前玩家变化只包含可自动确认的经验与 EO 战果', () {
    var state = SenkaState.forMonth(
      '2026-08',
    ).copyWith(memberId: 123, nickname: '矢矧', latestExperience: 100000);
    state = reducer.reduce(
      state,
      rankingEvent(
        page: 44,
        rows: [rankingRow(rank: 431, senka: 3421, nickname: '矢矧')],
        atJst: DateTime(2026, 8, 10, 3),
      ),
    );
    state = reducer.reduce(
      state,
      apiEvent('/kcsapi/api_req_sortie/battleresult', {
        'api_member_exp': 105500,
      }, atJst: DateTime(2026, 8, 10, 8)),
    );
    state = reducer.reduce(
      state,
      apiEvent('/kcsapi/api_get_member/mapinfo', {
        'api_map_info': [
          {'api_id': 15, 'api_cleared': 1},
        ],
      }, atJst: DateTime(2026, 8, 10, 9)),
    );
    state = reducer.reduce(
      state,
      apiEvent(
        '/kcsapi/api_req_quest/clearitemget',
        const {},
        params: const {'api_quest_id': '284'},
        atJst: DateTime(2026, 8, 10, 10),
      ),
    );

    expect(state.playerRankingRow.senkaDelta, closeTo(78.85, 0.0001));
  });

  test('新月份事件清空月度完成状态但保留账号身份', () {
    final old = SenkaState.forMonth('2026-07').copyWith(
      memberId: 123,
      nickname: '矢矧',
      completedEoIds: {15},
      completedQuestIds: {854},
    );
    final next = reducer.reduce(
      old,
      apiEvent('/kcsapi/api_port/port', {
        'api_basic': {
          'api_member_id': 123,
          'api_nickname': '矢矧',
          'api_experience': 200000,
        },
      }, atJst: DateTime(2026, 8, 1, 3)),
    );

    expect(next.monthKey, '2026-08');
    expect(next.completedEoIds, isEmpty);
    expect(next.completedQuestIds, isEmpty);
    expect(next.memberId, 123);
  });

  test('最后排名刷新时间取所有排名快照中的最新时间', () {
    final state = SenkaState.forMonth('2026-08').copyWith(
      rankingHistory: {
        '5': [
          snapshotAt(DateTime.utc(2026, 8, 10, 3)),
          snapshotAt(DateTime.utc(2026, 8, 10, 6)),
        ],
        'player': [snapshotAt(DateTime.utc(2026, 8, 10, 5))],
      },
    );

    expect(state.latestRankingUpdatedAt, DateTime.utc(2026, 8, 10, 6));
  });

  test('刷新任意排名页都会单独记录最后刷新时间', () {
    final state = reducer.reduce(
      SenkaState.forMonth('2026-08').copyWith(memberId: 123, nickname: '矢矧'),
      rankingEvent(
        page: 2,
        rows: [rankingRow(rank: 11, senka: 900, nickname: '十一位')],
        atJst: DateTime(2026, 8, 10, 16, 41, 47),
      ),
    );

    expect(state.latestRankingUpdatedAt, DateTime.utc(2026, 8, 10, 7, 41, 47));
  });
}

CapturedApiEvent apiEvent(
  String path,
  Object data, {
  Map<String, Object?> params = const {},
  required DateTime atJst,
}) {
  return CapturedApiEvent(
    path: path,
    requestParams: params,
    responseBody: jsonEncode({'api_result': 1, 'api_data': data}),
    source: CaptureSource.manual,
    capturedAt: DateTime.utc(
      atJst.year,
      atJst.month,
      atJst.day,
      atJst.hour,
      atJst.minute,
      atJst.second,
    ).subtract(const Duration(hours: 9)),
  );
}

CapturedApiEvent rankingEvent({
  required int page,
  required List<Map<String, Object?>> rows,
  required DateTime atJst,
}) => apiEvent('/kcsapi/api_req_ranking/mxltvkpyuklh', {
  'api_disp_page': page,
  'api_list': rows,
}, atJst: atJst);

Map<String, Object?> rankingRow({
  required int rank,
  required int senka,
  required String nickname,
  int? magic,
}) {
  const magicLeft = [36, 31, 33, 97, 64, 54, 52, 78, 40, 85];
  const magicRight = [
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
  const memberId = 123;
  final actualMagic = magic ?? magicLeft[memberId % 10];
  return {
    'api_mxltvkpyuklh': rank,
    'api_mtjmdcwtvhdr': nickname,
    'api_wuhnhojjxmke': (senka + 73 + 18) * magicRight[rank % 13] * actualMagic,
  };
}

SenkaRankingSnapshot snapshotAt(DateTime capturedAt) => SenkaRankingSnapshot(
  rank: 1,
  senka: 1,
  capturedAt: capturedAt,
  localSenkaAtCapture: 0,
);
