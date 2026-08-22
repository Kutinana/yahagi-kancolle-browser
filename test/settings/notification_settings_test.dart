import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/src/settings/notification_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/notification_settings_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationSettings', () {
    test('default values are true and aligned with defaults', () {
      const settings = NotificationSettings();
      expect(settings.master, isTrue);
      expect(settings.sound, isTrue);
      expect(settings.vibration, isTrue);
      expect(settings.ongoingLive, isTrue);
      expect(settings.showProgress, isTrue);
      expect(settings.showPercent, isTrue);
      expect(settings.showCountdown, isTrue);
      expect(settings.expedition, isTrue);
      expect(settings.expeditionPreemptSeconds, 60);
      expect(settings.repair, isTrue);
      expect(settings.repairPreemptSeconds, 0);
      expect(settings.anchorage, isTrue);
      expect(
        settings.anchorageMode,
        AnchorageNotificationMode.twentyMinutes,
      );
      expect(settings.construction, isTrue);
      expect(settings.constructionPreemptSeconds, 0);
      expect(settings.morale, isTrue);
      expect(settings.moralePreemptSeconds, 0);
    });

    test('copyWith updates specific fields correctly', () {
      const settings = NotificationSettings();
      final updated = settings.copyWith(
        master: false,
        expeditionPreemptSeconds: 30,
        constructionPreemptSeconds: 60,
        moralePreemptSeconds: 30,
        anchorageMode: AnchorageNotificationMode.allRepaired,
      );
      expect(updated.master, isFalse);
      expect(updated.sound, isTrue);
      expect(updated.expeditionPreemptSeconds, 30);
      expect(updated.constructionPreemptSeconds, 60);
      expect(updated.moralePreemptSeconds, 30);
      expect(
        updated.anchorageMode,
        AnchorageNotificationMode.allRepaired,
      );
    });
  });

  group('SharedPreferencesNotificationSettingsStore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('saves and loads customized settings', () async {
      const store = SharedPreferencesNotificationSettingsStore();
      const custom = NotificationSettings(
        master: true,
        sound: false,
        vibration: true,
        ongoingLive: false,
        expeditionPreemptSeconds: 30,
        repairPreemptSeconds: 60,
        anchorageMode: AnchorageNotificationMode.both,
        construction: false,
        constructionPreemptSeconds: 60,
        morale: true,
        moralePreemptSeconds: 30,
      );

      await store.save(custom);
      final loaded = await store.load();

      expect(loaded.master, isTrue);
      expect(loaded.sound, isFalse);
      expect(loaded.ongoingLive, isFalse);
      expect(loaded.expeditionPreemptSeconds, 30);
      expect(loaded.repairPreemptSeconds, 60);
      expect(loaded.anchorageMode, AnchorageNotificationMode.both);
      expect(loaded.construction, isFalse);
      expect(loaded.constructionPreemptSeconds, 60);
      expect(loaded.morale, isTrue);
      expect(loaded.moralePreemptSeconds, 30);
    });

    test('sanitizes legacy 120s preempt to default fallback', () async {
      SharedPreferences.setMockInitialValues({
        'yahagi_notification_exp_preempt': 120,
        'yahagi_notification_repair_preempt': 120,
      });
      const store = SharedPreferencesNotificationSettingsStore();
      final loaded = await store.load();

      expect(loaded.expeditionPreemptSeconds, 60);
      expect(loaded.repairPreemptSeconds, 0);
    });
  });

  group('NotificationSettingsController', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('notifies listeners on property change', () async {
      final controller = NotificationSettingsController(
        store: const SharedPreferencesNotificationSettingsStore(),
      );
      await controller.initialize();

      var notified = false;
      controller.addListener(() => notified = true);

      await controller.setExpeditionPreemptSeconds(30);
      expect(notified, isTrue);
      expect(controller.settings.expeditionPreemptSeconds, 30);

      await controller.setConstructionPreemptSeconds(60);
      expect(controller.settings.constructionPreemptSeconds, 60);

      await controller.setMoralePreemptSeconds(30);
      expect(controller.settings.moralePreemptSeconds, 30);
    });
  });
}
