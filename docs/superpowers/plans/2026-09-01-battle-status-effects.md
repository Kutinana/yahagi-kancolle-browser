# 战斗状态效果细分实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在保持大破进击安全弹窗独立的前提下，实现可分级、可限定显示范围的受损闪烁与震动，并增加士气星光开关和可靠的旧设置迁移。

**架构：** 用一个纯 Dart 损伤等级模型统一 HP 边界，用独立的 `BattleStatusEffectSettings` 表达总开关、显示范围和三类效果策略。设置控制器负责持久化与迁移，应用组合层按预测侧／编队侧派生有效视觉策略，战斗控制器只消费震动策略，各 Widget 只负责渲染。

**技术栈：** Flutter/Dart、SharedPreferences、Flutter Widget Test、Kotlin Android 单元测试、Flutter gen-l10n。

---

## 文件结构

**创建：**

- `lib/src/fleet/ship_damage_level.dart`：纯 Dart HP 损伤等级及精确整数边界。
- `lib/src/settings/battle_status_effect_settings.dart`：设置值对象、枚举、过滤和范围策略。
- `test/ship_damage_level_test.dart`：损伤边界测试。
- `test/settings/battle_status_effect_settings_test.dart`：策略真值表测试。
- `test/settings/battle_status_effect_migration_test.dart`：SharedPreferences 旧键迁移测试。

**修改：**

- `lib/src/fleet/ship_status_style.dart`：使用统一损伤等级和新闪烁模式。
- `lib/src/fleet/ship_status_visuals.dart`：按模式过滤受损动画，单独控制士气星光。
- `lib/src/settings/safety_settings_store.dart`：读写新配置并迁移旧键。
- `lib/src/settings/safety_settings_controller.dart`：暴露配置和五个更新入口。
- `lib/src/settings/battle_settings_page.dart`：实现 Demo 中的统一设置卡片。
- `lib/src/settings/screen_settings_page.dart`：移除旧强化呼吸入口。
- `lib/src/settings/layout_settings_controller.dart`、`lib/src/settings/layout_settings_store.dart`：移除运行时旧闪烁开关依赖，保留迁移键兼容。
- `lib/main.dart`：监听安全设置，并向预测侧／编队侧传递有效策略。
- `lib/src/fleet/fleet_ship_status_capsule.dart`、`lib/src/fleet/fleet_summary_card.dart`、`lib/src/fleet/fleet_information_center.dart`、`lib/src/fleet/land_base_summary_card.dart`：消费编队侧闪烁与士气星光策略。
- `lib/src/battle/live_battle_card.dart`、`lib/src/battle/detailed_battle_panel.dart`：消费预测侧闪烁策略，保持敌我双方一致。
- `lib/src/battle/battle_damage_alert.dart`、`lib/src/battle/battle_controller.dart`：按震动模式过滤最终新损伤等级。
- `lib/src/capture/battle_result_warning_overlay.dart`：弹窗独立，伴随震动按大破震动策略执行。
- `lib/l10n/app_zh.arb`、`lib/l10n/app_zh_Hant.arb`、`lib/l10n/app_ja.arb` 及生成文件：新增设置文案并删除旧入口引用。
- 相关现有测试：更新构造参数、旧枚举值和断言。

## 任务 1：统一损伤等级和闪烁过滤

**文件：**

- 创建：`lib/src/fleet/ship_damage_level.dart`
- 创建：`test/ship_damage_level_test.dart`
- 创建：`lib/src/settings/battle_status_effect_settings.dart`
- 创建：`test/settings/battle_status_effect_settings_test.dart`
- 修改：`lib/src/fleet/ship_status_style.dart`
- 修改：`test/ship_status_style_test.dart`

- [ ] **步骤 1：编写损伤边界失败测试**

