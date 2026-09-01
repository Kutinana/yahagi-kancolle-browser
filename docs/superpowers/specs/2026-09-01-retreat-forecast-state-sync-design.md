# 退避状态即时同步设计

## 背景

联合舰队使用舰队司令部设施后，游戏会先在战斗结果中给出待退避舰和伴随舰，并在玩家确认退避的 `goback_port` 请求中正式生效。当前舰队简报由 `GameStateController` 直接读取状态，因此会正确显示退避；未卜先知由 `BattleController` 缓存 `LiveBattle`，两个控制器各自异步排队，导致 `BattleController` 偶尔在 `GameStateController` 完成本次事件前读取旧状态。结果是未卜先知要等到下一次进战，才通过战斗包里的缺席哨兵补上退避状态。

POI 在同一个 Redux 状态流内按顺序把待退避位置提交为已退避位置，因此不存在跨控制器读取旧快照的问题。

## 目标

- 玩家确认退避后，未卜先知在当前罗盘或航路选择画面立即显示退避。
- 退避舰和伴随舰保留最后一次真实血量，只更新独立的 `isEscaped` 状态。
- 下一节点继续保持退避状态，不依赖下一场战斗包修正。
- 不改变 POI 战斗预测、大破提醒和损管推演的现有规则。

## 方案

给 `BattleController` 注入一个可选的游戏状态同步屏障 `waitForGameState`。主程序把它绑定到 `gameStateController.idle`。`BattleController` 每次处理已接收事件前，先等待游戏状态控制器处理完同一批已排队事件，再调用 `_reduce` 读取 `gameState()`。

事件顺序如下：

1. API 管线依次把事件交给 `GameStateController` 和 `BattleController`。
2. `GameStateController` 把状态归约加入自己的队列。
3. `BattleController` 把战斗处理加入自己的队列。
4. 战斗队列开始处理时等待 `gameStateController.idle`。
5. `goback_port` 已把 `pendingEscapeShipIds` 提交到 `escapedShipIds` 后，`BattleController` 立即把当前 `LiveBattle` 中对应两舰标记为退避。

测试和其他独立调用方可以不传屏障，保持现有构造方式和行为。

## 血量与提醒规则

- 退避状态和血量是两个字段：确认退避只设置 `isEscaped=true`，不把血量清零或改成负数。
- 后续战斗包中的 `-1` 只表示该位置不参战，不能覆盖最后一次真实血量。
- 非退避舰的血量继续由现有友军血量回写逻辑同步到 `GameStateController`。
- 退避确认前，大破舰仍按现有规则触发提醒；确认后，已退避舰被提醒过滤，其他大破舰仍会提醒。
- POI 预测和损管推演仍在状态同步之后执行，不改变计算逻辑。

同步屏障只发生在一次战斗事件开始处理之前。预测完成后的友军血量回写不会被本事件再次等待，因此不会形成 `BattleController` 与 `GameStateController` 互相等待的死锁。

## 测试策略

- 增加竞态回归测试：先把 `goback_port` 交给 `BattleController`，延迟游戏状态更新，确认控制器会等待；状态完成后应在同一事件内立即标记两艘退避舰。
- 断言退避舰最后真实血量不变，未退避舰状态不受影响。
- 验证下一次地图移动仍保留退避标记，不必等下一场战斗。
- 运行退避与提醒专项测试、战斗控制器和损管生命周期测试。
- 运行完整 Flutter 测试套件及 POI 战斗数据集回归。

## 非目标

- 不修改舰队司令部 API 的候选解析规则。
- 不调整未卜先知和舰队简报的 UI 布局。
- 不重新引入轻量战斗模式。
