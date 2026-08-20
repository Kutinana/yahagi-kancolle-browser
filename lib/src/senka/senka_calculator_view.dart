import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'senka_calculation.dart';
import 'senka_catalog.dart';
import 'senka_controller.dart';
import 'senka_state.dart';
import 'senka_ui.dart';

class SenkaCalculatorView extends StatefulWidget {
  const SenkaCalculatorView({
    super.key,
    required this.state,
    required this.controller,
    required this.now,
    required this.compact,
  });
  final SenkaState state;
  final SenkaController controller;
  final DateTime now;
  final bool compact;
  @override
  State<SenkaCalculatorView> createState() => _SenkaCalculatorViewState();
}

class _SenkaCalculatorViewState extends State<SenkaCalculatorView> {
  late final TextEditingController currentController = TextEditingController(
    text: senkaNumber(widget.state.calculatorCurrentSenka),
  );
  late final TextEditingController targetController = TextEditingController(
    text: senkaNumber(widget.state.targetSenka),
  );

  @override
  void didUpdateWidget(covariant SenkaCalculatorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncInput(currentController, widget.state.calculatorCurrentSenka);
    _syncInput(targetController, widget.state.targetSenka);
  }

  void _syncInput(TextEditingController controller, double model) {
    if (double.tryParse(controller.text) == model) return;
    final text = senkaNumber(model);
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  @override
  void dispose() {
    currentController.dispose();
    targetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final horizontal = constraints.maxWidth > constraints.maxHeight * 1.15;
      final overview = _overview();
      final tasks = _tasks(scrollContent: horizontal, horizontal: horizontal);
      final gap = widget.compact ? 4.0 : 10.0;
      if (horizontal) {
        return Row(
          key: const Key('senka-calculator-horizontal'),
          children: [
            Expanded(
              flex: 3,
              child: SizedBox(
                key: const Key('senka-calculator-left'),
                child: overview,
              ),
            ),
            SizedBox(width: gap),
            Expanded(
              flex: 7,
              child: SizedBox(
                key: const Key('senka-calculator-right'),
                child: tasks,
              ),
            ),
          ],
        );
      }
      return SingleChildScrollView(
        key: const Key('senka-calculator-vertical'),
        child: Column(
          children: [
            SizedBox(
              key: const Key('senka-calculator-left'),
              height: widget.compact ? 420 : 500,
              child: overview,
            ),
            SizedBox(height: gap),
            SizedBox(
              key: const Key('senka-calculator-right'),
              height: _taskPanelHeight(
                context,
                constraints.maxWidth,
                widget.compact,
              ),
              child: tasks,
            ),
          ],
        ),
      );
    },
  );

