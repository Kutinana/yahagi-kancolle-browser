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
      final tasks = _tasks(scrollContent: horizontal);
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
              height: widget.compact ? 390 : 430,
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
      title: '战果计算概况',
      compact: widget.compact,
      child: Padding(
        padding: EdgeInsets.all(widget.compact ? 7 : 12),
        child: Column(
          children: [
            _input(
              '当前战果',
              const Key('senka-current-input'),
              currentController,
              widget.controller.setCurrentSenka,
            ),
            SizedBox(height: widget.compact ? 5 : 9),
            _input(
              '目标战果',
              const Key('senka-target-input'),
              targetController,
              widget.controller.setTargetSenka,
            ),
            SizedBox(height: widget.compact ? 7 : 12),
            Text(
              'EO·战果炮 CLEAR 后共计 ${senkaNumber(result.projected)} 战果',
              maxLines: 1,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: senkaText,
                fontSize: widget.compact ? 10 : 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: widget.compact ? 2 : 5),
            Text(
              '（${senkaNumber(result.percentage)}% · $gapText）',
              maxLines: 1,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: senkaGold,
                fontSize: widget.compact ? 9 : 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: widget.compact ? 7 : 12),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        _metric(
                          '已勾选 EO',
                          '+${senkaNumber(result.plannedEo)}',
                          key: const Key('senka-metric-planned-eo'),
                        ),
                        _metric(
                          '已勾选战果任务',
                          '+${senkaNumber(result.plannedQuest)}',
                          key: const Key('senka-metric-planned-quest'),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: widget.compact ? 4 : 7),
                  Expanded(
                    child: Row(
                      children: [
                        _metric('剩余日数', '${result.remainingDays}'),
                        _metric('素战果', senkaNumber(result.baseSenka)),
                      ],
                    ),
                  ),
                  SizedBox(height: widget.compact ? 4 : 7),
                  Expanded(
                    child: Row(
                      children: [
                        _metric('每日所需', senkaNumber(result.dailyRequired)),
                        _metric('今日剩余', senkaNumber(result.todayRemaining)),
                      ],
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

  Widget _input(
    String label,
    Key key,
    TextEditingController controller,
    ValueChanged<double> setter,
  ) => Row(
    children: [
      SizedBox(
        width: widget.compact ? 62 : 78,
        child: Text(
          label,
          style: TextStyle(
            color: senkaMuted,
            fontSize: widget.compact ? 10 : 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      Expanded(
        child: SizedBox(
          height: widget.compact ? 30 : 38,
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
              fontSize: widget.compact ? 11 : 14,
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
      ),
    ],
  );

  Widget _metric(String label, String value, {Key? key}) => Expanded(
    child: Container(
      key: key,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: EdgeInsets.all(widget.compact ? 5 : 8),
      decoration: BoxDecoration(
        color: senkaPanelAlt,
        border: Border.all(color: senkaLine),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
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
              color: senkaGold,
              fontSize: widget.compact ? 12 : 16,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _tasks({required bool scrollContent}) {
    final result = SenkaCalculationResult.fromState(
      widget.state,
      now: widget.now,
    );
    return SenkaPanel(
      title: '任务矩阵',
      compact: widget.compact,
      child: Column(
        children: [
          Expanded(child: _taskGroups(scrollContent)),
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
                  child: Text(
                    '计划 EO 战果奖励 +${senkaNumber(result.plannedEo)}',
                    maxLines: 1,
                    style: _footerStyle(),
                  ),
                ),
                Expanded(
                  child: Text(
                    '计划任务战果奖励 +${senkaNumber(result.plannedQuest)}',
                    maxLines: 1,
                    style: _footerStyle(),
                  ),
                ),
                Expanded(
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

  Widget _taskGroups(bool scrollContent) {
    final groups = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _group('EO 战果奖励', senkaEoCatalog, quest: false),
        _group('季度战果任务', senkaQuarterlyQuestCatalog, quest: true),
        _group('年度战果任务', senkaAnnualQuestCatalog, quest: true),
        _group('单次战果任务', senkaOneTimeQuestCatalog, quest: true, last: true),
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
    List<SenkaCatalogItem> items, {
    required bool quest,
    bool last = false,
  }) => Padding(
    padding: EdgeInsets.only(bottom: last ? 0 : (widget.compact ? 6 : 10)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: senkaText,
            fontSize: widget.compact ? 10 : 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: widget.compact ? 3 : 6),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = _taskColumns(constraints.maxWidth, widget.compact);
            final width =
                (constraints.maxWidth -
                    (columns - 1) * (widget.compact ? 3 : 6)) /
                columns;
            return Wrap(
              spacing: widget.compact ? 3 : 6,
              runSpacing: widget.compact ? 3 : 6,
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
          color: color.withValues(alpha: .13),
          shape: RoundedRectangleBorder(
            side: BorderSide(color: color.withValues(alpha: .75)),
            borderRadius: BorderRadius.circular(999),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => quest
                ? widget.controller.cycleQuestReward(item.id)
                : widget.controller.cycleEoReward(item.id),
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
                        width: widget.compact ? 31 : 42,
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
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 19.5,
                    child: Container(
                      key: Key('senka-strike-$keyPrefix-${item.id}'),
                      height: 1,
                      color: color,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

int _taskColumns(double width, bool compact) =>
    compact ? (width >= 500 ? 7 : 3) : (width >= 700 ? 7 : 4);

double _taskPanelHeight(BuildContext context, double width, bool compact) {
  final padding = compact ? 5.0 : 9.0;
  final contentWidth = width - padding * 2 - 2;
  final columns = _taskColumns(contentWidth, compact);
  final spacing = compact ? 3.0 : 6.0;
  final groupGap = compact ? 6.0 : 10.0;
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
  var groupsHeight = 0.0;
  for (var index = 0; index < groupCounts.length; index++) {
    final rows = (groupCounts[index] / columns).ceil();
    groupsHeight +=
        titleHeight + titleGap + rows * chipHeight + (rows - 1) * spacing;
    if (index < groupCounts.length - 1) groupsHeight += groupGap;
  }
  final panelHeader = compact ? 28.0 : 36.0;
  final footer = compact ? 28.0 : 38.0;
  // Leave a small allowance for the font's platform-specific line metrics.
  return panelHeader + footer + padding * 2 + groupsHeight + 12;
}
