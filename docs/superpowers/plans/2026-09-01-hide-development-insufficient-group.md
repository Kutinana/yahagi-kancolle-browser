# 隐藏装备开发资源不足分组实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 从装备开发正向结果中移除「资源不足」可见分组，同时保持底层概率和失败率计算不变。

**架构：** 不修改 `development_projection.dart` 和配方计算，只调整 Flutter 页面投影。Widget 测试负责证明资源不足装备不再渲染，并确认其他三个分组仍正常显示。

**技术栈：** Dart 3、Flutter Material、`flutter_test`。

---

### 任务 1：移除资源不足可见分组

**文件：**

- 修改：`test/development/equipment_development_page_test.dart`
- 修改：`lib/src/development/equipment_development_page.dart`

- [ ] **步骤 1：编写失败的页面测试**

在页面夹具中加入一个最低资源高于当前 `10/10/10/10` 的装备，并断言页面不存在该装备对应的 `development-rate-details-*` 节点，同时断言目标、其他和替换分组逻辑不受影响。

- [ ] **步骤 2：运行测试验证失败**

运行：

```powershell
flutter test --no-test-assets test/development/equipment_development_page_test.dart
```

预期：FAIL，原因是页面仍渲染资源不足装备。

- [ ] **步骤 3：删除页面中的资源不足分组**

从 `_OutcomePanel` 的 `Column` 中删除：

```dart
_EquipmentGroup(
  title: l10n.developmentInsufficient,
  items: groups.insufficient,
  controller: controller,
  accent: const Color(0xffd59667),
),
```

不删除 `DevelopmentEquipmentGroups.insufficient`，也不修改 `evaluateDevelopmentRecipe`，确保不足门槛概率继续进入失败率。

- [ ] **步骤 4：运行页面与算法测试验证通过**

运行：

```powershell
flutter test --no-test-assets test/development/equipment_development_page_test.dart test/development/development_projection_test.dart test/development/development_recipe_calculator_test.dart
```

预期：全部 PASS。

- [ ] **步骤 5：提交**

```powershell
git add lib/src/development/equipment_development_page.dart test/development/equipment_development_page_test.dart docs/superpowers/plans/2026-09-01-hide-development-insufficient-group.md
git commit -m "fix(装备开发): 隐藏资源不足结果分组"
```
