import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/notification/notification_models.dart';
import 'package:yahagi_kancolle_browser/src/notification/notification_port.dart';
import 'package:yahagi_kancolle_browser/src/settings/notification_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/notification_settings_page.dart';
import 'package:yahagi_kancolle_browser/src/settings/notification_settings_store.dart';

class _NotificationPortStub implements NotificationPort {
  @override
  Future<NotificationApplyResult> applySnapshot(NotificationSnapshot snapshot) {
    throw UnimplementedError();
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

void main() {
  testWidgets('notification type choices use aligned menus before switches', (
    tester,
  ) async {
    final controller = NotificationSettingsController(
      initialSettings: const NotificationSettings(),
    );
    await _pumpPage(tester, controller);

    expect(find.byType(SegmentedButton<int>), findsNothing);
    expect(
      find.byType(SegmentedButton<AnchorageNotificationMode>),
      findsNothing,
    );

    const menuKeys = <Key>[
      Key('notification-expedition-menu'),
      Key('notification-repair-menu'),
      Key('notification-anchorage-menu'),
    ];
    const switchKeys = <Key>[
      Key('notification-expedition-switch'),
      Key('notification-repair-switch'),
      Key('notification-anchorage-switch'),
    ];
    for (var index = 0; index < menuKeys.length; index++) {
      final menu = find.byKey(menuKeys[index]);
      final toggle = find.byKey(switchKeys[index]);
      expect(menu, findsOneWidget);
      expect(toggle, findsOneWidget);
      expect(
        tester.getTopLeft(menu).dx,
        lessThan(tester.getTopLeft(toggle).dx),
      );
      expect(
        tester.getCenter(menu).dy,
        closeTo(tester.getCenter(toggle).dy, 1),
      );
    }

    final menuWidths = menuKeys
        .map((key) => tester.getSize(find.byKey(key)).width)
        .toSet();
    expect(menuWidths, hasLength(1));
  });

  testWidgets('expedition menu updates the selected preempt time', (
    tester,
  ) async {
    final controller = NotificationSettingsController(
      initialSettings: const NotificationSettings(),
    );
    await _pumpPage(tester, controller);

    final menu = find.byKey(const Key('notification-expedition-menu'));
    await tester.ensureVisible(menu);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('提前 30 秒').last);
    await tester.pumpAndSettle();

    expect(controller.settings.expeditionPreemptSeconds, 30);
  });

  test(
    'notification setting labels contain no English annotations or units',
    () {
      final zh = lookupAppLocalizations(const Locale('zh'));
      final zhHant = lookupAppLocalizations(
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      );
      final ja = lookupAppLocalizations(const Locale('ja'));

      expect(zh.notificationSectionOngoing, '后台常驻进行中进度');
      expect(zh.notificationSectionTypes, '业务通知分类与提醒时机');
      expect(zh.notificationExpedition, '远征归还');
      expect(zh.notificationRepair, '入渠修复');
      expect(zh.notificationAnchorage, '泊地修理');
      expect(zh.notificationConstruction, '工厂建造');
      expect(zh.notificationMorale, '士气 / 疲劳与刷闪');
      expect(zh.notificationPunctual, '准点');
      expect(zh.notificationPreempt30s, '提前 30 秒');
      expect(zh.notificationPreempt60s, '提前 60 秒');
      expect(zh.notificationPreempt120s, '提前 2 分钟');
      expect(zh.notificationRepairPunctual, '准点');
      expect(zh.notificationAnchorage20m, '满 20 分钟首轮');

      expect(zhHant.notificationSectionOngoing, '後台常駐進行中進度');
      expect(zhHant.notificationSectionTypes, '業務通知分類與提醒時機');
      expect(zhHant.notificationPreempt60s, '提前 60 秒');
      expect(zhHant.notificationPreempt120s, '提前 2 分鐘');
      expect(zhHant.notificationAnchorage20m, '滿 20 分鐘首輪');

      expect(ja.notificationSectionOngoing, 'バックグラウンド進行中常駐');
      expect(ja.notificationSectionTypes, '通知種別とタイミング');
      expect(ja.notificationExpedition, '遠征帰還');
      expect(ja.notificationRepair, '入渠修復');
      expect(ja.notificationAnchorage, '泊地修理');
      expect(ja.notificationConstruction, '工廠建造');
      expect(ja.notificationMorale, '士気 / 疲労とキラ付け');
      expect(ja.notificationPunctual, '定刻');
      expect(ja.notificationRepairPunctual, '定刻');
    },
  );
}

Future<void> _pumpPage(
  WidgetTester tester,
  NotificationSettingsController controller,
) async {
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: NotificationSettingsPage(
        controller: controller,
        notificationPort: _NotificationPortStub(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
