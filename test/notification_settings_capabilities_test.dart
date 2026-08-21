import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/notification/notification_models.dart';
import 'package:yahagi_kancolle_browser/src/notification/notification_port.dart';
import 'package:yahagi_kancolle_browser/src/settings/notification_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/notification_settings_page.dart';

class _CapabilityPort implements NotificationPort {
  @override
  Future<NotificationApplyResult> applySnapshot(NotificationSnapshot snapshot) {
    throw UnimplementedError();
  }

  @override
  Future<NotificationPlatformCapabilities> getCapabilities() async {
    return const NotificationPlatformCapabilities(
      notificationsGranted: false,
      exactAlarmsGranted: false,
      channelsEnabled: true,
    );
  }

  @override
  Future<void> openSystemNotificationSettings() async {}

  @override
  Future<void> requestExactAlarmPermission() async {}

  @override
  Future<bool> requestNotificationPermission() async => false;
}

void main() {
  testWidgets('shows native notification and exact alarm capability status', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final controller = NotificationSettingsController();
    await controller.initialize();

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: NotificationSettingsPage(
          controller: controller,
          notificationPort: _CapabilityPort(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('通知权限未授予'), findsOneWidget);
    expect(find.text('精确提醒未授权，将使用省电兼容模式'), findsOneWidget);
    expect(find.text('通知渠道可用'), findsOneWidget);
  });
}
