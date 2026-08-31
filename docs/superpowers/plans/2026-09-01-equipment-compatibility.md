# 装备可装备舰娘查询实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在仓库装备表中点击装备后打开右侧详情抽屉，准确展示该装备可用于普通槽或增设栏的全部舰娘形态与当前持有舰娘。

**架构：** 扩展 `GameState`，完整保存普通槽覆盖规则和 3 类增设栏官方主数据。新增纯 Dart 判定服务与投影层，UI 抽屉只消费结构化结果；仓库页面负责选中状态和抽屉开关。

**技术栈：** Flutter、Dart、`flutter_test`、现有 `GameStateReducer`/`GameStateSerializer`/`OwnedInventoryPage` 架构。

---

## 文件结构

- 修改 `lib/src/game_state/game_state.dart`：定义普通槽覆盖规则、增设栏特殊规则，并把规则集合加入 `GameState`。
- 修改 `lib/src/game_state/game_state_reducer.dart`：从 `api_start2/getData` 解析完整装备规则。
- 修改 `lib/src/game_state/game_state_serializer.dart`：缓存和恢复新增主数据，兼容旧缓存。
- 创建 `lib/src/inventory/equipment_compatibility.dart`：实现与 UI 无关的普通槽、增设栏判定。
- 创建 `lib/src/inventory/equipment_compatibility_projection.dart`：生成全部/持有舰娘列表、分组、搜索和筛选结果。
- 创建 `lib/src/inventory/equipment_compatibility_drawer.dart`：实现右侧详情抽屉。
- 修改 `lib/src/inventory/owned_inventory_page.dart`：管理装备选择，并把抽屉接入装备表。
- 修改 `lib/l10n/app_zh.arb`、`lib/l10n/app_zh_Hant.arb`、`lib/l10n/app_ja.arb`：增加界面文案。
- 修改生成的 `lib/l10n/app_localizations*.dart`：通过 `flutter gen-l10n` 更新。
- 修改 `test/game_state_reducer_test.dart`：覆盖官方规则解析。
- 修改 `test/game_state_serializer_test.dart`：覆盖规则缓存与旧缓存兼容。
- 创建 `test/equipment_compatibility_test.dart`：覆盖纯判定服务。
- 创建 `test/equipment_compatibility_projection_test.dart`：覆盖全部/持有投影。
- 修改 `test/owned_inventory_page_test.dart`：覆盖抽屉交互、筛选、切换与窄屏布局。

### 任务 1：完整保存官方装备规则

**文件：**
- 修改：`lib/src/game_state/game_state.dart`
- 修改：`lib/src/game_state/game_state_reducer.dart`
- 测试：`test/game_state_reducer_test.dart`

- [ ] **步骤 1：编写失败的解析测试**

在现有 `start2` 测试 fixture 中加入普通槽具体装备白名单、通用增设栏类别、特殊增设栏规则和排除规则，并断言：

```dart
expect(state.masterShips[100]?.limitedEquipmentIdsByType[27], <int>{268});
expect(state.expansionSlotEquipmentTypeIds, contains(27));
expect(state.expansionSlotLimitsByShipId[100], contains(27));
expect(state.expansionSlotSpecialRules[124]?.minimumImprovement, 7);
expect(state.expansionSlotSpecialRules[124]?.classTypeIds, contains(47));
```

- [ ] **步骤 2：运行测试验证失败**

运行：

```powershell
flutter test test/game_state_reducer_test.dart
```

预期：编译失败，提示新增字段或类型不存在。

- [ ] **步骤 3：实现最小数据模型**

在 `game_state.dart` 增加不可变规则：

```dart
class ExpansionSlotSpecialRule {
  const ExpansionSlotSpecialRule({
    required this.equipmentMasterId,
    this.shipMasterIds = const <int>{},
    this.classTypeIds = const <int>{},
    this.shipTypeIds = const <int>{},
    this.minimumImprovement = 0,
  });

  final int equipmentMasterId;
  final Set<int> shipMasterIds;
  final Set<int> classTypeIds;
  final Set<int> shipTypeIds;
  final int minimumImprovement;
}
```

