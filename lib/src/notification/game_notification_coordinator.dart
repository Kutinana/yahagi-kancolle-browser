import 'dart:async';
import 'package:flutter/foundation.dart';
import '../fleet/anchorage_repair_calculator.dart';
import '../fleet/nosaki_sparkle_calculator.dart';
import '../game_state/game_state.dart';
import '../game_state/game_state_controller.dart';
import '../settings/notification_settings_controller.dart';
import '../settings/notification_settings_store.dart';
import 'notification_models.dart';
import 'notification_port.dart';

class GameNotificationCoordinator {
  GameNotificationCoordinator({
    required this.gameStateController,
    required this.settingsController,
    required this.notificationPort,
    GameState Function()? gameStateProvider,
    DateTime Function()? nowProvider,
    DateTime? Function()? anchorageRepairStartedAtProvider,
    DateTime? Function()? nosakiSparkleStartedAtProvider,
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
       _onError = onError ?? _reportFlutterError;

  final GameStateController gameStateController;
  final NotificationSettingsController settingsController;
  final NotificationPort notificationPort;
  final GameState Function() _gameStateProvider;
  final DateTime Function() _now;
  final DateTime? Function() _anchorageStartedAt;
  final DateTime? Function() _nosakiStartedAt;
  final void Function(Object error, StackTrace stackTrace) _onError;

  bool _disposed = false;

  void start() {
    gameStateController.addListener(_onStateOrSettingsChanged);
    settingsController.addListener(_onStateOrSettingsChanged);
    _onStateOrSettingsChanged();
  }

  void dispose() {
    _disposed = true;
    gameStateController.removeListener(_onStateOrSettingsChanged);
    settingsController.removeListener(_onStateOrSettingsChanged);
  }

  void _onStateOrSettingsChanged() {
    if (_disposed) return;
    final settings = settingsController.settings;
    final snapshot = NotificationSnapshot(
      updatedAt: _now(),
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
    unawaited(_applySnapshot(snapshot));
  }

  Future<void> _applySnapshot(NotificationSnapshot snapshot) async {
    try {
      final result = await notificationPort.applySnapshot(snapshot);
      if (result.failures.isNotEmpty) {
        _onError(
          StateError(
            'Native notification failures: ${result.failures.join(', ')}',
          ),
          StackTrace.current,
        );
      }
    } catch (error, stackTrace) {
      _onError(error, stackTrace);
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
          final fleetName = '第${fleet.id}舰队';
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
            title: '泊地修理结算就绪 · 第1舰队',
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
              title: 'Anchorage repair complete · Fleet 1',
              body: 'All eligible ships in Fleet 1 should now be repaired.',
            );
          }
        }
      }
    }

