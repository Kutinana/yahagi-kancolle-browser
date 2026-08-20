import 'package:flutter/material.dart';

import 'senka_calendar_view.dart';
import 'senka_calculator_view.dart';
import 'senka_controller.dart';
import 'senka_info_view.dart';
import 'senka_state.dart';
import 'senka_ui.dart';

enum _SenkaSection { info, calendar, calculator }

class SenkaPage extends StatefulWidget {
  const SenkaPage({super.key, required this.controller, this.now});
  final SenkaController controller;
  final DateTime? now;
  @override
  State<SenkaPage> createState() => _SenkaPageState();
}

class _SenkaPageState extends State<SenkaPage> {
  _SenkaSection section = _SenkaSection.info;
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
          return Padding(
            padding: EdgeInsets.all(compact ? 4 : 10),
            child: Column(
              children: [
                SizedBox(
                  height: compact ? 40 : 44,
                  child: Row(
                    children: [
                      _tab('info', '战果信息', _SenkaSection.info, compact),
                      SizedBox(width: compact ? 4 : 8),
                      _tab('calendar', '战果日历', _SenkaSection.calendar, compact),
                      SizedBox(width: compact ? 4 : 8),
                      _tab(
                        'calculator',
                        '战果计算',
                        _SenkaSection.calculator,
                        compact,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: compact ? 4 : 10),
                Expanded(
                  child: switch (section) {
                    _SenkaSection.info => SenkaInfoView(
                      state: state,
                      controller: widget.controller,
                      compact: compact,
                    ),
                    _SenkaSection.calendar => SenkaCalendarView(
                      state: state,
                      now: widget.now ?? toJst(DateTime.now().toUtc()),
                      compact: compact,
                    ),
                    _SenkaSection.calculator => SenkaCalculatorView(
                      state: state,
                      controller: widget.controller,
                      now: widget.now ?? toJst(DateTime.now().toUtc()),
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

  Widget _tab(String keyName, String label, _SenkaSection value, bool compact) {
    final selected = section == value;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        child: Material(
          key: Key('senka-tab-$keyName'),
          color: selected ? senkaGold : senkaPanelAlt,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: selected ? senkaGold : senkaLine),
            borderRadius: BorderRadius.circular(compact ? 6 : 9),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => setState(() => section = value),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? senkaBackground : senkaText,
                  fontSize: compact ? 11 : 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
