# 持有一览锁定式多级排序实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 `subagent-driven-development`（推荐）或 `executing-plans` 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法跟踪进度。

**目标：** 将持有一览的排序交互改为「点击临时排序、长按锁定优先级」，并在表头直接显示临时与锁定状态。

**架构：** 新增一个独立、不可变的排序交互状态模型，负责点击、长按、还原和有效比较链的转换。页面只保存该状态并将有效比较链交给现有投影层；表头只负责显示方向、优先级和锁定图标，不承担状态规则。

**技术栈：** Dart、Flutter、`flutter_test`、现有 `OwnedInventoryProjection` 多条件比较器。

---

## 文件结构

- 创建 `lib/src/inventory/owned_inventory_sort_state.dart`：定义锁定条件、临时条件和状态转换。
- 创建 `test/owned_inventory_sort_state_test.dart`：以纯 Dart 测试覆盖点击、长按、锁定和还原规则。
- 修改 `lib/src/inventory/owned_inventory_page.dart`：接入新状态模型，调整表头视觉反馈和手势。
- 修改 `test/owned_inventory_page_test.dart`：验证真实页面中的单列排序、锁定链、视觉反馈和还原行为。
- 保持 `lib/src/inventory/owned_inventory_projection.dart` 不变：继续接收合成后的 `List<ShipInventorySortCriterion>`。

## 规格覆盖映射

- 点击未锁定表头：任务 1 的 `tap` 状态测试和任务 2 的页面交互测试。
- 长按未锁定表头：任务 1 的 `longPress` 状态测试和任务 3 的直接长按页面测试。
- 操作已锁定表头：任务 1 验证点击切换方向、长按保持不变，任务 2 验证表头反馈。
- 还原排序：任务 1 验证状态恢复，任务 3 验证等级降序和舰种筛选保留。
- 视觉反馈：任务 2 验证颜色职责、带圈优先级和锁图标。
- 稳定排序：任务 3 回归运行现有投影层测试，确认持有舰 ID 兜底不变。

### 任务 1：实现排序交互状态模型

**文件：**

- 创建：`lib/src/inventory/owned_inventory_sort_state.dart`
- 创建：`test/owned_inventory_sort_state_test.dart`

- [ ] **步骤 1：编写状态模型的失败测试**

测试应覆盖以下转换：

```dart
void main() {
  test('starts with an unlocked level descending criterion', () {
    const state = ShipInventorySortState.initial();

    expect(state.lockedCriteria, isEmpty);
    expect(state.activeCriterion?.field, ShipInventorySortField.level);
    expect(state.activeCriterion?.descending, isTrue);
    expect(state.effectiveCriteria, <ShipInventorySortCriterion>[
      const ShipInventorySortCriterion(
        field: ShipInventorySortField.level,
        descending: true,
      ),
    ]);
  });

  test('tap replaces the active field and toggles the same field', () {
    const initial = ShipInventorySortState.initial();
    final firepower = initial.tap(ShipInventorySortField.firepower);
    final ascending = firepower.tap(ShipInventorySortField.firepower);

    expect(firepower.activeCriterion?.field, ShipInventorySortField.firepower);
    expect(firepower.activeCriterion?.descending, isTrue);
    expect(ascending.activeCriterion?.descending, isFalse);
  });

  test('long press locks the active field and a later tap becomes the tail', () {
    final locked = const ShipInventorySortState.initial()
        .tap(ShipInventorySortField.antiSub)
        .longPress(ShipInventorySortField.antiSub);
    final withTail = locked.tap(ShipInventorySortField.firepower);

    expect(locked.lockedCriteria.single.field, ShipInventorySortField.antiSub);
    expect(locked.activeCriterion, isNull);
    expect(
      withTail.effectiveCriteria.map((item) => item.field),
      <ShipInventorySortField>[
        ShipInventorySortField.antiSub,
        ShipInventorySortField.firepower,
      ],
    );
  });
}
```

继续补充：长按其他未锁定字段时直接以降序追加、点击已锁定字段只切换方向、长按已锁定字段保持不变、新点击只替换临时末级、还原恢复未锁定的等级降序。

- [ ] **步骤 2：运行测试并确认失败**

运行：

```bash
flutter test test/owned_inventory_sort_state_test.dart
```

预期：FAIL，提示 `owned_inventory_sort_state.dart` 或 `ShipInventorySortState` 不存在。

- [ ] **步骤 3：实现最小状态模型**

实现以下不可变接口：

