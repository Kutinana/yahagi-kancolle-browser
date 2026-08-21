import 'dart:async';

import 'package:flutter/foundation.dart';

/// Rechecks responsive layout after fold, rotation, PiP, and multi-window
/// animations. Android can publish several intermediate window sizes before
/// the final bounds settle, so only the newest recovery generation is kept.
class WindowMetricsRecoveryScheduler {
  static const List<Duration> _delays = <Duration>[
    Duration(milliseconds: 50),
    Duration(milliseconds: 100),
    Duration(milliseconds: 350),
    Duration(milliseconds: 800),
  ];

  final List<Timer> _timers = <Timer>[];
  bool _disposed = false;

  void schedule(VoidCallback recover) {
    if (_disposed) return;
    _cancelTimers();
    for (final delay in _delays) {
      late final Timer timer;
      timer = Timer(delay, () {
        _timers.remove(timer);
        if (!_disposed) recover();
      });
      _timers.add(timer);
    }
  }

  void cancel() {
    if (_disposed) return;
    _cancelTimers();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _cancelTimers();
  }

  void _cancelTimers() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
  }
}
