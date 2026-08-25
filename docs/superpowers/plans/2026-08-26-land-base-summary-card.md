# 首页陆基简报实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在首页编队简报下方添加可折叠、可排序的陆基简报，准确显示各海域航空队的立绘、制空、航程、行动状态、基地 HP、搭载数和疲劳状态。

**架构：** 扩展 `GameState` 保存陆航主数据与中队快照，由 `GameStateReducer` 处理全量和局部 API 更新。制空计算与资源 URI 构建分别放在纯 Dart 单元中，首页组件只负责分组、选择海域和渲染，并复用现有 HP 与疲劳视觉组件。

**技术栈：** Flutter、Dart、Material、现有 KCSAPI 捕获管线、Flutter Widget Test。

---

## 文件结构

- 修改：`lib/src/game_state/game_state.dart`——补充地图区域、装备陆航属性和航空队中队模型。
- 修改：`lib/src/game_state/game_state_reducer.dart`——解析主数据、`mapinfo` 和陆航局部接口。
- 修改：`lib/src/game_state/game_state_serializer.dart`——持久化新增陆航字段并兼容旧缓存。
- 修改：`lib/src/capture/game_capture_path_catalog.dart`——捕获陆航换装、补给、状态与改名接口。
- 创建：`lib/src/fleet/land_base_air_power.dart`——实现 POI 同口径的单航空队制空计算。
- 创建：`lib/src/fleet/slot_item_portrait.dart`——构建并显示装备 `item_up` 资源。
- 创建：`lib/src/fleet/land_base_status_visuals.dart`——将中队疲劳映射为黄脸、红脸和槽位光晕。
- 创建：`lib/src/fleet/land_base_summary_card.dart`——首页卡片、海域切换与航空队行。
- 修改：`lib/src/fleet/ship_status_visuals.dart`——提取可供基地复用的疲劳脸组件，不改变舰娘现有表现。
- 修改：`lib/src/settings/layout_settings_store.dart`——将 `land_base` 放在 `fleet` 后。
- 修改：`lib/main.dart`——注册并构建陆基简报。
- 修改：`lib/l10n/app_zh.arb`、`lib/l10n/app_zh_Hant.arb`、`lib/l10n/app_ja.arb`——新增陆航界面文案。
- 创建：`test/land_base_air_power_test.dart`——验证制空公式。
- 创建：`test/land_base_summary_card_test.dart`——验证布局、HP 和疲劳表现。
- 修改：`test/game_state_reducer_test.dart`——验证 API 更新链路。
- 修改：`test/game_state_serializer_test.dart`——验证缓存兼容。
- 修改：`test/prototype_shell_test.dart`——验证首页接线。

### 任务 1：扩展陆航与装备数据模型

**文件：**

- 修改：`lib/src/game_state/game_state.dart`
- 修改：`lib/src/game_state/game_state_serializer.dart`
- 修改：`test/game_state_serializer_test.dart`

- [ ] **步骤 1：编写失败的序列化测试**

在 `test/game_state_serializer_test.dart` 增加包含航程和 4 个中队的往返测试：

```dart
test('land-base cache keeps distance and squadron state', () {
  const source = GameState(
    landBases: <LandBaseState>[
      LandBaseState(
        areaId: 62,
        baseId: 1,
        name: '第一基地航空队',
        actionKind: 1,
        distanceBase: 7,
        distanceBonus: 1,
        squadrons: <LandBaseSquadronState>[
          LandBaseSquadronState(
            squadronId: 1,
            state: 1,
            slotItemId: 101,
            currentCount: 12,
            maxCount: 18,
            condition: 3,
          ),
        ],
      ),
    ],
    masterMapAreas: <int, String>{62: '反击！第三十一战队的战斗'},
  );

  final restored = GameStateSerializer.deserialize(
    GameStateSerializer.serialize(source),
  );
  expect(restored.landBases.single.effectiveDistance, 8);
  expect(restored.landBases.single.squadrons.single.condition, 3);
  expect(restored.masterMapAreas[62], '反击！第三十一战队的战斗');
});
```

