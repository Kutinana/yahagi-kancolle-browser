# 普通多段攻击损管结算实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 修复普通多段攻击逐段触发损管导致的 HP 偏差，并保持特殊多目标攻击和七舰游击部队行为不变。

**架构：** 在两套炮击解析路径中以攻击类型为分支。普通攻击聚合伤害并只结算首个目标一次；已登记的特殊多目标攻击继续逐段结算。

**技术栈：** Dart、Flutter Test、poi-lib-battle 3.2.0 对照语料

---

### 任务 1：POI 预测引擎普通多段攻击

**文件：**
- 修改：`test/poi_battle_prediction_engine_test.dart`
- 修改：`lib/src/battle/prediction/poi/poi_battle_prediction_engine.dart`

- [ ] **步骤 1：编写失败的测试**

增加夜战普通二连测试：我方 30 HP、装备要员 42，敌方单次攻击目标 `[0, 0]`、伤害 `[30, 1]`，期望最终 HP 为 6 且只记录一次要员。

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/poi_battle_prediction_engine_test.dart --plain-name "POI engine aggregates ordinary multi-hit damage before damage control"`

预期：FAIL，实际 HP 为 5、期望为 6。

- [ ] **步骤 3：编写最少实现代码**

在 `_shell` 中检测 `attackOrder == null`。普通攻击对 `hits` 调用 `_damage` 后求和，使用 `targets.first` 只调用一次 `_damagePosition`；特殊攻击保留现有逐段循环。

- [ ] **步骤 4：运行测试验证通过**

运行：`flutter test test/poi_battle_prediction_engine_test.dart`

预期：全部通过。

- [ ] **步骤 5：提交**

提交：`fix(战斗): 聚合普通多段攻击后触发损管（任务 1/2）`

### 任务 2：备用解析器同步与全量验证

**文件：**
- 修改：`test/battle_damage_parser_test.dart`
- 修改：`lib/src/battle/battle_damage_parser.dart`

- [ ] **步骤 1：编写失败的测试**

增加与任务 1 相同数据的备用解析器测试，期望最终 HP 为 6 且只记录一次要员。

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/battle_damage_parser_test.dart --plain-name "aggregates ordinary multi-hit damage before damage control"`

预期：FAIL，实际 HP 为 5、期望为 6。

- [ ] **步骤 3：编写最少实现代码**

在 `_applyShelling` 中为 `attackOrder == null` 增加普通攻击聚合路径；特殊多目标路径继续逐段调用 `_damagePosition`。

- [ ] **步骤 4：运行专项与对照测试**

运行：`flutter test test/poi_battle_prediction_engine_test.dart test/battle_damage_parser_test.dart test/battle_controller_test.dart`

运行：设置 `YAHAGI_POI_BATTLE_FIXTURES` 后执行 `flutter test test/battle_poi_corpus_test.dart`。

预期：全部通过。

- [ ] **步骤 5：提交**

提交：`fix(战斗): 同步备用解析器多段损管结算（任务 2/2）`

- [ ] **步骤 6：合并与完整验证**

快进合并到 `master`，在包含本地测试夹具的主工作区运行 `flutter test`，预期 0 失败；再运行修改文件的 `flutter analyze`，预期 0 issues。