为 `MasterShip` 增加：

```dart
final Map<int, Set<int>> limitedEquipmentIdsByType;
```

为 `GameState` 增加：

```dart
final Set<int> expansionSlotEquipmentTypeIds;
final Map<int, ExpansionSlotSpecialRule> expansionSlotSpecialRules;
final Map<int, Set<int>> expansionSlotLimitsByShipId;
```

- [ ] **步骤 4：解析 `start2` 规则**

修改 `_start2`：保留 `api_mst_equip_ship.api_equip_type` 中数组值；解析 `api_mst_equip_exslot`、`api_mst_equip_exslot_ship` 与 `api_mst_equip_limit_exslot`。所有集合使用不可变副本，忽略非正整数键值。

- [ ] **步骤 5：运行解析测试验证通过**

运行：

```powershell
flutter test test/game_state_reducer_test.dart
```

预期：PASS。

- [ ] **步骤 6：提交**

```powershell
git add lib/src/game_state/game_state.dart lib/src/game_state/game_state_reducer.dart test/game_state_reducer_test.dart
git commit -m "feat(装备): 解析完整装备适配规则"
```

### 任务 2：缓存装备规则并兼容旧数据

**文件：**
- 修改：`lib/src/game_state/game_state_serializer.dart`
- 测试：`test/game_state_serializer_test.dart`

- [ ] **步骤 1：编写失败的序列化测试**

```dart
test('equipment compatibility rules survive cache serialization', () {
  const state = GameState(
    expansionSlotEquipmentTypeIds: <int>{21, 27},
    expansionSlotLimitsByShipId: <int, Set<int>>{100: <int>{27}},
    expansionSlotSpecialRules: <int, ExpansionSlotSpecialRule>{
      124: ExpansionSlotSpecialRule(
        equipmentMasterId: 124,
        classTypeIds: <int>{47},
        minimumImprovement: 7,
      ),
    },
  );
  final restored = GameStateSerializer.deserialize(
    GameStateSerializer.serialize(state),
  );
  expect(restored.expansionSlotEquipmentTypeIds, <int>{21, 27});
  expect(restored.expansionSlotLimitsByShipId[100], <int>{27});
  expect(restored.expansionSlotSpecialRules[124]?.minimumImprovement, 7);
});
```

同时增加旧 JSON 缺少新增字段时返回空集合的断言。

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/game_state_serializer_test.dart`

预期：新增规则在恢复后丢失。

- [ ] **步骤 3：实现序列化与反序列化**

规则对象转换为仅包含字符串键、整数和数组的 JSON。读取时使用现有 `_int`/`_string` 辅助函数，缺失字段回退为空集合，错误条目逐项忽略。

同时补齐离线判定必需的现有主数据缓存：

- `masterShipTypes` 的名称与 `equipTypeIds`；
- `masterShips` 的 `classTypeId`、`equipTypeIds` 与 `limitedEquipmentIdsByType`；
- `masterSlotItems` 的名称、排序号和完整 `type` 数组。

序列化测试必须先证明这些字段当前会丢失，再实现恢复逻辑。否则新增规则在离线状态下没有足够输入完成判定。

- [ ] **步骤 4：运行测试验证通过并提交**

运行：`flutter test test/game_state_serializer_test.dart`

预期：PASS。

```powershell
git add lib/src/game_state/game_state_serializer.dart test/game_state_serializer_test.dart
git commit -m "feat(装备): 缓存装备适配规则"
```

### 任务 3：实现纯 Dart 装备适配判定

**文件：**
- 创建：`lib/src/inventory/equipment_compatibility.dart`
- 创建：`test/equipment_compatibility_test.dart`

- [ ] **步骤 1：编写失败的判定矩阵测试**

定义以下公开结果：

```dart
class EquipmentCompatibility {
  const EquipmentCompatibility({
    required this.canEquipInRegularSlot,
    required this.canEquipInExpansionSlot,
    this.expansionSlotMinimumImprovement = 0,
  });
  final bool canEquipInRegularSlot;
  final bool canEquipInExpansionSlot;
  final int expansionSlotMinimumImprovement;
}
```

测试至少覆盖：普通槽类型命中、具体装备白名单命中/未命中、通用增设栏、增设栏排除、舰娘 ID/舰级/舰种/舰种 `99` 特殊匹配、最低改修等级、未知输入。

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/equipment_compatibility_test.dart`

