import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/capture/android_game_capture_port.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('test/game_capture');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    MethodChannelGameCapturePort.resetArbitersForTesting();
  });

  test(
    'replacement port owns the final cross-instance configuration',
    () async {
      final oldConfigure = Completer<void>();
      final enabledCalls = <bool>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'configure') {
          final enabled =
              (call.arguments as Map<Object?, Object?>)['enabled']! as bool;
          enabledCalls.add(enabled);
          if (enabledCalls.length == 1) await oldConfigure.future;
        }
        return null;
      });
      final oldPort = MethodChannelGameCapturePort(channel: channel);
      addTearDown(oldPort.dispose);
      final oldRequest = oldPort.configure(enabled: true, script: 'old');
      await Future<void>.delayed(Duration.zero);

      final newPort = MethodChannelGameCapturePort(channel: channel);
      addTearDown(newPort.dispose);
      final newRequest = newPort.configure(enabled: false, script: 'new');
      await oldPort.configure(enabled: true, script: 'stale');
      oldConfigure.complete();
      await Future.wait(<Future<void>>[oldRequest, newRequest]);

      expect(enabledCalls, <bool>[true, false]);
    },
  );

  test('queries support and configures the native bridge', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'isSupported') {
        return true;
      }
      return null;
    });
    final port = MethodChannelGameCapturePort(channel: channel);
    addTearDown(port.dispose);

    expect(await port.isSupported(), isTrue);
    await port.configure(enabled: true, script: 'capture-script');

    expect(calls.map((call) => call.method), <String>[
      'isSupported',
      'configure',
    ]);
    expect(calls.last.arguments, <String, Object?>{
      'enabled': true,
      'script': 'capture-script',
    });
  });

  test('converts a native onCaptureEvent call into an event stream', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => null);
    final port = MethodChannelGameCapturePort(channel: channel);
    addTearDown(port.dispose);
    final received = port.events.first;

    final completer = Completer<void>();
    await messenger.handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(
        MethodCall('onCaptureEvent', <String, Object?>{
          'version': 1,
          'kind': 'kcsapi_response',
          'method': 'POST',
          'path': '/kcsapi/api_port/port',
          'requestParams': <String, Object?>{},
          'responseBody': 'svdata={"api_result":1}',
          'statusCode': 200,
          'transport': 'xhr',
          'sourceOrigin': 'https://w01y.kancolle-server.com',
          'capturedAt': '2026-07-30T10:00:00.000Z',
          'sequence': 1,
        }),
      ),
      (_) => completer.complete(),
    );
    await completer.future;

    expect((await received).path, '/kcsapi/api_port/port');
  });

  test('disposing a stale port keeps the replacement handler active', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => null);
    final stalePort = MethodChannelGameCapturePort(channel: channel);
    final replacementPort = MethodChannelGameCapturePort(channel: channel);
    addTearDown(stalePort.dispose);
    addTearDown(replacementPort.dispose);
    final received = <String>[];
    final subscription = replacementPort.events.listen(
      (event) => received.add(event.path),
    );
    addTearDown(subscription.cancel);

    stalePort.dispose();
    final completer = Completer<void>();
    await messenger.handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(
        MethodCall('onCaptureEvent', <String, Object?>{
          'version': 1,
          'kind': 'kcsapi_response',
          'method': 'POST',
          'path': '/kcsapi/api_port/port',
          'requestParams': <String, Object?>{},
          'responseBody': 'svdata={"api_result":1}',
          'statusCode': 200,
          'transport': 'xhr',
          'sourceOrigin': 'https://w01y.kancolle-server.com',
          'capturedAt': '2026-08-14T10:00:00.000Z',
          'sequence': 2,
        }),
      ),
      (_) => completer.complete(),
    );
    await completer.future;
    await Future<void>.delayed(Duration.zero);

    expect(received, <String>['/kcsapi/api_port/port']);
  });

  test('treats a missing native implementation as unsupported', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw MissingPluginException();
    });
    final port = MethodChannelGameCapturePort(channel: channel);
    addTearDown(port.dispose);

    expect(await port.isSupported(), isFalse);
  });

  test('retries while the hybrid WebView is still mounting', () async {
    var attempts = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'configure') {
        attempts++;
        if (attempts < 3) {
          throw PlatformException(code: 'webview_not_found');
        }
      }
      return null;
    });
    final port = MethodChannelGameCapturePort(channel: channel);
    addTearDown(port.dispose);

    await port.configure(enabled: true, script: 'capture-script');

    expect(attempts, 3);
  });

  test('does not retry permanent native configuration errors', () async {
    var attempts = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'configure') {
        attempts++;
        throw PlatformException(code: 'invalid_capture_script');
      }
      return null;
    });
    final port = MethodChannelGameCapturePort(channel: channel);
    addTearDown(port.dispose);

    await expectLater(
      port.configure(enabled: true, script: 'capture-script'),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'invalid_capture_script',
        ),
      ),
    );
    expect(attempts, 1);
  });
}
