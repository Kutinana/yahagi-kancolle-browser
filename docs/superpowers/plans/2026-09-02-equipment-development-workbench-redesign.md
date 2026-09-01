# 装备开发工作台重构实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 将装备开发页改成「开发工作台」，分离开发计算器与开发公式，并以二级秘书舰选择器和可排序表格呈现结果。

**架构：** 保留 `EquipmentDevelopmentController` 和全部计算核心，以独立 Widget 承担秘书舰选择、正向结果投影和公式表渲染。页面 Stateful State 只持有工作台模式；目标、资源、秘书舰池与公式排序继续由控制器共享。

**技术栈：** Flutter、Dart、Material、Flutter Widget Test、ARB 本地化

---

## 文件结构

- 创建 `lib/src/development/development_secretary_picker.dart`：开发池分组和双栏秘书舰选择对话框。
- 创建 `lib/src/development/development_output_table.dart`：可见正向结果、目标置顶与最终概率排序。
- 修改 `lib/src/development/development_recipe_table.dart`：将配方卡片改成 9 列可排序表格。
- 修改 `lib/src/development/equipment_development_page.dart`：开发工作台标题、模式切换、资源图标输入和模式主体。
- 修改 `lib/l10n/app_zh.arb`、`app_zh_Hant.arb`、`app_ja.arb`：工作台、模式、表格和选择器文案。
- 修改 `test/development/equipment_development_page_test.dart`：工作台集成与交互测试。
- 创建 `test/development/development_output_table_test.dart`：正向结果排序和过滤测试。
- 创建 `test/development/development_secretary_picker_test.dart`：二级菜单分组和选择测试。

### 任务 1：正向结果表格

**文件：**
- 创建：`lib/src/development/development_output_table.dart`
- 创建：`test/development/development_output_table_test.dart`

- [ ] **步骤 1：编写失败的排序测试**

创建测试夹具，断言 `visibleDevelopmentOutput` 排除 `totalRate <= 0` 和资源不足装备，将目标装备置顶，并默认按概率降序：

```dart
final output = visibleDevelopmentOutput(
  groups: groups,
  targets: const {7},
  ascending: false,
);
expect(output.map((item) => item.id), [7, 8, 9]);
```

再断言 `ascending: true` 时目标仍在第一项，非目标从低到高。

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/development/development_output_table_test.dart`

预期：FAIL，提示 `development_output_table.dart` 或 `visibleDevelopmentOutput` 不存在。

- [ ] **步骤 3：实现最小投影和表格**

实现：

```dart
List<DevelopmentEquipmentProjection> visibleDevelopmentOutput({
  required DevelopmentEquipmentGroups groups,
  required Set<int> targets,
  required bool ascending,
}) {
  final items = [...groups.targets, ...groups.other];
  items.sort((left, right) {
    final targetOrder = (targets.contains(right.id) ? 1 : 0) -
        (targets.contains(left.id) ? 1 : 0);
    if (targetOrder != 0) return targetOrder;
    final rate = left.totalRate.compareTo(right.totalRate);
    if (rate != 0) return ascending ? rate : -rate;
    return left.id.compareTo(right.id);
  });
  return List.unmodifiable(items);
}
```

`DevelopmentOutputTable` 使用装备图标、名称、目标标记、类型和最终概率列；点击概率表头切换内部 `ascending` 状态。资源不足和抵消装备不传入表格。

- [ ] **步骤 4：运行测试验证通过**

运行：`flutter test test/development/development_output_table_test.dart`

预期：全部通过。

- [ ] **步骤 5：提交**

```powershell
git add lib/src/development/development_output_table.dart test/development/development_output_table_test.dart
git commit -m "feat(装备开发): 添加最终概率排序表"
```

### 任务 2：秘书舰二级选择器

**文件：**
- 创建：`lib/src/development/development_secretary_picker.dart`
- 创建：`test/development/development_secretary_picker_test.dart`

- [ ] **步骤 1：编写失败的分组和交互测试**

测试 `groupDevelopmentSecretaryPools` 将「炮战系-金刚级」「炮战系-内华达级」「空母系-赤城」分成两个有序大类。Widget 测试点击选择器、切换「炮战系」并选择「内华达级」，断言回调收到对应 `pool.key` 且对话框关闭。

```dart
expect(groups.map((group) => group.label), ['炮战系', '空母系']);
expect(groups.first.pools.map((pool) => pool.key), ['kongo#1', 'nevada#1']);
```

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/development/development_secretary_picker_test.dart`

预期：FAIL，提示选择器 API 不存在。

- [ ] **步骤 3：实现分组与双栏对话框**

按当前 Locale 的池标签，以首个 `-` 或 `－` 分割大类与具体名称；没有分隔符的项目归入「其他」。实现 `DevelopmentSecretaryPicker` 和 `_DevelopmentSecretaryPickerDialog`：左栏切换分类，右栏选择池并 `Navigator.pop(pool.key)`。

关键 Key：

```dart
const Key('development-secretary-picker');
const Key('development-secretary-picker-dialog');
Key('development-secretary-group-$index');
Key('development-secretary-option-${pool.key}');
```

- [ ] **步骤 4：运行测试验证通过**

运行：`flutter test test/development/development_secretary_picker_test.dart`

预期：全部通过。

- [ ] **步骤 5：提交**

