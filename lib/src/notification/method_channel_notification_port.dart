import 'package:flutter/services.dart';
import 'notification_models.dart';
import 'notification_port.dart';

final class MethodChannelNotificationPort implements NotificationPort {
  const MethodChannelNotificationPort([
    this._channel = const MethodChannel(
      'app.yahagi.kancollebrowser/notification',
    ),
  ]);

  final MethodChannel _channel;

  @override
  Future<NotificationApplyResult> applySnapshot(
    NotificationSnapshot snapshot,
  ) async {
    final result = await _channel.invokeMapMethod<Object?, Object?>(
      'applySnapshot',
      snapshot.toMap(),
    );
    if (result == null) {
      throw const FormatException('applySnapshot returned no result');
    }
    return NotificationApplyResult.fromMap(result);
  }

  @override
  Future<NotificationPlatformCapabilities> getCapabilities() async {
    final result = await _channel.invokeMapMethod<Object?, Object?>(
      'getCapabilities',
    );
    if (result == null) {
      throw const FormatException('getCapabilities returned no result');
    }
    return NotificationPlatformCapabilities.fromMap(result);
  }

  @override
  Future<bool> requestNotificationPermission() async {
    return await _channel.invokeMethod<bool>('requestNotificationPermission') ??
        false;
  }

  @override
  Future<void> requestExactAlarmPermission() {
    return _channel.invokeMethod<void>('requestExactAlarmPermission');
  }

  @override
  Future<void> openSystemNotificationSettings() {
    return _channel.invokeMethod<void>('openSystemNotificationSettings');
  }

  @override
  Future<void> scheduleAlarm(ScheduledNotificationItem item) async {
    try {
      await _channel.invokeMethod<void>('scheduleAlarm', item.toMap());
    } catch (_) {}
  }

  @override
  Future<void> cancelAlarm(String key) async {
    try {
      await _channel.invokeMethod<void>('cancelAlarm', <String, Object?>{
        'key': key,
      });
    } catch (_) {}
  }

  @override
  Future<void> cancelAllAlarms() async {
    try {
      await _channel.invokeMethod<void>('cancelAllAlarms');
    } catch (_) {}
  }

  @override
  Future<void> updateOngoingProgress(OngoingProgressSummary summary) async {
    try {
      await _channel.invokeMethod<void>(
        'updateOngoingProgress',
        summary.toMap(),
      );
    } catch (_) {}
  }

  @override
  Future<void> cancelOngoingProgress() async {
    try {
      await _channel.invokeMethod<void>('cancelOngoingProgress');
    } catch (_) {}
  }

  @override
  Future<bool> requestPermission() async {
    try {
      final granted = await _channel.invokeMethod<bool>('requestPermission');
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }
}
