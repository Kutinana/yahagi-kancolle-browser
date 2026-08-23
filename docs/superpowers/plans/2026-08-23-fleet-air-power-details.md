# 舰队制空详情实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 让首页和舰队中心的制空指标打开统一详情弹窗，展示最小、最大及保留改修补正的无熟练度加成制空值。

**架构：** `FleetMetrics` 继续提供现有制空最小值和最大值，并新增无熟练度加成值。新建专用 `fleet_air_power_details.dart` 展示详情，首页与舰队中心只负责在数据完整时调用同一入口。

**技术栈：** Flutter、Dart 记录类型、`AlertDialog`、Flutter 本地化、`flutter_test`。

---

## 文件职责

- `lib/src/game_state/fleet_metrics.dart`：计算并承载舰队制空最小、最大、无熟练度加成 3 个结果。
- `lib/src/fleet/fleet_air_power_details.dart`：唯一的制空详情弹窗入口和详情行布局。
- `lib/src/fleet/fleet_summary_card.dart`：首页制空胶囊点击入口。
- `lib/src/fleet/fleet_information_center.dart`：舰队中心制空指标点击入口。
- `lib/l10n/app_zh.arb`、`app_zh_Hant.arb`、`app_ja.arb`：制空详情相关文案。
- `test/fleet_metrics_test.dart`：制空公式及缺失数据回归。
- `test/fleet_air_power_details_test.dart`：共享弹窗内容和关闭行为。
- `test/fleet_summary_card_test.dart`、`test/fleet_information_center_test.dart`：两处点击集成回归。

### 任务 1：扩展舰队制空计算

**文件：**

- 修改：`lib/src/game_state/fleet_metrics.dart`
- 测试：`test/fleet_metrics_test.dart`

- [ ] **步骤 1：编写失败的无熟练度加成测试**

在现有制空测试组中构造搭载量 `4`、对空 `10`、改修 `★10`、熟练度等级 `6` 的舰战，并断言：

```dart
expect(metrics.airPower, 40);
expect(metrics.airPowerMaximum, 41);
expect(metrics.airPowerWithoutProficiency, 24);
```

该用例证明无加成计算保留舰战 `★10 × 0.2` 的改修补正，同时移除固定熟练度奖励和内部熟练度奖励。

- [ ] **步骤 2：运行测试并确认红灯**

运行：

```bash
flutter test test/fleet_metrics_test.dart
```

预期：编译失败，提示 `airPowerWithoutProficiency` 尚未定义。

- [ ] **步骤 3：实现最少的三值计算**

将 `FleetMetrics` 构造参数和字段扩展为：

```dart
required this.airPowerWithoutProficiency,

final int? airPowerWithoutProficiency;
```

工厂方法增加舰队累计值：

```dart
var calculatedAirPowerWithoutProficiency = 0;
calculatedAirPowerWithoutProficiency += slotAirPower.withoutProficiency;
```

将单格计算记录扩展为：

```dart
({int minimum, int maximum, int withoutProficiency})
```

返回值使用相同的 `effectiveAntiAir`，但无加成不加入 `typeBonus` 和内部熟练度：

```dart
final withoutProficiency = math.sqrt(count) * effectiveAntiAir;
return (
  minimum: (base + internalBonusMinimum).floor(),
  maximum: (base + internalBonusMaximum).floor(),
  withoutProficiency: withoutProficiency.floor(),
);
```

装备数据未知时，新增字段与现有两个字段一起返回 `null`。

- [ ] **步骤 4：运行计算测试并确认绿灯**

运行：

```bash
flutter test test/fleet_metrics_test.dart
```

预期：全部通过。

- [ ] **步骤 5：提交计算变更**

```bash
git add lib/src/game_state/fleet_metrics.dart test/fleet_metrics_test.dart
git commit -m "feat(舰队): 计算无熟练度加成制空值"
```

### 任务 2：实现共享制空详情弹窗

**文件：**

- 创建：`lib/src/fleet/fleet_air_power_details.dart`
- 创建：`test/fleet_air_power_details_test.dart`
- 修改：`lib/l10n/app_zh.arb`
- 修改：`lib/l10n/app_zh_Hant.arb`
- 修改：`lib/l10n/app_ja.arb`
- 修改：`lib/l10n/app_localizations.dart`
- 修改：`lib/l10n/app_localizations_zh.dart`
- 修改：`lib/l10n/app_localizations_ja.dart`

- [ ] **步骤 1：编写失败的弹窗测试**

测试通过按钮调用预期入口：

```dart
await tester.tap(find.text('打开'));
await tester.pumpAndSettle();

expect(find.text('制空详情'), findsOneWidget);
expect(find.text('最小'), findsOneWidget);
expect(find.text('40'), findsOneWidget);
expect(find.text('最大'), findsOneWidget);
expect(find.text('41'), findsOneWidget);
expect(find.text('无加成'), findsOneWidget);
expect(find.text('24'), findsOneWidget);
```