    // 5. Morale & Nosaki Sparkle
    if (settings.morale) {
      for (final fleet in state.fleets) {
        if (fleet.shipIds.isEmpty) continue;
        final fleetName = '第${fleet.id}舰队';

        // Check if Nosaki sparkle mode is active for this fleet
        final nosakiElapsed = _nosakiStartedAt() != null
            ? now.difference(_nosakiStartedAt()!)
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
            final neededTicks = ((49 - minCond) / 3).ceil();
            final neededDuration = Duration(minutes: neededTicks * 3);
            final completeTime = (state.updatedAt ?? now).add(neededDuration);
            if (!completeTime.isAfter(now)) continue;
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
        if (mission.isActive &&
            mission.completionTime != null &&
            mission.completionTime!.isAfter(now)) {
          final masterMission = state.masterMissions[mission.missionId];
          final totalSec =
              masterMission != null && masterMission.duration.inSeconds > 0
              ? masterMission.duration.inSeconds
              : 1800;
          final remainingSec = mission.completionTime!
              .difference(now)
              .inSeconds;
          final progress = (1.0 - (remainingSec / totalSec)).clamp(0.0, 1.0);
          final formattedMission = masterMission?.name.isNotEmpty == true
              ? '远征 ${mission.missionId} · ${masterMission!.name}'
              : (mission.missionId > 0 ? '远征 ${mission.missionId}' : '远征');
          items.add(
            OngoingTaskItem(
              id: 'expedition:${fleet.id}',
              type: GameNotificationType.expedition,
              title: '⚓ 第${fleet.id}舰队 · $formattedMission',
              progress: progress,
              remainingSeconds: remainingSec,
              targetEpochMs: mission.completionTime!.millisecondsSinceEpoch,
              totalDurationSec: totalSec,
            ),
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
          final remainingSec = dock.completionTime!.difference(now).inSeconds;
          final ship = state.ships[dock.shipId];
          final totalSec = ship != null && ship.repairDurationMilliseconds > 0
              ? (ship.repairDurationMilliseconds / 1000).round()
              : (remainingSec > 0 ? remainingSec : 1);
          final progress = totalSec > 0
              ? (1.0 - (remainingSec / totalSec)).clamp(0.0, 1.0)
              : 1.0;
          final masterShip = ship != null
              ? state.masterShips[ship.masterId]
              : null;
          final shipName = masterShip?.name.isNotEmpty == true
              ? masterShip!.name
              : '舰船';
          items.add(
            OngoingTaskItem(
              id: 'repair:${dock.id}',
              type: GameNotificationType.repair,
              title: '🔧 船坞 #${dock.id} · $shipName',
              progress: progress,
              remainingSeconds: remainingSec,
              targetEpochMs: dock.completionTime!.millisecondsSinceEpoch,
              totalDurationSec: totalSec,
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
        final twentyMinTime = ancStart.add(const Duration(minutes: 20));
        var target = twentyMinTime;
        var totalSeconds = 1200;
        if (settings.anchorageMode != AnchorageNotificationMode.twentyMinutes) {
          var remaining = Duration.zero;
          for (final row in repairingRows) {
            if (row.remaining != null && row.remaining! > remaining) {
              remaining = row.remaining!;
            }
          }
          if (remaining > Duration.zero) {
            target = now.add(remaining);
            totalSeconds = target.difference(ancStart).inSeconds;
          }
        }
        if (target.isAfter(now)) {
          final remainingSec = target.difference(now).inSeconds;
          final progress = totalSeconds > 0
              ? (1.0 - (remainingSec / totalSeconds)).clamp(0.0, 1.0)
              : 0.0;
          items.add(
            OngoingTaskItem(
              id: 'anchorage:1',
              type: GameNotificationType.anchorage,
              title: '⚓ 泊地修理 · 明石 (第1舰队)',
              progress: progress,
              remainingSeconds: remainingSec,
              targetEpochMs: target.millisecondsSinceEpoch,
              totalDurationSec: totalSeconds,
            ),
          );
        }
      }
    }

    // 4. Construction Docks
    if (settings.construction) {
      for (final dock in state.constructionDocks) {
        if (dock.isBuilding &&
            !dock.isCompletedAt(now) &&
            dock.completionTime != null &&
            dock.completionTime!.isAfter(now)) {
          final remainingSec = dock.completionTime!.difference(now).inSeconds;
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
          final progress = totalSec > 0
              ? (1.0 - (remainingSec / totalSec)).clamp(0.0, 1.0)
              : 1.0;
          items.add(
            OngoingTaskItem(
              id: 'construction:${dock.id}',
              type: GameNotificationType.construction,
              title: '🔨 船坞 #${dock.id} · $shipName 建造中',
              progress: progress,
              remainingSeconds: remainingSec,
              targetEpochMs: dock.completionTime!.millisecondsSinceEpoch,
              totalDurationSec: totalSec,
            ),
          );
        }
      }
    }

    // 5. Morale
    if (settings.morale) {
      for (final fleet in state.fleets) {
        if (fleet.shipIds.isEmpty) continue;
        final nosakiElapsed = _nosakiStartedAt() != null
            ? now.difference(_nosakiStartedAt()!)
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
                title: '✨ 第${fleet.id}舰队 · 野崎刷闪 (→ 54闪)',
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
            final target = (state.updatedAt ?? now).add(
              Duration(seconds: totalDurationSec),
            );
            final remainingSec = target.difference(now).inSeconds;
            if (remainingSec <= 0) continue;
            final progress = (minCond / 49.0).clamp(0.0, 1.0);
            items.add(
              OngoingTaskItem(
                id: 'morale:${fleet.id}',
                type: GameNotificationType.morale,
                title: '✨ 第${fleet.id}舰队 · 疲劳恢复 (Cond $minCond/49)',
                progress: progress,
                remainingSeconds: remainingSec,
                targetEpochMs: target.millisecondsSinceEpoch,
                totalDurationSec: totalDurationSec,
              ),
            );
          }
        }
      }
    }

    return items;
  }

  DateTime? _anchorageStartFor(GameState state) {
    final liveAnchor = _anchorageStartedAt();
    if (liveAnchor != null) return liveAnchor;
    if (!AnchorageRepairCalculator.hasReadyFleet(state)) return null;
    return state.updatedAt;
  }
}
