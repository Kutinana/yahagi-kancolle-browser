# 新舰提醒与未持有一览实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在持有一览增加未持有舰娘和装备页面，并在当前未持有舰系通过掉落、奖励或建造加入时，于母港显示带震动的新舰上锁提醒。

**架构：** 扩展游戏主数据以保存账号 ID 和舰娘改造后继关系，由纯投影模块计算舰系根节点及未持有内容。独立 API 消费者在事件处理前取得持有快照，负责持久化排除名单和战斗待发布队列；提醒控制器把发布事件分发给游戏内对话框、通知协调器和震动端口。持有一览维持现有表格实现，只在未持有分支渲染新的折叠卡片列表。

**技术栈：** Flutter、Dart、ChangeNotifier、SharedPreferences、MethodChannel、Android Kotlin、flutter_test。

---

## 文件结构

- 修改 `lib/src/game_state/game_state.dart`：增加账号 ID、舰娘改造后继 ID 和装备类型名字段。
- 修改 `lib/src/game_state/game_state_reducer.dart`：解析 `api_member_id`、`api_aftershipid` 和装备类型主数据。
- 修改 `lib/src/game_state/game_state_serializer.dart`：兼容保存和恢复新增字段。
- 创建 `lib/src/inventory/unowned_inventory_projection.dart`：计算舰系根节点、未持有舰系和未持有装备。
- 创建 `lib/src/new_ship/new_ship_reminder_store.dart`：按账号保存排除舰系、战斗待发布事件和幂等键。
- 创建 `lib/src/new_ship/new_ship_reminder_controller.dart`：实现 API 消费、发布队列和 UI 提醒状态。
- 创建 `lib/src/new_ship/new_ship_alert_port.dart`：封装新舰短震动 MethodChannel。
- 修改 `lib/src/notification/notification_models.dart`：增加 `newShip` 通知类型。
- 修改 `lib/src/notification/game_notification_coordinator.dart`：接收外部新舰即时通知并沿用快照重试。
- 修改 `android/app/src/main/kotlin/app/yahagi/kancollebrowser/MainActivity.kt`：注册新舰短震动方法。
- 修改 `lib/src/inventory/owned_inventory_page.dart`：增加未持有舰娘和装备内容。
- 修改 `lib/src/layout/workspace_context_header.dart`、`lib/main.dart`：提升两组页签状态并接入提醒控制器。
- 修改 `lib/l10n/app_*.arb`：增加简体中文、繁体中文、日文和英文文案，并重新生成本地化代码。
- 创建对应的 `test/new_ship/*_test.dart`、`test/unowned_inventory_projection_test.dart` 和 Widget 测试。

### 任务 1：扩展账号、舰娘改造链和装备类型主数据

**文件：**
- 修改：`lib/src/game_state/game_state.dart`
- 修改：`lib/src/game_state/game_state_reducer.dart`
- 修改：`lib/src/game_state/game_state_serializer.dart`
- 测试：`test/game_state_reducer_test.dart`
- 测试：`test/game_state_serializer_test.dart`

- [ ] **步骤 1：编写失败的解析测试**

在 `game_state_reducer_test.dart` 的 start2 与 basic 测试中断言：

```dart
expect(next.memberId, 90001);
expect(next.masterShips[1]?.afterShipId, 2);
expect(next.masterSlotItemTypes[1], '小口径主炮');
```

在 `game_state_serializer_test.dart` 中构造包含上述字段的 `GameState`，序列化再反序列化后断言字段保持不变。

- [ ] **步骤 2：运行测试验证失败**

运行：

```powershell
flutter test test/game_state_reducer_test.dart test/game_state_serializer_test.dart
```

预期：编译失败，提示 `memberId`、`afterShipId` 或 `masterSlotItemTypes` 未定义。

- [ ] **步骤 3：实现最少字段与解析**

为 `GameState` 增加 `memberId` 和 `masterSlotItemTypes`，为 `MasterShip` 增加 `afterShipId`。从 `api_basic.api_member_id`、`api_mst_ship.api_aftershipid` 和 `api_mst_slotitem_equiptype` 解析值，并在序列化器中以可选字段保持向后兼容。

- [ ] **步骤 4：运行测试验证通过**

运行同一步骤 2，预期全部 PASS。

- [ ] **步骤 5：提交**

```powershell
git add lib/src/game_state test/game_state_reducer_test.dart test/game_state_serializer_test.dart
git commit -m "feat(游戏数据): 保存账号与舰娘改造关系"
```

### 任务 2：实现未持有内容投影

**文件：**
- 创建：`lib/src/inventory/unowned_inventory_projection.dart`
- 测试：`test/unowned_inventory_projection_test.dart`

- [ ] **步骤 1：编写失败的投影测试**

覆盖以下行为：

```dart
final projection = UnownedInventoryProjection(state);
expect(projection.familyRootOf(3), 1);
expect(projection.unownedShipFamilies.map((row) => row.master.id), [4]);
expect(projection.unownedEquipment.map((row) => row.master.id), [102]);
```

