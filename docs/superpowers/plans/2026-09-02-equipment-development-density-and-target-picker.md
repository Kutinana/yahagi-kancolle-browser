# 装备开发表格密度与目标选择器优化实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 将出货概率表压缩到「持有」装备单行密度，简化资源输入，并把目标装备选择改成显示类型文字的双栏多选对话框。

**架构：** 保留 `EquipmentDevelopmentController` 的概率、兼容目标和搜索状态。表格只调整 Flutter `DataTable` 参数；资源输入只调整装饰与语义；目标选择器在现有文件内由底部面板改为 `Dialog`，用本地状态保存当前左栏类型，选择结果继续直接写入 Controller。

**技术栈：** Flutter、Dart、Material 3、flutter_test。

---

## 文件结构

- 修改 `lib/src/development/development_output_table.dart`：紧凑表头、行高、字号、图标和单元格间距。
- 修改 `lib/src/development/equipment_development_page.dart`：资源框移除可见文字，保留语义标签与图标。
- 修改 `lib/src/development/development_equipment_picker.dart`：目标装备双栏多选对话框、类型文字与无 ID 装备行。
- 修改 `lib/src/development/equipment_development_controller.dart`：提供按指定类型和搜索词过滤装备的稳定接口。
- 修改 `test/development/equipment_development_page_test.dart`：页面密度、资源输入和双栏选择集成测试。
- 修改 `test/development/equipment_development_controller_test.dart`：类型筛选与搜索组合的逻辑测试。

### 任务 1：压缩出货概率表

**文件：**
- 修改：`test/development/equipment_development_page_test.dart`
- 修改：`lib/src/development/development_output_table.dart`

- [ ] **步骤 1：编写失败的表格密度测试**

在工作台首个 Widget 测试中读取 `DataTable`，断言：

```dart
final table = tester.widget<DataTable>(find.byType(DataTable));
expect(table.headingRowHeight, 34);
expect(table.dataRowMinHeight, 44);
expect(table.dataRowMaxHeight, 44);

final equipmentName = tester.widget<Text>(find.text('测试舰攻'));
expect(equipmentName.style?.fontSize, 12);
expect(equipmentName.style?.fontWeight, FontWeight.w800);
```

通过 `development-output-icon-7` 的 Key 读取图标区域，并断言尺寸为 `25 × 25`。

- [ ] **步骤 2：运行测试验证失败**

运行：

```powershell
flutter test test/development/equipment_development_page_test.dart --plain-name "development workbench shows calculator table without old groups"
```

预期：FAIL，当前表头高度使用默认值，内容行高度为 `48–56`，名称没有 12 px 样式。

- [ ] **步骤 3：编写最少实现代码**

在 `DataTable` 上设置：

```dart
headingRowHeight: 34,
dataRowMinHeight: 44,
dataRowMaxHeight: 44,
horizontalMargin: 8,
columnSpacing: 24,
```

装备单元格使用 25 px 容器、23 px 图片、7 px 间距；名称设置 `fontSize: 12` 和 `FontWeight.w800`。类型设置 12 px / 700，概率保持 12 px / 900。表格的 `ConstrainedBox(minWidth: constraints.maxWidth)` 不变。

- [ ] **步骤 4：运行测试验证通过**

运行任务 1 的单项测试，预期 PASS。

- [ ] **步骤 5：提交任务 1**

```powershell
git add lib/src/development/development_output_table.dart test/development/equipment_development_page_test.dart
git commit -m "style(装备开发): 统一出货表格单行密度"
```

### 任务 2：简化资源输入

**文件：**
- 修改：`test/development/equipment_development_page_test.dart`
- 修改：`lib/src/development/equipment_development_page.dart`

- [ ] **步骤 1：编写失败的资源输入测试**

为 4 个输入分别断言可见装饰没有 `labelText`，但存在语义标签：

```dart
for (var index = 0; index < 4; index++) {
  final field = tester.widget<TextFormField>(
    find.byKey(Key('development-resource-$index')),
  );
  expect(field.decoration?.labelText, isNull);
  expect(
    find.byKey(Key('development-resource-semantics-$index')),
    findsOneWidget,
  );
}
```

- [ ] **步骤 2：运行测试验证失败**

运行首个工作台 Widget 测试，预期 FAIL，因为当前 `InputDecoration.labelText` 仍为资源名称，且没有语义 Key。

- [ ] **步骤 3：编写最少实现代码**

从 `InputDecoration` 删除 `labelText`，在 `TextFormField` 外包裹：

```dart
Semantics(
  key: Key('development-resource-semantics-${widget.index}'),
  label: widget.label,
  textField: true,
  child: Tooltip(message: widget.label, child: TextFormField(...)),
)
```

保持图标资产、输入宽度、数值范围、校验和即时提交逻辑不变。

- [ ] **步骤 4：运行测试验证通过**

运行 `equipment_development_page_test.dart`，预期全部 PASS。

- [ ] **步骤 5：提交任务 2**

```powershell
git add lib/src/development/equipment_development_page.dart test/development/equipment_development_page_test.dart
git commit -m "style(装备开发): 精简资源输入文字"
```

