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
                        '每日所需',
                        senkaNumber(result.dailyRequired),
                        '今日剩余',
                        senkaNumber(result.todayRemaining),
                        firstKey: const Key('senka-metric-daily-required'),
                        secondKey: const Key('senka-metric-today-remaining'),
                      ),
                    ),
                    const Divider(height: 1, color: senkaLine),
                    Expanded(
                      child: _metricRow(
                        '素战果',
                        senkaNumber(result.baseSenka),
                        '剩余日数',
                        '${result.remainingDays}',
                        firstKey: const Key('senka-metric-base-senka'),
                        secondKey: const Key('senka-metric-remaining-days'),
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
    return Column(
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
                child: Text.rich(
                  TextSpan(
                    style: _footerStyle(),
                    children: [
                      const TextSpan(text: '计划 EO 战果奖励 '),
                      TextSpan(
                        text: '+${senkaNumber(result.plannedEo)}',
                        style: const TextStyle(
                          color: senkaGold,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  textAlign: TextAlign.left,
                ),
              ),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: _footerStyle(),
                    children: [
                      const TextSpan(text: '计划任务战果奖励 '),
                      TextSpan(
                        text: '+${senkaNumber(result.plannedQuest)}',
                        style: const TextStyle(
                          color: senkaGold,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: _footerStyle(),
                    children: [
                      const TextSpan(text: '合计 '),
                      TextSpan(
                        text:
                            '+${senkaNumber(result.plannedEo + result.plannedQuest)}',
                        style: const TextStyle(
                          color: senkaGold,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _taskGroups(bool scrollContent, bool horizontal) {
    final groups = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _group(
          'EO 战果奖励',
          'eo',
          senkaEoCatalog,
          quest: false,
          legend: '黄色＋✕：计划放置，不计入预计战果，绿色＋✓：计划完成，计入预计战果，灰色＋○：已经完成，不再重复计算。',
        ),
        _group('季度战果任务', 'quarterly', senkaQuarterlyQuestCatalog, quest: true),
        if (horizontal)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _group(
                  '年度战果任务',
                  'annual',
                  senkaAnnualQuestCatalog,
                  quest: true,
                  columns: 1,
                  last: true,
                ),
              ),
              SizedBox(width: widget.compact ? 5 : 7),
              Expanded(
                child: _group(
                  '单次战果任务',
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
          _group('年度战果任务', 'annual', senkaAnnualQuestCatalog, quest: true),
          _group(
            '单次战果任务',
            'one-time',
            senkaOneTimeQuestCatalog,
            quest: true,
            last: true,
          ),
        ],
      ],
    );
    final padding = EdgeInsets.only(bottom: widget.compact ? 4 : 7);
    return scrollContent
        ? SingleChildScrollView(padding: padding, child: groups)
        : Padding(padding: padding, child: groups);
  }

  TextStyle _footerStyle() => TextStyle(
    color: senkaText,
    fontSize: widget.compact ? 11 : 13,
    fontWeight: FontWeight.w800,
  );

  Widget _group(
    String title,
    String groupKey,
    List<SenkaCatalogItem> items, {
    required bool quest,
    String? legend,
    int? columns,
    bool last = false,
  }) => Padding(
    padding: EdgeInsets.only(bottom: last ? 0 : (widget.compact ? 4 : 7)),
    child: Container(
      key: Key('senka-task-group-$groupKey'),
      child: Container(
        key: Key('senka-task-group-frame-$groupKey'),
        padding: EdgeInsets.all(widget.compact ? 5 : 7),
        decoration: BoxDecoration(
          color: senkaPanelAlt.withValues(alpha: .58),
          border: Border.all(color: senkaLine.withValues(alpha: .82)),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  maxLines: 1,
                  style: TextStyle(
                    color: senkaText,
                    fontSize: widget.compact ? 12 : 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (legend != null) ...[
                  SizedBox(width: widget.compact ? 5 : 8),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        legend,
                        maxLines: 1,
                        style: TextStyle(
                          color: senkaMuted,
                          fontSize: widget.compact ? 8 : 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: widget.compact ? 2 : 3),
            LayoutBuilder(
              builder: (context, constraints) {
                final colCount =
                    columns ??
                    _taskColumns(constraints.maxWidth, widget.compact);
                final spacing = widget.compact ? 3.0 : 5.0;
                final width =
                    (constraints.maxWidth - (colCount - 1) * spacing) /
                    colCount;
                return Wrap(
                  spacing: spacing,
                  runSpacing: 0,
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
    ),
  );

  Widget _reward(SenkaCatalogItem item, bool quest) {
    final status =
        (quest
            ? widget.state.questStatuses[item.id]
            : widget.state.eoStatuses[item.id]) ??
        SenkaRewardStatus.deferred;

    final rewardStyle = _RewardVisualStyle.resolve(status);
    final contentColor = rewardStyle.accent;
    final labelColor = rewardStyle.text;
    final statusLabel = switch (status) {
      SenkaRewardStatus.deferred => '计划放置',
      SenkaRewardStatus.planned => '计划完成（计预计）',
      SenkaRewardStatus.completed => '已完成',
    };
    final keyPrefix = quest ? 'quest' : 'eo';
    final rewardContent = Stack(
      fit: StackFit.expand,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: widget.compact ? 7 : 9),
          child: Center(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Row(
                    key: Key('senka-reward-leading-$keyPrefix-${item.id}'),
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        switch (status) {
                          SenkaRewardStatus.deferred => '✕',
                          SenkaRewardStatus.planned => '✓',
                          SenkaRewardStatus.completed => '○',
                        },
                        style: TextStyle(
                          color: contentColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          item.matrixLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            color: labelColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  key: Key('senka-reward-value-$keyPrefix-${item.id}'),
                  width: widget.compact ? 50 : 56,
                  child: Text(
                    '+${senkaNumber(item.senka)}',
                    maxLines: 1,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: contentColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      height: 1,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (status == SenkaRewardStatus.completed)
          Positioned.fill(
            child: Center(
              child: SizedBox(
                key: Key('senka-strike-$keyPrefix-${item.id}'),
                width: double.infinity,
                height: 1.2,
                child: ColoredBox(
                  color: const Color(0xffb8c1c7).withValues(alpha: .78),
                ),
              ),
            ),
          ),
      ],
    );
    final visibleSurface = SizedBox(
      height: 36,
      width: double.infinity,
      child: DecoratedBox(
        key: Key('senka-reward-visual-$keyPrefix-${item.id}'),
        decoration: rewardStyle.decoration,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: Stack(
            children: [
              Positioned.fill(
                child: Material(
                  key: Key('senka-reward-surface-$keyPrefix-${item.id}'),
                  color: Colors.transparent,
                  child: rewardContent,
                ),
              ),
              Positioned(
                top: 1,
                left: 5,
                right: 5,
                child: IgnorePointer(
                  child: SizedBox(
                    key: Key('senka-reward-highlight-$keyPrefix-${item.id}'),
                    height: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: .2),
                            Colors.white.withValues(alpha: .03),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
            borderRadius: BorderRadius.circular(5),
            onTap: () => quest
                ? widget.controller.cycleQuestReward(item.id)
                : widget.controller.cycleEoReward(item.id),
            child: Center(child: visibleSurface),
          ),
        ),
      ),
    );
  }
}

class _RewardVisualStyle {
  const _RewardVisualStyle({
    required this.gradient,
    required this.border,
    required this.text,
    required this.accent,
  });

  final List<Color> gradient;
  final Color border;
  final Color text;
  final Color accent;

  static _RewardVisualStyle resolve(SenkaRewardStatus status) =>
      switch (status) {
        SenkaRewardStatus.completed => const _RewardVisualStyle(
          gradient: [Color(0xff4b565e), Color(0xff323b42)],
          border: Color(0xff69757d),
          text: Color(0xffc4ccd1),
          accent: Color(0xffb8c1c7),
        ),
        SenkaRewardStatus.planned => const _RewardVisualStyle(
          gradient: [Color(0xff23694f), Color(0xff174b3a)],
          border: Color(0xff3b8064),
          text: Color(0xffe4f4eb),
          accent: Color(0xffafe5ca),
        ),
        SenkaRewardStatus.deferred => const _RewardVisualStyle(
          gradient: [Color(0xff735116), Color(0xff4a350f)],
          border: Color(0xff9b731e),
          text: Color(0xfff3d988),
          accent: Color(0xfff4c85b),
        ),
      };

  BoxDecoration get decoration => BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: gradient,
    ),
    border: Border.all(color: border.withValues(alpha: .72)),
    borderRadius: BorderRadius.circular(5),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: .25),
        blurRadius: 3,
        offset: const Offset(0, 1),
      ),
    ],
  );
}

int _taskColumns(double width, bool compact) =>
    width >= 380 ? 4 : (width >= 200 ? 2 : 1);

double _taskPanelHeight(BuildContext context, double width, bool compact) {
  final padding = compact ? 5.0 : 9.0;
  final contentWidth = width - padding * 2 - 2;
  final columns = _taskColumns(contentWidth, compact);
  final groupPadding = compact ? 5.0 : 7.0;
  final groupGap = compact ? 4.0 : 7.0;
  final titleFontSize = compact ? 12.0 : 15.0;
  final titleHeight =
      MediaQuery.textScalerOf(context).scale(titleFontSize) * 1.4;
  final titleGap = compact ? 2.0 : 3.0;
  const chipHeight = 44.0;
  final groupCounts = [
    senkaEoCatalog.length,
    senkaQuarterlyQuestCatalog.length,
    senkaAnnualQuestCatalog.length,
    senkaOneTimeQuestCatalog.length,
  ];
  var groupsHeight = 0.0;
  for (var index = 0; index < groupCounts.length; index++) {
    final rows = (groupCounts[index] / columns).ceil();
    groupsHeight +=
        groupPadding * 2 + titleHeight + titleGap + rows * chipHeight;
    if (index < groupCounts.length - 1) {
      groupsHeight += groupGap;
    }
  }
  final footer = compact ? 28.0 : 38.0;
  return footer + padding * 2 + groupsHeight + 40;
}
