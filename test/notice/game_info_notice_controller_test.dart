import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/notice/game_info_notice_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/widgets/top_notice.dart';

class TestTopNoticeSettingsStore
    implements LayoutSettingsStore, TopNoticeSettingsStore {
  bool enabled = true;
  int duration = 5;
  String? localeCode;

  @override
  Future<bool> loadTopNoticeEnabled() async => enabled;

  @override
  Future<void> saveTopNoticeEnabled(bool val) async => enabled = val;

  @override
  Future<int> loadTopNoticeDurationSeconds() async => duration;

  @override
  Future<void> saveTopNoticeDurationSeconds(int val) async => duration = val;

  @override
  Future<double> loadGameAreaRatio() async => 0.65;
  @override
  Future<void> saveGameAreaRatio(double ratio) async {}
  @override
  Future<double> loadInformationPanelWidth() async => 390;
  @override
  Future<void> saveInformationPanelWidth(double width) async {}
  @override
  Future<bool> loadAutoZoom() async => true;
  @override
  Future<void> saveAutoZoom(bool autoZoom) async {}
  @override
  Future<bool> loadEnhancedDamagePulse() async => true;
  @override
  Future<void> saveEnhancedDamagePulse(bool enabled) async {}
  @override
  Future<bool> loadWorkspaceMenuOnRight() async => false;
  @override
  Future<void> saveWorkspaceMenuOnRight(bool onRight) async {}
  @override
  Future<List<String>> loadDashboardCardOrder() async => <String>[];
  @override
  Future<void> saveDashboardCardOrder(List<String> order) async {}
  @override
  Future<List<String>> loadDashboardCardCollapsed() async => <String>[];
  @override
  Future<void> saveDashboardCardCollapsed(List<String> collapsedIds) async {}
  @override
  Future<List<String>> loadDashboardCardHidden() async => <String>[];
  @override
  Future<void> saveDashboardCardHidden(List<String> hiddenIds) async {}
  @override
  Future<String?> loadFontFamily() async => null;
  @override
  Future<void> saveFontFamily(String? value) async {}
  @override
  Future<String?> loadLocaleCode() async => localeCode;
  @override
  Future<void> saveLocaleCode(String? value) async => localeCode = value;
}

OwnedShip makeShip({
  int id = 1,
  int masterId = 1,
  int level = 90,
  int currentHp = 30,
  int maxHp = 30,
  int firepower = 50,
  int firepowerMax = 52,
  int torpedo = 80,
  int torpedoMax = 89,
  int antiAir = 50,
  int antiAirMax = 50,
  int armor = 40,
  int armorMax = 40,
  int antiSub = 60,
  int luck = 12,
  int luckMax = 50,
  int extraSlotId = 0,
}) {
  return OwnedShip(
    id: id,
    masterId: masterId,
    level: level,
    currentHp: currentHp,
    maxHp: maxHp,
    firepower: firepower,
    firepowerMax: firepowerMax,
    torpedo: torpedo,
    torpedoMax: torpedoMax,
    antiAir: antiAir,
    antiAirMax: antiAirMax,
    armor: armor,
    armorMax: armorMax,
    antiSub: antiSub,
    luck: luck,
    luckMax: luckMax,
    extraSlotId: extraSlotId,
  );
}

