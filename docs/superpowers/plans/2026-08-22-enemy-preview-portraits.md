# 战前敌方立绘实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在未卜先知完整模式的战前敌舰列表中显示可关闭的小型立绘，并保持简洁模式纯文字。

**架构：** 战斗控制器保留敌舰 master ID 和名称，预览组件使用 master ID 查找主数据并构建立绘。战斗预测设置控制器持久化默认开启的显示开关，主信息面板监听该控制器并即时刷新卡片。

**技术栈：** Flutter、Dart、SharedPreferences、`flutter_test`、Flutter gen-l10n

---

## 文件结构

- 修改：`lib/src/battle/battle_models.dart`，定义 `EnemyPreviewShip` 并保存结构化预览。
- 修改：`lib/src/battle/battle_controller.dart`，保留 `api_ship_ids` 中的 master ID。
- 修改：`lib/src/battle/official_enemy_preview.dart`，实现可选单列和双栏小型立绘。
- 修改：`lib/src/battle/detailed_battle_panel.dart`，为完整模式传入立绘设置和主数据。
- 修改：`lib/src/battle/live_battle_card.dart`，公开立绘开关并保证简洁模式纯文字。
- 修改：`lib/src/settings/battle_prediction_settings.dart`，持久化默认开启的立绘设置。
- 修改：`lib/src/settings/battle_prediction_settings_section.dart`，显示设置开关。
- 修改：`lib/main.dart`，把设置控制器接入主信息面板监听和卡片参数。
- 修改：`lib/l10n/app_zh.arb`、`app_zh_Hant.arb`、`app_ja.arb`，增加三语文案。
- 生成：`lib/l10n/app_localizations*.dart`，由 `flutter gen-l10n` 更新。
- 修改测试：`test/battle_controller_test.dart`、`test/live_battle_card_node_test.dart`、`test/battle_prediction_settings_test.dart`、`test/battle_prediction_settings_section_test.dart`、`test/localization_resource_audit_test.dart`。

### 任务 1：设置持久化与设置界面

**文件：**

- 修改：`test/battle_prediction_settings_test.dart`
- 修改：`test/battle_prediction_settings_section_test.dart`
- 修改：`lib/src/settings/battle_prediction_settings.dart`
- 修改：`lib/src/settings/battle_prediction_settings_section.dart`
- 修改：`lib/l10n/app_zh.arb`、`app_zh_Hant.arb`、`app_ja.arb`
- 生成：`lib/l10n/app_localizations*.dart`

- [x] **步骤 1：编写失败测试**

```dart
expect(await store.loadEnemyPortraitsEnabled(), isTrue);
expect(controller.enemyPortraitsEnabled, isTrue);
await controller.setEnemyPortraitsEnabled(false);
expect(await store.loadEnemyPortraitsEnabled(), isFalse);
expect(find.byKey(const Key('battle-enemy-preview-portraits')), findsOneWidget);
```

- [x] **步骤 2：运行红灯**

```powershell
flutter test test/battle_prediction_settings_test.dart test/battle_prediction_settings_section_test.dart
```

预期：FAIL，缺少立绘设置 API 和开关 Widget。

- [x] **步骤 3：最小实现**

Store 增加 `loadEnemyPortraitsEnabled()` 和 `saveEnemyPortraitsEnabled(bool)`，使用键 `battle.enemyPreviewPortraitsEnabled`。Controller 增加默认值为 `true` 的 getter 和保存后通知的 setter。先加入三语文案并生成本地化代码，再在设置区增加 Key 为 `battle-enemy-preview-portraits` 的 `SwitchListTile`。

- [x] **步骤 4：运行绿灯并提交**

```powershell
flutter test test/battle_prediction_settings_test.dart test/battle_prediction_settings_section_test.dart
git add lib/src/settings/battle_prediction_settings.dart lib/src/settings/battle_prediction_settings_section.dart lib/l10n test/battle_prediction_settings_test.dart test/battle_prediction_settings_section_test.dart
git commit -m "feat(战斗设置): 添加敌方立绘开关（任务 1/5）"
```