  Widget _overview() {
    final result = SenkaCalculationResult.fromState(
      widget.state,
      now: widget.now,
    );
    final gapText = result.gap > 0
        ? '距离目标还差 ${senkaNumber(result.gap)} 战果'
        : '已超出 ${senkaNumber(result.over)} 战果';
    return SenkaPanel(
      title: '战果计算',
      compact: widget.compact,
      trailing: Container(
        padding: EdgeInsets.symmetric(
          horizontal: widget.compact ? 7 : 10,
          vertical: widget.compact ? 3 : 4,
        ),
        decoration: BoxDecoration(
          color: senkaLine.withValues(alpha: .34),
          border: Border.all(color: senkaLine),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          '实时计算',
          style: TextStyle(
            color: senkaMuted,
            fontSize: widget.compact ? 8 : 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(widget.compact ? 7 : 12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _inputColumn(
                    '当前战果',
                    const Key('senka-current-input'),
                    currentController,
                    widget.controller.setCurrentSenka,
                  ),
                ),
                SizedBox(width: widget.compact ? 7 : 10),
                Expanded(
                  child: _inputColumn(
                    '目标战果',
                    const Key('senka-target-input'),
                    targetController,
                    widget.controller.setTargetSenka,
                  ),
                ),
              ],
            ),
            SizedBox(height: widget.compact ? 7 : 12),
            _projectedCard(result, gapText),
            SizedBox(height: widget.compact ? 7 : 12),
            Expanded(
              child: Container(
                key: const Key('senka-metrics-grid'),
                decoration: BoxDecoration(
                  color: senkaPanelAlt,
                  border: Border.all(color: senkaLine),
                  borderRadius: BorderRadius.circular(7),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Expanded(
                      child: _metricRow(
                        '已勾选 EO',
                        '+${senkaNumber(result.plannedEo)}',
                        '已勾选战果任务',
                        '+${senkaNumber(result.plannedQuest)}',
                        firstKey: const Key('senka-metric-planned-eo'),
                        secondKey: const Key('senka-metric-planned-quest'),
                      ),
                    ),
                    const Divider(height: 1, color: senkaLine),
                    Expanded(
                      child: _metricRow(
                        '剩余日数',
                        '${result.remainingDays}',
                        '素战果',
                        senkaNumber(result.baseSenka),
                        firstKey: const Key('senka-metric-remaining-days'),
                        secondKey: const Key('senka-metric-base-senka'),
                      ),
                    ),
                    const Divider(height: 1, color: senkaLine),
                    Expanded(
                      child: _metricRow(
                        '每日所需',
                        senkaNumber(result.dailyRequired),
                        '今日剩余',
                        senkaNumber(result.todayRemaining),
                        firstKey: const Key('senka-metric-daily-required'),
                        secondKey: const Key('senka-metric-today-remaining'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputColumn(
    String label,
    Key key,
    TextEditingController controller,
    ValueChanged<double> setter,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          color: senkaMuted,
          fontSize: widget.compact ? 9 : 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      SizedBox(height: widget.compact ? 2 : 4),
      SizedBox(
        height: 44,
        child: TextField(
          key: key,
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[-0-9.]')),
          ],
          onChanged: (value) {
            final parsed = double.tryParse(value);
            if (parsed != null && parsed.isFinite) setter(parsed);
          },
          style: TextStyle(
            color: senkaText,
            fontSize: widget.compact ? 12 : 16,
            fontWeight: FontWeight.w800,
          ),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: senkaPanelAlt,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 9,
              vertical: widget.compact ? 7 : 10,
            ),
            enabledBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: senkaLine),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: senkaGold),
            ),
          ),
        ),
      ),
    ],
  );

  Widget _projectedCard(SenkaCalculationResult result, String gapText) =>
      Container(
        key: const Key('senka-projected-card'),
        width: double.infinity,
        padding: EdgeInsets.all(widget.compact ? 9 : 13),
        decoration: BoxDecoration(
          color: senkaGold.withValues(alpha: .08),
          border: Border.all(color: senkaGold.withValues(alpha: .55)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'EO·战果炮 CLEAR 后共计',
              maxLines: 1,
              style: TextStyle(
                color: senkaMuted,
                fontSize: widget.compact ? 9 : 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: widget.compact ? 2 : 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  senkaNumber(result.projected),
                  style: TextStyle(
                    color: senkaGold,
                    fontSize: widget.compact ? 24 : 34,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 7),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    '战果',
                    style: TextStyle(
                      color: senkaGold,
                      fontSize: widget.compact ? 10 : 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: widget.compact ? 5 : 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                minHeight: widget.compact ? 5 : 7,
                value: (result.percentage / 100).clamp(0, 1),
                color: senkaGold,
                backgroundColor: senkaBackground,
              ),
            ),
            SizedBox(height: widget.compact ? 4 : 6),
            Text(
              '（${senkaNumber(result.percentage)}% · $gapText）',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: senkaGold,
                fontSize: widget.compact ? 8 : 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );

  Widget _metricRow(
    String firstLabel,
    String firstValue,
    String secondLabel,
    String secondValue, {
    Key? firstKey,
    Key? secondKey,
  }) => Row(
    children: [
      _metric(firstLabel, firstValue, key: firstKey),
      const VerticalDivider(width: 1, color: senkaLine),
      _metric(secondLabel, secondValue, key: secondKey),
    ],
  );

  Widget _metric(String label, String value, {Key? key}) => Expanded(
    child: Container(
      key: key,
      padding: EdgeInsets.all(widget.compact ? 5 : 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: senkaMuted,
              fontSize: widget.compact ? 9 : 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: widget.compact ? 2 : 4),
          Text(
            value,
            maxLines: 1,
            style: TextStyle(
              color: senkaText,
              fontSize: widget.compact ? 12 : 16,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _tasks({required bool scrollContent, required bool horizontal}) {
    final result = SenkaCalculationResult.fromState(
      widget.state,
      now: widget.now,
    );
    return SenkaPanel(
      title: 'EO · 战果奖励矩阵',
      compact: widget.compact,
      trailing: Text(
        '单击循环切换状态',
        style: TextStyle(
          color: senkaMuted,
          fontSize: widget.compact ? 8 : 10,
          fontWeight: FontWeight.w700,
        ),
      ),
      child: Column(
        children: [
          Expanded(child: _taskGroups(scrollContent, horizontal)),
          Container(
            key: const Key('senka-calculator-footer'),
            height: widget.compact ? 28 : 38,
            decoration: const BoxDecoration(
              color: senkaPanelAlt,
              border: Border(top: BorderSide(color: senkaLine)),
            ),
            padding: EdgeInsets.symmetric(horizontal: widget.compact ? 5 : 10),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '黄色 ✕：计划放置   绿色 ✓：计划完成   灰色删除线：已完成',
                      maxLines: 1,
                      style: _footerStyle().copyWith(color: senkaMuted),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    '计划 EO 战果奖励 +${senkaNumber(result.plannedEo)}',
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: _footerStyle(),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    '计划任务战果奖励 +${senkaNumber(result.plannedQuest)}',
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: _footerStyle(),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    '合计：${senkaNumber(result.plannedEo + result.plannedQuest)} 战果',
                    maxLines: 1,
                    textAlign: TextAlign.right,
                    style: _footerStyle().copyWith(color: senkaGold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _taskGroups(bool scrollContent, bool horizontal) {
    final groups = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _group(
          'EO 战果奖励',
          '放置 → 计划 → 完成',
          'eo',
          senkaEoCatalog,
          quest: false,
          columns: 2,
        ),
        _group(
          '季度战果任务',
          '放置 → 计划 → 完成',
          'quarterly',
          senkaQuarterlyQuestCatalog,
          quest: true,
          columns: 2,
        ),
        if (horizontal)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _group(
                  '年度战果任务',
                  '手动选择',
                  'annual',
                  senkaAnnualQuestCatalog,
                  quest: true,
                  columns: 1,
                  last: true,
                ),
              ),
              SizedBox(width: widget.compact ? 5 : 8),
              Expanded(
                child: _group(
                  '单次战果任务',
                  '手动选择',
                  'one-time',
                  senkaOneTimeQuestCatalog,
                  quest: true,
                  columns: 1,
                  last: true,
                ),
              ),
            ],
          )
        else ...[
          _group(
            '年度战果任务',
            '手动选择',
            'annual',
            senkaAnnualQuestCatalog,
            quest: true,
            columns: 1,
          ),
          _group(
            '单次战果任务',
            '手动选择',
            'one-time',
            senkaOneTimeQuestCatalog,
            quest: true,
            columns: 1,
            last: true,
          ),
        ],
      ],
    );
    final padding = EdgeInsets.all(widget.compact ? 5 : 9);
    return scrollContent
        ? SingleChildScrollView(padding: padding, child: groups)
        : Padding(padding: padding, child: groups);
  }

  TextStyle _footerStyle() => TextStyle(
    color: senkaText,
    fontSize: widget.compact ? 8 : 11,
    fontWeight: FontWeight.w800,
  );

  Widget _group(
    String title,
    String caption,
    String groupKey,
    List<SenkaCatalogItem> items, {
    required bool quest,
    required int columns,
    bool last = false,
  }) => Padding(
    padding: EdgeInsets.only(bottom: last ? 0 : (widget.compact ? 6 : 10)),
    child: Container(
      key: Key('senka-task-group-$groupKey'),
      padding: EdgeInsets.all(widget.compact ? 5 : 8),
      decoration: BoxDecoration(
        color: senkaPanelAlt.withValues(alpha: .52),
        border: Border.all(color: senkaLine),
        borderRadius: BorderRadius.circular(widget.compact ? 6 : 9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  style: TextStyle(
                    color: senkaText,
                    fontSize: widget.compact ? 10 : 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                caption,
                maxLines: 1,
                style: TextStyle(
                  color: senkaMuted,
                  fontSize: widget.compact ? 7 : 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: widget.compact ? 2 : 4),
          LayoutBuilder(
            builder: (context, constraints) {
              final spacing = widget.compact ? 4.0 : 7.0;
              final width =
                  (constraints.maxWidth - (columns - 1) * spacing) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: widget.compact ? 0 : 2,
                children: [
                  for (final item in items)
                    SizedBox(
                      width: width,
                      height: 44,
                      child: _reward(item, quest),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    ),
  );

  Widget _reward(SenkaCatalogItem item, bool quest) {
    final status =
        (quest
            ? widget.state.questStatuses[item.id]
            : widget.state.eoStatuses[item.id]) ??
        SenkaRewardStatus.deferred;
    final color = switch (status) {
      SenkaRewardStatus.deferred => senkaYellow,
      SenkaRewardStatus.planned => senkaGreen,
      SenkaRewardStatus.completed => senkaMuted,
    };
    final statusLabel = switch (status) {
      SenkaRewardStatus.deferred => '计划放置',
      SenkaRewardStatus.planned => '计划完成（计预计）',
      SenkaRewardStatus.completed => '已完成',
    };
    final keyPrefix = quest ? 'quest' : 'eo';
    return Semantics(
      label: '${item.label}，$statusLabel，${senkaNumber(item.senka)} 战果',
      button: true,
      selected: status == SenkaRewardStatus.planned,
      toggled: status == SenkaRewardStatus.planned,
      excludeSemantics: true,
      child: Tooltip(
        message: '${item.label} · $statusLabel · +${senkaNumber(item.senka)}',
        child: Material(
          key: Key('senka-toggle-$keyPrefix-${item.id}'),
          color: Colors.transparent,
          child: InkWell(
            onTap: () => quest
                ? widget.controller.cycleQuestReward(item.id)
                : widget.controller.cycleEoReward(item.id),
            child: Center(
              child: SizedBox(
                height: widget.compact ? 32 : 36,
                width: double.infinity,
                child: Material(
                  key: Key('senka-reward-surface-$keyPrefix-${item.id}'),
                  color: color.withValues(alpha: .13),
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: color.withValues(alpha: .75)),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: widget.compact ? 6 : 9,
                        ),
                        child: Row(
                          children: [
                            if (status != SenkaRewardStatus.completed) ...[
                              Text(
                                status == SenkaRewardStatus.planned ? '✓' : '✕',
                                style: TextStyle(
                                  color: color,
                                  fontSize: widget.compact ? 9 : 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(width: 3),
                            ],
                            Expanded(
                              child: Text(
                                item.matrixLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: color,
                                  fontSize: widget.compact ? 9 : 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 3),
                            SizedBox(
                              width: widget.compact ? 38 : 49,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Text(
                                  '+${senkaNumber(item.senka)}',
                                  maxLines: 1,
                                  style: TextStyle(
                                    color: color,
                                    fontSize: widget.compact ? 8 : 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (status == SenkaRewardStatus.completed)
                        Positioned.fill(
                          child: Center(
                            child: SizedBox(
                              key: Key('senka-strike-$keyPrefix-${item.id}'),
                              width: double.infinity,
                              height: 1,
                              child: ColoredBox(color: color),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

double _taskPanelHeight(BuildContext context, double _, bool compact) {
  final padding = compact ? 5.0 : 9.0;
  final spacing = compact ? 0.0 : 2.0;
  final groupGap = compact ? 6.0 : 10.0;
  final groupPadding = compact ? 5.0 : 8.0;
  final titleFontSize = compact ? 10.0 : 13.0;
  final titleHeight =
      MediaQuery.textScalerOf(context).scale(titleFontSize) * 1.3;
  final titleGap = compact ? 3.0 : 6.0;
  const chipHeight = 44.0;
  final groupCounts = [
    senkaEoCatalog.length,
    senkaQuarterlyQuestCatalog.length,
    senkaAnnualQuestCatalog.length,
    senkaOneTimeQuestCatalog.length,
  ];
  const groupColumns = [2, 2, 1, 1];
  var groupsHeight = 0.0;
  for (var index = 0; index < groupCounts.length; index++) {
    final rows = (groupCounts[index] / groupColumns[index]).ceil();
    groupsHeight +=
        groupPadding * 2 +
        titleHeight +
        titleGap +
        rows * chipHeight +
        (rows - 1) * spacing;
    if (index < groupCounts.length - 1) groupsHeight += groupGap;
  }
  final panelHeader = compact ? 28.0 : 36.0;
  final footer = compact ? 28.0 : 38.0;
  // Leave a small allowance for the font's platform-specific line metrics.
  return panelHeader + footer + padding * 2 + groupsHeight + 24;
}