预期：编译失败，提示服务不存在。

- [ ] **步骤 3：实现最小判定服务**

```dart
class EquipmentCompatibilityService {
  const EquipmentCompatibilityService(this.state);
  final GameState state;

  EquipmentCompatibility? resolve({
    required int shipMasterId,
    required int equipmentMasterId,
  }) {
    final ship = state.masterShips[shipMasterId];
    final equipment = state.masterSlotItems[equipmentMasterId];
    if (ship == null || equipment == null || equipment.type.length < 3) {
      return null;
    }
    final typeId = _actualTypeOverrides[equipmentMasterId] ?? equipment.type[2];
    final categoryAllowed = ship.equipTypeIds.contains(typeId);
    final whitelist = ship.limitedEquipmentIdsByType[typeId];
    final regular = categoryAllowed &&
        (whitelist == null || whitelist.contains(equipmentMasterId));
    final limited =
        state.expansionSlotLimitsByShipId[shipMasterId]?.contains(typeId) ??
        false;
    final generalExpansion = categoryAllowed &&
        state.expansionSlotEquipmentTypeIds.contains(typeId) &&
        !limited;
    final special = state.expansionSlotSpecialRules[equipmentMasterId];
    final specialExpansion = special != null &&
        categoryAllowed &&
        (special.shipTypeIds.contains(99) ||
            special.shipMasterIds.contains(shipMasterId) ||
            special.classTypeIds.contains(ship.classTypeId) ||
            special.shipTypeIds.contains(ship.shipTypeId));
    return EquipmentCompatibility(
      canEquipInRegularSlot: regular,
      canEquipInExpansionSlot: generalExpansion || specialExpansion,
      expansionSlotMinimumImprovement:
          specialExpansion ? special.minimumImprovement : 0,
    );
  }

  static const Map<int, int> _actualTypeOverrides = <int, int>{
    128: 38,
    142: 93,
    151: 94,
    281: 38,
    460: 93,
    465: 38,
    467: 95,
    561: 91,
  };
}
```

普通槽先应用类别能力，再应用具体装备白名单。增设栏先计算通用类别与排除规则，再合并特殊规则，并返回最低改修等级。未知舰娘或装备返回 `null`，与「明确不可装备」区分。

- [ ] **步骤 4：运行测试验证通过并提交**

运行：`flutter test test/equipment_compatibility_test.dart`

预期：PASS。

```powershell
git add lib/src/inventory/equipment_compatibility.dart test/equipment_compatibility_test.dart
git commit -m "feat(装备): 新增可装备舰娘判定服务"
```

### 任务 4：生成全部与持有舰娘投影

**文件：**
- 创建：`lib/src/inventory/equipment_compatibility_projection.dart`
- 创建：`test/equipment_compatibility_projection_test.dart`

- [ ] **步骤 1：编写失败的投影测试**

测试数据包含同一舰娘多个改造形态、重复持有、舰队内舰娘、未持有形态和 ID 大于 1500 的深海舰船。断言：

