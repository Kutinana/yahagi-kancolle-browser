# 主力舰舰种筛选拆分实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在持有与未持有舰娘筛选栏中，将 `BB/BC` 和 `CV/CVL` 拆分为 `BB`、`BC`、`CV`、`CVL` 四个独立分类。

**架构：** 拆分共享的 `ShipInventoryCategory` 枚举和 `shipTypeMatchesInventoryCategory` 映射，使持有与未持有投影自动获得同一行为。页面只更新分类标签；筛选栏仍由现有 `_FilterStrip` 按枚举顺序渲染，不调整布局组件。

**技术栈：** Flutter、Dart、`flutter_test`

---

## 文件结构

- 修改：`test/owned_inventory_projection_test.dart`——验证四个分类的舰种 ID 边界和旧分组覆盖关系。
- 修改：`test/unowned_inventory_projection_test.dart`——将未持有类型 8 的断言改为 `BC`。
- 修改：`test/owned_inventory_page_test.dart`——验证持有与未持有筛选栏的四个独立按钮及顺序。
- 修改：`lib/src/inventory/owned_inventory_projection.dart`——拆分分类枚举和共享匹配映射。
- 修改：`lib/src/inventory/owned_inventory_page.dart`——为四个分类输出独立缩写标签。

### 任务 1：用测试锁定四个分类

**文件：**
- 修改：`test/owned_inventory_projection_test.dart`
- 修改：`test/unowned_inventory_projection_test.dart`
- 修改：`test/owned_inventory_page_test.dart`

- [ ] **步骤 1：增加共享舰种 ID 映射测试**

在 `owned_inventory_projection_test.dart` 增加：

```dart
test('splits battleships and carriers into four disjoint categories', () {
  List<int> matches(ShipInventoryCategory category) => [
    for (var typeId = 1; typeId <= 22; typeId++)
      if (shipTypeMatchesInventoryCategory(typeId, category)) typeId,
  ];

  expect(matches(ShipInventoryCategory.bb), <int>[9, 10, 12]);
  expect(matches(ShipInventoryCategory.bc), <int>[8]);
  expect(matches(ShipInventoryCategory.cv), <int>[11, 18]);
  expect(matches(ShipInventoryCategory.cvl), <int>[7]);
  expect(
    <int>{
      ...matches(ShipInventoryCategory.bb),
      ...matches(ShipInventoryCategory.bc),
    },
    <int>{8, 9, 10, 12},
  );
  expect(
    <int>{
      ...matches(ShipInventoryCategory.cv),
      ...matches(ShipInventoryCategory.cvl),
    },
    <int>{7, 11, 18},
  );
});
```

- [ ] **步骤 2：更新未持有投影期望**

把类型 ID 8 的测试从旧 `bbBc` 改为：

```dart
projection.unownedShipFamiliesFor(category: ShipInventoryCategory.bc)
```

- [ ] **步骤 3：增加两套筛选栏按钮和顺序断言**

在未持有页面测试中断言：

```dart
for (final key in <String>['bb', 'bc', 'cv', 'cvl']) {
  expect(find.byKey(Key('unowned-ship-filter-$key')), findsOneWidget);
}
expect(find.byKey(const Key('unowned-ship-filter-bbBc')), findsNothing);
expect(find.byKey(const Key('unowned-ship-filter-cvCvl')), findsNothing);
final capitalFilterX = <double>[
  tester.getTopLeft(find.byKey(const Key('unowned-ship-filter-bb'))).dx,
  tester.getTopLeft(find.byKey(const Key('unowned-ship-filter-bc'))).dx,
  tester.getTopLeft(find.byKey(const Key('unowned-ship-filter-cv'))).dx,
  tester.getTopLeft(find.byKey(const Key('unowned-ship-filter-cvl'))).dx,
];
expect(capitalFilterX[0], lessThan(capitalFilterX[1]));
expect(capitalFilterX[1], lessThan(capitalFilterX[2]));
expect(capitalFilterX[2], lessThan(capitalFilterX[3]));
```

在持有页面紧凑控件测试中以 `ship-filter-bb`、`ship-filter-bc`、`ship-filter-cv`、`ship-filter-cvl` 重复相同的存在、旧 key 不存在和从左到右顺序检查。

- [ ] **步骤 4：运行测试并确认红灯**

运行：`flutter test test/owned_inventory_projection_test.dart test/unowned_inventory_projection_test.dart test/owned_inventory_page_test.dart --reporter compact`

预期：FAIL，编译器报告新的 `bb`、`bc`、`cv`、`cvl` 枚举值尚不存在，证明测试锁定了目标接口。

### 任务 2：拆分共享枚举、映射和标签

**文件：**
- 修改：`lib/src/inventory/owned_inventory_projection.dart`
- 修改：`lib/src/inventory/owned_inventory_page.dart`

- [ ] **步骤 1：拆分分类枚举并保持按钮顺序**

将枚举改为：

```dart
enum ShipInventoryCategory {
  all,
  bb,
  bc,
  cv,
  cvl,
  ca,
  cl,
  dd,
  de,
  ss,
  support,
}
```

- [ ] **步骤 2：拆分共享舰种匹配映射**

将旧两个分支替换为：

```dart
ShipInventoryCategory.bb => const <int>{9, 10, 12}.contains(typeId),
ShipInventoryCategory.bc => typeId == 8,
ShipInventoryCategory.cv => const <int>{11, 18}.contains(typeId),
ShipInventoryCategory.cvl => typeId == 7,
```

- [ ] **步骤 3：拆分页面标签**

将旧两个标签分支替换为：

```dart
ShipInventoryCategory.bb => 'BB',
ShipInventoryCategory.bc => 'BC',
ShipInventoryCategory.cv => 'CV',
ShipInventoryCategory.cvl => 'CVL',
```

- [ ] **步骤 4：运行三份定向测试并确认绿灯**

运行：`flutter test test/owned_inventory_projection_test.dart test/unowned_inventory_projection_test.dart test/owned_inventory_page_test.dart --reporter compact`

预期：全部通过，四组映射互不重叠，持有与未持有按钮均按 `BB → BC → CV → CVL` 显示。

- [ ] **步骤 5：提交功能变更**

```powershell
git add -- lib/src/inventory/owned_inventory_projection.dart lib/src/inventory/owned_inventory_page.dart test/owned_inventory_projection_test.dart test/unowned_inventory_projection_test.dart test/owned_inventory_page_test.dart
git commit -m "feat(持有一览): 拆分战舰与空母筛选"
```

### 任务 3：回归验证

**文件：**
- 验证：`lib/src/inventory/owned_inventory_projection.dart`
- 验证：`lib/src/inventory/owned_inventory_page.dart`
- 验证：`test/owned_inventory_projection_test.dart`
- 验证：`test/unowned_inventory_projection_test.dart`
- 验证：`test/owned_inventory_page_test.dart`

- [ ] **步骤 1：运行定向静态分析**

运行：`dart analyze lib/src/inventory/owned_inventory_projection.dart lib/src/inventory/owned_inventory_page.dart test/owned_inventory_projection_test.dart test/unowned_inventory_projection_test.dart test/owned_inventory_page_test.dart`

预期：输出 `No issues found!`。

- [ ] **步骤 2：运行完整测试集**

运行：`flutter test --reporter compact`

预期：退出码为 0；仓库既有跳过项允许保持跳过。

- [ ] **步骤 3：检查提交边界**

运行：`git status --short` 和 `git show --stat --oneline HEAD`。

预期：功能提交只包含持有一览投影、页面和三份对应测试；Android 未跟踪文件仍保留。