```dart
class ShipInventorySortState {
  const ShipInventorySortState({
    required this.lockedCriteria,
    required this.activeCriterion,
  });

  const ShipInventorySortState.initial()
      : lockedCriteria = const <ShipInventorySortCriterion>[],
        activeCriterion = const ShipInventorySortCriterion(
          field: ShipInventorySortField.level,
          descending: true,
        );

  final List<ShipInventorySortCriterion> lockedCriteria;
  final ShipInventorySortCriterion? activeCriterion;

  List<ShipInventorySortCriterion> get effectiveCriteria =>
      <ShipInventorySortCriterion>[
        ...lockedCriteria,
        if (activeCriterion case final active?) active,
      ];

  ShipInventorySortState tap(ShipInventorySortField field) {
    final lockedIndex = lockedCriteria.indexWhere(
      (criterion) => criterion.field == field,
    );
    if (lockedIndex >= 0) {
      final nextLocked = List<ShipInventorySortCriterion>.of(lockedCriteria);
      nextLocked[lockedIndex] = nextLocked[lockedIndex].copyWith(
        descending: !nextLocked[lockedIndex].descending,
      );
      return ShipInventorySortState(
        lockedCriteria: List.unmodifiable(nextLocked),
        activeCriterion: activeCriterion,
      );
    }
    if (activeCriterion?.field == field) {
      return ShipInventorySortState(
        lockedCriteria: lockedCriteria,
        activeCriterion: activeCriterion!.copyWith(
          descending: !activeCriterion!.descending,
        ),
      );
    }
    return ShipInventorySortState(
      lockedCriteria: lockedCriteria,
      activeCriterion: ShipInventorySortCriterion(
        field: field,
        descending: true,
      ),
    );
  }

  ShipInventorySortState longPress(ShipInventorySortField field) {
    if (lockedCriteria.any((criterion) => criterion.field == field)) {
      return this;
    }
    final criterion = activeCriterion?.field == field
        ? activeCriterion!
        : ShipInventorySortCriterion(field: field, descending: true);
    return ShipInventorySortState(
      lockedCriteria: List.unmodifiable(<ShipInventorySortCriterion>[
        ...lockedCriteria,
        criterion,
      ]),
      activeCriterion: null,
    );
  }

  ShipInventorySortState restoreDefault() =>
      const ShipInventorySortState.initial();
}
```

- [ ] **步骤 4：运行状态模型测试并确认通过**

运行：

```bash
flutter test test/owned_inventory_sort_state_test.dart
```

预期：PASS。

- [ ] **步骤 5：提交任务 1**

```bash
git add lib/src/inventory/owned_inventory_sort_state.dart test/owned_inventory_sort_state_test.dart
git commit -m "feat(持有一览): 添加锁定式排序状态模型"
```

### 任务 2：接入页面交互和表头视觉状态

**文件：**

- 修改：`lib/src/inventory/owned_inventory_page.dart:31-221`
- 修改：`lib/src/inventory/owned_inventory_page.dart:483-586`
- 修改：`lib/src/inventory/owned_inventory_page.dart:1043-1088`
- 修改：`test/owned_inventory_page_test.dart:94-234`

- [ ] **步骤 1：将页面测试改为新交互并确认旧实现失败**

把原来的「点击累加、长按删除」测试替换为以下行为断言：

```dart
expect(find.text('等级 ▼'), findsOneWidget);
expect(find.text('等级 ▼①'), findsNothing);

await tester.tap(find.byKey(const Key('owned-inventory-sort-firepower')));
await tester.pump();
expect(find.text('火力 ▼'), findsOneWidget);
expect(find.text('等级'), findsOneWidget);

await tester.longPress(
  find.byKey(const Key('owned-inventory-sort-firepower')),
);
await tester.pump();
expect(find.text('火力 ▼①'), findsOneWidget);
expect(
  find.descendant(
    of: find.byKey(const Key('owned-inventory-sort-firepower')),
    matching: find.byIcon(Icons.lock),
  ),
  findsOneWidget,
);

await tester.tap(find.byKey(const Key('owned-inventory-sort-antiSub')));
await tester.pump();
expect(find.text('对潜 ▼②'), findsOneWidget);
```

继续断言：点击另一个未锁定字段会替换临时末级；点击火力只切换锁定项方向；长按火力不解除锁定。

运行：

```bash
flutter test test/owned_inventory_page_test.dart
```

预期：FAIL，旧实现仍显示默认 `等级 ▼①`，并会点击累加、长按删除。

- [ ] **步骤 2：用新状态模型替换页面内的列表状态**

在页面中：