测试数据包含 `1 -> 2 -> 3` 改造链、当前持有 Master ID 3、未持有 Master ID 4、已持有装备 101、未持有玩家装备 102，以及 `sortNo == 0` 的内部装备 999。

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/unowned_inventory_projection_test.dart`

预期：编译失败，提示 `UnownedInventoryProjection` 未定义。

- [ ] **步骤 3：实现纯投影**

实现不可变的 `UnownedShipFamilyRow` 和 `UnownedEquipmentRow`。改造链使用反向表求根并缓存；循环和缺失后继引用返回自身。舰娘只返回 `sortNo > 0` 的未持有根舰，装备只返回 `sortNo > 0`、类型有效且当前实例数量为 0 的项目。

- [ ] **步骤 4：运行测试验证通过**

运行同一步骤 2，预期全部 PASS。

- [ ] **步骤 5：提交**

```powershell
git add lib/src/inventory/unowned_inventory_projection.dart test/unowned_inventory_projection_test.dart
git commit -m "feat(持有一览): 计算未持有舰系与装备"
```

### 任务 3：实现账号级排除和待发布存储

**文件：**
- 创建：`lib/src/new_ship/new_ship_reminder_store.dart`
- 测试：`test/new_ship/new_ship_reminder_store_test.dart`

- [ ] **步骤 1：编写失败的存储测试**

使用内存 `SharedPreferences.setMockInitialValues` 验证：

```dart
await store.saveExcludedFamilyIds(1001, {1, 4});
expect(await store.loadExcludedFamilyIds(1001), {1, 4});
expect(await store.loadExcludedFamilyIds(1002), isEmpty);
await store.savePending(1001, [pending]);
expect(await store.loadPending(1001), [pending]);
```

同时验证损坏 JSON 返回空集合并保留其他账号数据。

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/new_ship/new_ship_reminder_store_test.dart`

预期：编译失败，提示存储类型未定义。

- [ ] **步骤 3：实现 SharedPreferences 存储**

定义 `PendingNewShipAcquisition`，字段为 `key`、`masterIds`、`source`、`occurredAt`。键名以账号 ID 分区；所有列表先排序再编码，幂等键最多保留最近 128 项。

- [ ] **步骤 4：运行测试验证通过并提交**

运行同一步骤 2，预期全部 PASS，然后提交：

```powershell
git add lib/src/new_ship/new_ship_reminder_store.dart test/new_ship/new_ship_reminder_store_test.dart
git commit -m "feat(新舰提醒): 持久化排除与待提醒事件"
```

### 任务 4：实现新舰 API 消费与母港发布

**文件：**
- 创建：`lib/src/new_ship/new_ship_reminder_controller.dart`
- 测试：`test/new_ship/new_ship_reminder_controller_test.dart`

- [ ] **步骤 1：编写失败的事件测试**

使用可控 `GameState`、内存 Store 和发布回调验证：

```dart
controller.accept(battleResult(dropMasterId: 4));
await controller.idle;
expect(published, isEmpty);
controller.accept(portEvent());
await controller.idle;
expect(published.single.masterIds, [4]);
```

