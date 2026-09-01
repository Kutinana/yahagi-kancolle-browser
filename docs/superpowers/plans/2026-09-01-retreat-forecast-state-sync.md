# 退避状态即时同步实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 `executing-plans` 按任务逐项实现，并在宣称完成前使用 `verification-before-completion`。

**目标：** 消除舰队简报和未卜先知之间的退避状态竞态，使玩家确认退避后立即同步退避标记和一致的血量状态。

**架构：** 在 `BattleController` 处理每个事件前等待 `GameStateController` 的事件队列空闲。事件解析、POI 预测、损管和提醒逻辑保持不变，只修正读取状态的先后关系。

**技术栈：** Dart、Flutter、`flutter_test`、现有 `GameApiEventPipeline` / `GameStateController` / `BattleController`。

---

## 任务 1：用回归测试复现跨控制器竞态

**文件：**

- 修改：`test/fcf_retreat_battle_warning_test.dart`

**步骤：**

1. 在现有 `goback_port` 测试中加入可控的游戏状态同步屏障。
2. 先向 `BattleController` 投递确认退避事件，再延迟更新游戏状态，模拟真实 API 管线的独立异步队列。
3. 断言屏障释放前战斗控制器不会读取旧状态。
4. 释放屏障后断言退避舰和伴随舰立即变为 `isEscaped=true`。
5. 断言退避舰保留最后真实血量，其他舰状态不受影响。
6. 运行：

   `flutter test test/fcf_retreat_battle_warning_test.dart`

   在实现前应因缺少同步能力而失败；实现后应全部通过。

## 任务 2：实现游戏状态同步屏障

**文件：**

- 修改：`lib/src/battle/battle_controller.dart`
- 修改：`lib/main.dart`

**步骤：**

1. 给 `BattleController` 增加可选的 `Future<void> Function()? waitForGameState` 依赖。
2. 在战斗事件队列调用 `_reduce` 前等待该屏障，并在等待后重新检查控制器是否已释放。
3. 主程序构造 `BattleController` 时传入 `() => gameStateController.idle`。
4. 保持测试和独立调用方未传屏障时的原有行为。
5. 运行任务 1 的专项测试，确认竞态回归通过。
6. 运行格式化和涉及文件的静态分析。

## 任务 3：验证提醒、预测、损管及完整数据集

**文件：**

- 如测试暴露真实缺陷，最小修改相应实现和测试文件。

**步骤：**

1. 运行退避、大破提醒、战斗控制器、损管生命周期专项测试。
2. 运行 POI 预测相关测试和完整战斗数据集回归，确认预测结果没有变化。
3. 运行完整 `flutter test`。
4. 对修改文件运行静态分析，并检查 `git diff --check`。
5. 审核最终差异，确认只包含本次同步修复和对应文档测试。
6. 按任务提交到当前 `master`，提交信息使用中文 Conventional Commits。
