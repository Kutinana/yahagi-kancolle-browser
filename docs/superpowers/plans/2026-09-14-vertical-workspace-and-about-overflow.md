# 竖屏工作区与“关于”页溢出修复实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 让竖屏和展开折叠屏的游戏画面占满整行宽度，并消除“关于”页窄屏横向溢出。

**架构：** 游戏主页在垂直工作区中把导航栏从外层整高 `Row` 移入下方信息区，与信息面板共享相同的顶部、底部边界；横向工作区及其他页面维持原布局。“关于”头部用 `LayoutBuilder` 按可用宽度在横排与分行布局之间切换，复用同一组身份与按钮组件。

**技术栈：** Flutter、Dart、Widget tests、Android Flutter hot reload

---

## 文件结构

- 修改 `lib/main.dart`：计算垂直游戏工作区的导航位置与信息面板可用宽度。
- 修改 `test/prototype_shell_test.dart`：验证游戏、导航栏和信息面板的响应式几何关系。
- 修改 `lib/src/settings/about_dialog.dart`：实现“关于”头部窄屏分行布局。
- 修改 `test/about_dialog_test.dart`：复现截图宽度并验证无溢出且按钮可访问。

### 任务 1：竖屏游戏工作区导航对齐

**文件：**
- 修改：`test/prototype_shell_test.dart`
- 修改：`lib/main.dart`

- [ ] **步骤 1：编写失败的几何测试**

在现有游戏表面生命周期测试的 `700 x 900` 尺寸断言中加入：

```dart
final navigationRect = tester.getRect(find.byType(WorkspaceNavigation));
final panelRect = tester.getRect(informationPanel);
final gameRect = tester.getRect(gameSurface);
expect(gameRect.width, closeTo(700, 0.01));
expect(navigationRect.top, panelRect.top);
expect(navigationRect.bottom, panelRect.bottom);
expect(navigationRect.top, greaterThanOrEqualTo(gameRect.bottom));
```

- [ ] **步骤 2：运行测试并确认红灯**

运行：`flutter test test/prototype_shell_test.dart --plain-name "moves the workspace menu without disposing the game surface"`

预期：FAIL；当前游戏宽度被 58 像素导航栏扣减，且导航栏顶部仍位于游戏区域顶部。

- [ ] **步骤 3：实现垂直工作区布局**

在 `YahagiShell.build` 中仅对游戏主页的垂直工作区启用 `panelAlignedNavigation`。外层不再占用导航栏宽度；游戏保持全宽。信息面板宽度扣除 58 像素，并按 `workspaceMenuOnRight` 决定左右位置；同一个 `WorkspaceNavigation` 定位到信息区范围内。横向工作区和非游戏页面继续使用原整高导航栏。

- [ ] **步骤 4：运行测试并确认绿灯**

运行：`flutter test test/prototype_shell_test.dart --plain-name "moves the workspace menu without disposing the game surface"`

预期：PASS，且无 Flutter layout exception。

- [ ] **步骤 5：提交任务 1**

```powershell
git add -- lib/main.dart test/prototype_shell_test.dart
git commit -m "fix: 对齐竖屏导航栏与功能区"
```

### 任务 2：“关于”页窄屏头部换行

**文件：**
- 修改：`test/about_dialog_test.dart`
- 修改：`lib/src/settings/about_dialog.dart`

- [ ] **步骤 1：编写失败的窄屏测试**

增加 `320 x 700` 的 `AboutContentWidget` 测试，泵送页面后断言：

```dart
expect(tester.takeException(), isNull);
expect(find.textContaining('GitHub'), findsOneWidget);
expect(find.text('检查更新'), findsOneWidget);
final github = tester.getRect(find.textContaining('GitHub'));
final update = tester.getRect(find.text('检查更新'));
expect(github.right, lessThanOrEqualTo(320));
expect(update.right, lessThanOrEqualTo(320));
```

- [ ] **步骤 2：运行测试并确认红灯**

运行：`flutter test test/about_dialog_test.dart --plain-name "about header wraps actions on a narrow viewport"`

预期：FAIL，并捕获当前 `RenderFlex overflowed` 异常。

- [ ] **步骤 3：实现响应式头部**

用 `LayoutBuilder` 读取卡片宽度。可用宽度小于 520 时，使用 `Column`：身份行在上，按钮 `Wrap` 在下；小于 360 时两个按钮各自占满内容宽度。宽屏继续使用现有 `Row`。按钮回调与视觉样式保持不变。

- [ ] **步骤 4：运行测试并确认绿灯**

运行：`flutter test test/about_dialog_test.dart`

预期：全部 PASS，无 overflow exception。

- [ ] **步骤 5：提交任务 2**

```powershell
git add -- lib/src/settings/about_dialog.dart test/about_dialog_test.dart
git commit -m "fix: 修复关于页窄屏内容溢出"
```

### 任务 3：回归验证与真机热重载

**文件：**
- 验证：`lib/main.dart`
- 验证：`lib/src/settings/about_dialog.dart`
- 验证：`test/prototype_shell_test.dart`
- 验证：`test/about_dialog_test.dart`

- [ ] **步骤 1：运行相关测试**

运行：`flutter test test/prototype_shell_test.dart test/about_dialog_test.dart`

预期：全部 PASS。

- [ ] **步骤 2：运行静态检查和补丁检查**

运行：`flutter analyze lib/main.dart lib/src/settings/about_dialog.dart test/prototype_shell_test.dart test/about_dialog_test.dart`

运行：`git diff --check`

预期：没有新增 error 或 warning，补丁检查退出码为 0。

- [ ] **步骤 3：热重载并截图**

向当前 `flutter run` 会话发送 `r`。在连接的 Android 折叠屏中检查：游戏画面全宽；导航栏只位于信息区；“关于”页无黄黑 overflow 条纹；按钮仍可点击。
