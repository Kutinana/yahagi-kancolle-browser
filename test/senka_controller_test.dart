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
      expect(senkaQuarterlyQuestCatalog, hasLength(7));
      expect(
        senkaAnnualQuestCatalog.map(
          (item) => (item.id, item.label, item.senka),
        ),
        containsAll([(947, 'AL作戦', 480), (948, '機動部隊決戦', 600)]),
      );
      expect(senkaOneTimeQuestCatalog, hasLength(1));
      expect(senkaOneTimeQuestCatalog.single.id, 949);
      expect(
        senkaOneTimeQuestCatalog.single.label,
        '改装特務空母「Gambier Bay Mk.II」抜錨！',
      );
      expect(senkaOneTimeQuestCatalog.single.shortName, '火球炮');
      expect(senkaOneTimeQuestCatalog.single.senka, 800);
    });
  });

  group('战果状态持久化', () {
    test('新状态字段与出击统计完整往返', () {
      final original = SenkaState.forMonth('2026-08').copyWith(
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

      final restored = SenkaState.fromJson(original.toJson());

      expect(restored.eoStatuses, original.eoStatuses);
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

    test('旧完成集合迁移为 completed 且未知单项状态降级 deferred', () {
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

      expect(state.eoStatuses[15], SenkaRewardStatus.completed);
      expect(state.eoStatuses[16], SenkaRewardStatus.deferred);
      expect(state.questStatuses[854], SenkaRewardStatus.completed);
      expect(state.questStatuses[947], SenkaRewardStatus.planned);
      expect(state.completedEoIds, {15});
      expect(state.completedQuestIds, {854});
      expect(state.memberId, 123);
      expect(state.nickname, '矢矧');
      expect(state.magic, 36);
      expect(state.day(DateTime(2026, 8, 10)).experience, 3.85);
      expect(state.rankingHistory['5'], hasLength(1));
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
      SenkaState.forMonth(
        '2026-07',
      ).copyWith(memberId: 123, nickname: '矢矧', completedEoIds: {15}),
    );
    final controller = SenkaController(
      store: store,
      now: () => DateTime.utc(2026, 8, 10),
    );

    await controller.initialize();

    expect(controller.state.monthKey, '2026-08');
    expect(controller.state.memberId, 123);
    expect(controller.state.completedEoIds, isEmpty);
  });

  test('手动切换 EO 和任务只改变完成状态不伪造日历记录', () async {
    final store = MemorySenkaStore();
    final controller = SenkaController(
      store: store,
      now: () => DateTime.utc(2026, 8, 10),
    );
    await controller.initialize();

    controller.toggleEo(15);
    controller.toggleQuest(854);
    await controller.idle;

    expect(controller.state.completedEoIds, {15});
    expect(controller.state.completedQuestIds, {854});
    expect(controller.state.completedSenka, 425);
    expect(controller.state.monthRecorded, 0);

    controller.toggleEo(15);
    controller.toggleQuest(854);
    await controller.idle;
    expect(controller.state.completedEoIds, isEmpty);
    expect(controller.state.completedQuestIds, isEmpty);
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

  test('EO 自动同步后仍可由玩家手动取消', () async {
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
    expect(controller.state.completedEoIds, isEmpty);
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

CapturedApiEvent event(String path, Object data) => CapturedApiEvent(
  path: path,
  responseBody: jsonEncode({'api_result': 1, 'api_data': data}),
  source: CaptureSource.manual,
  capturedAt: DateTime.utc(2026, 8, 10, 3),
);
