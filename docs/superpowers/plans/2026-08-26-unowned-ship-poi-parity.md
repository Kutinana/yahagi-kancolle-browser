# 未持有舰娘 POI 对齐实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 修正可逆改造循环导致的未持有舰娘重复计数，并把未持有舰娘页精简为顶部统计加平铺卡片。

**架构：** `UnownedInventoryProjection` 改用与 POI 相同的“从初始舰向后遍历”家族索引，所有未持有判定继续依赖统一的 `familyRootOf`。页面复用 `_FilterStrip`，增加可选的第二统计值和末尾动作；舰娘列表直接滚动平铺，装备分组保持不变。

**技术栈：** Dart、Flutter、flutter_test、ARB 本地化、Git

---

## 文件结构

- 修改：`lib/src/inventory/unowned_inventory_projection.dart`——构建 POI 兼容的改造家族根索引。
- 修改：`lib/src/inventory/owned_inventory_page.dart`——顶部排除统计和平铺舰娘卡片。
- 修改：`lib/l10n/app_zh.arb`、`lib/l10n/app_zh_Hant.arb`、`lib/l10n/app_ja.arb`——增加独立“已排除”标签。
- 生成：`lib/l10n/app_localizations.dart`、`lib/l10n/app_localizations_zh.dart`、`lib/l10n/app_localizations_ja.dart`——同步本地化接口。
- 修改：`test/unowned_inventory_projection_test.dart`——覆盖入口循环、纯循环和非玩家舰。
- 修改：`test/owned_inventory_page_test.dart`——覆盖顶部统计和平铺布局。

### 任务 1：按 POI 规则归并改造家族

**文件：**
- 修改：`test/unowned_inventory_projection_test.dart`
- 修改：`lib/src/inventory/unowned_inventory_projection.dart`

- [ ] **步骤 1：编写失败的投影测试**

构造 `5 -> 6 -> 7 -> 6`，断言三个形态的根均为 `5`；构造独立 `8 -> 9 -> 8`，断言两个形态的根均为升序首项 `8`；加入 ID `1501` 且 `sortNo > 0` 的舰娘，断言未持有列表不包含它：

```dart
expect(projection.familyRootOf(5), 5);
expect(projection.familyRootOf(6), 5);
expect(projection.familyRootOf(7), 5);
expect(projection.familyRootOf(8), 8);
expect(projection.familyRootOf(9), 8);
expect(
  projection.unownedShipFamilies.map((row) => row.master.id),
  isNot(contains(1501)),
);
```

- [ ] **步骤 2：运行测试并确认红灯**

运行：

```powershell
flutter test test/unowned_inventory_projection_test.dart
```

预期：FAIL，旧实现把循环形态 `6`、`7` 或 `8`、`9` 作为不同根。

- [ ] **步骤 3：实现 POI 兼容家族索引**

用 `_buildFamilyRoots` 取代 `_buildPredecessors`：

```dart
static Map<int, int> _buildFamilyRoots(GameState state) {
  final validIds = state.masterShips.keys.where((id) => id <= 1500).toList();
  final afterIds = <int>{
    for (final id in validIds)
      if (state.masterShips[id]!.afterShipId > 0)
        state.masterShips[id]!.afterShipId,
  };
  final roots = validIds.where((id) => !afterIds.contains(id)).toList()..sort();
  final chains = <int, List<int>>{};
  List<int> trace(int root) {
    final result = <int>[];
    final visited = <int>{};
    var current = root;
    while (visited.add(current)) {
      result.add(current);
      final next = state.masterShips[current]?.afterShipId ?? 0;
      if (next <= 0) break;
      current = next;
    }
    return result;
  }
  for (final root in roots) chains[root] = trace(root);
  final covered = chains.values.expand((chain) => chain).toSet();
  final missing = validIds.where((id) => !covered.contains(id)).toList()..sort();
  while (missing.isNotEmpty) {
    final root = missing.first;
    final chain = trace(root);
    chains[root] = chain;
    missing.removeWhere(chain.toSet().contains);
  }
  return <int, int>{
    for (final entry in chains.entries)
      for (final id in entry.value) id: entry.key,
  };
}
```

生产实现需要保留 POI 的数字根顺序覆盖行为，并让 `unownedShipFamilies` 只遍历家族根对应的玩家舰。

- [ ] **步骤 4：运行投影测试并确认绿灯**

运行：

```powershell
flutter test test/unowned_inventory_projection_test.dart
```

预期：全部通过。

- [ ] **步骤 5：提交家族归并修复**

