# 未持有列表重置图标实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 将未持有舰娘的“清除排除”文字按钮替换为筛选结果前的回转图标，并为未持有装备增加恢复“全部”筛选的同款图标。

**架构：** 两个未持有筛选条复用 `_FilterStrip` 已有的前置 action 通道和 `_FilterActionButton`，不新增视觉组件。舰娘 action 调用现有 `clearExcludedFamilies()`，装备 action 只更新 `_unownedEquipmentCategory`；移除不再使用的 trailing action 通道。

**技术栈：** Flutter、Dart、`gen-l10n`、`flutter_test`

---

## 文件结构

- 修改：`test/owned_inventory_page_test.dart`——验证按钮位置、图标样式、持续显示和点击行为。
- 修改：`lib/l10n/app_zh.arb`、`lib/l10n/app_zh_Hant.arb`、`lib/l10n/app_ja.arb`——增加“重置筛选”文案。
- 生成：`lib/l10n/app_localizations.dart`、`lib/l10n/app_localizations_zh.dart`、`lib/l10n/app_localizations_ja.dart`——生成新 getter。
- 修改：`lib/src/inventory/owned_inventory_page.dart`——接入两个前置图标 action，并删除尾部文字 action 通道。

### 任务 1：用组件测试锁定两个重置图标

**文件：**
- 修改：`test/owned_inventory_page_test.dart`

- [ ] **步骤 1：扩展未持有舰娘测试**

在首个未持有舰娘测试中增加：

```dart
final clearExclusions = find.byKey(
  const Key('unowned-ship-clear-exclusions'),
);
expect(clearExclusions, findsOneWidget);
expect(
  find.descendant(of: clearExclusions, matching: find.byIcon(Icons.restore)),
  findsOneWidget,
);
expect(find.text('清除排除'), findsNothing);
expect(
  tester.getTopLeft(clearExclusions).dx,
  lessThan(
    tester
        .getTopLeft(
          find.byKey(const Key('unowned-ship-filter-result-count')),
        )
        .dx,
  ),
);

await tester.tap(clearExclusions);
await tester.pump();
expect(reminderController.excludedFamilyIds, isEmpty);
expect(tester.widget<Text>(excludedCount).data, '0');
expect(clearExclusions, findsOneWidget);
```

- [ ] **步骤 2：扩展未持有装备测试**

在选择 `mainGun` 并验证数量后增加：

```dart
final resetEquipmentFilter = find.byKey(
  const Key('unowned-equipment-filter-reset'),
);
expect(resetEquipmentFilter, findsOneWidget);
expect(
  find.descendant(
    of: resetEquipmentFilter,
    matching: find.byIcon(Icons.restore),
  ),
  findsOneWidget,
);
expect(
  tester.getTopLeft(resetEquipmentFilter).dx,
  lessThan(
    tester
        .getTopLeft(
          find.byKey(const Key('unowned-equipment-filter-result-count')),
        )
        .dx,
  ),
);
await tester.tap(resetEquipmentFilter);
await tester.pump();
final allLabel = tester.widget<Text>(
  find.descendant(
    of: find.byKey(const Key('unowned-equipment-filter-all')),
    matching: find.text('全部'),
  ),
);
expect(allLabel.style?.color, const Color(0xffffcf62));
expect(
  tester
      .widget<Text>(
        find.byKey(const Key('unowned-equipment-filter-result-count')),
      )
      .data,
  '${unownedEquipmentRows.length}',
);
```

- [ ] **步骤 3：运行测试并确认红灯**

运行：`flutter test test/owned_inventory_page_test.dart --plain-name "unowned ship cards are flat and exclusions follow the active filter"`

预期：FAIL，因为旧按钮没有 `Icons.restore` 且位于筛选结果之后。

运行：`flutter test test/owned_inventory_page_test.dart --plain-name "unowned views reuse filters and remember each category"`

预期：FAIL，因为未持有装备还没有 `unowned-equipment-filter-reset`。

