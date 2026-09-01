# 开发公式表格紧凑化实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 将开发公式配方表改为资源图标表头和紧凑内容宽度，并在已选目标装备标签中显示装备类型图标。

**架构：** 保留 `DevelopmentRecipeTable` 的 `DataTable`、排序和行点击逻辑，只调整布局层级、列顺序和密度参数。目标标签继续使用 `InputChip`，通过装备数据的 `iconId` 复用 `EquipmentTypeIconImage`。所有行为由现有开发页面 Widget 测试覆盖，不引入新状态或计算逻辑。

**技术栈：** Flutter、Dart、Material `DataTable`、Flutter Widget Test

---

## 文件结构

- 修改：`lib/src/development/development_recipe_table.dart` — 配方表布局、资源图标表头、列顺序和排序索引。
- 修改：`lib/src/development/equipment_development_page.dart` — 已选目标装备标签图标。
- 修改：`test/development/equipment_development_page_test.dart` — 紧凑表格和目标标签的回归测试。

### 任务 1：锁定配方表列顺序和密度

**文件：**
- 修改：`test/development/equipment_development_page_test.dart`
- 修改：`lib/src/development/development_recipe_table.dart`

- [ ] **步骤 1：编写失败的表格测试**

在选择目标并进入开发公式页后，取得 `development-recipe-table` 对应的 `DataTable`，增加以下断言：

```dart
final tableFinder = find.byKey(const Key('development-recipe-table'));
final table = tester.widget<DataTable>(tableFinder);

expect(table.headingRowHeight, 34);
expect(table.dataRowMinHeight, 44);
expect(table.dataRowMaxHeight, 44);
expect(table.horizontalMargin, 8);
expect(table.columnSpacing, 16);
expect(table.columns.length, 9);
expect(find.byKey(const Key('development-recipe-resource-0')), findsOneWidget);
expect(find.byKey(const Key('development-recipe-resource-1')), findsOneWidget);
expect(find.byKey(const Key('development-recipe-resource-2')), findsOneWidget);
expect(find.byKey(const Key('development-recipe-resource-3')), findsOneWidget);
expect(
  (table.columns.last.label as Text).data,
  AppLocalizations.of(tester.element(tableFinder))!.developmentPoolType,
);
```

再断言资源短文字不作为表头出现，并验证默认目标概率排序列索引为 `6`。

- [ ] **步骤 2：运行测试验证失败**

运行：

```powershell
flutter test test/development/equipment_development_page_test.dart --plain-name "selecting a target produces recipe rows that can be applied"
```

预期：FAIL；现有表格行高为 `46–54`、没有资源图标键、池类型不是最后一列。

- [ ] **步骤 3：实现紧凑表格**

在 `development_recipe_table.dart` 中：

1. 新增资源图标表头辅助组件：

```dart
class _ResourceHeader extends StatelessWidget {
  const _ResourceHeader({
    required this.index,
    required this.asset,
    required this.label,
  });

  final int index;
  final String asset;
  final String label;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: Semantics(
      label: label,
      image: true,
      child: Image.asset(
        asset,
        key: Key('development-recipe-resource-$index'),
        width: 20,
        height: 20,
      ),
    ),
  );
}
```

2. 为 `DataTable` 设置：

```dart
headingRowHeight: 34,
dataRowMinHeight: 44,
dataRowMaxHeight: 44,
horizontalMargin: 8,
columnSpacing: 16,
headingTextStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
dataTextStyle: const TextStyle(fontSize: 12),
```

3. 将列顺序改为秘书舰、4 个资源图标、总资源、出货率、失败率、池类型，并按相同顺序移动每行 `DataCell`。
4. 将 `_sortColumn` 映射改为：目标概率 `6`、总资源 `5`、失败率 `7`。
5. 将装饰容器移入横向 `SingleChildScrollView`，外层使用 `Align(alignment: Alignment.centerLeft)`，让边框随内容宽度收缩。

- [ ] **步骤 4：运行测试验证通过**

运行：

```powershell
flutter test test/development/equipment_development_page_test.dart --plain-name "selecting a target produces recipe rows that can be applied"
```

预期：PASS。

- [ ] **步骤 5：提交表格修改**

```powershell
git add lib/src/development/development_recipe_table.dart test/development/equipment_development_page_test.dart
git commit -m "style(装备开发): 紧凑化开发公式表格"
```

### 任务 2：为已选目标标签增加装备图标

**文件：**
- 修改：`test/development/equipment_development_page_test.dart`
- 修改：`lib/src/development/equipment_development_page.dart`

- [ ] **步骤 1：编写失败的目标标签测试**

在目标多选测试中选中装备后关闭对话框，增加以下断言：

```dart
final iconFinder = find.byKey(const Key('development-target-chip-icon-7'));
expect(iconFinder, findsOneWidget);
final icon = tester.widget<EquipmentTypeIconImage>(iconFinder);
expect(icon.iconId, 8);
expect(icon.width, 23);
expect(icon.height, 23);
```

继续点击标签删除按钮，保留现有「目标被移除」断言，证明图标没有改变删除行为。

- [ ] **步骤 2：运行测试验证失败**

运行：

```powershell
flutter test test/development/equipment_development_page_test.dart --plain-name "target dialog preserves multi-selection across types"
```

预期：FAIL；找不到 `development-target-chip-icon-7`。

- [ ] **步骤 3：实现目标标签图标**

在 `equipment_development_page.dart` 引入 `equipment_type_icon.dart`，并为每个 `InputChip` 增加：

```dart
avatar: EquipmentTypeIconImage(
  key: Key('development-target-chip-icon-$id'),
  iconId: controller.dataset!.equipment[id]!.iconId,
  width: 23,
  height: 23,
),
```

保留原有名称、`onDeleted` 和 `Wrap` 布局。

- [ ] **步骤 4：运行测试验证通过**

运行：

```powershell
flutter test test/development/equipment_development_page_test.dart --plain-name "target dialog preserves multi-selection across types"
```

预期：PASS。

- [ ] **步骤 5：提交标签修改**

```powershell
git add lib/src/development/equipment_development_page.dart test/development/equipment_development_page_test.dart
git commit -m "style(装备开发): 为目标标签补充装备图标"
```

### 任务 3：完整验证

**文件：**
- 验证：`lib/src/development/`
- 验证：`test/development/`

- [ ] **步骤 1：格式化并检查补丁**

```powershell
dart format lib/src/development test/development
git diff --check
```

预期：格式化完成，`git diff --check` 无错误。

- [ ] **步骤 2：运行装备开发完整测试**

```powershell
flutter test test/development
```

预期：全部测试通过，失败数为 `0`。

- [ ] **步骤 3：运行局部静态分析**

```powershell
dart analyze lib/src/development test/development
```

预期：输出 `No issues found!`。

- [ ] **步骤 4：检查提交和工作区**

```powershell
git status --short
git log -4 --oneline
```

预期：工作区干净，表格与标签修改均已提交到 `master`。
