import 'dart:async';
import 'package:flutter/foundation.dart';
import '../fleet/anchorage_repair_calculator.dart';
import '../fleet/nosaki_sparkle_calculator.dart';
import '../expedition/expedition_mission_picker.dart';
import '../game_state/game_state.dart';
import '../game_state/game_state_controller.dart';
import '../settings/notification_settings_controller.dart';
import '../settings/notification_settings_store.dart';
import 'notification_models.dart';
import 'notification_port.dart';
import 'notification_timer_anchor_store.dart';

class GameNotificationCoordinator {
  GameNotificationCoordinator({
    required this.gameStateController,
    required this.settingsController,
    required this.notificationPort,
    GameState Function()? gameStateProvider,
    DateTime Function()? nowProvider,
    DateTime? Function()? anchorageRepairStartedAtProvider,
    DateTime? Function()? nosakiSparkleStartedAtProvider,
    String? Function()? lastUpdatedPathProvider,
    NotificationTimerAnchors initialTimerAnchors =
        NotificationTimerAnchors.empty,
    NotificationTimerAnchorStore? timerAnchorStore,
    Future<void> Function(Duration delay)? retryDelay,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) : _gameStateProvider =
           gameStateProvider ?? (() => gameStateController.state),
       _now = nowProvider ?? DateTime.now,
       _anchorageStartedAt =
           anchorageRepairStartedAtProvider ??
           (() => gameStateController.anchorageRepairStartedAt),
       _nosakiStartedAt =
           nosakiSparkleStartedAtProvider ??
           (() => gameStateController.nosakiSparkleStartedAt),
       _lastUpdatedPath =
           lastUpdatedPathProvider ??
           (() => gameStateController.lastUpdatedPath),
       _timerAnchors = initialTimerAnchors,
       _timerAnchorStore = timerAnchorStore,
       _retryDelay = retryDelay ?? ((delay) => Future<void>.delayed(delay)),
       _onError = onError ?? _reportFlutterError;

  final GameStateController gameStateController;
  final NotificationSettingsController settingsController;
  final NotificationPort notificationPort;
  final GameState Function() _gameStateProvider;
  final DateTime Function() _now;
  final DateTime? Function() _anchorageStartedAt;
  final DateTime? Function() _nosakiStartedAt;
  final String? Function() _lastUpdatedPath;
  final NotificationTimerAnchorStore? _timerAnchorStore;
  final Future<void> Function(Duration delay) _retryDelay;
  final void Function(Object error, StackTrace stackTrace) _onError;

  bool _disposed = false;
  Map<String, _ManualCompletionTask> _manualCompletionTasks = const {};
  final Map<String, OngoingTaskItem> _completedTombstones = {};
  NotificationTimerAnchors _timerAnchors;
  Future<void> _timerAnchorSaveQueue = Future<void>.value();
  final Map<String, ImmediateNotificationItem> _pendingImmediateAlerts = {};
  NotificationSnapshot? _pendingSnapshot;
  Completer<void>? _retryWake;
  bool _drainingSnapshots = false;

  static const _snapshotRetryBackoff = <Duration>[
    Duration(seconds: 1),
    Duration(seconds: 3),
    Duration(seconds: 10),
  ];

  void start() {
    final state = _gameStateProvider();
    _restoreGlobalTimerAnchors(state);
    _recordGlobalTimerAnchors(state);
    _manualCompletionTasks = _captureManualCompletionTasks(state, _now());
    gameStateController.addListener(_onGameStateChanged);
    settingsController.addListener(_syncSnapshot);
    _syncSnapshot();
  }

  void dispose() {
    _disposed = true;
    _pendingSnapshot = null;
    final retryWake = _retryWake;
    if (retryWake != null && !retryWake.isCompleted) retryWake.complete();
    gameStateController.removeListener(_onGameStateChanged);
    settingsController.removeListener(_syncSnapshot);
  }

  void _onGameStateChanged() {
    if (_disposed) return;
    final now = _now();
    final state = _gameStateProvider();
    _recordGlobalTimerAnchors(state);
    final alerts = _buildImmediateAlerts(state, now);
    _updateCompletedTombstones(state);
    _manualCompletionTasks = _captureManualCompletionTasks(state, now);
    _syncSnapshot(immediateAlerts: alerts);
  }

  void _syncSnapshot({
    List<ImmediateNotificationItem> immediateAlerts = const [],
  }) {
    if (_disposed) return;
    final settings = settingsController.settings;
    if (!settings.master) {
      _pendingImmediateAlerts.clear();
    } else {
      for (final alert in immediateAlerts) {
        _pendingImmediateAlerts[alert.key] = alert;
      }
    }
    final snapshot = NotificationSnapshot(
      updatedAt: _now(),
      immediateAlerts: _pendingImmediateAlerts.values.toList(growable: false),
      alarms: settings.master ? _buildScheduledAlarms() : const [],
      ongoingItems: settings.master && settings.ongoingLive
          ? _buildOngoingItems()
          : const [],
      presentation: NotificationPresentation(
        enabled: settings.master,
        sound: settings.sound,
        vibration: settings.vibration,
        showProgress: settings.showProgress,
        showPercent: settings.showPercent,
        showCountdown: settings.showCountdown,
        ongoingLive: settings.ongoingLive,
      ),
    );
    _enqueueSnapshot(snapshot);
  }

  Map<String, _ManualCompletionTask> _captureManualCompletionTasks(
    GameState state,
    DateTime now,
  ) {
    final tasks = <String, _ManualCompletionTask>{};
    for (final dock in state.constructionDocks) {
      final deadline = dock.completionTime;
      if (!dock.isBuilding ||
          dock.state == 3 ||
          deadline == null ||
          !deadline.isAfter(now)) {
        continue;
      }
      final master = state.masterShips[dock.createdShipMasterId];
      final shipName = master?.name.isNotEmpty == true ? master!.name : '舰娘';
      final id = 'construction:${dock.id}';
      tasks[id] = _ManualCompletionTask(
        id: id,
        dockId: dock.id,
        type: GameNotificationType.construction,
        deadline: deadline,
        title: '建造完成 · 船坞 #${dock.id}',
        body: '$shipName 已在船坞建造完成！',
        ongoingTitle: '🔨 建造 船坞 #${dock.id} · $shipName 建造完成',
        totalSeconds: dock.startedAt == null
            ? deadline.difference(now).inSeconds.clamp(1, 1 << 31)
            : deadline.difference(dock.startedAt!).inSeconds.clamp(1, 1 << 31),
      );
    }
    for (final dock in state.repairDocks) {
      final deadline = dock.completionTime;
      if (!dock.isRepairing || deadline == null || !deadline.isAfter(now)) {
        continue;
      }
      final ship = state.ships[dock.shipId];
      final master = ship == null ? null : state.masterShips[ship.masterId];
      final shipName = master?.name.isNotEmpty == true ? master!.name : '舰船';
      final id = 'repair:${dock.id}';
      tasks[id] = _ManualCompletionTask(
        id: id,
        dockId: dock.id,
        type: GameNotificationType.repair,
        deadline: deadline,
        title: '舰船修复完成 · 船坞 #${dock.id}',
        body: '$shipName 已经在船坞修理完毕，HP 已完全修满！',
        ongoingTitle: '🔧 入渠 船坞 #${dock.id} · $shipName 修复完成',
        totalSeconds: ship != null && ship.repairDurationMilliseconds > 0
            ? (ship.repairDurationMilliseconds / 1000).round()
            : deadline.difference(now).inSeconds.clamp(1, 1 << 31),
      );
    }
    return tasks;
  }

  List<ImmediateNotificationItem> _buildImmediateAlerts(
    GameState state,
    DateTime now,
  ) {
    final settings = settingsController.settings;
    if (!settings.master) return const [];
    final alerts = <ImmediateNotificationItem>[];
    for (final task in _manualCompletionTasks.values) {
      if (!task.deadline.isAfter(now)) continue;
      final manuallyCompleted = _isManuallyCompleted(task, state);
      final typeEnabled = switch (task.type) {
        GameNotificationType.construction => settings.construction,
        GameNotificationType.repair => settings.repair,
        _ => false,
      };
      if (!manuallyCompleted || !typeEnabled) continue;
      alerts.add(
        ImmediateNotificationItem(
          key: '${task.id}:manual:${task.deadline.millisecondsSinceEpoch}',
          taskId: task.id,
          type: task.type,
          occurredAt: now,
          deadline: task.deadline,
          title: task.title,
          body: task.body,
        ),
      );
    }
    return alerts;
  }

  bool _isManuallyCompleted(_ManualCompletionTask task, GameState state) =>
      switch (task.type) {
        GameNotificationType.construction => state.constructionDocks.any(
          (dock) => dock.id == task.dockId && dock.state == 3,
        ),
        GameNotificationType.repair => state.repairDocks.any(
          (dock) => dock.id == task.dockId && !dock.isRepairing,
        ),
        _ => false,
      };

  void _updateCompletedTombstones(GameState state) {
    for (final task in _manualCompletionTasks.values) {
      if (task.type != GameNotificationType.repair ||
          !_isManuallyCompleted(task, state)) {
        continue;
      }
      _completedTombstones[task.id] = OngoingTaskItem(
        id: task.id,
        type: task.type,
        title: task.ongoingTitle,
        state: OngoingTaskState.completed,
        progress: 1,
        remainingSeconds: 0,
        targetEpochMs: task.deadline.millisecondsSinceEpoch,
        totalDurationSec: task.totalSeconds,
      );
    }

    final path = _lastUpdatedPath();
    final authoritativeRepairRefresh =
        path == '/kcsapi/api_get_member/ndock' ||
        path == '/kcsapi/api_port/port';
    if (authoritativeRepairRefresh) {
      _completedTombstones.removeWhere(
        (_, item) => item.type == GameNotificationType.repair,
      );
    }
  }

  void _enqueueSnapshot(NotificationSnapshot snapshot) {
    _pendingSnapshot = snapshot;
    final retryWake = _retryWake;
    if (retryWake != null && !retryWake.isCompleted) retryWake.complete();
    if (!_drainingSnapshots) unawaited(_drainSnapshots());
  }

  Future<void> _drainSnapshots() async {
    if (_drainingSnapshots) return;
    _drainingSnapshots = true;
    try {
      while (!_disposed) {
        final snapshot = _pendingSnapshot;
        if (snapshot == null) break;
        _pendingSnapshot = null;
        var retryIndex = 0;
        while (!_disposed) {
          Object? lastError;
          StackTrace? lastStackTrace;
          try {
            final result = await notificationPort.applySnapshot(snapshot);
            if (result.failures.isNotEmpty) {
              throw StateError(
                'Native notification failures: ${result.failures.join(', ')}',
              );
            }
            final deliveredKeys = snapshot.immediateAlerts
                .map((alert) => alert.key)
                .toSet();
            _pendingImmediateAlerts.removeWhere(
              (key, _) => deliveredKeys.contains(key),
            );
            final pending = _pendingSnapshot;
            if (pending != null && deliveredKeys.isNotEmpty) {
              _pendingSnapshot = NotificationSnapshot(
                schemaVersion: pending.schemaVersion,
                updatedAt: pending.updatedAt,
                immediateAlerts: pending.immediateAlerts
                    .where((alert) => !deliveredKeys.contains(alert.key))
                    .toList(growable: false),
                alarms: pending.alarms,
                ongoingItems: pending.ongoingItems,
                presentation: pending.presentation,
              );
            }
            break;
          } catch (error, stackTrace) {
            lastError = error;
            lastStackTrace = stackTrace;
          }

          if (_pendingSnapshot != null) break;
          if (retryIndex >= _snapshotRetryBackoff.length) {
            _onError(lastError!, lastStackTrace!);
            break;
          }
          final wake = Completer<void>();
          _retryWake = wake;
          await Future.any<void>([
            _retryDelay(_snapshotRetryBackoff[retryIndex]),
            wake.future,
          ]);
          if (identical(_retryWake, wake)) _retryWake = null;
          retryIndex++;
          if (_pendingSnapshot != null) break;
        }
      }
    } finally {
      _retryWake = null;
      _drainingSnapshots = false;
    }
  }

  static void _reportFlutterError(Object error, StackTrace stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'game notification coordinator',
      ),
    );
  }

  List<ScheduledNotificationItem> _buildScheduledAlarms() {
    final settings = settingsController.settings;

    final state = _gameStateProvider();
    final now = _now();
    final desiredAlarms = <String, ScheduledNotificationItem>{};

    // 1. Expedition
    if (settings.expedition) {
      for (final fleet in state.fleets) {
        final mission = fleet.mission;
        if (mission.isActive &&
            mission.completionTime != null &&
            mission.completionTime!.isAfter(now)) {
          final retTime = mission.completionTime!;
          final fleetName = fleet.displayName;
          final masterMission = state.masterMissions[mission.missionId];
          final missionName = masterMission?.name.isNotEmpty == true
              ? masterMission!.name
              : (mission.missionId > 0 ? '远征 ${mission.missionId}' : '远征');

          // Preempt alarm
          if (settings.expeditionPreemptSeconds > 0) {
            final preemptTime = retTime.subtract(
              Duration(seconds: settings.expeditionPreemptSeconds),
            );
            if (preemptTime.isAfter(now)) {
              final key = 'expedition_${fleet.id}_preempt';
              desiredAlarms[key] = ScheduledNotificationItem(
                key: key,
                taskId: 'expedition:${fleet.id}',
                type: GameNotificationType.expedition,
                stage: NotificationAlarmStage.preempt,
                removeTaskOnFire: false,
                triggerTime: preemptTime,
                title: '远征即将归还 · $fleetName',
                body:
                    '$missionName 还有 ${settings.expeditionPreemptSeconds} 秒返回母港，请做好迎接准备。',
              );
            }
          }

          // Complete alarm
          final key = 'expedition_${fleet.id}_complete';
          desiredAlarms[key] = ScheduledNotificationItem(
            key: key,
            taskId: 'expedition:${fleet.id}',
            type: GameNotificationType.expedition,
            stage: NotificationAlarmStage.complete,
            removeTaskOnFire: true,
            triggerTime: retTime,
            title: '远征完成 · $fleetName',
            body: '$missionName 已顺利返抵母港！',
          );
        }
      }
    }

    // 2. Repair Docks
    if (settings.repair) {
      for (final dock in state.repairDocks) {
        if (dock.isRepairing &&
            dock.completionTime != null &&
            dock.completionTime!.isAfter(now)) {
          final compTime = dock.completionTime!;
          final ship = state.ships[dock.shipId];
          final masterShip = ship != null
              ? state.masterShips[ship.masterId]
              : null;
          final shipName = masterShip?.name.isNotEmpty == true
              ? masterShip!.name
              : '舰船';

          if (settings.repairPreemptSeconds > 0) {
            final preemptTime = compTime.subtract(
              Duration(seconds: settings.repairPreemptSeconds),
            );
            if (preemptTime.isAfter(now)) {
              final key = 'repair_${dock.id}_preempt';
              desiredAlarms[key] = ScheduledNotificationItem(
                key: key,
                taskId: 'repair:${dock.id}',
                type: GameNotificationType.repair,
                stage: NotificationAlarmStage.preempt,
                removeTaskOnFire: false,
                triggerTime: preemptTime,
                title: '修复即将完成 · 船坞 #${dock.id}',
                body: '$shipName 还有 ${settings.repairPreemptSeconds} 秒修理完毕。',
              );
            }
          }

          final key = 'repair_${dock.id}_complete';
          desiredAlarms[key] = ScheduledNotificationItem(
            key: key,
            taskId: 'repair:${dock.id}',
            type: GameNotificationType.repair,
            stage: NotificationAlarmStage.complete,
            removeTaskOnFire: true,
            triggerTime: compTime,
            title: '舰船修复完成 · 船坞 #${dock.id}',
            body: '$shipName 已经在船坞修理完毕，HP 已完全修满！',
          );
        }
      }
    }

    // 3. Construction Docks
    if (settings.construction) {
      for (final dock in state.constructionDocks) {
        if (dock.isBuilding &&
            !dock.isCompletedAt(now) &&
            dock.completionTime != null &&
            dock.completionTime!.isAfter(now)) {
          final compTime = dock.completionTime!;
          String shipName = '舰娘';
          final masterId = dock.createdShipMasterId;
          if (masterId > 0) {
            final master = state.masterShips[masterId];
            if (master != null && master.name.isNotEmpty) {
              shipName = master.name;
            }
          }

          if (settings.constructionPreemptSeconds > 0) {
            final preemptTime = compTime.subtract(
              Duration(seconds: settings.constructionPreemptSeconds),
            );
            if (preemptTime.isAfter(now)) {
              final key = 'construction_${dock.id}_preempt';
              desiredAlarms[key] = ScheduledNotificationItem(
                key: key,
                taskId: 'construction:${dock.id}',
                type: GameNotificationType.construction,
                stage: NotificationAlarmStage.preempt,
                removeTaskOnFire: false,
                triggerTime: preemptTime,
                title: '建造即将完成 · 船坞 #${dock.id}',
                body:
                    '$shipName 还有 ${settings.constructionPreemptSeconds} 秒建造完成。',
              );
            }
          }

          final key = 'construction_${dock.id}_complete';
          desiredAlarms[key] = ScheduledNotificationItem(
            key: key,
            taskId: 'construction:${dock.id}',
            type: GameNotificationType.construction,
            stage: NotificationAlarmStage.complete,
            removeTaskOnFire: true,
            triggerTime: compTime,
            title: '建造完成 · 船坞 #${dock.id}',
            body: '$shipName 已在船坞建造完成！',
          );
        }
      }
    }

    // 4. Anchorage Repair
    if (settings.anchorage) {
      final ancStart = _anchorageStartFor(state);
      final projection = ancStart == null
          ? null
          : AnchorageRepairCalculator.project(
              state: state,
              fleetId: 1,
              elapsed: now.difference(ancStart),
            );
      final hasRepairTarget =
          projection?.isReady == true &&
          projection!.rows.any(
            (row) => row.status == AnchorageRepairShipStatus.repairing,
          );
      if (ancStart != null && hasRepairTarget) {
        final fleet1 = state.fleets.cast<Fleet?>().firstWhere(
          (f) => f?.id == 1,
          orElse: () => null,
        );
        final fleet1Name = fleet1?.displayName ?? '第1舰队';
        final twentyMinTime = ancStart.add(const Duration(minutes: 20));
        if (twentyMinTime.isAfter(now) &&
            (settings.anchorageMode ==
                    AnchorageNotificationMode.twentyMinutes ||
                settings.anchorageMode == AnchorageNotificationMode.both)) {
          const key = 'anchorage_1_20m';
          desiredAlarms[key] = ScheduledNotificationItem(
            key: key,
            taskId: 'anchorage:1',
            type: GameNotificationType.anchorage,
            stage: NotificationAlarmStage.milestone,
            removeTaskOnFire: false,
            triggerTime: twentyMinTime,
            title: '泊地修理结算就绪 · $fleet1Name',
            body: '明石泊地修理已满 20 分钟！可返回母港刷新以结算首轮回血。',
          );
        }

        if (settings.anchorageMode == AnchorageNotificationMode.allRepaired ||
            settings.anchorageMode == AnchorageNotificationMode.both) {
          var remaining = Duration.zero;
          for (final row in projection.rows) {
            if (row.status == AnchorageRepairShipStatus.repairing &&
                row.remaining != null &&
                row.remaining! > remaining) {
              remaining = row.remaining!;
            }
          }
          if (remaining > Duration.zero) {
            const key = 'anchorage_1_all_repaired';
            desiredAlarms[key] = ScheduledNotificationItem(
              key: key,
              taskId: 'anchorage:1',
              type: GameNotificationType.anchorage,
              stage: NotificationAlarmStage.complete,
              removeTaskOnFire: true,
              triggerTime: now.add(remaining),
              title: 'Anchorage repair complete · $fleet1Name',
              body: 'All eligible ships in $fleet1Name should now be repaired.',
            );
          }
        }
      }
    }

    // 5. Morale & Nosaki Sparkle
    if (settings.morale) {
      for (final fleet in state.fleets) {
        if (fleet.shipIds.isEmpty) continue;
        final fleetName = fleet.displayName;

        // Check if Nosaki sparkle mode is active for this fleet
        final nosakiStart = _nosakiStartFor(state);
        final nosakiElapsed = nosakiStart != null
            ? now.difference(nosakiStart)
            : Duration.zero;
        final nosakiProjection = NosakiSparkleCalculator.project(
          state: state,
          fleetId: fleet.id,
          elapsed: nosakiElapsed,
        );

        if (nosakiProjection.isReady &&
            nosakiProjection.rows.isNotEmpty &&
            nosakiProjection.eligibleShipCount > 0) {
          // Nosaki sparkle mode: Target 54 sparkle
          Duration maxTimeTo54 = Duration.zero;
          for (final row in nosakiProjection.rows) {
            if (row.estimatedTimeTo54 != null &&
                row.estimatedTimeTo54! > maxTimeTo54) {
              maxTimeTo54 = row.estimatedTimeTo54!;
            }
          }

          if (maxTimeTo54 > Duration.zero) {
            final completeTime = now.add(maxTimeTo54);
            if (settings.moralePreemptSeconds > 0) {
              final preemptTime = completeTime.subtract(
                Duration(seconds: settings.moralePreemptSeconds),
              );
              if (preemptTime.isAfter(now)) {
                final key = 'morale_${fleet.id}_nosaki_preempt';
                desiredAlarms[key] = ScheduledNotificationItem(
                  key: key,
                  taskId: 'morale:${fleet.id}',
                  type: GameNotificationType.morale,
                  stage: NotificationAlarmStage.preempt,
                  removeTaskOnFire: false,
                  triggerTime: preemptTime,
                  title: '野崎刷闪即将完成 · $fleetName',
                  body:
                      '$fleetName 随伴舰还有 ${settings.moralePreemptSeconds} 秒达到 54 闪。',
                );
              }
            }

            final key = 'morale_${fleet.id}_nosaki';
            desiredAlarms[key] = ScheduledNotificationItem(
              key: key,
              taskId: 'morale:${fleet.id}',
              type: GameNotificationType.morale,
              stage: NotificationAlarmStage.complete,
              removeTaskOnFire: true,
              triggerTime: completeTime,
              title: '野崎刷闪完成 · $fleetName',
              body: '$fleetName 随伴舰已全部达到 54 闪。',
            );
          }
        } else {
          // Natural morale recovery mode: Target 49
          int minCond = 100;
          for (final shipId in fleet.shipIds) {
            final ship = state.ships[shipId];
            if (ship != null && ship.condition < minCond) {
              minCond = ship.condition;
            }
          }

          if (minCond < 49) {
            final completeTime = _normalMoraleTarget(
              fleet: fleet,
              state: state,
              now: now,
              minCond: minCond,
            );
            if (!completeTime.isAfter(now)) continue;

            if (settings.moralePreemptSeconds > 0) {
              final preemptTime = completeTime.subtract(
                Duration(seconds: settings.moralePreemptSeconds),
              );
              if (preemptTime.isAfter(now)) {
                final key = 'morale_${fleet.id}_normal_preempt';
                desiredAlarms[key] = ScheduledNotificationItem(
                  key: key,
                  taskId: 'morale:${fleet.id}',
                  type: GameNotificationType.morale,
                  stage: NotificationAlarmStage.preempt,
                  removeTaskOnFire: false,
                  triggerTime: preemptTime,
                  title: '疲劳即将恢复 · $fleetName',
                  body:
                      '$fleetName 全队舰船士气还有 ${settings.moralePreemptSeconds} 秒恢复至 49。',
                );
              }
            }

            final key = 'morale_${fleet.id}_normal';
            desiredAlarms[key] = ScheduledNotificationItem(
              key: key,
              taskId: 'morale:${fleet.id}',
              type: GameNotificationType.morale,
              stage: NotificationAlarmStage.complete,
              removeTaskOnFire: true,
              triggerTime: completeTime,
              title: '疲劳恢复完毕 · $fleetName',
              body: '$fleetName 全队舰船士气已恢复至 49。',
            );
          }
        }
      }
    }

    return desiredAlarms.values.toList(growable: false);
  }

  List<OngoingTaskItem> _buildOngoingItems() {
    final settings = settingsController.settings;

    final state = _gameStateProvider();
    final now = _now();
    final items = <OngoingTaskItem>[];

    // 1. Expedition
    if (settings.expedition) {
      for (final fleet in state.fleets) {
        final mission = fleet.mission;
        if (mission.isActive && mission.completionTime != null) {
          final masterMission = state.masterMissions[mission.missionId];
          final displayId = expeditionDisplayId(
            mission.missionId,
            masterMission,
          );
          final totalSec =
              masterMission != null && masterMission.duration.inSeconds > 0
              ? masterMission.duration.inSeconds
              : 1800;
          final fleetName = fleet.displayName;
          final formattedMission = masterMission?.name.isNotEmpty == true
              ? '远征 $fleetName $displayId · ${masterMission!.name}'
              : (mission.missionId > 0
                    ? '远征 $fleetName $displayId'
                    : '远征 $fleetName');
          items.add(
            _deadlineItem(
              id: 'expedition:${fleet.id}',
              type: GameNotificationType.expedition,
              title: '⚓ $formattedMission',
              deadline: mission.completionTime!,
              totalSeconds: totalSec,
              now: now,
            ),
          );
        }
      }
    }

    // 2. Repair Docks
    if (settings.repair) {
      for (final dock in state.repairDocks) {
        if (dock.isRepairing && dock.completionTime != null) {
          final ship = state.ships[dock.shipId];
          final totalSec = ship != null && ship.repairDurationMilliseconds > 0
              ? (ship.repairDurationMilliseconds / 1000).round()
              : dock.completionTime!
                    .difference(now)
                    .inSeconds
                    .clamp(1, 1 << 31);
          final masterShip = ship != null
              ? state.masterShips[ship.masterId]
              : null;
          final shipName = masterShip?.name.isNotEmpty == true
              ? masterShip!.name
              : '舰船';
          items.add(
            _deadlineItem(
              id: 'repair:${dock.id}',
              type: GameNotificationType.repair,
              title: '🔧 入渠 船坞 #${dock.id} · $shipName',
              deadline: dock.completionTime!,
              totalSeconds: totalSec,
              now: now,
            ),
          );
        }
      }
    }

    // 3. Anchorage Repair
    if (settings.anchorage) {
      final ancStart = _anchorageStartFor(state);
      final projection = ancStart == null
          ? null
          : AnchorageRepairCalculator.project(
              state: state,
              fleetId: 1,
              elapsed: now.difference(ancStart),
            );
      final repairingRows = projection?.isReady == true
          ? projection!.rows
                .where(
                  (row) => row.status == AnchorageRepairShipStatus.repairing,
                )
                .toList(growable: false)
          : const <AnchorageRepairShipProjection>[];
      if (ancStart != null && repairingRows.isNotEmpty) {
        final fleet1 = state.fleets.cast<Fleet?>().firstWhere(
          (f) => f?.id == 1,
          orElse: () => null,
        );
        final fleet1Name = fleet1?.displayName ?? '第1舰队';
        final elapsed = now.difference(ancStart);
        final includesMilestone =
            settings.anchorageMode == AnchorageNotificationMode.twentyMinutes ||
            settings.anchorageMode == AnchorageNotificationMode.both;
        final includesAllRepaired =
            settings.anchorageMode == AnchorageNotificationMode.allRepaired ||
            settings.anchorageMode == AnchorageNotificationMode.both;
        var remaining = const Duration(minutes: 20) - elapsed;
        var totalSeconds = const Duration(minutes: 20).inSeconds;
        var completed = false;
        if (includesAllRepaired) {
          remaining = Duration.zero;
          for (final row in repairingRows) {
            if (row.remaining != null && row.remaining! > remaining) {
              remaining = row.remaining!;
            }
          }
          completed = remaining <= Duration.zero;
          totalSeconds = (elapsed + remaining).inSeconds;
        }
        if (remaining < Duration.zero) remaining = Duration.zero;
        final taskState = completed
            ? OngoingTaskState.completed
            : includesMilestone &&
                  elapsed >= AnchorageRepairCalculator.minimumRepairTime
            ? OngoingTaskState.settlementReady
            : OngoingTaskState.running;
        final safeTotalSeconds = totalSeconds > 0 ? totalSeconds : 1;
        final progress = completed
            ? 1.0
            : (elapsed.inSeconds / safeTotalSeconds).clamp(0.0, 1.0);
        items.add(
          OngoingTaskItem(
            id: 'anchorage:1',
            type: GameNotificationType.anchorage,
            title: '⚓ 泊地 ($fleet1Name)',
            state: taskState,
            clockMode: OngoingClockMode.elapsed,
            anchorEpochMs: ancStart.millisecondsSinceEpoch,
            progress: progress,
            remainingSeconds: remaining.inSeconds,
            targetEpochMs: ancStart
                .add(Duration(seconds: safeTotalSeconds))
                .millisecondsSinceEpoch,
            totalDurationSec: safeTotalSeconds,
          ),
        );
      }
    }

    // 4. Construction Docks
    if (settings.construction) {
      for (final dock in state.constructionDocks) {
        if (dock.isBuilding && dock.completionTime != null) {
          String shipName = '舰娘';
          final masterId = dock.createdShipMasterId;
          final master = masterId > 0 ? state.masterShips[masterId] : null;
          if (master != null && master.name.isNotEmpty) {
            shipName = master.name;
          }
          int totalSec = 3600;
          if (dock.startedAt != null) {
            final diff = dock.completionTime!
                .difference(dock.startedAt!)
                .inSeconds;
            if (diff > 0) totalSec = diff;
          } else if (master != null && master.buildTimeMinutes > 0) {
            totalSec = master.buildTimeMinutes * 60;
          }
          final title = dock.isCompletedAt(now)
              ? '🔨 建造 船坞 #${dock.id} · $shipName 建造完成'
              : '🔨 建造 船坞 #${dock.id} · $shipName';
          items.add(
            _deadlineItem(
              id: 'construction:${dock.id}',
              type: GameNotificationType.construction,
              title: title,
              deadline: dock.completionTime!,
              totalSeconds: totalSec,
              now: now,
            ),
          );
        }
      }
    }

    // 5. Morale
    if (settings.morale) {
      for (final fleet in state.fleets) {
        if (fleet.shipIds.isEmpty) continue;
        final fleetName = fleet.displayName;
        final nosakiStart = _nosakiStartFor(state);
        final nosakiElapsed = nosakiStart != null
            ? now.difference(nosakiStart)
            : Duration.zero;
        final nosakiProjection = NosakiSparkleCalculator.project(
          state: state,
          fleetId: fleet.id,
          elapsed: nosakiElapsed,
        );

        if (nosakiProjection.isReady &&
            nosakiProjection.rows.isNotEmpty &&
            nosakiProjection.eligibleShipCount > 0) {
          Duration maxTimeTo54 = Duration.zero;
          for (final row in nosakiProjection.rows) {
            if (row.estimatedTimeTo54 != null &&
                row.estimatedTimeTo54! > maxTimeTo54) {
              maxTimeTo54 = row.estimatedTimeTo54!;
            }
          }
          if (maxTimeTo54 > Duration.zero) {
            final remainingSec = maxTimeTo54.inSeconds;
            var totalCond = 0;
            var shipCount = 0;
            for (final row in nosakiProjection.rows) {
              totalCond += row.currentCond;
              shipCount++;
            }
            final progress = shipCount > 0
                ? (totalCond / (shipCount * 54.0)).clamp(0.0, 1.0)
                : 1.0;
            items.add(
              OngoingTaskItem(
                id: 'morale:${fleet.id}',
                type: GameNotificationType.morale,
                title: '✨ 野崎刷闪 $fleetName (→ 54闪)',
                progress: progress,
                remainingSeconds: remainingSec,
                targetEpochMs: now.add(maxTimeTo54).millisecondsSinceEpoch,
                totalDurationSec: remainingSec,
              ),
            );
          }
        } else {
          int minCond = 100;
          for (final shipId in fleet.shipIds) {
            final ship = state.ships[shipId];
            if (ship != null && ship.condition < minCond) {
              minCond = ship.condition;
            }
          }
          if (minCond < 49) {
            final neededTicks = ((49 - minCond) / 3).ceil();
            final totalDurationSec = neededTicks * 180;
            final target = _normalMoraleTarget(
              fleet: fleet,
              state: state,
              now: now,
              minCond: minCond,
            );
            items.add(
              _deadlineItem(
                id: 'morale:${fleet.id}',
                type: GameNotificationType.morale,
                title: '✨ 疲劳 $fleetName (Cond $minCond/49)',
                deadline: target,
                totalSeconds: totalDurationSec,
                now: now,
              ),
            );
          }
        }
      }
    }

    for (final tombstone in _completedTombstones.values) {
      final enabled = switch (tombstone.type) {
        GameNotificationType.repair => settings.repair,
        GameNotificationType.construction => settings.construction,
        _ => true,
      };
      if (enabled && items.every((item) => item.id != tombstone.id)) {
        items.add(tombstone);
      }
    }

    return items;
  }

  OngoingTaskItem _deadlineItem({
    required String id,
    required GameNotificationType type,
    required String title,
    required DateTime deadline,
    required int totalSeconds,
    required DateTime now,
  }) {
    final completed = !deadline.isAfter(now);
    final safeTotalSeconds = totalSeconds > 0 ? totalSeconds : 1;
    final remainingSeconds = completed ? 0 : deadline.difference(now).inSeconds;
    return OngoingTaskItem(
      id: id,
      type: type,
      title: title,
      state: completed ? OngoingTaskState.completed : OngoingTaskState.running,
      progress: completed
          ? 1
          : (1 - remainingSeconds / safeTotalSeconds).clamp(0.0, 1.0),
      remainingSeconds: remainingSeconds,
      targetEpochMs: deadline.millisecondsSinceEpoch,
      totalDurationSec: safeTotalSeconds,
    );
  }

  DateTime? _anchorageStartFor(GameState state) {
    final liveAnchor = _anchorageStartedAt();
    if (liveAnchor != null) return liveAnchor;
    final signature = NotificationTimerSignature.anchorage(state);
    final persisted = _timerAnchors.akashi;
    if (signature == null || persisted?.signature != signature) return null;
    return persisted!.anchorAt;
  }

  DateTime? _nosakiStartFor(GameState state) {
    final liveAnchor = _nosakiStartedAt();
    if (liveAnchor != null) return liveAnchor;
    final persisted = _timerAnchors.nozaki;
    final signature = NotificationTimerSignature.nozaki(state);
    return persisted?.signature == signature ? persisted!.anchorAt : null;
  }

  DateTime _normalMoraleTarget({
    required Fleet fleet,
    required GameState state,
    required DateTime now,
    required int minCond,
  }) {
    final signature = NotificationTimerSignature.morale(fleet);
    final existing = _timerAnchors.moraleByFleet[fleet.id];
    if (existing != null &&
        existing.fleetSignature == signature &&
        existing.observedCondition == minCond) {
      return existing.targetAt;
    }

    final observedAt = (state.updatedAt ?? now).toUtc();
    final neededTicks = ((49 - minCond) / 3).ceil();
    final anchor = MoraleNotificationTimerAnchor(
      fleetSignature: signature,
      observedAt: observedAt,
      observedCondition: minCond,
      targetAt: observedAt.add(Duration(minutes: neededTicks * 3)),
    );
    _replaceTimerAnchors(
      _timerAnchors.copyWith(
        moraleByFleet: {..._timerAnchors.moraleByFleet, fleet.id: anchor},
      ),
    );
    return anchor.targetAt;
  }

  void _restoreGlobalTimerAnchors(GameState state) {
    final akashi = _timerAnchors.akashi;
    if (gameStateController.akashiTimer.anchorAt == null &&
        akashi != null &&
        akashi.signature == NotificationTimerSignature.anchorage(state)) {
      gameStateController.akashiTimer.restore(akashi.anchorAt);
    }
    final nozaki = _timerAnchors.nozaki;
    if (gameStateController.nozakiTimer.anchorAt == null &&
        nozaki != null &&
        nozaki.signature == NotificationTimerSignature.nozaki(state)) {
      gameStateController.nozakiTimer.restore(nozaki.anchorAt);
    }
  }

  void _recordGlobalTimerAnchors(GameState state) {
    final liveAkashi = _anchorageStartedAt();
    final akashiSignature = NotificationTimerSignature.anchorage(state);
    final liveNozaki = _nosakiStartedAt();
    final recordedAkashi = liveAkashi != null && akashiSignature != null
        ? GlobalNotificationTimerAnchor(
            anchorAt: liveAkashi,
            signature: akashiSignature,
          )
        : _timerAnchors.akashi?.signature == akashiSignature
        ? _timerAnchors.akashi
        : null;
    final nozakiSignature = NotificationTimerSignature.nozaki(state);
    final recordedNozaki = liveNozaki != null
        ? GlobalNotificationTimerAnchor(
            anchorAt: liveNozaki,
            signature: nozakiSignature,
          )
        : _timerAnchors.nozaki?.signature == nozakiSignature
        ? _timerAnchors.nozaki
        : null;
    final next = _timerAnchors.copyWith(
      akashi: recordedAkashi,
      clearAkashi: recordedAkashi == null,
      nozaki: recordedNozaki,
      clearNozaki: recordedNozaki == null,
    );
    _replaceTimerAnchors(next);
  }

  void _replaceTimerAnchors(NotificationTimerAnchors next) {
    if (next == _timerAnchors) return;
    _timerAnchors = next;
    final store = _timerAnchorStore;
    if (store == null) return;
    _timerAnchorSaveQueue = _timerAnchorSaveQueue
        .then((_) => store.save(next))
        .catchError((Object error, StackTrace stackTrace) {
          _onError(error, stackTrace);
        });
  }
}

class _ManualCompletionTask {
  const _ManualCompletionTask({
    required this.id,
    required this.dockId,
    required this.type,
    required this.deadline,
    required this.title,
    required this.body,
    required this.ongoingTitle,
    required this.totalSeconds,
  });

  final String id;
  final int dockId;
  final GameNotificationType type;
  final DateTime deadline;
  final String title;
  final String body;
  final String ongoingTitle;
  final int totalSeconds;
}
