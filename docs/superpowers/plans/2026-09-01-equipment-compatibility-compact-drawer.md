# 装备适配抽屉紧凑化实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 将装备适配抽屉改为紧凑、统一滚动的布局，并通过二级弹窗提供舰种筛选与舰娘搜索。

**架构：** `EquipmentCompatibilityProjection` 增加舰种条件，保持筛选逻辑可单测；`EquipmentCompatibilityDrawer` 使用单个 `CustomScrollView` 组织非固定头部、工具栏和惰性舰娘列表。搜索复用 `StandaloneTextInputDialog`，舰种筛选使用与远征选择器一致的自定义 `Dialog`。

**技术栈：** Flutter、Material、Dart、flutter_test

---

## 文件结构

- 修改 `lib/src/inventory/equipment_compatibility_projection.dart`：增加按舰种 ID 筛选能力。
- 修改 `lib/src/inventory/equipment_compatibility_drawer.dart`：精简头部、增加紧凑工具栏与二级弹窗、统一滚动、显示舰娘等级。
- 修改 `test/equipment_compatibility_projection_test.dart`：验证舰种筛选与其他条件组合。
- 修改 `test/owned_inventory_page_test.dart`：验证抽屉视觉契约、弹窗交互、滚动行为和等级文案。

### 任务 1：投影层支持舰种筛选

**文件：**
- 修改：`lib/src/inventory/equipment_compatibility_projection.dart`
- 测试：`test/equipment_compatibility_projection_test.dart`

- [ ] **步骤 1：编写失败的投影测试**

在现有投影 fixture 中调用：

```dart
final rows = projection.rows(
  equipmentMasterId: 201,
  shipTypeId: 2,
);
expect(rows, isNotEmpty);
expect(rows.every((row) => row.shipMaster.shipTypeId == 2), isTrue);
```

同时验证 `shipTypeId: null` 保留全部舰种，且舰种条件可与 `ownedOnly`、`query`、`filter` 组合。

- [ ] **步骤 2：运行测试验证失败**

运行：

```powershell
flutter test test/equipment_compatibility_projection_test.dart
```

预期：编译失败，提示 `rows` 没有命名参数 `shipTypeId`。

- [ ] **步骤 3：实现最少筛选逻辑**

为 `rows` 增加可空参数，并在现有过滤器中判断：

```dart
int? shipTypeId,
```

```dart
if (shipTypeId != null && row.shipMaster.shipTypeId != shipTypeId) {
  return false;
}
```

- [ ] **步骤 4：运行测试验证通过**

运行：

```powershell
flutter test test/equipment_compatibility_projection_test.dart
```

预期：全部通过。

- [ ] **步骤 5：提交**

```powershell
git add lib/src/inventory/equipment_compatibility_projection.dart test/equipment_compatibility_projection_test.dart
git commit -m "feat(装备): 支持按舰种筛选适配结果"
```

### 任务 2：建立紧凑工具栏和二级弹窗契约

**文件：**
- 修改：`lib/src/inventory/equipment_compatibility_drawer.dart`
- 测试：`test/owned_inventory_page_test.dart`

- [ ] **步骤 1：编写失败的 Widget 测试**

打开装备抽屉后断言旧头部文案和常驻输入框消失，新按钮存在：

```dart
expect(find.text('装备 ID 201'), findsNothing);
expect(find.text('分类：主炮'), findsNothing);
expect(find.text('持有数 2'), findsNothing);
expect(find.text('普通槽 3'), findsNothing);
expect(find.text('增设栏 1'), findsNothing);
expect(find.text('规则来源：游戏官方主数据'), findsNothing);
expect(find.byKey(const Key('equipment-compatibility-search')), findsNothing);
expect(find.byKey(const Key('equipment-compatibility-ship-type-button')), findsOneWidget);
expect(find.byKey(const Key('equipment-compatibility-search-button')), findsOneWidget);
```

