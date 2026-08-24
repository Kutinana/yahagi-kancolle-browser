# 先制反潜规则完整实现计划

> **执行要求：** 使用 `executing-plans` 按任务顺序实施；每个功能任务遵循先写失败测试、再写最小实现、最后重构的节奏。

**目标：** 补齐舰队页面“先反”TAG所依赖的先制反潜判定规则，修复日向改二装备 S-51J 不显示，并覆盖用户列出的通用舰种、海防舰、轻空母/护卫空母及特殊舰规则。

**实现方式：** 保留 `detectShipCombatMechanisms` 和 `_canOpeningAsw` 的现有入口，在 `combat_mechanism.dart` 内增加小型规则辅助函数和舰娘 ID 集合。为正确表达“搭载总和不为 0”，在 `MasterShip` 保存母港主数据 `api_maxeq`；判定使用原始搭载容量，不使用战斗后的当前 `api_onslot`。

**技术栈：** Dart 3、Flutter、`flutter_test`

---

## 任务 1：保存舰娘原始搭载容量

**涉及文件：**

- 修改：`lib/src/game_state/game_state.dart`
- 修改：`lib/src/game_state/game_state_reducer.dart`
- 测试：`test/game_state_reducer_test.dart`

### 步骤 1：添加失败测试

在 `game_state_reducer_test.dart` 的主数据解析测试中给舰娘响应加入：

```dart
'api_maxeq': <int>[12, 8, 4, 0],
```

断言：

```dart
expect(state.masterShips[shipId]!.slotCapacities, <int>[12, 8, 4, 0]);
```

并增加一次主数据图片信息合并/`copyWith` 后仍保留该列表的断言。

### 步骤 2：运行失败测试

运行：

```powershell
flutter test test/game_state_reducer_test.dart
```

预期：由于 `MasterShip.slotCapacities` 尚不存在而失败。

### 步骤 3：实现最小模型与解析改动

在 `MasterShip` 中添加默认空列表字段：

```dart
this.slotCapacities = const <int>[],
```

并在 `copyWith` 中完整保留。在主数据 reducer 解析 `api_maxeq` 为整数列表后传入构造函数。缺失或格式异常时回退为空列表，保持旧缓存和测试兼容。

### 步骤 4：运行测试并提交

运行：

```powershell
dart format lib/src/game_state/game_state.dart lib/src/game_state/game_state_reducer.dart test/game_state_reducer_test.dart
flutter test test/game_state_reducer_test.dart
```

预期：全部通过。

提交：

```powershell
git add lib/src/game_state/game_state.dart lib/src/game_state/game_state_reducer.dart test/game_state_reducer_test.dart
git commit -m "feat(舰队): 保存舰娘原始搭载容量（任务 1/4）"
```

## 任务 2：用测试锁定完整先制反潜规则

**涉及文件：**

- 修改：`test/combat_mechanism_test.dart`

### 步骤 1：扩展测试构造器

让 `_state` 支持：

- `masterId`、`shipTypeId`、`antiSub`；
- `slotCapacities`，默认按普通装备槽生成正容量；
- `onSlot`，用于证明战斗后当前搭载数不会影响静态 TAG；
- 真实装备分类、图标和白板对潜值。

新增 `_hasOpeningAsw` 辅助断言，减少重复调用。

### 步骤 2：添加规则测试矩阵

至少覆盖以下正反例：

1. 驱逐/轻巡/练巡/雷巡/补给：100 对潜 + 小型或大型声呐；99 不触发。
2. 海防舰：60 + 声呐；75 + 装备白板对潜合计 4；不满足时不触发；Norge/Eidsvold 不套用通用海防舰规则。
3. 无条件舰代表：五十铃改二无需对潜值和装备即可触发。
4. 普通轻空母：50 + 声呐 + 对潜 7 航空装备；65 + 对潜 7 航空装备；100 + 声呐 + 对潜 1 舰攻/舰爆；缺少原始搭载容量或被排除舰不触发；当前 `onSlot` 为 0 仍触发。
5. 护卫空母代表：大鹰改、加贺改二护装备对潜 1 的规定航空装备且原始搭载容量大于 0 时触发。
6. 扶桑改二/山城改二、熊野丸/改、大和改二重/神州丸改按各自 100 对潜和装备组合触发。
7. 日向改二真实 ID 554：一架 S-51J/S-51J改触发；两架普通旋翼机触发；一架普通旋翼机不触发。

