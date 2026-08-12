import 'dart:isolate';
import 'dart:convert';

import '../bridge/captured_api_event.dart';
import 'game_api_decoder.dart';

typedef GameApiEnvelopeDecoder =
    Future<Map<String, Object?>> Function(String responseBody);
typedef GameApiSyncEnvelopeDecoder =
    Map<String, Object?> Function(String responseBody);

abstract interface class GameApiEventConsumer {
  bool supportsPath(String path);

  void accept(CapturedApiEvent event);

  Future<void> get idle;
}

final class GameApiTiming {
  const GameApiTiming({
    required this.path,
    required this.responseBytes,
    required this.queueDepth,
    required this.queueWaitMicros,
    required this.decodeMicros,
    required this.dispatchMicros,
    required this.success,
  });

  final String path;
  final int responseBytes;
  final int queueDepth;
  final int queueWaitMicros;
  final int decodeMicros;
  final int dispatchMicros;
  final bool success;
}

abstract interface class GameApiPipelineObserver {
  void onCompleted(GameApiTiming timing);
}

final class GameApiEventPipeline {
  GameApiEventPipeline({
    required List<GameApiEventConsumer> consumers,
    GameApiEnvelopeDecoder? decodeEnvelope,
    GameApiSyncEnvelopeDecoder? decodeSmallEnvelope,
    this.observer,
    this.backgroundThresholdBytes = 64 * 1024,
  }) : assert(backgroundThresholdBytes > 0),
       _consumers = List<GameApiEventConsumer>.unmodifiable(consumers),
       _decodeEnvelope = decodeEnvelope ?? _decodeInBackground,
       _decodeSmallEnvelope =
           decodeSmallEnvelope ?? GameApiDecoder.decodeEnvelope;

  final List<GameApiEventConsumer> _consumers;
  final GameApiEnvelopeDecoder _decodeEnvelope;
  final GameApiSyncEnvelopeDecoder _decodeSmallEnvelope;
  final int backgroundThresholdBytes;
  GameApiPipelineObserver? observer;
  Future<void> _queue = Future<void>.value();
  int _pendingEventCount = 0;

  int get pendingEventCount => _pendingEventCount;

  void add(CapturedApiEvent event) {
    final currentObserver = observer;
    if (currentObserver == null) {
      _queue = _queue.then(
        (_) => _prepareAndDispatch(event),
        onError: (_) => _prepareAndDispatch(event),
      );
      return;
    }
    _pendingEventCount += 1;
    final queueDepth = _pendingEventCount;
    final queued = Stopwatch()..start();
    _queue = _queue.then(
      (_) => _prepareDispatchAndObserve(
        event,
        currentObserver,
        queued,
        queueDepth,
      ),
      onError: (_) => _prepareDispatchAndObserve(
        event,
        currentObserver,
        queued,
        queueDepth,
      ),
    );
  }

  Future<void> _prepareDispatchAndObserve(
    CapturedApiEvent event,
    GameApiPipelineObserver target,
    Stopwatch queued,
    int queueDepth,
  ) async {
    queued.stop();
    final queueWaitMicros = queued.elapsedMicroseconds;
    var result = (decodeMicros: 0, dispatchMicros: 0, success: false);
    try {
      result = await _prepareAndDispatch(event);
    } finally {
      _pendingEventCount -= 1;
      target.onCompleted(
        GameApiTiming(
          path: event.path,
          responseBytes:
              event.responseByteLength ??
              utf8.encode(event.responseBody).length,
          queueDepth: queueDepth,
          queueWaitMicros: queueWaitMicros,
          decodeMicros: result.decodeMicros,
          dispatchMicros: result.dispatchMicros,
          success: result.success,
        ),
      );
    }
  }

  Future<void> get idle async {
    await _queue;
    await Future.wait<void>(<Future<void>>[
      for (final consumer in _consumers) consumer.idle,
    ]);
  }

  Future<({int decodeMicros, int dispatchMicros, bool success})>
  _prepareAndDispatch(CapturedApiEvent event) async {
    final consumers = <GameApiEventConsumer>[
      for (final consumer in _consumers)
        if (consumer.supportsPath(event.path)) consumer,
    ];
    if (consumers.isEmpty) {
      return (decodeMicros: 0, dispatchMicros: 0, success: true);
    }

    var prepared = event;
    var success = true;
    final decodeWatch = Stopwatch()..start();
    if (!event.hasDecodedEnvelope) {
      try {
        prepared = event.withDecodedEnvelope(
          _shouldDecodeInBackground(event)
              ? await _decodeEnvelope(event.responseBody)
              : _decodeSmallEnvelope(event.responseBody),
        );
      } catch (_) {
        success = false;
        // Preserve the established controller error path for invalid responses.
      }
    }
    decodeWatch.stop();

    final dispatchWatch = Stopwatch()..start();
    for (final consumer in consumers) {
      consumer.accept(prepared);
    }
    dispatchWatch.stop();
    return (
      decodeMicros: decodeWatch.elapsedMicroseconds,
      dispatchMicros: dispatchWatch.elapsedMicroseconds,
      success: success,
    );
  }

  bool _shouldDecodeInBackground(CapturedApiEvent event) {
    return event.path == '/kcsapi/api_start2/getData' ||
        event.responseBody.length >= backgroundThresholdBytes;
  }
}

Future<Map<String, Object?>> _decodeInBackground(String responseBody) {
  return Isolate.run(() => GameApiDecoder.decodeEnvelope(responseBody));
}
