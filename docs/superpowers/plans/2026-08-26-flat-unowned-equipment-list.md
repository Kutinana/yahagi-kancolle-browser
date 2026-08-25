# 未持有装备扁平列表实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 删除未持有装备页的重复汇总行和装备类型折叠分组，按现有投影顺序直接展示装备卡片。

**架构：** 保留顶部 `_FilterStrip` 与 `UnownedInventoryProjection` 的过滤、排序逻辑，只将 `_UnownedEquipmentView` 从“分组 Column + ExpansionTile”替换为与 `_UnownedShipsView` 一致的 `SingleChildScrollView + Wrap`。删除不再使用的 `_UnownedGroup`，装备卡组件保持不变。

**技术栈：** Flutter、Dart、`flutter_test`

---

## 文件结构

- 修改：`test/owned_inventory_page_test.dart`——锁定扁平结构、顶部筛选计数、卡片数量与投影顺序。
- 修改：`lib/src/inventory/owned_inventory_page.dart`——扁平渲染装备卡并删除分组组件。

### 任务 1：用组件测试锁定扁平装备列表

**文件：**
- 修改：`test/owned_inventory_page_test.dart`

- [ ] **步骤 1：改写未持有筛选测试，使其要求扁平列表**

在 `unowned views reuse filters and remember each category` 中保存主炮筛选行，并把旧汇总断言替换为结构和顺序断言：

```dart
final mainGunRows = projection.unownedEquipmentFor(
  category: EquipmentInventoryCategory.mainGun,
);
final mainGunCount = mainGunRows.length;
```

```dart
expect(find.byKey(const Key('unowned-equipment-summary')), findsNothing);
expect(find.byType(ExpansionTile), findsNothing);
expect(
  tester
      .widget<Text>(
        find.byKey(const Key('unowned-equipment-filter-result-count')),
      )
      .data,
  '$mainGunCount',
);
final equipmentCardKeys = find
    .byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith(
            'unowned-equipment-',
          ),
    )
    .evaluate()
    .map((element) => (element.widget.key! as ValueKey<String>).value)
    .toList();
expect(
  equipmentCardKeys,
  mainGunRows.map((row) => 'unowned-equipment-${row.master.id}').toList(),
);
expect(tester.takeException(), isNull);
```

- [ ] **步骤 2：运行测试并确认红灯**

运行：`flutter test test/owned_inventory_page_test.dart --plain-name "unowned views reuse filters and remember each category"`

预期：FAIL，因为 `unowned-equipment-summary` 和 `ExpansionTile` 仍存在。

### 任务 2：扁平渲染未持有装备卡

**文件：**
- 修改：`lib/src/inventory/owned_inventory_page.dart`

- [ ] **步骤 1：将装备视图替换为舰娘同款滚动 Wrap**

用以下实现替换 `_UnownedEquipmentView.build`：

```dart
@override
Widget build(BuildContext context) {
  return SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Align(
        alignment: Alignment.topLeft,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final row in rows) _UnownedEquipmentCard(row: row),
          ],
        ),
      ),
    ),
  );
}
```

- [ ] **步骤 2：删除不再使用的分组组件**

完整删除 `_UnownedGroup` 类。不要修改 `_UnownedEquipmentCard`，以保留卡片内装备名称和装备类型。

- [ ] **步骤 3：运行定向测试并确认绿灯**

运行：`flutter test test/owned_inventory_page_test.dart --plain-name "unowned views reuse filters and remember each category"`

预期：PASS，顶部结果数正确、无汇总和折叠控件、卡片顺序与投影一致、无布局异常。

- [ ] **步骤 4：提交功能变更**

```powershell
git add -- lib/src/inventory/owned_inventory_page.dart test/owned_inventory_page_test.dart
git commit -m "feat(持有一览): 扁平展示未持有装备"
```

### 任务 3：回归验证

**文件：**
- 验证：`lib/src/inventory/owned_inventory_page.dart`
- 验证：`test/owned_inventory_page_test.dart`

- [ ] **步骤 1：运行持有一览完整测试文件**

运行：`flutter test test/owned_inventory_page_test.dart --reporter compact`

预期：全部通过。

- [ ] **步骤 2：运行定向静态分析**

运行：`dart analyze lib/src/inventory/owned_inventory_page.dart test/owned_inventory_page_test.dart`

预期：输出 `No issues found!`。

- [ ] **步骤 3：运行完整测试集**

运行：`flutter test --reporter compact`

预期：退出码为 0；仓库既有跳过项允许保持跳过。

- [ ] **步骤 4：检查提交边界**

运行：`git status --short` 和 `git show --stat --oneline HEAD`。

预期：功能提交只包含持有一览页面和对应组件测试；工作区没有本次功能遗留修改。
