import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'senka_calculation.dart';
import 'senka_calendar_view.dart';
import 'senka_calculator_view.dart';
import 'senka_controller.dart';
import 'senka_info_view.dart';
import 'senka_ui.dart';

enum SenkaCenterMode {
  info('战果信息'),
  calendar('战果日历'),
  calculator('战果计算');

  const SenkaCenterMode(this.label);
  final String label;
}

String senkaCenterModeLabel(AppLocalizations? l10n, SenkaCenterMode mode) =>
    switch (mode) {
      SenkaCenterMode.info => l10n?.senkaInfoTab ?? mode.label,
      SenkaCenterMode.calendar => l10n?.senkaCalendarTab ?? mode.label,
      SenkaCenterMode.calculator => l10n?.senkaCalculatorTab ?? mode.label,
    };

class SenkaPage extends StatefulWidget {
  const SenkaPage({
    super.key,
    required this.controller,
    this.now,
    this.mode = SenkaCenterMode.info,
    this.onOpenSortieLog,
  });

  final SenkaController controller;
  final DateTime? now;
  final SenkaCenterMode mode;
  final VoidCallback? onOpenSortieLog;

  @override
  State<SenkaPage> createState() => _SenkaPageState();
}

class _SenkaPageState extends State<SenkaPage> {
  Timer? _refreshTimer;
  late DateTime _instant;

  @override
  void initState() {
    super.initState();
    _instant = widget.now?.toUtc() ?? DateTime.now().toUtc();
    _scheduleRefresh();
  }

  @override
  void didUpdateWidget(covariant SenkaPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.now != oldWidget.now ||
        widget.controller != oldWidget.controller) {
      _refreshTimer?.cancel();
      _instant = widget.now?.toUtc() ?? DateTime.now().toUtc();
      _scheduleRefresh();
    }
  }

  void _scheduleRefresh() {
    if (widget.now != null) return;
    final current = DateTime.now().toUtc();
    final next = senkaNextRefreshInstant(current);
    _refreshTimer = Timer(next.difference(current), _refreshAtBoundary);
  }

  void _refreshAtBoundary() {
    if (!mounted) return;
    _instant = DateTime.now().toUtc();
    widget.controller.refreshForCurrentTime();
    setState(() {});
    _scheduleRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: senkaBackground,
    child: AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxHeight <= 450 || constraints.maxWidth <= 450;
          final state = widget.controller.state;
          final instant = widget.now?.toUtc() ?? _instant;
          return Padding(
            padding: EdgeInsets.all(compact ? 4 : 10),
            child: Column(
              children: [
                if (widget.controller.hasPersistenceError) ...[
                  Container(
                    key: const Key('senka-persistence-error'),
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 8 : 12,
                      vertical: compact ? 3 : 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xff4a2020),
                      border: Border.all(color: const Color(0xffb85b5b)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      (AppLocalizations.of(context) ??
                              lookupAppLocalizations(const Locale('zh')))
                          .senkaSaveFailedWarning,
                      style: TextStyle(
                        color: const Color(0xffffb8b8),
                        fontSize: compact ? 9 : 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(height: compact ? 3 : 6),
                ],
                Expanded(
                  child: switch (widget.mode) {
                    SenkaCenterMode.info => SenkaInfoView(
                      state: state,
                      controller: widget.controller,
                      now: instant,
                      compact: compact,
                      onOpenSortieLog: widget.onOpenSortieLog,
                    ),
                    SenkaCenterMode.calendar => SenkaCalendarView(
                      state: state,
                      now: instant,
                      compact: compact,
                    ),
                    SenkaCenterMode.calculator => SenkaCalculatorView(
                      state: state,
                      controller: widget.controller,
                      now: instant,
                      compact: compact,
                    ),
                  },
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}
