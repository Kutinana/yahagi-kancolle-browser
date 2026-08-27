# POI 全量重放战斗预测引擎实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法跟踪进度。

**目标：** 把默认 POI 预测引擎改为 POI 式全包重放，并完整覆盖 NPC 友军舰队、联合舰队、七舰游击部队、损管、战果等级和 MVP。

**架构：** `PoiBattlePredictionEngine` 只保存不可变初始舰队和深拷贝数据包历史；每次 `append` 新建 `PoiBattleSimulator` 并按路径重放全部历史。模拟器独立保存玩家主力/随伴、敌主力/随伴和 NPC 友军槽位，以阶段语义路由攻击。Yahagi 引擎及设置入口保持不变。

**技术栈：** Dart、Flutter、`flutter_test`、POI `lib-battle` JavaScript fixture oracle、Git worktree

---

## 文件结构

- 重写 `lib/src/battle/prediction/poi/poi_battle_prediction_engine.dart`：公共重放包装器。
- 新建 `lib/src/battle/prediction/poi/poi_battle_simulator.dart`：路径调度、阶段模拟、伤害和结算。
- 新建 `lib/src/battle/prediction/poi/poi_battle_state.dart`：保留位置的舰队槽位、攻击和数据包模型。
- 修改 `lib/src/battle/battle_controller.dart`：默认 POI 引擎接收真实联合舰队类型。
- 修改 `test/poi_battle_prediction_engine_test.dart`：重放、友军、联合、七舰、损管和排名单元测试。
- 修改 `test/battle_controller_test.dart`：控制器上下文传递和跨包重放测试。
- 修改 `test/battle_poi_corpus_test.dart` 与对照脚本：POI fixture 逐包对照及覆盖统计。
- 新建 `test/fixtures/battle/e4_combined_friendly_night.json`：与 E4 问题同结构的可复现回归夹具。

### 任务 1：锁定全量重放契约

**文件：**
- 修改：`test/poi_battle_prediction_engine_test.dart`
- 重写：`lib/src/battle/prediction/poi/poi_battle_prediction_engine.dart`
- 新建：`lib/src/battle/prediction/poi/poi_battle_state.dart`
- 新建：`lib/src/battle/prediction/poi/poi_battle_simulator.dart`

- [ ] **步骤 1：编写失败测试**

增加两包连续战斗测试：第一包造成伤害并触发损管，第二包追加夜战。断言第二次返回等于“从初始舰队依次执行两包”的结果，第一包不会被重复累计，损管不会沿用上次模拟器的消费对象。

- [ ] **步骤 2：验证旧实现失败**

运行：`flutter test test/poi_battle_prediction_engine_test.dart --plain-name "replays every packet from immutable initial fleets"`

预期：FAIL；旧实现直接在当前 HP 上增量执行。

- [ ] **步骤 3：实现最小重放骨架**

包装器深拷贝初始舰队和每个包；`append` 新建模拟器并顺序重放历史。先把现有阶段实现迁入模拟器，确保接口输出保持兼容。

- [ ] **步骤 4：验证重放测试**

运行：`flutter test test/poi_battle_prediction_engine_test.dart`

预期：新增重放测试 PASS，已有用例无回归。

- [ ] **步骤 5：提交任务**

提交：`refactor(战斗): 建立 POI 全量重放骨架（任务 1/6）`

### 任务 2：按 POI 路径和舰队类型调度阶段

**文件：**
- 修改：`lib/src/battle/prediction/poi/poi_battle_simulator.dart`
- 修改：`lib/src/battle/prediction/poi/poi_battle_prediction_engine.dart`
- 修改：`lib/src/battle/battle_controller.dart`
- 修改：`test/poi_battle_prediction_engine_test.dart`
- 修改：`test/battle_controller_test.dart`

- [ ] **步骤 1：编写失败测试**

覆盖通常、空袭、夜战、夜转日及联合舰队各路径。构造相同字段但不同路径的数据，断言只执行该路径允许的阶段，并按 POI 固定顺序结算。

- [ ] **步骤 2：验证旧实现失败**

运行新增路径调度测试，确认旧实现因为见键即执行或顺序不正确而失败。

- [ ] **步骤 3：实现路径调度表**

移植 POI `Simulator` 的路径分发和 fleet type 阶段顺序。默认引擎从 `BattleContext.combinedFleetType.apiValue` 接收舰队类型；注入的自定义测试工厂保持现有签名。

- [ ] **步骤 4：运行测试**

运行：`flutter test test/poi_battle_prediction_engine_test.dart test/battle_controller_test.dart`

预期：全部 PASS。

- [ ] **步骤 5：提交任务**

提交：`refactor(战斗): 对齐 POI 战斗阶段调度（任务 2/6）`

### 任务 3：隔离 NPC 友军并修正目标路由

**文件：**
- 修改：`lib/src/battle/prediction/poi/poi_battle_state.dart`
- 修改：`lib/src/battle/prediction/poi/poi_battle_simulator.dart`
- 修改：`test/poi_battle_prediction_engine_test.dart`
- 新建：`test/fixtures/battle/e4_combined_friendly_night.json`

