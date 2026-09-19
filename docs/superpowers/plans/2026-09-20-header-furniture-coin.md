# 顶部家具币资源胶囊实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在顶部资源栏增加默认隐藏的家具币胶囊，使用官方家具币图标和已抓取的 `api_fcoin` 数值。

**架构：** 在现有 `HeaderResourceSpec` 目录中增加家具币值来源，由 `CompactResourceBar` 继续负责统一渲染、筛选与排序。设置规范化函数负责把新资源迁移到「改修资材」与「家具箱（小）」之间，同时保持旧用户的可见项不变。

**技术栈：** Flutter、Dart、flutter_test、SharedPreferences、舰队 Collection `common_itemicons` 图集资源。

---

## 文件结构

- 创建：`assets/images/material/useitem_44.png`——从官方图集中提取的 75 × 75 家具币图标。
- 修改：`lib/src/fleet/header_resource_catalog.dart`——注册家具币资源及其状态取值规则。
- 修改：`lib/src/settings/header_resource_settings.dart`——声明资源 ID、完整顺序和旧配置插入规则。
- 修改：`lib/src/settings/layout_settings_controller.dart`——持久化旧顺序迁移，不改变旧可见项。
- 修改：`lib/src/fleet/fleet_ui_strings.dart`——补充简中、繁中、日文标签。
- 修改：`test/compact_resource_bar_test.dart`——验证显示值、占位符、图标和默认隐藏/手动启用。
- 修改：`test/layout_settings_behavior_test.dart`——验证新装与旧配置的顺序、可见性和持久化迁移。
- 修改：`test/fleet_localization_test.dart`——验证家具币标签本地化。

### 任务 1：锁定家具币目录行为

- [ ] **步骤 1：编写失败的目录与组件测试**

在 `test/compact_resource_bar_test.dart` 中增加测试：

```dart
testWidgets('furniture coin is hidden by default and can be enabled', (
  tester,
) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final controller = await LayoutSettingsController.load(
    SharedPreferencesLayoutSettingsStore(),
  );
  const state = GameState(
    furnitureCoins: 88000,
    hasFurnitureCoinData: true,
  );

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: CompactResourceBar(
          state: state,
          settingsController: controller,
        ),
      ),
    ),
  );

  expect(find.byKey(const Key('header-resource-furniture-coin')), findsNothing);
  await controller.toggleHeaderResourceVisible(headerFurnitureCoinId);
  await tester.pump();
  expect(find.byKey(const Key('header-resource-furniture-coin')), findsOneWidget);
  expect(find.text('88000'), findsOneWidget);
  expect(
    find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName ==
              'assets/images/material/useitem_44.png',
    ),
    findsOneWidget,
  );
});
```

另加一个使用 `GameState.empty` 的测试，启用家具币后断言显示 `—`。

- [ ] **步骤 2：运行测试验证失败**

运行：

```powershell
flutter test test/compact_resource_bar_test.dart --plain-name "furniture coin"
```

预期：FAIL，原因是 `headerFurnitureCoinId` 和目录项尚不存在。

- [ ] **步骤 3：加入官方图标和最小目录实现**

从 `common_itemicons` 的家具币条目（道具 ID 44）取得 75 × 75 PNG，保存为 `assets/images/material/useitem_44.png`。

在 `header_resource_catalog.dart` 中让家具币值读取：

```dart
int? value(GameState state) {
  if (isFurnitureCoin) {
    return state.hasFurnitureCoinData ? state.furnitureCoins : null;
  }
  final material = type;
  return material == null
      ? state.useItemCount(useItemId!)
      : state.resource(material);
}
```

新增目录项：

```dart
HeaderResourceSpec(
  id: headerFurnitureCoinId,
  label: '家具コイン',
  assetPath: 'assets/images/material/useitem_44.png',
  isFurnitureCoin: true,
),
```

- [ ] **步骤 4：运行组件测试验证通过**

运行：

```powershell
flutter test test/compact_resource_bar_test.dart --plain-name "furniture coin"
```

预期：PASS，家具币显示实际值或未同步占位符，并使用新图标。

