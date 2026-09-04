# 出击记录战斗详情实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 仅为 Yahagi 今后自动捕获的新战斗保存 POI 风格详情，并从航海日志的战斗行打开响应式舰队对比与战斗过程页面。

**架构：** 用独立、版本化的详情模型将一次 `BattleSession` 固化成 JSON；回放构建器按现有 POI 兼容阶段顺序生成逐次攻击事件；日志数据库懒加载详情，日志页面在自身状态内切换列表与详情以保留筛选和滚动。详情组件独立于日志表，便于四种目标尺寸做组件测试。

**技术栈：** Flutter/Dart、Material、sqflite_common_ffi、flutter_test。

---

## 文件结构

- 创建 `lib/src/battle/battle_detail_models.dart`：版本化快照、舰船、装备、阶段和攻击事件的 JSON 模型。
- 创建 `lib/src/battle/battle_detail_replay_builder.dart`：从开战舰队、最终舰队和 `BattleSessionPacket` 构造详情。
- 修改 `lib/src/battle/battle_models.dart`：让 `BattleRecord` 可携带可空详情快照。
- 修改 `lib/src/battle/battle_controller.dart`：在归档会话前生成详情并随记录持久化。
- 修改 `lib/src/logbook/logbook_database.dart`：schema v11、`detail_json` 写入与按 ID 懒加载。
- 创建 `lib/src/logbook/battle_detail_page.dart`：舰队/战斗过程两页签与响应式布局。
- 修改 `lib/src/logbook/logbook_page.dart`：战斗行点击、详情加载、列表状态原地保留。
- 创建 `test/battle_detail_models_test.dart`：JSON 往返测试。
- 创建 `test/battle_detail_replay_builder_test.dart`：双方攻击、联合舰队、多段伤害测试。
- 修改 `test/logbook_database_test.dart`：v10→v11 迁移和详情持久化测试。
- 创建 `test/battle_detail_page_test.dart`：四种尺寸、页签、筛选和无侧栏测试。
- 修改 `test/logbook_page_test.dart`：点击新战斗、旧记录不可进入、返回保持列表测试。

### 任务 1：详情领域模型

- [ ] **步骤 1：编写失败的 JSON 往返测试**

在 `test/battle_detail_models_test.dart` 构造包含四舰队、一条三段攻击和损管字段的快照，断言 `BattleDetailSnapshot.fromJson(snapshot.toJson())` 保持版本、舰位、装备、每段伤害及段后 HP。

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/battle_detail_models_test.dart`

预期：FAIL，提示 `battle_detail_models.dart` 或模型类型不存在。

- [ ] **步骤 3：实现最小完整模型**

实现不可变类型 `BattleDetailSnapshot`、`BattleDetailFleet`、`BattleDetailShip`、`BattleDetailEquipment`、`BattleDetailStage`、`BattleDetailAttack`、`BattleDetailHit`，全部提供显式 `toJson/fromJson`。枚举按稳定字符串编码，未知值回退到安全默认值；集合反序列化后不可修改。

- [ ] **步骤 4：运行模型测试**

运行：`flutter test test/battle_detail_models_test.dart`

预期：PASS。

- [ ] **步骤 5：提交任务 1**

运行：`git add lib/src/battle/battle_detail_models.dart lib/src/battle/battle_models.dart test/battle_detail_models_test.dart && git commit -m "feat(战斗详情): 添加版本化战斗快照模型（任务 1/5）"`

### 任务 2：战斗包回放为攻击事件

- [ ] **步骤 1：编写失败的回放测试**

在 `test/battle_detail_replay_builder_test.dart` 使用紧凑的昼战和夜战包覆盖：我方三段攻击敌方、敌方攻击我方随伴舰、未命中、段后 HP，以及四舰队归属。断言阶段顺序和左右阵营准确。

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/battle_detail_replay_builder_test.dart`

预期：FAIL，提示 `BattleDetailReplayBuilder` 不存在。

- [ ] **步骤 3：实现回放构建器**

构建器接收 `BattleSession`、最终 `LiveBattle`、完成时间、舰娘等级表及装备名称表。先复制开战 HP 状态，再依 POI 顺序解析航空、支援、反潜、雷击、炮击和夜战字段；每段命中立即更新目标 HP 并生成 `BattleDetailHit`。攻击者无法确定时保留阶段来源。用舰队实际槽位长度和联合舰队标记解析绝对舰位。

- [ ] **步骤 4：运行回放与现有预测测试**

运行：`flutter test test/battle_detail_replay_builder_test.dart test/poi_battle_prediction_engine_test.dart`

预期：全部 PASS。

- [ ] **步骤 5：提交任务 2**

运行：`git add lib/src/battle/battle_detail_replay_builder.dart test/battle_detail_replay_builder_test.dart && git commit -m "feat(战斗详情): 生成逐段战斗回放（任务 2/5）"`

### 任务 3：捕获链路与数据库持久化

- [ ] **步骤 1：编写失败的数据库测试**

