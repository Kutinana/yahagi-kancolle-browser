import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/notification/game_notification_coordinator.dart';
import 'package:yahagi_kancolle_browser/src/notification/notification_models.dart';
import 'package:yahagi_kancolle_browser/src/notification/notification_port.dart';
import 'package:yahagi_kancolle_browser/src/settings/notification_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/notification_settings_store.dart';

class FakeNotificationPort implements NotificationPort {
  final Map<String, ScheduledNotificationItem> scheduledAlarms = {};
  final List<String> canceledAlarms = [];
  bool allAlarmsCanceled = false;
  OngoingProgressSummary? currentOngoingSummary;
  bool ongoingCanceled = false;

  @override
  Future<void> scheduleAlarm(ScheduledNotificationItem item) async {
    scheduledAlarms[item.key] = item;
  }

  @override
  Future<void> cancelAlarm(String key) async {
    scheduledAlarms.remove(key);
    canceledAlarms.add(key);
  }

  @override
  Future<void> cancelAllAlarms() async {
    scheduledAlarms.clear();
    allAlarmsCanceled = true;
  }

  @override
  Future<void> updateOngoingProgress(OngoingProgressSummary summary) async {
    currentOngoingSummary = summary;
    ongoingCanceled = false;
  }

  @override
  Future<void> cancelOngoingProgress() async {
    currentOngoingSummary = null;
    ongoingCanceled = true;
  }

