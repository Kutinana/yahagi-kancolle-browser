import 'notification_models.dart';

abstract interface class NotificationPort {
  Future<NotificationApplyResult> applySnapshot(NotificationSnapshot snapshot);
  Future<NotificationPlatformCapabilities> getCapabilities();
  Future<bool> requestNotificationPermission();
  Future<void> requestExactAlarmPermission();
  Future<void> openSystemNotificationSettings();

  // Legacy operations retained until the coordinator migration is complete.
  Future<void> scheduleAlarm(ScheduledNotificationItem item);
  Future<void> cancelAlarm(String key);
  Future<void> cancelAllAlarms();
  Future<void> updateOngoingProgress(OngoingProgressSummary summary);
  Future<void> cancelOngoingProgress();
  Future<bool> requestPermission();
}