### 任务 2：接入前置图标 action

**文件：**
- 修改：`lib/l10n/app_zh.arb`
- 修改：`lib/l10n/app_zh_Hant.arb`
- 修改：`lib/l10n/app_ja.arb`
- 生成：`lib/l10n/app_localizations.dart`
- 生成：`lib/l10n/app_localizations_zh.dart`
- 生成：`lib/l10n/app_localizations_ja.dart`
- 修改：`lib/src/inventory/owned_inventory_page.dart`

- [ ] **步骤 1：增加三语“重置筛选”资源并生成代码**

分别加入：

```json
"resetFilter": "重置筛选"
```

```json
"resetFilter": "重設篩選"
```

```json
"resetFilter": "絞り込みをリセット"
```

运行：`flutter gen-l10n`

预期：生成类包含 `resetFilter` getter，命令退出码为 0。

- [ ] **步骤 2：把未持有舰娘 action 移到筛选结果前**

将原 trailing 参数替换为：

```dart
actionLabel: l10n.clearNewShipExclusions,
actionIcon: Icons.restore,
actionKey: const Key('unowned-ship-clear-exclusions'),
onAction: () => widget.reminderController?.clearExcludedFamilies(),
```

这些参数始终提供，因此无排除项时图标仍显示；当前舰种筛选不变。

- [ ] **步骤 3：为未持有装备增加恢复全部 action**

在装备 `_FilterStrip` 增加：

```dart
actionLabel: l10n.resetFilter,
actionIcon: Icons.restore,
actionKey: const Key('unowned-equipment-filter-reset'),
onAction: () => setState(() {
  _unownedEquipmentCategory = EquipmentInventoryCategory.all;
}),
```

- [ ] **步骤 4：删除尾部文字 action 通道**

从 `_FilterStrip` 构造函数、字段和 `build` 中删除：

```dart
trailingActionLabel
trailingActionKey
onTrailingAction
```

以及对应的尾部 `_FilterChip` 渲染分支。

- [ ] **步骤 5：运行两个定向测试并确认绿灯**

运行：`flutter test test/owned_inventory_page_test.dart --plain-name "unowned ship cards are flat and exclusions follow the active filter"`

运行：`flutter test test/owned_inventory_page_test.dart --plain-name "unowned views reuse filters and remember each category"`

预期：两个测试均 PASS。

- [ ] **步骤 6：提交功能变更**

```powershell
git add -- lib/src/inventory/owned_inventory_page.dart test/owned_inventory_page_test.dart lib/l10n/app_zh.arb lib/l10n/app_zh_Hant.arb lib/l10n/app_ja.arb lib/l10n/app_localizations.dart lib/l10n/app_localizations_zh.dart lib/l10n/app_localizations_ja.dart
git commit -m "feat(持有一览): 统一未持有列表重置图标"
```

### 任务 3：回归验证

**文件：**
- 验证：`lib/src/inventory/owned_inventory_page.dart`
- 验证：`test/owned_inventory_page_test.dart`
- 验证：`lib/l10n/*.arb`

- [ ] **步骤 1：运行持有一览和本地化测试**

运行：`flutter test test/owned_inventory_page_test.dart test/localization_contract_test.dart test/localization_resource_audit_test.dart --reporter compact`

预期：全部测试通过。

- [ ] **步骤 2：运行定向静态分析**

运行：`dart analyze lib/src/inventory/owned_inventory_page.dart test/owned_inventory_page_test.dart lib/l10n`

预期：输出 `No issues found!`。

- [ ] **步骤 3：运行完整测试集**

运行：`flutter test --reporter compact`

预期：退出码为 0；仓库既有跳过项允许保持跳过。

- [ ] **步骤 4：检查提交边界**

运行：`git status --short` 和 `git show --stat --oneline HEAD`。

预期：功能提交只包含持有一览、本地化和对应测试；现有舰队中心及 Android 并行修改仍未暂存。
