# 持有一览多级排序实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 为舰娘持有一览增加按点击顺序组合的多级排序、长按移除条件，以及位于舰种分类行末尾的默认排序还原按钮。

**架构：** 在持有数据投影层定义不可变的排序条件，并由投影层执行逐级比较和稳定兜底。页面只管理有序条件列表和手势，把条件及优先级传给表头展示；分类筛选与排序状态保持相互独立。

**技术栈：** Dart、Flutter、`flutter_test`、现有 `OwnedInventoryProjection` 与 `FrozenDataTable`。

---

## 文件结构

- 修改 `lib/src/inventory/owned_inventory_projection.dart`：定义排序条件、默认条件和多级比较器。
- 修改 `test/owned_inventory_projection_test.dart`：覆盖多级方向、稳定兜底和空列表回退。
- 修改 `lib/src/inventory/owned_inventory_page.dart`：管理条件列表、增加表头长按、优先级标记和还原按钮。
- 修改 `test/owned_inventory_page_test.dart`：覆盖追加、切换、移除、还原及分类保留。

### 任务 1：在投影层实现多级排序

**文件：**

- 修改：`lib/src/inventory/owned_inventory_projection.dart:5-22,153-223`
- 测试：`test/owned_inventory_projection_test.dart:1-82`

- [ ] **步骤 1：编写失败的多级排序测试**

增加包含相同等级、不同火力和反潜值的舰娘数据，并断言以下条件按顺序生效：

```dart
const criteria = <ShipInventorySortCriterion>[
  ShipInventorySortCriterion(
    field: ShipInventorySortField.level,
    descending: true,
  ),
  ShipInventorySortCriterion(
    field: ShipInventorySortField.firepower,
    descending: true,
  ),
  ShipInventorySortCriterion(
    field: ShipInventorySortField.antiSub,
    descending: false,
  ),
];

expect(
  projection.shipRows(sortCriteria: criteria).map((row) => row.ship.id),
  <int>[4, 3, 2, 1],
);
```

再增加两个断言：空列表回退为等级降序；全部字段相同时按持有舰实例 ID 升序。

- [ ] **步骤 2：运行投影测试并确认失败**

运行：

```bash
flutter test test/owned_inventory_projection_test.dart
```

预期：编译失败，提示 `ShipInventorySortCriterion` 或 `sortCriteria` 尚未定义。

- [ ] **步骤 3：实现不可变排序条件和逐级比较**

在投影文件中加入：

```dart
class ShipInventorySortCriterion {
  const ShipInventorySortCriterion({
    required this.field,
    required this.descending,
  });

  final ShipInventorySortField field;
  final bool descending;

  ShipInventorySortCriterion copyWith({bool? descending}) =>
      ShipInventorySortCriterion(
        field: field,
        descending: descending ?? this.descending,
      );
}

const defaultShipInventorySortCriteria = <ShipInventorySortCriterion>[
  ShipInventorySortCriterion(
    field: ShipInventorySortField.level,
    descending: true,
  ),
];
```

将 `shipRows` 的单字段参数替换为：

```dart
List<ShipInventoryRow> shipRows({
  ShipInventoryCategory category = ShipInventoryCategory.all,
  List<ShipInventorySortCriterion> sortCriteria =
      defaultShipInventorySortCriteria,
})
```

空列表使用 `defaultShipInventorySortCriteria`。排序闭包逐项调用 `_compareShipRows`，应用各自方向；所有条件相同后使用 `left.ship.id.compareTo(right.ship.id)`。

- [ ] **步骤 4：更新原有单字段测试调用并验证通过**

将原有 `sortField` 和 `descending` 调用改为单元素 `sortCriteria`。运行：

```bash
dart format lib/src/inventory/owned_inventory_projection.dart test/owned_inventory_projection_test.dart
flutter test test/owned_inventory_projection_test.dart
```

预期：投影测试全部通过。

- [ ] **步骤 5：提交投影层变更**

```bash
git add lib/src/inventory/owned_inventory_projection.dart test/owned_inventory_projection_test.dart
git commit -m "feat(持有一览): 支持舰娘多级排序比较"
```

### 任务 2：接入页面状态、表头手势和还原按钮

**文件：**

- 修改：`lib/src/inventory/owned_inventory_page.dart:30-190,350-430,440-510,991-1030`
- 测试：`test/owned_inventory_page_test.dart:82-115`

- [ ] **步骤 1：编写失败的页面交互测试**

扩展现有排序组件测试或增加独立测试，验证：

```dart
expect(find.text('等级 ▼①'), findsOneWidget);

await tester.tap(find.text('火力'));
await tester.pump();
expect(find.text('等级 ▼①'), findsOneWidget);
expect(find.text('火力 ▼②'), findsOneWidget);

await tester.tap(find.text('反潜'));
await tester.pump();
expect(find.text('反潜 ▼③'), findsOneWidget);

await tester.tap(find.text('火力 ▼②'));
await tester.pump();
expect(find.text('火力 ▲②'), findsOneWidget);
```

增加长按测试：长按“火力”后，反潜的编号变为 `②`。增加还原测试：切换舰种分类后点击 `owned-inventory-sort-reset`，恢复“等级 ▼①”，且分类结果数量保持不变。