### 任务 3：目标装备双栏多选对话框

**文件：**
- 修改：`test/development/equipment_development_controller_test.dart`
- 修改：`test/development/equipment_development_page_test.dart`
- 修改：`lib/src/development/equipment_development_controller.dart`
- 修改：`lib/src/development/development_equipment_picker.dart`

- [ ] **步骤 1：编写失败的 Controller 过滤测试**

为控制器增加期望接口并测试类型与搜索组合：

```dart
controller.setEquipmentSearch('测试');
expect(
  controller.filteredEquipmentForType(1).map((item) => item.id),
  [7],
);
expect(controller.equipmentTypeName(1), '小口径主炮');
```

类型列表仍按 `typeId` 升序，缺失主数据的类型标签由 UI 统一映射到「其他」。

- [ ] **步骤 2：运行 Controller 测试验证失败**

运行：

```powershell
flutter test test/development/equipment_development_controller_test.dart
```

预期：FAIL，提示 `filteredEquipmentForType` 未定义。

- [ ] **步骤 3：实现最少 Controller 接口**

提取现有过滤逻辑：

```dart
List<DevelopmentEquipmentRecord> filteredEquipmentForType(int typeId) =>
    _filteredEquipment(typeId: typeId);
```

`filteredEquipment` 继续兼容现有调用，内部复用 `_filteredEquipment(typeId: _equipmentTypeFilter)`；搜索名称和精确 ID 的规则不变。

- [ ] **步骤 4：运行 Controller 测试验证通过**

运行 Controller 测试，预期全部 PASS。

- [ ] **步骤 5：编写失败的双栏 Widget 测试**

更新目标选择器测试，断言：

```dart
await tester.tap(find.byKey(const Key('development-open-target-picker')));
await tester.pumpAndSettle();

expect(find.byKey(const Key('development-target-dialog')), findsOneWidget);
expect(find.byKey(const Key('development-equipment-type-filter')), findsNothing);
expect(find.text('舰上攻击机'), findsOneWidget);
expect(find.text('#8'), findsNothing);
expect(find.textContaining('ID 7'), findsNothing);

await tester.tap(find.byKey(const Key('development-equipment-7')));
await tester.pumpAndSettle();
expect(find.byKey(const Key('development-target-dialog')), findsOneWidget);
expect(find.text('已选 1 件'), findsOneWidget);
```

再点击另一左栏类型，断言第一项仍选中；关闭对话框后公式页显示已选目标标签。

- [ ] **步骤 6：运行 Widget 测试验证失败**

运行：

```powershell
flutter test test/development/equipment_development_page_test.dart
```

预期：FAIL，当前实现仍为 `development-target-sheet`、类型下拉框和带 ID 副标题的底部卡片列表。

- [ ] **步骤 7：实现双栏多选对话框**

将 `showModalBottomSheet` 改为 `showDialog<void>`，新增 Stateful 对话框状态：

```dart
class _DevelopmentEquipmentPickerState
    extends State<_DevelopmentEquipmentPicker> {
  late int selectedTypeId = _initialTypeId();
}
```

布局与 `development_secretary_picker.dart` 一致：顶部 52 px 标题栏；左栏宽度为对话框的 30%，限制在 112–190 px；右栏 `ListView.separated`。左栏显示 `equipmentTypeName(typeId)`，缺失名称显示本地化「其他」。右栏装备项只显示 23 px 图标、名称和选择图标，不渲染 ID 或类型编号。

点击装备调用 `toggleTarget` 后不关闭；关闭按钮、遮罩和返回键只关闭对话框，不回滚已选择目标。搜索按钮继续打开现有独立搜索弹窗，搜索标签放在右栏顶部。

- [ ] **步骤 8：运行 Widget 测试验证通过**

运行 `equipment_development_page_test.dart`，预期全部 PASS。

- [ ] **步骤 9：提交任务 3**

```powershell
git add lib/src/development/development_equipment_picker.dart lib/src/development/equipment_development_controller.dart test/development/equipment_development_controller_test.dart test/development/equipment_development_page_test.dart
git commit -m "feat(装备开发): 改造目标装备双栏多选"
```

### 任务 4：回归验证与热重启

**文件：**
- 验证：`lib/src/development/`
- 验证：`test/development/`

- [ ] **步骤 1：格式化与差异检查**

```powershell
dart format lib/src/development test/development
git diff --check
```

预期：格式化成功，差异检查退出码为 0。

- [ ] **步骤 2：运行开发模块全部测试**

```powershell
flutter test test/development
```

预期：全部测试通过，失败数为 0。

- [ ] **步骤 3：运行静态分析**

```powershell
dart analyze lib/src/development test/development
```

预期：`No issues found!`。

- [ ] **步骤 4：热重启运行实例**

向现有 Flutter 会话发送 `R`。预期输出 `Restarted application`，之后 5 秒没有新的运行时异常。不构建 Debug APK。

- [ ] **步骤 5：确认工作区与提交历史**

```powershell
git status --short
git log -5 --oneline
```

预期：工作区为空，最近提交包含任务 1、任务 2、任务 3 和本计划文档。
