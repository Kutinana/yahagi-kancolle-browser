import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/notification/method_channel_notification_port.dart';
import 'package:yahagi_kancolle_browser/src/notification/notification_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/notification');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'applySnapshot sends one complete snapshot and parses the result',
    () async {
      MethodCall? received;
      messenger.setMockMethodCallHandler(channel, (call) async {
        received = call;
        return {
          'scheduledExact': 1,
          'scheduledInexact': 0,
          'canceled': 2,
          'failures': <String>[],
        };
      });
      final snapshot = NotificationSnapshot(
        updatedAt: DateTime.fromMillisecondsSinceEpoch(1234),
        alarms: const [],
        ongoingItems: const [],
        presentation: const NotificationPresentation(
          enabled: true,
          sound: true,
          vibration: true,
          showProgress: true,
          showPercent: true,
          showCountdown: true,
          ongoingLive: true,
        ),
      );

      final result = await const MethodChannelNotificationPort(
        channel,
      ).applySnapshot(snapshot);

      expect(received?.method, 'applySnapshot');
      expect(received?.arguments, snapshot.toMap());
      expect(result.scheduledExact, 1);
      expect(result.canceled, 2);
    },
  );

  test('native failures remain observable to the caller', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => throw PlatformException(code: 'apply_failed'),
    );
    final snapshot = NotificationSnapshot(
      updatedAt: DateTime.fromMillisecondsSinceEpoch(1234),
      alarms: const [],
      ongoingItems: const [],
      presentation: const NotificationPresentation(
        enabled: true,
        sound: true,
        vibration: true,
        showProgress: true,
        showPercent: true,
        showCountdown: true,
        ongoingLive: true,
      ),
    );

    expect(
      const MethodChannelNotificationPort(channel).applySnapshot(snapshot),
      throwsA(isA<PlatformException>()),
    );
  });
}