void main() {
  late TestTopNoticeSettingsStore store;
  late LayoutSettingsController layoutController;
  late TopNoticeController topNoticeController;
  late GameState state;

  setUp(() async {
    store = TestTopNoticeSettingsStore();
    layoutController = await LayoutSettingsController.load(store);
    topNoticeController = TopNoticeController();
    state = GameState.empty.copyWith(
      maxShipCount: 100,
      maxEquipmentCount: 500,
      masterSlotItems: {
        42: const MasterSlotItem(id: 42, name: '流星改', type: [1, 2, 8]),
        43: const MasterSlotItem(id: 43, name: '烈风', type: [1, 2, 6]),
      },
      masterShips: {
        154: const MasterShip(id: 154, name: '香取', shipTypeId: 21),
        465: const MasterShip(id: 465, name: '鹿島', shipTypeId: 21),
        1: const MasterShip(id: 1, name: '吹雪', shipTypeId: 2),
      },
      ships: {1: makeShip()},
      fleets: [
        const Fleet(id: 1, name: '第1舰队', shipIds: [1]),
      ],
    );
  });

  CapturedApiEvent createEvent(String path, String responseJson) {
    return CapturedApiEvent(
      path: path,
      responseBody: 'svdata=$responseJson',
      capturedAt: DateTime.now(),
      statusCode: 200,
      source: CaptureSource.xhr,
      sourceOrigin: 'http://example.com',
      captureDocumentId: 'doc1',
      captureDocumentStartedAtEpochMs: 1000,
    );
  }

  test(
    'game notifications preserve a simultaneous quest in either order',
    () async {
      final controller = GameInfoNoticeController(
        stateProvider: () => state,
        layoutSettingsController: layoutController,
        topNoticeController: topNoticeController,
      );
      for (final questFirst in [true, false]) {
        topNoticeController.hide();
        void quest() => topNoticeController.show(
          message: '任务完成',
          tone: TopNoticeTone.quest,
          appendWithin: const Duration(milliseconds: 500),
        );
        if (questFirst) quest();
        controller.accept(
          createEvent(
            '/kcsapi/api_req_kousyou/createitem',
            '{"api_result":1,"api_data":{"api_create_flag":0}}',
          ),
        );
        await controller.idle;
        if (!questFirst) quest();
        expect(
          topNoticeController.notices.map((n) => n.message),
          unorderedEquals(['任务完成', '装备开发失败']),
        );
      }
    },
  );

  for (final sample in <(String, String)>[
    ('/kcsapi/api_req_kousyou/remodel_slot', '{"api_remodel_flag":1}'),
    ('/kcsapi/api_req_kaisou/powerup', '{"api_powerup_flag":0}'),
    ('/kcsapi/api_req_kaisou/marriage', '{"api_id":1,"api_lucky":[15,50]}'),
    ('/kcsapi/api_get_member/mapinfo', '{}'),
    (
      '/kcsapi/api_req_member/get_practice_enemyinfo',
      '{"api_deck":{"api_ships":[{"api_level":99}]}}',
    ),
  ]) {
    test('${sample.$1} preserves simultaneous quest in either order', () async {
      state = state.copyWith(maxShipCount: 1);
      final controller = GameInfoNoticeController(
        stateProvider: () => state,
        layoutSettingsController: layoutController,
        topNoticeController: topNoticeController,
      );
      for (final questFirst in [true, false]) {
        topNoticeController.hide();
        void quest() => topNoticeController.show(
          message: '任务完成',
          tone: TopNoticeTone.quest,
          appendWithin: const Duration(milliseconds: 500),
        );
        if (questFirst) quest();
        controller.accept(
          createEvent(sample.$1, '{"api_result":1,"api_data":${sample.$2}}'),
        );
        await controller.idle;
        if (!questFirst) quest();
        expect(topNoticeController.notices, hasLength(2));
        expect(
          topNoticeController.notices.where(
            (n) => n.tone == TopNoticeTone.quest,
          ),
          hasLength(1),
        );
      }
    });
  }

  group('Requirement 1: Practice base experience formula & edge cases', () {
    for (final delay in [Duration.zero, const Duration(milliseconds: 600)]) {
      test(
        'switching practice opponents replaces only practice after $delay',
        () async {
          final controller = GameInfoNoticeController(
            stateProvider: () => state,
            layoutSettingsController: layoutController,
            topNoticeController: topNoticeController,
          );
          addTearDown(topNoticeController.dispose);
          void opponent(int level) => controller.accept(
            createEvent(
              '/kcsapi/api_req_member/get_practice_enemyinfo',
              '{"api_result":1,"api_data":{"api_deck":{"api_ships":[{"api_level":$level}]}}}',
            ),
          );
          opponent(50);
          await controller.idle;
          topNoticeController.show(
            message: '任务完成',
            tone: TopNoticeTone.quest,
            appendWithin: const Duration(milliseconds: 500),
          );
          await Future<void>.delayed(delay);
          opponent(80);
          opponent(99);
          await controller.idle;
          expect(topNoticeController.notices.map((n) => n.message), [
            '任务完成',
            '演习经验（约）：S胜 716 · A胜 597',
          ]);
        },
      );
    }

    test(
      'empty opponent clears stale practice but preserves other notices',
      () async {
        final controller = GameInfoNoticeController(
          stateProvider: () => state,
          layoutSettingsController: layoutController,
          topNoticeController: topNoticeController,
        );
        addTearDown(topNoticeController.dispose);
        controller.accept(
          createEvent(
            '/kcsapi/api_req_member/get_practice_enemyinfo',
            '{"api_result":1,"api_data":{"api_deck":{"api_ships":[{"api_level":99}]}}}',
          ),
        );
        await controller.idle;
        topNoticeController.show(
          message: '任务完成',
          tone: TopNoticeTone.quest,
          appendWithin: const Duration(milliseconds: 500),
        );
        controller.accept(
          createEvent(
            '/kcsapi/api_req_member/get_practice_enemyinfo',
            '{"api_result":1,"api_data":{"api_deck":{"api_ships":[]}}}',
          ),
        );
        await controller.idle;
        expect(topNoticeController.notices.map((n) => n.message), ['任务完成']);
      },
    );

    test(
      'high-level second ship and out-of-range levels use shared limits',
      () {
        expect(GameInfoNoticeController.calculatePracticeBaseExp(1, 99), 553);
        expect(
          GameInfoNoticeController.calculatePracticeBaseExp(188, 188),
          1018,
        );
        expect(
          GameInfoNoticeController.calculatePracticeBaseExp(999, 999),
          1018,
        );
      },
    );
    test('uses canonical cumulative experience at level boundaries', () {
      for (final sample in <(int, int)>[
        (52, 528),
        (99, 597),
        (100, 597),
        (180, 859),
        (188, 948),
      ]) {
        expect(
          GameInfoNoticeController.calculatePracticeBaseExp(sample.$1, 0),
          sample.$2,
          reason: 'single opponent level ${sample.$1}',
        );
      }
    });
    test(
      'Calculates exact theoretical values with sqrt decay when total > 500',
      () {
        // 383000 / 100 + 181500 / 300 = 4435.
        expect(
          GameInfoNoticeController.calculatePracticeBaseExp(80, 60),
          equals(562),
        );

        // Benchmark 2: L1=50, L2=0 (single ship) -> total=1225 -> 500 + sqrt(725) = 526
        expect(
          GameInfoNoticeController.calculatePracticeBaseExp(50, 0),
          equals(526),
        );

        // 1255000 / 100 + 1255000 / 300 -> 627.
        expect(
          GameInfoNoticeController.calculatePracticeBaseExp(120, 120),
          equals(627),
        );
      },
    );

    test('Calculates small totals without decay when total <= 500', () {
      // L1=10, L2=10 -> total=60
      expect(
        GameInfoNoticeController.calculatePracticeBaseExp(10, 10),
        equals(60),
      );

      // L1=1, L2=1 -> total=0 -> floor limit 10
      expect(
        GameInfoNoticeController.calculatePracticeBaseExp(1, 1),
        equals(10),
      );
    });

    test('Handles 0-ship and abnormal inputs safely', () {
      // Opponent first ship level <= 0 means empty/missing deck
      expect(
        GameInfoNoticeController.calculatePracticeBaseExp(0, 0),
        equals(0),
      );
      expect(
        GameInfoNoticeController.calculatePracticeBaseExp(0, 80),
        equals(0),
      );
      expect(
        GameInfoNoticeController.calculatePracticeBaseExp(-1, 80),
        equals(0),
      );
      expect(
        GameInfoNoticeController.calculatePracticeBaseExp(80, -5),
        equals(557),
      );
    });

    test(
      'Practice API event with single ship opponent computes and displays',
      () async {
        final controller = GameInfoNoticeController(
          stateProvider: () => state,
          layoutSettingsController: layoutController,
          topNoticeController: topNoticeController,
        );

        controller.accept(
          createEvent(
            '/kcsapi/api_req_member/get_practice_enemyinfo',
            '{"api_result":1,"api_data":{"api_deck":{"api_ships":[{"api_level":50}]}}}',
          ),
        );

        await controller.idle;
        expect(topNoticeController.current, isNotNull);
        // baseExp=526, S win=631 (526 * 1.2 round), A win=526
        expect(
          topNoticeController.current!.message,
          equals('演习经验（约）：S胜 631 · A胜 526'),
        );
        expect(topNoticeController.current!.tone, equals(TopNoticeTone.info));
      },
    );

    test(
      'Practice API event with empty ships list is ignored safely',
      () async {
        final controller = GameInfoNoticeController(
          stateProvider: () => state,
          layoutSettingsController: layoutController,
          topNoticeController: topNoticeController,
        );

        controller.accept(
          createEvent(
            '/kcsapi/api_req_member/get_practice_enemyinfo',
            '{"api_result":1,"api_data":{"api_deck":{"api_ships":[]}}}',
          ),
        );

        await controller.idle;
        expect(topNoticeController.current, isNull);
      },
    );
  });

  group('Requirement 2: Training cruiser bonus 4-mode matrix', () {
    GameState makeFleetWithCt({
      required bool flagshipIsCt,
      required int flagshipLevel,
      required int ctCompanionCount,
      required int ctCompanionLevel,
    }) {
      final shipsMap = <int, OwnedShip>{};
      final fleetShipIds = <int>[];

      if (flagshipIsCt) {
        shipsMap[10] = OwnedShip(
          id: 10,
          masterId: 154, // Katori CT
          level: flagshipLevel,
        );
        fleetShipIds.add(10);
      } else {
        shipsMap[10] = OwnedShip(
          id: 10,
          masterId: 1, // Fubuki DD
          level: flagshipLevel,
        );
        fleetShipIds.add(10);
      }

      for (var i = 1; i <= ctCompanionCount; i++) {
        final id = 10 + i;
        shipsMap[id] = OwnedShip(
          id: id,
          masterId: i == 1 ? 465 : 154, // Kashima or Katori
          level: ctCompanionLevel,
        );
        fleetShipIds.add(id);
      }

      return state.copyWith(
        ships: shipsMap,
        fleets: [Fleet(id: 1, name: 'Fleet 1', shipIds: fleetShipIds)],
      );
    }

    test('Mode 1: CT Flagship only', () {
      expect(
        GameInfoNoticeController.calculateFleetTrainingCruiserBonus(
          makeFleetWithCt(
            flagshipIsCt: true,
            flagshipLevel: 5,
            ctCompanionCount: 0,
            ctCompanionLevel: 1,
          ),
        ),
        equals(5.0),
      );
      expect(
        GameInfoNoticeController.calculateFleetTrainingCruiserBonus(
          makeFleetWithCt(
            flagshipIsCt: true,
            flagshipLevel: 25,
            ctCompanionCount: 0,
            ctCompanionLevel: 1,
          ),
        ),
        equals(8.0),
      );
      expect(
        GameInfoNoticeController.calculateFleetTrainingCruiserBonus(
          makeFleetWithCt(
            flagshipIsCt: true,
            flagshipLevel: 45,
            ctCompanionCount: 0,
            ctCompanionLevel: 1,
          ),
        ),
        equals(12.0),
      );
      expect(
        GameInfoNoticeController.calculateFleetTrainingCruiserBonus(
          makeFleetWithCt(
            flagshipIsCt: true,
            flagshipLevel: 75,
            ctCompanionCount: 0,
            ctCompanionLevel: 1,
          ),
        ),
        equals(15.0),
      );
      expect(
        GameInfoNoticeController.calculateFleetTrainingCruiserBonus(
          makeFleetWithCt(
            flagshipIsCt: true,
            flagshipLevel: 120,
            ctCompanionCount: 0,
            ctCompanionLevel: 1,
          ),
        ),
        equals(20.0),
      );
    });

    test('Mode 2: CT Flagship + Companion', () {
      expect(
        GameInfoNoticeController.calculateFleetTrainingCruiserBonus(
          makeFleetWithCt(
            flagshipIsCt: true,
            flagshipLevel: 5,
            ctCompanionCount: 1,
            ctCompanionLevel: 30,
          ),
        ),
        equals(10.0),
      );
      expect(
        GameInfoNoticeController.calculateFleetTrainingCruiserBonus(
          makeFleetWithCt(
            flagshipIsCt: true,
            flagshipLevel: 25,
            ctCompanionCount: 1,
            ctCompanionLevel: 30,
          ),
        ),
        equals(13.0),
      );
      expect(
        GameInfoNoticeController.calculateFleetTrainingCruiserBonus(
          makeFleetWithCt(
            flagshipIsCt: true,
            flagshipLevel: 45,
            ctCompanionCount: 1,
            ctCompanionLevel: 30,
          ),
        ),
        equals(16.0),
      );
      expect(
        GameInfoNoticeController.calculateFleetTrainingCruiserBonus(
          makeFleetWithCt(
            flagshipIsCt: true,
            flagshipLevel: 75,
            ctCompanionCount: 1,
            ctCompanionLevel: 30,
          ),
        ),
        equals(20.0),
      );
      expect(
        GameInfoNoticeController.calculateFleetTrainingCruiserBonus(
          makeFleetWithCt(
            flagshipIsCt: true,
            flagshipLevel: 120,
            ctCompanionCount: 1,
            ctCompanionLevel: 30,
          ),
        ),
        equals(25.0),
      );
    });

    test('Mode 3: Companion 1 only (no CT flagship)', () {
      expect(
        GameInfoNoticeController.calculateFleetTrainingCruiserBonus(
          makeFleetWithCt(
            flagshipIsCt: false,
            flagshipLevel: 50,
            ctCompanionCount: 1,
            ctCompanionLevel: 5,
          ),
        ),
        equals(3.0),
      );
      expect(
        GameInfoNoticeController.calculateFleetTrainingCruiserBonus(
          makeFleetWithCt(
            flagshipIsCt: false,
            flagshipLevel: 50,
            ctCompanionCount: 1,
            ctCompanionLevel: 20,
          ),
        ),
        equals(5.0),
      );
      expect(
        GameInfoNoticeController.calculateFleetTrainingCruiserBonus(
          makeFleetWithCt(
            flagshipIsCt: false,
            flagshipLevel: 50,
            ctCompanionCount: 1,
            ctCompanionLevel: 40,
          ),
        ),
        equals(7.0),
      );
      expect(
        GameInfoNoticeController.calculateFleetTrainingCruiserBonus(
          makeFleetWithCt(
            flagshipIsCt: false,
            flagshipLevel: 50,
            ctCompanionCount: 1,
            ctCompanionLevel: 80,
          ),
        ),
        equals(10.0),
      );
      expect(
        GameInfoNoticeController.calculateFleetTrainingCruiserBonus(
          makeFleetWithCt(
            flagshipIsCt: false,
            flagshipLevel: 50,
            ctCompanionCount: 1,
            ctCompanionLevel: 110,
          ),
        ),
        equals(15.0),
      );
    });

    test('Mode 4: Companion 2 only (no CT flagship)', () {
      expect(
        GameInfoNoticeController.calculateFleetTrainingCruiserBonus(
          makeFleetWithCt(
            flagshipIsCt: false,
            flagshipLevel: 50,
            ctCompanionCount: 2,
            ctCompanionLevel: 5,
          ),
        ),
        equals(4.0),
      );
      expect(
        GameInfoNoticeController.calculateFleetTrainingCruiserBonus(
          makeFleetWithCt(
            flagshipIsCt: false,
            flagshipLevel: 50,
            ctCompanionCount: 2,
            ctCompanionLevel: 20,
          ),
        ),
        equals(6.0),
      );
      expect(
        GameInfoNoticeController.calculateFleetTrainingCruiserBonus(
          makeFleetWithCt(
            flagshipIsCt: false,
            flagshipLevel: 50,
            ctCompanionCount: 2,
            ctCompanionLevel: 40,
          ),
        ),
        equals(8.0),
      );
      expect(
        GameInfoNoticeController.calculateFleetTrainingCruiserBonus(
          makeFleetWithCt(
            flagshipIsCt: false,
            flagshipLevel: 50,
            ctCompanionCount: 2,
            ctCompanionLevel: 80,
          ),
        ),
        equals(12.0),
      );
      expect(
        GameInfoNoticeController.calculateFleetTrainingCruiserBonus(
          makeFleetWithCt(
            flagshipIsCt: false,
            flagshipLevel: 50,
            ctCompanionCount: 2,
            ctCompanionLevel: 110,
          ),
        ),
        equals(17.5),
      );
    });

    test(
      'Practice enemy info event formats decimal training cruiser bonus',
      () async {
        final ctState = makeFleetWithCt(
          flagshipIsCt: false,
          flagshipLevel: 50,
          ctCompanionCount: 2,
          ctCompanionLevel: 110,
        ); // Mode 4 Lv 110 -> 17.5%

        final controller = GameInfoNoticeController(
          stateProvider: () => ctState,
          layoutSettingsController: layoutController,
          topNoticeController: topNoticeController,
        );

        controller.accept(
          createEvent(
            '/kcsapi/api_req_member/get_practice_enemyinfo',
            '{"api_result":1,"api_data":{"api_deck":{"api_ships":[{"api_level":80},{"api_level":60}]}}}',
          ),
        );

        await controller.idle;
        expect(topNoticeController.current, isNotNull);
        // baseExp=562, boostedSExp=792, boostedAExp=660, bonus=17.5%
        expect(
          topNoticeController.current!.message,
          equals('演习经验（约）：S胜 792 · A胜 660 (练巡 +17.5%)'),
        );
        expect(topNoticeController.current!.tone, equals(TopNoticeTone.info));
      },
    );
  });

  group('Requirement 3: Synchronous stateBefore capture (Race condition bug fix)', () {
    test(
      'Captures stateBefore synchronously at accept time so mutations do not zero deltas',
      () async {
        var dynamicState =
            state; // Initial state: firepower=50, firepowerMax=52

        final controller = GameInfoNoticeController(
          stateProvider: () => dynamicState,
          layoutSettingsController: layoutController,
          topNoticeController: topNoticeController,
        );

        // Fire accept()
        controller.accept(
          createEvent(
            '/kcsapi/api_req_kaisou/powerup',
            '{"api_result":1,"api_data":{"api_powerup_flag":1,"api_ship":{"api_id":1,"api_karyoku":[52,52]}}}',
          ),
        );

        // Immediately simulate pipeline reducer updating the game state before async queue runs!
        dynamicState = dynamicState.copyWith(
          ships: {
            1: makeShip(firepower: 52), // New ship stats applied to state!
          },
        );

        await controller.idle;
        // If stateBefore was not captured synchronously, delta would be 52 - 52 = 0!
        // Since it was captured synchronously, delta is 52 - 50 = 2!
        expect(topNoticeController.current, isNotNull);
        expect(topNoticeController.current!.message, contains('火力 ▲ 2 (MAX)'));
      },
    );
  });

  group('Requirement 4 & 8: 7-dimension modernization & safe int parsing', () {
    test(
      'Modernization detects all 7 dimensions including HP and ASW',
      () async {
        final controller = GameInfoNoticeController(
          stateProvider: () => state,
          layoutSettingsController: layoutController,
          topNoticeController: topNoticeController,
        );

        // Old: HP=30, FP=50, Torpedo=80, AA=50, Armor=40, Luck=12, ASW=60
        controller.accept(
          createEvent(
            '/kcsapi/api_req_kaisou/powerup',
            '{"api_result":1,"api_data":{"api_powerup_flag":1,"api_ship":{'
                '"api_id":"1",'
                '"api_karyoku":["51",52],'
                '"api_raisou":[81,89],'
                '"api_taiku":[51,55],'
                '"api_soukou":[41,45],'
                '"api_lucky":[13,50],'
                '"api_maxhp":[31,32],'
                '"api_taisen":[62,80]'
                '}}}',
          ),
        );

        await controller.idle;
        final msg = topNoticeController.current!.message;
        expect(msg, contains('火力 ▲ 1'));
        expect(msg, contains('雷装 ▲ 1'));
        expect(msg, contains('对空 ▲ 1'));
        expect(msg, contains('装甲 ▲ 1'));
        expect(msg, contains('运 ▲ 1'));
        expect(msg, contains('耐久 ▲ 1'));
        expect(msg, contains('对潜 ▲ 2'));
      },
    );

    test('Modernization marks MAX on all stats when reached', () async {
      final controller = GameInfoNoticeController(
        stateProvider: () => state,
        layoutSettingsController: layoutController,
        topNoticeController: topNoticeController,
      );

      controller.accept(
        createEvent(
          '/kcsapi/api_req_kaisou/powerup',
          '{"api_result":1,"api_data":{"api_powerup_flag":1,"api_ship":{'
              '"api_id":1,'
              '"api_karyoku":[52,52],'
              '"api_raisou":[89,89],'
              '"api_taiku":[50,50],'
              '"api_soukou":[40,40],'
              '"api_lucky":[50,50],'
              '"api_maxhp":[32,32],'
              '"api_taisen":[80,80]'
              '}}}',
        ),
      );

      await controller.idle;
      final msg = topNoticeController.current!.message;
      expect(msg, contains('火力 ▲ 2 (MAX)'));
      expect(msg, contains('雷装 ▲ 9 (MAX)'));
      expect(msg, contains('运 ▲ 38 (MAX)'));
      expect(msg, contains('耐久 ▲ 2 (MAX)'));
      expect(msg, contains('对潜 ▲ 20 (MAX)'));
    });

    test(
      'Modernization does not infer all stats max from equipped totals',
      () async {
        final maxedState = state.copyWith(
          ships: {
            1: makeShip(
              firepower: 52,
              torpedo: 89,
              luck: 50,
              maxHp: 32,
              antiSub: 80,
            ),
          },
        );
        final controller = GameInfoNoticeController(
          stateProvider: () => maxedState,
          layoutSettingsController: layoutController,
          topNoticeController: topNoticeController,
        );
        controller.accept(
          createEvent(
            '/kcsapi/api_req_kaisou/powerup',
            '{"api_result":1,"api_data":{"api_powerup_flag":1,"api_ship":{'
                '"api_id":1,"api_karyoku":[52,52],"api_raisou":[89,89],'
                '"api_taiku":[50,50],"api_soukou":[40,40],"api_lucky":[50,50],'
                '"api_maxhp":[32,32],"api_taisen":[80,80]}}}',
          ),
        );
        await controller.idle;
        expect(topNoticeController.current!.message, equals('近代化改修成功'));
      },
    );

    test('Modernization does not infer all stats max from no increase', () async {
      final maxedShip = makeShip(firepower: 52, firepowerMax: 52);
      final maxedState = state.copyWith(ships: {1: maxedShip});

      final controller = GameInfoNoticeController(
        stateProvider: () => maxedState,
        layoutSettingsController: layoutController,
        topNoticeController: topNoticeController,
      );

      controller.accept(
        createEvent(
          '/kcsapi/api_req_kaisou/powerup',
          '{"api_result":1,"api_data":{"api_powerup_flag":1,"api_ship":{"api_id":1,"api_karyoku":[52,52]}}}',
        ),
      );

      await controller.idle;
      expect(topNoticeController.current!.message, equals('近代化改修成功'));
    });

    test(
      'Poi parity: Nisshin Kai with equipment does NOT falsely flag Firepower as MAX',
      () async {
        // Nisshin Kai (Master ID: 690):
        // baseFirepower: 18, maxFirepower: 54 (room: 36)
        // baseArmor: 24, maxArmor: 46 (room: 22)
        // baseTorpedo: 0, maxTorpedo: 75 (room: 75)
        // baseAntiAir: 22, maxAntiAir: 62 (room: 40)
        const nisshinMaster = MasterShip(
          id: 690,
          name: '日進改',
          shipTypeId: 11,
          baseFirepower: 18,
          maxFirepower: 54,
          baseArmor: 24,
          maxArmor: 46,
          baseTorpedo: 0,
          maxTorpedo: 75,
          baseAntiAir: 22,
          maxAntiAir: 62,
        );

        // Before modernization:
        // Equipped firepower is 54 (naked 48 + 6 equip bonus). kyouka=[30, 0, 14, 21, 0, 0, 0]
        final oldNisshin = OwnedShip(
          id: 42,
          masterId: 690,
          level: 40,
          firepower: 54,
          firepowerMax: 54,
          torpedo: 0,
          torpedoMax: 75,
          antiAir: 36,
          antiAirMax: 62,
          armor: 45,
          armorMax: 46,
          modernization: const [30, 0, 14, 21, 0, 0, 0],
        );

        final testState = state.copyWith(
          masterShips: {...state.masterShips, 690: nisshinMaster},
          ships: {42: oldNisshin},
        );

        final controller = GameInfoNoticeController(
          stateProvider: () => testState,
          layoutSettingsController: layoutController,
          topNoticeController: topNoticeController,
        );

        // Modernization response:
        // Firepower kyouka: 30 -> 33 (+3). Naked is 18 + 33 = 51 < 54. Equipped is 51 + 6 = 57.
        // AntiAir kyouka: 14 -> 15 (+1). Naked is 22 + 15 = 37 < 62.
        // Armor kyouka: 21 -> 22 (+1). Naked is 24 + 22 = 46 == 46 (MAX!).
        controller.accept(
          createEvent(
            '/kcsapi/api_req_kaisou/powerup',
            '{"api_result":1,"api_data":{"api_powerup_flag":1,"api_ship":{'
                '"api_id":42,'
                '"api_ship_id":690,'
                '"api_karyoku":[57,54],'
                '"api_raisou":[0,75],'
                '"api_taiku":[37,62],'
                '"api_soukou":[46,46],'
                '"api_lucky":[10,58],'
                '"api_kyouka":[33,0,15,22,0,0,0]'
                '}}}',
          ),
        );

        await controller.idle;
        final msg = topNoticeController.current!.message;
        // Exactly matches the game:
        // Firepower increased by 3 (NOT max, because 51 < 54).
        // AntiAir increased by 1 (NOT max).
        // Armor increased by 1 (MAX, because 46 == 46).
        expect(msg, contains('火力 ▲ 3'));
        expect(msg, isNot(contains('火力 ▲ 3 (MAX)')));
        expect(msg, contains('对空 ▲ 1'));
        expect(msg, isNot(contains('对空 ▲ 1 (MAX)')));
        expect(msg, contains('装甲 ▲ 1 (MAX)'));
      },
    );

    test(
      'Poi mathematical parity test across multiple stats and boundary conditions',
      () {
        // Test parity against Poi's formula: remaining = max - (base + kyouka)
        const master = MasterShip(
          id: 100,
          name: 'TestShip',
          shipTypeId: 2,
          baseFirepower: 20,
          maxFirepower: 60,
          baseTorpedo: 30,
          maxTorpedo: 80,
          baseAntiAir: 15,
          maxAntiAir: 50,
          baseArmor: 10,
          maxArmor: 40,
          baseLuck: 12,
          maxLuck: 50,
        );

        int poiRemaining(int base, int max, int kyouka) =>
            max - (base + kyouka);
        bool poiIsMax(int base, int max, int kyouka) =>
            poiRemaining(base, max, kyouka) <= 0;

        // Check values for all stats
        final testCases = [
          (0, 20, 60, 39, false), // 20+39=59, rem=1
          (0, 20, 60, 40, true), // 20+40=60, rem=0 (MAX)
          (0, 20, 60, 41, true), // 20+41=61, rem=-1 (MAX)
          (1, 30, 80, 49, false),
          (1, 30, 80, 50, true),
          (2, 15, 50, 34, false),
          (2, 15, 50, 35, true),
          (3, 10, 40, 29, false),
          (3, 10, 40, 30, true),
          (4, 12, 50, 37, false),
          (4, 12, 50, 38, true),
        ];

        for (final (statIndex, base, maxVal, kyouka, expectedMax)
            in testCases) {
          final poiRem = poiRemaining(base, maxVal, kyouka);
          final yahagiRem = master.remainingModernization(statIndex, kyouka);
          expect(
            yahagiRem,
            equals(poiRem),
            reason: 'Remaining must exactly match Poi',
          );
          expect(yahagiRem! <= 0, equals(expectedMax));
          expect(poiIsMax(base, maxVal, kyouka), equals(expectedMax));
        }
      },
    );
  });

  group('Requirement 5: Marriage luck bonus critical & MAX logic', () {
    test(
      '+6 / MAX: critical double arrow and MAX when luck reaches cap',
      () async {
        final ship = makeShip(luck: 44, luckMax: 50);
        final marriageState = state.copyWith(ships: {1: ship});

        final controller = GameInfoNoticeController(
          stateProvider: () => marriageState,
          layoutSettingsController: layoutController,
          topNoticeController: topNoticeController,
        );

        controller.accept(
          createEvent(
            '/kcsapi/api_req_kaisou/marriage',
            '{"api_result":1,"api_data":{"api_id":1,"api_lucky":[50,50]}}',
          ),
        );

        await controller.idle;
        expect(
          topNoticeController.current!.message,
          equals('誓约运提升：运 ▲▲ +6 / MAX'),
        );
        expect(
          topNoticeController.current!.tone,
          equals(TopNoticeTone.marriage),
        );
      },
    );

    test(
      '+5 / +12: critical double arrow when delta > 4 but remaining > 0',
      () async {
        final ship = makeShip(luck: 33, luckMax: 50);
        final marriageState = state.copyWith(ships: {1: ship});

        final controller = GameInfoNoticeController(
          stateProvider: () => marriageState,
          layoutSettingsController: layoutController,
          topNoticeController: topNoticeController,
        );

        controller.accept(
          createEvent(
            '/kcsapi/api_req_kaisou/marriage',
            '{"api_result":1,"api_data":{"api_id":1,"api_lucky":[38,50]}}',
          ),
        );

        await controller.idle;
        expect(
          topNoticeController.current!.message,
          equals('誓约运提升：运 ▲▲ +5 / +12'),
        );
        expect(
          topNoticeController.current!.tone,
          equals(TopNoticeTone.marriage),
        );
      },
    );

    test(
      '+3 / +35: normal single arrow when delta <= 4 and remaining > 0',
      () async {
        final ship = makeShip(luck: 12, luckMax: 50);
        final marriageState = state.copyWith(ships: {1: ship});

        final controller = GameInfoNoticeController(
          stateProvider: () => marriageState,
          layoutSettingsController: layoutController,
          topNoticeController: topNoticeController,
        );

        controller.accept(
          createEvent(
            '/kcsapi/api_req_kaisou/marriage',
            '{"api_result":1,"api_data":{"api_id":1,"api_lucky":[15,50]}}',
          ),
        );

        await controller.idle;
        expect(
          topNoticeController.current!.message,
          equals('誓约运提升：运 ▲ +3 / +35'),
        );
        expect(
          topNoticeController.current!.tone,
          equals(TopNoticeTone.marriage),
        );
      },
    );
  });

  group('Requirement 6: Sortie safety checks & composite warnings', () {
    test('Both ship and item full triggers composite error notice', () async {
      final fullState = state.copyWith(
        maxShipCount: 1,
        ships: {1: state.ships[1]!},
        maxEquipmentCount: 2,
        slotItems: {
          1: const OwnedSlotItem(instanceId: 1, masterSlotItemId: 10),
          2: const OwnedSlotItem(instanceId: 2, masterSlotItemId: 10),
        },
      );

      final controller = GameInfoNoticeController(
        stateProvider: () => fullState,
        layoutSettingsController: layoutController,
        topNoticeController: topNoticeController,
      );

      controller.accept(
        createEvent(
          '/kcsapi/api_get_member/mapinfo',
          '{"api_result":1,"api_data":{"api_map_info":[]}}',
        ),
      );

      await controller.idle;
      expect(
        topNoticeController.current!.message,
        equals('母港船位与装备槽已满！出击将无法获得新舰娘与装备'),
      );
      expect(topNoticeController.current!.tone, equals(TopNoticeTone.error));
    });

    test(
      'Ship capacity low and item capacity full gives Error priority',
      () async {
        final stateWithItemFull = state.copyWith(
          maxShipCount: 5,
          ships: {
            1: state.ships[1]!,
            2: state.ships[1]!,
          }, // 3 ships left (low warning)
          maxEquipmentCount: 2,
          slotItems: {
            1: const OwnedSlotItem(instanceId: 1, masterSlotItemId: 10),
            2: const OwnedSlotItem(instanceId: 2, masterSlotItemId: 10),
          }, // 2 items / 2 capacity = 0 left (error!)
        );

        final controller = GameInfoNoticeController(
          stateProvider: () => stateWithItemFull,
          layoutSettingsController: layoutController,
          topNoticeController: topNoticeController,
        );

        controller.accept(
          createEvent(
            '/kcsapi/api_get_member/mapinfo',
            '{"api_result":1,"api_data":{"api_map_info":[]}}',
          ),
        );

        await controller.idle;
        expect(
          topNoticeController.current!.message,
          equals('装备槽已满！出击将无法获得新装备'),
        );
        expect(topNoticeController.current!.tone, equals(TopNoticeTone.error));
      },
    );

    test(
      'Both ship and item capacity low triggers composite warning',
      () async {
        final stateWithBothLow = state.copyWith(
          maxShipCount: 5,
          ships: {
            1: state.ships[1]!,
            2: state.ships[1]!,
            3: state.ships[1]!,
          }, // 2 left
          maxEquipmentCount: 5,
          slotItems: {
            1: const OwnedSlotItem(instanceId: 1, masterSlotItemId: 10),
            2: const OwnedSlotItem(instanceId: 2, masterSlotItemId: 10),
          }, // 3 left
        );

        final controller = GameInfoNoticeController(
          stateProvider: () => stateWithBothLow,
          layoutSettingsController: layoutController,
          topNoticeController: topNoticeController,
        );

        controller.accept(
          createEvent(
            '/kcsapi/api_get_member/mapinfo',
            '{"api_result":1,"api_data":{"api_map_info":[]}}',
          ),
        );

        await controller.idle;
        expect(
          topNoticeController.current!.message,
          equals('船位仅剩 2 个 · 装备槽仅剩 3 个，请注意母港容量'),
        );
        expect(
          topNoticeController.current!.tone,
          equals(TopNoticeTone.warning),
        );
      },
    );

    test('Ship capacity low triggers warning notice', () async {
      final stateWithShipLow = state.copyWith(
        maxShipCount: 5,
        ships: {
          1: state.ships[1]!,
          2: state.ships[1]!,
          3: state.ships[1]!,
        }, // 2 left (<= 5)
        maxEquipmentCount: 20,
        slotItems: {
          1: const OwnedSlotItem(instanceId: 1, masterSlotItemId: 10),
        }, // 19 left (> 5)
      );

      final controller = GameInfoNoticeController(
        stateProvider: () => stateWithShipLow,
        layoutSettingsController: layoutController,
        topNoticeController: topNoticeController,
      );

      controller.accept(
        createEvent(
          '/kcsapi/api_get_member/mapinfo',
          '{"api_result":1,"api_data":{"api_map_info":[]}}',
        ),
      );

      await controller.idle;
      expect(topNoticeController.current!.message, equals('船位仅剩 2 个，请注意母港容量'));
      expect(topNoticeController.current!.tone, equals(TopNoticeTone.warning));
    });

    test('Item capacity low triggers warning notice', () async {
      final stateWithItemLow = state.copyWith(
        maxShipCount: 20,
        ships: {1: state.ships[1]!}, // 19 left (> 5)
        maxEquipmentCount: 5,
        slotItems: {
          1: const OwnedSlotItem(instanceId: 1, masterSlotItemId: 10),
          2: const OwnedSlotItem(instanceId: 2, masterSlotItemId: 10),
          3: const OwnedSlotItem(instanceId: 3, masterSlotItemId: 10),
        }, // 2 left (<= 5)
      );

      final controller = GameInfoNoticeController(
        stateProvider: () => stateWithItemLow,
        layoutSettingsController: layoutController,
        topNoticeController: topNoticeController,
      );

      controller.accept(
        createEvent(
          '/kcsapi/api_get_member/mapinfo',
          '{"api_result":1,"api_data":{"api_map_info":[]}}',
        ),
      );

      await controller.idle;
      expect(topNoticeController.current!.message, equals('装备槽仅剩 2 个，请注意母港容量'));
      expect(topNoticeController.current!.tone, equals(TopNoticeTone.warning));
    });

    test('Sufficient capacity triggers no notice', () async {
      final sufficientState = state.copyWith(
        maxShipCount: 100,
        ships: {1: state.ships[1]!},
        maxEquipmentCount: 100,
        slotItems: {
          1: const OwnedSlotItem(instanceId: 1, masterSlotItemId: 10),
        },
      );

      final controller = GameInfoNoticeController(
        stateProvider: () => sufficientState,
        layoutSettingsController: layoutController,
        topNoticeController: topNoticeController,
      );

      controller.accept(
        createEvent(
          '/kcsapi/api_get_member/mapinfo',
          '{"api_result":1,"api_data":{"api_map_info":[]}}',
        ),
      );

      await controller.idle;
      expect(topNoticeController.current, isNull);
    });

    test(
      'Uncounted equipment (damage control, combat rations) does not reduce remaining equipment capacity',
      () async {
        // 2191 capacity, 2126 countable items + 64 uncounted damage control items = 2190 total items
        // equipmentCapacityUsed should be 2126, remaining should be 2191 - 2126 = 65 (> 5, no warning)
        final stateWithUncounted = state.copyWith(
          maxShipCount: 100,
          ships: {1: state.ships[1]!},
          maxEquipmentCount: 2191,
          slotItems: {
            // 2 countable items (ID 10)
            1: const OwnedSlotItem(instanceId: 1, masterSlotItemId: 10),
            2: const OwnedSlotItem(instanceId: 2, masterSlotItemId: 10),
            // 10 uncounted damage control items (ID 42 / 43 / 145)
            for (int i = 3; i <= 12; i++)
              i: OwnedSlotItem(
                instanceId: i,
                masterSlotItemId: i.isEven ? 42 : 43,
              ),
          },
        );

        // equipmentCapacityUsed should be 2, not 12
        expect(stateWithUncounted.equipmentCapacityUsed, equals(2));
        expect(stateWithUncounted.slotItems.length, equals(12));

        final controller = GameInfoNoticeController(
          stateProvider: () => stateWithUncounted,
          layoutSettingsController: layoutController,
          topNoticeController: topNoticeController,
        );

        controller.accept(
          createEvent(
            '/kcsapi/api_get_member/mapinfo',
            '{"api_result":1,"api_data":{"api_map_info":[]}}',
          ),
        );

        await controller.idle;
        // 2191 - 2 = 2189 remaining, so NO warning should be posted!
        expect(topNoticeController.current, isNull);
      },
    );
  });

  group('Requirement 7: Multi-language i18n support', () {
    test('Notices are localized into Japanese when localeCode is ja', () async {
      await layoutController.setLocaleCode('ja');

      final controller = GameInfoNoticeController(
        stateProvider: () => state,
        layoutSettingsController: layoutController,
        topNoticeController: topNoticeController,
      );

      controller.accept(
        createEvent(
          '/kcsapi/api_req_kousyou/createitem',
          '{"api_result":1,"api_data":{"api_create_flag":1,"api_slot_item":{"api_id":1,"api_slotitem_id":42}}}',
        ),
      );

      await controller.idle;
      expect(topNoticeController.current!.message, contains('流星改 の開発に成功しました'));
    });

    test(
      'Notices are localized into Traditional Chinese when localeCode is zh_Hant',
      () async {
        await layoutController.setLocaleCode('zh_Hant');

        final controller = GameInfoNoticeController(
          stateProvider: () => state,
          layoutSettingsController: layoutController,
          topNoticeController: topNoticeController,
        );

        controller.accept(
          createEvent(
            '/kcsapi/api_req_kousyou/createitem',
            '{"api_result":1,"api_data":{"api_create_flag":1,"api_slot_item":{"api_id":1,"api_slotitem_id":42}}}',
          ),
        );

        await controller.idle;
        expect(topNoticeController.current!.message, contains('流星改 開發成功'));
      },
    );
  });

  group('Equipment development & Settings toggle', () {
    test('3-batch development formats slot-by-slot with slash', () async {
      final controller = GameInfoNoticeController(
        stateProvider: () => state,
        layoutSettingsController: layoutController,
        topNoticeController: topNoticeController,
      );

      controller.accept(
        createEvent(
          '/kcsapi/api_req_kousyou/createitem',
          '{"api_result":1,"api_data":{"api_create_flag":1,"api_get_items":['
              '{"api_id":1,"api_slotitem_id":42},'
              '{"api_id":2,"api_slotitem_id":43},'
              '{"api_id":-1,"api_slotitem_id":-1}'
              ']}}',
        ),
      );

      await controller.idle;
      expect(topNoticeController.current, isNotNull);
      expect(topNoticeController.current!.message, equals('流星改 / 烈风 / 开发失败'));
      expect(topNoticeController.current!.tone, equals(TopNoticeTone.success));
    });

    test(
      '3-batch real response keeps later successes after the first failure',
      () async {
        final controller = GameInfoNoticeController(
          stateProvider: () => state,
          layoutSettingsController: layoutController,
          topNoticeController: topNoticeController,
        );

        controller.accept(
          createEvent(
            '/kcsapi/api_req_kousyou/createitem',
            '{"api_result":1,"api_data":{"api_create_flag":1,"api_get_items":['
                '{"api_id":-1,"api_slotitem_id":-1},'
                '{"api_id":2,"api_slotitem_id":42},'
                '{"api_id":3,"api_slotitem_id":43}'
                ']}}',
          ),
        );

        await controller.idle;
        expect(topNoticeController.current, isNotNull);
        expect(topNoticeController.current!.message, equals('开发失败 / 流星改 / 烈风'));
        expect(
          topNoticeController.current!.tone,
          equals(TopNoticeTone.success),
        );
      },
    );

    test('3-batch all failed reports penguin', () async {
      final controller = GameInfoNoticeController(
        stateProvider: () => state,
        layoutSettingsController: layoutController,
        topNoticeController: topNoticeController,
      );

      controller.accept(
        createEvent(
          '/kcsapi/api_req_kousyou/createitem',
          '{"api_result":1,"api_data":{"api_create_flag":0,"api_get_items":['
              '{"api_id":-1,"api_slotitem_id":-1},'
              '{"api_id":-1,"api_slotitem_id":-1},'
              '{"api_id":-1,"api_slotitem_id":-1}'
              ']}}',
        ),
      );

      await controller.idle;
      expect(topNoticeController.current, isNotNull);
      expect(topNoticeController.current!.message, equals('装备开发失败'));
      expect(topNoticeController.current!.tone, equals(TopNoticeTone.warning));
    });

    test('Does not post notices when disabled in settings', () async {
      await layoutController.setTopNoticeEnabled(false);
      final controller = GameInfoNoticeController(
        stateProvider: () => state,
        layoutSettingsController: layoutController,
        topNoticeController: topNoticeController,
      );

      controller.accept(
        createEvent(
          '/kcsapi/api_req_kousyou/createitem',
          '{"api_result":1,"api_data":{"api_create_flag":1,"api_slot_item":{"api_id":1,"api_slotitem_id":42}}}',
        ),
      );

      await controller.idle;
      expect(topNoticeController.current, isNull);
    });
  });

  group('Equipment improvement notices', () {
    test(
      'successful equipment improvement posts its own success notice',
      () async {
        final controller = GameInfoNoticeController(
          stateProvider: () => state,
          layoutSettingsController: layoutController,
          topNoticeController: topNoticeController,
        );

        expect(
          controller.supportsPath('/kcsapi/api_req_kousyou/remodel_slot'),
          isTrue,
        );
        controller.accept(
          createEvent(
            '/kcsapi/api_req_kousyou/remodel_slot',
            '{"api_result":1,"api_data":{"api_remodel_flag":1}}',
          ),
        );

        await controller.idle;
        expect(topNoticeController.current?.message, '装备改修成功');
        expect(topNoticeController.current?.tone, TopNoticeTone.success);
      },
    );

    test('failed equipment improvement posts its own failure notice', () async {
      final controller = GameInfoNoticeController(
        stateProvider: () => state,
        layoutSettingsController: layoutController,
        topNoticeController: topNoticeController,
      );

      controller.accept(
        createEvent(
          '/kcsapi/api_req_kousyou/remodel_slot',
          '{"api_result":1,"api_data":{"api_remodel_flag":0}}',
        ),
      );

      await controller.idle;
      expect(topNoticeController.current?.message, '装备改修失败');
      expect(topNoticeController.current?.tone, TopNoticeTone.warning);
    });
  });

  group('Devil Review: Second Round Adversarial & Edge Case Verification', () {
    test(
      'Scenario A: Stat already maxed prior to modernization (delta 0) is omitted from notice',
      () async {
        const master = MasterShip(
          id: 1,
          name: '吹雪',
          shipTypeId: 2,
          baseFirepower: 12,
          maxFirepower: 52,
          baseTorpedo: 20,
          maxTorpedo: 89,
        );

        // Ship already reached MAX firepower before this modernization:
        // kyouka[0] is 40 (12 + 40 = 52 == maxFirepower).
        // Torpedo is not maxed: kyouka[1] is 0.
        final oldShip = OwnedShip(
          id: 1,
          masterId: 1,
          level: 80,
          firepower: 52,
          firepowerMax: 52,
          torpedo: 20,
          torpedoMax: 89,
          modernization: const [40, 0, 0, 0, 0, 0, 0],
        );

        final testState = state.copyWith(
          masterShips: {1: master},
          ships: {1: oldShip},
        );

        final controller = GameInfoNoticeController(
          stateProvider: () => testState,
          layoutSettingsController: layoutController,
          topNoticeController: topNoticeController,
        );

        // Modernization response:
        // Firepower remains 52 (kyouka[0] still 40, delta = 0).
        // Torpedo increases from 20 to 25 (kyouka[1] becomes 5, delta = 5).
        controller.accept(
          createEvent(
            '/kcsapi/api_req_kaisou/powerup',
            '{"api_result":1,"api_data":{"api_powerup_flag":1,"api_ship":{'
                '"api_id":1,'
                '"api_ship_id":1,'
                '"api_karyoku":[52,52],'
                '"api_raisou":[25,89],'
                '"api_kyouka":[40,5,0,0,0,0,0]'
                '}}}',
          ),
        );

        await controller.idle;
        final msg = topNoticeController.current!.message;
        // Must ONLY show Torpedo delta:
        expect(msg, equals('改修成功：雷装 ▲ 5'));
        // Must NOT contain Firepower or MAX:
        expect(msg, isNot(contains('火力')));
        expect(msg, isNot(contains('MAX')));
        expect(
          topNoticeController.current!.tone,
          equals(TopNoticeTone.success),
        );
      },
    );

    test(
      'Scenario B: All stats already maxed when modernized again (all deltas 0) reports max cap notice',
      () async {
        const master = MasterShip(
          id: 1,
          name: '吹雪',
          shipTypeId: 2,
          baseFirepower: 12,
          maxFirepower: 52,
          baseTorpedo: 20,
          maxTorpedo: 89,
          baseAntiAir: 10,
          maxAntiAir: 50,
          baseArmor: 10,
          maxArmor: 40,
          baseLuck: 12,
          maxLuck: 50,
        );

        // Ship has all 7 stats maxed:
        final oldShip = OwnedShip(
          id: 1,
          masterId: 1,
          level: 99,
          firepower: 52,
          firepowerMax: 52,
          torpedo: 89,
          torpedoMax: 89,
          antiAir: 50,
          antiAirMax: 50,
          armor: 40,
          armorMax: 40,
          luck: 50,
          luckMax: 50,
          maxHp: 32,
          antiSub: 80,
          modernization: const [40, 69, 40, 30, 38, 2, 9],
        );

        final testState = state.copyWith(
          masterShips: {1: master},
          ships: {1: oldShip},
        );

        final controller = GameInfoNoticeController(
          stateProvider: () => testState,
          layoutSettingsController: layoutController,
          topNoticeController: topNoticeController,
        );

        // Modernization response with all stats still at max (deltas are all 0):
        controller.accept(
          createEvent(
            '/kcsapi/api_req_kaisou/powerup',
            '{"api_result":1,"api_data":{"api_powerup_flag":1,"api_ship":{'
                '"api_id":1,'
                '"api_ship_id":1,'
                '"api_karyoku":[52,52],'
                '"api_raisou":[89,89],'
                '"api_taiku":[50,50],'
                '"api_soukou":[40,40],'
                '"api_lucky":[50,50],'
                '"api_maxhp":[32,32],'
                '"api_taisen":[80,80],'
                '"api_kyouka":[40,69,40,30,38,2,9]'
                '}}}',
          ),
        );

        await controller.idle;
        expect(topNoticeController.current!.message, equals('改修成功 (属性已达上限)'));
        expect(
          topNoticeController.current!.tone,
          equals(TopNoticeTone.success),
        );
      },
    );

    test(
      'Scenario C: Multi-language parity (zh, zh_Hant, ja) across all notice types',
      () async {
        // 1. Japanese (ja)
        await layoutController.setLocaleCode('ja');
        final jaController = GameInfoNoticeController(
          stateProvider: () => state,
          layoutSettingsController: layoutController,
          topNoticeController: topNoticeController,
        );

        // Modernization detail in ja
        jaController.accept(
          createEvent(
            '/kcsapi/api_req_kaisou/powerup',
            '{"api_result":1,"api_data":{"api_powerup_flag":1,"api_ship":{"api_id":1,"api_karyoku":[52,52]}}}',
          ),
        );
        await jaController.idle;
        expect(
          topNoticeController.current!.message,
          equals('近代化改修成功：火力 ▲ 2 (MAX)'),
        );

        // Modernization max cap in ja
        final maxedShip = makeShip(firepower: 52, firepowerMax: 52);
        final jaMaxState = state.copyWith(ships: {1: maxedShip});
        final jaMaxController = GameInfoNoticeController(
          stateProvider: () => jaMaxState,
          layoutSettingsController: layoutController,
          topNoticeController: topNoticeController,
        );
        jaMaxController.accept(
          createEvent(
            '/kcsapi/api_req_kaisou/powerup',
            '{"api_result":1,"api_data":{"api_powerup_flag":1,"api_ship":{"api_id":1,"api_karyoku":[52,52]}}}',
          ),
        );
        await jaMaxController.idle;
        expect(topNoticeController.current!.message, equals('近代化改修に成功しました'));

        // Modernization fail in ja
        jaController.accept(
          createEvent(
            '/kcsapi/api_req_kaisou/powerup',
            '{"api_result":1,"api_data":{"api_powerup_flag":0}}',
          ),
        );
        await jaController.idle;
        expect(topNoticeController.current!.message, equals('近代化改修に失敗しました'));

        // Marriage luck normal & max in ja
        jaController.accept(
          createEvent(
            '/kcsapi/api_req_kaisou/marriage',
            '{"api_result":1,"api_data":{"api_id":1,"api_lucky":[15,50]}}',
          ),
        );
        await jaController.idle;
        expect(
          topNoticeController.current!.message,
          equals('ケッコンカッコカリ：運 ▲ +3 / +35'),
        );

        jaController.accept(
          createEvent(
            '/kcsapi/api_req_kaisou/marriage',
            '{"api_result":1,"api_data":{"api_id":1,"api_lucky":[50,50]}}',
          ),
        );
        await jaController.idle;
        expect(
          topNoticeController.current!.message,
          equals('ケッコンカッコカリ：運 ▲▲ +38 / MAX'),
        );

        // Sortie check in ja
        final jaSortieState = state.copyWith(
          maxShipCount: 1,
          ships: {1: state.ships[1]!},
          maxEquipmentCount: 2,
          slotItems: {
            1: const OwnedSlotItem(instanceId: 1, masterSlotItemId: 10),
            2: const OwnedSlotItem(instanceId: 2, masterSlotItemId: 10),
          },
        );
        final jaSortieController = GameInfoNoticeController(
          stateProvider: () => jaSortieState,
          layoutSettingsController: layoutController,
          topNoticeController: topNoticeController,
        );
        jaSortieController.accept(
          createEvent(
            '/kcsapi/api_get_member/mapinfo',
            '{"api_result":1,"api_data":{"api_map_info":[]}}',
          ),
        );
        await jaSortieController.idle;
        expect(
          topNoticeController.current!.message,
          equals('艦船・装備保有数が上限に達しています！出撃しても新しい艦娘と装備を入手できません'),
        );

        // Practice exp in ja
        jaController.accept(
          createEvent(
            '/kcsapi/api_req_member/get_practice_enemyinfo',
            '{"api_result":1,"api_data":{"api_deck":{"api_ships":[{"api_level":50}]}}}',
          ),
        );
        await jaController.idle;
        expect(
          topNoticeController.current!.message,
          equals('演習経験値（約）：S勝利 631 · A勝利 526'),
        );

        // 2. Traditional Chinese (zh_Hant)
        await layoutController.setLocaleCode('zh_Hant');
        final zhHantController = GameInfoNoticeController(
          stateProvider: () => state,
          layoutSettingsController: layoutController,
          topNoticeController: topNoticeController,
        );

        // Modernization detail in zh_Hant
        zhHantController.accept(
          createEvent(
            '/kcsapi/api_req_kaisou/powerup',
            '{"api_result":1,"api_data":{"api_powerup_flag":1,"api_ship":{"api_id":1,"api_karyoku":[52,52]}}}',
          ),
        );
        await zhHantController.idle;
        expect(
          topNoticeController.current!.message,
          equals('改修成功：火力 ▲ 2 (MAX)'),
        );

        // Modernization max cap in zh_Hant
        final zhHantMaxController = GameInfoNoticeController(
          stateProvider: () => jaMaxState,
          layoutSettingsController: layoutController,
          topNoticeController: topNoticeController,
        );
        zhHantMaxController.accept(
          createEvent(
            '/kcsapi/api_req_kaisou/powerup',
            '{"api_result":1,"api_data":{"api_powerup_flag":1,"api_ship":{"api_id":1,"api_karyoku":[52,52]}}}',
          ),
        );
        await zhHantMaxController.idle;
        expect(topNoticeController.current!.message, equals('近代化改修成功'));

        // Marriage in zh_Hant
        zhHantController.accept(
          createEvent(
            '/kcsapi/api_req_kaisou/marriage',
            '{"api_result":1,"api_data":{"api_id":1,"api_lucky":[15,50]}}',
          ),
        );
        await zhHantController.idle;
        expect(
          topNoticeController.current!.message,
          equals('誓約運提升：運 ▲ +3 / +35'),
        );

        // Practice exp in zh_Hant
        zhHantController.accept(
          createEvent(
            '/kcsapi/api_req_member/get_practice_enemyinfo',
            '{"api_result":1,"api_data":{"api_deck":{"api_ships":[{"api_level":50}]}}}',
          ),
        );
        await zhHantController.idle;
        expect(
          topNoticeController.current!.message,
          equals('演習經驗（約）：S勝 631 · A勝 526'),
        );

        // Sortie check in zh_Hant
        final zhHantSortieController = GameInfoNoticeController(
          stateProvider: () => jaSortieState,
          layoutSettingsController: layoutController,
          topNoticeController: topNoticeController,
        );
        zhHantSortieController.accept(
          createEvent(
            '/kcsapi/api_get_member/mapinfo',
            '{"api_result":1,"api_data":{"api_map_info":[]}}',
          ),
        );
        await zhHantSortieController.idle;
        expect(
          topNoticeController.current!.message,
          equals('母港船位與裝備槽已滿！出擊將無法獲得新艦娘與裝備'),
        );
      },
    );

    test(
      'Scenario D: Extreme inputs for Luck (Maruyu overflow), HP, and ASW',
      () async {
        // 1. Maruyu Luck Overflow:
        // Base luck: 12, Max luck: 50.
        // Ship was at 48 luck (kyouka[4] = 36).
        // Player feeds 5 Maruyu (+8 luck): kyouka[4] becomes 44 (12 + 44 = 56 > 50).
        const master = MasterShip(
          id: 1,
          name: '吹雪',
          shipTypeId: 2,
          baseLuck: 12,
          maxLuck: 50,
        );

        final shipWithLuck = OwnedShip(
          id: 1,
          masterId: 1,
          level: 90,
          luck: 48,
          luckMax: 50,
          modernization: const [0, 0, 0, 0, 36, 0, 0],
        );

        final luckState = state.copyWith(
          masterShips: {1: master},
          ships: {1: shipWithLuck},
        );

        final luckController = GameInfoNoticeController(
          stateProvider: () => luckState,
          layoutSettingsController: layoutController,
          topNoticeController: topNoticeController,
        );

        luckController.accept(
          createEvent(
            '/kcsapi/api_req_kaisou/powerup',
            '{"api_result":1,"api_data":{"api_powerup_flag":1,"api_ship":{'
                '"api_id":1,'
                '"api_ship_id":1,'
                '"api_lucky":[50,50],'
                '"api_kyouka":[0,0,0,0,44,0,0]'
                '}}}',
          ),
        );

        await luckController.idle;
        // Delta: 44 - 36 = 8. Max luck reached (remaining <= 0).
        expect(
          topNoticeController.current!.message,
          equals('改修成功：运 ▲ 8 (MAX)'),
        );

        // 2. HP Modernization Overflow (e.g. kyouka[5] reaches 3):
        final shipWithHp = OwnedShip(
          id: 1,
          masterId: 1,
          level: 90,
          maxHp: 31,
          modernization: const [0, 0, 0, 0, 0, 1, 0],
        );
        final hpState = state.copyWith(
          masterShips: {1: master},
          ships: {1: shipWithHp},
        );
        final hpController = GameInfoNoticeController(
          stateProvider: () => hpState,
          layoutSettingsController: layoutController,
          topNoticeController: topNoticeController,
        );

        hpController.accept(
          createEvent(
            '/kcsapi/api_req_kaisou/powerup',
            '{"api_result":1,"api_data":{"api_powerup_flag":1,"api_ship":{'
                '"api_id":1,'
                '"api_ship_id":1,'
                '"api_maxhp":33,'
                '"api_kyouka":[0,0,0,0,0,3,0]'
                '}}}',
          ),
        );

        await hpController.idle;
        // Delta: 3 - 1 = 2. Max HP reached (remaining = 2 - 3 = -1 <= 0).
        expect(
          topNoticeController.current!.message,
          equals('改修成功：耐久 ▲ 2 (MAX)'),
        );

        // 3. ASW Modernization: Overflow past 9 (e.g. 10):
        final shipWithAsw = OwnedShip(
          id: 1,
          masterId: 1,
          level: 90,
          antiSub: 88,
          modernization: const [0, 0, 0, 0, 0, 0, 8],
        );
        final aswState = state.copyWith(
          masterShips: {1: master},
          ships: {1: shipWithAsw},
        );
        final aswController = GameInfoNoticeController(
          stateProvider: () => aswState,
          layoutSettingsController: layoutController,
          topNoticeController: topNoticeController,
        );

        aswController.accept(
          createEvent(
            '/kcsapi/api_req_kaisou/powerup',
            '{"api_result":1,"api_data":{"api_powerup_flag":1,"api_ship":{'
                '"api_id":1,'
                '"api_ship_id":1,'
                '"api_taisen":[90,80],'
                '"api_kyouka":[0,0,0,0,0,0,10]'
                '}}}',
          ),
        );

        await aswController.idle;
        // Delta: 10 - 8 = 2. Max ASW reached (9 - 10 = -1 <= 0).
        expect(
          topNoticeController.current!.message,
          equals('改修成功：对潜 ▲ 2 (MAX)'),
        );

        // 4. ASW already at 9, another Kaiboukan fed (ASW delta 0):
        final shipWithMaxAsw = OwnedShip(
          id: 1,
          masterId: 1,
          level: 90,
          antiSub: 90,
          modernization: const [0, 0, 0, 0, 0, 0, 9],
        );
        final maxAswState = state.copyWith(
          masterShips: {1: master},
          ships: {1: shipWithMaxAsw},
        );
        final maxAswController = GameInfoNoticeController(
          stateProvider: () => maxAswState,
          layoutSettingsController: layoutController,
          topNoticeController: topNoticeController,
        );

        maxAswController.accept(
          createEvent(
            '/kcsapi/api_req_kaisou/powerup',
            '{"api_result":1,"api_data":{"api_powerup_flag":1,"api_ship":{'
                '"api_id":1,'
                '"api_ship_id":1,'
                '"api_taisen":[90,80],'
                '"api_kyouka":[0,0,0,0,0,0,9]'
                '}}}',
          ),
        );

        await maxAswController.idle;
        // Only ASW is known to be maxed; do not claim all stats are capped.
        expect(topNoticeController.current!.message, equals('近代化改修成功'));
      },
    );

    test(
      'Scenario E: Graceful degradation when Master stats cache is missing/zero (legacy cache)',
      () async {
        // MasterShip where base/max stats are all 0 (legacy serialized format):
        const legacyMaster = MasterShip(
          id: 1,
          name: '吹雪',
          shipTypeId: 2,
          baseFirepower: 0,
          maxFirepower: 0,
          baseTorpedo: 0,
          maxTorpedo: 0,
          baseAntiAir: 0,
          maxAntiAir: 0,
          baseArmor: 0,
          maxArmor: 0,
          baseLuck: 0,
          maxLuck: 0,
        );

        // Ship with empty modernization list (old save format):
        final legacyShip = OwnedShip(
          id: 1,
          masterId: 1,
          level: 50,
          firepower: 48,
          firepowerMax: 52,
          torpedo: 80,
          torpedoMax: 89,
          antiAir: 45,
          antiAirMax: 50,
          armor: 38,
          armorMax: 40,
          luck: 12,
          luckMax: 50,
          modernization: const [],
        );

        final legacyState = state.copyWith(
          masterShips: {1: legacyMaster},
          ships: {1: legacyShip},
        );

        final controller = GameInfoNoticeController(
          stateProvider: () => legacyState,
          layoutSettingsController: layoutController,
          topNoticeController: topNoticeController,
        );

        // Modernization event without api_kyouka (old API fallback):
        // Firepower reaches 52/52 (MAX). Torpedo reaches 85/89.
        controller.accept(
          createEvent(
            '/kcsapi/api_req_kaisou/powerup',
            '{"api_result":1,"api_data":{"api_powerup_flag":1,"api_ship":{'
                '"api_id":1,'
                '"api_ship_id":1,'
                '"api_karyoku":[52,52],'
                '"api_raisou":[85,89]'
                '}}}',
          ),
        );

        await controller.idle;
        final msg = topNoticeController.current!.message;
        // Firepower: 52 - 48 = 4 (MAX). Torpedo: 85 - 80 = 5.
        expect(msg, contains('火力 ▲ 4 (MAX)'));
        expect(msg, contains('雷装 ▲ 5'));
        expect(msg, isNot(contains('雷装 ▲ 5 (MAX)')));
        expect(
          topNoticeController.current!.tone,
          equals(TopNoticeTone.success),
        );
      },
    );
  });
}
