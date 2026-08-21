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