### 任务 2：结构化敌舰预览数据

**文件：**

- 修改：`test/battle_controller_test.dart`
- 修改：`lib/src/battle/battle_models.dart`
- 修改：`lib/src/battle/battle_controller.dart`

- [x] **步骤 1：编写失败测试**

```dart
expect(controller.current?.enemyPreviewShips, const <EnemyPreviewShip>[
  EnemyPreviewShip(masterId: 1501, name: '潜水ヨ級'),
  EnemyPreviewShip(masterId: 1502, name: '潜水カ級'),
  EnemyPreviewShip(masterId: 1503, name: '潜水ソ級'),
]);
```

联合舰队测试继续断言随伴 3 艘在前、主力 3 艘在后。

- [x] **步骤 2：运行红灯**

```powershell
flutter test test/battle_controller_test.dart --plain-name "map response exposes at most three official enemy preview ships"
```

预期：FAIL，缺少 `EnemyPreviewShip` 和 `enemyPreviewShips`。

- [x] **步骤 3：最小实现**

增加不可变值对象和 `LiveBattle.enemyPreviewShips`。控制器从 `api_ship_ids` 构造 `EnemyPreviewShip(masterId: id, name: name)`，跳过无效 ID 和空名称，每支舰队最多 3 艘，结果不可修改。

- [x] **步骤 4：运行绿灯并提交**

```powershell
flutter test test/battle_controller_test.dart
git add lib/src/battle/battle_models.dart lib/src/battle/battle_controller.dart test/battle_controller_test.dart
git commit -m "feat(未卜先知): 保留战前敌舰标识（任务 2/5）"
```

### 任务 3：完整模式立绘和简洁模式边界

**文件：**

- 修改：`test/live_battle_card_node_test.dart`
- 修改：`lib/src/battle/official_enemy_preview.dart`
- 修改：`lib/src/battle/detailed_battle_panel.dart`
- 修改：`lib/src/battle/live_battle_card.dart`

- [x] **步骤 1：编写失败的 Widget 测试**

使用带敌舰立绘元数据的 `GameState`，断言完整模式存在 Key `official-enemy-preview-portrait-0`。切到简洁模式后断言该 Key 不存在。另一个完整模式用例传入 `showEnemyPortraits: false`，断言没有立绘但舰名仍存在；缺少版本号时同样只显示舰名。

- [x] **步骤 2：运行红灯**

```powershell
flutter test test/live_battle_card_node_test.dart --plain-name "enemy preview portraits"
```

预期：FAIL，预览组件仍只接收纯舰名。

- [x] **步骤 3：最小实现**

`LiveBattleCard` 增加默认开启的 `showEnemyPortraits` 参数。完整模式把设置、`GameState.masterShips` 和 `serverOrigin` 传入预览组件；简洁模式显式禁用。普通列表使用 56 × 34 dp，双栏使用 48 × 30 dp；缺少 master 数据或有效 URI 时只显示舰名。

- [x] **步骤 4：运行绿灯并提交**

```powershell
flutter test test/live_battle_card_node_test.dart
git add lib/src/battle/official_enemy_preview.dart lib/src/battle/detailed_battle_panel.dart lib/src/battle/live_battle_card.dart test/live_battle_card_node_test.dart
git commit -m "feat(未卜先知): 显示战前敌方立绘（任务 3/5）"
```

### 任务 4：主界面即时刷新和本地化审计

**文件：**

- 修改：`lib/main.dart`
- 修改：`test/localization_resource_audit_test.dart`

- [x] **步骤 1：编写失败的本地化审计**

要求 3 个 ARB 文件都包含 `battleEnemyPreviewPortraits` 和 `battleEnemyPreviewPortraitsDesc`。

- [x] **步骤 2：运行红灯**

```powershell
flutter test test/localization_resource_audit_test.dart
```

预期：若任务 1 尚未加入资源则 FAIL；正常执行顺序下用于确认三个 ARB 资源均已覆盖新键。

- [x] **步骤 3：最小实现**