```powershell
git add lib/src/inventory/unowned_inventory_projection.dart test/unowned_inventory_projection_test.dart
git commit -m "fix(持有一览): 对齐 POI 未持有舰娘家族口径"
```

### 任务 2：精简未持有舰娘界面

**文件：**
- 修改：`test/owned_inventory_page_test.dart`
- 修改：`lib/src/inventory/owned_inventory_page.dart`
- 修改：`lib/l10n/app_zh.arb`
- 修改：`lib/l10n/app_zh_Hant.arb`
- 修改：`lib/l10n/app_ja.arb`
- 生成：`lib/l10n/app_localizations.dart`
- 生成：`lib/l10n/app_localizations_zh.dart`
- 生成：`lib/l10n/app_localizations_ja.dart`

- [ ] **步骤 1：编写失败的页面测试**

页面选择 DD 并排除一艘后，验证：

```dart
expect(find.byKey(const Key('unowned-ship-summary')), findsNothing);
expect(find.byType(ExpansionTile), findsNothing);
expect(find.byKey(const Key('unowned-ship-excluded-count')), findsOneWidget);
expect(
  tester.widget<Text>(
    find.byKey(const Key('unowned-ship-excluded-count')),
  ).style?.color,
  const Color(0xffffc85a),
);
```

同时验证切到非 DD 分类时排除数变为当前分类与排除集合的交集，而装备页仍保留 `ExpansionTile`。

- [ ] **步骤 2：运行页面测试并确认红灯**

运行：

```powershell
flutter test test/owned_inventory_page_test.dart --plain-name "unowned ship cards are flat and exclusions follow the active filter"
```

预期：FAIL，旧页面仍显示摘要和舰种折叠标题，筛选条也没有排除统计。

- [ ] **步骤 3：增加本地化标签**

增加键 `unownedShipExcludedLabel`：

```json
// app_zh.arb
"unownedShipExcludedLabel": "已排除"

// app_zh_Hant.arb
"unownedShipExcludedLabel": "已排除"

// app_ja.arb
"unownedShipExcludedLabel": "除外済み"
```

运行：

```powershell
flutter gen-l10n
```

- [ ] **步骤 4：扩展筛选条并平铺舰娘卡片**

为 `_FilterStrip` 增加可选的第二统计标签、数值、数值 Key 和末尾动作。页面计算当前筛选排除数：

```dart
final filteredExcludedCount = unownedShipRows
    .where((row) => excludedFamilyIds.contains(row.familyRootId))
    .length;
```

删除 `_UnownedShipsView` 的摘要 `Padding` 和舰种分组 Map，改为：

```dart
Expanded(
  child: SingleChildScrollView(
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final row in rows) _UnownedShipCard(...),
      ],
    ),
  ),
)
```

未持有装备继续使用 `_UnownedGroup`。

- [ ] **步骤 5：运行页面与本地化测试并确认绿灯**

运行：

```powershell
flutter test test/owned_inventory_page_test.dart test/unowned_inventory_view_test.dart test/inventory_quest_localization_test.dart test/localization_contract_test.dart
```

预期：全部通过。

- [ ] **步骤 6：提交界面精简**

仅暂存本任务实际修改；若本地化文件包含其他任务的未提交改动，使用精确暂存确保不带入无关内容：

```powershell
git add lib/src/inventory/owned_inventory_page.dart test/owned_inventory_page_test.dart
git add lib/l10n/app_zh.arb lib/l10n/app_zh_Hant.arb lib/l10n/app_ja.arb lib/l10n/app_localizations.dart lib/l10n/app_localizations_zh.dart lib/l10n/app_localizations_ja.dart
git commit -m "feat(持有一览): 精简未持有舰娘列表统计"
```

### 任务 3：完整验证与审计

**文件：**
- 验证：本计划涉及的全部生产与测试文件

- [ ] **步骤 1：格式与定向静态分析**

```powershell
dart format lib/src/inventory/unowned_inventory_projection.dart lib/src/inventory/owned_inventory_page.dart test/unowned_inventory_projection_test.dart test/owned_inventory_page_test.dart
dart analyze lib/src/inventory/unowned_inventory_projection.dart lib/src/inventory/owned_inventory_page.dart test/unowned_inventory_projection_test.dart test/owned_inventory_page_test.dart
```

预期：`No issues found!`

- [ ] **步骤 2：完整 Flutter 回归**

```powershell
flutter test --reporter compact
```

预期：所有非跳过测试通过。

- [ ] **步骤 3：工作区与提交审计**

```powershell
git diff --check
git status --short
git log -5 --oneline
```

预期：本任务文件无未提交改动；其他任务原有改动保持不变且未被本任务提交。
