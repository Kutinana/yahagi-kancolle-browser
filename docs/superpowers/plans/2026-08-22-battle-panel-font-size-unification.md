# 未卜先知模式字号统一实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 将未卜先知简洁模式的对应字号统一到完整模式标准，并防止两种模式再次发生字号漂移。

**架构：** 保留简洁模式与完整模式的现有组件边界，只调整简洁模式的局部 `TextStyle` 和 `BattleRankBadge` 参数。使用现有 Widget 测试从渲染后的 `Text` 组件读取字号，覆盖战斗主体和基地空袭两个入口。

**技术栈：** Flutter、Dart、`flutter_test`

---

## 文件结构

- 修改：`lib/src/battle/live_battle_card.dart`，统一简洁模式的敌方舰队名、评级、舰队标题、HP 和退避字号。
- 修改：`lib/src/battle/land_base_raid_panel.dart`，取消简洁模式对基地空袭 HP 的字号缩小。
- 修改：`test/live_battle_card_node_test.dart`，增加简洁模式主体字号回归测试。
- 修改：`test/land_base_raid_panel_test.dart`，增加简洁模式基地空袭字号回归测试。

### 任务 1：战斗主体字号

**文件：**

- 修改：`test/live_battle_card_node_test.dart`
- 修改：`lib/src/battle/live_battle_card.dart`

- [ ] **步骤 1：编写失败的 Widget 测试**

在现有简洁模式战斗测试中，按 Widget Key 和文本读取对应 `Text`，验证完整模式标准：

```dart
final friendTitle = find.descendant(
  of: find.byKey(const Key('compact-fleet-side-title-friend')),
  matching: find.textContaining('我方舰队'),
);
expect(tester.widget<Text>(friendTitle).style?.fontSize, 11);
expect(tester.widget<Text>(hpText).style?.fontSize, 10);
expect(tester.widget<Text>(find.text('敌方舰队')).style?.fontSize, 14);
expect(tester.widget<Text>(find.text('S')).style?.fontSize, 20);
```

手机布局继续由现有 `phone detailed battle header matches compact layout` 测试保证 13 sp 和 21 sp。

- [ ] **步骤 2：运行测试并确认红灯**

运行：

```powershell
flutter test test/live_battle_card_node_test.dart --plain-name "compact tablet battle uses detailed typography sizes"
```

预期：FAIL；实际字号分别仍为 9 sp、9 sp、13 sp 或 21 sp。

- [ ] **步骤 3：编写最小实现**

在 `_CompactBattlePanel` 中复用 `isPhoneDensity(context)`，并调整对应样式：

```dart
final phone = isPhoneDensity(context);

enemyStyle: TextStyle(
  fontSize: phone ? 13 : 14,
  fontWeight: FontWeight.w600,
  color: enemyCombined ? const Color(0xffff8c78) : null,
),

_RankBadge(rank: battle.rank, phone: phone)
```

让 `_RankBadge` 在手机使用默认 50/21，在平板使用完整模式的 48/20；同时把简洁舰队标题、HP 和「退避」分别改为 11 sp、10 sp、11 sp。

- [ ] **步骤 4：运行测试并确认绿灯**

运行：

```powershell
flutter test test/live_battle_card_node_test.dart --plain-name "compact tablet battle uses detailed typography sizes"
flutter test test/live_battle_card_node_test.dart --plain-name "phone detailed battle header matches compact layout"
```

预期：两个测试均 PASS。

### 任务 2：基地空袭字号

**文件：**

- 修改：`test/land_base_raid_panel_test.dart`
- 修改：`lib/src/battle/land_base_raid_panel.dart`

- [ ] **步骤 1：编写失败的 Widget 测试**

在紧凑入口渲染 `LandBaseRaidPanel(result: result, compact: true)`，验证 HP 字号：

```dart
final hp = tester.widget<Text>(find.text('200/200（-0）'));
expect(hp.style?.fontSize, 11);
```

- [ ] **步骤 2：运行测试并确认红灯**

运行：

```powershell
flutter test test/land_base_raid_panel_test.dart --plain-name "compact raid keeps detailed hp font size"
```

预期：FAIL；实际字号为 10 sp。

- [ ] **步骤 3：编写最小实现**

将基地空袭 HP 的字号固定为完整模式标准：

```dart
fontSize: 11,
```

保留 `compact` 对内边距、间距和进度条高度的现有控制。

- [ ] **步骤 4：运行测试并确认绿灯**

运行：

```powershell
flutter test test/land_base_raid_panel_test.dart --plain-name "compact raid keeps detailed hp font size"
```

预期：PASS。

### 任务 3：完整验证与提交

**文件：**

- 验证：`lib/src/battle/live_battle_card.dart`
- 验证：`lib/src/battle/land_base_raid_panel.dart`
- 验证：`test/live_battle_card_node_test.dart`
- 验证：`test/land_base_raid_panel_test.dart`

- [ ] **步骤 1：格式化改动文件**

```powershell
dart format lib/src/battle/live_battle_card.dart lib/src/battle/land_base_raid_panel.dart test/live_battle_card_node_test.dart test/land_base_raid_panel_test.dart
```

- [ ] **步骤 2：运行相关测试套件**

```powershell
flutter test test/live_battle_card_node_test.dart test/land_base_raid_panel_test.dart test/fcf_retreat_battle_warning_test.dart
```

预期：全部 PASS，且无异常或警告。

- [ ] **步骤 3：运行静态分析**

```powershell
flutter analyze lib/src/battle/live_battle_card.dart lib/src/battle/land_base_raid_panel.dart test/live_battle_card_node_test.dart test/land_base_raid_panel_test.dart
```

预期：退出码为 0，无分析错误。

- [ ] **步骤 4：检查差异并提交**

```powershell
git diff --check
git diff --stat
git add lib/src/battle/live_battle_card.dart lib/src/battle/land_base_raid_panel.dart test/live_battle_card_node_test.dart test/land_base_raid_panel_test.dart
git commit -m "fix(未卜先知): 统一简洁与完整模式字号"
```