```dart
test('classifies exact quarter half and three-quarter HP boundaries', () {
  expect(shipDamageLevel(currentHp: 0, maxHp: 100), ShipDamageLevel.none);
  expect(shipDamageLevel(currentHp: 25, maxHp: 100), ShipDamageLevel.heavy);
  expect(shipDamageLevel(currentHp: 26, maxHp: 100), ShipDamageLevel.moderate);
  expect(shipDamageLevel(currentHp: 50, maxHp: 100), ShipDamageLevel.moderate);
  expect(shipDamageLevel(currentHp: 51, maxHp: 100), ShipDamageLevel.minor);
  expect(shipDamageLevel(currentHp: 75, maxHp: 100), ShipDamageLevel.minor);
  expect(shipDamageLevel(currentHp: 76, maxHp: 100), ShipDamageLevel.healthy);
  expect(shipDamageLevel(currentHp: 8, maxHp: 33), ShipDamageLevel.heavy);
  expect(shipDamageLevel(currentHp: 9, maxHp: 33), ShipDamageLevel.moderate);
});
```

- [ ] **步骤 2：运行边界测试并确认失败**

运行：`flutter test test/ship_damage_level_test.dart`

预期：FAIL，`ship_damage_level.dart` 或 `ShipDamageLevel` 尚不存在。

- [ ] **步骤 3：实现纯 Dart 损伤等级**

```dart
enum ShipDamageLevel { none, healthy, minor, moderate, heavy }

ShipDamageLevel shipDamageLevel({
  required int currentHp,
  required int maxHp,
}) {
  if (currentHp <= 0 || maxHp <= 0) return ShipDamageLevel.none;
  if (currentHp * 4 <= maxHp) return ShipDamageLevel.heavy;
  if (currentHp * 2 <= maxHp) return ShipDamageLevel.moderate;
  if (currentHp * 4 <= maxHp * 3) return ShipDamageLevel.minor;
  return ShipDamageLevel.healthy;
}
```

- [ ] **步骤 4：编写设置策略失败测试**

```dart
test('damage pulse filters match only the requested band', () {
  expect(DamagePulseFilter.minorOnly.allows(ShipDamageLevel.minor), isTrue);
  expect(DamagePulseFilter.minorOnly.allows(ShipDamageLevel.moderate), isFalse);
  expect(DamagePulseFilter.moderateOnly.allows(ShipDamageLevel.heavy), isFalse);
  expect(DamagePulseFilter.heavyOnly.allows(ShipDamageLevel.heavy), isTrue);
  expect(DamagePulseFilter.all.allows(ShipDamageLevel.minor), isTrue);
  expect(DamagePulseFilter.off.allows(ShipDamageLevel.heavy), isFalse);
});

test('display scope and master switch produce effective policies', () {
  const settings = BattleStatusEffectSettings(
    displayScope: BattleEffectDisplayScope.predictionOnly,
  );
  expect(settings.pulseFilterFor(BattleEffectSurface.prediction), DamagePulseFilter.all);
  expect(settings.pulseFilterFor(BattleEffectSurface.fleet), DamagePulseFilter.off);
  expect(settings.copyWith(enabled: false).vibrates(ShipDamageLevel.heavy), isFalse);
});
```

- [ ] **步骤 5：实现设置值对象和过滤枚举**

实现这些稳定名称：

```dart
enum BattleEffectDisplayScope { predictionOnly, fleetOnly, all }
enum BattleEffectSurface { prediction, fleet }
enum DamagePulseFilter { off, minorOnly, moderateOnly, heavyOnly, all }
enum DamageVibrationFilter { off, moderateOnly, heavyOnly, all }

@immutable
class BattleStatusEffectSettings {
  const BattleStatusEffectSettings({
    this.enabled = true,
    this.displayScope = BattleEffectDisplayScope.all,
    this.damagePulseFilter = DamagePulseFilter.all,
    this.damageVibrationFilter = DamageVibrationFilter.all,
    this.moraleSparkleEnabled = true,
  });

  final bool enabled;
  final BattleEffectDisplayScope displayScope;
  final DamagePulseFilter damagePulseFilter;
  final DamageVibrationFilter damageVibrationFilter;
  final bool moraleSparkleEnabled;

  DamagePulseFilter pulseFilterFor(BattleEffectSurface surface) =>
      enabled && displayScope.includes(surface)
          ? damagePulseFilter
          : DamagePulseFilter.off;

  bool sparkleFor(BattleEffectSurface surface) =>
      enabled && moraleSparkleEnabled && displayScope.includes(surface);

  bool vibrates(ShipDamageLevel level) =>
      enabled && damageVibrationFilter.allows(level);

  BattleStatusEffectSettings copyWith({
    bool? enabled,
    BattleEffectDisplayScope? displayScope,
    DamagePulseFilter? damagePulseFilter,
    DamageVibrationFilter? damageVibrationFilter,
    bool? moraleSparkleEnabled,
  });
}
```