### 任务 2：锁定顺序、默认隐藏和旧配置迁移

- [ ] **步骤 1：编写失败的设置测试**

在 `test/layout_settings_behavior_test.dart` 中增加断言：

```dart
expect(controller.visibleHeaderResourceIds, isNot(contains(headerFurnitureCoinId)));
final coinIndex = controller.headerResourceOrder.indexOf(headerFurnitureCoinId);
expect(controller.headerResourceOrder[coinIndex - 1], 'material-8');
expect(controller.headerResourceOrder[coinIndex + 1], 'useitem-10');
```

再使用不含 `headerFurnitureCoinId` 的完整旧顺序与旧可见项加载 Controller，断言迁移后顺序正确、旧可见项完全不变，并验证保存后的顺序包含家具币。

- [ ] **步骤 2：运行测试验证失败**

运行：

```powershell
flutter test test/layout_settings_behavior_test.dart --plain-name "furniture coin"
```

预期：FAIL，原因是设置目录和迁移逻辑尚未包含家具币。

- [ ] **步骤 3：实现最小设置迁移**

在 `header_resource_settings.dart` 中声明：

```dart
const headerFurnitureCoinId = 'furniture-coin';
```

将其放入 `allHeaderResourceIds` 的 `material-8` 与 `useitem-10` 之间，不加入 `defaultVisibleHeaderResourceIds`。在 `normalizeHeaderResourceOrder` 中，当旧顺序缺失该项时优先插入 `material-8` 后方。

在 `LayoutSettingsController.load` 中检测 `migratesFurnitureCoin`，把顺序迁移写回存储，但不把家具币加入 `visibleHeaderResourceIds`。

- [ ] **步骤 4：运行设置测试验证通过**

运行：

```powershell
flutter test test/layout_settings_behavior_test.dart --plain-name "furniture coin"
```

预期：PASS，新装与旧配置都获得正确顺序，家具币保持隐藏。

### 任务 3：本地化与回归验证

- [ ] **步骤 1：编写失败的本地化测试**

在 `test/fleet_localization_test.dart` 中对 `fleetText(context, '家具コイン')` 验证：

```dart
expect(find.text('家具币'), findsOneWidget); // zh
expect(find.text('家具幣'), findsOneWidget); // zh-Hant
expect(find.text('家具コイン'), findsOneWidget); // ja
```

- [ ] **步骤 2：运行测试验证失败**

运行：

```powershell
flutter test test/fleet_localization_test.dart --plain-name "furniture coin"
```

预期：FAIL，简中和繁中仍显示日文源标签。

- [ ] **步骤 3：增加本地化映射**

在 `fleet_ui_strings.dart` 的资源映射中加入：

```dart
"家具コイン": ("家具币", "家具幣", "家具コイン"),
```

- [ ] **步骤 4：运行相关测试与静态分析**

运行：

```powershell
flutter test test/compact_resource_bar_test.dart test/layout_settings_behavior_test.dart test/fleet_localization_test.dart
flutter analyze lib/src/fleet/header_resource_catalog.dart lib/src/fleet/resource_grid.dart lib/src/settings/header_resource_settings.dart lib/src/settings/layout_settings_controller.dart
```

预期：全部测试 PASS，静态分析报告 `No issues found!`。

### 任务 4：DEBUG 热重载和视觉检查

- [ ] **步骤 1：确认当前 DEBUG 会话**

读取现有 Flutter 终端输出和设备状态，确认运行的是开发会话；不执行 `flutter build`。

- [ ] **步骤 2：执行热重载**

向现有 `flutter run` 会话发送 `r`，等待 `Reloaded` 成功消息。

- [ ] **步骤 3：检查界面**

在应用顶部资源栏长按进入编辑模式，打开筛选，确认家具币默认未选中；启用后确认它位于改修资材与家具箱（小）之间，并检查图标、数值、胶囊尺寸和无溢出。

- [ ] **步骤 4：记录验证结果**

保留测试命令、静态分析、热重载和界面检查的实际结果；若 DEBUG 会话不存在，只启动 `flutter run` 开发会话，不执行任何打包命令。
