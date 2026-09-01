# 装备开发自适应表格与状态缓存实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 让开发公式表格与出货概率卡片保持一致并填满宽屏，同时持久化装备开发工作台状态。

**架构：** `DevelopmentRecipeTable` 改为包含标题栏和自适应 `DataTable` 的完整卡片。新增可注入的 `DevelopmentWorkbenchStateStore`，Controller 在数据集加载后恢复缓存，并在状态变更后串行异步保存；生产使用 `SharedPreferences`，测试使用内存 Store。

**技术栈：** Flutter、Dart、Material `DataTable`、SharedPreferences、Flutter Widget Test

---

## 文件结构

- 创建：`lib/src/development/development_workbench_state_store.dart` — 状态模型、Store 接口和 SharedPreferences 实现。
- 修改：`lib/src/development/development_recipe_table.dart` — 卡片标题、自适应宽度和空状态。
- 修改：`lib/src/development/equipment_development_controller.dart` — 模式、恢复、校验和保存调度。
- 修改：`lib/src/development/equipment_development_page.dart` — Store 注入和 Controller 模式绑定。
- 创建：`test/development/development_workbench_state_store_test.dart` — JSON 与 SharedPreferences 往返测试。
- 修改：`test/development/equipment_development_page_test.dart` — 宽度、标题和页面重建恢复测试。

### 任务 1：修复表格卡片自适应

**文件：**
- 修改：`test/development/equipment_development_page_test.dart`
- 修改：`lib/src/development/development_recipe_table.dart`
- 修改：`lib/src/development/equipment_development_page.dart`

- [ ] **步骤 1：编写失败的布局测试**

将宽屏断言改为：

```dart
expect(
  tester.getSize(find.byKey(const Key('development-recipe-table-frame'))).width,
  tester.getSize(find.byKey(const Key('development-formula-body'))).width,
);
expect(
  find.descendant(
    of: find.byKey(const Key('development-recipe-table-frame')),
    matching: find.text('可用公式'),
  ),
  findsOneWidget,
);
expect(find.text('可用公式'), findsOneWidget);
```

保留 `390 px` 实际窗口的横向滚动断言。

- [ ] **步骤 2：运行测试验证失败**

```powershell
flutter test test/development/equipment_development_page_test.dart --plain-name "selecting a target produces recipe rows that can be applied"
```

预期：FAIL；卡片宽度小于公式内容区，标题位于卡片外。

- [ ] **步骤 3：实现卡片结构**

在 `DevelopmentRecipeTable` 中使用以下结构：

```dart
Container(
  key: const Key('development-recipe-table-frame'),
  width: double.infinity,
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(13, 11, 13, 9),
        child: Text(l10n.developmentAvailableRecipes),
      ),
      const Divider(height: 1),
      LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(...),
          ),
        ),
      ),
    ],
  ),
)
```

无目标和无结果状态也放在标题栏下方。删除 `_FormulaBody` 中独立的「可用公式」文字和间距。

- [ ] **步骤 4：运行页面测试验证通过**

```powershell
flutter test test/development/equipment_development_page_test.dart
```

预期：10 项页面测试全部通过。

- [ ] **步骤 5：提交布局修复**

```powershell
git add lib/src/development/development_recipe_table.dart lib/src/development/equipment_development_page.dart test/development/equipment_development_page_test.dart
git commit -m "fix(装备开发): 让公式表格自适应内容宽度"
```

### 任务 2：新增持久化状态 Store

**文件：**
- 创建：`lib/src/development/development_workbench_state_store.dart`
- 创建：`test/development/development_workbench_state_store_test.dart`

- [ ] **步骤 1：编写失败的 Store 测试**

覆盖完整状态 JSON 往返、损坏 JSON 返回 `null` 和 SharedPreferences 保存后读取：

```dart
final state = DevelopmentWorkbenchState(
  mode: DevelopmentWorkbenchMode.formula,
  selectedPoolKey: 'carrier-akagi#1',
  followsCurrentFlagship: false,
  resources: const DevelopmentResources(20, 30, 40, 50),
  targetIds: const [7, 8],
  recipeSort: DevelopmentRecipeSortField.totalResources,
  sortAscending: true,
);
expect(DevelopmentWorkbenchState.fromJson(state.toJson()), state);
```