在 `test/logbook_database_test.dart` 新增：新库拥有 `detail_json`；模拟 v10 数据库升级后旧行字段为空；插入带详情 `BattleRecord` 后 `getBattleDetail(id)` 返回完整快照。

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/logbook_database_test.dart`

预期：FAIL，字段或查询方法不存在。

- [ ] **步骤 3：实现 v11 与捕获接线**

将 schema 提升到 11，创建/升级时加入 `detail_json TEXT`。`insertBattleRecord` 写入 JSON 并返回记录 ID；`getBattleDetail` 只查询真实 battle ID 并安全解析。`BattleController` 在战果到达且会话未归档时生成快照；失败只记录调试信息，不影响原战果入库。

- [ ] **步骤 4：运行数据库和控制器测试**

运行：`flutter test test/logbook_database_test.dart test/battle_controller_test.dart test/battle_session_test.dart`

预期：全部 PASS。

- [ ] **步骤 5：提交任务 3**

运行：`git add lib/src/logbook/logbook_database.dart lib/src/battle/battle_controller.dart test/logbook_database_test.dart test/battle_controller_test.dart && git commit -m "feat(航海日志): 保存新战斗详情快照（任务 3/5）"`

### 任务 4：响应式详情页面

- [ ] **步骤 1：编写失败的页面测试**

在 `test/battle_detail_page_test.dart` 构造完整快照，逐一设置 915×412、914×836、1280×800、800×1280。断言只存在「舰队」「战斗过程」，四个舰队标题正确；切换过程页后双方攻击、逐段伤害和左右箭头可见；筛选敌方攻击有效；不存在 `battle-stage-sidebar`、结算和原始数据；测试期间无 Flutter 布局异常。

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/battle_detail_page_test.dart`

预期：FAIL，页面类型不存在。

- [ ] **步骤 3：实现页面**

实现 `BattleDetailPage`：紧凑元信息头、两个 Yahagi 风格胶囊页签、舰队对比卡片、内联可折叠阶段、全部/我方/敌方筛选。宽度不小于 840 时使用七列攻击行，较窄时使用两层卡片；页面只纵向滚动。

- [ ] **步骤 4：运行详情页面测试**

运行：`flutter test test/battle_detail_page_test.dart`

预期：全部 PASS 且无 overflow 日志。

- [ ] **步骤 5：提交任务 4**

运行：`git add lib/src/logbook/battle_detail_page.dart test/battle_detail_page_test.dart && git commit -m "feat(战斗详情): 实现响应式舰队与过程页面（任务 4/5）"`

### 任务 5：从出击记录进入并完成回归

- [ ] **步骤 1：编写失败的日志交互测试**

修改 `test/logbook_page_test.dart`：插入一条带详情和一条旧战斗，点击带详情的整行进入页面，点返回后仍显示相同过滤结果；点击旧行不切换。断言资源节点不具按钮语义。

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/logbook_page_test.dart`

预期：FAIL，战斗行未打开详情。

- [ ] **步骤 3：接入日志列表**

给出击查询增加 `has_detail` 轻量标记。`_LogbookTablePageState` 保存当前详情和加载状态，仅对 `record_type == battle && has_detail == 1` 传递行点击；点击时把合成行 ID 还原为 battle ID 并懒加载。用 `IndexedStack` 保留原表格 State，详情返回只清除选择。

- [ ] **步骤 4：格式化并执行完整验证**

运行：

```powershell
dart format lib/src/battle/battle_detail_models.dart lib/src/battle/battle_detail_replay_builder.dart lib/src/battle/battle_models.dart lib/src/battle/battle_controller.dart lib/src/logbook/logbook_database.dart lib/src/logbook/battle_detail_page.dart lib/src/logbook/logbook_page.dart test/battle_detail_models_test.dart test/battle_detail_replay_builder_test.dart test/logbook_database_test.dart test/battle_detail_page_test.dart test/logbook_page_test.dart
flutter test test/battle_detail_models_test.dart test/battle_detail_replay_builder_test.dart test/logbook_database_test.dart test/battle_detail_page_test.dart test/logbook_page_test.dart test/poi_battle_prediction_engine_test.dart test/battle_controller_test.dart
flutter analyze
```

预期：格式化无错误；所有测试 PASS；静态检查无新增问题。禁止运行 `flutter build apk --debug`。

- [ ] **步骤 5：提交任务 5**

运行：`git add lib/src/logbook/logbook_page.dart test/logbook_page_test.dart && git commit -m "feat(出击记录): 点击战斗行查看详情（任务 5/5）"`

## 自检结果

- 规格中的未来捕获、四舰队、双方伤害、多段攻击、两页签、无阶段侧栏、四种尺寸和返回状态均有对应任务。
- 模型、构建器、数据库方法和页面命名在各任务间一致。
- 每项实现之前均有明确失败测试，每项验证均给出可运行命令。
- 计划不包含旧数据导入、结算页、原始 JSON 页或自动弹窗。