为三个枚举实现 `includes`／`allows` 扩展，并为值对象实现 `==`、`hashCode`。

- [ ] **步骤 6：把闪烁视觉规格切到严格过滤**

将 `damagePulseVisualSpec` 的 `DamagePulseMode.normal/enhanced` 参数替换为 `DamagePulseFilter filter`；先用 `hpRatio` 得到等级，只有 `filter.allows(level)` 时才返回 `pulses: true`，启用时统一沿用原强化动画的颜色和时长。`isShipHeavilyDamaged` 改为调用 `shipDamageLevel(...) == ShipDamageLevel.heavy`。

- [ ] **步骤 7：运行纯逻辑与视觉规格测试**

运行：

```powershell
flutter test test/ship_damage_level_test.dart test/settings/battle_status_effect_settings_test.dart test/ship_status_style_test.dart
```

预期：全部 PASS；小破、中破、大破仍分别为 2200 ms、1450 ms、760 ms。

- [ ] **步骤 8：提交**

```powershell
git add lib/src/fleet/ship_damage_level.dart lib/src/settings/battle_status_effect_settings.dart lib/src/fleet/ship_status_style.dart test/ship_damage_level_test.dart test/settings/battle_status_effect_settings_test.dart test/ship_status_style_test.dart
git commit -m "feat(战斗提示): 统一损伤等级和效果策略"
```

## 任务 2：设置持久化和旧键迁移

**文件：**

- 修改：`lib/src/settings/safety_settings_store.dart`
- 修改：`lib/src/settings/safety_settings_controller.dart`
- 创建：`test/settings/battle_status_effect_migration_test.dart`
- 修改：`test/battle_damage_vibration_settings_test.dart`

- [ ] **步骤 1：编写默认值、持久化和迁移失败测试**

```dart
test('new status effects default to all enabled', () async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final controller = await SafetySettingsController.load(
    SharedPreferencesSafetySettingsStore(),
  );
  expect(controller.statusEffects, const BattleStatusEffectSettings());
});

test('legacy disabled vibration migrates to off without changing warning mode', () async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'battle.damageVibrationEnabled': false,
    'safety.battleWarningMode': 'confirm',
    'layout_enhanced_damage_pulse': false,
  });
  final controller = await SafetySettingsController.load(
    SharedPreferencesSafetySettingsStore(),
  );
  expect(controller.statusEffects.damageVibrationFilter, DamageVibrationFilter.off);
  expect(controller.statusEffects.damagePulseFilter, DamagePulseFilter.all);
  expect(controller.battleWarningMode, BattleWarningMode.confirm);
});
```

再增加测试：旧震动 `true` → `all`、新键优先于旧键、未知枚举回退默认、五字段保存后重新加载相等。

- [ ] **步骤 2：运行迁移测试并确认失败**

运行：`flutter test test/settings/battle_status_effect_migration_test.dart`

预期：FAIL，存储接口还没有 `loadStatusEffects`。

- [ ] **步骤 3：扩展存储接口并实现 SharedPreferences 迁移**

接口新增：

```dart
Future<BattleStatusEffectSettings> loadStatusEffects();
Future<void> saveStatusEffects(BattleStatusEffectSettings settings);
```

新增键：

```dart
static const _effectsEnabledKey = 'battle.statusEffects.enabled';
static const _effectsScopeKey = 'battle.statusEffects.displayScope';
static const _pulseFilterKey = 'battle.statusEffects.damagePulseFilter';
static const _vibrationFilterKey = 'battle.statusEffects.damageVibrationFilter';
static const _moraleSparkleKey = 'battle.statusEffects.moraleSparkleEnabled';
```

以 `_effectsEnabledKey` 是否存在作为新配置存在标志。新配置不存在时读取旧 `battle.damageVibrationEnabled`，按规格构造默认配置并调用 `saveStatusEffects`；不要删除旧键。字符串枚举用 `values.firstWhere(..., orElse: ...)` 安全解析。

