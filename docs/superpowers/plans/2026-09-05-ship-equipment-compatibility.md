# 舰娘可装备装备抽屉实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 让持有舰娘表格与未持有舰娘卡片打开右侧抽屉，查看该舰娘可装备的持有或全部装备。

**架构：** 保持 `EquipmentCompatibilityService` 为唯一规则来源，新建反向投影负责遍历、过滤、分组和持有数量。新建镜像抽屉复用现有紧凑视觉与二级窗口模式，`OwnedInventoryPage` 只管理舰娘选择和生命周期。

**技术栈：** Dart 3.12、Flutter Material、`flutter_test`、现有 `GameState` 主数据与库存投影。

---

## 文件结构

- 创建 `lib/src/inventory/ship_equipment_compatibility_projection.dart`：反向查询、过滤、分组与持有数量。
- 创建 `lib/src/inventory/ship_equipment_compatibility_drawer.dart`：舰娘标题、范围页签、筛选和装备分组卡片。
- 修改 `lib/src/inventory/owned_inventory_page.dart`：接通两种舰娘入口并管理抽屉状态。
- 创建 `test/ship_equipment_compatibility_projection_test.dart`：单元测试反向投影。
- 创建 `test/ship_equipment_compatibility_drawer_test.dart`：独立验证抽屉结构与交互。
- 修改 `test/owned_inventory_page_test.dart`：验证入口和页面级生命周期。

### 任务 1：反向适配投影

**文件：**
- 创建：`test/ship_equipment_compatibility_projection_test.dart`
- 创建：`lib/src/inventory/ship_equipment_compatibility_projection.dart`

- [ ] **步骤 1：编写范围与持有数量的失败测试**

```dart
final projection = ShipEquipmentCompatibilityProjection(state);
final owned = projection.groups(shipMasterId: 101, ownedOnly: true);
final all = projection.groups(shipMasterId: 101);
expect(owned.single.rows.single.ownedCount, 3);
expect(all.expand((group) => group.rows).map((row) => row.master.id),
    containsAll(<int>[201, 202]));
```

- [ ] **步骤 2：运行测试验证正确红灯**

运行：`flutter test test/ship_equipment_compatibility_projection_test.dart`

预期：FAIL，报告 `ShipEquipmentCompatibilityProjection` 未定义。

- [ ] **步骤 3：实现最小投影 API**

```dart
class ShipEquipmentCompatibilityRow {
  const ShipEquipmentCompatibilityRow({
    required this.master,
    required this.ownedCount,
    required this.compatibility,
  });
  final MasterSlotItem master;
  final int ownedCount;
  final EquipmentCompatibility compatibility;
}

class ShipEquipmentCompatibilityGroup {
  const ShipEquipmentCompatibilityGroup({
    required this.typeId,
    required this.typeName,
    required this.rows,
  });
  final int typeId;
  final String typeName;
  final List<ShipEquipmentCompatibilityRow> rows;
}
```

`groups` 先按装备主数据 ID 汇总 `slotItems`，再遍历 `sortNo > 0` 的有效装备，调用 `EquipmentCompatibilityService.resolve`。

- [ ] **步骤 4：补充现有大类、搜索、槽位和分组排序测试**

```dart
final groups = projection.groups(
  shipMasterId: 101,
  category: EquipmentInventoryCategory.mainGun,
  query: '连装',
  filter: EquipmentCompatibilitySlotFilter.expansion,
);
expect(groups.single.typeName, '中口径主炮');
```

另断言组按 `typeId` 排序，组内按 `sortNo` 与 ID 排序，无效装备被排除。

- [ ] **步骤 5：运行投影测试至全部通过**

运行：`flutter test test/ship_equipment_compatibility_projection_test.dart`

- [ ] **步骤 6：提交任务 1**

`feat(装备): 添加舰娘可装备装备投影`

### 任务 2：镜像抽屉

**文件：**
- 创建：`test/ship_equipment_compatibility_drawer_test.dart`
- 创建：`lib/src/inventory/ship_equipment_compatibility_drawer.dart`
- 参考：`lib/src/inventory/equipment_compatibility_drawer.dart`

- [ ] **步骤 1：编写抽屉骨架与分组卡片的失败测试**

```dart
await tester.pumpWidget(MaterialApp(
  home: ShipEquipmentCompatibilityDrawer(
    state: state,
    ship: state.masterShips[101]!,
    ownedShip: state.ships[9001],
    onClose: () {},
  ),
));
expect(find.byKey(const Key('ship-equipment-compatibility-drawer')), findsOneWidget);
expect(find.text('中口径主炮'), findsOneWidget);
expect(find.text('持有 X3'), findsOneWidget);
```

- [ ] **步骤 2：运行测试验证正确红灯**

运行：`flutter test test/ship_equipment_compatibility_drawer_test.dart`

预期：FAIL，报告 `ShipEquipmentCompatibilityDrawer` 未定义。

- [ ] **步骤 3：实现单一整体滚动抽屉**

