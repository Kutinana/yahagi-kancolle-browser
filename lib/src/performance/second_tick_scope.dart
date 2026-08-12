import 'dart:async';

import 'package:flutter/widgets.dart';

typedef SecondTickWidgetBuilder =
    Widget Function(BuildContext context, DateTime now, Widget? child);

class SecondTickScope extends StatefulWidget {
  const SecondTickScope({super.key, required this.child, this.now});

  final Widget child;
  final DateTime Function()? now;

  static ValueNotifier<DateTime>? _notifierOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_InheritedSecondTick>()
        ?.notifier;
  }

  @override
  State<SecondTickScope> createState() => _SecondTickScopeState();
}

class _SecondTickScopeState extends State<SecondTickScope>
    with WidgetsBindingObserver {
  late final ValueNotifier<DateTime> _notifier;
  Timer? _timer;

  DateTime _now() => (widget.now ?? DateTime.now)().toUtc();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _notifier = ValueNotifier<DateTime>(_now());
    _startTimer();
  }

  void _startTimer() {
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      _notifier.value = _now();
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _notifier.value = _now();
      _startTimer();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _stopTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _InheritedSecondTick(notifier: _notifier, child: widget.child);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopTimer();
    _notifier.dispose();
    super.dispose();
  }
}

class _InheritedSecondTick extends InheritedWidget {
  const _InheritedSecondTick({required this.notifier, required super.child});

  final ValueNotifier<DateTime> notifier;

  @override
  bool updateShouldNotify(_InheritedSecondTick oldWidget) {
    return notifier != oldWidget.notifier;
  }
}

class SecondTickBuilder extends StatefulWidget {
  const SecondTickBuilder({
    super.key,
    required this.builder,
    this.child,
    this.now,
    this.enabled = true,
    this.stopAt,
  });

  final SecondTickWidgetBuilder builder;
  final Widget? child;
  final DateTime Function()? now;
  final bool enabled;
  final DateTime? stopAt;

  @override
  State<SecondTickBuilder> createState() => _SecondTickBuilderState();
}

class _SecondTickBuilderState extends State<SecondTickBuilder> {
  ValueNotifier<DateTime>? _scopedNotifier;
  Timer? _fallbackTimer;
  late DateTime _fallbackNow = _now();
  bool _tickerModeEnabled = true;

  DateTime _now() => (widget.now ?? DateTime.now)().toUtc();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _stopTickSource();
    _scopedNotifier = SecondTickScope._notifierOf(context);
    _tickerModeEnabled = TickerMode.valuesOf(context).enabled;
    _startTickSource();
  }

  bool _shouldTick(DateTime now) {
    final stopAt = widget.stopAt;
    return widget.enabled && (stopAt == null || now.isBefore(stopAt));
  }

  void _startTickSource() {
    final current = _scopedNotifier?.value ?? _now();
    _fallbackNow = current;
    if (!_tickerModeEnabled || !_shouldTick(current)) return;
    if (_scopedNotifier case final notifier?) {
      notifier.addListener(_handleScopedTick);
      return;
    }
    _fallbackTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final current = _now();
      setState(() => _fallbackNow = current);
      if (!_shouldTick(current)) {
        _stopTickSource();
      }
    });
  }

  void _stopTickSource() {
    _scopedNotifier?.removeListener(_handleScopedTick);
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
  }

  void _handleScopedTick() {
    if (!mounted) return;
    final current = _scopedNotifier!.value;
    setState(() => _fallbackNow = current);
    if (!_shouldTick(current)) {
      _stopTickSource();
    }
  }

  @override
  void didUpdateWidget(SecondTickBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.now != widget.now ||
        oldWidget.enabled != widget.enabled ||
        oldWidget.stopAt != widget.stopAt) {
      _stopTickSource();
      _startTickSource();
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _fallbackNow, widget.child);
  }

  @override
  void dispose() {
    _stopTickSource();
    super.dispose();
  }
}
