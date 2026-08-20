import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';
import 'package:yahagi_kancolle_browser/src/performance/frame_notification_coalescer.dart';
import 'package:yahagi_kancolle_browser/src/senka/senka_catalog.dart';
import 'package:yahagi_kancolle_browser/src/senka/senka_controller.dart';
import 'package:yahagi_kancolle_browser/src/senka/senka_state.dart';
import 'package:yahagi_kancolle_browser/src/senka/senka_store.dart';

void main() {
  group('战果奖励状态与目录', () {
    test('奖励状态按未计划、计划、完成循环且未知存储值安全降级', () {
      expect(SenkaRewardStatus.deferred.next, SenkaRewardStatus.planned);
      expect(SenkaRewardStatus.planned.next, SenkaRewardStatus.completed);
      expect(SenkaRewardStatus.completed.next, SenkaRewardStatus.deferred);
      expect(
        SenkaRewardStatus.fromStorage('planned'),
        SenkaRewardStatus.planned,
      );
      expect(
        SenkaRewardStatus.fromStorage('future-value'),
        SenkaRewardStatus.deferred,
      );
      expect(SenkaRewardStatus.fromStorage(null), SenkaRewardStatus.deferred);
    });

    test('目录区分 EO、季度、年度与单次奖励', () {
      expect(senkaEoCatalog, isNotEmpty);
      expect(
        senkaEoCatalog.every((item) => item.category == SenkaRewardCategory.eo),
        isTrue,
      );
      expect(senkaQuarterlyQuestCatalog, hasLength(7));
      expect(
        senkaQuarterlyQuestCatalog.every(
          (item) => item.category == SenkaRewardCategory.quarterly,
        ),
        isTrue,
      );
      expect(
        senkaAnnualQuestCatalog.map(
          (item) => (item.id, item.label, item.senka),
        ),
        containsAll([(947, 'AL作戦', 480), (948, '機動部隊決戦', 600)]),
      );
      expect(
        senkaAnnualQuestCatalog.every(
          (item) => item.category == SenkaRewardCategory.annual,
        ),
        isTrue,
      );
      expect(senkaOneTimeQuestCatalog, hasLength(1));
      expect(senkaOneTimeQuestCatalog.single.id, 949);
      expect(
        senkaOneTimeQuestCatalog.single.label,
        '改装特務空母「Gambier Bay Mk.II」抜錨！',
      );
      expect(senkaOneTimeQuestCatalog.single.shortName, '火球炮');
      expect(senkaOneTimeQuestCatalog.single.senka, 800);
      expect(
        senkaOneTimeQuestCatalog.single.category,
        SenkaRewardCategory.oneTime,
      );
    });

    test('服务器来源解析 w01 到 w20 且非法来源安全降级', () {
      expect(
        senkaServerName('https://w01y.kancolle-server.com'),
        '横須賀鎮守府（横须贺）',
      );
      expect(senkaServerName('https://w01.kancolle-server.com'), '横須賀鎮守府（横须贺）');
      expect(senkaServerName('https://w14p.kancolle-server.com'), '単冠湾泊地（单冠湾）');
      expect(senkaServerName('https://w20i.kancolle-server.com'), '柱島泊地（柱岛）');
      expect(senkaServerName('https://w21.invalid'), '未知服务器');
      expect(senkaServerName('ftp://w01.kancolle-server.com'), '未知服务器');
      expect(senkaServerName('https://w01.evil.example'), '未知服务器');
      expect(
        senkaServerName('https://w01y.kancolle-server.com.evil.example'),
        '未知服务器',
      );
      expect(senkaServerName('not-an-origin'), '未知服务器');
      expect(senkaServerName(''), '未知服务器');
    });
  });

  group('战果状态持久化', () {
    test('新状态字段与出击统计完整往返', () {
      final original = SenkaState.forMonth('2026-08').copyWith(
        serverOrigin: 'https://w14p.kancolle-server.com',
        eoStatuses: const {
          15: SenkaRewardStatus.planned,
          16: SenkaRewardStatus.completed,
        },
        questStatuses: const {947: SenkaRewardStatus.planned},
        targetSenka: 3500,
        calculatorCurrentSenka: 1234.5,
        sortieStats: const {
          '1-5': SenkaSortieStats(
            areaId: 1,
            mapNo: 5,
            sorties: 12,
            bossArrivals: 10,
            sWins: 8,
            aWins: 1,
          ),
        },
        favoriteSortieMapKeys: const {'1-5'},
        hiddenSortieMapKeys: const {'7-1'},
      );

      final restored = SenkaState.fromJson(
        jsonDecode(jsonEncode(original.toJson())),
      );

      expect(restored.eoStatuses, original.eoStatuses);
      expect(restored.serverOrigin, original.serverOrigin);
      expect(restored.questStatuses, original.questStatuses);
      expect(restored.targetSenka, 3500);
      expect(restored.calculatorCurrentSenka, 1234.5);
      expect(restored.sortieStats['1-5']?.sorties, 12);
      expect(restored.sortieStats['1-5']?.bossArrivals, 10);
      expect(restored.sortieStats['1-5']?.sWins, 8);
      expect(restored.sortieStats['1-5']?.aWins, 1);
      expect(restored.favoriteSortieMapKeys, {'1-5'});
      expect(restored.hiddenSortieMapKeys, {'7-1'});
    });

    test('状态对传入和暴露的集合执行防御性不可变复制', () {
      final eoStatuses = <int, SenkaRewardStatus>{
        15: SenkaRewardStatus.planned,
      };
      final questStatuses = <int, SenkaRewardStatus>{
        854: SenkaRewardStatus.completed,
      };
      final sortieStats = <String, SenkaSortieStats>{
        'wrong': const SenkaSortieStats(areaId: 1, mapNo: 5, sorties: 1),
      };
      final favorites = <String>{'1-5', 'bad', '0-1'};
      final hidden = <String>{'7-1', '1-0'};
      final ranking = <String, List<SenkaRankingSnapshot>>{
        '5': [
          SenkaRankingSnapshot(
            rank: 5,
            senka: 1000,
            capturedAt: DateTime.utc(2026, 8, 10),
            localSenkaAtCapture: 100,
          ),
        ],
      };
      final state = SenkaState(
        monthKey: '2026-08',
        eoStatuses: eoStatuses,
        questStatuses: questStatuses,
        sortieStats: sortieStats,
        favoriteSortieMapKeys: favorites,
        hiddenSortieMapKeys: hidden,
        rankingHistory: ranking,
      );

      eoStatuses[16] = SenkaRewardStatus.completed;
      questStatuses.clear();
      sortieStats.clear();
      favorites.clear();
      hidden.clear();
      ranking['5']!.clear();

      expect(state.eoStatuses.keys, {15});
      expect(state.questStatuses.keys, {854});
      expect(state.sortieStats.keys, {'1-5'});
      expect(state.favoriteSortieMapKeys, {'1-5'});
      expect(state.hiddenSortieMapKeys, {'7-1'});
      expect(state.rankingHistory['5'], hasLength(1));
      expect(
        () => state.eoStatuses[16] = SenkaRewardStatus.completed,
        throwsUnsupportedError,
      );
      expect(() => state.questStatuses.clear(), throwsUnsupportedError);
      expect(() => state.sortieStats.clear(), throwsUnsupportedError);
      expect(() => state.favoriteSortieMapKeys.clear(), throwsUnsupportedError);
      expect(() => state.hiddenSortieMapKeys.clear(), throwsUnsupportedError);
      expect(() => state.rankingHistory['5']!.clear(), throwsUnsupportedError);
    });

    test('日期记录对输入执行防御性复制且不可从 state 原地修改', () {
      final inputDays = <String, SenkaDayRecord>{
        '2026-08-10': const SenkaDayRecord(experience: 3.85),
      };
      final state = SenkaState(monthKey: '2026-08', days: inputDays);

      inputDays.clear();

      expect(state.days.keys, {'2026-08-10'});
      expect(() => state.days.clear(), throwsUnsupportedError);
    });

    test('新状态字段存在时优先于旧完成集合', () {
      final state = SenkaState.fromJson(
        jsonDecode(
          jsonEncode({
            'monthKey': '2026-08',
            'eoStatuses': {'15': 'planned'},
            'questStatuses': {'854': 'deferred'},
            'completedEoIds': [15],
            'completedQuestIds': [854],
          }),
        ),
      );

      expect(state.eoStatuses[15], SenkaRewardStatus.planned);
      expect(state.questStatuses[854], SenkaRewardStatus.deferred);
      expect(state.completedEoIds, isEmpty);
      expect(state.completedQuestIds, isEmpty);
    });

    test('兼容 copyWith 完成集合只替换 completed 并保留其他状态', () {
      final state = SenkaState.forMonth('2026-08').copyWith(
        eoStatuses: const {
          15: SenkaRewardStatus.planned,
          16: SenkaRewardStatus.completed,
        },
        questStatuses: const {
          854: SenkaRewardStatus.deferred,
          947: SenkaRewardStatus.completed,
        },
      );

      final copied = state.copyWith(
        completedEoIds: {25},
        completedQuestIds: {948},
      );

      expect(copied.eoStatuses[15], SenkaRewardStatus.planned);
      expect(copied.eoStatuses.containsKey(16), isFalse);
      expect(copied.eoStatuses[25], SenkaRewardStatus.completed);
      expect(copied.questStatuses[854], SenkaRewardStatus.deferred);
      expect(copied.questStatuses.containsKey(947), isFalse);
      expect(copied.questStatuses[948], SenkaRewardStatus.completed);
    });

    test('copyWith 同时传新状态与旧完成集合时新状态优先', () {
      final copied = SenkaState.forMonth('2026-08').copyWith(
        eoStatuses: const {15: SenkaRewardStatus.planned},
        questStatuses: const {854: SenkaRewardStatus.deferred},
        completedEoIds: {25},
        completedQuestIds: {947},
      );

      expect(copied.eoStatuses, {15: SenkaRewardStatus.planned});
      expect(copied.questStatuses, {854: SenkaRewardStatus.deferred});
      expect(copied.completedEoIds, isEmpty);
      expect(copied.completedQuestIds, isEmpty);
    });

    test('地图 key 统一生成且反序列化规范化并过滤非法收藏隐藏项', () {
      expect(senkaMapKey(1, 5), '1-5');
      expect(const SenkaSortieStats(areaId: 7, mapNo: 1).mapKey, '7-1');

      final state = SenkaState.fromJson(
        jsonDecode(
          jsonEncode({
            'monthKey': '2026-08',
            'sortieStats': {
              'wrong': {'areaId': 1, 'mapNo': 5, 'sorties': 3},
              'invalid': {'areaId': 0, 'mapNo': 2, 'sorties': 9},
            },
            'favoriteSortieMapKeys': ['1-5', '01-05', '0-1', 'bad'],
            'hiddenSortieMapKeys': ['7-1', '1-0', '-1-2'],
          }),
        ),
      );

      expect(state.sortieStats.keys, {'1-5'});
      expect(state.sortieStats['1-5']?.sorties, 3);
      expect(state.favoriteSortieMapKeys, {'1-5'});
      expect(state.hiddenSortieMapKeys, {'7-1'});
    });

    test('旧字段缺失时迁移完成集合且未知单项状态降级 deferred', () {
      final state = SenkaState.fromJson({
        'monthKey': '2026-08',
        'memberId': 123,
        'nickname': '矢矧',
        'magic': 36,
        'completedEoIds': [15],
        'completedQuestIds': [854],
        'eoStatuses': {'16': 'future-value'},
        'questStatuses': {'947': 'planned'},
        'days': {
          '2026-08-10': {'experience': 3.85},
        },
        'rankingHistory': {
          '5': [
            {
              'rank': 5,
              'senka': 1000,
              'capturedAt': '2026-08-10T00:00:00Z',
              'localSenkaAtCapture': 3.85,
            },
          ],
        },
      });

      expect(state.eoStatuses[16], SenkaRewardStatus.deferred);
      expect(state.questStatuses[947], SenkaRewardStatus.planned);
      expect(state.completedEoIds, isEmpty);
      expect(state.completedQuestIds, isEmpty);
      expect(state.memberId, 123);
      expect(state.nickname, '矢矧');
      expect(state.magic, 36);
      expect(state.day(DateTime(2026, 8, 10)).experience, 3.85);
      expect(state.rankingHistory['5'], hasLength(1));

      final migrated = SenkaState.fromJson(
        jsonDecode(
          jsonEncode({
            'monthKey': '2026-08',
            'completedEoIds': [15],
            'completedQuestIds': [854],
          }),
        ),
      );
      expect(migrated.eoStatuses[15], SenkaRewardStatus.completed);
      expect(migrated.questStatuses[854], SenkaRewardStatus.completed);
    });

    test('非法或非规范 monthKey 不进入状态并回退当前战果月', () {
      final current = currentSenkaMonthKey();
      for (final invalid in ['2026-8', 'garbage', '9999-99']) {
        expect(
          SenkaState.fromJson({'monthKey': invalid}).monthKey,
          current,
          reason: invalid,
        );
      }
      expect(SenkaState.fromJson({'monthKey': '2026-08'}).monthKey, '2026-08');
    });

    test('非法 monthKey 回退当前月时只保留跨月安全字段', () {
      for (final invalid in ['garbage', '2026-8', '9999-99']) {
        final state = SenkaState.fromJson({
          'monthKey': invalid,
          'serverOrigin': 'https://w14p.kancolle-server.com',
          'memberId': 123,
          'nickname': '矢矧',
          'magic': 61,
          'latestExperience': 100000,
          'days': {
            '2026-08-10': {'experience': 3.85, 'eo': 75, 'quest': 80},
          },
          'eoStatuses': {'15': 'completed'},
          'questStatuses': {
            '854': 'completed',
            '947': 'planned',
            '949': 'completed',
          },
          'targetSenka': 3000,
          'calculatorCurrentSenka': 1200,
          'sortieStats': {
            '1-5': {'areaId': 1, 'mapNo': 5, 'sorties': 1},
          },
          'latestSortieEventAt': '2026-08-10T01:00:00.000Z',
          'lastSortieStartAt': '2026-08-10T01:00:00.000Z',
          'lastSortieStartMapKey': '1-5',
          'activeSortie': {
            'areaId': 1,
            'mapNo': 5,
            'bossCellNo': 4,
            'bossArrived': false,
            'startedAt': '2026-08-10T01:00:00.000Z',
            'lastEventAt': '2026-08-10T01:00:00.000Z',
          },
          'favoriteSortieMapKeys': ['1-5'],
          'hiddenSortieMapKeys': ['7-1'],
          'rankingHistory': {
            '5': [
              {
                'rank': 5,
                'senka': 1000,
                'capturedAt': '2026-08-10T00:00:00Z',
                'localSenkaAtCapture': 0,
              },
            ],
          },
          'rankingUpdatedAt': '2026-08-10T00:00:00Z',
          'updatedAt': '2026-08-10T01:00:00Z',
        });

        expect(state.monthKey, currentSenkaMonthKey(), reason: invalid);
        expect(state.serverOrigin, 'https://w14p.kancolle-server.com');
        expect(state.memberId, 123);
        expect(state.nickname, '矢矧');
        expect(state.magic, 61);
        expect(state.questStatuses, {949: SenkaRewardStatus.completed});
        expect(state.favoriteSortieMapKeys, {'1-5'});
        expect(state.hiddenSortieMapKeys, {'7-1'});
        expect(state.latestExperience, isNull);
        expect(state.days, isEmpty);
        expect(state.eoStatuses, isEmpty);
        expect(state.targetSenka, 0);
        expect(state.calculatorCurrentSenka, 0);
        expect(state.sortieStats, isEmpty);
        expect(state.activeSortie, isNull);
        expect(state.latestSortieEventAt, isNull);
        expect(state.lastSortieStartAt, isNull);
        expect(state.lastSortieStartMapKey, isNull);
        expect(state.rankingHistory, isEmpty);
        expect(state.rankingUpdatedAt, isNull);
        expect(state.updatedAt, isNull);
      }
    });
  });

  test('连续捕获只在下一帧通知一次', () async {
    final scheduled = <void Function()>[];
    final controller = SenkaController(
      store: MemorySenkaStore(),
      now: () => DateTime.utc(2026, 8, 10),
      captureNotifications: FrameNotificationCoalescer(
        scheduleFrame: scheduled.add,
      ),
    );
    var notifications = 0;
    controller.addListener(() => notifications += 1);

    controller
      ..accept(
        event('/kcsapi/api_get_member/basic', {
          'api_member_id': 123,
          'api_nickname': '矢矧',
          'api_experience': 100000,
        }),
      )
      ..accept(
        event('/kcsapi/api_get_member/mapinfo', {
          'api_map_info': [
            {'api_id': 15, 'api_cleared': 1},
          ],
        }),
      );
    await controller.idle;

    expect(controller.state.completedEoIds, {15});
    expect(notifications, 0);
    expect(scheduled, hasLength(1));
    scheduled.single();
    expect(notifications, 1);
    controller.dispose();
  });

  test('初始化加载当月档案并在事件处理后保存', () async {
    final store = MemorySenkaStore(
      SenkaState.forMonth('2026-08').copyWith(memberId: 123),
    );
    final controller = SenkaController(
      store: store,
      now: () => DateTime.utc(2026, 8, 10),
    );

    await controller.initialize();
    controller.accept(
      event('/kcsapi/api_port/port', {
        'api_basic': {
          'api_member_id': 123,
          'api_nickname': '矢矧',
          'api_experience': 100000,
        },
      }),
    );
    await controller.idle;

    expect(controller.state.nickname, '矢矧');
    expect(store.saved?.nickname, '矢矧');
    expect(store.saveCount, 1);
  });

  test('加载旧月份只保留账号身份并创建当月档案', () async {
    final store = MemorySenkaStore(
      SenkaState.forMonth('2026-07').copyWith(
        memberId: 123,
        nickname: '矢矧',
        serverOrigin: 'https://w14p.kancolle-server.com',
        completedEoIds: {15},
        questStatuses: const {
          854: SenkaRewardStatus.planned,
          947: SenkaRewardStatus.completed,
          949: SenkaRewardStatus.planned,
        },
        favoriteSortieMapKeys: const {'1-5'},
        hiddenSortieMapKeys: const {'7-1'},
        targetSenka: 3000,
        calculatorCurrentSenka: 1200,
      ),
    );
    final controller = SenkaController(
      store: store,
      now: () => DateTime.utc(2026, 8, 10),
    );

    await controller.initialize();

    expect(controller.state.monthKey, '2026-08');
    expect(controller.state.memberId, 123);
    expect(controller.state.serverOrigin, 'https://w14p.kancolle-server.com');
    expect(controller.state.completedEoIds, isEmpty);
    expect(controller.state.questStatuses, {
      854: SenkaRewardStatus.planned,
      947: SenkaRewardStatus.completed,
      949: SenkaRewardStatus.planned,
    });
    expect(controller.state.favoriteSortieMapKeys, {'1-5'});
    expect(controller.state.hiddenSortieMapKeys, {'7-1'});
    expect(controller.state.targetSenka, 0);
    expect(controller.state.calculatorCurrentSenka, 0);
    expect(store.saveCount, 1);
    expect(store.saved, same(controller.state));
  });

  test('奖励按 deferred、planned、completed 循环且旧入口保持相同语义', () async {
    final store = MemorySenkaStore();
    final controller = SenkaController(
      store: store,
      now: () => DateTime.utc(2026, 8, 10),
    );
    await controller.initialize();

    controller.cycleEoReward(15);
    controller.cycleQuestReward(854);
    await controller.idle;

    expect(controller.state.eoStatuses[15], SenkaRewardStatus.planned);
    expect(controller.state.questStatuses[854], SenkaRewardStatus.planned);
    expect(controller.state.completedSenka, 0);
    expect(controller.state.monthRecorded, 0);

    controller.toggleEo(15);
    controller.toggleQuest(854);
    await controller.idle;
    expect(controller.state.completedEoIds, {15});
    expect(controller.state.completedQuestIds, {854});

    controller.cycleEoReward(15);
    controller.cycleQuestReward(854);
    await controller.idle;
    expect(controller.state.eoStatuses[15], SenkaRewardStatus.deferred);
    expect(controller.state.questStatuses[854], SenkaRewardStatus.deferred);
    expect(store.saveCount, 3);
    expect(store.saved?.toJson(), controller.state.toJson());
  });

  test('实时战果输入过滤非有限值、负数归零且重复值不保存', () async {
    final store = MemorySenkaStore();
    final controller = SenkaController(
      store: store,
      now: () => DateTime.utc(2026, 8, 10),
    );

    controller.setCurrentSenka(1234.567);
    controller.setTargetSenka(-50);
    controller.setCurrentSenka(double.nan);
    controller.setTargetSenka(double.infinity);
    controller.setCurrentSenka(1234.567);
    controller.setTargetSenka(0);
    await controller.idle;

    expect(controller.state.calculatorCurrentSenka, 1234.567);
    expect(controller.state.targetSenka, 0);
    expect(store.saveCount, 1);
  });

  test('海域收藏和隐藏仅操作已有统计的规范 key 且互不排斥', () async {
    final store = MemorySenkaStore();
    final controller = SenkaController(
      store: store,
      now: () => DateTime.utc(2026, 8, 10),
    );
    controller.accept(
      event('/kcsapi/api_req_map/start', {
        'api_maparea_id': 1,
        'api_mapinfo_no': 5,
        'api_no': 1,
        'api_bosscell_no': 4,
      }),
    );
    await controller.idle;
    final baseline = store.saveCount;

    controller.toggleSortieFavorite('1-5');
    controller.toggleSortieHidden('1-5');
    controller.toggleSortieFavorite('01-05');
    controller.toggleSortieHidden('7-1');
    await controller.idle;

    expect(controller.state.favoriteSortieMapKeys, {'1-5'});
    expect(controller.state.hiddenSortieMapKeys, {'1-5'});
    expect(controller.state.sortieStats['1-5']?.sorties, 1);
    expect(store.saveCount, baseline + 1);
    expect(store.saved?.toJson(), controller.state.toJson());
  });

  test('同月初始化不产生多余保存', () async {
    final store = MemorySenkaStore(SenkaState.forMonth('2026-08'));
    final controller = SenkaController(
      store: store,
      now: () => DateTime.utc(2026, 8, 10),
    );

    await controller.initialize();

    expect(store.saveCount, 0);
  });

  test('同一时间捕获的多条数据依次入档不丢失', () async {
    final store = MemorySenkaStore();
    final controller = SenkaController(
      store: store,
      now: () => DateTime.utc(2026, 8, 10),
    );
    await controller.initialize();

    controller.accept(
      event('/kcsapi/api_port/port', {
        'api_basic': {
          'api_member_id': 123,
          'api_nickname': '矢矧',
          'api_experience': 100000,
        },
      }),
    );
    controller.accept(
      event('/kcsapi/api_get_member/mapinfo', {
        'api_map_info': [
          {'api_id': 15, 'api_cleared': 1},
        ],
      }),
    );
    await controller.idle;

    expect(controller.state.nickname, '矢矧');
    expect(controller.state.completedEoIds, {15});
    expect(store.saveCount, 2);
  });

  test('accept 后同步设置目标不会由旧快照覆盖身份', () async {
    final store = MemorySenkaStore();
    final controller = SenkaController(
      store: store,
      now: () => DateTime.utc(2026, 8, 10),
    );

    controller.accept(
      event('/kcsapi/api_get_member/basic', {
        'api_member_id': 123,
        'api_nickname': '矢矧',
        'api_experience': 100000,
      }),
    );
    controller.setTargetSenka(100);
    await controller.idle;

    expect(controller.state.nickname, '矢矧');
    expect(controller.state.targetSenka, 100);
    expect(store.saved?.toJson(), controller.state.toJson());
    expect(store.saveCount, 1);
  });

  test('accept 后同步循环奖励不会由旧快照覆盖身份', () async {
    final store = MemorySenkaStore();
    final controller = SenkaController(
      store: store,
      now: () => DateTime.utc(2026, 8, 10),
    );

    controller.accept(
      event('/kcsapi/api_get_member/basic', {
        'api_member_id': 123,
        'api_nickname': '矢矧',
        'api_experience': 100000,
      }),
    );
    controller.cycleQuestReward(854);
    await controller.idle;

    expect(controller.state.nickname, '矢矧');
    expect(controller.state.questStatuses[854], SenkaRewardStatus.planned);
    expect(store.saved?.toJson(), controller.state.toJson());
    expect(store.saveCount, 1);
  });

  test('连续同步设置后 accept 基于最新状态并持久化最终快照', () async {
    final store = MemorySenkaStore();
    final controller = SenkaController(
      store: store,
      now: () => DateTime.utc(2026, 8, 10),
    );

    controller
      ..setTargetSenka(100)
      ..setTargetSenka(200)
      ..accept(
        event('/kcsapi/api_get_member/basic', {
          'api_member_id': 123,
          'api_nickname': '矢矧',
          'api_experience': 100000,
        }),
      );
    await controller.idle;

    expect(controller.state.nickname, '矢矧');
    expect(controller.state.targetSenka, 200);
    expect(store.saved?.toJson(), controller.state.toJson());
    expect(store.saveCount, 2);
  });

  test('一次保存失败后队列恢复且后续 accept 正常归档', () async {
    final store = RecoveringSenkaStore(failSaveCount: 1);
    final controller = SenkaController(
      store: store,
      now: () => DateTime.utc(2026, 8, 10),
    );

    controller.setTargetSenka(100);
    await controller.idle;
    controller.accept(
      event('/kcsapi/api_get_member/basic', {
        'api_member_id': 123,
        'api_nickname': '矢矧',
        'api_experience': 100000,
      }),
    );
    await controller.idle;

    expect(store.saveAttempts, 2);
    expect(store.saveCount, 1);
    expect(store.saved?.toJson(), controller.state.toJson());
  });

  test('延迟保存交错仍由最终 revision 覆盖且次数确定', () async {
    final store = DelayedSenkaStore();
    final controller = SenkaController(
      store: store,
      now: () => DateTime.utc(2026, 8, 10),
    );

    controller.setTargetSenka(100);
    await store.firstSaveStarted.future;
    controller.accept(
      event('/kcsapi/api_get_member/basic', {
        'api_member_id': 123,
        'api_nickname': '矧',
        'api_experience': 100000,
      }),
    );
    controller.setTargetSenka(200);
    store.releaseFirstSave.complete();
    await controller.idle;

    expect(store.saveCount, 2);
    expect(store.saved?.toJson(), controller.state.toJson());
  });

  test('延迟加载期间同步更新不会被 initialize 旧档覆盖', () async {
    final store = DelayedLoadSenkaStore(
      SenkaState.forMonth('2026-08').copyWith(nickname: '旧档'),
    );
    final controller = SenkaController(
      store: store,
      now: () => DateTime.utc(2026, 8, 10),
    );

    final initializing = controller.initialize();
    await store.loadStarted.future;
    controller.setTargetSenka(100);
    store.releaseLoad.complete();
    await initializing;
    await controller.idle;

    expect(controller.state.nickname, isEmpty);
    expect(controller.state.targetSenka, 100);
    expect(store.saveCount, 1);
    expect(store.saved?.toJson(), controller.state.toJson());
  });

  test('初始化加载失败保持空状态且后续操作可恢复', () async {
    final store = RecoveringSenkaStore(failLoadCount: 1);
    final controller = SenkaController(
      store: store,
      now: () => DateTime.utc(2026, 8, 10),
    );

    await controller.initialize();
    controller.setTargetSenka(100);
    await controller.idle;

    expect(controller.state.targetSenka, 100);
    expect(store.saveCount, 1);
    expect(store.saved?.toJson(), controller.state.toJson());
  });

  test('dispose 后等待已开始保存但不处理排队 accept', () async {
    final store = DelayedSenkaStore();
    final controller = SenkaController(
      store: store,
      now: () => DateTime.utc(2026, 8, 10),
    );

    controller.setTargetSenka(100);
    await store.firstSaveStarted.future;
    controller.accept(
      event('/kcsapi/api_get_member/basic', {
        'api_member_id': 123,
        'api_nickname': '不应处理',
        'api_experience': 100000,
      }),
    );
    controller.dispose();
    store.releaseFirstSave.complete();
    await controller.idle;

    expect(controller.state.nickname, isEmpty);
    expect(store.saveCount, 1);
    expect(store.saved?.toJson(), controller.state.toJson());
  });

  test('EO 自动同步后旧入口继续循环到 deferred', () async {
    final controller = SenkaController(
      store: MemorySenkaStore(),
      now: () => DateTime.utc(2026, 8, 10),
    );
    await controller.initialize();
    controller.accept(
      event('/kcsapi/api_get_member/mapinfo', {
        'api_map_info': [
          {'api_id': 15, 'api_cleared': 1},
        ],
      }),
    );
    await controller.idle;
    expect(controller.state.completedEoIds, {15});

    controller.toggleEo(15);
    await controller.idle;
    expect(controller.state.eoStatuses[15], SenkaRewardStatus.deferred);
    controller.dispose();
  });
}

