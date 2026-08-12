import 'dart:async';

import 'diagnostic_event.dart';
import 'diagnostic_storage.dart';

typedef DiagnosticTimerFactory =
    Timer Function(Duration duration, void Function() callback);

final class DiagnosticRecorder {
  DiagnosticRecorder({
    required DiagnosticSink sink,
    bool enabled = true,
    this.flushEventCount = 50,
    this.flushByteCount = 64 * 1024,
    this.flushInterval = const Duration(seconds: 30),
    DiagnosticTimerFactory? timerFactory,
  }) : assert(flushEventCount > 0),
       assert(flushByteCount > 0),
       _sink = sink,
       _enabled = enabled,
       _timerFactory = timerFactory ?? _defaultTimerFactory {
    if (_enabled) _scheduleTimer();
  }

  final DiagnosticSink _sink;
  final int flushEventCount;
  final int flushByteCount;
  final Duration flushInterval;
  final DiagnosticTimerFactory _timerFactory;
  final List<DiagnosticEvent> _buffer = <DiagnosticEvent>[];
  Future<void> _queue = Future<void>.value();
  Timer? _timer;
  int _bufferBytes = 0;
  int _droppedEventCount = 0;
  bool _enabled;
  bool _disposed = false;

  bool get enabled => _enabled;
  int get bufferedEventCount => _buffer.length;
  int get droppedEventCount => _droppedEventCount;
  Future<void> get idle => _queue;

  void record(DiagnosticEvent event) {
    if (!_enabled || _disposed) return;
    _buffer.add(event);
    _bufferBytes += event.estimatedEncodedBytes;
    if (_buffer.length >= flushEventCount || _bufferBytes >= flushByteCount) {
      unawaited(flush());
    }
  }

  Future<void> flush() {
    if (_buffer.isEmpty) return _queue;
    final batch = List<DiagnosticEvent>.of(_buffer, growable: false);
    _buffer.clear();
    _bufferBytes = 0;
    _queue = _queue.then((_) => _sink.appendAll(batch)).catchError((_) {
      _droppedEventCount += batch.length;
    });
    return _queue;
  }

  Future<void> setEnabled(bool value) async {
    if (_disposed || value == _enabled) return;
    _enabled = value;
    if (!value) {
      _timer?.cancel();
      _timer = null;
      await flush();
      return;
    }
    _scheduleTimer();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _enabled = false;
    _timer?.cancel();
    _timer = null;
    await flush();
  }

  void _scheduleTimer() {
    _timer?.cancel();
    _timer = _timerFactory(flushInterval, () {
      if (!_enabled || _disposed) return;
      unawaited(flush());
      _scheduleTimer();
    });
  }
}

Timer _defaultTimerFactory(Duration duration, void Function() callback) =>
    Timer(duration, callback);
