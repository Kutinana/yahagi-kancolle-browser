# 未卜先知 HP 损伤界限刻度实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 为未卜先知的简洁和完整舰船血条增加 POI 式 25%、50%、75% 损伤界限刻度。

**架构：** 新建一个只负责血条表现的 `ProphetHpBar` 组件，内部保留现有 `LinearProgressIndicator`，并在填充区域上叠加三条可裁剪短刻度。简洁与完整视图共享该组件，继续由现有调用方计算 HP 比例和颜色，避免影响战斗预测与损伤判定。

**技术栈：** Flutter、Dart、`flutter_test`、Material `LinearProgressIndicator`、`LayoutBuilder`、`ClipRect`。

---

## 文件结构

- 创建：`lib/src/battle/prophet_hp_bar.dart`——未卜先知专用 HP 血条及填充区域裁剪。
- 创建：`test/prophet_hp_bar_test.dart`——刻度数量、阈值边界、坐标和比例限制测试。
- 修改：`lib/src/battle/live_battle_card.dart`——简洁视图改用共享血条。
- 修改：`lib/src/battle/detailed_battle_panel.dart`——完整视图改用共享血条。
- 修改：`test/live_battle_card_node_test.dart`——验证两种视图均接入共享血条且原有行为保留。

### 任务 1：实现可独立测试的 POI 式血条组件

**文件：**

- 创建：`test/prophet_hp_bar_test.dart`
- 创建：`lib/src/battle/prophet_hp_bar.dart`

- [ ] **步骤 1：编写失败的组件测试**

在 `test/prophet_hp_bar_test.dart` 中构造固定宽度血条，验证刻度数量和边界：

```dart
Future<void> pumpBar(WidgetTester tester, double value) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: SizedBox(
          width: 400,
          child: ProphetHpBar(
            value: value,
            color: Colors.green,
            backgroundColor: const Color(0xff263e4d),
          ),
        ),
      ),
    ),
  );
}

testWidgets('shows only thresholds strictly below the filled ratio', (tester) async {
  await pumpBar(tester, 1.0);
  expect(find.byKey(const Key('prophet-hp-threshold-25')), findsOneWidget);
  expect(find.byKey(const Key('prophet-hp-threshold-50')), findsOneWidget);
  expect(find.byKey(const Key('prophet-hp-threshold-75')), findsOneWidget);

  await pumpBar(tester, 0.64);
  expect(find.byKey(const Key('prophet-hp-threshold-25')), findsOneWidget);
  expect(find.byKey(const Key('prophet-hp-threshold-50')), findsOneWidget);
  expect(find.byKey(const Key('prophet-hp-threshold-75')), findsNothing);

  await pumpBar(tester, 0.25);
  expect(find.byKey(const Key('prophet-hp-threshold-25')), findsNothing);
});
```

补充测试断言：

- 400 px 宽血条的三条刻度横坐标分别接近 100、200、300 px。
- `value < 0` 时内部进度值为 `0.0` 且没有刻度。
- `value > 1` 时内部进度值为 `1.0` 且显示三条刻度。
- 刻度宽 1 px、高 4 px，血条总高 6 px。

- [ ] **步骤 2：运行测试并确认因组件缺失而失败**

运行：

```powershell
flutter test test/prophet_hp_bar_test.dart
```

预期：FAIL，提示 `ProphetHpBar` 或导入文件不存在。

- [ ] **步骤 3：编写最少组件实现**

在 `lib/src/battle/prophet_hp_bar.dart` 中实现：