class MemorySenkaStore implements SenkaStore {
  MemorySenkaStore([this.saved]);

  SenkaState? saved;
  int saveCount = 0;

  @override
  Future<SenkaState?> load() async => saved;

  @override
  Future<void> save(SenkaState state) async {
    saved = state;
    saveCount++;
  }
}

class RecoveringSenkaStore extends MemorySenkaStore {
  RecoveringSenkaStore({this.failLoadCount = 0, this.failSaveCount = 0});

  int failLoadCount;
  int failSaveCount;
  int saveAttempts = 0;

  @override
  Future<SenkaState?> load() async {
    if (failLoadCount > 0) {
      failLoadCount--;
      throw StateError('load failed');
    }
    return super.load();
  }

  @override
  Future<void> save(SenkaState state) async {
    saveAttempts++;
    if (failSaveCount > 0) {
      failSaveCount--;
      throw StateError('save failed');
    }
    await super.save(state);
  }
}

class DelayedSenkaStore extends MemorySenkaStore {
  final firstSaveStarted = Completer<void>();
  final releaseFirstSave = Completer<void>();
  bool _delayed = false;

  @override
  Future<void> save(SenkaState state) async {
    if (!_delayed) {
      _delayed = true;
      firstSaveStarted.complete();
      await releaseFirstSave.future;
    }
    await super.save(state);
  }
}

class DelayedLoadSenkaStore extends MemorySenkaStore {
  DelayedLoadSenkaStore(super.saved);

  final loadStarted = Completer<void>();
  final releaseLoad = Completer<void>();

  @override
  Future<SenkaState?> load() async {
    loadStarted.complete();
    await releaseLoad.future;
    return super.load();
  }
}

CapturedApiEvent event(String path, Object data) => CapturedApiEvent(
  path: path,
  responseBody: jsonEncode({'api_result': 1, 'api_data': data}),
  source: CaptureSource.manual,
  capturedAt: DateTime.utc(2026, 8, 10, 3),
);
