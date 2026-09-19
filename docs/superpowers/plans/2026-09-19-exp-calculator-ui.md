# 经验计算页面 UI 重构实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在不改变经验计算业务行为的前提下，将页面重构为 Yahagi 统一的深海军蓝、灰蓝与金色视觉体系，并为宽屏提供双栏工作区。

**架构：** 保留 `_ExpCalcPageState` 的状态、计算与持久化逻辑，仅调整 `build` 及其私有展示方法。页面内部增加集中式调色板，并通过宽度断点在双栏与单列之间切换；现有 Widget Key 和交互方法保持不变。

**技术栈：** Flutter、Dart、Material 3、flutter_test

---

## 文件结构

- 修改：`lib/src/toolbox/exp_calc/exp_calc_page.dart`——集中页面色彩，重排响应式布局，统一卡片与控件样式。
- 修改：`test/exp_calc_page_test.dart`——覆盖宽屏双栏、窄屏单列及既有交互回归。

### 任务 1：锁定响应式布局行为

**文件：**
- 修改：`test/exp_calc_page_test.dart`
- 测试：`test/exp_calc_page_test.dart`

- [ ] **步骤 1：编写失败的宽屏和窄屏布局测试**

在测试文件中增加对新布局 Key 的断言：

```dart
expect(find.byKey(const Key('exp-calc-wide-workspace')), findsOneWidget);
expect(find.byKey(const Key('exp-calc-compact-workspace')), findsNothing);
```

并在现有 360 px 窄屏测试中增加：

```dart
expect(find.byKey(const Key('exp-calc-wide-workspace')), findsNothing);
expect(find.byKey(const Key('exp-calc-compact-workspace')), findsOneWidget);
```

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/exp_calc_page_test.dart`

预期：FAIL，原因是新布局 Key 尚不存在。

- [ ] **步骤 3：提交测试基线**

```powershell
git add test/exp_calc_page_test.dart
git commit -m "test: 锁定经验计算响应式布局"
```

### 任务 2：重构页面信息结构与视觉组件

**文件：**
- 修改：`lib/src/toolbox/exp_calc/exp_calc_page.dart:1-2025`
- 测试：`test/exp_calc_page_test.dart`

- [ ] **步骤 1：增加页面调色板**

在文件顶部增加私有调色板，统一背景、表面、边框、主色、数据色和语义色：

```dart
abstract final class _ExpCalcPalette {
  static const background = Color(0xff091923);
  static const surface = Color(0xff102732);
  static const surfaceRaised = Color(0xff16333f);
  static const border = Color(0xff284553);
  static const gold = Color(0xffd7b56d);
  static const goldSoft = Color(0xffffdc88);
  static const data = Color(0xff76c6df);
  static const text = Color(0xffecf3f5);
  static const textMuted = Color(0xff91aab8);
  static const textFaint = Color(0xff6f8a98);
  static const success = Color(0xff63c59b);
  static const danger = Color(0xffe66e68);
  static const target = Color(0xffe5a95f);
}
```

- [ ] **步骤 2：实现宽屏双栏与窄屏单列**

将现有连续 Column 改为共享区块构建器。宽度不小于 760 px 时使用带 `exp-calc-wide-workspace` Key 的 Row，左侧放舰娘目标与路线配置，右侧放结果摘要；窄屏使用带 `exp-calc-compact-workspace` Key 的 Column。追踪列表固定放在工作区下方并占满宽度。

```dart
final isWide = constraints.maxWidth >= 760;
final workspace = isWide
    ? Row(
        key: const Key('exp-calc-wide-workspace'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: setupColumn),
          const SizedBox(width: 16),
          Expanded(flex: 2, child: resultCard),
        ],
      )
    : Column(
        key: const Key('exp-calc-compact-workspace'),
        children: [setupColumn, const SizedBox(height: 12), resultCard],
      );
```

- [ ] **步骤 3：统一标题、卡片、输入框和状态色**

使用 `_ExpCalcPalette` 替换页面独有的高饱和蓝色。标题标识、步骤标识、选中态和主按钮使用金色；数值使用 `data`；删除与未达成使用 `danger`；完成与启用使用 `success`。保持全部现有 Widget Key、回调与计算表达式不变。

- [ ] **步骤 4：格式化实现文件**

运行：`dart format lib/src/toolbox/exp_calc/exp_calc_page.dart test/exp_calc_page_test.dart`

预期：两个文件格式化成功，无语法错误。

- [ ] **步骤 5：运行页面测试验证通过**

运行：`flutter test test/exp_calc_page_test.dart`

预期：PASS，所有经验计算页面测试通过。

- [ ] **步骤 6：提交页面重构**

```powershell
git add lib/src/toolbox/exp_calc/exp_calc_page.dart test/exp_calc_page_test.dart
git commit -m "style: 统一经验计算页面设计"
```

### 任务 3：静态检查与热重载

**文件：**
- 验证：`lib/src/toolbox/exp_calc/exp_calc_page.dart`
- 验证：`test/exp_calc_page_test.dart`

- [ ] **步骤 1：执行定向静态分析**

运行：`flutter analyze lib/src/toolbox/exp_calc/exp_calc_page.dart test/exp_calc_page_test.dart`

预期：没有新增 error 或 warning。

- [ ] **步骤 2：确认 Flutter 运行会话**

读取当前 Codex 终端输出，确认其处于 `flutter run` 会话且支持交互式热重载。

- [ ] **步骤 3：触发热重载**

向当前 Flutter 终端发送 `r`。

预期：终端显示 hot reload 成功；不运行 `flutter build`，不生成 debug APK。

- [ ] **步骤 4：检查最终差异**

运行：`git diff --check`，并检查 `git diff -- lib/src/toolbox/exp_calc/exp_calc_page.dart test/exp_calc_page_test.dart`。

预期：没有空白错误；差异只包含已批准的页面 UI、响应式布局及对应测试。