- [ ] **步骤 2：运行测试验证失败**

```powershell
flutter test test/development/development_workbench_state_store_test.dart
```

预期：FAIL；状态类型和 Store 尚不存在。

- [ ] **步骤 3：实现状态模型和 Store**

状态对象包含模式、开发池、跟随旗舰、4 项资源、目标 ID 列表、排序字段和方向。SharedPreferences 使用键 `development_workbench_state_v1` 保存 `jsonEncode(state.toJson())`，解析异常返回 `null`，`setString` 返回 `false` 时抛出 `StateError`。

- [ ] **步骤 4：运行 Store 测试验证通过**

```powershell
flutter test test/development/development_workbench_state_store_test.dart
```

预期：全部通过。

- [ ] **步骤 5：提交 Store**

```powershell
git add lib/src/development/development_workbench_state_store.dart test/development/development_workbench_state_store_test.dart
git commit -m "feat(装备开发): 添加工作台状态缓存"
```

### 任务 3：接入 Controller 和页面恢复

**文件：**
- 修改：`lib/src/development/equipment_development_controller.dart`
- 修改：`lib/src/development/equipment_development_page.dart`
- 修改：`test/development/equipment_development_page_test.dart`

- [ ] **步骤 1：编写失败的页面重建测试**

使用同一个内存 Store：设置资源为 `20`，切换公式，选择目标 `7`，排序到总资源；卸载页面并重建后断言模式、目标、排序和资源全部恢复。

```dart
await tester.pumpWidget(const SizedBox.shrink());
await tester.pumpWidget(
  _app(size: const Size(1000, 700), stateStore: store),
);
await tester.pumpAndSettle();
expect(find.byKey(const Key('development-recipe-table')), findsOneWidget);
expect(find.text('测试舰攻'), findsOneWidget);
expect(
  tester.widget<DataTable>(find.byKey(const Key('development-recipe-table'))).sortColumnIndex,
  5,
);
```

- [ ] **步骤 2：运行测试验证失败**

```powershell
flutter test test/development/equipment_development_page_test.dart --plain-name "workbench state survives page recreation"
```

预期：FAIL；重建后回到计算器默认状态。

- [ ] **步骤 3：实现恢复与保存**

- Controller 构造函数接收可选 `DevelopmentWorkbenchStateStore`。
- `initialize` 在数据集可用后应用缓存并重算。
- 目标 ID 按缓存顺序重放，只恢复存在且当前允许的目标。
- 每次模式、目标、开发池、资源、配方应用和排序变化后，将快照加入串行保存链。
- 页面默认使用 `SharedPreferencesDevelopmentWorkbenchStateStore`，测试注入内存 Store。
- 页面模式改为读取 `controller.mode`，切换时调用 `controller.setMode`。

- [ ] **步骤 4：运行页面和 Controller 测试验证通过**

```powershell
flutter test test/development/equipment_development_page_test.dart test/development/equipment_development_controller_test.dart
```

预期：全部通过。

- [ ] **步骤 5：提交缓存接入**

```powershell
git add lib/src/development/equipment_development_controller.dart lib/src/development/equipment_development_page.dart test/development/equipment_development_page_test.dart
git commit -m "feat(装备开发): 恢复上次工作台状态"
```

### 任务 4：验证和 Debug 构建

- [ ] **步骤 1：格式化与补丁检查**

```powershell
dart format lib/src/development test/development
git diff --check
```

- [ ] **步骤 2：完整验证**

```powershell
flutter test test/development
dart analyze lib/src/development test/development
```

预期：全部测试通过，静态分析输出 `No issues found!`。

- [ ] **步骤 3：构建 Debug APK，不安装**

```powershell
$env:TEMP='C:\jtmp'
$env:TMP='C:\jtmp'
flutter build apk --debug
```

只生成 `build/app/outputs/flutter-apk/app-debug.apk`，禁止运行 `flutter install`、`adb install` 或启动应用。

- [ ] **步骤 4：校验产物和工作区**

```powershell
apksigner verify --verbose build/app/outputs/flutter-apk/app-debug.apk
Get-FileHash -Algorithm SHA256 build/app/outputs/flutter-apk/app-debug.apk
git status --short
```

预期：APK v2 签名验证通过，工作区干净。
