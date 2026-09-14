# 竖屏作业卡片与战果顶部栏溢出修复实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 消除竖屏下修理、建造卡片与战果顶部栏的布局溢出。

**架构：** 在共用 `_OperationCard` 的手机布局中以 `Expanded`、`Flexible` 和 `FittedBox` 分配真实剩余宽度；在 `WorkspaceContextHeader` 中让战果标签胶囊根据窄宽约束单独占行宽。宽屏结构保持不变。

**技术栈：** Flutter、Dart、flutter_test

---

### 任务 1：修理与建造卡片窄屏布局

**文件：**
- 修改：`lib/src/fleet/operation_status_views.dart:359-421`
- 测试：`test/repair_dock_status_view_test.dart`
- 测试：`test/fleet_information_center_test.dart`

- [ ] **步骤 1：编写失败的窄屏回归测试**

在 390×844、1.3 倍文字缩放下分别渲染修理和建造列表，断言 `tester.takeException()` 为 `null`，并断言卡片、身份与尾部内容均位于屏幕右边界内。

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/repair_dock_status_view_test.dart test/fleet_information_center_test.dart --plain-name "portrait operation cards stay within the viewport"`

预期：FAIL，捕获现有 RenderFlex 横向溢出。

- [ ] **步骤 3：实现最少响应式修改**

将手机布局首行改为：固定头像 + 弹性身份区 + 受限尾部区；尾部通过 `FittedBox(fit: BoxFit.scaleDown)` 在可用宽度内显示。正文仍位于第二行。

- [ ] **步骤 4：运行相关测试验证通过**

运行：`flutter test test/repair_dock_status_view_test.dart test/fleet_information_center_test.dart`

预期：PASS，且无 RenderFlex 异常。

### 任务 2：战果顶部标签窄屏布局

**文件：**
- 修改：`lib/src/layout/workspace_context_header.dart:344-362`
- 测试：`test/workspace_context_header_test.dart`

- [ ] **步骤 1：编写失败的窄屏回归测试**

以 390px 宽度渲染战果头部，断言标签胶囊左右边界位于头部内、三个标签均存在且没有布局异常。

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/workspace_context_header_test.dart --plain-name "senka header fits a portrait workspace"`

预期：FAIL，捕获固定 360px 胶囊与标题同行造成的溢出。

- [ ] **步骤 3：实现最少响应式修改**

使用 `LayoutBuilder` 检测窄宽；窄宽时仅以 `SizedBox(width: constraints.maxWidth)` 承载 `SenkaModeTabs`，宽屏沿用标题、间隔和固定宽标签胶囊。

- [ ] **步骤 4：运行头部测试验证通过**

运行：`flutter test test/workspace_context_header_test.dart`

预期：PASS。

### 任务 3：回归检查与真机热重载

**文件：**
- 检查：`lib/src/fleet/operation_status_views.dart`
- 检查：`lib/src/layout/workspace_context_header.dart`
- 检查：相关测试文件

- [ ] **步骤 1：运行完整相关测试**

运行：`flutter test test/repair_dock_status_view_test.dart test/fleet_information_center_test.dart test/workspace_context_header_test.dart test/senka_page_test.dart`

预期：全部通过。

- [ ] **步骤 2：运行静态检查**

运行：`flutter analyze lib/src/fleet/operation_status_views.dart lib/src/layout/workspace_context_header.dart test/repair_dock_status_view_test.dart test/fleet_information_center_test.dart test/workspace_context_header_test.dart`

预期：无新增错误或警告。

- [ ] **步骤 3：热重载并逐页检查**

向现有 `flutter run` 会话发送 `r`，随后在真机打开修理、建造和战果页面，确认不再出现黄黑 RenderFlex 溢出条。