点击舰种按钮后断言 `equipment-compatibility-ship-type-dialog` 出现；选择一个舰种后断言弹窗关闭、列表只保留该舰种。点击搜索按钮后断言 `equipment-compatibility-search-dialog` 和输入框出现；分别覆盖取消、确定和清空搜索词。

- [ ] **步骤 2：运行测试验证失败**

运行：

```powershell
flutter test test/owned_inventory_page_test.dart --plain-name "compatibility drawer"
```

预期：新按钮和二级弹窗尚不存在，测试失败。

- [ ] **步骤 3：实现紧凑工具栏**

删除 `_Header` 的统计参数与统计文案，只保留装备图标、名称和关闭按钮。在 State 中增加：

```dart
int? _shipTypeId;
```

将工具区改为一行：

```dart
Row(
  children: [
    IconButton(
      key: const Key('equipment-compatibility-ship-type-button'),
      onPressed: () => _selectShipType(allRows),
      icon: const Icon(Icons.filter_alt_outlined),
    ),
    IconButton(
      key: const Key('equipment-compatibility-search-button'),
      onPressed: _editQuery,
      icon: const Icon(Icons.search),
    ),
    const SizedBox(width: 6),
    Expanded(child: _ScopeTabs(...)),
  ],
)
```

将 `_shipTypeId` 传入投影查询。按钮在条件生效时使用选中色和填充背景。

- [ ] **步骤 4：实现二级弹窗**

搜索使用已有组件：

```dart
final value = await showDialog<String>(
  context: context,
  builder: (_) => StandaloneTextInputDialog(
    key: const Key('equipment-compatibility-search-dialog'),
    title: l10n.equipmentCompatibilitySearchHint,
    label: l10n.equipmentCompatibilitySearchHint,
    initialValue: _query,
    fieldKey: const Key('equipment-compatibility-search-dialog-field'),
    cancelKey: const Key('equipment-compatibility-search-dialog-cancel'),
    confirmKey: const Key('equipment-compatibility-search-dialog-confirm'),
    cancelLabel: l10n.cancel,
    confirmLabel: l10n.confirm,
  ),
);
```

舰种使用自定义 `Dialog`，标题为 `l10n.shipType`，内容从 `allRows` 提取实际存在的 `shipTypeId`，以 `FilterChip` 展示「全部」和各舰种。点击选项后 `Navigator.pop<int?>`，返回后更新 `_shipTypeId`。

- [ ] **步骤 5：运行测试验证通过**

运行：

```powershell
flutter test test/owned_inventory_page_test.dart --plain-name "compatibility drawer"
```

预期：全部通过。

- [ ] **步骤 6：提交**

```powershell
git add lib/src/inventory/equipment_compatibility_drawer.dart test/owned_inventory_page_test.dart
git commit -m "feat(装备): 使用二级窗口筛选适配舰娘"
```

### 任务 3：统一滚动并用等级替代舰级 ID

**文件：**
- 修改：`lib/src/inventory/equipment_compatibility_drawer.dart`
- 测试：`test/owned_inventory_page_test.dart`

- [ ] **步骤 1：编写失败的滚动和文案测试**

在较矮窗口打开抽屉，断言只有一个主滚动组件，并验证滚动后头部位置上移：

```dart
final scroll = find.byKey(const Key('equipment-compatibility-scroll'));
expect(scroll, findsOneWidget);
final titleBefore = tester.getTopLeft(find.text('12.7cm 连装炮').last).dy;
await tester.drag(scroll, const Offset(0, -300));
await tester.pumpAndSettle();
final titleAfter = tester.getTopLeft(find.text('12.7cm 连装炮').last).dy;
expect(titleAfter, lessThan(titleBefore));
```

验证等级文案：

```dart
expect(find.textContaining('舰级 #'), findsNothing);
expect(find.textContaining('驱逐舰 · Lv.'), findsWidgets);
```

切换到「全部舰娘」后，未持有行只显示舰种，不显示伪造等级。

