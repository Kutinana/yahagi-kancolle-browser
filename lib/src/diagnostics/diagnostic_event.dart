import 'dart:collection';
import 'dart:convert';

import 'diagnostic_privacy_policy.dart';

enum DiagnosticOutcome { success, failure, skipped }

enum DiagnosticLifecycleState { started, resumed, paused, stopped, lowMemory }

enum DiagnosticComponent { application, capture, database, platform, webView }

enum DiagnosticErrorCode {
  operationFailed,
  decodeFailed,
  platformUnavailable,
  webViewLoadFailed,
  renderProcessGone,
}

enum DiagnosticWebViewHost { flutterPlatformView, activityDirect, absent }

enum DiagnosticGameRenderer { webgl, canvas, unknown }

enum DiagnosticPreviousExitReason {
  lowMemory,
  crash,
  anr,
  userRequested,
  systemUpdate,
  unknown,
  unavailable,
}

final class DiagnosticEvent {
  DiagnosticEvent._({
    required this.occurredAt,
    required this.type,
    required Map<String, Object?> fields,
  }) : fields = UnmodifiableMapView<String, Object?>(fields) {
    _policy.validateField('type', type);
    _policy.validateRecord(fields);
  }

  static final DiagnosticPrivacyPolicy _policy = DiagnosticPrivacyPolicy.v1();

  final DateTime occurredAt;
  final String type;
  final Map<String, Object?> fields;

  factory DiagnosticEvent.lifecycle({
    required DateTime occurredAt,
    required DiagnosticLifecycleState state,
    required int uptimeMs,
  }) => DiagnosticEvent._(
    occurredAt: occurredAt.toUtc(),
    type: 'lifecycle',
    fields: <String, Object?>{'state': state.name, 'uptimeMs': uptimeMs},
  );

  factory DiagnosticEvent.slowApi({
    required DateTime occurredAt,
    required String path,
    required int responseBytes,
    required int queueWaitMicros,
    required int decodeMicros,
    required int dispatchMicros,
    required DiagnosticOutcome outcome,
  }) => DiagnosticEvent._(
    occurredAt: occurredAt.toUtc(),
    type: 'apiSlow',
    fields: <String, Object?>{
      'path': _policy.safeApiPath(path),
      'responseBytes': responseBytes,
      'queueWaitMicros': queueWaitMicros,
      'decodeMicros': decodeMicros,
      'dispatchMicros': dispatchMicros,
      'outcome': outcome.name,
    },
  );

  factory DiagnosticEvent.fixedError({
    required DateTime occurredAt,
    required DiagnosticComponent component,
    required String errorType,
    required DiagnosticErrorCode code,
    StackTrace? stack,
  }) => DiagnosticEvent._(
    occurredAt: occurredAt.toUtc(),
    type: 'fixedError',
    fields: <String, Object?>{
      'component': component.name,
      'errorType': errorType,
      'code': code.name,
      'stack': _policy.safeStack(stack),
    },
  );

  factory DiagnosticEvent.performanceSample({
    required DateTime occurredAt,
    required int uptimeMs,
    required int pssKb,
    required int javaHeapKb,
    required int nativeHeapKb,
    required int graphicsKb,
    required int privateOtherKb,
    required int systemAvailableKb,
    required DiagnosticWebViewHost webViewHost,
    required DiagnosticGameRenderer renderer,
    required int generationId,
    required int totalFrames,
    required int over16Ms,
    required int over33Ms,
    required int over100Ms,
    required int maxFrameMicros,
    required int pendingApiEvents,
    required int databaseBytes,
  }) => DiagnosticEvent._(
    occurredAt: occurredAt.toUtc(),
    type: 'performanceSample',
    fields: <String, Object?>{
      'uptimeMs': uptimeMs,
      'pssKb': pssKb,
      'javaHeapKb': javaHeapKb,
      'nativeHeapKb': nativeHeapKb,
      'graphicsKb': graphicsKb,
      'privateOtherKb': privateOtherKb,
      'systemAvailableKb': systemAvailableKb,
      'webViewHost': webViewHost.name,
      'renderer': renderer.name,
      'generationId': generationId,
      'totalFrames': totalFrames,
      'over16Ms': over16Ms,
      'over33Ms': over33Ms,
      'over100Ms': over100Ms,
      'maxFrameMicros': maxFrameMicros,
      'pendingApiEvents': pendingApiEvents,
      'databaseBytes': databaseBytes,
    },
  );

  factory DiagnosticEvent.webViewState({
    required DateTime occurredAt,
    required String state,
    required int durationMs,
    int? errorCode,
  }) => DiagnosticEvent._(
    occurredAt: occurredAt.toUtc(),
    type: 'webViewState',
    fields: <String, Object?>{
      'state': state,
      'durationMs': durationMs,
      'errorCode': ?errorCode,
    },
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'occurredAt': occurredAt.toIso8601String(),
    'type': type,
    'fields': fields,
  };

  int get estimatedEncodedBytes => utf8.encode(jsonEncode(toJson())).length + 1;
}