- [ ] **步骤 4：扩展控制器的原子更新入口**

```dart
BattleStatusEffectSettings get statusEffects => _statusEffects;

Future<void> setStatusEffectsEnabled(bool value) =>
    _saveStatusEffects(_statusEffects.copyWith(enabled: value));
Future<void> setStatusEffectDisplayScope(BattleEffectDisplayScope value) =>
    _saveStatusEffects(_statusEffects.copyWith(displayScope: value));
Future<void> setDamagePulseFilter(DamagePulseFilter value) =>
    _saveStatusEffects(_statusEffects.copyWith(damagePulseFilter: value));
Future<void> setDamageVibrationFilter(DamageVibrationFilter value) =>
    _saveStatusEffects(_statusEffects.copyWith(damageVibrationFilter: value));
Future<void> setMoraleSparkleEnabled(bool value) =>
    _saveStatusEffects(_statusEffects.copyWith(moraleSparkleEnabled: value));
```

更新内存存储，使其可注入初始配置并记录保存值。

- [ ] **步骤 5：运行设置测试**

运行：

```powershell
flutter test test/settings/battle_status_effect_migration_test.dart test/battle_damage_vibration_settings_test.dart
```

预期：全部 PASS。

- [ ] **步骤 6：提交**

```powershell
git add lib/src/settings/safety_settings_store.dart lib/src/settings/safety_settings_controller.dart test/settings/battle_status_effect_migration_test.dart test/battle_damage_vibration_settings_test.dart
git commit -m "feat(战斗设置): 持久化并迁移状态效果选项"
```

## 任务 3：实现 1:1 设置 UI 和本地化

**文件：**

- 修改：`lib/src/settings/battle_settings_page.dart`
- 修改：`lib/src/settings/screen_settings_page.dart`
- 修改：`lib/l10n/app_zh.arb`
- 修改：`lib/l10n/app_zh_Hant.arb`
- 修改：`lib/l10n/app_ja.arb`
- 生成：`lib/l10n/app_localizations*.dart`
- 修改：`test/battle_settings_damage_vibration_test.dart`
- 修改：`test/screen_settings_damage_pulse_test.dart`
- 修改：`test/prototype_shell_test.dart`

- [ ] **步骤 1：把已批准 Demo 转成 Widget 失败测试**

```dart
testWidgets('battle page exposes unified status effect controls', (tester) async {
  final controller = await SafetySettingsController.load(MemorySafetySettingsStore());
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('zh'),
    home: BattleSettingsPage(safetySettingsController: controller),
  ));

  expect(find.text('启用状态效果'), findsOneWidget);
  expect(find.text('画面显示范围'), findsOneWidget);
  expect(find.text('受损闪烁'), findsOneWidget);
  expect(find.text('受损震动'), findsOneWidget);
  expect(find.text('士气闪光效果'), findsOneWidget);
  expect(find.text('战斗受损震动提醒'), findsNothing);
});
```

增加交互断言：关闭总开关后四个子控件不可操作但值不变；选择三种范围、闪烁五档、震动四档能更新控制器；窄宽 420 px 不抛 overflow。

- [ ] **步骤 2：运行页面测试并确认失败**

运行：`flutter test test/battle_settings_damage_vibration_test.dart test/screen_settings_damage_pulse_test.dart`

预期：FAIL，新文案和控件不存在。

- [ ] **步骤 3：添加三语本地化键并生成代码**

中文键值至少包括：

```json
"battleStatusEffectsSection": "战斗状态效果",
"battleStatusEffectsEnabled": "启用状态效果",
"battleStatusEffectsEnabledDesc": "统一开启或关闭受损闪烁、受损震动与士气闪光。",
"battleEffectDisplayScope": "画面显示范围",
"battleEffectScopePrediction": "仅未卜先知",
"battleEffectScopeFleet": "仅编队",
"battleEffectScopeAll": "全部",
"battleDamagePulse": "受损闪烁",
"battleDamageVibration": "受损震动",
"moraleSparkleEffect": "士气闪光效果",
"effectOff": "关闭",
"effectMinorOnly": "仅小破",
"effectModerateOnly": "仅中破",
"effectHeavyOnly": "仅大破",
"effectAll": "全部开启"
```