- [ ] **步骤 2：运行测试并确认因类型和字段缺失而失败**

运行：`flutter test test/game_state_serializer_test.dart`

预期：FAIL，提示 `LandBaseSquadronState`、`distanceBase` 或 `masterMapAreas` 未定义。

- [ ] **步骤 3：实现不可变模型与向后兼容序列化**

在 `game_state.dart` 增加：

```dart
class LandBaseSquadronState {
  const LandBaseSquadronState({
    required this.squadronId,
    this.state = 0,
    this.slotItemId = 0,
    this.currentCount = 0,
    this.maxCount = 0,
    this.condition = 1,
  });

  final int squadronId;
  final int state;
  final int slotItemId;
  final int currentCount;
  final int maxCount;
  final int condition;
}
```

为 `LandBaseState` 增加 `distanceBase`、`distanceBonus`、`squadrons` 和 `effectiveDistance`。为 `GameState` 增加 `masterMapAreas`。为 `MasterSlotItem` 增加 `interception`、`antiBomber`、`distance` 和 `resourceVersion`，默认值保持旧调用兼容。

序列化时写入新增字段；反序列化缺失字段时使用默认值。继续只丢弃临时 `maxHp/currentHp/lastRaidDamage`。

- [ ] **步骤 4：运行模型测试**

运行：`flutter test test/game_state_serializer_test.dart`

预期：PASS。

- [ ] **步骤 5：提交模型变更**

```bash
git add lib/src/game_state/game_state.dart lib/src/game_state/game_state_serializer.dart test/game_state_serializer_test.dart
git commit -m "feat(陆基简报): 扩展基地航空队状态模型"
```

### 任务 2：补齐陆航 API 捕获与刷新

**文件：**

- 修改：`lib/src/capture/game_capture_path_catalog.dart`
- 修改：`lib/src/game_state/game_state_reducer.dart`
- 修改：`test/game_state_reducer_test.dart`

- [ ] **步骤 1：编写 `mapinfo` 全量解析失败测试**

将现有 `mapinfo captures land bases` 用例扩展为：

```dart
'api_distance': <String, Object?>{'api_base': 7, 'api_bonus': 1},
'api_plane_info': <Object?>[
  <String, Object?>{
    'api_squadron_id': 1,
    'api_state': 1,
    'api_slotid': 101,
    'api_count': 12,
    'api_max_count': 18,
    'api_cond': 3,
  },
],
```

并断言：

```dart
expect(firstBase.effectiveDistance, 8);
expect(firstBase.squadrons.single.currentCount, 12);
expect(firstBase.squadrons.single.condition, 3);
```

- [ ] **步骤 2：编写局部更新失败测试**

新增测试依次发送：

```dart
api_req_air_corps/set_action
api_req_air_corps/set_plane
api_req_air_corps/supply
api_req_air_corps/change_name
api_req_air_corps/change_deployment_base
```

断言只更新目标海域和基地，未返回的中队保持原值；补给后 `currentCount == maxCount`；换装后的 `api_state == 2` 可保留。

- [ ] **步骤 3：运行测试验证失败**

运行：`flutter test test/game_state_reducer_test.dart`

预期：FAIL，`mapinfo` 未保存中队，局部接口未进入 reducer。

- [ ] **步骤 4：实现解析与局部合并**

在路径目录加入：

```dart
'/kcsapi/api_req_air_corps/set_plane',
'/kcsapi/api_req_air_corps/change_deployment_base',
'/kcsapi/api_req_air_corps/set_action',
'/kcsapi/api_req_air_corps/supply',
'/kcsapi/api_req_air_corps/change_name',
```

在 reducer 中使用 `(areaId, baseId)` 查找基地，使用 `squadronId` 合并 `api_plane_info`。解析 `api_mst_maparea` 和 `api_mst_slotitem` 的陆航字段。所有局部分支在响应缺少目标或字段时返回原状态，不清空其他基地。

