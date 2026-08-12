import 'package:flutter/material.dart';

import '../layout/adaptive_layout.dart';
import 'senka_catalog.dart';
import 'senka_controller.dart';
import 'senka_state.dart';

const _background = Color(0xff071520);
const _panel = Color(0xff102432);
const _panelAlt = Color(0xff0d202d);
const _line = Color(0xff294657);
const _text = Color(0xffe7eef2);
const _muted = Color(0xff8198a7);
const _gold = Color(0xffd7a957);
const _green = Color(0xff5dc9a5);
const _yellow = Color(0xffe4b34e);

class SenkaPage extends StatefulWidget {
  const SenkaPage({super.key, required this.controller, this.now});

  final SenkaController controller;
  final DateTime? now;

  @override
  State<SenkaPage> createState() => _SenkaPageState();
}

class _SenkaPageState extends State<SenkaPage> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = widget.now ?? toJst(DateTime.now().toUtc());
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: _background,
    child: AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) {
          final portrait = usesVerticalWorkspace(
            Size(constraints.maxWidth, constraints.maxHeight),
          );
          final compact =
              constraints.maxHeight <= 450 ||
              (portrait && constraints.maxWidth > constraints.maxHeight);
          final gap = compact ? 4.0 : 10.0;
          final padding = compact ? 4.0 : 10.0;
          final state = widget.controller.state;
          final ranking = _RankingPanel(state: state, compact: compact);
          final matrix = _MatrixPanel(
            state: state,
            compact: compact,
            onToggleEo: widget.controller.toggleEo,
            onToggleQuest: widget.controller.toggleQuest,
          );
          final calendar = _CalendarPanel(
            state: state,
            compact: compact,
            selectedDate: _selectedDate,
            now: widget.now ?? toJst(DateTime.now().toUtc()),
            onSelected: (date) => setState(() => _selectedDate = date),
          );
          return Padding(
            padding: EdgeInsets.all(padding),
            child: portrait
                ? Column(
                    key: const Key('senka-portrait-layout'),
                    children: [
                      Expanded(flex: 90, child: ranking),
                      SizedBox(height: gap),
                      Expanded(flex: 60, child: matrix),
                      SizedBox(height: gap),
                      Expanded(flex: 125, child: calendar),
                    ],
                  )
                : Row(
                    key: const Key('senka-landscape-layout'),
                    children: [
                      Expanded(
                        flex: 42,
                        child: Column(
                          children: [
                            Expanded(flex: 60, child: ranking),
                            SizedBox(height: gap),
                            Expanded(flex: 40, child: matrix),
                          ],
                        ),
                      ),
                      SizedBox(width: gap),
                      Expanded(flex: 58, child: calendar),
                    ],
                  ),
          );
        },
      ),
    ),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.compact,
    required this.child,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final bool compact;
  final Widget child;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: _panel,
      border: Border.all(color: _line),
      borderRadius: BorderRadius.circular(compact ? 8 : 12),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(compact ? 7 : 11),
      child: Column(
        children: [
          SizedBox(
            height: compact ? 24 : 36,
            child: ColoredBox(
              color: _panelAlt,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 11),
                child: Row(
                  children: [
                    Expanded(
                      child: subtitle == null
                          ? _titleText(title, compact)
                          : Row(
                              children: [
                                _titleText(title, compact),
                                SizedBox(width: compact ? 5 : 8),
                                Expanded(
                                  child: Text(
                                    subtitle!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: _muted,
                                      fontSize: compact ? 9 : 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                    ?trailing,
                  ],
                ),
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    ),
  );

  Widget _titleText(String value, bool compact) => Text(
    value,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      color: _text,
      fontSize: compact ? 12 : 15,
      fontWeight: FontWeight.w800,
    ),
  );
}

class _RankingPanel extends StatelessWidget {
  const _RankingPanel({required this.state, required this.compact});

  final SenkaState state;
  final bool compact;

  @override
  Widget build(BuildContext context) => _Panel(
    title: '战果信息',
    subtitle: _rankingUpdateText(state.latestRankingUpdatedAt),
    compact: compact,
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 4 : 8,
        compact ? 2 : 5,
        compact ? 4 : 8,
        compact ? 3 : 6,
      ),
      child: Column(
        children: [
          Expanded(
            key: const Key('ranking-header-row'),
            child: _rankingColumns(
              compact,
              const Text('顺位'),
              const Text('战果'),
              const Text('变化'),
              header: true,
            ),
          ),
          for (final rank in const [5, 20, 100, 501])
            Expanded(
              key: Key('ranking-row-$rank'),
              child: Padding(
                padding: EdgeInsets.only(top: compact ? 1 : 2),
                child: _AnchorRow(
                  row: state.rankingRow(rank),
                  expectedRank: rank,
                  compact: compact,
                ),
              ),
            ),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 3),
                child: Text(
                  '当前',
                  style: TextStyle(
                    color: _text,
                    fontSize: compact ? 10 : 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: _PlayerRow(row: state.playerRankingRow, compact: compact),
          ),
        ],
      ),
    ),
  );
}

Widget _rankingColumns(
  bool compact,
  Widget rank,
  Widget senka,
  Widget delta, {
  bool header = false,
}) {
  final style = TextStyle(
    color: header ? _text : _text,
    fontSize: compact ? 10 : 14,
    fontWeight: header ? FontWeight.w800 : FontWeight.w700,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
  Widget styled(Widget child) => DefaultTextStyle(style: style, child: child);
  return Row(
    children: [
      Expanded(
        flex: 48,
        child: Padding(
          padding: const EdgeInsets.only(left: 3),
          child: styled(rank),
        ),
      ),
      Expanded(flex: 27, child: styled(senka)),
      Expanded(flex: 25, child: styled(delta)),
    ],
  );
}

class _AnchorRow extends StatelessWidget {
  const _AnchorRow({
    required this.row,
    required this.expectedRank,
    required this.compact,
  });

  final SenkaRankingRow row;
  final int expectedRank;
  final bool compact;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: _panelAlt,
      borderRadius: BorderRadius.circular(compact ? 3 : 5),
    ),
    child: _rankingColumns(
      compact,
      Text('$expectedRank'),
      Text(_number(row.senka)),
      Text(
        _senkaDelta(row.senkaDelta),
        key: Key('ranking-delta-$expectedRank'),
        style: TextStyle(color: _senkaDeltaColor(row.senkaDelta)),
      ),
    ),
  );
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({required this.row, required this.compact});

  final SenkaRankingRow row;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final fontSize = compact ? 10.0 : 14.0;
    final style = TextStyle(
      color: _text,
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _yellow.withValues(alpha: 0.15),
        border: Border.all(color: _yellow.withValues(alpha: 0.65)),
        borderRadius: BorderRadius.circular(compact ? 4 : 7),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 48,
            child: Padding(
              padding: const EdgeInsets.only(left: 3),
              child: Row(
                key: const Key('player-rank-subcolumns'),
                children: [
                  Expanded(
                    flex: 5625,
                    child: Text(
                      _integer(row.rank),
                      key: const Key('player-rank'),
                      style: style,
                    ),
                  ),
                  Expanded(
                    flex: 4375,
                    child: Text(
                      _rankDelta(row),
                      key: const Key('player-rank-delta'),
                      style: style.copyWith(
                        color: _rankColor(row.rankDirection),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 27,
            child: Text(
              _number(row.senka),
              key: const Key('player-senka'),
              style: style,
            ),
          ),
          Expanded(
            flex: 25,
            child: Text(
              _senkaDelta(row.senkaDelta),
              key: const Key('player-senka-delta'),
              style: style.copyWith(color: _green),
            ),
          ),
        ],
      ),
    );
  }
}

class _MatrixPanel extends StatelessWidget {
  const _MatrixPanel({
    required this.state,
    required this.compact,
    required this.onToggleEo,
    required this.onToggleQuest,
  });

  final SenkaState state;
  final bool compact;
  final ValueChanged<int> onToggleEo;
  final ValueChanged<int> onToggleQuest;

  @override
  Widget build(BuildContext context) {
    final items = <({SenkaCatalogItem item, bool quest})>[
      for (final item in senkaEoCatalog) (item: item, quest: false),
      for (final item in senkaQuestCatalog) (item: item, quest: true),
    ];
    return _Panel(
      title: 'EO 与战果任务',
      compact: compact,
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(compact ? 3 : 6),
              child: Column(
                children: [
                  for (var row = 0; row < 4; row++)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          bottom: row == 3 ? 0 : (compact ? 2 : 4),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var column = 0; column < 4; column++)
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    right: column == 3 ? 0 : (compact ? 2 : 4),
                                  ),
                                  child: _MatrixCell(
                                    key: Key(
                                      'senka-cell-${items[row * 4 + column].quest ? 'quest' : 'eo'}-${items[row * 4 + column].item.id}',
                                    ),
                                    item: items[row * 4 + column].item,
                                    quest: items[row * 4 + column].quest,
                                    completed: items[row * 4 + column].quest
                                        ? state.completedQuestIds.contains(
                                            items[row * 4 + column].item.id,
                                          )
                                        : state.completedEoIds.contains(
                                            items[row * 4 + column].item.id,
                                          ),
                                    compact: compact,
                                    onToggle: items[row * 4 + column].quest
                                        ? onToggleQuest
                                        : onToggleEo,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(
            key: const Key('senka-month-summary'),
            height: compact ? 24 : 30,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: _line)),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '已选择战果奖励',
                      style: TextStyle(
                        color: _text,
                        fontSize: compact ? 10 : 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(width: compact ? 5 : 8),
                    Text(
                      '+${state.completedSenka}',
                      style: TextStyle(
                        color: _gold,
                        fontSize: compact ? 10 : 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MatrixCell extends StatelessWidget {
  const _MatrixCell({
    super.key,
    required this.item,
    required this.quest,
    required this.completed,
    required this.compact,
    required this.onToggle,
  });

  final SenkaCatalogItem item;
  final bool quest;
  final bool completed;
  final bool compact;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    final color = completed ? _green : _yellow;
    return Material(
      color: color.withValues(alpha: 0.13),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: color.withValues(alpha: 0.7)),
        borderRadius: BorderRadius.circular(compact ? 3 : 5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              key: Key('senka-toggle-${quest ? 'quest' : 'eo'}-${item.id}'),
              onTap: () => onToggle(item.id),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 5),
                child: Row(
                  children: [
                    Text(
                      completed ? '✓' : '×',
                      style: TextStyle(
                        color: color,
                        fontSize: compact ? 10 : 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          item.matrixLabel,
                          maxLines: 1,
                          style: TextStyle(
                            color: color,
                            fontSize: compact ? 10 : 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarPanel extends StatelessWidget {
  const _CalendarPanel({
    required this.state,
    required this.compact,
    required this.selectedDate,
    required this.now,
    required this.onSelected,
  });

  final SenkaState state;
  final bool compact;
  final DateTime selectedDate;
  final DateTime now;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final parts = state.monthKey.split('-');
    final year = int.tryParse(parts.first) ?? now.year;
    final month = parts.length > 1
        ? int.tryParse(parts[1]) ?? now.month
        : now.month;
    final first = DateTime(year, month, 1);
    final leading = first.weekday - 1;
    final dayCount = DateTime(year, month + 1, 0).day;
    final selected = selectedDate.year == year && selectedDate.month == month
        ? selectedDate
        : DateTime(year, month, 1);
    final record = state.day(selected);
    return _Panel(
      title: '$year年$month月战果日历',
      compact: compact,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '本月已记录 ',
            style: TextStyle(
              color: _text,
              fontSize: compact ? 12 : 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            _plain(state.monthRecorded),
            style: TextStyle(
              color: _gold,
              fontSize: compact ? 12 : 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            key: const Key('calendar-weekday-row'),
            child: ColoredBox(
              key: const Key('calendar-weekday-background'),
              color: const Color(0xff071923),
              child: Row(
                children: [
                  for (final weekday in const [
                    '一',
                    '二',
                    '三',
                    '四',
                    '五',
                    '六',
                    '日',
                  ])
                    Expanded(
                      child: Center(
                        child: Text(
                          weekday,
                          style: TextStyle(
                            color: _text,
                            fontSize: compact ? 10 : 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: compact ? 3 : 6),
              child: Column(
                children: [
                  for (var row = 0; row < 6; row++)
                    Expanded(
                      key: Key('calendar-week-row-$row'),
                      child: Row(
                        children: [
                          for (var column = 0; column < 7; column++)
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.all(compact ? 1 : 2),
                                child: _CalendarCell(
                                  key: Key('calendar-cell-${row * 7 + column}'),
                                  day: row * 7 + column - leading + 1,
                                  dayCount: dayCount,
                                  year: year,
                                  month: month,
                                  now: now,
                                  selectedDate: selected,
                                  state: state,
                                  compact: compact,
                                  onSelected: onSelected,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(
            key: const Key('senka-day-detail'),
            height: compact ? 24 : 30,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: _line)),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 9),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _detailLabel('经验', compact),
                    _detailValue(_signed(record.experience), compact),
                    _detailLabel('EO', compact),
                    _detailValue(_signed(record.eo), compact),
                    _detailLabel('任务', compact),
                    _detailValue(_signed(record.quest), compact),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailLabel(String value, bool compact) => Padding(
    padding: EdgeInsets.only(left: compact ? 3 : 8),
    child: Text(
      value,
      style: TextStyle(
        color: _text,
        fontSize: compact ? 10 : 14,
        fontWeight: FontWeight.w800,
      ),
    ),
  );

  Widget _detailValue(String value, bool compact) => Padding(
    padding: EdgeInsets.only(left: compact ? 2 : 4),
    child: Text(
      value,
      style: TextStyle(
        color: _gold,
        fontSize: compact ? 10 : 14,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _CalendarCell extends StatelessWidget {
  const _CalendarCell({
    super.key,
    required this.day,
    required this.dayCount,
    required this.year,
    required this.month,
    required this.now,
    required this.selectedDate,
    required this.state,
    required this.compact,
    required this.onSelected,
  });

  final int day;
  final int dayCount;
  final int year;
  final int month;
  final DateTime now;
  final DateTime selectedDate;
  final SenkaState state;
  final bool compact;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    if (day < 1 || day > dayCount) return const SizedBox.expand();
    final date = DateTime(year, month, day);
    final selected = date == selectedDate;
    final record = state.day(date);
    final isFuture = date.isAfter(DateTime(now.year, now.month, now.day));
    return Material(
      color: selected ? const Color(0xff2d78d2) : _panelAlt,
      borderRadius: BorderRadius.circular(compact ? 3 : 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(compact ? 3 : 6),
        onTap: () => onSelected(date),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$day',
              style: TextStyle(
                color: _text,
                fontSize: compact ? 16 : 18,
                height: 1,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: compact ? 2 : 3),
            Text(
              isFuture ? '-' : _plain(record.total),
              style: TextStyle(
                color: _gold,
                fontSize: compact ? 12 : 14,
                height: 1,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _integer(int? value) => value == null ? '-' : _withCommas(value);

String _number(double? value) {
  if (value == null) return '-';
  if (value == value.roundToDouble()) return _withCommas(value.round());
  return value.toStringAsFixed(1);
}

String _plain(double value) => value.toStringAsFixed(1);

String _signed(double value) => '+${value.toStringAsFixed(1)}';

String? _rankingUpdateText(DateTime? value) {
  if (value == null) return null;
  final jst = toJst(value);
  String two(int part) => part.toString().padLeft(2, '0');
  return '更新：${jst.year}-${two(jst.month)}-${two(jst.day)} '
      '${two(jst.hour)}:${two(jst.minute)}:${two(jst.second)}';
}

String _senkaDelta(double? value) {
  if (value == null) return '-';
  final arrow = value < 0 ? '↓' : '↑';
  final absolute = value.abs();
  return '$arrow${absolute == absolute.roundToDouble() ? absolute.round() : absolute.toStringAsFixed(1)}';
}

Color _senkaDeltaColor(double? value) {
  if (value == null || value == 0) return _text;
  return value > 0 ? _green : const Color(0xffec7777);
}

String _rankDelta(SenkaRankingRow row) => switch (row.rankDirection) {
  SenkaRankDirection.up => '↑${row.rankDelta ?? 0}',
  SenkaRankDirection.down => '↓${row.rankDelta ?? 0}',
  SenkaRankDirection.same => '↑0',
  SenkaRankDirection.unknown => '-',
};

Color _rankColor(SenkaRankDirection direction) => switch (direction) {
  SenkaRankDirection.up => _green,
  SenkaRankDirection.down => const Color(0xffec7777),
  _ => _muted,
};

String _withCommas(int value) {
  final negative = value < 0;
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
    buffer.write(digits[index]);
  }
  return negative ? '-$buffer' : '$buffer';
}
