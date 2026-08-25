# 未持有一览顶部筛选实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 为未持有舰娘和未持有装备加入与持有页一致的顶部分类筛选条。

**架构：** 将舰娘分类判定提取为持有与未持有投影共享的纯函数，并让未持有投影按可选分类返回结果。页面为未持有舰娘和装备分别保存筛选状态，复用现有 `_FilterStrip` 渲染按钮及结果数，过滤后再生成下方分组。

**技术栈：** Flutter、Dart、flutter_test

---

## 文件结构

- 修改 `lib/src/inventory/owned_inventory_projection.dart`：公开共享的舰种分类判定函数。
- 修改 `lib/src/inventory/unowned_inventory_projection.dart`：提供按舰娘/装备分类过滤的投影方法。
- 修改 `lib/src/inventory/owned_inventory_page.dart`：保存未持有筛选状态并复用顶部筛选条。
- 修改 `test/unowned_inventory_projection_test.dart`：验证未持有纯投影分类。
- 修改 `test/owned_inventory_page_test.dart`：验证页面筛选交互与结果数。

### 任务 1：未持有投影支持通用分类

**文件：**
- 修改：`lib/src/inventory/owned_inventory_projection.dart`
- 修改：`lib/src/inventory/unowned_inventory_projection.dart`
- 测试：`test/unowned_inventory_projection_test.dart`

- [ ] **步骤 1：编写失败的投影测试**

在测试数据中增加战舰舰系、驱逐舰舰系、主炮和舰载机，断言：

```dart
expect(
  projection
      .unownedShipFamiliesFor(category: ShipInventoryCategory.dd)
      .map((row) => row.master.id),
  <int>[4],
);
expect(
  projection
      .unownedEquipmentFor(category: EquipmentInventoryCategory.mainGun)
      .map((row) => row.master.id),
  <int>[102],
);
expect(
  projection
      .unownedShipFamiliesFor(category: ShipInventoryCategory.bbBc)
      .map((row) => row.master.id),
  <int>[8],
);
```

- [ ] **步骤 2：运行测试验证失败**

运行：

```powershell
flutter test test/unowned_inventory_projection_test.dart
```

预期：编译失败，提示 `unownedShipFamiliesFor` 和 `unownedEquipmentFor` 未定义。

- [ ] **步骤 3：实现最少投影代码**

在持有投影中提取：

```dart
bool shipTypeMatchesInventoryCategory(
  int typeId,
  ShipInventoryCategory category,
) => switch (category) {
  ShipInventoryCategory.all => true,
  ShipInventoryCategory.bbBc => const <int>{8, 9, 10, 12}.contains(typeId),
  ShipInventoryCategory.cvCvl => const <int>{7, 11, 18}.contains(typeId),
  ShipInventoryCategory.ca => const <int>{5, 6}.contains(typeId),
  ShipInventoryCategory.cl => const <int>{3, 4, 21}.contains(typeId),
  ShipInventoryCategory.dd => typeId == 2,
  ShipInventoryCategory.de => typeId == 1,
  ShipInventoryCategory.ss => const <int>{13, 14}.contains(typeId),
  ShipInventoryCategory.support =>
    const <int>{15, 16, 17, 19, 20, 22}.contains(typeId),
};
```

持有舰娘过滤改用该函数。未持有投影新增：

```dart
List<UnownedShipFamilyRow> unownedShipFamiliesFor({
  ShipInventoryCategory category = ShipInventoryCategory.all,
}) => <UnownedShipFamilyRow>[
  for (final row in unownedShipFamilies)
    if (category == ShipInventoryCategory.all ||
        shipTypeMatchesInventoryCategory(row.typeId, category))
      row,
];

List<UnownedEquipmentRow> unownedEquipmentFor({
  EquipmentInventoryCategory category = EquipmentInventoryCategory.all,
}) => <UnownedEquipmentRow>[
  for (final row in unownedEquipment)
    if (category == EquipmentInventoryCategory.all ||
        equipmentInventoryCategoryFor(row.master) == category)
      row,
];
```

- [ ] **步骤 4：运行测试验证通过并提交**