```powershell
git add lib/src/development/development_secretary_picker.dart test/development/development_secretary_picker_test.dart
git commit -m "feat(装备开发): 添加秘书舰二级选择器"
```

### 任务 3：开发工作台与模式切换

**文件：**
- 修改：`lib/src/development/equipment_development_page.dart`
- 修改：`lib/l10n/app_zh.arb`
- 修改：`lib/l10n/app_zh_Hant.arb`
- 修改：`lib/l10n/app_ja.arb`
- 修改：`test/development/equipment_development_page_test.dart`

- [ ] **步骤 1：编写失败的工作台 Widget 测试**

将首个页面测试改为断言：

```dart
expect(find.text('开发工作台'), findsOneWidget);
expect(find.byKey(const Key('development-mode-calculator')), findsOneWidget);
expect(find.byKey(const Key('development-mode-formula')), findsOneWidget);
expect(find.text('出货概率'), findsOneWidget);
expect(find.text('其他出货'), findsNothing);
expect(find.text('被替换出货'), findsNothing);
expect(find.byKey(const Key('development-minimum-7')), findsNothing);
```

新增测试点击「开发公式」后出现目标装备按钮和公式空状态，计算器资源输入退出 Widget 树；切回后资源状态不丢失。新增 4 个资源图片 Key 断言。

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/development/equipment_development_page_test.dart`

预期：FAIL，仍显示「开发指挥台」和旧双栏结果。

- [ ] **步骤 3：生成本地化接口**

在 3 份 ARB 中加入 `developmentWorkbenchTitle`、`developmentCalculator`、`developmentFormula`、`developmentOutputProbability`、`developmentFinalProbability`、`developmentAvailableRecipes`、`developmentPoolType` 和 `developmentSelectSecretary`，然后运行：

```powershell
flutter gen-l10n
```

- [ ] **步骤 4：实现工作台外壳**

在页面 State 增加：

```dart
enum _DevelopmentWorkbenchMode { calculator, formula }
var mode = _DevelopmentWorkbenchMode.calculator;
```

将标题和 `SegmentedButton` 放进同一顶栏。计算器模式组合 `DevelopmentSecretaryPicker`、当前旗舰、带 `assets/images/material/01.png` 至 `04.png` 前缀图标的资源输入、池类型和 `DevelopmentOutputTable`。公式模式组合目标装备按钮、已选目标标签和 `DevelopmentRecipeTable`。删除旧 `_OutcomePanel`、`_EquipmentGroup` 和宽屏双栏。

- [ ] **步骤 5：运行页面测试验证通过**

运行：`flutter test test/development/equipment_development_page_test.dart`

预期：全部通过，且没有 Dropdown 重复值断言或 RenderFlex 溢出。

- [ ] **步骤 6：提交**

```powershell
git add lib/src/development/equipment_development_page.dart lib/l10n test/development/equipment_development_page_test.dart
git commit -m "feat(装备开发): 重构开发工作台模式"
```

### 任务 4：可用公式数据表

**文件：**
- 修改：`lib/src/development/development_recipe_table.dart`
- 修改：`test/development/equipment_development_page_test.dart`

- [ ] **步骤 1：编写失败的公式表测试**

选择目标并切换公式模式，断言存在 9 个列标题和第一条配方行；点击行后资源与秘书舰池回填、行语义为选中，且仍停留在公式模式。

```dart
for (final header in ['秘书舰', '油', '弹', '钢', '铝', '总资源', '池类型', '出货率', '失败率']) {
  expect(find.text(header), findsOneWidget);
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/development/equipment_development_page_test.dart`

预期：FAIL，现有实现为卡片和排序胶囊，没有 9 列表头。

- [ ] **步骤 3：实现横向数据表**

用 `SingleChildScrollView(scrollDirection: Axis.horizontal)` 包裹 `DataTable`。`DataColumn` 的 `onSort` 调用现有 `controller.sortRecipes`；`DataRow` 点击时调用 `controller.applyRecipe`，并通过 `selected` 与背景色表示当前应用项。资源列使用数值，秘书舰列使用 `pool.label(locale)`，池类型使用本地化名称。

- [ ] **步骤 4：运行开发模块测试与静态分析**

运行：

```powershell
flutter test test/development
flutter analyze
```

预期：开发模块测试全部通过，静态分析无问题。

- [ ] **步骤 5：提交**

```powershell
git add lib/src/development/development_recipe_table.dart test/development/equipment_development_page_test.dart
git commit -m "feat(装备开发): 改造可用公式表格"
```

### 任务 5：回归验证与热重载

**文件：**
- 修改：仅在验证发现问题时修改对应文件与测试。

- [ ] **步骤 1：格式化和差异检查**

运行：

```powershell
dart format lib/src/development test/development
git diff --check
```

- [ ] **步骤 2：运行全量测试**

运行：`flutter test`

预期：全部测试通过；现有跳过项数量不增加。

- [ ] **步骤 3：运行最终静态分析**

运行：`flutter analyze`

预期：无错误和警告。

- [ ] **步骤 4：对当前设备执行热重载或 Hot Restart**

优先向现有 Flutter 会话发送热重载；若出现 Kernel isolate 拒绝，则执行 Hot Restart。不得运行 `flutter build apk`。

- [ ] **步骤 5：确认工作区与提交记录**

运行：

```powershell
git status --short
git log -6 --oneline
```

预期：工作区干净，计划内实现均已提交到 `master`。