随后点击本地化关闭按钮并断言弹窗消失。

- [ ] **步骤 2：运行测试并确认红灯**

运行：

```bash
flutter test test/fleet_air_power_details_test.dart
```

预期：编译失败，提示 `showFleetAirPowerDetails` 尚未定义。

- [ ] **步骤 3：增加本地化资源**

3 种 ARB 均新增以下键，并提供对应语言文案：

```json
"airPowerDetails": "制空详情",
"minimumValue": "最小",
"maximumValue": "最大",
"withoutBonus": "无加成",
"showAirPowerDetails": "点击查看制空详情"
```

运行：

```bash
flutter gen-l10n
```

- [ ] **步骤 4：实现与索敌详情同风格的共享弹窗**

新增入口：

```dart
Future<void> showFleetAirPowerDetails(
  BuildContext context,
  FleetMetrics metrics,
)
```

使用 `AlertDialog`、`Color(0xff142735)`、`Divider(Color(0xff294052))`、左右两列详情行和底部关闭按钮。详情行严格按最小、最大、无加成顺序读取：

```dart
metrics.airPower
metrics.airPowerMaximum
metrics.airPowerWithoutProficiency
```

- [ ] **步骤 5：运行弹窗与本地化契约测试**

运行：

```bash
flutter test test/fleet_air_power_details_test.dart test/localization_contract_test.dart
```

预期：全部通过。

- [ ] **步骤 6：提交共享弹窗**

```bash
git add lib/l10n lib/src/fleet/fleet_air_power_details.dart test/fleet_air_power_details_test.dart
git commit -m "feat(舰队): 添加制空详情弹窗"
```

### 任务 3：接入首页和舰队中心

**文件：**

- 修改：`lib/src/fleet/fleet_summary_card.dart`
- 修改：`lib/src/fleet/fleet_information_center.dart`
- 测试：`test/fleet_summary_card_test.dart`
- 测试：`test/fleet_information_center_test.dart`

- [ ] **步骤 1：编写两个入口的失败测试**

首页测试点击：

```dart
await tester.tap(find.byKey(const Key('fleet-summary-metric-air-power')));
await tester.pumpAndSettle();
expect(find.text('制空详情'), findsOneWidget);
expect(find.text('无加成'), findsOneWidget);
```

舰队中心测试点击：

```dart
await tester.tap(find.byKey(const Key('fleet-air-power-metric')));
await tester.pumpAndSettle();
expect(find.text('制空详情'), findsOneWidget);
expect(find.text('无加成'), findsOneWidget);
```

- [ ] **步骤 2：运行入口测试并确认红灯**

运行：

```bash
flutter test test/fleet_summary_card_test.dart test/fleet_information_center_test.dart
```

预期：找不到制空详情弹窗或舰队中心制空指标键。

- [ ] **步骤 3：接入首页制空胶囊**

为 `air-power` 指标在 3 个制空结果均非空时提供：

```dart
() => showFleetAirPowerDetails(context, current)
```

并使用 `showAirPowerDetails` 作为按钮语义。数据未知时保持 `onTap == null`。

- [ ] **步骤 4：接入舰队中心制空指标**

为索引 `6` 增加 `Key('fleet-air-power-metric')`，在 3 个制空结果均非空时调用同一 `showFleetAirPowerDetails`。索引 `7` 的索敌详情行为保持不变。

- [ ] **步骤 5：运行相关回归测试**

运行：

```bash
flutter test test/fleet_metrics_test.dart test/fleet_air_power_details_test.dart test/fleet_summary_card_test.dart test/fleet_information_center_test.dart test/localization_contract_test.dart
```

预期：全部通过。

- [ ] **步骤 6：提交入口集成**

```bash
git add lib/src/fleet/fleet_summary_card.dart lib/src/fleet/fleet_information_center.dart test/fleet_summary_card_test.dart test/fleet_information_center_test.dart
git commit -m "feat(舰队): 支持点击查看制空详情"
```

### 任务 4：最终验证

**文件：**

- 验证暴露问题时，仅修改对应实现和回归测试。

- [ ] **步骤 1：运行定向静态分析**

```bash
flutter analyze lib/src/game_state/fleet_metrics.dart lib/src/fleet/fleet_air_power_details.dart lib/src/fleet/fleet_summary_card.dart lib/src/fleet/fleet_information_center.dart
```

记录仓库既有告警；本次新增文件不得产生告警。

- [ ] **步骤 2：运行全量测试**

```bash
flutter test
```

预期：全部通过，允许保留项目既有的跳过项。

- [ ] **步骤 3：检查工作区**

```bash
git diff --check
git status --short
```

预期：无未提交变更。