运行：`flutter test test/unowned_inventory_projection_test.dart`

预期：全部 PASS。

```powershell
git add lib/src/inventory/owned_inventory_projection.dart lib/src/inventory/unowned_inventory_projection.dart test/unowned_inventory_projection_test.dart
git commit -m "feat(持有一览): 支持未持有内容分类投影"
```

### 任务 2：未持有页面复用顶部筛选条

**文件：**
- 修改：`lib/src/inventory/owned_inventory_page.dart`
- 测试：`test/owned_inventory_page_test.dart`

- [ ] **步骤 1：编写失败的 Widget 测试**

构造包含 DD、BB、主炮和舰载机的页面状态，以 `showOwned: false` 打开页面并断言：

```dart
expect(find.byKey(const Key('unowned-ship-filter-all')), findsOneWidget);
expect(find.byKey(const Key('unowned-ship-filter-dd')), findsOneWidget);
await tester.tap(find.byKey(const Key('unowned-ship-filter-dd')));
await tester.pump();
expect(find.byKey(const Key('unowned-ship-4')), findsOneWidget);
expect(find.byKey(const Key('unowned-ship-8')), findsNothing);
```

切换装备后断言：

```dart
expect(find.byKey(const Key('unowned-equipment-filter-mainGun')), findsOneWidget);
await tester.tap(find.byKey(const Key('unowned-equipment-filter-mainGun')));
await tester.pump();
expect(find.byKey(const Key('unowned-equipment-102')), findsOneWidget);
expect(find.byKey(const Key('unowned-equipment-103')), findsNothing);
expect(find.byType(TextField), findsNothing);
```

- [ ] **步骤 2：运行测试验证失败**

运行：

```powershell
flutter test test/owned_inventory_page_test.dart --plain-name "unowned inventory reuses the common category filter strip"
```

预期：FAIL，找不到 `unowned-ship-filter-*` 筛选按钮。

- [ ] **步骤 3：实现最少页面代码**

在 `_OwnedInventoryPageState` 增加独立状态：

```dart
ShipInventoryCategory _unownedShipCategory = ShipInventoryCategory.all;
EquipmentInventoryCategory _unownedEquipmentCategory =
    EquipmentInventoryCategory.all;
```

未持有模式中计算过滤后的结果，并在内容区前复用 `_FilterStrip`：

```dart
_FilterStrip<ShipInventoryCategory>(
  values: ShipInventoryCategory.values,
  selected: _unownedShipCategory,
  resultCount: unownedShipRows.length,
  label: (value) => _shipCategoryLabel(value, l10n),
  keyFor: (value) => Key('unowned-ship-filter-${value.name}'),
  onSelected: (value) => setState(() => _unownedShipCategory = value),
)
```

装备使用 `EquipmentInventoryCategory.values`、`_equipmentCategoryLabel` 和 `unowned-equipment-filter-${value.name}`，不传排序恢复 action。将过滤后的行传入未持有分组视图，保证空分组自然消失。

- [ ] **步骤 4：运行页面与本地化测试**

运行：

```powershell
flutter test test/owned_inventory_page_test.dart test/unowned_inventory_view_test.dart test/localization_contract_test.dart
```

预期：全部 PASS。

- [ ] **步骤 5：提交**

```powershell
git add lib/src/inventory/owned_inventory_page.dart test/owned_inventory_page_test.dart
git commit -m "feat(持有一览): 为未持有页添加顶部筛选"
```

### 任务 3：完整回归与静态检查

**文件：**
- 验证：全部已修改文件

- [ ] **步骤 1：运行针对性静态检查**

```powershell
flutter analyze lib/src/inventory/owned_inventory_projection.dart lib/src/inventory/unowned_inventory_projection.dart lib/src/inventory/owned_inventory_page.dart
```

预期：无 error 或 warning。

- [ ] **步骤 2：运行完整测试**

```powershell
flutter test --reporter compact
```

预期：全部测试通过；允许项目已有的显式 skip。

- [ ] **步骤 3：审计工作区**

```powershell
git diff --check
git status --short
```

预期：没有未提交的本功能文件；用户原有 `.gitignore` 修改保持未提交。
