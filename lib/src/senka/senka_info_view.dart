import 'package:flutter/material.dart';

import 'senka_catalog.dart';
import 'senka_controller.dart';
import 'senka_state.dart';
import 'senka_ui.dart';

class SenkaInfoView extends StatefulWidget {
  const SenkaInfoView({
    super.key,
    required this.state,
    required this.controller,
    required this.compact,
    this.onOpenSortieLog,
  });
  final SenkaState state;
  final SenkaController controller;
  final bool compact;
  final VoidCallback? onOpenSortieLog;
  @override
  State<SenkaInfoView> createState() => _SenkaInfoViewState();
}

class _SenkaInfoViewState extends State<SenkaInfoView> {
  bool showHidden = false;
  String timeFilter = 'month';

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final horizontal = constraints.maxWidth > constraints.maxHeight * 1.15;
      final server = _ServerOverview(
        state: widget.state,
        compact: widget.compact,
      );
      final ranking = _RankingPanel(
        state: widget.state,
        compact: widget.compact,
      );
      final sorties = _SortiePanel(
        state: widget.state,
        controller: widget.controller,
        compact: widget.compact,
        showHidden: showHidden,
        onShowHidden: (value) => setState(() => showHidden = value),
        timeFilter: timeFilter,
        onTimeFilterChanged: (value) => setState(() => timeFilter = value),
        scrollRows: horizontal,
        onOpenSortieLog: widget.onOpenSortieLog,
      );
      final gap = widget.compact ? 4.0 : 10.0;
      if (horizontal) {
        return Row(
          key: const Key('senka-info-horizontal'),
          children: [
            Expanded(
              key: const Key('senka-info-left'),
              child: Column(
                children: [
                  Expanded(
                    flex: 3,
                    child: SizedBox(
                      key: const Key('senka-info-server'),
                      child: server,
                    ),
                  ),
                  SizedBox(height: gap),
                  Expanded(
                    flex: 7,
                    child: SizedBox(
                      key: const Key('senka-info-ranking'),
                      child: ranking,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: gap),
            Expanded(key: const Key('senka-info-right'), child: sorties),
          ],
        );
      }
      return SingleChildScrollView(
        key: const Key('senka-info-vertical'),
        child: Column(
          children: [
            SizedBox(
              key: const Key('senka-info-server'),
              height: 150,
              child: server,
            ),
            SizedBox(height: gap),
            SizedBox(
              key: const Key('senka-info-ranking'),
              height: 330,
              child: ranking,
            ),
            SizedBox(height: gap),
            SizedBox(
              key: const Key('senka-info-sorties'),
              height: _sortiePanelHeight(
                widget.state,
                showHidden,
                widget.compact,
              ),
              child: sorties,
            ),
          ],
        ),
      );
    },
  );
}

double _sortiePanelHeight(SenkaState state, bool showHidden, bool compact) {
  final rowCount = state.sortieStats.values
      .where(
        (item) =>
            showHidden || !state.hiddenSortieMapKeys.contains(item.mapKey),
      )
      .length;
  const panelHeaderHeight = 44.0;
  final subHeaderHeight = compact ? 26.0 : 34.0;
  const filterBarHeight = 44.0;
  final tableHeaderHeight = compact ? 26.0 : 34.0;
  const dataRowHeight = 44.0;
  return panelHeaderHeight +
      subHeaderHeight +
      filterBarHeight +
      tableHeaderHeight +
      rowCount * dataRowHeight +
      8;
}

class _ServerOverview extends StatelessWidget {
  const _ServerOverview({required this.state, required this.compact});
  final SenkaState state;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final current = state.playerRankingRow;
    return Material(
      color: senkaPanel,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: senkaLine),
        borderRadius: BorderRadius.circular(compact ? 7 : 11),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 16,
          vertical: compact ? 6 : 10,
        ),
        child: Row(
          children: [
            Expanded(
              flex: 50,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '所在服务器',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: senkaMuted,
                      fontSize: compact ? 10 : 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: compact ? 2 : 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      senkaServerName(state.serverOrigin),
                      maxLines: 1,
                      style: TextStyle(
                        color: senkaText,
                        fontSize: compact ? 16 : 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 1,
              height: compact ? 44 : 60,
              color: senkaLine,
              margin: EdgeInsets.symmetric(horizontal: compact ? 10 : 18),
            ),
            Expanded(
              flex: 50,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Text(
                        '战果',
                        style: TextStyle(
                          color: senkaMuted,
                          fontSize: compact ? 11 : 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            senkaNumber(current.senka),
                            style: TextStyle(
                              color: senkaYellow,
                              fontSize: compact ? 22 : 30,
                              fontWeight: FontWeight.w900,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: compact ? 8 : 12),
                  Row(
                    children: [
                      Text(
                        '排名',
                        style: TextStyle(
                          color: senkaMuted,
                          fontSize: compact ? 11 : 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            senkaInteger(current.rank),
                            style: TextStyle(
                              color: senkaYellow,
                              fontSize: compact ? 22 : 30,
                              fontWeight: FontWeight.w900,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RankingPanel extends StatelessWidget {
  const _RankingPanel({required this.state, required this.compact});
  final SenkaState state;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final timeStr = _formatRankingTime(state.latestRankingUpdatedAt);
    return SenkaPanel(
      title: '战果排名',
      compact: compact,
      trailing: Text(
        '更新：$timeStr',
        style: TextStyle(
          color: senkaMuted,
          fontSize: compact ? 9 : 11,
          fontWeight: FontWeight.w600,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 4 : 8),
        child: Column(
          children: [
            Expanded(child: _row('顺位', '战果', '变化', compact, header: true)),
            for (final rank in const [5, 20, 100, 501])
              Expanded(
                key: Key('ranking-row-$rank'),
                child: _anchorRow(rank, state.rankingRow(rank), compact),
              ),
            Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              child: Text(
                '当前',
                style: TextStyle(
                  color: senkaMuted,
                  fontSize: compact ? 9 : 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(child: _playerRow(state.playerRankingRow, compact)),
          ],
        ),
      ),
    );
  }

  Widget _anchorRow(int rank, SenkaRankingRow row, bool compact) =>
      DecoratedBox(
        decoration: BoxDecoration(
          color: senkaPanelAlt,
          borderRadius: BorderRadius.circular(4),
        ),
        child: _row(
          '$rank',
          senkaNumber(row.senka),
          _delta(row.senkaDelta),
          compact,
          deltaColor: _deltaColor(row.senkaDelta),
          deltaKey: Key('ranking-delta-$rank'),
        ),
      );

  Widget _playerRow(SenkaRankingRow row, bool compact) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xff0b1e2a),
      border: Border.all(color: const Color(0xff8a6628), width: 1.2),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      children: [
        Expanded(
          flex: 42,
          child: Row(
            key: const Key('player-rank-subcolumns'),
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Text(
                    senkaInteger(row.rank),
                    key: const Key('player-rank'),
                    style: _style(compact).copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  _rankDelta(row),
                  style: _style(compact).copyWith(
                    color: _rankColor(row.rankDirection),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 30,
          child: Text(
            senkaNumber(row.senka),
            key: const Key('player-senka'),
            style: _style(compact).copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        Expanded(
          flex: 28,
          child: Text(
            _delta(row.senkaDelta),
            key: const Key('player-senka-delta'),
            style: _style(
              compact,
            ).copyWith(color: senkaGreen, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
}

Widget _row(
  String rank,
  String senka,
  String delta,
  bool compact, {
  bool header = false,
  Color? deltaColor,
  Key? deltaKey,
}) => Row(
  children: [
    Expanded(
      flex: 42,
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(rank, maxLines: 1, style: _style(compact, header: header)),
      ),
    ),
    Expanded(
      flex: 30,
      child: Text(senka, maxLines: 1, style: _style(compact, header: header)),
    ),
    Expanded(
      flex: 28,
      child: Text(
        delta,
        key: deltaKey,
        maxLines: 1,
        style: _style(compact, header: header).copyWith(color: deltaColor),
      ),
    ),
  ],
);

TextStyle _style(bool compact, {bool header = false}) => TextStyle(
  color: senkaText,
  fontSize: compact ? 10 : 14,
  fontWeight: header ? FontWeight.w800 : FontWeight.w700,
  fontFeatures: const [FontFeature.tabularFigures()],
);
String _delta(double? value) => value == null
    ? '--'
    : '${value >= 0 ? '+' : ''}${value.toStringAsFixed(2)}';
Color _deltaColor(double? value) => value == null || value == 0
    ? senkaText
    : value > 0
    ? senkaGreen
    : senkaRed;
String _rankDelta(SenkaRankingRow row) => switch (row.rankDirection) {
  SenkaRankDirection.up || SenkaRankDirection.same => '↑${row.rankDelta ?? 0}',
  SenkaRankDirection.down => '↓${row.rankDelta ?? 0}',
  SenkaRankDirection.unknown => '--',
};
Color _rankColor(SenkaRankDirection direction) =>
    direction == SenkaRankDirection.down
    ? senkaRed
    : direction == SenkaRankDirection.unknown
    ? senkaText
    : senkaGreen;

class _SortiePanel extends StatelessWidget {
  const _SortiePanel({
    required this.state,
    required this.controller,
    required this.compact,
    required this.showHidden,
    required this.onShowHidden,
    required this.timeFilter,
    required this.onTimeFilterChanged,
    required this.scrollRows,
    this.onOpenSortieLog,
  });
  final SenkaState state;
  final SenkaController controller;
  final bool compact;
  final bool showHidden;
  final ValueChanged<bool> onShowHidden;
  final String timeFilter;
  final ValueChanged<String> onTimeFilterChanged;
  final bool scrollRows;
  final VoidCallback? onOpenSortieLog;

  @override
  Widget build(BuildContext context) {
    final rows =
        state.sortieStats.values
            .where(
              (item) =>
                  showHidden ||
                  !state.hiddenSortieMapKeys.contains(item.mapKey),
            )
            .toList()
          ..sort((a, b) {
            final favorite =
                (state.favoriteSortieMapKeys.contains(b.mapKey) ? 1 : 0) -
                (state.favoriteSortieMapKeys.contains(a.mapKey) ? 1 : 0);
            return favorite != 0 ? favorite : a.mapKey.compareTo(b.mapKey);
          });

    final totalSorties = rows.fold<int>(0, (sum, s) => sum + s.sorties);
    final totalBoss = rows.fold<int>(0, (sum, s) => sum + s.bossArrivals);
    final totalS = rows.fold<int>(0, (sum, s) => sum + s.sWins);

    return SenkaPanel(
      title: '出击海域统计',
      compact: compact,
      headerHeight: compact ? 34 : 44,
      trailing: Semantics(
        button: true,
        label: '最近记录',
        excludeSemantics: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: const Key('senka-recent-records'),
            onTap: onOpenSortieLog,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xff142b3a),
                border: Border.all(color: const Color(0xff2a4c62)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '最近记录',
                style: TextStyle(
                  color: senkaText,
                  fontSize: compact ? 10 : 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
      child: Column(
        children: [
          Container(
            height: compact ? 26 : 34,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(
              color: Color(0xff071822),
              border: Border(bottom: BorderSide(color: senkaLine)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _summaryMetric('本月出击', '$totalSorties', compact),
                _summaryMetric('Boss 到达', '$totalBoss', compact),
                _summaryMetric('S 胜', '$totalS', compact),
              ],
            ),
          ),
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Container(
                  height: compact ? 24 : 28,
                  decoration: BoxDecoration(
                    color: const Color(0xff0b1e2a),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: senkaLine),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _timeFilterButton(
                        '本月',
                        'month',
                        timeFilter == 'month',
                        compact,
                      ),
                      _timeFilterButton(
                        '今日',
                        'today',
                        timeFilter == 'today',
                        compact,
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Semantics(
                  label: '显示隐藏海域',
                  button: true,
                  toggled: showHidden,
                  excludeSemantics: true,
                  child: Container(
                    key: const Key('senka-show-hidden'),
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    child: InkWell(
                      onTap: () => onShowHidden(!showHidden),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Icon(
                            showHidden
                                ? Icons.check_box
                                : Icons.check_box_outline_blank,
                            size: compact ? 14 : 18,
                            color: showHidden ? senkaGold : senkaMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '显示已隐藏',
                            style: TextStyle(
                              color: showHidden ? senkaText : senkaMuted,
                              fontSize: compact ? 10 : 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: compact ? 26 : 34,
            decoration: const BoxDecoration(
              color: Color(0xff091a26),
              border: Border(
                top: BorderSide(color: senkaLine),
                bottom: BorderSide(color: senkaLine),
              ),
            ),
            child: _sortieRow(
              const ['海域', 'Boss', '出击', 'S / A', '操作'],
              compact,
              header: true,
            ),
          ),
          if (scrollRows)
            Expanded(
              child: ListView.builder(
                itemCount: rows.length,
                itemBuilder: (context, index) =>
                    _sortieData(rows[index], index),
              ),
            )
          else
            for (var i = 0; i < rows.length; i++) _sortieData(rows[i], i),
        ],
      ),
    );
  }

  Widget _summaryMetric(String label, String value, bool compact) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        label,
        style: TextStyle(
          color: senkaMuted,
          fontSize: compact ? 9 : 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(width: 6),
      Text(
        value,
        style: TextStyle(
          color: senkaText,
          fontSize: compact ? 11 : 14,
          fontWeight: FontWeight.w900,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    ],
  );

  Widget _timeFilterButton(
    String label,
    String value,
    bool active,
    bool compact,
  ) => Material(
    color: active ? const Color(0xff3b2f1e) : Colors.transparent,
    borderRadius: BorderRadius.circular(5),
    child: InkWell(
      onTap: () => onTimeFilterChanged(value),
      borderRadius: BorderRadius.circular(5),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 12,
          vertical: compact ? 2 : 4,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? const Color(0xffffdc88) : senkaMuted,
            fontSize: compact ? 10 : 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ),
  );

  Widget _sortieData(SenkaSortieStats stats, int index) {
    final isFavorite = state.favoriteSortieMapKeys.contains(stats.mapKey);
    final isHidden = state.hiddenSortieMapKeys.contains(stats.mapKey);
    final isEven = index % 2 == 0;
    final rowBg = isFavorite
        ? const Color(0xff182c2b)
        : (isEven ? const Color(0xff0d2230) : const Color(0xff06141e));
    final rowHeight = compact ? 30.0 : 36.0;

    return SizedBox(
      key: Key('senka-sortie-row-${stats.mapKey}'),
      height: rowHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: rowBg,
          border: Border(
            top: const BorderSide(color: Color(0xff173245), width: 0.5),
            bottom: const BorderSide(color: Color(0xff173245), width: 0.5),
            left: isFavorite
                ? const BorderSide(color: senkaGold, width: 3.0)
                : BorderSide.none,
          ),
        ),
        child: Row(
          children: [
            _cell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isFavorite)
                    Text(
                      '★ ',
                      style: _sortieStyle(compact).copyWith(color: senkaGold),
                    ),
                  Text(
                    stats.mapKey,
                    maxLines: 1,
                    style: _sortieStyle(compact).copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              20,
            ),
            _cell(
              Text(
                '${stats.bossArrivals}',
                maxLines: 1,
                style: _sortieStyle(compact).copyWith(
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              14,
            ),
            _cell(
              Text(
                '${stats.sorties}',
                maxLines: 1,
                style: _sortieStyle(compact).copyWith(
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              14,
            ),
            _cell(
              Text(
                '${stats.sWins} / ${stats.aWins}',
                maxLines: 1,
                style: _sortieStyle(compact).copyWith(
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              20,
            ),
            Expanded(
              flex: 26,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Tooltip(
                    message: '收藏海域 ${stats.mapKey}',
                    child: Semantics(
                      button: true,
                      toggled: isFavorite,
                      label: '收藏海域 ${stats.mapKey}',
                      excludeSemantics: true,
                      child: SizedBox(
                        key: Key('senka-favorite-${stats.mapKey}'),
                        width: rowHeight,
                        height: rowHeight,
                        child: InkWell(
                          onTap: () =>
                              controller.toggleSortieFavorite(stats.mapKey),
                          child: Center(
                            child: Icon(
                              isFavorite ? Icons.star : Icons.star_border,
                              size: compact ? 17 : 20,
                              color: isFavorite ? senkaGold : senkaMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Tooltip(
                    message: '隐藏海域 ${stats.mapKey}',
                    child: Semantics(
                      button: true,
                      toggled: isHidden,
                      label: '隐藏海域 ${stats.mapKey}',
                      excludeSemantics: true,
                      child: SizedBox(
                        key: Key('senka-hide-${stats.mapKey}'),
                        width: rowHeight,
                        height: rowHeight,
                        child: InkWell(
                          onTap: () =>
                              controller.toggleSortieHidden(stats.mapKey),
                          child: Center(
                            child: Icon(
                              Icons.block,
                              size: compact ? 15 : 18,
                              color: isHidden ? senkaRed : senkaMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _sortieRow(
  List<String> values,
  bool compact, {
  bool header = false,
}) => Row(
  children: [
    _cell(Text(values[0], style: _sortieStyle(compact, header: header)), 20),
    _cell(Text(values[1], style: _sortieStyle(compact, header: header)), 14),
    _cell(Text(values[2], style: _sortieStyle(compact, header: header)), 14),
    _cell(Text(values[3], style: _sortieStyle(compact, header: header)), 20),
    _cell(Text(values[4], style: _sortieStyle(compact, header: header)), 26),
  ],
);
Widget _cell(Widget child, int flex) => Expanded(
  flex: flex,
  child: Center(child: child),
);
TextStyle _sortieStyle(bool compact, {bool header = false}) => TextStyle(
  color: header ? senkaMuted : senkaText,
  fontSize: compact ? 10 : 13,
  fontWeight: header ? FontWeight.w800 : FontWeight.w700,
  fontFeatures: const [FontFeature.tabularFigures()],
);

String _formatRankingTime(DateTime? time) {
  if (time == null) return '--';
  final t = time.toLocal();
  final year = t.year.toString().padLeft(4, '0');
  final month = t.month.toString().padLeft(2, '0');
  final day = t.day.toString().padLeft(2, '0');
  final hour = t.hour.toString().padLeft(2, '0');
  final minute = t.minute.toString().padLeft(2, '0');
  final second = t.second.toString().padLeft(2, '0');
  return '$year-$month-$day $hour:$minute:$second';
}
