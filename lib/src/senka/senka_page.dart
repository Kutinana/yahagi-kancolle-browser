import 'package:flutter/material.dart';

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

class SenkaPage extends StatelessWidget {
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
  Widget build(BuildContext context) => ColoredBox(
    color: senkaBackground,
    child: AnimatedBuilder(
      animation: controller,
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxHeight <= 450 || constraints.maxWidth <= 450;
          final state = controller.state;
          final instant = now ?? DateTime.now().toUtc();
          return Padding(
            padding: EdgeInsets.all(compact ? 4 : 10),
            child: switch (mode) {
              SenkaCenterMode.info => SenkaInfoView(
                state: state,
                controller: controller,
                compact: compact,
                onOpenSortieLog: onOpenSortieLog,
              ),
              SenkaCenterMode.calendar => SenkaCalendarView(
                state: state,
                now: instant,
                compact: compact,
              ),
              SenkaCenterMode.calculator => SenkaCalculatorView(
                state: state,
                controller: controller,
                now: instant,
                compact: compact,
              ),
            },
          );
        },
      ),
    ),
  );
}
