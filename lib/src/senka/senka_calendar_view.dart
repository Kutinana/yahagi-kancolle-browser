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
  late DateTime selected = _initialSelection(widget.state, widget.now);

  @override
  void didUpdateWidget(covariant SenkaCalendarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldMonth = parseSenkaMonthKey(oldWidget.state.monthKey);
    final newMonth = parseSenkaMonthKey(widget.state.monthKey);
    final oldDate = senkaBusinessDate(oldWidget.now);
    final newDate = senkaBusinessDate(widget.now);
    if (oldMonth != newMonth ||
        oldDate.year != newDate.year ||
        oldDate.month != newDate.month) {
      selected = _initialSelection(widget.state, widget.now);
    }
  }

  @override
  Widget build(BuildContext context) {
    final parsed = parseSenkaMonthKey(widget.state.monthKey);
    final currentDate = senkaBusinessDate(widget.now);
    final year = parsed?.year ?? currentDate.year;
    final month = parsed?.month ?? currentDate.month;
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
            height: widget.compact ? 22 : 32,
            color: const Color(0xff071822),
            padding: EdgeInsets.symmetric(horizontal: widget.compact ? 2 : 6),
            child: Row(
              key: const Key('calendar-weekday-row'),
              children: [
                for (final day in const ['一', '二', '三', '四', '五', '六', '日'])
                  Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: TextStyle(
                          color: const Color(0xff8fa7b7),
                          fontSize: widget.compact ? 11 : 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: widget.compact ? 2 : 6,
                vertical: widget.compact ? 2 : 4,
              ),
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
                                currentDate,
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          Container(
            key: const Key('senka-day-detail'),
            height: widget.compact ? 24 : 38,
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

  Widget _cell(
    int year,
    int month,
    int slot,
    int leading,
    int count,
    DateTime currentDate,
  ) {
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
    final isToday = inMonth &&
        date!.year == currentDate.year &&
        date.month == currentDate.month &&
        date.day == currentDate.day;

    final isFuture = date != null && date.isAfter(currentDate);
    final displayValue = date == null
        ? ''
        : (isFuture && record.total == 0
            ? '-'
            : (record.total == 0
                ? '0.0'
                : record.total.toStringAsFixed(
                    record.total * 10 % 1 == 0 ? 1 : 2,
                  )));

    final Color backgroundColor = chosen
        ? const Color(0xff8a6628)
        : const Color(0xff0b1e2a);

    final Color dayNumberColor = chosen
        ? Colors.white
        : (inMonth ? senkaText : Colors.transparent);

    final Color valueColor = chosen
        ? const Color(0xffffdc88)
        : (isFuture && record.total == 0 ? const Color(0xff627d8e) : senkaGold);

    final Border? border = chosen
        ? Border.all(color: const Color(0xffe4b34e), width: 1.5)
        : (isToday
            ? Border.all(color: const Color(0xff8a6628), width: 1.5)
            : Border.all(color: const Color(0xff1c3545), width: 1));

    final cell = Material(
      key: Key(inMonth ? 'calendar-cell-$day' : 'calendar-cell-out-$slot'),
      color: Colors.transparent,
      child: InkWell(
        onTap: date == null ? null : () => setState(() => selected = date),
        child: inMonth
            ? Container(
                margin: EdgeInsets.all(widget.compact ? 1.5 : 2.5),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(widget.compact ? 5 : 7),
                  border: border,
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$day',
                      style: TextStyle(
                        color: dayNumberColor,
                        fontSize: widget.compact ? 15 : 21,
                        fontWeight: FontWeight.w800,
                        height: 1.05,
                      ),
                    ),
                    SizedBox(height: widget.compact ? 1 : 2),
                    Text(
                      displayValue,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: valueColor,
                        fontSize: widget.compact ? 12 : 16,
                        fontWeight: FontWeight.w700,
                        height: 1.05,
                        fontFeatures: const [
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
    if (date == null) return ExcludeSemantics(child: cell);
    return Semantics(
      button: true,
      selected: chosen,
      label: '$year年$month月$day日，战果${senkaNumber(record.total)}',
      excludeSemantics: true,
      child: cell,
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
            fontSize: widget.compact ? 11 : 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(width: widget.compact ? 2 : 5),
        Flexible(
          child: Text(
            '${value >= 0 ? '+' : ''}${value.toStringAsFixed(2)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: senkaGold,
              fontSize: widget.compact ? 11 : 13,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    ),
  );
}

DateTime _initialSelection(SenkaState state, DateTime now) {
  final currentDate = senkaBusinessDate(now);
  final month = parseSenkaMonthKey(state.monthKey);
  if (month == null) {
    return DateTime(currentDate.year, currentDate.month, currentDate.day);
  }
  return currentDate.year == month.year && currentDate.month == month.month
      ? DateTime(month.year, month.month, currentDate.day)
      : DateTime(month.year, month.month, 1);
}
