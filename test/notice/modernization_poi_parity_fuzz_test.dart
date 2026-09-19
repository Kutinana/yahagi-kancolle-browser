import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/notice/game_info_notice_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/widgets/top_notice.dart';

class _MockStore implements LayoutSettingsStore, TopNoticeSettingsStore {
  @override
  Future<bool> loadTopNoticeEnabled() async => true;
  @override
  Future<void> saveTopNoticeEnabled(bool val) async {}
  @override
  Future<int> loadTopNoticeDurationSeconds() async => 5;
  @override
  Future<void> saveTopNoticeDurationSeconds(int val) async {}
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
  Future<String?> loadLocaleCode() async => 'zh';
  @override
  Future<void> saveLocaleCode(String? value) async {}
}

const int poiRemainingUnknown = -10000;

int poiCalcRemaining(List<int>? statusPair, List<int> kyoukaList, int i) {
  if (statusPair == null || statusPair.length < 2) return poiRemainingUnknown;
  if (i >= kyoukaList.length) return poiRemainingUnknown;
  return statusPair[1] - (statusPair[0] + kyoukaList[i]);
}

bool poiIsMax(int remaining) {
  if (remaining == poiRemainingUnknown) return false;
  return remaining <= 0;
}

int poiCalcDelta(List<int> kyoukaBefore, List<int> kyoukaAfter, int i) {
  final before = i < kyoukaBefore.length ? kyoukaBefore[i] : 0;
  final after = i < kyoukaAfter.length ? kyoukaAfter[i] : 0;
  return after - before;
}

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

