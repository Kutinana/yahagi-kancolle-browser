import 'notification_models.dart';

abstract interface class NotificationPort {
  Future<void> scheduleAlarm(ScheduledNotificationItem item);
  Future<void> cancelAlarm(String key);
  Future<void> cancelAllAlarms();
  Future<void> updateOngoingProgress(OngoingProgressSummary summary);
  Future<void> cancelOngoingProgress();
  Future<bool> requestPermission();
}
