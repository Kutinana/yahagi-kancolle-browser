# 出击道具掉落 POI 对齐修复设计

## 背景

Yahagi v1.0.5 已在航海日志的「出击」表中增加「道具掉落」列，但战斗结算解析只覆盖 `api_get_useitem` 和 `api_get_eventitem`。实服响应还会通过 `api_get_exmap_useitem_id` 返回 EO 等海域的结算道具。该字段未进入 `BattleRewardItem`，导致数据库保存空奖励数组，界面最终显示 `-`。

POI 对普通舰队与联合舰队的战斗结算使用相同规则：分别读取 `api_get_useitem.api_useitem_id` 和 `api_get_exmap_useitem_id`，将有效 ID 对应的道具数量各增加 1。

## 目标

- 航海日志能够记录并显示 `api_get_exmap_useitem_id` 返回的道具。
- 普通舰队和联合舰队结算使用同一套解析逻辑。
- 同时兼容数字与数字字符串形式的道具 ID。
- 保持现有 `api_get_useitem`、`api_get_eventitem`、舰娘掉落、地图资源和数据库结构不变。

## 方案

在 `BattleController._applyResult` 中解析 `api_get_exmap_useitem_id`。当 ID 大于 0 时，向本次战斗的 `rewardItems` 增加一项：

- `kind`：`BattleRewardKind.item`
- `id`：解析后的道具 ID
- `count`：`1`
- `name`：通过现有 `expeditionRewardName` 解析；目录中没有该 ID 时保留「道具 ID」回退文本

不把该字段写入旧的 `dropItemId` 和 `dropItemName`。这两个字段继续表示 `api_get_useitem`，航海日志统一从 `rewardItems` 展示全部道具，避免改变旧接口语义。

## 数据流

1. `BattleController` 收到普通或联合舰队的 `battleresult`。
2. `_applyResult` 解析 `api_get_useitem`、`api_get_exmap_useitem_id` 和 `api_get_eventitem`。
3. 所有非舰娘奖励进入 `LiveBattle.rewardItems`。
4. `LogbookDatabase.insertBattleRecord` 将奖励编码到 `reward_items_json`。
5. 航海日志「道具掉落」列从该 JSON 显示「名称 ×数量」。

## 边界与兼容性

- 缺失、`null`、空字符串、非数字、`0` 和负数均不生成奖励。
- 数字 `57` 与字符串 `"57"` 产生相同的勋章奖励。
- 若 `api_get_useitem`、`api_get_exmap_useitem_id` 和 `api_get_eventitem` 同时存在，全部保留，不互相覆盖。
- 不修改 SQLite 版本，不迁移旧数据；历史上未保存的道具无法恢复。
- 不在本次修复中引入完整 `api_mst_useitem` 主数据模型，避免扩大修改范围。

## 测试设计

采用测试驱动开发（Test-Driven Development，TDD）：

1. 先添加 POI 实录形态的失败测试：普通舰队结算返回 `"api_get_exmap_useitem_id": "57"`，期望得到「勋章 ×1」。
2. 添加联合舰队与数字 ID 测试，证明两个结算路径共用正确逻辑。
3. 添加无效 ID 测试，确保不会产生伪奖励。
4. 保留并运行现有多奖励测试，确认 `api_get_useitem` 与 `api_get_eventitem` 没有回归。
5. 运行航海日志数据库和 Widget 测试，确认奖励可持久化并显示。
6. 运行相关目录静态分析、格式检查和 `git diff --check`。

## 验收标准

- POI 实录中的字符串 `"57"` 被解析为「勋章 ×1」。
- 普通与联合舰队结算均能记录 `api_get_exmap_useitem_id`。
- 无效字段不会污染日志。
- 多来源奖励不会互相覆盖。
- 定向测试、航海日志回归测试、静态分析和格式检查全部通过。