运行：`flutter gen-l10n`

- [ ] **步骤 4：实现统一卡片**

保留原大破提醒卡。新增卡片使用现有 `buildCard`、`buildSwitchTile` 和同色分隔线：顶部总开关；显示范围使用与 Demo 相同的三段胶囊按钮；闪烁和震动使用 `DropdownButton`；末行使用士气星光 `Switch`。子行的 `onChanged` 在总开关关闭时为 `null`，但 `value` 保持控制器原值。

显示范围组件在宽度不足时换到标题下方，不能压缩标题或产生黄黑 overflow 条。

- [ ] **步骤 5：移除画面设置中的旧入口**

删除 `ScreenSettingsPage` 中 `settings-enhanced-damage-pulse` 那一行及相邻多余分隔线，更新测试为 `find.byKey(...), findsNothing`。暂不在本任务删除底层旧存储键。

- [ ] **步骤 6：运行 UI 和壳层测试**

运行：

```powershell
flutter test test/battle_settings_damage_vibration_test.dart test/screen_settings_damage_pulse_test.dart test/prototype_shell_test.dart
```

预期：全部 PASS，无 overflow 异常。

- [ ] **步骤 7：提交**

```powershell
git add lib/src/settings/battle_settings_page.dart lib/src/settings/screen_settings_page.dart lib/l10n test/battle_settings_damage_vibration_test.dart test/screen_settings_damage_pulse_test.dart test/prototype_shell_test.dart
git commit -m "feat(战斗设置): 添加状态效果细分界面"
```

## 任务 4：编队侧受损闪烁和士气星光

**文件：**

- 修改：`lib/src/fleet/ship_status_visuals.dart`
- 修改：`lib/src/fleet/fleet_ship_status_capsule.dart`
- 修改：`lib/src/fleet/fleet_summary_card.dart`
- 修改：`lib/src/fleet/fleet_information_center.dart`
- 修改：`lib/src/fleet/land_base_summary_card.dart`
- 修改：`lib/main.dart`
- 修改：`test/ship_hp_frame_test.dart`
- 修改：`test/ship_morale_mark_test.dart`
- 修改：`test/fleet_information_center_test.dart`

- [ ] **步骤 1：编写闪烁过滤和士气星光失败测试**

```dart
testWidgets('moderate-only pulse stops again after entering heavy damage', (tester) async {
  Widget frame(double ratio) => MaterialApp(home: SizedBox(
    width: 120,
    height: 80,
    child: ShipHpFrame(
      shipId: 1,
      ratio: ratio,
      color: shipHpBarColor(ratio),
      pulseFilter: DamagePulseFilter.moderateOnly,
    ),
  ));

  await tester.pumpWidget(frame(0.20));
  expect(find.byKey(const Key('ship-hp-pulse-1')), findsNothing);

  await tester.pumpWidget(frame(0.40));
  expect(find.byKey(const Key('ship-hp-pulse-1')), findsOneWidget);
});

testWidgets('disabled sparkle keeps fatigue face and badge', (tester) async {
  Widget mark(int cond) => MaterialApp(home: SizedBox(
    width: 180,
    height: 90,
    child: ShipMoraleMark(
      shipId: 1,
      value: cond,
      sparklePulse: const AlwaysStoppedAnimation<double>(1),
      sparkleEnabled: false,
      layout: ShipMoraleMarkLayout.detail,
    ),
  ));

  await tester.pumpWidget(mark(18));
  expect(find.byKey(const Key('fleet-fatigue-face-18')), findsOneWidget);
  expect(find.byKey(const Key('fleet-fatigue-badge-1')), findsOneWidget);

  await tester.pumpWidget(mark(53));
  expect(find.byKey(const Key('fleet-morale-stars-1')), findsNothing);
});
```

测试不要依赖私有 painter 类型；若现有 key 足够，使用动画 controller／key 断言。需要可观测性时新增稳定 key，例如 `ship-hp-pulse-$shipId`。

- [ ] **步骤 2：运行视觉组件测试并确认失败**

运行：`flutter test test/ship_hp_frame_test.dart test/ship_morale_mark_test.dart`

预期：FAIL，组件尚不接受新参数。

- [ ] **步骤 3：让视觉组件显式消费策略**