- [ ] **步骤 1：编写失败测试**

至少加入：

1. `api_friendly_kouku.api_fdam` 只伤 NPC 友军，不伤玩家。
2. `api_friendly_battle.api_hougeki` 只伤敌主力/随伴，不计玩家 MVP。
3. 我方联合 + 敌联合 + NPC 友军 + 入夜的 E4 结构回归。
4. 友军阶段缺失可推断标志时固定 NPC→敌；明确字段矛盾时返回未确认。
5. 七舰玩家 0～6 号逐船受伤，第 7 舰不会映射到敌舰或旗舰。

- [ ] **步骤 2：验证旧实现失败**

逐个运行测试并记录旧实现的错误舰队或错误槽位。

- [ ] **步骤 3：实现独立友军槽位和显式路由**

由 `api_friendly_info` 初始化 NPC 友军；航空与夜战使用阶段固定的攻击/目标舰队。所有目标先解析舰队再解析位置；非法非零目标添加 `BattleParseIssue`，不得折算到其他舰。

- [ ] **步骤 4：运行测试**

运行：`flutter test test/poi_battle_prediction_engine_test.dart`

预期：NPC 友军、联合舰队和七舰用例全部 PASS。

- [ ] **步骤 5：提交任务**

提交：`fix(战斗): 隔离 NPC 友军和联合舰队目标（任务 3/6）`

### 任务 4：对齐损管、战果等级和 MVP

**文件：**
- 修改：`lib/src/battle/prediction/poi/poi_battle_state.dart`
- 修改：`lib/src/battle/prediction/poi/poi_battle_simulator.dart`
- 修改：`test/poi_battle_prediction_engine_test.dart`

- [ ] **步骤 1：编写失败测试**

覆盖要员、女神、单次多段致命伤、跨阶段再次致命、重放后消费一致；覆盖敌舰数量 1～12 的半沉阈值，重点断言 9～11；覆盖女神恢复后总损失非正时 SS；覆盖联合舰队日夜 MVP 归属。

- [ ] **步骤 2：验证旧实现至少在 9～11 舰阈值和重放损管上失败**

运行新增精确测试，保留失败输出作为修复依据。

- [ ] **步骤 3：实现结算规则**

损管按槽位顺序一次消费；排名表使用 POI `[0,1,1,2,2,3,4,4,5,6,7,7,8]`；SS 使用非正总损失；未知 HP 或解析问题返回 unknown；NPC 友军输出不参与 MVP。

- [ ] **步骤 4：运行测试**

运行：`flutter test test/poi_battle_prediction_engine_test.dart test/battle_damage_parser_test.dart`

预期：全部 PASS。

- [ ] **步骤 5：提交任务**

提交：`fix(战斗): 对齐 POI 损管排名和 MVP（任务 4/6）`

### 任务 5：升级 POI 语料逐包对照

**文件：**
- 修改：`test/battle_poi_corpus_test.dart`
- 修改或新建：`tool/poi_battle_oracle.*`

- [ ] **步骤 1：让 oracle 输出每包快照**

对每个 fixture 返回第 1～N 包之后的主力/随伴 HP、等级、MVP和解析元数据。不得只输出最终结果。

- [ ] **步骤 2：Dart 测试逐包比较**

每次 `append` 后与对应 POI 快照比较，并输出分类覆盖统计：NPC 友军、联合、夜转日、航空、支援、损管、七舰。

- [ ] **步骤 3：运行完整语料**

设置 `YAHAGI_POI_BATTLE_FIXTURES` 后运行：`flutter test test/battle_poi_corpus_test.dart`

预期：303 个 fixture 的全部包无差异；未被语料覆盖的类别明确显示为 0，并由本地合成测试补足。

- [ ] **步骤 4：提交任务**

提交：`test(战斗): 增加 POI 逐包语料对照（任务 5/6）`

### 任务 6：全量验证并安全合并 master

**文件：**
- 验证全部本次修改文件和仓库测试状态

- [ ] **步骤 1：格式和差异检查**

运行涉及文件的 `dart format`，然后运行 `git diff --check` 和 `git status --short`，确认没有带入 master 用户未提交内容。

- [ ] **步骤 2：战斗测试全集**

运行所有 `test/battle*`、`test/poi_battle_prediction_engine_test.dart`、设置与执行器相关测试。

- [ ] **步骤 3：静态分析**

运行本次涉及文件的 `flutter analyze`，预期 `No issues found!`。

- [ ] **步骤 4：全仓测试**

运行 `flutter test`。若仓库缺少未跟踪 fixture 导致装配失败，记录精确文件和基线数量，同时确保与引擎相关的独立测试全部通过。

- [ ] **步骤 5：构建验证**

运行项目可用的 Android debug 构建或等价编译检查，确保生产代码可编译。

- [ ] **步骤 6：最终提交和合并**

确认分支干净后，在主工作树运行非破坏性 `git merge --no-ff fix/poi-replay-parity`。合并前后核对 master 上原有五项未提交改动仍存在且内容未被覆盖。

- [ ] **步骤 7：合并后抽样复测**

在 master 上重新运行 POI 引擎、控制器、语料和静态分析，记录最终 commit id。