```dart
expect(allRows.map((row) => row.shipMaster.id), containsAll(<int>[1, 2, 3]));
expect(allRows.map((row) => row.shipMaster.id), isNot(contains(1501)));
expect(ownedRows.where((row) => row.shipMaster.id == 3).single.ownedShips, hasLength(2));
expect(ownedRows.first.fleetNumbers, contains(1));
```

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/equipment_compatibility_projection_test.dart`

预期：编译失败，提示投影类型不存在。

- [ ] **步骤 3：实现投影、搜索和筛选**

创建 `EquipmentCompatibilityShipRow`，包含主数据、舰种名、持有实例、舰队编号和判定结果。提供：

```dart
List<EquipmentCompatibilityShipRow> rows({
  required int equipmentMasterId,
  required bool ownedOnly,
  String query = '',
  EquipmentCompatibilitySlotFilter filter = EquipmentCompatibilitySlotFilter.all,
})
```

结果按舰种顺序、舰娘 `sortNo`、主数据 ID 排序。搜索匹配具体形态名称；普通槽与增设栏筛选分别使用判定布尔值。

- [ ] **步骤 4：运行测试验证通过并提交**

运行：`flutter test test/equipment_compatibility_projection_test.dart`

预期：PASS。

```powershell
git add lib/src/inventory/equipment_compatibility_projection.dart test/equipment_compatibility_projection_test.dart
git commit -m "feat(装备): 生成可装备舰娘查询结果"
```

### 任务 5：实现右侧详情抽屉

**文件：**
- 创建：`lib/src/inventory/equipment_compatibility_drawer.dart`
- 修改：`lib/src/inventory/owned_inventory_page.dart`
- 修改：`test/owned_inventory_page_test.dart`

- [ ] **步骤 1：编写失败的打开与切换测试**

测试点击装备名称行后出现：

```dart
expect(find.byKey(const Key('equipment-compatibility-drawer')), findsOneWidget);
expect(find.text('持有舰娘'), findsOneWidget);
expect(find.text('全部舰娘'), findsOneWidget);
expect(find.text('普通槽＋增设栏'), findsWidgets);
```

继续点击另一装备，断言抽屉仍只有一个且标题替换；点击关闭按钮后抽屉消失、选中状态清除。

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/owned_inventory_page_test.dart`

预期：找不到抽屉 Key。

- [ ] **步骤 3：让装备表回传选中装备**

为 `_EquipmentInventoryTable` 增加：

```dart
final int? selectedEquipmentMasterId;
final ValueChanged<EquipmentInventoryGroup> onEquipmentSelected;
```

装备行使用 `InkWell` 提供点击、悬停、按钮语义和选中样式。

- [ ] **步骤 4：实现自适应抽屉容器**

在装备表外使用 `Stack`，宽屏抽屉宽度为 `438`，窄屏宽度为可用宽度减去安全边距。使用 `AnimatedPositioned` 或 `AnimatedSlide` 从右侧进入。抽屉内部拥有独立滚动区域，关闭按钮和 `Escape` 调用同一关闭方法。

- [ ] **步骤 5：实现抽屉内容与本地状态**

抽屉管理：

```dart
bool ownedOnly = true;
String query = '';
EquipmentCompatibilitySlotFilter slotFilter = EquipmentCompatibilitySlotFilter.all;
```

顶部显示装备摘要；列表按舰种插入分组标题。持有模式显示最高/全部实例等级与舰队状态，全部模式保留未持有具体形态。

- [ ] **步骤 6：运行交互测试验证通过并提交**

运行：`flutter test test/owned_inventory_page_test.dart`

预期：PASS。

```powershell
git add lib/src/inventory/equipment_compatibility_drawer.dart lib/src/inventory/owned_inventory_page.dart test/owned_inventory_page_test.dart
git commit -m "feat(仓库): 添加可装备舰娘详情抽屉"
```

### 任务 6：补齐本地化、异常状态与响应式测试