`DamagePulseBuilder` 和 `ShipHpFrame` 将旧 `mode` 参数替换为 `pulseFilter`，默认 `DamagePulseFilter.all`。`ShipMoraleMark` 新增：

```dart
final bool sparkleEnabled;
// build 内：
if (sparkleEnabled && value >= 50)
  _ShipSparkleLayer(shipId: shipId, animation: sparklePulse),
```

不要用改变 `value` 的方式隐藏星光。

- [ ] **步骤 4：向编队侧组件传递参数**

为编队简报、舰队中心和陆基卡增加 `DamagePulseFilter pulseFilter`；含舰娘 Cond 的组件再增加 `bool moraleSparkleEnabled`。所有内部舰娘卡片和陆基 HP 框必须继续向下传递，默认值保持 `all/true`，避免无关测试大面积破坏。

- [ ] **步骤 5：在应用组合层派生编队侧策略**

`YahagiApp` 顶层 `Listenable.merge` 加入 `safetySettingsController`，确保设置即时刷新。所有编队侧构造使用：

```dart
final effects = widget.safetySettingsController.statusEffects;
final fleetPulse = effects.pulseFilterFor(BattleEffectSurface.fleet);
final fleetSparkle = effects.sparkleFor(BattleEffectSurface.fleet);
```

首页编队卡、舰队中心和陆基卡均传 `fleetPulse`；舰娘卡传 `fleetSparkle`。

- [ ] **步骤 6：运行编队侧测试**

运行：

```powershell
flutter test test/ship_hp_frame_test.dart test/ship_morale_mark_test.dart test/fleet_summary_card_test.dart test/land_base_summary_card_test.dart
```

预期全部 PASS。

- [ ] **步骤 7：提交**

```powershell
git add lib/src/fleet lib/main.dart test/ship_hp_frame_test.dart test/ship_morale_mark_test.dart test/fleet_summary_card_test.dart test/land_base_summary_card_test.dart
git commit -m "feat(编队): 应用受损与士气效果范围"
```

## 任务 5：未卜先知敌我双方显示范围

**文件：**

- 修改：`lib/src/battle/live_battle_card.dart`
- 修改：`lib/src/battle/detailed_battle_panel.dart`
- 修改：`lib/main.dart`
- 修改：`test/live_battle_card_node_test.dart`

- [ ] **步骤 1：编写预测侧范围失败测试**

新增含己方中破和敌方大破的 `LiveBattle`：

```dart
testWidgets('prediction pulse filter applies to both friendly and enemy ships', (tester) async {
  final fixture = LiveBattleCardNodeFixture.withFriendlyAndEnemyDamage(
    friendlyHp: 10,
    friendlyMaxHp: 30,
    enemyHp: 5,
    enemyMaxHp: 30,
  );
  await fixture.pump(tester, pulseFilter: DamagePulseFilter.all);
  expect(find.byKey(const Key('battle-friend-pulse-main-1')), findsOneWidget);
  expect(find.byKey(const Key('battle-enemy-pulse-main-1')), findsOneWidget);

  await fixture.pump(tester, pulseFilter: DamagePulseFilter.off);
  expect(find.byKey(const Key('battle-friend-pulse-main-1')), findsNothing);
  expect(find.byKey(const Key('battle-enemy-pulse-main-1')), findsNothing);
});
```

在 `test/live_battle_card_node_test.dart` 中增加上述 `LiveBattleCardNodeFixture`，内部复用该文件现有的 `BattleController` 测试装配并构造指定敌我 HP。生产组件增加包含 side、fleetRole、position 的稳定 pulse key。

- [ ] **步骤 2：运行预测面板测试并确认失败**

运行：`flutter test test/live_battle_card_node_test.dart`

预期：FAIL，新参数或稳定 key 不存在。

- [ ] **步骤 3：传递预测侧闪烁策略**

把 `LiveBattleCard`、紧凑舰队格和 `DetailedBattlePanel` 的旧 `damagePulseMode` 全部替换为 `DamagePulseFilter pulseFilter`。己方和敌方调用同一个过滤器，不增加 side 特判。

应用组合层使用：

```dart
final predictionPulse = effects.pulseFilterFor(BattleEffectSurface.prediction);
```

