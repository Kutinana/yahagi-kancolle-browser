import 'package:flutter/material.dart';

import 'senka_state.dart';
import 'senka_ui.dart';

class SenkaCalendarView extends StatefulWidget {
  const SenkaCalendarView({
    super.key,
    required this.state,
    required this.now,
    required this.compact,
  });
  final SenkaState state;
  final DateTime now;
  final bool compact;
  @override
  State<SenkaCalendarView> createState() => _SenkaCalendarViewState();
}

class _SenkaCalendarViewState extends State<SenkaCalendarView> {
  late DateTime selected = DateTime(
    widget.now.year,
    widget.now.month,
    widget.now.day,
  );
  @override
  Widget build(BuildContext context) {
    final parsed = parseSenkaMonthKey(widget.state.monthKey);
    final year = parsed?.year ?? widget.now.year;
    final month = parsed?.month ?? widget.now.month;
    final first = DateTime(year, month, 1);
    final leading = first.weekday - 1;
    final count = DateTime(year, month + 1, 0).day;
    final shownSelected = selected.year == year && selected.month == month
        ? selected
        : first;
    final record = widget.state.day(shownSelected);
    return SenkaPanel(
      title: '$year年$month月战果日历',
      compact: widget.compact,
      trailing: Text(
        '本月已记录 ${senkaNumber(widget.state.monthRecorded)}',
        style: TextStyle(
          color: senkaGold,
          fontSize: widget.compact ? 10 : 14,
          fontWeight: FontWeight.w800,
        ),
      ),
      child: Column(
        children: [
          Container(
            key: const Key('calendar-weekday-background'),
            height: widget.compact ? 24 : 32,
            color: const Color(0xff071923),
            child: Row(
              key: const Key('calendar-weekday-row'),
              children: [
                for (final day in const ['一', '二', '三', '四', '五', '六', '日'])
                  Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: TextStyle(
                          color: senkaText,
                          fontSize: widget.compact ? 10 : 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                for (var week = 0; week < 6; week++)
                  Expanded(
                    key: Key('calendar-week-row-$week'),
                    child: Row(
                      children: [
                        for (var weekday = 0; weekday < 7; weekday++)
                          Expanded(
                            child: _cell(
                              year,
                              month,
                              week * 7 + weekday,
                              leading,
                              count,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Container(
            key: const Key('senka-day-detail'),
            height: widget.compact ? 28 : 38,
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: senkaLine)),
            ),
            child: Row(
              children: [
                _detail('经验', record.experience),
                _detail('EO', record.eo),
                _detail('任务', record.quest),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cell(int year, int month, int slot, int leading, int count) {
    final day = slot - leading + 1;
    final inMonth = day >= 1 && day <= count;
    final date = inMonth ? DateTime(year, month, day) : null;
    final record = date == null
        ? const SenkaDayRecord()
        : widget.state.day(date);
    final chosen =
        date != null &&
        date.year == selected.year &&
        date.month == selected.month &&
        date.day == selected.day;
    return Material(
      key: Key(inMonth ? 'calendar-cell-$day' : 'calendar-cell-out-$slot'),
      color: chosen ? senkaGold.withValues(alpha: .12) : senkaPanel,
      child: InkWell(
        onTap: date == null ? null : () => setState(() => selected = date),
        child: Container(
          decoration: const BoxDecoration(
            border: Border(
              right: BorderSide(color: senkaLine),
              bottom: BorderSide(color: senkaLine),
            ),
          ),
          padding: EdgeInsets.all(widget.compact ? 2 : 5),
          child: inMonth
              ? Stack(
                  children: [
                    Align(
                      alignment: Alignment.topLeft,
                      child: Text(
                        '$day',
                        style: TextStyle(
                          color: senkaText,
                          fontSize: widget.compact ? 11 : 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Text(
                        senkaNumber(record.total),
                        maxLines: 1,
                        style: TextStyle(
                          color: senkaGold,
                          fontSize: widget.compact ? 9 : 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _detail(String label, double value) => Expanded(
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            color: senkaText,
            fontSize: widget.compact ? 10 : 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(width: widget.compact ? 3 : 7),
        Text(
          '${value >= 0 ? '+' : ''}${value.toStringAsFixed(2)}',
          style: TextStyle(
            color: senkaGold,
            fontSize: widget.compact ? 10 : 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}
