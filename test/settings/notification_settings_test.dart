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
      expect(settings.morale, isTrue);
    });

    test('copyWith updates specific fields correctly', () {
      const settings = NotificationSettings();
      final updated = settings.copyWith(
        master: false,
        expeditionPreemptSeconds: 30,
        anchorageMode: AnchorageNotificationMode.allRepaired,
      );
      expect(updated.master, isFalse);
      expect(updated.sound, isTrue);
      expect(updated.expeditionPreemptSeconds, 30);
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
        expeditionPreemptSeconds: 120,
        repairPreemptSeconds: 60,
        anchorageMode: AnchorageNotificationMode.both,
        construction: false,
        morale: true,
      );

      await store.save(custom);
      final loaded = await store.load();

      expect(loaded.master, isTrue);
      expect(loaded.sound, isFalse);
      expect(loaded.ongoingLive, isFalse);
      expect(loaded.expeditionPreemptSeconds, 120);
      expect(loaded.repairPreemptSeconds, 60);
      expect(loaded.anchorageMode, AnchorageNotificationMode.both);
      expect(loaded.construction, isFalse);
      expect(loaded.morale, isTrue);
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
    });
  });
}
