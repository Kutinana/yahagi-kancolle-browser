# 工具箱导航图标实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 将工具箱导航项改为用户选定的 `Widgets` 图标，并用 Widget 测试防止再次与建造图标重复。

**架构：** 保持现有 `_WorkspaceDestination` 和 `_NavigationButton` 不变，只替换工具箱目的地的 `IconData`。在现有根工作区 Widget 测试中按导航按钮 Key 检查各自后代图标，避免依赖全页面图标数量。

**技术栈：** Flutter、Material Icons、flutter_test

---

## 文件结构

- 修改：`lib/main.dart`，定义工具箱工作区目的地的图标。
- 修改：`test/prototype_shell_test.dart`，验证工具箱与建造导航项使用不同图标。

### 任务 1：替换工具箱导航图标

**文件：**
- 修改：`test/prototype_shell_test.dart:406-423`
- 修改：`lib/main.dart:1969-1974`

- [ ] **步骤 1：编写失败的 Widget 测试断言**

在现有工作区导航测试中，完成导航项存在性检查后加入：

```dart
final toolboxNavigation = find.byKey(const Key('workspace-nav-tools'));
final constructionNavigation = find.byKey(
  const Key('workspace-nav-construction'),
);
expect(
  find.descendant(
    of: toolboxNavigation,
    matching: find.byIcon(Icons.widgets_outlined),
  ),
  findsOneWidget,
);
expect(
  find.descendant(
    of: toolboxNavigation,
    matching: find.byIcon(Icons.handyman_outlined),
  ),
  findsNothing,
);
expect(
  find.descendant(
    of: constructionNavigation,
    matching: find.byIcon(Icons.handyman_outlined),
  ),
  findsOneWidget,
);
```

- [ ] **步骤 2：运行测试验证失败**

运行：

```bash
flutter test test/prototype_shell_test.dart --plain-name "shows the game surface, information panel, and capture modes"
```

预期：FAIL，工具箱按钮中找不到 `Icons.widgets_outlined`，且仍能找到 `Icons.handyman_outlined`。

- [ ] **步骤 3：编写最少实现代码**

将 `lib/main.dart` 中工具箱目的地改为：

```dart
'tools': _WorkspaceDestination(
  id: 'tools',
  pageIndex: 10,
  icon: Icons.widgets_outlined,
  label: l10n.toolbox,
),
```

- [ ] **步骤 4：运行针对性验证**

运行：

```bash
flutter test test/prototype_shell_test.dart
flutter analyze lib/main.dart test/prototype_shell_test.dart
git diff --check
```

预期：测试全部通过，静态分析无问题，`git diff --check` 无输出且退出码为 0。

- [ ] **步骤 5：运行完整测试**

运行：

```bash
flutter test
```

预期：全部测试通过，失败数为 0。

- [ ] **步骤 6：提交实现**

```bash
git add lib/main.dart test/prototype_shell_test.dart
git commit -m "fix(工具箱): 更换导航图标"
```
