# 游击部队七舰战斗预测 POI 一致性实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 修正七舰游击部队在缺少 `api_at_eflag` 时的炮击索引映射，并让诊断会话完整保存第七舰。

**架构：** 保留现有战斗数据流，只将 POI 炮击算法中的 `mainFleetRange` 语义同步到两个 Dart 解析路径。战斗会话槽位扩展到七，战果页不再伪造 1 HP。

**技术栈：** Dart、Flutter、`flutter_test`、现有 POI 语料对照脚本

---

## 文件结构

- 修改 `lib/src/battle/prediction/poi/poi_battle_prediction_engine.dart`：POI 实时预测的动态主舰队边界。
- 修改 `test/poi_battle_prediction_engine_test.dart`：七舰且缺失攻击方标志的回归测试。
- 修改 `lib/src/battle/battle_damage_parser.dart`：备用解析路径使用相同边界。
- 修改 `test/battle_damage_parser_test.dart`：备用解析的七舰回归测试。
- 修改 `lib/src/battle/battle_session.dart`：保存七个主舰队位置。
- 修改 `test/battle_session_test.dart`：验证第七舰不会被截断。
- 修改 `lib/src/battle/battle_controller.dart` 与 `test/battle_controller_test.dart`：移除临时 1 HP 战果修正及对应测试。

### 任务 1：锁定 POI 引擎的七舰索引行为

**文件：**
- 修改：`test/poi_battle_prediction_engine_test.dart`
- 修改：`lib/src/battle/prediction/poi/poi_battle_prediction_engine.dart`

- [ ] **步骤 1：编写失败的测试**

加入一场七舰炮击：不提供 `api_at_eflag`，友军攻击敌方第零舰时使用合并目标位置 `7`，并验证敌方第零舰而非第一舰扣血。

```dart
test('POI engine uses seven-ship boundary when attacker flags are absent', () {
  final engine = PoiBattlePredictionEngine(
    friendMain: <BattleShipSnapshot>[
      for (var position = 0; position < 7; position++)
        poiShip(side: BattleSide.friend, position: position, hp: 30),
    ],
    enemyMain: <BattleShipSnapshot>[
      poiShip(side: BattleSide.enemy, position: 0, hp: 30),
      poiShip(side: BattleSide.enemy, position: 1, hp: 30),
    ],
  );
  final result = engine.append(
    path: '/kcsapi/api_req_sortie/battle',
    data: <String, Object?>{
      'api_hougeki1': <String, Object?>{
        'api_at_list': <int>[0],
        'api_df_list': <Object?>[<int>[7]],
        'api_damage': <Object?>[<num>[11]],
      },
    },
  );
  expect(result.enemyMain.map((ship) => ship.currentHp), <int>[19, 30]);
  expect(result.friendMain.every((ship) => ship.currentHp == 30), isTrue);
});
```

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/poi_battle_prediction_engine_test.dart --plain-name "POI engine uses seven-ship boundary when attacker flags are absent"`

预期：FAIL；旧实现固定减六，敌方第二舰被扣血。

- [ ] **步骤 3：编写最少实现代码**

在 `_shell` 中引入实际边界，并仅替换缺少 `api_at_eflag` 时的判断与换算：

```dart
final mainFleetRange = _friendMain.length;
final enemyAttack = row < flags.length
    ? _int(flags[row]) != 0
    : (targets.isNotEmpty && _int(targets.first) < mainFleetRange);
// ...
if (!enemyAttack && position >= mainFleetRange) {
  position -= mainFleetRange;
}
```

- [ ] **步骤 4：运行测试验证通过**

运行：`flutter test test/poi_battle_prediction_engine_test.dart`

预期：全部 PASS。

### 任务 2：同步备用伤害解析器

**文件：**
- 修改：`test/battle_damage_parser_test.dart`
- 修改：`lib/src/battle/battle_damage_parser.dart`

- [ ] **步骤 1：编写失败的测试**

使用与任务 1 相同的七舰无标志炮击数据调用 `BattleDamageParser().apply(...)`，断言敌方 HP 为 `<int>[19, 30]`，七艘友军 HP 均为 30。

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/battle_damage_parser_test.dart --plain-name "uses seven-ship boundary when shelling omits api_at_eflag"`

预期：FAIL；旧实现将目标七固定减六。

- [ ] **步骤 3：编写最少实现代码**

