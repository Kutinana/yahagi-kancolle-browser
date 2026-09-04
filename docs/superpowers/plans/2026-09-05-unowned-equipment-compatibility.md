# 未持有装备适配入口实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 点击未持有装备卡片时复用现有右侧装备适配抽屉，并正确处理范围切换与装备持有状态变化。

**架构：** 由 `OwnedInventoryPage` 统一保存所选装备主数据 ID，并在持有/未持有装备内容之外渲染唯一的 `EquipmentCompatibilityDrawer`。未持有装备视图只负责把卡片点击回调上送；页面根据当前持有范围验证选中装备是否仍属于列表。

**技术栈：** Flutter、Dart、Flutter Widget Test。

---

## 文件结构

- 修改 `lib/src/inventory/owned_inventory_page.dart`：接通未持有装备点击、提升共用抽屉、完善选中装备生命周期。
- 修改 `test/owned_inventory_page_test.dart`：覆盖未持有装备打开、替换、关闭与状态变化。

### 任务 1：为未持有装备接入共用适配抽屉

**文件：**

- 修改：`lib/src/inventory/owned_inventory_page.dart`
- 测试：`test/owned_inventory_page_test.dart`

- [ ] **步骤 1：编写失败的 Widget 测试**

使用现有装备适配夹具打开「未持有 → 装备」，点击 `unowned-equipment-<masterId>`，断言：

```dart
expect(
  find.byKey(const Key('equipment-compatibility-drawer')),
  findsOneWidget,
);
expect(find.text(unownedEquipmentName), findsWidgets);
```

随后点击另一张未持有装备卡片，验证抽屉装备名称替换；点击关闭按钮后抽屉消失。重新打开后，把该装备实例加入控制器状态，验证它从未持有列表消失且抽屉自动关闭。最后切换到持有范围和舰娘页面，验证抽屉不会跨页面残留。

- [ ] **步骤 2：运行测试确认正确失败**

运行：

```powershell
flutter test test/owned_inventory_page_test.dart --plain-name "未持有装备复用装备适配抽屉"
```

预期：FAIL，因为未持有装备卡片尚无点击回调，找不到抽屉。

- [ ] **步骤 3：编写最少实现**

调整组件接口：

```dart
final int? selectedEquipmentMasterId;
final ValueChanged<int>? onEquipmentTap;
```

未持有装备卡片使用 `Material` 与 `InkWell`，点击时提交 `row.master.id`，并根据 `selectedEquipmentMasterId` 显示与持有表格一致的选中边框。

页面的装备内容统一包装为：

```dart
Stack(
  children: [
    Positioned.fill(child: equipmentContent),
    if (_selectedEquipmentMasterId case final masterId?)
      if (_state.masterSlotItems[masterId] case final equipment?)
        Positioned.fill(
          left: math.max(0, MediaQuery.sizeOf(context).width - 458),
          child: EquipmentCompatibilityDrawer(...),
        ),
  ],
)
```

选中项仍有效的条件为：装备主数据存在，并且在持有范围内有实例、在未持有范围内没有实例。切换持有范围或舰娘页面时清空选择。

- [ ] **步骤 4：运行目标测试和相关回归测试**

运行：

```powershell
flutter test test/owned_inventory_page_test.dart
```

预期：全部 PASS。

- [ ] **步骤 5：运行静态检查并提交**

```powershell
flutter analyze lib/src/inventory/owned_inventory_page.dart test/owned_inventory_page_test.dart
git diff --check
git add lib/src/inventory/owned_inventory_page.dart test/owned_inventory_page_test.dart
git commit -m "feat(装备): 支持查看未持有装备适配舰娘"
```

预期：静态分析无问题，差异检查无输出，只提交上述两个文件。

### 任务 2：完成验证

**文件：**

- 验证：`lib/src/inventory/owned_inventory_page.dart`
- 验证：`test/owned_inventory_page_test.dart`

- [ ] **步骤 1：运行装备适配相关测试**

```powershell
flutter test test/owned_inventory_page_test.dart test/equipment_compatibility_projection_test.dart test/equipment_compatibility_test.dart
```

预期：全部 PASS。

- [ ] **步骤 2：检查仓库状态**

```powershell
git status --short
git log -4 --oneline
```

预期：本次两个代码文件无未提交差异；用户原有的其他未提交文件保持不变。按用户要求不构建 Debug APK，不执行热重载。
