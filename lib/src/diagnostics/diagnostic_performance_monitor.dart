import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'diagnostic_event.dart';
import 'diagnostic_platform_port.dart';
import 'diagnostic_recorder.dart';

final class DiagnosticFrameSnapshot {
  const DiagnosticFrameSnapshot({
    required this.totalFrames,
    required this.over16Ms,
    required this.over33Ms,
    required this.over100Ms,
    required this.maxFrameMicros,
  });

  final int totalFrames;
  final int over16Ms;
  final int over33Ms;
  final int over100Ms;
  final int maxFrameMicros;
}

final class DiagnosticFrameWindow {
  int _totalFrames = 0;
  int _over16Ms = 0;
  int _over33Ms = 0;
  int _over100Ms = 0;
  int _maxFrameMicros = 0;

  void add(Duration duration) {
    final micros = duration.inMicroseconds;
    _totalFrames += 1;
    if (micros > 16667) _over16Ms += 1;
    if (micros > 33333) _over33Ms += 1;
    if (micros > 100000) _over100Ms += 1;
    if (micros > _maxFrameMicros) _maxFrameMicros = micros;
  }

  DiagnosticFrameSnapshot takeSnapshot() {
    final result = DiagnosticFrameSnapshot(
      totalFrames: _totalFrames,
      over16Ms: _over16Ms,
      over33Ms: _over33Ms,
      over100Ms: _over100Ms,
      maxFrameMicros: _maxFrameMicros,
    );
    _totalFrames = 0;
    _over16Ms = 0;
    _over33Ms = 0;
    _over100Ms = 0;
    _maxFrameMicros = 0;
    return result;
  }
}

final class DiagnosticPerformanceMonitor with WidgetsBindingObserver {
  DiagnosticPerformanceMonitor({
    required this.recorder,
    required this.platform,
    required this.pendingApiEvents,
    required this.databaseBytes,
    this.sampleInterval = const Duration(seconds: 60),
    DateTime Function()? now,
    Stopwatch? uptime,
  }) : _now = now ?? DateTime.now,
       _uptime = uptime ?? (Stopwatch()..start());

  final DiagnosticRecorder recorder;
  final DiagnosticPlatformPort platform;
  final int Function() pendingApiEvents;
  final Future<int> Function() databaseBytes;
  final Duration sampleInterval;
  final DateTime Function() _now;
  final Stopwatch _uptime;
  final DiagnosticFrameWindow _frames = DiagnosticFrameWindow();
  Timer? _timer;
  bool _attached = false;
  late final TimingsCallback _timingsCallback = _onTimings;

  void attach() {
    if (_attached || !recorder.enabled) return;
    _attached = true;
    WidgetsBinding.instance.addObserver(this);
    SchedulerBinding.instance.addTimingsCallback(_timingsCallback);
    _timer = Timer.periodic(sampleInterval, (_) => unawaited(sample()));
  }

  void detach() {
    if (!_attached) return;
    _attached = false;
    _timer?.cancel();
    _timer = null;
    SchedulerBinding.instance.removeTimingsCallback(_timingsCallback);
    WidgetsBinding.instance.removeObserver(this);
    _frames.takeSnapshot();
  }

  void _onTimings(List<FrameTiming> timings) {
    if (!_attached) return;
    for (final timing in timings) {
      _frames.add(timing.totalSpan);
    }
  }

  Future<void> sample() async {
    if (!_attached || !recorder.enabled) return;
    try {
      final runtime = await platform.runtimeSnapshot();
      final frames = _frames.takeSnapshot();
      recorder.record(
        DiagnosticEvent.performanceSample(
          occurredAt: _now(),
          uptimeMs: _uptime.elapsedMilliseconds,
          pssKb: runtime.pssKb,
          javaHeapKb: runtime.javaHeapKb,
          nativeHeapKb: runtime.nativeHeapKb,
          totalFrames: frames.totalFrames,
          over16Ms: frames.over16Ms,
          over33Ms: frames.over33Ms,
          over100Ms: frames.over100Ms,
          maxFrameMicros: frames.maxFrameMicros,
          pendingApiEvents: pendingApiEvents(),
          databaseBytes: await databaseBytes(),
        ),
      );
    } catch (_) {
      // Missing platform statistics must never affect the app or recurse.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_attached) return;
    if (state == AppLifecycleState.resumed) {
      _recordLifecycle(DiagnosticLifecycleState.resumed);
      _timer ??= Timer.periodic(sampleInterval, (_) => unawaited(sample()));
    } else {
      _recordLifecycle(
        state == AppLifecycleState.detached
            ? DiagnosticLifecycleState.stopped
            : DiagnosticLifecycleState.paused,
      );
      _timer?.cancel();
      _timer = null;
      unawaited(recorder.flush());
    }
  }

  @override
  void didHaveMemoryPressure() {
    if (!_attached) return;
    _recordLifecycle(DiagnosticLifecycleState.lowMemory);
    unawaited(sample());
  }

  void _recordLifecycle(DiagnosticLifecycleState state) {
    recorder.record(
      DiagnosticEvent.lifecycle(
        occurredAt: _now(),
        state: state,
        uptimeMs: _uptime.elapsedMilliseconds,
      ),
    );
  }
}