测试中的装备类型使用游戏 API 分类：舰爆 7、舰攻 8、水爆 11、爆雷投射机/爆雷 15、旋翼机 25、对潜哨戒机 26；声呐同时覆盖图标 17 和 18；零式水中听音机使用真实装备 ID。

### 步骤 3：运行失败测试

运行：

```powershell
flutter test test/combat_mechanism_test.dart
```

预期：新增规则用例失败，且原测试中错误标注为日向改二的 ID 646 被更正为 554 后揭示现有问题。

### 步骤 4：仅提交测试契约

```powershell
git add test/combat_mechanism_test.dart
git commit -m "test(舰队): 覆盖完整先制反潜规则（任务 2/4）"
```

## 任务 3：实现完整先制反潜判定

**涉及文件：**

- 修改：`lib/src/fleet/combat_mechanism.dart`

### 步骤 1：补充通用装备辅助函数

增加并复用以下判定：

- 声呐：装备图标为 17 或 18；
- 零式水中听音机：按真实装备 ID；
- 装备白板对潜总和：累加 `MasterSlotItem.antiSub`，不计算改修加成；
- 原始搭载容量：`master.slotCapacities` 合计大于 0；
- 对潜航空装备：按规则区分舰攻、舰爆、水爆、旋翼机、对潜哨戒机；
- S-51J 系列：一类对潜哨戒机规则；普通旋翼机：类型 25。

### 步骤 2：按互斥舰种和特殊舰顺序实现规则

按以下顺序处理，避免普通舰种规则吞掉特殊规则：

1. 无条件舰集合；
2. 日向改二；
3. 扶桑改二/山城改二、熊野丸/改、大和改二重/神州丸改；
4. 护卫空母集合；
5. 普通轻空母及其排除集合；
6. 海防舰及 Norge/Eidsvold 排除；
7. 驱逐/轻巡/练巡/雷巡/补给通用规则；
8. 其他舰返回 false。

每个分支只表达用户给出的对潜阈值、装备组合和原始搭载容量约束，不加入昼夜战或联合舰队位置等出击时动态条件。

### 步骤 3：运行模块测试并整理

运行：

```powershell
dart format lib/src/fleet/combat_mechanism.dart test/combat_mechanism_test.dart
flutter test test/combat_mechanism_test.dart
```

预期：新增规则和既有机制测试全部通过。

### 步骤 4：提交实现

```powershell
git add lib/src/fleet/combat_mechanism.dart
git commit -m "fix(舰队): 补齐先制反潜判定规则（任务 3/4）"
```

## 任务 4：集成回归与完整验证

**涉及文件：**

- 验证：`lib/src/fleet/combat_mechanism.dart`
- 验证：`lib/src/game_state/game_state.dart`
- 验证：`lib/src/game_state/game_state_reducer.dart`
- 验证：舰队 TAG 相关测试

### 步骤 1：运行定向回归

```powershell
flutter test test/combat_mechanism_test.dart test/game_state_reducer_test.dart test/fleet_summary_card_test.dart test/fleet_information_center_test.dart
```

预期：全部通过，确认“先反”TAG与舰队卡片集成未回归。

### 步骤 2：运行静态检查

```powershell
flutter analyze lib/src/fleet/combat_mechanism.dart lib/src/game_state/game_state.dart lib/src/game_state/game_state_reducer.dart test/combat_mechanism_test.dart test/game_state_reducer_test.dart
```

预期：无 error、warning 或 info。

### 步骤 3：运行完整测试

```powershell
flutter test
```

预期：整个项目测试套件通过。

### 步骤 4：检查最终差异与提交状态

```powershell
git diff --check
git status --short --branch
git log -4 --oneline
```

如果集成验证需要调整测试契约，单独提交：

```powershell
git add <调整文件>
git commit -m "test(舰队): 完善先制反潜集成回归（任务 4/4）"
```

最终交付需报告：实现的规则类别、关键修复（日向改二 ID 554 与 S-51J）、定向测试/静态检查/完整测试的实际结果，以及当前 `master` 的提交状态。
