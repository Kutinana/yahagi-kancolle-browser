import 'notification_models.dart';

abstract interface class NotificationPort {
  Future<NotificationApplyResult> applySnapshot(NotificationSnapshot snapshot);
  Future<NotificationPlatformCapabilities> getCapabilities();
  Future<bool> requestNotificationPermission();
  Future<void> requestExactAlarmPermission();
  Future<void> openSystemNotificationSettings();
}