- [ ] **步骤 5：运行 reducer 与捕获目录测试**

运行：`flutter test test/game_state_reducer_test.dart test/game_capture_path_catalog_test.dart`

预期：PASS；如果没有独立路径目录测试文件，则运行 `flutter test test/game_state_reducer_test.dart` 并由局部接口用例证明事件可处理。

- [ ] **步骤 6：提交刷新链路**

```bash
git add lib/src/capture/game_capture_path_catalog.dart lib/src/game_state/game_state_reducer.dart test/game_state_reducer_test.dart
git commit -m "feat(陆基简报): 捕获并刷新航空队数据"
```

### 任务 3：实现 POI 同口径制空计算

**文件：**

- 创建：`lib/src/fleet/land_base_air_power.dart`
- 创建：`test/land_base_air_power_test.dart`

- [ ] **步骤 1：编写出击、防空和侦察补正测试**

测试公开入口：

```dart
final result = LandBaseAirPower.calculate(
  state: state,
  base: base,
);
expect(result.minimum, 114);
expect(result.maximum, greaterThanOrEqualTo(result.minimum));
expect(result.displayValue, result.minimum == result.maximum ? '114' : '114+');
```

分别覆盖局地战斗机出击 `1.5 × interception`、防空 `interception + 2 × antiBomber`、陆侦最高倍率、不足搭载数、配置转换中和未知装备。

- [ ] **步骤 2：运行公式测试验证失败**

运行：`flutter test test/land_base_air_power_test.dart`

预期：FAIL，提示 `LandBaseAirPower` 未定义。

- [ ] **步骤 3：实现纯 Dart 计算器**

定义：

```dart
class LandBaseAirPowerResult {
  const LandBaseAirPowerResult({required this.minimum, required this.maximum});
  final int minimum;
  final int maximum;
  String get displayValue => minimum == maximum ? '$minimum' : '$minimum+';
}
```

复制 `FleetMetrics` 已验证的熟练度区间表，但按 POI `getTyku` 增加陆航类型、迎击、对爆和侦察倍率。每槽先 `floor`，求和后乘最高侦察倍率再 `floor`。`api_state != 1` 或搭载数小于 1 的槽位不计入。

- [ ] **步骤 4：运行公式测试**

运行：`flutter test test/land_base_air_power_test.dart`

预期：PASS。

- [ ] **步骤 5：提交公式**

```bash
git add lib/src/fleet/land_base_air_power.dart test/land_base_air_power_test.dart
git commit -m "feat(陆基简报): 添加陆航制空计算"
```

### 任务 4：实现装备立绘 URI 与疲劳视觉

**文件：**

- 创建：`lib/src/fleet/slot_item_portrait.dart`
- 创建：`lib/src/fleet/land_base_status_visuals.dart`
- 修改：`lib/src/fleet/ship_status_visuals.dart`
- 创建：`test/slot_item_portrait_test.dart`
- 创建：`test/land_base_status_visuals_test.dart`

- [ ] **步骤 1：编写资源 URI 和疲劳映射失败测试**

```dart
expect(
  SlotItemPortraitUriBuilder.build(
    item: const MasterSlotItem(id: 168, name: '九六式陆攻', resourceVersion: '2'),
    serverOrigin: 'https://example.test',
  ).toString(),
  startsWith('https://example.test/kcs2/resources/slot/item_up/0168_'),
);

expect(landBaseFatigueLevel(const <int>[1, 2]), LandBaseFatigueLevel.yellow);
expect(landBaseFatigueLevel(const <int>[1, 3]), LandBaseFatigueLevel.red);
```

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/slot_item_portrait_test.dart test/land_base_status_visuals_test.dart`

预期：FAIL，URI 构建器和疲劳映射未定义。

- [ ] **步骤 3：实现资源和视觉单元**

从 `ShipPortraitUriBuilder` 提取共享资源密钥算法，装备使用种子 `slot_item_up`。`SlotItemPortrait` 用 `Image.network`，错误时显示 `EquipmentTypeIconImage`，不显示破图。

将 `ShipMoraleMark` 内的疲劳脸提取为可复用的 `FatigueFace`：

```dart
enum FatigueFaceLevel { yellow, red }