```dart
ShipInventorySortState _sortState = const ShipInventorySortState.initial();

void _tapShipSort(ShipInventorySortField field) {
  setState(() {
    _sortState = _sortState.tap(field);
    _cachedShipRows = null;
  });
}

void _lockShipSort(ShipInventorySortField field) {
  setState(() {
    _sortState = _sortState.longPress(field);
    _cachedShipRows = null;
  });
}

void _restoreDefaultShipSort() {
  setState(() {
    _sortState = _sortState.restoreDefault();
    _cachedShipRows = null;
  });
}
```

将 `_shipRows()` 和 `_ShipInventoryTable` 的输入改为 `_sortState.effectiveCriteria`、锁定条件和临时条件。

- [ ] **步骤 3：让表头显示锁定与临时状态**

扩展 `_SortableHeader`：

```dart
const _SortableHeader({
  required this.label,
  required this.priority,
  required this.descending,
  required this.locked,
  required this.active,
  required this.onTap,
  required this.onLongPress,
});
```

显示规则：

- 锁定项：蓝色文字、方向、带圈优先级和 `Icons.lock`。
- 有锁定链时的临时项：黄色文字、方向和末级优先级，不显示锁图标。
- 无锁定链时的临时项：黄色文字和方向，不显示优先级。
- 未参与排序的字段：保持现有灰色样式。

长按已锁定字段仍把事件交给状态模型，由状态模型保证无变化。

- [ ] **步骤 4：运行页面测试并确认通过**

运行：

```bash
flutter test test/owned_inventory_page_test.dart
```

预期：PASS。

- [ ] **步骤 5：提交任务 2**

```bash
git add lib/src/inventory/owned_inventory_page.dart test/owned_inventory_page_test.dart
git commit -m "feat(持有一览): 接入表头锁定排序交互"
```

### 任务 3：补充回归验证并完成交付检查

**文件：**

- 修改：`test/owned_inventory_page_test.dart`
- 验证：`test/owned_inventory_projection_test.dart`
- 验证：`test/owned_inventory_sort_state_test.dart`

- [ ] **步骤 1：补充还原与直接长按的页面边界测试**

增加测试以验证：

```dart
await tester.longPress(
  find.byKey(const Key('owned-inventory-sort-antiSub')),
);
await tester.pump();
expect(find.text('对潜 ▼①'), findsOneWidget);
expect(
  find.descendant(
    of: find.byKey(const Key('owned-inventory-sort-antiSub')),
    matching: find.byIcon(Icons.lock),
  ),
  findsOneWidget,
);

await tester.tap(find.byKey(const Key('ship-filter-dd')));
await tester.tap(find.byKey(const Key('owned-inventory-sort-reset')));
await tester.pump();
expect(find.text('等级 ▼'), findsOneWidget);
expect(
  find.descendant(
    of: find.byKey(const Key('owned-inventory-sort-level')),
    matching: find.byIcon(Icons.lock),
  ),
  findsNothing,
);
expect(find.text('夕立'), findsOneWidget);
expect(find.text('吹雪'), findsNothing);
```

另加一组断言：锁定反潜、锁定火力、点击雷装后改点装甲，最终只显示装甲作为临时 `③`，锁定的 `①②` 不变。

- [ ] **步骤 2：运行相关测试**

运行：

```bash
flutter test \
  test/owned_inventory_sort_state_test.dart \
  test/owned_inventory_projection_test.dart \
  test/owned_inventory_page_test.dart
```

预期：全部 PASS。

- [ ] **步骤 3：运行定向静态分析和差异检查**

运行：

```bash
flutter analyze \
  lib/src/inventory/owned_inventory_sort_state.dart \
  lib/src/inventory/owned_inventory_projection.dart \
  lib/src/inventory/owned_inventory_page.dart \
  test/owned_inventory_sort_state_test.dart \
  test/owned_inventory_projection_test.dart \
  test/owned_inventory_page_test.dart
git diff --check
```

预期：静态分析显示 `No issues found!`，差异检查无输出。

- [ ] **步骤 4：提交任务 3**

```bash
git add test/owned_inventory_page_test.dart
git commit -m "test(持有一览): 补充锁定排序边界验证"
```

- [ ] **步骤 5：请求代码审查并处理结果**

审查范围从计划提交后的基线到当前分支 `HEAD`，重点检查：

- 点击与长按是否严格符合书面规格。
- 锁定项是否只能通过还原统一清除。
- 表头的颜色、优先级与锁图标是否和实际状态一致。
- 排序链是否继续使用持有舰 ID 作为稳定兜底。
