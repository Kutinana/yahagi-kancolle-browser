import 'dart:async';
import 'package:flutter/foundation.dart';
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
  })  : _gameStateProvider = gameStateProvider ?? (() => gameStateController.state),
        _now = nowProvider ?? DateTime.now,
        _anchorageStartedAt = anchorageRepairStartedAtProvider ??
            (() => gameStateController.anchorageRepairStartedAt),
        _nosakiStartedAt = nosakiSparkleStartedAtProvider ??
            (() => gameStateController.nosakiSparkleStartedAt);

  final GameStateController gameStateController;
  final NotificationSettingsController settingsController;
  final NotificationPort notificationPort;
  final GameState Function() _gameStateProvider;
  final DateTime Function() _now;
  final DateTime? Function() _anchorageStartedAt;
  final DateTime? Function() _nosakiStartedAt;

  final Set<String> _activeAlarmKeys = <String>{};
  Timer? _ongoingRefreshTimer;
  bool _disposed = false;

  void start() {
    gameStateController.addListener(_onStateOrSettingsChanged);
    settingsController.addListener(_onStateOrSettingsChanged);
    _onStateOrSettingsChanged();

    _ongoingRefreshTimer?.cancel();
    _ongoingRefreshTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _refreshOngoingProgress(),
    );
  }

  void dispose() {
    _disposed = true;
    _ongoingRefreshTimer?.cancel();
    gameStateController.removeListener(_onStateOrSettingsChanged);
    settingsController.removeListener(_onStateOrSettingsChanged);
  }

  void _onStateOrSettingsChanged() {
    if (_disposed) return;
    final settings = settingsController.settings;
    if (!settings.master) {
      _cancelAll();
      return;
    }
    _syncScheduledAlarms();
    _refreshOngoingProgress();
  }

  void _cancelAll() {
    _activeAlarmKeys.clear();
    unawaited(notificationPort.cancelAllAlarms());
    unawaited(notificationPort.cancelOngoingProgress());
  }

  void _syncScheduledAlarms() {
    final settings = settingsController.settings;
    if (!settings.master) return;

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
                type: GameNotificationType.expedition,
                triggerTime: preemptTime,
                title: '远征即将归还 · $fleetName',
                body: '$missionName 还有 ${settings.expeditionPreemptSeconds} 秒返回母港，请做好迎接准备。',
              );
            }
          }

          // Complete alarm
          final key = 'expedition_${fleet.id}_complete';
          desiredAlarms[key] = ScheduledNotificationItem(
            key: key,
            type: GameNotificationType.expedition,
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
          final masterShip = ship != null ? state.masterShips[ship.masterId] : null;
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
                type: GameNotificationType.repair,
                triggerTime: preemptTime,
                title: '修复即将完成 · 船坞 #${dock.id}',
                body: '$shipName 还有 ${settings.repairPreemptSeconds} 秒修理完毕。',
              );
            }
          }

          final key = 'repair_${dock.id}_complete';
          desiredAlarms[key] = ScheduledNotificationItem(
            key: key,
            type: GameNotificationType.repair,
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
            type: GameNotificationType.construction,
            triggerTime: compTime,
            title: '建造完成 · 船坞 #${dock.id}',
            body: '$shipName 已在船坞建造完成！',
          );
        }
      }
    }

    // 4. Anchorage Repair
    if (settings.anchorage) {
      final ancStart = _anchorageStartedAt();
      if (ancStart != null) {
        final twentyMinTime = ancStart.add(const Duration(minutes: 20));
        if (twentyMinTime.isAfter(now) &&
            (settings.anchorageMode == AnchorageNotificationMode.twentyMinutes ||
                settings.anchorageMode == AnchorageNotificationMode.both)) {
          const key = 'anchorage_1_20m';
          desiredAlarms[key] = ScheduledNotificationItem(
            key: key,
            type: GameNotificationType.anchorage,
            triggerTime: twentyMinTime,
            title: '泊地修理结算就绪 · 第1舰队',
            body: '明石泊地修理已满 20 分钟！可返回母港刷新以结算首轮回血。',
          );
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
              type: GameNotificationType.morale,
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
            final completeTime = now.add(neededDuration);
            final key = 'morale_${fleet.id}_normal';
            desiredAlarms[key] = ScheduledNotificationItem(
              key: key,
              type: GameNotificationType.morale,
              triggerTime: completeTime,
              title: '疲劳恢复完毕 · $fleetName',
              body: '$fleetName 全队舰船士气已恢复至 49。',
            );
          }
        }
      }
    }

    // Cancel alarms that are no longer present
    final keysToRemove = _activeAlarmKeys.difference(desiredAlarms.keys.toSet());
    for (final key in keysToRemove) {
      unawaited(notificationPort.cancelAlarm(key));
    }
    _activeAlarmKeys.removeAll(keysToRemove);

    // Schedule new / updated alarms
    for (final entry in desiredAlarms.entries) {
      _activeAlarmKeys.add(entry.key);
      unawaited(notificationPort.scheduleAlarm(entry.value));
    }
  }

  void _refreshOngoingProgress() {
    if (_disposed) return;
    final settings = settingsController.settings;
    if (!settings.master || !settings.ongoingLive) {
      unawaited(notificationPort.cancelOngoingProgress());
      return;
    }

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
          final totalSec = masterMission != null &&
                  masterMission.duration.inSeconds > 0
              ? masterMission.duration.inSeconds
              : 1800;
          final remainingSec = mission.completionTime!.difference(now).inSeconds;
          final progress = (1.0 - (remainingSec / totalSec)).clamp(0.0, 1.0);
          final formattedMission = masterMission?.name.isNotEmpty == true
              ? '远征 ${mission.missionId} · ${masterMission!.name}'
              : (mission.missionId > 0 ? '远征 ${mission.missionId}' : '远征');
          items.add(
            OngoingTaskItem(
              id: 'exp_${fleet.id}',
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
          final masterShip =
              ship != null ? state.masterShips[ship.masterId] : null;
          final shipName = masterShip?.name.isNotEmpty == true
              ? masterShip!.name
              : '舰船';
          items.add(
            OngoingTaskItem(
              id: 'repair_${dock.id}',
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
      final ancStart = _anchorageStartedAt();
      if (ancStart != null) {
        final twentyMinTime = ancStart.add(const Duration(minutes: 20));
        if (twentyMinTime.isAfter(now)) {
          final remainingSec = twentyMinTime.difference(now).inSeconds;
          final progress = (1.0 - (remainingSec / 1200)).clamp(0.0, 1.0);
          items.add(
            OngoingTaskItem(
              id: 'anc_1',
              type: GameNotificationType.anchorage,
              title: '⚓ 泊地修理 · 明石 (第1舰队)',
              progress: progress,
              remainingSeconds: remainingSec,
              targetEpochMs: twentyMinTime.millisecondsSinceEpoch,
              totalDurationSec: 1200,
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
            final diff = dock.completionTime!.difference(dock.startedAt!).inSeconds;
            if (diff > 0) totalSec = diff;
          } else if (master != null && master.buildTimeMinutes > 0) {
            totalSec = master.buildTimeMinutes * 60;
          }
          final progress = totalSec > 0
              ? (1.0 - (remainingSec / totalSec)).clamp(0.0, 1.0)
              : 1.0;
          items.add(
            OngoingTaskItem(
              id: 'build_${dock.id}',
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
                id: 'morale_${fleet.id}',
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
            final remainingSec = neededTicks * 180;
            final progress = (minCond / 49.0).clamp(0.0, 1.0);
            items.add(
              OngoingTaskItem(
                id: 'morale_${fleet.id}',
                type: GameNotificationType.morale,
                title: '✨ 第${fleet.id}舰队 · 疲劳恢复 (Cond $minCond/49)',
                progress: progress,
                remainingSeconds: remainingSec,
                targetEpochMs: now.add(Duration(seconds: remainingSec)).millisecondsSinceEpoch,
                totalDurationSec: remainingSec,
              ),
            );
          }
        }
      }
    }

    if (items.isEmpty) {
      unawaited(notificationPort.cancelOngoingProgress());
    } else {
      unawaited(
        notificationPort.updateOngoingProgress(
          OngoingProgressSummary(
            items: items,
            showProgress: settings.showProgress,
            showPercent: settings.showPercent,
            showCountdown: settings.showCountdown,
          ),
        ),
      );
    }
  }
}
