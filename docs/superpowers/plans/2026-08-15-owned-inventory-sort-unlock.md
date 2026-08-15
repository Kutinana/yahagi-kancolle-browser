# 持有一览排序长按解锁与图标还原实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 允许再次长按已锁定排序列来解除该列并自动前移后续优先级，同时把文字还原按钮替换为紧凑的琥珀色还原图标。

**架构：** 解锁规则集中在不可变的 `ShipInventorySortState` 中，页面只接收新状态并刷新排序缓存。表头对锁定和未锁定状态都暴露长按及键盘语义操作；筛选条通过可选图标动作渲染还原按钮，仍复用现有本地化标签。

**技术栈：** Dart、Flutter Material、Flutter widget test、ARB/gen-l10n

---

## 文件结构

- 修改 `lib/src/inventory/owned_inventory_sort_state.dart`：实现移除锁定条件及最后一个锁定条件的回退规则。
- 修改 `lib/src/inventory/owned_inventory_page.dart`：开放锁定表头长按解锁，提供对应语义动作，并渲染图标还原按钮。
- 修改 `lib/l10n/app_zh.arb`、`lib/l10n/app_zh_Hant.arb`、`lib/l10n/app_ja.arb`：更新锁定表头提示并增加解除锁定动作文案。
- 重新生成 `lib/l10n/app_localizations.dart`、`lib/l10n/app_localizations_zh.dart`、`lib/l10n/app_localizations_ja.dart`：同步本地化接口与实现。
- 修改 `test/owned_inventory_sort_state_test.dart`：覆盖中间解锁、临时排序保留和最后锁回退。
- 修改 `test/owned_inventory_page_test.dart`：覆盖实际长按解锁、语义动作和图标还原交互。

### 任务 1：排序状态解锁规则

**文件：**
- 修改：`test/owned_inventory_sort_state_test.dart`
- 修改：`lib/src/inventory/owned_inventory_sort_state.dart`

- [ ] **步骤 1：把旧的“长按锁定字段不变”测试替换为三个失败测试**

```dart
test('long-pressing a locked field removes it and keeps remaining order', () {
  final state = const ShipInventorySortState.initial()
      .longPress(ShipInventorySortField.level)
      .longPress(ShipInventorySortField.name)
      .tap(ShipInventorySortField.condition);

  final result = state.longPress(ShipInventorySortField.level);

  expect(result.lockedCriteria, hasLength(1));
  expectCriterion(result.lockedCriteria.single, ShipInventorySortField.name, true);
  expectCriterion(result.activeCriterion!, ShipInventorySortField.condition, true);
});

test('unlocking the last lock keeps an active single-column sort', () {
  final state = const ShipInventorySortState.initial()
      .longPress(ShipInventorySortField.level)
      .tap(ShipInventorySortField.firepower);

  final result = state.longPress(ShipInventorySortField.level);

  expect(result.lockedCriteria, isEmpty);
  expectCriterion(result.activeCriterion!, ShipInventorySortField.firepower, true);
});

test('unlocking the last lock without active restores default level sort', () {
  final state = const ShipInventorySortState.initial()
      .longPress(ShipInventorySortField.antiSub);

  final result = state.longPress(ShipInventorySortField.antiSub);

  expect(result.lockedCriteria, isEmpty);
  expectCriterion(result.activeCriterion!, ShipInventorySortField.level, true);
});
```

- [ ] **步骤 2：运行状态测试并确认因旧逻辑而失败**

运行：`flutter test test/owned_inventory_sort_state_test.dart`

预期：新增用例 FAIL；实际状态仍保留被长按的锁定字段，或最后一锁没有恢复默认排序。

- [ ] **步骤 3：实现最小解锁逻辑**

```dart
ShipInventorySortState longPress(ShipInventorySortField field) {
  final lockedIndex = lockedCriteria.indexWhere(
    (criterion) => criterion.field == field,
  );
  if (lockedIndex >= 0) {
    final nextLocked = List<ShipInventorySortCriterion>.of(lockedCriteria)
      ..removeAt(lockedIndex);
    if (nextLocked.isEmpty && activeCriterion == null) {
      return const ShipInventorySortState.initial();
    }
    return ShipInventorySortState._(nextLocked, activeCriterion);
  }

  final criterion = activeCriterion?.field == field
      ? activeCriterion!
      : ShipInventorySortCriterion(field: field, descending: true);
  return ShipInventorySortState._(
    <ShipInventorySortCriterion>[...lockedCriteria, criterion],
    null,
  );
}
```

- [ ] **步骤 4：运行状态测试并确认通过**

运行：`flutter test test/owned_inventory_sort_state_test.dart`

预期：全部 PASS。

- [ ] **步骤 5：提交状态模型变更**

```powershell
git add -- lib/src/inventory/owned_inventory_sort_state.dart test/owned_inventory_sort_state_test.dart
git commit -m "feat(持有一览): 支持长按解除排序锁定"
```

### 任务 2：表头解锁交互与无障碍语义

**文件：**
- 修改：`test/owned_inventory_page_test.dart`
- 修改：`lib/src/inventory/owned_inventory_page.dart`
- 修改：`lib/l10n/app_zh.arb`
- 修改：`lib/l10n/app_zh_Hant.arb`
- 修改：`lib/l10n/app_ja.arb`
- 生成：`lib/l10n/app_localizations.dart`
- 生成：`lib/l10n/app_localizations_zh.dart`
- 生成：`lib/l10n/app_localizations_ja.dart`

- [ ] **步骤 1：编写锁定表头可解锁及优先级前移的失败测试**