只把它传给未卜先知及其详细面板。

- [ ] **步骤 4：验证三种范围**

增加 Widget/壳层测试断言：

- `predictionOnly`：预测敌我有动画，编队无动画；
- `fleetOnly`：预测敌我无动画，编队有动画；
- `all`：两侧均有动画；
- 总开关关闭：两侧均无动画但静态损伤颜色仍存在。

- [ ] **步骤 5：运行战斗视觉测试**

运行：

```powershell
flutter test test/live_battle_card_node_test.dart test/ship_status_style_test.dart
```

预期：全部 PASS。

- [ ] **步骤 6：提交**

```powershell
git add lib/src/battle/live_battle_card.dart lib/src/battle/detailed_battle_panel.dart lib/main.dart test/live_battle_card_node_test.dart
git commit -m "feat(未卜先知): 支持敌我受损闪烁范围"
```

## 任务 6：震动等级过滤和大破安全弹窗解耦

**文件：**

- 修改：`lib/src/battle/battle_damage_alert.dart`
- 修改：`lib/src/battle/battle_controller.dart`
- 修改：`lib/src/capture/battle_result_warning_overlay.dart`
- 修改：`lib/main.dart`
- 修改：`test/battle_controller_test.dart`
- 修改：`test/battle_result_warning_overlay_test.dart`
- 保持：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/BattleDamageVibration.kt`
- 保持或补充：`android/app/src/test/kotlin/app/yahagi/kancollebrowser/BattleDamageVibrationPatternTest.kt`

- [ ] **步骤 1：编写震动四档失败测试**

将现有布尔回调测试改为配置回调，并增加：

```dart
test('moderate-only ignores a direct heavy transition', () {
  final severity = detectFriendlyDamageAlert(
    before: <BattleShipSnapshot>[healthyShip],
    after: <BattleShipSnapshot>[heavyShip],
    filter: DamageVibrationFilter.moderateOnly,
  );
  expect(severity, isNull);
});

