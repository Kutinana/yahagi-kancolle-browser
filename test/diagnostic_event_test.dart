import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/diagnostics/diagnostic_event.dart';

void main() {
  test('slow api event contains metrics but no request or response body', () {
    final event = DiagnosticEvent.slowApi(
      occurredAt: DateTime.utc(2026, 8, 13),
      path: '/kcsapi/api_port/port',
      responseBytes: 18432,
      queueWaitMicros: 100,
      decodeMicros: 200,
      dispatchMicros: 300,
      outcome: DiagnosticOutcome.success,
    );

    final encoded = jsonEncode(event.toJson());
    expect(encoded, contains('/kcsapi/api_port/port'));
    expect(encoded, contains('18432'));
    expect(encoded, isNot(contains('requestParams')));
    expect(encoded, isNot(contains('responseBody')));
    expect(encoded, isNot(contains('decodedEnvelope')));
  });

  test('fixed error stores only type code and safe stack', () {
    final event = DiagnosticEvent.fixedError(
      occurredAt: DateTime.utc(2026, 8, 13),
      component: DiagnosticComponent.database,
      errorType: 'DatabaseException',
      code: DiagnosticErrorCode.operationFailed,
      stack: StackTrace.fromString(
        '#0 Foo.run (package:yahagi_kancolle_browser/src/foo.dart:4:2)',
      ),
    );

    final encoded = jsonEncode(event.toJson());
    expect(encoded, contains('DatabaseException'));
    expect(encoded, contains('operationFailed'));
    expect(encoded, isNot(contains('message')));
    expect(encoded, isNot(contains('src/foo.dart')));
  });

  test('performance sample keeps host renderer and memory classifications', () {
    final event = DiagnosticEvent.performanceSample(
      occurredAt: DateTime.utc(2026, 8, 13),
      uptimeMs: 60000,
      pssKb: 900000,
      javaHeapKb: 120000,
      nativeHeapKb: 80000,
      graphicsKb: 210000,
      privateOtherKb: 70000,
      systemAvailableKb: 1800000,
      webViewHost: DiagnosticWebViewHost.activityDirect,
      renderer: DiagnosticGameRenderer.webgl,
      generationId: 17,
      totalFrames: 3600,
      over16Ms: 120,
      over33Ms: 40,
      over100Ms: 6,
      maxFrameMicros: 120000,
      pendingApiEvents: 3,
      databaseBytes: 8192,
    );

    final encoded = jsonEncode(event.toJson());
    expect(encoded, contains('activityDirect'));
    expect(encoded, contains('webgl'));
    expect(encoded, contains('"generationId":17'));
    expect(encoded, contains('"graphicsKb":210000'));
    expect(encoded, isNot(contains('"previousExitReason"')));
  });

  test('event fields are immutable', () {
    final event = DiagnosticEvent.lifecycle(
      occurredAt: DateTime.utc(2026, 8, 13),
      state: DiagnosticLifecycleState.started,
      uptimeMs: 0,
    );

    expect(() => event.fields['state'] = 'tampered', throwsUnsupportedError);
  });
}