```dart
class ProphetHpBar extends StatelessWidget {
  const ProphetHpBar({
    super.key,
    required this.value,
    required this.color,
    required this.backgroundColor,
  });

  final double value;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final ratio = value.clamp(0.0, 1.0).toDouble();
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 6,
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            fit: StackFit.expand,
            children: <Widget>[
              LinearProgressIndicator(
                minHeight: 6,
                value: ratio,
                color: color,
                backgroundColor: backgroundColor,
              ),
              ClipRect(
                clipper: _ProphetHpFillClipper(ratio),
                child: Stack(
                  children: <Widget>[
                    for (final threshold in const <double>[0.25, 0.50, 0.75])
                      if (ratio > threshold)
                        Positioned(
                          key: Key(
                            'prophet-hp-threshold-${(threshold * 100).round()}',
                          ),
                          left: constraints.maxWidth * threshold,
                          top: 1,
                          width: 1,
                          height: 4,
                          child: const ColoredBox(
                            color: Color.fromRGBO(2, 11, 16, 0.78),
                          ),
                        ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

实现 `_ProphetHpFillClipper`，裁剪矩形为
`Rect.fromLTWH(0, 0, size.width * ratio, size.height)`；仅当比例变化时重裁剪。

- [ ] **步骤 4：运行组件测试并确认通过**

运行：

```powershell
flutter test test/prophet_hp_bar_test.dart
```

预期：全部 PASS。

- [ ] **步骤 5：提交组件与测试**

```powershell
git add lib/src/battle/prophet_hp_bar.dart test/prophet_hp_bar_test.dart
git commit -m "feat(战斗): 添加未卜先知血条损伤刻度"
```

### 任务 2：接入简洁与完整未卜先知视图

**文件：**

- 修改：`test/live_battle_card_node_test.dart`
- 修改：`lib/src/battle/live_battle_card.dart`
- 修改：`lib/src/battle/detailed_battle_panel.dart`

- [ ] **步骤 1：编写失败的集成测试**

在 `test/live_battle_card_node_test.dart` 中导入
`package:yahagi_kancolle_browser/src/battle/prophet_hp_bar.dart`，并增加两个测试：

```dart
testWidgets('compact prophet rows use threshold HP bars', (tester) async {
  final controller = _createController();
  addTearDown(controller.dispose);
  controller
    ..accept(mapStartEvent)
    ..accept(dayBattleEvent);
  await controller.idle;
  await _pumpCard(tester, controller, compact: true);

  final row = find.byKey(const Key('compact-bar-friend-0'));
  expect(
    find.descendant(of: row, matching: find.byType(ProphetHpBar)),
    findsOneWidget,
  );
});

testWidgets('detailed prophet rows use threshold HP bars', (tester) async {
  final controller = _createController();
  addTearDown(controller.dispose);
  controller
    ..accept(mapStartEvent)
    ..accept(dayBattleEvent);
  await controller.idle;
  await _pumpCard(tester, controller);

  final row = find.byKey(const Key('battle-ship-friend-0'));
  expect(
    find.descendant(of: row, matching: find.byType(ProphetHpBar)),
    findsOneWidget,
  );
});
```

- [ ] **步骤 2：运行集成测试并确认旧视图尚未接入**

运行：

```powershell
flutter test test/live_battle_card_node_test.dart --plain-name "threshold HP bars"
```

预期：FAIL，两个测试均报告找不到 `ProphetHpBar`。

- [ ] **步骤 3：用共享组件替换两处原始血条**

在 `live_battle_card.dart` 与 `detailed_battle_panel.dart` 中导入
`prophet_hp_bar.dart`，将原有 `ClipRRect + LinearProgressIndicator` 替换为：

```dart
ProphetHpBar(
  value: ratio,
  color: hpBarColor,
  backgroundColor: const Color(0xff263e4d),
)
```

保留外层 `Opacity`、损伤脉冲键、HP 文字、MVP 标记和退避分支。

- [ ] **步骤 4：运行集成测试和原有节点测试**

运行：

```powershell
flutter test test/live_battle_card_node_test.dart
```

预期：全部 PASS；原有查找 `LinearProgressIndicator`、颜色与布局的断言继续通过。

- [ ] **步骤 5：提交视图接入**

```powershell
git add lib/src/battle/live_battle_card.dart lib/src/battle/detailed_battle_panel.dart test/live_battle_card_node_test.dart
git commit -m "feat(战斗): 在未卜先知显示损伤界限"
```

### 任务 3：格式化与回归验证

**文件：**

- 验证：`lib/src/battle/prophet_hp_bar.dart`
- 验证：`lib/src/battle/live_battle_card.dart`
- 验证：`lib/src/battle/detailed_battle_panel.dart`
- 验证：`test/prophet_hp_bar_test.dart`
- 验证：`test/live_battle_card_node_test.dart`

- [ ] **步骤 1：格式化本功能文件**

```powershell
dart format lib/src/battle/prophet_hp_bar.dart lib/src/battle/live_battle_card.dart lib/src/battle/detailed_battle_panel.dart test/prophet_hp_bar_test.dart test/live_battle_card_node_test.dart
```

- [ ] **步骤 2：运行定向静态分析**

```powershell
flutter analyze lib/src/battle/prophet_hp_bar.dart lib/src/battle/live_battle_card.dart lib/src/battle/detailed_battle_panel.dart test/prophet_hp_bar_test.dart test/live_battle_card_node_test.dart
```

预期：`No issues found!`。

- [ ] **步骤 3：运行战斗模块测试**

```powershell
flutter test test/prophet_hp_bar_test.dart test/live_battle_card_node_test.dart test/battle_rank_test.dart test/battle_session_test.dart test/battle_prediction_executor_test.dart
```

预期：全部 PASS。

- [ ] **步骤 4：运行 Flutter 全量测试**

```powershell
flutter test
```

预期：全部现有测试通过；既有跳过测试保持跳过。

- [ ] **步骤 5：核对提交与工作区**

```powershell
git status --short
git log -3 --oneline
```

预期：本功能文件已提交，工作区不包含本功能的未提交修改。