void main() {
  group('Devil Review: 100+ Fuzz & Extreme Cases Bidirectional Poi Parity', () {
    test('Poi formula vs MasterShip.remainingModernization 150+ randomized cases', () {
      final rng = Random(42);

      for (var round = 0; round < 150; round++) {
        final statIndex = rng.nextInt(5); // 0..4
        final base = 5 + rng.nextInt(50);
        final maxCapacity = 10 + rng.nextInt(60);
        final maxVal = base + maxCapacity;
        final kyouka = rng.nextInt(maxCapacity + 10); // can exceed max

        final statusPair = [base, maxVal];
        final kyoukaList = List.generate(5, (_) => 0)..[statIndex] = kyouka;

        final master = MasterShip(
          id: 100,
          name: 'FuzzShip',
          shipTypeId: 2,
          baseFirepower: statIndex == 0 ? base : 0,
          maxFirepower: statIndex == 0 ? maxVal : 0,
          baseTorpedo: statIndex == 1 ? base : 0,
          maxTorpedo: statIndex == 1 ? maxVal : 0,
          baseAntiAir: statIndex == 2 ? base : 0,
          maxAntiAir: statIndex == 2 ? maxVal : 0,
          baseArmor: statIndex == 3 ? base : 0,
          maxArmor: statIndex == 3 ? maxVal : 0,
          baseLuck: statIndex == 4 ? base : 0,
          maxLuck: statIndex == 4 ? maxVal : 0,
        );

        final poiRem = poiCalcRemaining(statusPair, kyoukaList, statIndex);
        final yahagiRem = master.remainingModernization(statIndex, kyouka);

        expect(
          yahagiRem,
          equals(poiRem),
          reason: 'Mismatch at round $round for stat $statIndex: Poi=$poiRem, Yahagi=$yahagiRem',
        );

        final poiMax = poiIsMax(poiRem);
        final yahagiMax = yahagiRem != null && yahagiRem <= 0;
        expect(
          yahagiMax,
          equals(poiMax),
          reason: 'MAX status mismatch at round $round for stat $statIndex',
        );
      }
    });

    test('Edge case: Zero max stat (e.g. BB torpedo, Maruyu anti-air)', () {
      const bbMaster = MasterShip(
        id: 131,
        name: '大和',
        shipTypeId: 9,
        baseFirepower: 96,
        maxFirepower: 129,
        baseTorpedo: 0,
        maxTorpedo: 0, // 0 max torpedo
      );

      // Stat index 1 (torpedo) with maxTorpedo == 0
      expect(bbMaster.remainingModernization(1, 0), isNull);

      const maruyuMaster = MasterShip(
        id: 163,
        name: 'まるゆ',
        shipTypeId: 13,
        baseAntiAir: 0,
        maxAntiAir: 0, // 0 max anti-air
      );

      // Stat index 2 (anti-air) with maxAntiAir == 0
      expect(maruyuMaster.remainingModernization(2, 0), isNull);
    });

    test('Edge case: Exactly 1 point away from MAX, exactly at MAX, and overflowing MAX', () {
      const master = MasterShip(
        id: 1,
        name: 'Test',
        shipTypeId: 2,
        baseFirepower: 20,
        maxFirepower: 60, // capacity = 40
      );

      // 39: 1 point away
      expect(master.remainingModernization(0, 39), equals(1));
      expect(master.remainingModernization(0, 39)! <= 0, isFalse);

      // 40: exactly MAX
      expect(master.remainingModernization(0, 40), equals(0));
      expect(master.remainingModernization(0, 40)! <= 0, isTrue);

      // 41: over MAX
      expect(master.remainingModernization(0, 41), equals(-1));
      expect(master.remainingModernization(0, 41)! <= 0, isTrue);
    });

    test('Edge case: kyouka delta matches Poi when delta is zero, positive, or missing', () {
      final before = [10, 20, 30, 40, 12, 0, 0];
      final after = [13, 20, 35, 40, 13, 1, 3];

      for (var i = 0; i < 7; i++) {
        final expectedDelta = after[i] - before[i];
        expect(poiCalcDelta(before, after, i), equals(expectedDelta));
      }

      // Truncated list safe
      expect(poiCalcDelta([], [5], 0), equals(5));
      expect(poiCalcDelta([5], [], 0), equals(-5));
    });

    test('ASW equipment isolation: Sonars must NOT trigger false MAX when kyouka[6] < 9', () async {
      final store = _MockStore();
      final layoutController = await LayoutSettingsController.load(store);
      final topNoticeController = TopNoticeController();

      // Ship: level 99 DD with 2 Type 4 Sonars (+24 ASW).
      // Naked ASW: 70. Level 99 natural stat: 75.
      // With sonars: 70 + 24 = 94 > 75 (maxAsw).
      // Modernization ASW: 0 -> 1 (+1 ASW). kyouka[6] = 1 (out of 9, NOT max!).
      const master = MasterShip(
        id: 1,
        name: '吹雪',
        shipTypeId: 2,
        baseFirepower: 10,
        maxFirepower: 50,
      );

      final oldShip = OwnedShip(
        id: 42,
        masterId: 1,
        level: 99,
        antiSub: 94,
        modernization: const [0, 0, 0, 0, 0, 0, 0],
      );

      final state = GameState.empty.copyWith(
        masterShips: {1: master},
        ships: {42: oldShip},
      );

      final controller = GameInfoNoticeController(
        stateProvider: () => state,
        layoutSettingsController: layoutController,
        topNoticeController: topNoticeController,
      );

      // Response: new ASW is 95 (94 + 1), maxAsw is 75. kyouka[6] is 1.
      controller.accept(
        createEvent(
          '/kcsapi/api_req_kaisou/powerup',
          '{"api_result":1,"api_data":{"api_powerup_flag":1,"api_ship":{'
              '"api_id":42,'
              '"api_ship_id":1,'
              '"api_taisen":[95,75],'
              '"api_kyouka":[0,0,0,0,0,0,1]'
              '}}}',
        ),
      );

      await controller.idle;
      final msg = topNoticeController.current!.message;
      // MUST show +1 ASW, but MUST NOT have (MAX) because kyouka[6] is only 1!
      expect(msg, contains('对潜 ▲ 1'));
      expect(msg, isNot(contains('对潜 ▲ 1 (MAX)')));
    });

    test('ASW MAX: Triggered when kyouka[6] reaches 9', () async {
      final store = _MockStore();
      final layoutController = await LayoutSettingsController.load(store);
      final topNoticeController = TopNoticeController();

      const master = MasterShip(
        id: 1,
        name: '吹雪',
        shipTypeId: 2,
      );

      final oldShip = OwnedShip(
        id: 42,
        masterId: 1,
        level: 99,
        antiSub: 78,
        modernization: const [0, 0, 0, 0, 0, 0, 8],
      );

      final state = GameState.empty.copyWith(
        masterShips: {1: master},
        ships: {42: oldShip},
      );

      final controller = GameInfoNoticeController(
        stateProvider: () => state,
        layoutSettingsController: layoutController,
        topNoticeController: topNoticeController,
      );

      // Response: kyouka[6] is 9 (MAX)
      controller.accept(
        createEvent(
          '/kcsapi/api_req_kaisou/powerup',
          '{"api_result":1,"api_data":{"api_powerup_flag":1,"api_ship":{'
              '"api_id":42,'
              '"api_ship_id":1,'
              '"api_taisen":[79,75],'
              '"api_kyouka":[0,0,0,0,0,0,9]'
              '}}}',
        ),
      );

      await controller.idle;
      final msg = topNoticeController.current!.message;
      expect(msg, contains('对潜 ▲ 1 (MAX)'));
    });

    test('HP modernization: +1 is not MAX, +2 is MAX', () async {
      final store = _MockStore();
      final layoutController = await LayoutSettingsController.load(store);
      final topNoticeController = TopNoticeController();

      const master = MasterShip(
        id: 1,
        name: '吹雪',
        shipTypeId: 2,
        baseHp: 13,
        maxHp: 24,
      );

      final oldShip = OwnedShip(
        id: 42,
        masterId: 1,
        level: 1,
        maxHp: 13,
        modernization: const [0, 0, 0, 0, 0, 0, 0],
      );

      final state = GameState.empty.copyWith(
        masterShips: {1: master},
        ships: {42: oldShip},
      );

      final controller = GameInfoNoticeController(
        stateProvider: () => state,
        layoutSettingsController: layoutController,
        topNoticeController: topNoticeController,
      );

      // Step 1: HP 13 -> 14 (kyouka[5] = 1, NOT MAX)
      controller.accept(
        createEvent(
          '/kcsapi/api_req_kaisou/powerup',
          '{"api_result":1,"api_data":{"api_powerup_flag":1,"api_ship":{'
              '"api_id":42,'
              '"api_ship_id":1,'
              '"api_maxhp":14,'
              '"api_kyouka":[0,0,0,0,0,1,0]'
              '}}}',
        ),
      );

      await controller.idle;
      expect(topNoticeController.current!.message, contains('耐久 ▲ 1'));
      expect(topNoticeController.current!.message, isNot(contains('耐久 ▲ 1 (MAX)')));

      // Step 2: HP 14 -> 15 (kyouka[5] = 2, MAX!)
      final shipStep2 = OwnedShip(
        id: 42,
        masterId: 1,
        level: 1,
        maxHp: 14,
        modernization: const [0, 0, 0, 0, 0, 1, 0],
      );
      final stateStep2 = state.copyWith(ships: {42: shipStep2});
      final controller2 = GameInfoNoticeController(
        stateProvider: () => stateStep2,
        layoutSettingsController: layoutController,
        topNoticeController: topNoticeController,
      );

      controller2.accept(
        createEvent(
          '/kcsapi/api_req_kaisou/powerup',
          '{"api_result":1,"api_data":{"api_powerup_flag":1,"api_ship":{'
              '"api_id":42,'
              '"api_ship_id":1,'
              '"api_maxhp":15,'
              '"api_kyouka":[0,0,0,0,0,2,0]'
              '}}}',
        ),
      );

      await controller2.idle;
      expect(topNoticeController.current!.message, contains('耐久 ▲ 1 (MAX)'));
    });

    test('Old save compatibility: empty oldKyouka and missing master data does not crash', () async {
      final store = _MockStore();
      final layoutController = await LayoutSettingsController.load(store);
      final topNoticeController = TopNoticeController();

      // Ship with empty modernization list (old save)
      final oldShip = OwnedShip(
        id: 99,
        masterId: 999,
        level: 1,
        firepower: 20,
        firepowerMax: 40,
        modernization: const [],
      );

      // State without master data for 999
      final state = GameState.empty.copyWith(
        ships: {99: oldShip},
      );

      final controller = GameInfoNoticeController(
        stateProvider: () => state,
        layoutSettingsController: layoutController,
        topNoticeController: topNoticeController,
      );

      // Response has empty kyouka and karyoku [40, 40]
      controller.accept(
        createEvent(
          '/kcsapi/api_req_kaisou/powerup',
          '{"api_result":1,"api_data":{"api_powerup_flag":1,"api_ship":{'
              '"api_id":99,'
              '"api_karyoku":[40,40]'
              '}}}',
        ),
      );

      await controller.idle;
      expect(topNoticeController.current, isNotNull);
      expect(topNoticeController.current!.message, contains('火力 ▲ 20 (MAX)'));
    });
  });
}
