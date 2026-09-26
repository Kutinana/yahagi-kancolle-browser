import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';
import 'package:yahagi_kancolle_browser/src/bridge/native_game_capture_script.dart';
import 'package:yahagi_kancolle_browser/src/capture/game_capture_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/game_capture_port.dart';

void main() {
  test(
    'session rotation rejects old document even after new start2 arrives',
    () async {
      final port = _CapturePort();
      final accepted = <CapturedApiEvent>[];
      final capture = GameCaptureController(onAcceptedEvent: accepted.add);
      addTearDown(() async {
        capture.dispose();
        await port.stream.close();
      });
      await capture.attach(
        port,
        enabled: true,
        script: nativeGameCaptureScript,
      );
      final oldId = capture.captureSessionId;
      port.stream.add(_event(oldId));
      await Future<void>.delayed(Duration.zero);
      expect(accepted, hasLength(1));
      final configGate = Completer<void>();
      port.gate = configGate;
      final rotation = capture.invalidateSession();
      expect(capture.latestEvent, isNull);
      final newId = capture.captureSessionId;
      expect(newId, isNot(oldId));
      port.stream.add(_event(oldId, path: '/kcsapi/api_start2/getData'));
      await Future<void>.delayed(Duration.zero);
      expect(accepted, hasLength(1));
      configGate.complete();
      await rotation;
      expect(port.scripts.last, contains("const captureSessionId = '$newId'"));
      expect(port.scripts.last, isNot(contains(captureSessionIdPlaceholder)));
      port.stream.add(_event(newId, path: '/kcsapi/api_start2/getData'));
      port.stream.add(_event(oldId));
      port.stream.add(_event(oldId, path: '/kcsapi/api_get_member/basic'));
      port.stream.add(_event(null));
      port.stream.add(_event(newId));
      await Future<void>.delayed(Duration.zero);
      expect(accepted, hasLength(3));
      expect(
        accepted.skip(1).every((event) => event.captureSessionId == newId),
        isTrue,
      );
      expect(
        accepted.last.withDecodedEnvelope({'api_result': 1}).captureSessionId,
        newId,
      );
    },
  );

  test(
    'real capture script keeps old fetch and XHR responses in original session',
    () async {
      final directory = Directory.systemTemp.createTempSync(
        'yahagi-capture-session-',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final script = File('${directory.path}/capture.js')
        ..writeAsStringSync(nativeGameCaptureScript);
      final result = await Process.run('node', [
        'test/fixtures/native_capture_session_test.cjs',
        script.path,
      ]);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    },
  );
}

CapturedApiEvent _event(
  String? sessionId, {
  String path = '/kcsapi/api_port/port',
}) => CapturedApiEvent(
  path: path,
  responseBody: '{"api_result":1}',
  source: CaptureSource.xhr,
  capturedAt: DateTime.utc(2026, 9, 12),
  captureSessionId: sessionId,
);

class _CapturePort implements GameCapturePort {
  final stream = StreamController<CapturedApiEvent>();
  final scripts = <String>[];
  Completer<void>? gate;
  @override
  Stream<CapturedApiEvent> get events => stream.stream;
  @override
  Future<bool> isSupported() async => true;
  @override
  Future<void> configure({
    required bool enabled,
    required String script,
  }) async {
    scripts.add(script);
    await gate?.future;
  }

  @override
  void dispose() {}
}
