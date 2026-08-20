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
  });
  final SenkaState state;
  final SenkaController controller;
  final bool compact;
  @override
  State<SenkaInfoView> createState() => _SenkaInfoViewState();
}

class _SenkaInfoViewState extends State<SenkaInfoView> {
  bool showHidden = false;
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
        scrollRows: horizontal,
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
  final tableHeaderHeight = compact ? 28.0 : 36.0;
  const dataRowHeight = 44.0;
  return panelHeaderHeight + tableHeaderHeight + rowCount * dataRowHeight + 2;
}

class _ServerOverview extends StatelessWidget {
  const _ServerOverview({required this.state, required this.compact});
  final SenkaState state;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final current = state.playerRankingRow;
    return SenkaPanel(
      title: '服务器概况',
      compact: compact,
      child: Padding(
        padding: EdgeInsets.all(compact ? 7 : 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            SenkaLabelValue(
              '所在服务器',
              senkaServerName(state.serverOrigin),
              compact: compact,
            ),
            SenkaLabelValue(
              '当前战果',
              senkaNumber(current.senka),
              compact: compact,
            ),
            SenkaLabelValue(
              '当前排名',
              senkaInteger(current.rank),
              compact: compact,
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
  Widget build(BuildContext context) => SenkaPanel(
    title: '战果排名',
    compact: compact,
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
          Expanded(child: _playerRow(state.playerRankingRow, compact)),
        ],
      ),
    ),
  );

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
      color: senkaYellow.withValues(alpha: .14),
      border: Border.all(color: senkaYellow.withValues(alpha: .65)),
      borderRadius: BorderRadius.circular(5),
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
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    senkaInteger(row.rank),
                    key: const Key('player-rank'),
                    style: _style(compact),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  _rankDelta(row),
                  style: _style(
                    compact,
                  ).copyWith(color: _rankColor(row.rankDirection)),
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
            style: _style(compact),
          ),
        ),
        Expanded(
          flex: 28,
          child: Text(
            _delta(row.senkaDelta),
            key: const Key('player-senka-delta'),
            style: _style(compact).copyWith(color: senkaGreen),
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
    required this.scrollRows,
  });
  final SenkaState state;
  final SenkaController controller;
  final bool compact;
  final bool showHidden;
  final ValueChanged<bool> onShowHidden;
  final bool scrollRows;
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
    return SenkaPanel(
      title: '出击海域统计',
      compact: compact,
      headerHeight: 44,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '显示隐藏',
            style: TextStyle(color: senkaMuted, fontSize: compact ? 9 : 12),
          ),
          SizedBox(width: compact ? 2 : 4),
          Semantics(
            label: '显示隐藏海域',
            button: true,
            toggled: showHidden,
            excludeSemantics: true,
            child: SizedBox(
              key: const Key('senka-show-hidden'),
              width: 44,
              height: 44,
              child: InkWell(
                onTap: () => onShowHidden(!showHidden),
                child: Center(
                  child: SizedBox(
                    width: compact ? 30 : 38,
                    height: compact ? 24 : 30,
                    child: FittedBox(
                      child: IgnorePointer(
                        child: Switch(
                          value: showHidden,
                          activeThumbColor: senkaGold,
                          onChanged: (_) {},
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: compact ? 28 : 36,
            child: _sortieRow(
              const ['海域', 'Boss', '出击', 'S', 'A', '操作'],
              compact,
              header: true,
            ),
          ),
          if (scrollRows)
            Expanded(
              child: ListView.builder(
                itemCount: rows.length,
                itemBuilder: (context, index) => _sortieData(rows[index]),
              ),
            )
          else
            for (final row in rows) _sortieData(row),
        ],
      ),
    );
  }

  Widget _sortieData(SenkaSortieStats stats) => SizedBox(
    key: Key('senka-sortie-row-${stats.mapKey}'),
    height: 44,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: state.favoriteSortieMapKeys.contains(stats.mapKey)
            ? senkaGold.withValues(alpha: .08)
            : Colors.transparent,
        border: const Border(top: BorderSide(color: senkaLine)),
      ),
      child: Row(
        children: [
          _cell(
            Text(stats.mapKey, maxLines: 1, style: _sortieStyle(compact)),
            18,
          ),
          _cell(
            Text(
              '${stats.bossArrivals}',
              maxLines: 1,
              style: _sortieStyle(compact),
            ),
            14,
          ),
          _cell(
            Text('${stats.sorties}', maxLines: 1, style: _sortieStyle(compact)),
            14,
          ),
          _cell(
            Text('${stats.sWins}', maxLines: 1, style: _sortieStyle(compact)),
            10,
          ),
          _cell(
            Text('${stats.aWins}', maxLines: 1, style: _sortieStyle(compact)),
            10,
          ),
          Expanded(
            flex: 28,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Tooltip(
                  message: '收藏海域 ${stats.mapKey}',
                  child: Semantics(
                    button: true,
                    toggled: state.favoriteSortieMapKeys.contains(stats.mapKey),
                    label: '收藏海域 ${stats.mapKey}',
                    excludeSemantics: true,
                    child: SizedBox(
                      key: Key('senka-favorite-${stats.mapKey}'),
                      width: 44,
                      height: 44,
                      child: InkWell(
                        onTap: () =>
                            controller.toggleSortieFavorite(stats.mapKey),
                        child: Center(
                          child: Text(
                            '★',
                            style: _sortieStyle(compact).copyWith(
                              color:
                                  state.favoriteSortieMapKeys.contains(
                                    stats.mapKey,
                                  )
                                  ? senkaGold
                                  : senkaMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Tooltip(
                  message: '隐藏海域 ${stats.mapKey}',
                  child: Semantics(
                    button: true,
                    toggled: state.hiddenSortieMapKeys.contains(stats.mapKey),
                    label: '隐藏海域 ${stats.mapKey}',
                    excludeSemantics: true,
                    child: SizedBox(
                      key: Key('senka-hide-${stats.mapKey}'),
                      width: 44,
                      height: 44,
                      child: InkWell(
                        onTap: () =>
                            controller.toggleSortieHidden(stats.mapKey),
                        child: Center(
                          child: Text(
                            '⊘',
                            style: _sortieStyle(compact).copyWith(
                              color:
                                  state.hiddenSortieMapKeys.contains(
                                    stats.mapKey,
                                  )
                                  ? senkaRed
                                  : senkaMuted,
                            ),
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

Widget _sortieRow(
  List<String> values,
  bool compact, {
  bool header = false,
}) => Row(
  children: [
    _cell(Text(values[0], style: _sortieStyle(compact, header: header)), 18),
    _cell(Text(values[1], style: _sortieStyle(compact, header: header)), 14),
    _cell(Text(values[2], style: _sortieStyle(compact, header: header)), 14),
    _cell(Text(values[3], style: _sortieStyle(compact, header: header)), 10),
    _cell(Text(values[4], style: _sortieStyle(compact, header: header)), 10),
    _cell(Text(values[5], style: _sortieStyle(compact, header: header)), 28),
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