**文件：**
- 修改：`lib/l10n/app_zh.arb`
- 修改：`lib/l10n/app_zh_Hant.arb`
- 修改：`lib/l10n/app_ja.arb`
- 修改：`lib/l10n/app_localizations.dart`
- 修改：`lib/l10n/app_localizations_zh.dart`
- 修改：`lib/l10n/app_localizations_ja.dart`
- 修改：`lib/src/inventory/equipment_compatibility_drawer.dart`
- 修改：`test/owned_inventory_page_test.dart`
- 修改：`test/localization_resource_audit_test.dart`

- [ ] **步骤 1：编写失败的异常与窄屏测试**

覆盖主数据缺失、未知装备、持有结果为空、全部结果为空和 800 px 宽度布局。窄屏测试调用：

```dart
tester.view.physicalSize = const Size(800, 900);
tester.view.devicePixelRatio = 1;
await tester.pumpWidget(
  MaterialApp(
    locale: const Locale('zh'),
    home: Scaffold(body: OwnedInventoryPage(controller: controller)),
  ),
);
expect(tester.takeException(), isNull);
```

- [ ] **步骤 2：增加 3 种语言的文案键并生成代码**

增加统一键名，包括 `compatibleShips`、`ownedCompatibleShips`、`allCompatibleShips`、`regularSlot`、`expansionSlot`、`minimumImprovementRequired`、`equipmentRulesWaiting`、`noCompatibleOwnedShips` 和 `noCompatibleShipForms`。

运行：

```powershell
flutter gen-l10n
```

- [ ] **步骤 3：实现异常、空状态和窄屏布局**

未知规则显示等待/未知状态，不显示「不可装备」。窄屏抽屉宽度使用 `min(438, availableWidth - 16)`，并确保搜索框、标签和列表无横向溢出。

- [ ] **步骤 4：运行相关测试并提交**

运行：

```powershell
flutter test test/owned_inventory_page_test.dart test/localization_resource_audit_test.dart
```

预期：PASS。

```powershell
git add lib/l10n lib/src/inventory/equipment_compatibility_drawer.dart test/owned_inventory_page_test.dart test/localization_resource_audit_test.dart
git commit -m "feat(装备): 完善查询抽屉本地化与异常状态"
```

### 任务 7：全量验证与 Debug APK

**文件：**
- 验证：所有本次修改文件
- 产物：`build/app/outputs/flutter-apk/app-debug.apk`

- [ ] **步骤 1：格式化并运行静态分析**

```powershell
dart format lib/src/game_state/game_state.dart lib/src/game_state/game_state_reducer.dart lib/src/game_state/game_state_serializer.dart lib/src/inventory/equipment_compatibility.dart lib/src/inventory/equipment_compatibility_projection.dart lib/src/inventory/equipment_compatibility_drawer.dart lib/src/inventory/owned_inventory_page.dart test/game_state_reducer_test.dart test/game_state_serializer_test.dart test/equipment_compatibility_test.dart test/equipment_compatibility_projection_test.dart test/owned_inventory_page_test.dart
flutter analyze
```

预期：格式化完成，静态分析无错误。

- [ ] **步骤 2：运行聚焦测试与全量测试**

```powershell
flutter test test/game_state_reducer_test.dart test/game_state_serializer_test.dart test/equipment_compatibility_test.dart test/equipment_compatibility_projection_test.dart test/owned_inventory_page_test.dart test/localization_resource_audit_test.dart
flutter test
```

预期：全部 PASS。

- [ ] **步骤 3：构建 Debug APK**

```powershell
flutter build apk --debug
```

预期：生成 `build/app/outputs/flutter-apk/app-debug.apk`。

- [ ] **步骤 4：检查产物和工作区**

```powershell
Get-Item build/app/outputs/flutter-apk/app-debug.apk | Select-Object FullName,Length,LastWriteTime
git status --short
```

预期：APK 存在且大小大于 0；工作区只包含已知生成物或保持干净。

- [ ] **步骤 5：提交最终验证修正**

仅当格式化、生成代码或验证修正产生跟踪文件变化时执行：

```powershell
git add lib test
git commit -m "test(装备): 完成可装备舰娘功能验证"
```
