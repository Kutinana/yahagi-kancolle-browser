# POI 退避事实来源修复实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 `executing-plans` 在当前会话逐项实现，并在完成前使用 `verification-before-completion`。

**目标：** 让退避状态只来自战果接口的首个退避/拖带位置，并只在 `goback_port` 后生效，彻底移除负血量和 `map/next` 的退避推断。

**架构：** 保留当前按舰娘实例 ID 存储状态和跨控制器同步屏障；收窄退避事实来源，使它在有效 API 流程上与 POI 等价。负 HP 继续只承担“不参战/不覆盖最后真实血量”的含义。

**技术栈：** Dart 3、Flutter、`flutter_test`、POI Redux 参考实现。

---

### 任务 1：锁定 POI 语义的失败用例

**文件：**

- 修改：`test/fcf_retreat_battle_warning_test.dart`

- [ ] 把“负 HP 自动退避”两条旧测试改为“负 HP 不产生退避”，并断言保留最后真实 HP。
- [ ] 把 `map/next` 测试改为候选仍处于 pending、不得进入 escaped。
- [ ] 增加“数组只看首项；后续正数候选不能顶替无效首项”的测试。
- [ ] 运行 `flutter test test/fcf_retreat_battle_warning_test.dart`，确认因现有推断逻辑而失败。

### 任务 2：最小化实现 POI 判断方式

**文件：**

- 修改：`lib/src/battle/battle_controller.dart`
- 修改：`lib/src/game_state/combat_state.dart`
- 修改：`lib/src/game_state/game_state_reducer.dart`

- [ ] 从 `_friendFleet` 的初次和后续阶段删除 `nowHp < 0 => isEscaped`。
- [ ] `map/next` 只移动节点，不提交 `pendingEscapeShipIds`；新出击仍清空全部退避状态。
- [ ] 退避/拖带数组只读取索引 0，保留标量兼容，并忽略非正索引。
- [ ] 运行专项测试确认全部通过。

### 任务 3：审计与完整验证

**文件：**

- 审计：`lib/src/game_state/game_state_reducer.dart`
- 审计：`lib/src/battle/battle_controller.dart`
- 验证：相关战斗、提醒、损管与 POI 数据集测试。

- [ ] 搜索所有 `escapedShipIds` / `pendingEscapeShipIds` 写入点，确认没有其他 HP 或阶段推断。
- [ ] 运行退避、大破提醒、战斗控制器、损管生命周期专项测试。
- [ ] 用完整 POI fixture 运行 `test/battle_poi_corpus_test.dart`。
- [ ] 运行 `flutter analyze`、完整 `flutter test`、`git diff --check`。
- [ ] 按中文代码审查规范检查最终差异，只提交本次两个实现文件、测试和计划文档，不带入装备开发的现有改动。