把 `BattlePredictionSettingsController` 传给 `_InformationPanel`，加入 `Listenable.merge`，并向 `LiveBattleCard` 传递 `enemyPortraitsEnabled`；本地化审计固定任务 1 已加入的两个资源键。

- [x] **步骤 4：运行绿灯并提交**

```powershell
flutter test test/localization_resource_audit_test.dart test/settings_localization_test.dart
git add lib/main.dart lib/l10n test/localization_resource_audit_test.dart
git commit -m "feat(未卜先知): 接入立绘设置与三语文案（任务 4/5）"
```

### 任务 5：完整验证

- [x] **步骤 1：格式化**

```powershell
dart format lib/src/battle lib/src/settings/battle_prediction_settings.dart lib/src/settings/battle_prediction_settings_section.dart lib/main.dart test/battle_controller_test.dart test/live_battle_card_node_test.dart test/battle_prediction_settings_test.dart test/battle_prediction_settings_section_test.dart test/localization_resource_audit_test.dart
```

- [x] **步骤 2：运行相关测试**

```powershell
flutter test test/battle_controller_test.dart test/live_battle_card_node_test.dart test/battle_prediction_settings_test.dart test/battle_prediction_settings_section_test.dart test/localization_resource_audit_test.dart test/settings_localization_test.dart
```

预期：全部 PASS。

- [x] **步骤 3：运行静态分析**

```powershell
flutter analyze lib/main.dart lib/src/battle lib/src/settings/battle_prediction_settings.dart lib/src/settings/battle_prediction_settings_section.dart
```

预期：退出码为 0，无分析错误。

- [x] **步骤 4：检查差异并提交格式化结果**

```powershell
git diff --check
git status --short
git add lib test
git commit -m "style(未卜先知): 格式化敌方立绘改动（任务 5/5）"
```

### 修订任务 6：采用 POI 的敌舰 banner 资源

**文件：**

- 修改：`test/ship_portrait_test.dart`
- 修改：`test/live_battle_card_node_test.dart`
- 修改：`lib/src/fleet/ship_portrait.dart`
- 修改：`lib/src/battle/official_enemy_preview.dart`

- [ ] **步骤 1：编写失败测试**

```dart
expect(
  ShipPortraitUriBuilder.build(
    ship: enemy,
    serverOrigin: 'https://w01y.kancolle-server.com',
    resourceType: ShipPortraitResourceType.banner,
  ).toString(),
  'https://w01y.kancolle-server.com/kcs2/resources/ship/banner/1501_2115.png?version=7',
);
```

Widget 测试同时断言 `official-enemy-preview-portrait-0` 内的 `NetworkImage.url` 包含 `/ship/banner/`。

- [ ] **步骤 2：运行红灯**

```powershell
flutter test test/ship_portrait_test.dart test/live_battle_card_node_test.dart --plain-name "enemy portrait uses POI banner resources"
```

预期：FAIL，缺少 `ShipPortraitResourceType.banner`，敌舰预览仍生成 `ship/remodel`。

- [ ] **步骤 3：最小实现**

为 `ShipPortraitUriBuilder.build` 增加默认值为 `remodel` 的资源类型；banner 使用 `ship_banner` 密钥。`ShipPortrait` 增加资源类型和横向裁切系数参数，敌舰预览传入 `banner` 与 `1.5`。单舰队及联合舰队胶囊尺寸不变。

- [ ] **步骤 4：运行绿灯和回归验证**

```powershell
flutter test test/ship_portrait_test.dart test/live_battle_card_node_test.dart
flutter analyze lib/src/fleet/ship_portrait.dart lib/src/battle/official_enemy_preview.dart
```

预期：全部 PASS，静态分析退出码为 0。

- [ ] **步骤 5：提交**

```powershell
git add lib/src/fleet/ship_portrait.dart lib/src/battle/official_enemy_preview.dart test/ship_portrait_test.dart test/live_battle_card_node_test.dart docs/superpowers
git commit -m "fix(未卜先知): 按 POI 规则加载敌舰立绘"
```