在 `_applyShelling` 使用 `battle.friendMain.length`：

```dart
final mainFleetRange = battle.friendMain.length;
final attackerIsEnemy = hasAttackerFlag
    ? _int(flags[attackIndex]) != 0
    : _int(targets.first) < mainFleetRange;
// ...
if (!attackerIsEnemy && targetPosition >= mainFleetRange) {
  targetPosition -= mainFleetRange;
}
```

- [ ] **步骤 4：运行测试验证通过**

运行：`flutter test test/battle_damage_parser_test.dart`

预期：全部 PASS。

### 任务 3：完整保存第七舰诊断快照

**文件：**
- 修改：`test/battle_session_test.dart`
- 修改：`lib/src/battle/battle_session.dart`

- [ ] **步骤 1：编写失败的测试**

```dart
test('retains the seventh strike-force ship slot', () {
  final session = BattleSession(
    id: 'session-7',
    context: const BattleContext(node: 1),
    startedAt: DateTime.utc(2026),
    friendMain: <BattleShipSnapshot>[
      for (var position = 0; position < 7; position++) _ship(position),
    ],
  );
  expect(session.friendMainSlots, hasLength(7));
  expect(session.friendMainSlots[6]?.masterId, 106);
});
```

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/battle_session_test.dart --plain-name "retains the seventh strike-force ship slot"`

预期：FAIL；旧槽位长度为六。

- [ ] **步骤 3：编写最少实现代码**

将 `_slots` 的容量从六扩展为七，并更新类注释。更新原测试对槽位长度的期望为七。

- [ ] **步骤 4：运行测试验证通过**

运行：`flutter test test/battle_session_test.dart`

预期：全部 PASS。

### 任务 4：移除战果页 1 HP 临时修正

**文件：**
- 修改：`lib/src/battle/battle_controller.dart`
- 修改：`test/battle_controller_test.dart`

- [ ] **步骤 1：删除临时行为和测试**

删除 `_reconcileFriendlySurvival`、调用它的局部变量与额外 `_emitFriendlyHp`；删除 `official S result cannot confirm a sunk friendly forecast` 测试。保留战果确认、MVP、奖励等原有逻辑。

- [ ] **步骤 2：运行控制器测试**

运行：`flutter test test/battle_controller_test.dart`

预期：全部 PASS，战果处理回到修改前行为。

### 任务 5：全面验证

**文件：**
- 验证上述全部生产与测试文件

- [ ] **步骤 1：格式化并检查差异**

运行：`dart format lib/src/battle/prediction/poi/poi_battle_prediction_engine.dart lib/src/battle/battle_damage_parser.dart lib/src/battle/battle_session.dart lib/src/battle/battle_controller.dart test/poi_battle_prediction_engine_test.dart test/battle_damage_parser_test.dart test/battle_session_test.dart test/battle_controller_test.dart`

运行：`git diff --check`

- [ ] **步骤 2：运行战斗相关测试**

运行：`flutter test test/poi_battle_prediction_engine_test.dart test/battle_damage_parser_test.dart test/battle_session_test.dart test/battle_controller_test.dart`

预期：全部 PASS。

- [ ] **步骤 3：运行 POI 语料对照**

设置现有 POI fixture 环境变量后运行：`flutter test test/battle_poi_corpus_test.dart`

预期：语料数量与测试基线一致，所有可用战例 PASS。

- [ ] **步骤 4：运行静态分析**

运行：`flutter analyze lib/src/battle/prediction/poi/poi_battle_prediction_engine.dart lib/src/battle/battle_damage_parser.dart lib/src/battle/battle_session.dart lib/src/battle/battle_controller.dart test/poi_battle_prediction_engine_test.dart test/battle_damage_parser_test.dart test/battle_session_test.dart test/battle_controller_test.dart`

预期：`No issues found!`

- [ ] **步骤 5：提交实现**

仅暂存本计划涉及的变更，核对不包含用户其他工作后提交：

```bash
git add lib/src/battle/prediction/poi/poi_battle_prediction_engine.dart lib/src/battle/battle_damage_parser.dart lib/src/battle/battle_session.dart lib/src/battle/battle_controller.dart test/poi_battle_prediction_engine_test.dart test/battle_damage_parser_test.dart test/battle_session_test.dart test/battle_controller_test.dart
git diff --cached --stat
git commit -m "fix(战斗): 对齐 POI 七舰游击部队索引"
```