- [ ] **步骤 2：运行页面测试并确认失败**

运行：

```bash
flutter test test/owned_inventory_page_test.dart
```

预期：测试找不到多级编号和还原按钮。

- [ ] **步骤 3：将页面排序状态改为有序条件列表**

用以下状态替换 `_sortField` 和 `_descending`：

```dart
List<ShipInventorySortCriterion> _sortCriteria =
    List<ShipInventorySortCriterion>.of(defaultShipInventorySortCriteria);
```

实现三个状态方法：

```dart
void _toggleShipSort(ShipInventorySortField field) {
  final next = List<ShipInventorySortCriterion>.of(_sortCriteria);
  final index = next.indexWhere((criterion) => criterion.field == field);
  if (index < 0) {
    next.add(ShipInventorySortCriterion(field: field, descending: true));
  } else {
    next[index] = next[index].copyWith(
      descending: !next[index].descending,
    );
  }
  setState(() {
    _sortCriteria = next;
    _cachedShipRows = null;
  });
}

void _removeShipSort(ShipInventorySortField field) {
  final next = _sortCriteria
      .where((criterion) => criterion.field != field)
      .toList();
  setState(() {
    _sortCriteria = next.isEmpty
        ? List<ShipInventorySortCriterion>.of(
            defaultShipInventorySortCriteria,
          )
        : next;
    _cachedShipRows = null;
  });
}

void _restoreDefaultShipSort() {
  setState(() {
    _sortCriteria = List<ShipInventorySortCriterion>.of(
      defaultShipInventorySortCriteria,
    );
    _cachedShipRows = null;
  });
}
```

每次变更创建新列表、清除 `_cachedShipRows` 并调用 `setState`。分类状态不在还原方法中修改。

- [ ] **步骤 4：让分类条支持末尾操作按钮**

为 `_FilterStrip` 增加可选的 `actionLabel`、`actionKey` 和 `onAction`。舰娘分类条传入：

```dart
actionLabel: l10n.restoreDefaultOrder,
actionKey: const Key('owned-inventory-sort-reset'),
onAction: _restoreDefaultShipSort,
```

操作按钮放在最后一个舰种分类按钮之后、结果数量之前。装备分类条不传这些参数，外观和行为保持不变。

- [ ] **步骤 5：展示所有排序字段的方向和优先级**

`_ShipInventoryTable` 接收 `sortCriteria`、`onSort` 和 `onRemoveSort`。表头按字段查找条件下标，将 `priority = index + 1` 传给 `_SortableHeader`。

`_SortableHeader` 增加 `priority` 和 `onLongPress`。当 `priority != null` 时显示箭头及圈号：

```dart
String _circledPriority(int priority) =>
    priority >= 1 && priority <= 20
        ? String.fromCharCode(0x245f + priority)
        : '($priority)';
```

`InkWell` 同时绑定 `onTap` 和 `onLongPress`。未参与排序的字段不显示箭头、编号或选中颜色。

- [ ] **步骤 6：格式化并运行页面测试**

运行：

```bash
dart format lib/src/inventory/owned_inventory_page.dart test/owned_inventory_page_test.dart
flutter test test/owned_inventory_page_test.dart
```

预期：页面交互测试全部通过。

- [ ] **步骤 7：提交页面变更**

```bash
git add lib/src/inventory/owned_inventory_page.dart test/owned_inventory_page_test.dart
git commit -m "feat(持有一览): 添加多级排序交互"
```

### 任务 3：回归验证和完成审查

**文件：**

- 验证：`lib/src/inventory/owned_inventory_projection.dart`
- 验证：`lib/src/inventory/owned_inventory_page.dart`
- 验证：`test/owned_inventory_projection_test.dart`
- 验证：`test/owned_inventory_page_test.dart`

- [ ] **步骤 1：运行持有一览相关验证**

```bash
flutter test test/owned_inventory_projection_test.dart test/owned_inventory_page_test.dart
flutter analyze lib/src/inventory/owned_inventory_projection.dart lib/src/inventory/owned_inventory_page.dart test/owned_inventory_projection_test.dart test/owned_inventory_page_test.dart
```

预期：测试全部通过，静态分析无问题。

- [ ] **步骤 2：运行全量 Flutter 测试**

```bash
flutter test
```

预期：全部测试通过；既有跳过项数量可以保持不变。

- [ ] **步骤 3：检查差异和工作区边界**

```bash
git diff --check
git status --short
```

确认没有空白错误，且未暂存或修改与本功能无关的用户文件。

- [ ] **步骤 4：请求代码审查并处理 Critical/Important 问题**

审查重点：排序优先级是否稳定、长按是否误触点击、还原是否保留分类，以及分类条在紧凑横屏下是否仍可横向滚动。

- [ ] **步骤 5：提交审查修正（仅在需要时）**

```bash
git add lib/src/inventory/owned_inventory_projection.dart lib/src/inventory/owned_inventory_page.dart test/owned_inventory_projection_test.dart test/owned_inventory_page_test.dart
git commit -m "fix(持有一览): 修正多级排序边界行为"
```
