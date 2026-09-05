# 开发功能导航迁移实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 将现有装备开发工作台从工具箱迁移到建造单元，并形成“建造 → 开发 → 改修”的模式顺序。

**架构：** 扩展建造中心模式枚举和页面分发，让建造中心直接承载现有 `EquipmentDevelopmentPage`。工具箱收敛为舰队导出页面，开发功能内部实现不变。

**技术栈：** Flutter、Dart、flutter_test、gen-l10n

---

### 任务 1：用测试锁定导航归属与顺序

**文件：**
- 修改：`test/construction_improvement_integration_test.dart`
- 修改：`test/workspace_context_header_test.dart`
- 修改：`test/prototype_shell_test.dart`
- 修改：`test/toolbox_page_test.dart`

- [ ] **步骤 1：编写失败的测试**

断言建造模式键依次为 `construction`、`development`、`improvement`，点击 `development` 后渲染 `EquipmentDevelopmentPage`；同时断言工具箱没有开发切换入口。

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/construction_improvement_integration_test.dart test/workspace_context_header_test.dart test/toolbox_page_test.dart`

预期：因 `ConstructionCenterMode.development` 尚未实现而失败。

### 任务 2：迁移页面与精简工具箱

**文件：**
- 修改：`lib/src/improvement/improvement_planner_controller.dart`
- 修改：`lib/src/fleet/fleet_information_center.dart`
- 修改：`lib/src/layout/workspace_context_header.dart`
- 修改：`lib/src/toolbox/toolbox_page.dart`
- 修改：`lib/main.dart`
- 修改：`lib/l10n/app_zh.arb`
- 修改：`lib/l10n/app_zh_Hant.arb`
- 修改：`lib/l10n/app_ja.arb`
- 生成：`lib/l10n/app_localizations*.dart`

- [ ] **步骤 1：编写最少实现代码**

增加 `development` 模式；建造中心用现有仓库渲染 `EquipmentDevelopmentPage`；移除工具箱模式状态和切换；新增本地化键 `development`。

- [ ] **步骤 2：格式化并生成本地化代码**

运行：`flutter gen-l10n` 与 `dart format`（仅本次修改的 Dart 文件）。

- [ ] **步骤 3：运行测试验证通过**

运行：`flutter test test/construction_improvement_integration_test.dart test/workspace_context_header_test.dart test/toolbox_page_test.dart test/prototype_shell_test.dart`

预期：全部通过。

- [ ] **步骤 4：静态分析**

运行：`flutter analyze`

预期：无错误。

- [ ] **步骤 5：提交**

仅暂存本计划涉及的文件，提交信息：`refactor(建造): 将开发功能移入建造单元`。