- [ ] **步骤 2：运行测试验证失败**

运行：

```powershell
flutter test test/owned_inventory_page_test.dart --plain-name "compatibility drawer"
```

预期：找不到统一滚动组件，且仍显示「舰级 #34」。

- [ ] **步骤 3：实现单一 `CustomScrollView`**

将抽屉内部 `Column + Expanded(ListView)` 改为：

```dart
CustomScrollView(
  key: const Key('equipment-compatibility-scroll'),
  slivers: [
    SliverToBoxAdapter(child: _Header(...)),
    SliverToBoxAdapter(child: _CompactControls(...)),
    if (!hasRules) const SliverFillRemaining(child: _RulesWaiting())
    else if (rows.isEmpty) SliverFillRemaining(child: _EmptyResult(...))
    else _CompatibilityList(state: widget.state, rows: rows),
  ],
)
```

将 `_CompatibilityList` 改为返回 `SliverList.builder`，生成舰种标题和舰娘行，不使用嵌套滚动视图。头部和工具栏不得使用 `SliverPersistentHeader`。

- [ ] **步骤 4：重排舰娘信息**

将舰娘元信息组合为：

```dart
final shipMeta = row.ownedShips.isEmpty
    ? row.shipTypeName
    : '${row.shipTypeName} · ${l10n.equipmentCompatibilityOwnedLevels(
        row.ownedShips.map((ship) => ship.level).join(' / '),
      )}';
```

第一条元信息只显示 `shipMeta`；下一行仅在有舰队归属时显示 `fleetText`。删除 `equipmentCompatibilityShipClassId` 的使用。

- [ ] **步骤 5：运行测试验证通过**

运行：

```powershell
flutter test test/owned_inventory_page_test.dart --plain-name "compatibility drawer"
```

预期：全部通过，窄屏无溢出。

- [ ] **步骤 6：提交**

```powershell
git add lib/src/inventory/equipment_compatibility_drawer.dart test/owned_inventory_page_test.dart
git commit -m "refactor(装备): 统一滚动适配抽屉"
```

### 任务 4：回归验证和 Debug APK

**文件：**
- 验证：`lib/src/inventory/equipment_compatibility_drawer.dart`
- 验证：`lib/src/inventory/equipment_compatibility_projection.dart`
- 验证：`test/equipment_compatibility_projection_test.dart`
- 验证：`test/owned_inventory_page_test.dart`

- [ ] **步骤 1：格式化并检查差异**

```powershell
dart format lib/src/inventory/equipment_compatibility_drawer.dart lib/src/inventory/equipment_compatibility_projection.dart test/equipment_compatibility_projection_test.dart test/owned_inventory_page_test.dart
git diff --check
```

预期：无格式错误和空白错误。

- [ ] **步骤 2：运行聚焦测试与静态分析**

```powershell
flutter test test/equipment_compatibility_projection_test.dart test/owned_inventory_page_test.dart
flutter analyze lib/src/inventory/equipment_compatibility_drawer.dart lib/src/inventory/equipment_compatibility_projection.dart
```

预期：测试全部通过，静态分析显示 `No issues found!`。

- [ ] **步骤 3：运行全量测试**

```powershell
flutter test
```

预期：全部测试通过，仅保留仓库既有跳过项。

- [ ] **步骤 4：构建并校验 Debug APK**

```powershell
New-Item -ItemType Directory -Force -Path 'C:\jtmp' | Out-Null
$env:TEMP='C:\jtmp'
$env:TMP='C:\jtmp'
flutter build apk --debug
Get-FileHash -Algorithm SHA256 build/app/outputs/flutter-apk/app-debug.apk
```

预期：生成 `build/app/outputs/flutter-apk/app-debug.apk`，命令返回 SHA-256。

- [ ] **步骤 5：确认工作区状态**

```powershell
git status --short
git log -1 --oneline
```

预期：工作区干净，最新提交位于 `master`。
