# 出击道具掉落 POI 对齐修复实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 让普通与联合舰队结算中的 `api_get_exmap_useitem_id` 正确进入航海日志「道具掉落」列。

**架构：** 保持现有奖励模型、数据库和界面不变，只在 `BattleController` 的统一战斗结算入口补齐 POI 已处理的字段。通过控制器测试锁定字符串、数字和无效 ID 行为，再用现有数据库与 Widget 测试验证持久化和显示链路。

**技术栈：** Flutter、Dart、flutter_test、sqflite。

---

## 文件职责

- 修改 `test/battle_controller_test.dart`：增加实服字段形态和普通／联合结算回归测试。
- 修改 `lib/src/battle/battle_controller.dart`：解析 `api_get_exmap_useitem_id` 并生成 `BattleRewardItem`。
- 验证 `lib/src/logbook/logbook_database.dart`：现有 `reward_items_json` 持久化链路不变。
- 验证 `lib/src/logbook/logbook_page.dart`：现有「道具掉落」渲染链路不变。

### 任务 1：用失败测试锁定 POI 对齐行为

**文件：**
- 修改：`test/battle_controller_test.dart`

- [ ] **步骤 1：添加普通舰队字符串 ID 测试**

在现有战斗奖励测试附近加入测试。使用 POI 实录中的字段形态，期望字符串 `"57"` 解析为勋章：

```dart
test('records string extra-map useitem reward from sortie result', () async {
  final reducer = GameStateReducer();
  var state = reducer.reduce(GameState.empty, start2Event);
  state = reducer.reduce(state, portEvent);
  final controller = BattleController(gameState: () => state);
  addTearDown(controller.dispose);

  controller
    ..accept(mapStartEvent)
    ..accept(dayBattleEvent)
    ..accept(
      kcsapiEvent('/kcsapi/api_req_sortie/battleresult', <String, Object?>{
        'api_win_rank': 'S',
        'api_get_exmap_useitem_id': '57',
      }, sequence: 223),
    );
  await controller.idle;

  expect(controller.current!.rewardItems, const <BattleRewardItem>[
    BattleRewardItem(
      kind: BattleRewardKind.item,
      id: 57,
      count: 1,
      name: '勋章',
    ),
  ]);
});
```

- [ ] **步骤 2：添加联合舰队数字 ID 测试**

使用联合舰队结果端点和数字 ID，期望使用相同规则：

```dart
test('records numeric extra-map useitem reward from combined result', () async {
  final reducer = GameStateReducer();
  var state = reducer.reduce(GameState.empty, start2Event);
  state = reducer.reduce(state, portEvent);
  final controller = BattleController(gameState: () => state);
  addTearDown(controller.dispose);

  controller
    ..accept(mapStartEvent)
    ..accept(dayBattleEvent)
    ..accept(
      kcsapiEvent(
        '/kcsapi/api_req_combined_battle/battleresult',
        <String, Object?>{
          'api_win_rank': 'S',
          'api_get_exmap_useitem_id': 57,
        },
        sequence: 224,
      ),
    );
  await controller.idle;

  expect(controller.current!.rewardItems.single.id, 57);
  expect(controller.current!.rewardItems.single.name, '勋章');
});
```

- [ ] **步骤 3：添加无效 ID 测试**

```dart
test('ignores invalid extra-map useitem reward ids', () async {
  final reducer = GameStateReducer();
  var state = reducer.reduce(GameState.empty, start2Event);
  state = reducer.reduce(state, portEvent);
  final controller = BattleController(gameState: () => state);
  addTearDown(controller.dispose);

  controller
    ..accept(mapStartEvent)
    ..accept(dayBattleEvent)
    ..accept(
      kcsapiEvent('/kcsapi/api_req_sortie/battleresult', <String, Object?>{
        'api_win_rank': 'S',
        'api_get_exmap_useitem_id': 'not-a-number',
      }, sequence: 225),
    );
  await controller.idle;

  expect(controller.current!.rewardItems, isEmpty);
});
```

- [ ] **步骤 4：运行红灯测试**

运行：

```powershell
flutter test test/battle_controller_test.dart --plain-name "records string extra-map useitem reward from sortie result"
flutter test test/battle_controller_test.dart --plain-name "records numeric extra-map useitem reward from combined result"
```

预期：两个命令均 FAIL，实际奖励列表为空。无效 ID 测试预期 PASS，用于锁定现有容错边界。

- [ ] **步骤 5：提交测试红灯**

```powershell
git add -- test/battle_controller_test.dart
git commit -m "test(航海日志): 复现海域结算道具漏记"
```

### 任务 2：实现最小字段解析

**文件：**
- 修改：`lib/src/battle/battle_controller.dart:650-673`
- 测试：`test/battle_controller_test.dart`

- [ ] **步骤 1：读取并校验额外海域道具 ID**

在 `_applyResult` 中与 `getItem`、`eventRewards` 一起解析：

```dart
final extraMapUseItemId = _positive(data['api_get_exmap_useitem_id'], 0);
```

- [ ] **步骤 2：把有效 ID 追加到统一奖励列表**

在普通道具之后、活动奖励之前增加：

```dart
if (extraMapUseItemId > 0)
  BattleRewardItem(
    kind: BattleRewardKind.item,
    id: extraMapUseItemId,
    count: 1,
    name: expeditionRewardName(extraMapUseItemId),
  ),
```

不得修改 `dropItemId`、`dropItemName` 或数据库结构。

- [ ] **步骤 3：格式化修改文件**

```powershell
dart format lib/src/battle/battle_controller.dart test/battle_controller_test.dart
```

- [ ] **步骤 4：运行绿灯测试**

运行：

```powershell
flutter test test/battle_controller_test.dart
```

预期：新测试和既有 `api_get_useitem`、`api_get_eventitem` 测试全部 PASS。

- [ ] **步骤 5：提交实现**

```powershell
git add -- lib/src/battle/battle_controller.dart
git commit -m "fix(航海日志): 补记海域结算道具"
```

### 任务 3：验证持久化、界面与回归范围

**文件：**
- 验证：`test/logbook_database_test.dart`
- 验证：`test/logbook_page_test.dart`
- 验证：`test/logbook_event_recorder_test.dart`
- 验证：`test/live_battle_card_node_test.dart`

- [ ] **步骤 1：运行奖励持久化与界面测试**

```powershell
flutter test test/logbook_database_test.dart test/logbook_page_test.dart test/logbook_event_recorder_test.dart test/live_battle_card_node_test.dart
```

预期：全部 PASS；现有 `BattleRewardItem` 会继续写入 `reward_items_json`，航海日志显示「名称 ×数量」。

- [ ] **步骤 2：运行完整相关回归**

```powershell
flutter test test/battle_controller_test.dart test/live_battle_card_node_test.dart test/battle_records_page_test.dart test/logbook_database_test.dart test/logbook_event_recorder_test.dart test/logbook_page_test.dart
```

预期：全部 PASS。

- [ ] **步骤 3：运行格式与静态检查**

```powershell
dart format --output=none --set-exit-if-changed lib/src/battle/battle_controller.dart test/battle_controller_test.dart
flutter analyze lib/src/battle/battle_controller.dart test/battle_controller_test.dart
git diff --check
```

预期：所有命令退出码为 `0`，没有格式差异、分析错误或空白错误。

- [ ] **步骤 4：审查最终差异和提交边界**

```powershell
git diff HEAD~2 -- lib/src/battle/battle_controller.dart test/battle_controller_test.dart
git status --short
```

确认只包含规格、回归测试和字段解析，不包含数据库迁移或无关重构。