  @override
  Future<bool> requestPermission() async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GameNotificationCoordinator', () {
    late GameStateController gameStateController;
    late NotificationSettingsController settingsController;
    late FakeNotificationPort fakePort;
    late DateTime testNow;
    late GameState testState;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      gameStateController = GameStateController();
      settingsController = NotificationSettingsController(
        store: const SharedPreferencesNotificationSettingsStore(),
      );
      await settingsController.initialize();
      fakePort = FakeNotificationPort();
      testNow = DateTime(2026, 8, 22, 12, 0, 0);
      testState = GameState.empty;
    });

    test('schedules expedition complete and preempt alarms correctly', () {
      final returnTime = testNow.add(const Duration(minutes: 30));

      testState = testState.copyWith(
        masterMissions: {
          37: const MasterMission(
            id: 37,
            name: '东京急行',
            duration: Duration(minutes: 30),
          ),
        },
        fleets: [
          const Fleet(
            id: 1,
            name: '第1舰队',
            shipIds: [1],
          ),
          Fleet(
            id: 2,
            name: '第2舰队',
            shipIds: const [2],
            mission: FleetMission(
              state: 1,
              missionId: 37,
              completionTime: returnTime,
            ),
          ),
        ],
      );

      final coordinator = GameNotificationCoordinator(
        gameStateController: gameStateController,
        settingsController: settingsController,
        notificationPort: fakePort,
        gameStateProvider: () => testState,
        nowProvider: () => testNow,
      );
      coordinator.start();

      // Verify expedition alarms
      expect(
        fakePort.scheduledAlarms.containsKey('expedition_2_complete'),
        isTrue,
      );
      expect(
        fakePort.scheduledAlarms.containsKey('expedition_2_preempt'),
        isTrue,
      );

      final completeAlarm = fakePort.scheduledAlarms['expedition_2_complete']!;
      expect(completeAlarm.triggerTime, returnTime);
      expect(completeAlarm.body, '东京急行 已顺利返抵母港！');

      final preemptAlarm = fakePort.scheduledAlarms['expedition_2_preempt']!;
      expect(
        preemptAlarm.triggerTime,
        returnTime.subtract(const Duration(seconds: 60)),
      );

      coordinator.dispose();
    });

    test('schedules repair dock alarm and cancels when repaired', () {
      final completeTime = testNow.add(const Duration(hours: 1));
      testState = testState.copyWith(
        masterShips: {
          131: const MasterShip(id: 131, name: '大和', shipTypeId: 9),
        },
        ships: {
          10: const OwnedShip(
            id: 10,
            masterId: 131,
            level: 99,
            currentHp: 20,
            maxHp: 96,
            condition: 49,
            currentFuel: 100,
            currentAmmo: 100,
            slotIds: [],
          ),
        },
        repairDocks: [
          RepairDock(
            id: 1,
            state: 1,
            shipId: 10,
            completionTime: completeTime,
          ),
        ],
      );

      final coordinator = GameNotificationCoordinator(
        gameStateController: gameStateController,
        settingsController: settingsController,
        notificationPort: fakePort,
        gameStateProvider: () => testState,
        nowProvider: () => testNow,
      );
      coordinator.start();

      expect(fakePort.scheduledAlarms.containsKey('repair_1_complete'), isTrue);
      final alarm = fakePort.scheduledAlarms['repair_1_complete']!;
      expect(alarm.body, '大和 已经在船坞修理完毕，HP 已完全修满！');

      // Now clear the dock (e.g. instant bucket used)
      testState = testState.copyWith(
        repairDocks: [
          const RepairDock(id: 1, state: 0, shipId: 0, completionTime: null),
        ],
      );
      // Trigger setting change or notification sync
      settingsController.notifyListeners();

      expect(fakePort.scheduledAlarms.containsKey('repair_1_complete'), isFalse);
      expect(fakePort.canceledAlarms.contains('repair_1_complete'), isTrue);

      coordinator.dispose();
    });

    test('schedules construction dock with parsed master ship name', () {
      final completeTime = testNow.add(const Duration(hours: 4));
      testState = testState.copyWith(
        masterShips: {
          153: const MasterShip(id: 153, name: '大凤', shipTypeId: 11),
        },
        constructionDocks: [
          ConstructionDock(
            id: 1,
            state: 2,
            createdShipMasterId: 153,
            completionTime: completeTime,
          ),
        ],
      );

      final coordinator = GameNotificationCoordinator(
        gameStateController: gameStateController,
        settingsController: settingsController,
        notificationPort: fakePort,
        gameStateProvider: () => testState,
        nowProvider: () => testNow,
      );
      coordinator.start();

      expect(
        fakePort.scheduledAlarms.containsKey('construction_1_complete'),
        isTrue,
      );
      final alarm = fakePort.scheduledAlarms['construction_1_complete']!;
      expect(alarm.body, '大凤 已在船坞建造完成！');

      coordinator.dispose();
    });

    test('schedules anchorage repair 20m alarm when timer is active', () {
      final ancStarted = testNow.subtract(const Duration(minutes: 5));
      final coordinator = GameNotificationCoordinator(
        gameStateController: gameStateController,
        settingsController: settingsController,
        notificationPort: fakePort,
        gameStateProvider: () => testState,
        nowProvider: () => testNow,
        anchorageRepairStartedAtProvider: () => ancStarted,
      );
      coordinator.start();

      expect(fakePort.scheduledAlarms.containsKey('anchorage_1_20m'), isTrue);
      final alarm = fakePort.scheduledAlarms['anchorage_1_20m']!;
      expect(
        alarm.triggerTime,
        ancStarted.add(const Duration(minutes: 20)),
      );
      expect(alarm.body, contains('20 分钟'));

      coordinator.dispose();
    });

    test('cancels construction alarm and drops ongoing progress on fast build', () {
      final completeTime = testNow.add(const Duration(hours: 1));
      testState = testState.copyWith(
        masterShips: {
          153: const MasterShip(id: 153, name: '大凤', shipTypeId: 11),
        },
        constructionDocks: [
          ConstructionDock(
            id: 1,
            state: 1,
            createdShipMasterId: 153,
            completionTime: completeTime,
          ),
        ],
      );

      final coordinator = GameNotificationCoordinator(
        gameStateController: gameStateController,
        settingsController: settingsController,
        notificationPort: fakePort,
        gameStateProvider: () => testState,
        nowProvider: () => testNow,
      );
      coordinator.start();

      expect(
        fakePort.scheduledAlarms.containsKey('construction_1_complete'),
        isTrue,
      );
      expect(fakePort.currentOngoingSummary?.items.length, 1);

      // Fast build (speedchange) sets state to 3 and completionTime to now
      testState = testState.copyWith(
        constructionDocks: [
          ConstructionDock(
            id: 1,
            state: 3,
            createdShipMasterId: 153,
            completionTime: testNow,
          ),
        ],
      );
      gameStateController.notifyListeners();

      expect(
        fakePort.scheduledAlarms.containsKey('construction_1_complete'),
        isFalse,
      );
      expect(fakePort.currentOngoingSummary, isNull);

      coordinator.dispose();
    });
  });
}