```dart
await tester.longPress(antiSubHeader);
await tester.pump();
await tester.longPress(firepowerHeader);
await tester.pump();
await tester.tap(armorHeader);
await tester.pump();

await tester.longPress(antiSubHeader);
await tester.pump();

expect(find.text('对潜'), findsOneWidget);
expect(find.text('火力 ▼①'), findsOneWidget);
expect(find.text('装甲 ▼②'), findsOneWidget);
expect(find.descendant(of: antiSubHeader, matching: find.byIcon(Icons.lock)), findsNothing);
expect(find.descendant(of: firepowerHeader, matching: find.byIcon(Icons.lock)), findsOneWidget);
```

同时更新语义测试，要求锁定后的表头仍有 `SemanticsAction.longPress` 和名为“解除当前排序锁定”的自定义动作；执行后锁图标消失。

- [ ] **步骤 2：运行页面测试并确认因锁定语义被禁用而失败**

运行：`flutter test test/owned_inventory_page_test.dart`

预期：FAIL，锁定表头目前没有长按和自定义语义动作，长按后的显示优先级也不变化。

- [ ] **步骤 3：更新本地化文案并生成代码**

ARB 新增：

```json
"sortUnlockAction": "解除当前排序锁定"
```

简体中文锁定提示改为：

```json
"sortHeaderLockedHint": "点击切换排序方向；长按或按 Shift+Enter 解除锁定"
```

繁体中文与日文提供等义文案，然后运行：`flutter gen-l10n`。

- [ ] **步骤 4：开放锁定状态下的长按和键盘操作**

```dart
final sortAction = CustomSemanticsAction(
  label: locked ? l10n.sortUnlockAction : l10n.sortLockAction,
);

return Semantics(
  onTap: onTap,
  onLongPress: onLongPress,
  customSemanticsActions: <CustomSemanticsAction, VoidCallback>{
    sortAction: onLongPress,
  },
  // ...
);
```

`Shift+Enter` 始终调用 `onLongPress`，使键盘行为与长按一致。

- [ ] **步骤 5：运行页面测试并确认通过**

运行：`flutter test test/owned_inventory_page_test.dart`

预期：全部 PASS。

- [ ] **步骤 6：提交表头交互变更**

```powershell
git add -- lib/src/inventory/owned_inventory_page.dart lib/l10n test/owned_inventory_page_test.dart
git commit -m "feat(持有一览): 完善排序锁定解除交互"
```

### 任务 3：紧凑还原图标

**文件：**
- 修改：`test/owned_inventory_page_test.dart`
- 修改：`lib/src/inventory/owned_inventory_page.dart`

- [ ] **步骤 1：编写还原按钮视觉与语义失败测试**

```dart
final reset = find.byKey(const Key('owned-inventory-sort-reset'));
expect(find.descendant(of: reset, matching: find.byIcon(Icons.restore)), findsOneWidget);
expect(find.descendant(of: reset, matching: find.text('还原默认排序')), findsNothing);
expect(tester.getSize(reset).width, inInclusiveRange(32, 36));

final semantics = tester.getSemantics(reset);
expect(semantics.label, contains('还原默认排序'));
```

保留现有“点击后恢复等级降序且 DD 筛选不变”断言。

- [ ] **步骤 2：运行页面测试并确认因当前文字芯片而失败**

运行：`flutter test test/owned_inventory_page_test.dart`

预期：FAIL，当前动作仍渲染文字 `_FilterChip`，没有 `Icons.restore`。

- [ ] **步骤 3：给筛选条增加图标动作并替换文字芯片**

`_FilterStrip` 增加可选 `actionIcon`，舰娘筛选条传入 `Icons.restore`。动作使用：

```dart
Tooltip(
  message: actionLabel!,
  child: Semantics(
    button: true,
    label: actionLabel!,
    child: SizedBox.square(
      dimension: 34,
      child: IconButton(
        key: actionKey,
        padding: EdgeInsets.zero,
        iconSize: 19,
        color: const Color(0xffffc85a),
        tooltip: actionLabel!,
        onPressed: onAction,
        icon: Icon(actionIcon),
      ),
    ),
  ),
)
```

避免重复 Tooltip/语义包装；最终结构只保留一个工具提示和一个按钮语义节点。

- [ ] **步骤 4：运行页面测试并确认通过**

运行：`flutter test test/owned_inventory_page_test.dart`

预期：全部 PASS，筛选条高度仍不超过 30 px，或在现有 28 px 行高内通过约束压缩图标点击区；如 Material 最小约束导致超高，使用 `constraints: const BoxConstraints.tightFor(width: 34, height: 28)` 保持现有行高。

- [ ] **步骤 5：提交图标还原变更**

```powershell
git add -- lib/src/inventory/owned_inventory_page.dart test/owned_inventory_page_test.dart
git commit -m "style(持有一览): 将排序还原改为图标按钮"
```

### 任务 4：整体验证

**文件：**
- 验证本计划涉及的全部文件

- [ ] **步骤 1：运行定向回归测试**

运行：

```powershell
flutter test test/owned_inventory_sort_state_test.dart test/owned_inventory_page_test.dart
```

预期：全部 PASS。

- [ ] **步骤 2：运行相关静态分析**

运行：

```powershell
flutter analyze lib/src/inventory/owned_inventory_sort_state.dart lib/src/inventory/owned_inventory_page.dart test/owned_inventory_sort_state_test.dart test/owned_inventory_page_test.dart
```

预期：`No issues found!`

- [ ] **步骤 3：检查变更范围和空白错误**

运行：

```powershell
git diff --check master...HEAD
git status --short
git diff --stat master...HEAD
```

预期：没有空白错误；提交只包含计划、排序状态、持有一览页面、本地化和对应测试。既存未跟踪 `test/fixtures/` 不纳入提交。

- [ ] **步骤 4：确认功能分支提交完整**

运行：`git log --oneline master..HEAD`

预期：显示本计划文档及三个原子功能提交。