test('filters disabled bands before choosing the strongest remaining alert', () {
  final severity = detectFriendlyDamageAlert(
    before: <BattleShipSnapshot>[healthyA, healthyB],
    after: <BattleShipSnapshot>[moderateA, heavyB],
    filter: DamageVibrationFilter.moderateOnly,
  );
  expect(severity, BattleDamageAlertSeverity.moderate);
});
```

覆盖 `off`、`moderateOnly`、`heavyOnly`、`all`，以及同等级继续掉血不提醒。

- [ ] **步骤 2：运行战斗提醒测试并确认失败**

运行：`flutter test test/battle_controller_test.dart test/battle_result_warning_overlay_test.dart`

预期：FAIL，API 仍为布尔开关。

- [ ] **步骤 3：改造战斗提醒检测**

`detectFriendlyDamageAlert` 使用统一 `shipDamageLevel`，先确认 HP 下降且进入更严重等级，再用 `DamageVibrationFilter.allows` 过滤，最后选最严重的已启用提醒。删除私有 `_DamageBand`。

`BattleController` 构造参数改为：

```dart
final BattleStatusEffectSettings Function()? battleStatusEffects;
```

非演习且账本可信时调用 `battleStatusEffects?.call()`，只有 `settings.enabled` 且过滤器允许时才触发端口。

- [ ] **步骤 4：保持弹窗独立，只过滤伴随震动**

`BattleResultWarningOverlay._showPendingWarning` 继续先检查 `BattleWarningMode.off` 决定是否弹窗。震动条件改为：

```dart
if (widget.safetySettingsController.statusEffects
    .vibrates(ShipDamageLevel.heavy)) {
  unawaited(widget.damageAlertPort.alert(
    BattleDamageAlertSeverity.postBattleWarning,
  ));
}
_showWarningDialog();
```

测试必须证明：状态效果关闭或仅中破时仍弹安全框但不震动；大破或全部模式时弹框并震动；大破进击保护关闭时两者都不发生。

- [ ] **步骤 5：验证原生震动模式未回退**

运行：

```powershell
flutter test test/battle_controller_test.dart test/battle_result_warning_overlay_test.dart test/battle_damage_alert_port_test.dart
Set-Location android
.\gradlew.bat testDebugUnitTest --tests "app.yahagi.kancollebrowser.BattleDamageVibrationPatternTest"
Set-Location ..
```

预期：Dart 测试全部 PASS；Kotlin 测试确认中破单次 300 ms、大破双次 255/90/255 ms。

- [ ] **步骤 6：提交**

```powershell
git add lib/src/battle/battle_damage_alert.dart lib/src/battle/battle_controller.dart lib/src/capture/battle_result_warning_overlay.dart lib/main.dart test/battle_controller_test.dart test/battle_result_warning_overlay_test.dart
git commit -m "feat(战斗提示): 按损伤等级过滤震动"
```

## 任务 7：清理旧接口并完成全量验证

**文件：**

- 修改：`lib/src/settings/layout_settings_controller.dart`
- 修改：`lib/src/settings/layout_settings_store.dart`
- 修改：所有仍引用 `enhancedDamagePulse`、`DamagePulseMode`、`battleDamageVibrationEnabled` 的生产代码和测试

- [ ] **步骤 1：扫描旧运行时接口**

运行：

```powershell
rg -n "enhancedDamagePulse|DamagePulseMode|battleDamageVibrationEnabled" lib test
```

预期：只允许 `layout_enhanced_damage_pulse` 旧键字符串和明确的迁移测试存在；生产运行时引用必须为零。

- [ ] **步骤 2：删除旧控制器字段和页面测试残留**

删除 `LayoutSettingsController.enhancedDamagePulse`、setter 和不再需要的抽象存储方法。SharedPreferences 旧键常量作为迁移兼容可以移到安全设置存储中，禁止继续影响 UI。更新构造器和测试替身直到静态分析通过。

- [ ] **步骤 3：格式化和静态分析**

运行：

```powershell
dart format lib test
flutter analyze
```

预期：格式化无未提交的二次漂移；`flutter analyze` 为 0 error。

- [ ] **步骤 4：运行聚焦回归组**

运行：

```powershell
flutter test test/ship_damage_level_test.dart test/settings/battle_status_effect_settings_test.dart test/settings/battle_status_effect_migration_test.dart test/ship_status_style_test.dart test/ship_hp_frame_test.dart test/ship_morale_mark_test.dart test/battle_settings_damage_vibration_test.dart test/screen_settings_damage_pulse_test.dart test/live_battle_card_node_test.dart test/battle_controller_test.dart test/battle_result_warning_overlay_test.dart
```

预期：全部 PASS。

- [ ] **步骤 5：运行完整 Dart 测试套件**

运行：`flutter test`

预期：全部 PASS；若存在与本功能无关的既有失败，记录准确测试名和基线证据，不得静默忽略。

- [ ] **步骤 6：运行 Android 单元测试**

运行：

```powershell
Set-Location android
.\gradlew.bat testDebugUnitTest
Set-Location ..
```

预期：BUILD SUCCESSFUL。

- [ ] **步骤 7：人工适配检查**

对照已批准 Demo 检查：

- 横屏常用宽度下卡片层级、颜色、字号、间距与现有 UI 一致；
- 420 px 窄宽不溢出；
- 总开关关闭后的弱化状态清晰且子选项不丢失；
- 三段范围按钮、两个下拉菜单和两个开关可正常操作；
- 大破进击保护仍独立显示在上方。

- [ ] **步骤 8：提交清理和验证结果**

```powershell
git add lib test android/app/src/test
git commit -m "refactor(战斗提示): 移除旧状态效果接口"
```

- [ ] **步骤 9：检查最终工作树和提交序列**

运行：

```powershell
git status --short
git log -8 --oneline
```

预期：工作树干净；功能由多个职责单一、可回滚的提交组成。

## 规格覆盖自检

- 总开关、显示范围、闪烁五档、震动四档、士气星光开关：任务 1–5。
- 未卜先知敌我双方保持一致：任务 5。
- 编队、舰队中心、陆基卡：任务 4。
- 大破安全弹窗独立、震动受大破过滤：任务 6。
- 疲劳脸、Cond、出击警告和恢复通知不受影响：任务 4 的 Widget 测试。
- 旧键迁移和回退安全：任务 2、7。
- 1:1 UI 与窄屏适配：任务 3、7。
- 完整自动化与 Android 回归：任务 7。
