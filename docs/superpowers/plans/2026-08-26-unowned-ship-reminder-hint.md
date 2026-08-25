# 未持有舰娘提醒说明实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在未持有舰娘筛选栏下显示一条简短说明，明确未勾选会提醒并震动、勾选后不提醒。

**架构：** 沿用 `OwnedInventoryPage` 的现有状态分支，只在 `_showOwned == false && _showShips == true` 时插入本地化文本。说明使用固定的小号浅灰样式和普通 `Text` 布局，让 Flutter 在窄屏下自然换行；不改动提醒控制器和排除逻辑。

**技术栈：** Flutter、Dart、`gen-l10n`、`flutter_test`

---

## 文件结构

- 修改：`test/owned_inventory_page_test.dart`——覆盖说明文案、样式、显示范围和窄屏溢出。
- 修改：`lib/l10n/app_zh.arb`——增加简体中文说明文案。
- 修改：`lib/l10n/app_zh_Hant.arb`——增加繁体中文说明文案。
- 修改：`lib/l10n/app_ja.arb`——增加日文说明文案。
- 生成：`lib/l10n/app_localizations.dart`、`lib/l10n/app_localizations_zh.dart`、`lib/l10n/app_localizations_ja.dart`——暴露新的本地化 getter。
- 修改：`lib/src/inventory/owned_inventory_page.dart`——在未持有舰娘筛选栏后渲染说明。

### 任务 1：用组件测试锁定说明行为

**文件：**
- 修改：`test/owned_inventory_page_test.dart`

- [ ] **步骤 1：编写失败的组件测试**

在未持有视图测试附近增加以下测试；使用窄屏验证自然换行没有布局异常，并切换装备验证说明隐藏：

```dart
testWidgets('explains unowned ship reminder exclusions below the filter', (
  tester,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(520, 700);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final controller = GameStateController();
  addTearDown(controller.dispose);

  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh'),
      home: Scaffold(
        body: OwnedInventoryPage(controller: controller, showOwned: false),
      ),
    ),
  );

  final hint = find.byKey(const Key('unowned-ship-reminder-hint'));
  expect(hint, findsOneWidget);
  final hintText = tester.widget<Text>(hint);
  expect(
    hintText.data,
    '获得未勾选的舰娘时，将正常提醒并震动；勾选的舰娘则不会提醒。',
  );
  expect(hintText.style?.fontSize, 12);
  expect(hintText.style?.color, const Color(0xff8ba2af));
  expect(tester.takeException(), isNull);

  await tester.tap(find.byKey(const Key('owned-inventory-tab-equipment')));
  await tester.pump();
  expect(hint, findsNothing);

  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh'),
      home: Scaffold(body: OwnedInventoryPage(controller: controller)),
    ),
  );
  expect(hint, findsNothing);
});
```

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/owned_inventory_page_test.dart --plain-name "explains unowned ship reminder exclusions below the filter"`

预期：FAIL，找不到键 `unowned-ship-reminder-hint`。

### 任务 2：增加本地化文案并渲染说明

**文件：**
- 修改：`lib/l10n/app_zh.arb`
- 修改：`lib/l10n/app_zh_Hant.arb`
- 修改：`lib/l10n/app_ja.arb`
- 生成：`lib/l10n/app_localizations.dart`
- 生成：`lib/l10n/app_localizations_zh.dart`
- 生成：`lib/l10n/app_localizations_ja.dart`
- 修改：`lib/src/inventory/owned_inventory_page.dart`

- [ ] **步骤 1：写入三种语言资源**

在三个 ARB 文件的 `unownedShipExcludedLabel` 附近分别添加：

```json
"unownedShipReminderHint": "获得未勾选的舰娘时，将正常提醒并震动；勾选的舰娘则不会提醒。"
```

```json
"unownedShipReminderHint": "獲得未勾選的艦娘時，將正常提醒並震動；勾選的艦娘則不會提醒。"
```

```json
"unownedShipReminderHint": "未選択の艦娘を入手すると通常どおり通知と振動を行い、選択した艦娘は通知しません。"
```

- [ ] **步骤 2：生成本地化代码**

运行：`flutter gen-l10n`

预期：生成的本地化类包含 `unownedShipReminderHint` getter，命令退出码为 0。

- [ ] **步骤 3：在筛选栏下增加条件说明**

在 `OwnedInventoryPage.build` 的筛选控件后、现有 `SizedBox(height: 4)` 前加入：

```dart
if (!_showOwned && _showShips) ...[
  const SizedBox(height: 4),
  Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Text(
      l10n.unownedShipReminderHint,
      key: const Key('unowned-ship-reminder-hint'),
      style: const TextStyle(
        color: Color(0xff8ba2af),
        fontSize: 12,
      ),
    ),
  ),
],
```

- [ ] **步骤 4：运行定向测试验证通过**

运行：`flutter test test/owned_inventory_page_test.dart --plain-name "explains unowned ship reminder exclusions below the filter"`

预期：PASS，且 `tester.takeException()` 为 `null`。

- [ ] **步骤 5：提交功能变更**

```powershell
git add -- test/owned_inventory_page_test.dart lib/l10n/app_zh.arb lib/l10n/app_zh_Hant.arb lib/l10n/app_ja.arb lib/l10n/app_localizations.dart lib/l10n/app_localizations_zh.dart lib/l10n/app_localizations_ja.dart lib/src/inventory/owned_inventory_page.dart
git commit -m "feat(持有一览): 说明未持有舰娘排除规则"
```

### 任务 3：回归验证

**文件：**
- 验证：`lib/src/inventory/owned_inventory_page.dart`
- 验证：`lib/l10n/*.arb`
- 验证：`test/owned_inventory_page_test.dart`

- [ ] **步骤 1：运行持有一览和本地化测试**

运行：`flutter test test/owned_inventory_page_test.dart test/localization_contract_test.dart test/localization_resource_audit_test.dart --reporter compact`

预期：全部测试通过。

- [ ] **步骤 2：运行定向静态分析**

运行：`dart analyze lib/src/inventory/owned_inventory_page.dart test/owned_inventory_page_test.dart lib/l10n`

预期：输出 `No issues found!`。

- [ ] **步骤 3：运行完整测试集**

运行：`flutter test --reporter compact`

预期：测试退出码为 0；仓库既有跳过项允许保持跳过。

- [ ] **步骤 4：检查提交边界**

运行：`git status --short` 和 `git show --stat --oneline HEAD`。

预期：本次提交只包含上方列出的持有一览、本地化和测试文件；原有 `land_base_summary_card` 两处工作区修改仍未暂存。
