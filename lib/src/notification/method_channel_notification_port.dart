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
}
