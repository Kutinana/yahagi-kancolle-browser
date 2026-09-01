# 装备适配舰种筛选优化实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 让装备适配工具按钮与范围按钮视觉等高，并将舰种二级窗口改为更宽、与舰娘页一致的英文缩写分类筛选器。

**架构：** 复用 `owned_inventory_projection.dart` 中的 `ShipInventoryCategory` 和 `shipTypeMatchesInventoryCategory`，避免维护第二套舰种归类规则。抽屉保存舰种分类而非单个舰种 ID，投影层按分类匹配；弹窗固定展示舰娘页的十个分类。

**技术栈：** Flutter、Dart、Flutter Widget Test。

---

## 文件结构

- 修改 `lib/src/inventory/equipment_compatibility_projection.dart`：接受舰种分类并复用统一映射过滤结果。
- 修改 `lib/src/inventory/equipment_compatibility_drawer.dart`：保存分类状态、显示英文缩写、放宽弹窗并缩小按钮可见外框。
- 修改 `test/equipment_compatibility_projection_test.dart`：验证组合分类可同时命中多个舰种 ID。
- 修改 `test/owned_inventory_page_test.dart`：验证按钮视觉尺寸、弹窗宽度、英文分类与交互。

### 任务 1：投影层支持组合舰种分类

**文件：**

- 修改：`lib/src/inventory/equipment_compatibility_projection.dart`
- 测试：`test/equipment_compatibility_projection_test.dart`

- [ ] **步骤 1：编写失败的组合分类测试**

在夹具中加入分别属于战舰和航空战舰的可装备舰娘，并调用：

```dart
final rows = projection.rows(
  equipmentMasterId: 10,
  shipCategory: ShipInventoryCategory.bbBc,
);
expect(rows.map((row) => row.shipMaster.shipTypeId), containsAll(<int>[9, 10]));
```

- [ ] **步骤 2：运行测试并确认因参数尚不存在而失败**

运行：

```powershell
flutter test test/equipment_compatibility_projection_test.dart
```

预期：FAIL，提示 `shipCategory` 不是 `rows` 的命名参数。

- [ ] **步骤 3：实现最少分类过滤**

导入舰娘库存投影，并将单舰种参数替换为分类参数：

```dart
ShipInventoryCategory shipCategory = ShipInventoryCategory.all,
```

过滤条件使用：

```dart
if (!shipTypeMatchesInventoryCategory(
  row.shipMaster.shipTypeId,
  shipCategory,
)) {
  return false;
}
```

- [ ] **步骤 4：运行投影测试确认通过**

运行：

```powershell
flutter test test/equipment_compatibility_projection_test.dart
```

预期：PASS。

- [ ] **步骤 5：提交投影层变更**

```powershell
git add lib/src/inventory/equipment_compatibility_projection.dart test/equipment_compatibility_projection_test.dart
git commit -m "feat(装备): 支持组合舰种分类筛选"
```

### 任务 2：优化按钮和舰种二级窗口

**文件：**

- 修改：`lib/src/inventory/equipment_compatibility_drawer.dart`
- 测试：`test/owned_inventory_page_test.dart`

- [ ] **步骤 1：编写失败的 Widget 测试**

测试断言：

```dart
expect(
  tester.getSize(find.byKey(const Key('equipment-compatibility-tool-button-visual'))).height,
  32,
);
expect(tester.getSize(find.byKey(const Key('equipment-compatibility-ship-type-dialog'))).width, 480);
expect(find.text('BB/BC'), findsOneWidget);
expect(find.text('DD'), findsOneWidget);
expect(find.text('AV/AO/AS…'), findsOneWidget);
```

点击 `equipment-compatibility-ship-category-dd` 后，断言只保留驱逐舰行，并验证筛选按钮语义为已选中。

- [ ] **步骤 2：运行测试并确认因新尺寸、标签和 Key 尚不存在而失败**

运行：

```powershell
flutter test test/owned_inventory_page_test.dart --plain-name "装备适配抽屉"
```

预期：FAIL，找不到英文分类标签或新 Key，且弹窗仍为 360 宽。

- [ ] **步骤 3：实现最少界面改动**

- 将 `_shipTypeId` 改为 `_shipCategory`，默认 `ShipInventoryCategory.all`。
- `_ShipTypeDialog` 遍历 `ShipInventoryCategory.values`，标签与舰娘页一致。
- 将弹窗目标宽度改为 480，使用现有 `insetPadding` 保证窄屏不溢出。
- `_ToolButton` 保留 48 × 48 外层触控区，在中心绘制 32 × 32 可见按钮。
- 选择分类后立即关闭窗口并更新投影结果。

- [ ] **步骤 4：运行 Widget 测试确认通过**

运行：

```powershell
flutter test test/owned_inventory_page_test.dart --plain-name "装备适配抽屉"
```

预期：PASS。

- [ ] **步骤 5：提交界面变更**

```powershell
git add lib/src/inventory/equipment_compatibility_drawer.dart test/owned_inventory_page_test.dart
git commit -m "fix(装备): 缩小筛选按钮并改用舰种缩写"
```

### 任务 3：验证并热重载

**文件：**

- 验证：`lib/src/inventory/equipment_compatibility_drawer.dart`
- 验证：`lib/src/inventory/equipment_compatibility_projection.dart`
- 验证：`test/owned_inventory_page_test.dart`
- 验证：`test/equipment_compatibility_projection_test.dart`

- [ ] **步骤 1：运行相关测试**

```powershell
flutter test test/equipment_compatibility_projection_test.dart test/owned_inventory_page_test.dart
```

预期：PASS。

- [ ] **步骤 2：运行静态分析和差异检查**

```powershell
flutter analyze lib/src/inventory/equipment_compatibility_drawer.dart lib/src/inventory/equipment_compatibility_projection.dart
git diff --check
```

预期：`No issues found!`，且 `git diff --check` 无输出。

- [ ] **步骤 3：连接调试进程并热重载**

先检查当前终端和 Flutter 进程；存在可交互的 `flutter run` 会话时发送 `r`。若只有不可交互的孤立进程，则保持代码与测试结果，明确告知用户需要重新启动调试会话，不提前构建 Debug APK。

- [ ] **步骤 4：记录最终状态**

```powershell
git status --short
git log -5 --oneline
```

预期：工作区干净，最新提交包含本次投影与界面改动。
