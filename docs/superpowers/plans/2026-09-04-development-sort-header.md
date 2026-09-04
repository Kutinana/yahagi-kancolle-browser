# 装备开发排序表头统一实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 将装备开发排序表头统一为持有一览的黄色文字与后置三角符号。

**架构：** 在开发模块内增加一个小型排序标签组件，由两张表传入标题、是否激活和排序方向。DataTable 继续负责点击回调，组件只负责视觉展示。

**技术栈：** Flutter、Dart、Widget Test

---

### 任务 1：排序表头组件与两张表接入

**文件：**
- 修改：`lib/src/development/development_output_table.dart`
- 修改：`lib/src/development/development_recipe_table.dart`
- 测试：`test/development/equipment_development_page_test.dart`

- [ ] **步骤 1：编写失败的测试**

断言默认表头包含黄色 `最终概率 ▼`、`出货率 ▼`，点击后切换为 `▲`，公式切换排序列后仅新列带符号。

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/development/equipment_development_page_test.dart`

预期：因当前表头使用图标或 DataTable 默认箭头而失败。

- [ ] **步骤 3：编写最少实现代码**

新增开发模块内部排序标签，输出 `${label} ${ascending ? '▲' : '▼'}`，激活时使用黄色，未激活时只输出普通标题。关闭 DataTable 自带排序指示，避免重复箭头。

- [ ] **步骤 4：运行测试验证通过**

运行：`flutter test test/development/equipment_development_page_test.dart`

预期：全部通过。

- [ ] **步骤 5：验证与提交**

运行：`dart analyze lib/src/development test/development`、`flutter test test/development`、`git diff --check`。

提交：`fix(装备开发): 统一表格排序提示样式`

