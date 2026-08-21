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
  NotificationSnapshot? latestSnapshot;
  bool failApply = false;

  @override
  Future<NotificationApplyResult> applySnapshot(
    NotificationSnapshot snapshot,
  ) async {
    if (failApply) throw StateError('native apply failed');
    latestSnapshot = snapshot;
    scheduledAlarms
      ..clear()
      ..addEntries(snapshot.alarms.map((alarm) => MapEntry(alarm.key, alarm)));
    return const NotificationApplyResult(
      scheduledExact: 0,
      scheduledInexact: 0,
      canceled: 0,
      failures: [],
    );
  }

  @override
  Future<NotificationPlatformCapabilities> getCapabilities() async {
    return const NotificationPlatformCapabilities(
      notificationsGranted: true,
      exactAlarmsGranted: true,
      channelsEnabled: true,
    );
  }

  @override
  Future<void> openSystemNotificationSettings() async {}

  @override
  Future<void> requestExactAlarmPermission() async {}

  @override
  Future<bool> requestNotificationPermission() async => true;
}

GameState _anchorageState({bool akashiFlagship = true}) {
  const akashiMaster = MasterShip(id: 182, name: '明石', shipTypeId: 19);
  const escortMaster = MasterShip(id: 1, name: '护卫舰', shipTypeId: 2);
  const akashi = OwnedShip(
    id: 1,
    masterId: 182,
    level: 35,
    currentHp: 39,
    maxHp: 39,
    condition: 49,
    currentFuel: 50,
    currentAmmo: 10,
    slotIds: [],
  );
  const escort = OwnedShip(
    id: 2,
    masterId: 1,
    level: 50,
    currentHp: 20,
    maxHp: 30,
    condition: 49,
    currentFuel: 15,
    currentAmmo: 20,
    slotIds: [],
    repairDurationMilliseconds: 3_600_000,
  );
  return GameState.empty.copyWith(
    masterShips: const {182: akashiMaster, 1: escortMaster},
    ships: const {1: akashi, 2: escort},
    fleets: [
      Fleet(
        id: 1,
        name: '第1舰队',
        shipIds: akashiFlagship ? const [1, 2] : const [2, 1],
      ),
    ],
  );
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
          const Fleet(id: 1, name: '第1舰队', shipIds: [1]),
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
          RepairDock(id: 1, state: 1, shipId: 10, completionTime: completeTime),
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

      expect(
        fakePort.scheduledAlarms.containsKey('repair_1_complete'),
        isFalse,
      );
      expect(
        fakePort.latestSnapshot?.alarms.map((item) => item.key),
        isNot(contains('repair_1_complete')),
      );

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

    test('keeps overdue authoritative tasks as completed ongoing items', () {
      final overdue = testNow.subtract(const Duration(minutes: 1));
      testState = GameState.empty.copyWith(
        updatedAt: testNow.subtract(const Duration(minutes: 30)),
        masterMissions: const {
          37: MasterMission(
            id: 37,
            name: '东京急行',
            duration: Duration(minutes: 30),
          ),
        },
        masterShips: const {
          1: MasterShip(id: 1, name: '吹雪', shipTypeId: 2),
          153: MasterShip(id: 153, name: '大凤', shipTypeId: 11),
        },
        ships: const {
          1: OwnedShip(
            id: 1,
            masterId: 1,
            level: 1,
            currentHp: 10,
            maxHp: 10,
            condition: 40,
            currentFuel: 10,
            currentAmmo: 10,
            slotIds: [],
          ),
          10: OwnedShip(
            id: 10,
            masterId: 1,
            level: 1,
            currentHp: 5,
            maxHp: 10,
            condition: 49,
            currentFuel: 10,
            currentAmmo: 10,
            slotIds: [],
            repairDurationMilliseconds: 600000,
          ),
        },
        fleets: [
          const Fleet(id: 1, name: '第1舰队', shipIds: [1]),
          Fleet(
            id: 2,
            name: '第2舰队',
            shipIds: const [10],
            mission: FleetMission(
              state: 1,
              missionId: 37,
              completionTime: overdue,
            ),
          ),
        ],
        repairDocks: [
          RepairDock(id: 1, state: 1, shipId: 10, completionTime: overdue),
        ],
        constructionDocks: [
          ConstructionDock(
            id: 1,
            state: 1,
            createdShipMasterId: 153,
            completionTime: overdue,
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

      final completedById = {
        for (final item in fakePort.latestSnapshot!.ongoingItems) item.id: item,
      };
      for (final id in const [
        'expedition:2',
        'repair:1',
        'construction:1',
        'morale:1',
      ]) {
        expect(
          completedById[id]?.state,
          OngoingTaskState.completed,
          reason: id,
        );
        expect(completedById[id]?.progress, 1, reason: id);
        expect(completedById[id]?.remainingSeconds, 0, reason: id);
      }
      expect(fakePort.latestSnapshot!.alarms, isEmpty);

      coordinator.dispose();
    });

    test('schedules anchorage repair 20m alarm when timer is active', () {
      final ancStarted = testNow.subtract(const Duration(minutes: 5));
      testState = _anchorageState();
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
      expect(alarm.triggerTime, ancStarted.add(const Duration(minutes: 20)));
      expect(alarm.body, contains('20 分钟'));

      coordinator.dispose();
    });

    test(
      'restores anchorage estimate from cached state after process restart',
      () {
        final cachedAt = testNow.subtract(const Duration(minutes: 5));
        testState = _anchorageState().copyWith(updatedAt: cachedAt);
        final coordinator = GameNotificationCoordinator(
          gameStateController: gameStateController,
          settingsController: settingsController,
          notificationPort: fakePort,
          gameStateProvider: () => testState,
          nowProvider: () => testNow,
          anchorageRepairStartedAtProvider: () => null,
        );
        coordinator.start();

        final alarm = fakePort.scheduledAlarms['anchorage_1_20m'];
        expect(alarm?.triggerTime, cachedAt.add(const Duration(minutes: 20)));
        expect(
          fakePort.latestSnapshot?.ongoingItems.map((item) => item.id),
          contains('anchorage:1'),
        );

        coordinator.dispose();
      },
    );

    test('drops anchorage task when Akashi is moved out of flagship', () {
      final ancStarted = testNow.subtract(const Duration(minutes: 5));
      testState = _anchorageState();
      final coordinator = GameNotificationCoordinator(
        gameStateController: gameStateController,
        settingsController: settingsController,
        notificationPort: fakePort,
        gameStateProvider: () => testState,
        nowProvider: () => testNow,
        anchorageRepairStartedAtProvider: () => ancStarted,
      );
      coordinator.start();

      expect(
        fakePort.latestSnapshot?.ongoingItems.map((item) => item.id),
        contains('anchorage:1'),
      );

      testState = _anchorageState(akashiFlagship: false);
      gameStateController.notifyListeners();

      expect(
        fakePort.latestSnapshot?.ongoingItems.map((item) => item.id),
        isNot(contains('anchorage:1')),
      );
      expect(
        fakePort.latestSnapshot?.alarms.map((alarm) => alarm.taskId),
        isNot(contains('anchorage:1')),
      );

      coordinator.dispose();
    });

    test(
      'all-repaired mode schedules the projected final repair deadline',
      () async {
        await settingsController.setAnchorageMode(
          AnchorageNotificationMode.allRepaired,
        );
        final ancStarted = testNow.subtract(const Duration(minutes: 5));
        testState = _anchorageState();
        final coordinator = GameNotificationCoordinator(
          gameStateController: gameStateController,
          settingsController: settingsController,
          notificationPort: fakePort,
          gameStateProvider: () => testState,
          nowProvider: () => testNow,
          anchorageRepairStartedAtProvider: () => ancStarted,
        );
        coordinator.start();

        final alarm = fakePort.latestSnapshot?.alarms.singleWhere(
          (item) => item.key == 'anchorage_1_all_repaired',
        );
        expect(alarm?.taskId, 'anchorage:1');
        expect(alarm?.removeTaskOnFire, isTrue);
        expect(alarm?.triggerTime.isAfter(testNow), isTrue);

        coordinator.dispose();
      },
    );

    test(
      'cancels construction alarm and drops ongoing progress on fast build',
      () {
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
        expect(fakePort.latestSnapshot?.ongoingItems.length, 1);

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
        expect(fakePort.latestSnapshot?.ongoingItems, isEmpty);
        expect(fakePort.latestSnapshot?.alarms, isEmpty);
        expect(fakePort.latestSnapshot?.ongoingItems, isEmpty);

        coordinator.dispose();
      },
    );

    test('reports native snapshot application failures', () async {
      fakePort.failApply = true;
      final errors = <Object>[];
      final coordinator = GameNotificationCoordinator(
        gameStateController: gameStateController,
        settingsController: settingsController,
        notificationPort: fakePort,
        gameStateProvider: () => testState,
        nowProvider: () => testNow,
        onError: (error, _) => errors.add(error),
      );

      coordinator.start();
      await Future<void>.delayed(Duration.zero);

      expect(errors.single, isA<StateError>());
      coordinator.dispose();
    });

    test('natural morale deadline stays anchored to the game snapshot', () {
      testState = GameState.empty.copyWith(
        updatedAt: testNow,
        ships: const {
          1: OwnedShip(
            id: 1,
            masterId: 1,
            level: 1,
            currentHp: 10,
            maxHp: 10,
            condition: 40,
            currentFuel: 10,
            currentAmmo: 10,
            slotIds: [],
          ),
        },
        fleets: const [
          Fleet(id: 1, name: 'Fleet 1', shipIds: [1]),
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
      final firstDeadline = fakePort.latestSnapshot!.alarms
          .singleWhere((alarm) => alarm.key == 'morale_1_normal')
          .triggerTime;

      testNow = testNow.add(const Duration(minutes: 1));
      settingsController.notifyListeners();
      final secondDeadline = fakePort.latestSnapshot!.alarms
          .singleWhere((alarm) => alarm.key == 'morale_1_normal')
          .triggerTime;

      expect(secondDeadline, firstDeadline);
      coordinator.dispose();
    });
  });
}