```dart
Focus(
  autofocus: true,
  onKeyEvent: _handleKeyEvent,
  child: Material(
    key: const Key('ship-equipment-compatibility-drawer'),
    child: SingleChildScrollView(
      key: const Key('ship-equipment-compatibility-scroll'),
      child: Column(children: [
        _ShipHeader(...),
        _CompactToolRow(...),
        _ScopeTabs(...),
        _SlotFilters(...),
        for (final group in groups) _EquipmentGroup(group: group),
      ]),
    ),
  ),
)
```

卡片右侧使用固定对齐列渲染 `持有 X${row.ownedCount}` 和槽位标签。

- [ ] **步骤 4：编写现有装备分类窗口的失败测试**

```dart
await tester.tap(find.byKey(const Key('ship-equipment-category-button')));
await tester.pumpAndSettle();
expect(find.byKey(const Key('ship-equipment-category-dialog')), findsOneWidget);
expect(find.text('主炮'), findsOneWidget);
expect(find.text('副炮／髒角炮'), findsOneWidget);
expect(find.text('重置'), findsNothing);
expect(find.text('完成'), findsNothing);
```

- [ ] **步骤 5：实现分类、搜索和槽位筛选**

分类标签复用库存页的 `EquipmentInventoryCategory` 映射。点击分类立即生效，窗口不放「重置 / 完成」。搜索和 `Esc` 行为对齐现有抽屉。

- [ ] **步骤 6：补充范围切换保留筛选、槽位筛选和规则未就绪测试**

- [ ] **步骤 7：运行抽屉测试至全部通过**

运行：`flutter test test/ship_equipment_compatibility_drawer_test.dart`

- [ ] **步骤 8：提交任务 2**

`feat(装备): 添加舰娘可装备装备抽屉`

### 任务 3：库存页双入口集成

**文件：**
- 修改：`test/owned_inventory_page_test.dart`
- 修改：`lib/src/inventory/owned_inventory_page.dart`

- [ ] **步骤 1：编写持有舰娘行打开抽屉的失败测试**

```dart
await tester.tap(find.byKey(const Key('owned-ship-name-row-9001')));
await tester.pumpAndSettle();
expect(find.byKey(const Key('ship-equipment-compatibility-drawer')), findsOneWidget);
expect(find.text('Lv.98'), findsWidgets);
```

- [ ] **步骤 2：运行定向测试验证正确红灯**

运行：`flutter test test/owned_inventory_page_test.dart --plain-name "持有舰娘打开可装备装备抽屉"`

预期：FAIL，找不到抽屉。

- [ ] **步骤 3：接通持有舰娘选择**

为 `_ShipInventoryTable` 增加 `selectedShipInstanceId` 和 `onShipTap`，将选中实例映射到舰娘主数据，在舰娘页的 `Stack` 中渲染新抽屉。

- [ ] **步骤 4：编写未持有舰娘卡片打开抽屉的失败测试**

```dart
await tester.tap(find.byKey(const Key('owned-inventory-tab-unowned')));
await tester.pump();
await tester.tap(find.byKey(const Key('unowned-ship-103')));
await tester.pumpAndSettle();
expect(find.byKey(const Key('ship-equipment-compatibility-drawer')), findsOneWidget);
```

- [ ] **步骤 5：接通未持有舰娘选择**

为 `UnownedInventoryView`、`_UnownedShipsView` 和 `_UnownedShipCard` 逐层传入舰娘主数据 ID 与回调，卡片增加 `Material`/`InkWell` 且保留排除复选框。

- [ ] **步骤 6：补充替换、关闭、页签切换和选中舰娘离开当前范围的测试**

- [ ] **步骤 7：运行完整库存页测试**

运行：`flutter test test/owned_inventory_page_test.dart`

预期：PASS，原「装备 → 舰娘」用例仍通过。

- [ ] **步骤 8：提交任务 3**

`feat(库存): 接入舰娘可装备装备查询`

### 任务 4：回归验证与收尾

- [ ] **步骤 1：运行功能测试集**

```text
flutter test test/ship_equipment_compatibility_projection_test.dart test/ship_equipment_compatibility_drawer_test.dart test/owned_inventory_page_test.dart
```

- [ ] **步骤 2：运行变更文件静态分析**

```text
flutter analyze lib/src/inventory test/ship_equipment_compatibility_projection_test.dart test/ship_equipment_compatibility_drawer_test.dart test/owned_inventory_page_test.dart
```

预期：`No issues found!`

- [ ] **步骤 3：检查格式与提交边界**

```text
dart format --output=none --set-exit-if-changed lib/src/inventory test/ship_equipment_compatibility_projection_test.dart test/ship_equipment_compatibility_drawer_test.dart test/owned_inventory_page_test.dart
git diff --check
git status --short
```

- [ ] **步骤 4：请求独立代码审查并修复 Critical / Important 问题**

- [ ] **步骤 5：记录最终验证结果**

报告投影、抽屉、库存页测试与静态分析结果，明确说明未构建 Debug APK。