另测当前持有同舰系、已排除舰系、活动奖励、任务奖励、建造开箱、重复 sequence、多舰合并和账号切换。

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/new_ship/new_ship_reminder_controller_test.dart`

预期：编译失败，提示 Controller 未定义。

- [ ] **步骤 3：实现消费者和提醒状态**

Controller 实现 `GameApiEventConsumer` 和 `ChangeNotifier`。`accept` 同步捕获事件前状态，内部队列解析 `decodedEnvelope`；战斗结果写 pending，母港消费 pending，任务与建造直接发布。发布结果以 `NewShipAlert` 暴露，并提供 `acknowledge(alertKey)`。

- [ ] **步骤 4：运行测试验证通过并提交**

运行同一步骤 2，预期全部 PASS，然后提交：

```powershell
git add lib/src/new_ship/new_ship_reminder_controller.dart test/new_ship/new_ship_reminder_controller_test.dart
git commit -m "feat(新舰提醒): 检测获取事件并在母港发布"
```

### 任务 5：接入系统通知和短震动

**文件：**
- 创建：`lib/src/new_ship/new_ship_alert_port.dart`
- 修改：`lib/src/notification/notification_models.dart`
- 修改：`lib/src/notification/game_notification_coordinator.dart`
- 修改：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/MainActivity.kt`
- 修改：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/BattleDamageVibration.kt`
- 测试：`test/new_ship/new_ship_alert_port_test.dart`
- 测试：`test/notification/game_notification_coordinator_test.dart`

- [ ] **步骤 1：编写失败的交付测试**

断言 `GameNotificationType.newShip.channelId == 'channel_newShip'`；向协调器提交 `NewShipAlert` 后，Fake Port 收到 1 条标题为「获得新舰」的即时通知。MethodChannel 测试断言调用 `alertNewShip`，多舰合并只调用一次。

- [ ] **步骤 2：运行测试验证失败**

运行：

```powershell
flutter test test/new_ship/new_ship_alert_port_test.dart test/notification/game_notification_coordinator_test.dart
```

预期：编译失败，提示 `newShip` 或 `alertNewShip` 未定义。

- [ ] **步骤 3：实现通知和震动**

为通知协调器增加 `enqueueImmediateAlert` 公共入口，复用已有 `_pendingImmediateAlerts`、快照合并和重试。新舰 Port 使用独立 MethodChannel 方法 `alertNewShip`；Android 端执行单次短震动并在没有振动器或权限时返回 false，不抛出到 Flutter API 管线。

- [ ] **步骤 4：运行测试验证通过并提交**

运行同一步骤 2，预期全部 PASS，然后提交：

```powershell
git add lib/src/new_ship lib/src/notification android/app/src/main/kotlin/app/yahagi/kancollebrowser test/new_ship test/notification/game_notification_coordinator_test.dart
git commit -m "feat(新舰提醒): 接入系统通知与震动"
```

### 任务 6：实现持有一览四状态界面

**文件：**
- 修改：`lib/src/inventory/owned_inventory_page.dart`
- 修改：`lib/src/layout/workspace_context_header.dart`
- 修改：`lib/main.dart`
- 修改：`lib/l10n/app_en.arb`
- 修改：`lib/l10n/app_ja.arb`
- 修改：`lib/l10n/app_zh.arb`
- 修改：`lib/l10n/app_zh_Hant.arb`
- 测试：`test/owned_inventory_unowned_view_test.dart`
- 测试：`test/owned_inventory_layout_test.dart`

- [ ] **步骤 1：编写失败的 Widget 测试**

断言顶部存在 `inventory-ownership-segmented` 和现有内容页签；切换到未持有舰娘后出现舰种折叠、两行卡片和排除复选框；切到装备后不出现图鉴编号、属性、搜索和复选框。长舰名在 800 × 480 尺寸下无 Flutter overflow。

- [ ] **步骤 2：运行测试验证失败**

运行：

```powershell
flutter test test/owned_inventory_unowned_view_test.dart test/owned_inventory_layout_test.dart
```

预期：找不到 ownership segmented 或未持有页面控件。

- [ ] **步骤 3：实现 UI 和本地化**

为 Header 增加 `inventoryShowOwned` 及回调，在 `YahagiShell` 提升状态。`OwnedInventoryPage` 接收 Reminder Controller；持有分支不改现有投影和表格，未持有分支使用 `ExpansionTile` 与紧凑卡片。舰娘卡片为头像、两行文字和 Checkbox；装备卡片为图标和两行文字。

运行：`flutter gen-l10n`

- [ ] **步骤 4：运行 Widget 测试验证通过并提交**

运行同一步骤 2，预期全部 PASS，然后提交：

```powershell
git add lib/main.dart lib/src/inventory lib/src/layout lib/l10n test/owned_inventory_unowned_view_test.dart test/owned_inventory_layout_test.dart
git commit -m "feat(持有一览): 添加未持有舰娘与装备页面"
```

### 任务 7：接线游戏内对话框并完成回归验证

**文件：**
- 创建：`lib/src/new_ship/new_ship_alert_overlay.dart`
- 修改：`lib/main.dart`
- 测试：`test/new_ship/new_ship_alert_overlay_test.dart`

- [ ] **步骤 1：编写失败的对话框测试**

发布包含 2 艘舰娘的 `NewShipAlert`，断言标题、舰名列表和「记得上锁」均存在；点击遮罩不关闭；点击「知道了」后调用 `acknowledge`。震动关闭时 Port 不调用，开启时只调用 1 次。

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/new_ship/new_ship_alert_overlay_test.dart`

预期：编译失败，提示 Overlay 未定义。

- [ ] **步骤 3：实现 Overlay 与应用接线**

在应用根部包裹 `NewShipAlertOverlay`。初始化 Reminder Controller 后加入 `GameApiEventPipeline.consumers`，将发布回调接到通知协调器；Overlay 监听 Controller 并以 `barrierDismissible: false` 展示对话框，按现有通知震动设置调用 Port。

- [ ] **步骤 4：运行定向测试**

运行：

```powershell
flutter test test/new_ship test/unowned_inventory_projection_test.dart test/owned_inventory_unowned_view_test.dart test/owned_inventory_layout_test.dart test/game_state_reducer_test.dart test/game_state_serializer_test.dart test/notification/game_notification_coordinator_test.dart
```

预期：全部 PASS。

- [ ] **步骤 5：运行完整质量检查**

运行：

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

预期：格式检查退出码 0、`flutter analyze` 无错误、全量测试 0 failure。

- [ ] **步骤 6：提交**

```powershell
git add lib/main.dart lib/src/new_ship test/new_ship
git commit -m "feat(新舰提醒): 显示母港上锁提示"
```
