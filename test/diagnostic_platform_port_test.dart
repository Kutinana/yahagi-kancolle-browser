import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/diagnostics/diagnostic_platform_port.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/diagnostics');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('accepts exactly the approved device fields', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => <String, Object?>{
            'manufacturer': 'Google',
            'model': 'Pixel',
            'androidSdk': 35,
            'androidRelease': '15',
            'supportedAbi': 'arm64-v8a',
            'memoryClassMb': 8192,
            'screenWidthPx': 2400,
            'screenHeightPx': 1080,
            'webViewVersion': '139.0.0',
          },
        );
    final port = MethodChannelDiagnosticPlatformPort(channel);

    final snapshot = await port.deviceSnapshot();

    expect(snapshot.model, 'Pixel');
    expect(snapshot.androidSdk, 35);
  });

  test('rejects an unexpected native field', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => <String, Object?>{
            'manufacturer': 'Google',
            'model': 'Pixel',
            'androidSdk': 35,
            'androidRelease': '15',
            'supportedAbi': 'arm64-v8a',
            'memoryClassMb': 8192,
            'screenWidthPx': 2400,
            'screenHeightPx': 1080,
            'webViewVersion': '139.0.0',
            'androidId': 'TEST_ONLY_SECRET_DO_NOT_USE',
          },
        );

    expect(
      MethodChannelDiagnosticPlatformPort(channel).deviceSnapshot,
      throwsA(isA<DiagnosticPlatformSchemaException>()),
    );
  });

  test('saveJson returns the final file name or cancellation', () async {
    final calls = <MethodCall>[];
    var savedName = 'Yahagi-Diagnostics-20260813-091445.json';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return savedName;
        });
    final port = MethodChannelDiagnosticPlatformPort(channel);

    expect(await port.saveJson('/safe/export.json'), savedName);
    expect(calls.single.method, 'saveJson');
    expect(calls.single.arguments, <String, Object?>{
      'path': '/safe/export.json',
    });

    savedName = '';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);
    expect(await port.saveJson('/safe/export.json'), isNull);
  });

  test('saveJson rejects an invalid platform result', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => 42);

    expect(
      () => MethodChannelDiagnosticPlatformPort(
        channel,
      ).saveJson('/safe/export.json'),
      throwsA(isA<DiagnosticPlatformSchemaException>()),
    );
  });
}