class FatigueFace extends StatelessWidget {
  const FatigueFace({super.key, required this.level});
  final FatigueFaceLevel level;
}
```

舰娘保持原位置和阈值；陆航只在最严重中队为黄或红时，将脸放到立绘右上角。

- [ ] **步骤 4：运行资源与视觉测试**

运行：`flutter test test/slot_item_portrait_test.dart test/land_base_status_visuals_test.dart test/ship_morale_mark_test.dart`

预期：PASS，现有舰娘疲劳测试无回归。

- [ ] **步骤 5：提交视觉基础组件**

```bash
git add lib/src/fleet/slot_item_portrait.dart lib/src/fleet/land_base_status_visuals.dart lib/src/fleet/ship_status_visuals.dart test/slot_item_portrait_test.dart test/land_base_status_visuals_test.dart test/ship_morale_mark_test.dart
git commit -m "feat(陆基简报): 复用立绘状态视觉"
```

### 任务 5：实现航空队行和状态模拟覆盖

**文件：**

- 创建：`lib/src/fleet/land_base_summary_card.dart`
- 创建：`test/land_base_summary_card_test.dart`

- [ ] **步骤 1：编写航空队行失败测试**

构造正常、轻损、中损、重损、黄疲劳、红疲劳、缺机、配置转换中和无数据状态，断言：

```dart
expect(find.byKey(const Key('land-base-portrait-hp-frame-62-1')), findsOneWidget);
expect(find.byKey(const Key('land-base-row-hp-frame-62-1')), findsNothing);
expect(find.byKey(const Key('land-base-hp-meter-62-1')), findsOneWidget);
expect(find.byKey(const Key('land-base-fatigue-face-62-1')), findsNothing);
```

黄疲劳与红疲劳用例断言疲劳脸存在并位于立绘 `Stack` 内；纯损伤用例断言疲劳脸不存在。

- [ ] **步骤 2：运行组件测试验证失败**

运行：`flutter test test/land_base_summary_card_test.dart`

预期：FAIL，`LandBaseSummaryCard` 未定义。

- [ ] **步骤 3：实现航空队行**

每行使用一个普通固定边框容器。左侧立绘 `Stack` 内依次放置：

1. `SlotItemPortrait`
2. `ShipHpFrame`
3. 航空队名称和制空/航程文字
4. 可选 `FatigueFace`

中间显示行动状态胶囊和 `CompactStatusMeter` 风格 HP 条；右侧固定渲染 4 个中队槽位。HP 缺失时按 `200/200` 渲染，损伤只改变 HP 视觉，不生成疲劳脸。

- [ ] **步骤 4：运行航空队行测试**

运行：`flutter test test/land_base_summary_card_test.dart`

预期：PASS。

- [ ] **步骤 5：提交航空队行**

```bash
git add lib/src/fleet/land_base_summary_card.dart test/land_base_summary_card_test.dart
git commit -m "feat(陆基简报): 添加航空队状态胶囊"
```

### 任务 6：实现海域分组与首页卡片

**文件：**

- 修改：`lib/src/fleet/land_base_summary_card.dart`
- 修改：`test/land_base_summary_card_test.dart`

- [ ] **步骤 1：编写卡片交互失败测试**

构造海域 `6` 和 `62`，断言默认选择第一个有数据海域；点击 `land-base-area-selector-62` 后只显示 `62` 的航空队；折叠后不显示行；空数据时显示 `无数据`。

- [ ] **步骤 2：运行交互测试验证失败**

运行：`flutter test test/land_base_summary_card_test.dart`

预期：FAIL，海域选择器或折叠行为尚未实现。

- [ ] **步骤 3：实现 `DashboardCard` 包装与海域切换**

`LandBaseSummaryCard` 监听 `GameStateController`，将 `landBases` 按 `areaId` 分组并排序。标题使用飞机图标；右侧切换器显示区域 ID；区域标题读取 `masterMapAreas`。卡片不创建详情弹层，不显示详情提示。

- [ ] **步骤 4：运行完整卡片测试**

运行：`flutter test test/land_base_summary_card_test.dart`

预期：PASS。

- [ ] **步骤 5：提交卡片**

```bash
git add lib/src/fleet/land_base_summary_card.dart test/land_base_summary_card_test.dart
git commit -m "feat(陆基简报): 添加海域切换卡片"
```

### 任务 7：接入首页、设置和本地化

**文件：**

- 修改：`lib/src/settings/layout_settings_store.dart`
- 修改：`lib/main.dart`
- 修改：`lib/l10n/app_zh.arb`
- 修改：`lib/l10n/app_zh_Hant.arb`
- 修改：`lib/l10n/app_ja.arb`
- 修改：生成的 `lib/l10n/app_localizations*.dart`
- 修改：`test/prototype_shell_test.dart`
- 修改：`test/layout_settings_behavior_test.dart`

- [ ] **步骤 1：编写首页顺序和接线失败测试**

断言：

```dart
expect(
  LayoutSettingsStore.defaultDashboardCardOrder,
  containsAllInOrder(<String>['fleet', 'land_base', 'expedition']),
);
expect(find.byType(LandBaseSummaryCard), findsOneWidget);
```

并覆盖旧保存顺序缺少 `land_base` 时，规范化逻辑将新卡片插入 `fleet` 后。

- [ ] **步骤 2：运行首页测试验证失败**

运行：`flutter test test/prototype_shell_test.dart test/layout_settings_behavior_test.dart`

预期：FAIL，默认顺序和卡片构建分支尚未注册。

- [ ] **步骤 3：接入首页和本地化**

在默认顺序中加入 `land_base`，在 `main.dart` 导入并构建 `LandBaseSummaryCard`，传递现有伤害脉冲设置。新增简体中文、繁体中文和日语的标题、行动状态、制空、航程、疲劳、缺机和配置转换文案。

运行：`flutter gen-l10n`

- [ ] **步骤 4：运行首页与本地化测试**

运行：`flutter test test/prototype_shell_test.dart test/layout_settings_behavior_test.dart test/locale_font_mapping_test.dart`

预期：PASS。

- [ ] **步骤 5：提交首页接线**

```bash
git add lib/main.dart lib/src/settings/layout_settings_store.dart lib/l10n test/prototype_shell_test.dart test/layout_settings_behavior_test.dart
git commit -m "feat(首页): 接入陆基简报卡片"
```

### 任务 8：格式化、回归与实机前检查

**文件：**

- 检查：本计划涉及的全部 Dart、ARB 和测试文件

- [ ] **步骤 1：格式化**

运行：

```bash
dart format lib/src/game_state lib/src/capture lib/src/fleet lib/src/settings test
```

预期：命令成功，不产生语法错误。

- [ ] **步骤 2：运行聚焦测试**

运行：

```bash
flutter test test/game_state_serializer_test.dart test/game_state_reducer_test.dart test/land_base_air_power_test.dart test/slot_item_portrait_test.dart test/land_base_status_visuals_test.dart test/land_base_summary_card_test.dart test/prototype_shell_test.dart test/layout_settings_behavior_test.dart
```

预期：全部 PASS。

- [ ] **步骤 3：运行静态检查**

运行：`flutter analyze`

预期：无新增 error 或 warning；既有提示单独记录，不混入本功能提交。

- [ ] **步骤 4：运行全量测试**

运行：`flutter test`

预期：全部 PASS。若存在与本功能无关的既有失败，保存完整命令和失败用例名称，并确认聚焦测试仍全部通过。

- [ ] **步骤 5：检查工作树与提交历史**

运行：

```bash
git status --short
git log --oneline -10
```

预期：没有未提交的本功能文件；用户其他改动保持原状。
