# 单一 POI 战斗引擎与退避修复实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 修正司令部退避候选被全部计为退避的问题，删除轻量预测模式及其设置入口，并让所有战斗预测只经过 POI 兼容引擎。

**架构：** `GameStateReducer` 只读取 `api_escape_idx` 与 `api_tow_idx` 各自的第一个有效候选，再沿用现有舰队索引映射和去重逻辑。`BattleController` 不再接受运行时模式选择，始终构造 `PoiBattlePredictionEngine`；设置控制器只保留敌方立绘和上次阵形提示开关，并在初始化时清理旧的 `battle.predictionMethod`。旧轻量引擎和通用伤害解析器删除，解析问题类型迁到引擎共享模型。

**技术栈：** Dart 3、Flutter、flutter_test、SharedPreferences、POI battle prediction simulator、Flutter gen-l10n

---

## 文件结构

- 修改 `lib/src/game_state/game_state_reducer.dart`：只选择实际采用的退避舰与拖带舰候选。
- 修改 `test/fcf_retreat_battle_warning_test.dart`：覆盖 E5 联合舰队多候选、七舰队多候选、标量兼容和 `goback_port` 确认。
- 修改 `lib/src/settings/battle_prediction_settings.dart`：删除 `BattlePredictionMethod` 与读写模式接口，初始化时清理旧键；保留两个显示开关。
- 修改 `lib/src/settings/battle_prediction_settings_section.dart`：删除模式标题、分段按钮、推荐语和模式说明，只展示两个现有开关。
- 修改 `lib/main.dart`：停止向 `BattleController` 注入模式读取器。
- 修改 `lib/src/battle/battle_controller.dart`：固定创建 POI 引擎，删除轻量解析器、轻量工厂和模式锁定分支。
- 修改 `lib/src/battle/prediction/battle_prediction_engine.dart`：承载引擎共用的 `BattleParseIssue` 类型。
- 修改 `lib/src/battle/prediction/poi/poi_battle_prediction_engine.dart`：改用共享引擎模型中的解析问题类型。
- 删除 `lib/src/battle/battle_damage_parser.dart`：移除会把友军伤害写到我方的旧通用解析器。
- 删除 `lib/src/battle/prediction/yahagi_battle_prediction_engine.dart`：移除轻量预测运行时。
- 修改 `lib/l10n/app_zh.arb`、`lib/l10n/app_zh_Hant.arb`、`lib/l10n/app_ja.arb`：删除只服务于模式选择器的七组文案。
- 重新生成 `lib/l10n/app_localizations.dart`、`lib/l10n/app_localizations_zh.dart`、`lib/l10n/app_localizations_ja.dart`。
- 修改 `test/battle_prediction_settings_test.dart`：验证旧模式键清理和两个显示开关仍可持久化。
- 修改 `test/battle_prediction_settings_section_test.dart`：验证设置页不再出现模式选择器，两个开关仍可交互。
- 修改 `test/battle_controller_test.dart`：验证控制器固定使用 POI 工厂，并覆盖 NPC 友军阶段不会修改我方血量。
- 修改 `test/battle_controller_damage_control_lifecycle_test.dart`：删除运行时切换模式场景，保留单一 POI 损管账本生命周期断言。
- 修改 `test/battle_poi_corpus_test.dart`：保留 POI 引擎对上游 JS oracle 的全数据集比较，删除 Yahagi 横向比较。
- 删除 `test/battle_damage_parser_test.dart`、`test/yahagi_battle_prediction_engine_test.dart`：随已删除实现一并移除。

### 任务 1：修正退避候选解析

**文件：**
- 修改：`test/fcf_retreat_battle_warning_test.dart`
- 修改：`lib/src/game_state/game_state_reducer.dart:2432-2488`

- [ ] **步骤 1：加入 E5 联合舰队多候选失败用例**

在已有联合舰队夹具中发送以下战果数据，并断言只记录每组首项对应的两艘舰：

```dart
'api_escape_flag': 1,
'api_escape': <String, Object?>{
  'api_escape_idx': <int>[8],
  'api_tow_idx': <int>[9, 10, 11],
},
```

```dart
expect(state.combatState.pendingEscapeShipIds, <int>[202, 203]);
```

- [ ] **步骤 2：修正七舰队候选测试并加入标量兼容用例**

把七舰队 `api_escape_idx: [1, 7]` 的预期改为只取索引 `1`。另用以下旧格式确认标量仍映射为两艘实际退避舰：

```dart
'api_escape_idx': 8,
'api_tow_idx': 9,
```

```dart
expect(state.combatState.pendingEscapeShipIds, <int>[202, 203]);
```

- [ ] **步骤 3：运行回归测试确认旧实现失败**

运行：

```powershell
flutter test test/fcf_retreat_battle_warning_test.dart
```

预期：E5 多候选用例实际得到四艘退避舰，七舰队用例实际得到两个候选，因此测试 FAIL。

- [ ] **步骤 4：实现首个有效候选选择**

在 `GameStateReducer` 中添加局部帮助方法，列表取首个正整数，标量直接读取：

```dart
int firstEscapeIndex(Object? raw) {
  for (final value in _intList(raw)) {
    if (value > 0) return value;
  }
  return _asInt(raw);
}
```

用两个独立结果替换扁平化：

```dart
final indices = <int>[];
final escapeIndex = firstEscapeIndex(rawEscape);
final towIndex = firstEscapeIndex(rawTow);
if (escapeIndex > 0) indices.add(escapeIndex);
if (towIndex > 0) indices.add(towIndex);
```

保留后续普通舰队、联合舰队、七舰队索引映射和 ship id 去重逻辑不变。

- [ ] **步骤 5：运行退避测试确认通过**

运行：

```powershell
flutter test test/fcf_retreat_battle_warning_test.dart
```

预期：全部 PASS；E5 用例在 `goback_port` 前后分别只有两艘 pending/escaped 舰。

- [ ] **步骤 6：提交退避修复**

```powershell
git add lib/src/game_state/game_state_reducer.dart test/fcf_retreat_battle_warning_test.dart
git commit -m "fix(退避): 仅采用实际选择的退避候选"
```

### 任务 2：移除轻量模式设置与持久化选择

**文件：**
- 修改：`test/battle_prediction_settings_test.dart`
- 修改：`test/battle_prediction_settings_section_test.dart`
- 修改：`lib/src/settings/battle_prediction_settings.dart`
- 修改：`lib/src/settings/battle_prediction_settings_section.dart`
- 修改：`lib/l10n/app_zh.arb`
- 修改：`lib/l10n/app_zh_Hant.arb`
- 修改：`lib/l10n/app_ja.arb`
- 生成：`lib/l10n/app_localizations.dart`
- 生成：`lib/l10n/app_localizations_zh.dart`
- 生成：`lib/l10n/app_localizations_ja.dart`

- [ ] **步骤 1：把设置存储测试改为旧键清理契约**

使用 SharedPreferences 测试初值写入旧配置：

```dart
SharedPreferences.setMockInitialValues(<String, Object>{
  'battle.predictionMethod': 'yahagi',
});
final store = SharedPreferencesBattlePredictionSettingsStore();
await store.initialize();
final prefs = await SharedPreferences.getInstance();
expect(prefs.containsKey('battle.predictionMethod'), isFalse);
```

继续保留并验证：

```dart
await controller.setShowEnemyPreviewPortraits(false);
await controller.setShowLastFormationHint(false);
expect(await store.loadShowEnemyPreviewPortraits(), isFalse);
expect(await store.loadShowLastFormationHint(), isFalse);
```

- [ ] **步骤 2：把设置组件测试改为单一模式界面契约**

构建 `BattlePredictionSettingsSection` 后断言：

```dart
expect(find.byType(SegmentedButton), findsNothing);
expect(find.text('轻量模式'), findsNothing);
expect(find.text('增强模式'), findsNothing);
expect(find.byType(SwitchListTile), findsNWidgets(2));
```

点击两个开关并断言 controller/store 更新，证明删除模式入口没有影响敌方立绘和上次阵形提示。

- [ ] **步骤 3：运行设置测试确认旧实现失败**

运行：

```powershell
flutter test test/battle_prediction_settings_test.dart test/battle_prediction_settings_section_test.dart
```

预期：旧 store 没有 `initialize()` 清理契约，UI 仍含分段选择器，因此测试 FAIL 或编译失败。

- [ ] **步骤 4：删除模式枚举和模式读写接口**

把 store 接口收敛为：

```dart
abstract interface class BattlePredictionSettingsStore {
  Future<void> initialize();
  Future<bool> loadShowEnemyPreviewPortraits();
  Future<void> saveShowEnemyPreviewPortraits(bool value);
  Future<bool> loadShowLastFormationHint();
  Future<void> saveShowLastFormationHint(bool value);
}
```

SharedPreferences 实现的初始化只清理旧键：

```dart
static const _legacyPredictionMethodKey = 'battle.predictionMethod';

@override
Future<void> initialize() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_legacyPredictionMethodKey);
}
```

内存实现同步删除 `_method`、`load()`、`save()`；controller 初始化先调用 `store.initialize()`，清理异常按项目既有容错方式处理，不阻断两个显示开关的读取。

- [ ] **步骤 5：删除设置页模式控件**

将 `BattlePredictionSettingsSection` 的 `build` 内容收敛为现有两个 `SwitchListTile`，删除 `SegmentedButton<BattlePredictionMethod>`、推荐语和模式说明。保留现有图标、间距、字体和 divider，使 UI 与当前设置页风格一致。

- [ ] **步骤 6：删除模式专属本地化键并重新生成**

从三个 ARB 删除：

```text
battlePredictionEngine
battlePredictionRecommendation
battlePredictionHighAccuracy
battlePredictionLightweight
battlePredictionHighAccuracyDesc
battlePredictionLightweightDesc
battlePredictionNextBattle
```

运行：

```powershell
flutter gen-l10n
```

预期：命令退出码 0，生成的三个 Dart 本地化文件不再暴露上述 getter。

- [ ] **步骤 7：运行设置测试确认通过**

运行：

```powershell
flutter test test/battle_prediction_settings_test.dart test/battle_prediction_settings_section_test.dart
```

预期：全部 PASS。

- [ ] **步骤 8：提交设置清理**

```powershell
git add lib/src/settings/battle_prediction_settings.dart lib/src/settings/battle_prediction_settings_section.dart lib/l10n test/battle_prediction_settings_test.dart test/battle_prediction_settings_section_test.dart
git commit -m "refactor(战斗): 移除轻量预测模式设置"
```

### 任务 3：控制器固定使用 POI 引擎

**文件：**
- 修改：`test/battle_controller_test.dart`
- 修改：`test/battle_controller_damage_control_lifecycle_test.dart`
- 修改：`lib/src/battle/battle_controller.dart`
- 修改：`lib/main.dart`

- [ ] **步骤 1：用固定 POI 工厂测试替换模式切换测试**

构造 controller 时只注入 `poiEngineFactory`，记录构造次数：

```dart
var poiFactoryCalls = 0;
final controller = BattleController(
  gameState: () => state,
  poiEngineFactory: ({
    required friendMain,
    required friendEscort,
    required enemyMain,
    required enemyEscort,
    required fleetType,
  }) {
    poiFactoryCalls += 1;
    return PoiBattlePredictionEngine(
      friendMain: friendMain,
      friendEscort: friendEscort,
      enemyMain: enemyMain,
      enemyEscort: enemyEscort,
      fleetType: fleetType,
    );
  },
);
```

连续处理两场战斗，断言 `poiFactoryCalls == 2`，且构造函数不再提供 `predictionMethod` 与 `yahagiEngineFactory`。

- [ ] **步骤 2：加入友军阶段我方 HP 隔离测试**

发送包含 NPC 友军夜战的 E4 风格包，其中 `api_friendly_battle.api_hougeki.api_damage` 有非零值；处理后断言：

```dart
expect(controller.current!.friendMain.first.currentHp, 30);
expect(controller.current!.enemyMain.first.currentHp, lessThan(50));
```

再验证 `GameStateController.applyFriendlyBattleHp` 没有收到把我方舰娘降血的发布结果。

- [ ] **步骤 3：运行控制器测试确认接口与行为约束生效**

运行：

```powershell
flutter test test/battle_controller_test.dart test/battle_controller_damage_control_lifecycle_test.dart
```

预期：旧控制器仍要求或接受模式分支，更新后的测试编译失败；友军隔离测试用于锁定 POI 行为。

- [ ] **步骤 4：删除控制器中的模式分支**

从构造函数和字段删除：

```dart
BattleDamageParser? damageParser
BattlePredictionMethod Function()? predictionMethod
BattlePredictionEngineFactory? yahagiEngineFactory
BattlePredictionMethod? _predictionEngineMethod
```

把引擎创建收敛为：

```dart
BattlePredictionEngine _createPredictionEngine({
  required List<BattleShipSnapshot> friendMain,
  required List<BattleShipSnapshot> friendEscort,
  required List<BattleShipSnapshot> enemyMain,
  required List<BattleShipSnapshot> enemyEscort,
}) {
  final factory = poiEngineFactory;
  if (factory != null) {
    return factory(
      friendMain: friendMain,
      friendEscort: friendEscort,
      enemyMain: enemyMain,
      enemyEscort: enemyEscort,
      fleetType: _context.combinedFleetType.apiValue,
    );
  }
  return PoiBattlePredictionEngine(
    friendMain: friendMain,
    friendEscort: friendEscort,
    enemyMain: enemyMain,
    enemyEscort: enemyEscort,
    fleetType: _context.combinedFleetType.apiValue,
  );
}
```

所有损管账本可信度、HP 发布和战斗结束判断直接按 POI 路径执行，不再检查 `_predictionEngineMethod`。

- [ ] **步骤 5：删除 main 中的模式注入**

从 `BattleController(...)` 调用删除：

```dart
predictionMethod: () => battlePredictionSettingsController.method,
```

设置 controller 仍由应用持有，供敌方立绘和上次阵形提示开关使用。

- [ ] **步骤 6：运行控制器与应用壳测试确认通过**

运行：

```powershell
flutter test test/battle_controller_test.dart test/battle_controller_damage_control_lifecycle_test.dart test/prototype_shell_test.dart
```

预期：全部 PASS，且 `rg "BattlePredictionMethod|predictionMethod|yahagiEngineFactory" lib test` 只剩待删除旧引擎测试中的引用。

- [ ] **步骤 7：提交单一引擎接线**

```powershell
git add lib/main.dart lib/src/battle/battle_controller.dart test/battle_controller_test.dart test/battle_controller_damage_control_lifecycle_test.dart test/prototype_shell_test.dart
git commit -m "refactor(战斗): 固定使用 POI 预测引擎"
```

### 任务 4：删除旧轻量预测实现并保留 POI oracle 回归

**文件：**
- 修改：`lib/src/battle/prediction/battle_prediction_engine.dart`
- 修改：`lib/src/battle/prediction/poi/poi_battle_prediction_engine.dart`
- 删除：`lib/src/battle/battle_damage_parser.dart`
- 删除：`lib/src/battle/prediction/yahagi_battle_prediction_engine.dart`
- 删除：`test/battle_damage_parser_test.dart`
- 删除：`test/yahagi_battle_prediction_engine_test.dart`
- 修改：`test/battle_poi_corpus_test.dart`

- [ ] **步骤 1：把解析问题类型迁入共享模型**

在 `battle_prediction_engine.dart` 定义：

```dart
class BattleParseIssue {
  const BattleParseIssue({
    required this.phase,
    required this.message,
  });

  final String phase;
  final String message;
}
```

保持 `BattlePrediction.issues` 的类型为 `List<BattleParseIssue>`，POI 引擎仅导入共享模型。

- [ ] **步骤 2：删除旧实现及其单元测试**

删除四个文件：

```text
lib/src/battle/battle_damage_parser.dart
lib/src/battle/prediction/yahagi_battle_prediction_engine.dart
test/battle_damage_parser_test.dart
test/yahagi_battle_prediction_engine_test.dart
```

- [ ] **步骤 3：把数据集测试收敛为 POI 对上游 oracle**

从 `battle_poi_corpus_test.dart` 删除 Yahagi import、构造和结果比较；保留每个 fixture 的 POI Dart 结果与 `poooi/lib-battle` JS oracle 的主/随伴、我/敌 HP 和损管结果逐项断言。

- [ ] **步骤 4：运行静态引用扫描**

运行：

```powershell
rg -n "BattleDamageParser|YahagiBattlePredictionEngine|BattlePredictionMethod|battlePredictionLightweight|battlePredictionHighAccuracy" lib test
```

预期：退出码 1 且无输出，表示运行时代码、测试和本地化生成代码都没有轻量模式残留。

- [ ] **步骤 5：运行核心战斗测试**

运行：

```powershell
flutter test test/poi_battle_prediction_engine_test.dart test/battle_controller_test.dart test/battle_controller_damage_control_lifecycle_test.dart
```

预期：全部 PASS。

- [ ] **步骤 6：提交旧代码删除**

```powershell
git add -A lib/src/battle test/battle_damage_parser_test.dart test/yahagi_battle_prediction_engine_test.dart test/battle_poi_corpus_test.dart
git commit -m "refactor(战斗): 删除旧轻量预测实现"
```

### 任务 5：完整验证、审核与 master 收口

**文件：**
- 验证：`test/fcf_retreat_battle_warning_test.dart`
- 验证：`test/poi_battle_prediction_engine_test.dart`
- 验证：`test/battle_controller_test.dart`
- 验证：`test/battle_controller_damage_control_lifecycle_test.dart`
- 验证：`test/battle_prediction_settings_test.dart`
- 验证：`test/battle_prediction_settings_section_test.dart`
- 验证：`test/battle_poi_corpus_test.dart`

- [ ] **步骤 1：运行定向问题回归**

```powershell
flutter test test/fcf_retreat_battle_warning_test.dart test/poi_battle_prediction_engine_test.dart test/battle_controller_test.dart test/battle_controller_damage_control_lifecycle_test.dart test/battle_prediction_settings_test.dart test/battle_prediction_settings_section_test.dart
```

预期：全部 PASS，覆盖多候选退避、友军舰队隔离、损管生命周期和设置入口删除。

- [ ] **步骤 2：运行完整 POI 战斗数据集**

```powershell
$env:YAHAGI_POI_BATTLE_FIXTURES='G:\kancolle project\.reference\poi-battle-fixtures'
$env:YAHAGI_POI_LIB_BATTLE='G:\kancolle project\.reference\poi-lib-battle-source'
flutter test test/battle_poi_corpus_test.dart
```

如果仓库中的实际 fixture/oracle 环境变量名称或目录由测试文件指定，则使用测试文件读取的两个精确路径运行。预期：304 个 fixture、366 个 battle packet 全部与 POI oracle 一致；输出中无 mismatch。

- [ ] **步骤 3：运行静态分析与全量测试**

```powershell
flutter analyze
flutter test
```

预期：`flutter analyze` 为 `No issues found!`，全量测试退出码 0。

- [ ] **步骤 4：审核 diff 和提交边界**

```powershell
git status --short
git diff HEAD~4 --check
git diff HEAD~4 --stat
git log -5 --oneline
```

预期：无未提交文件、`git diff --check` 无空白错误、提交只包含退避修复、单一 POI 引擎和对应测试/文案变更。

- [ ] **步骤 5：确认 master 已包含全部通过审核的提交**

```powershell
git branch --show-current
git status --short --branch
```

预期：当前分支为 `master`，工作区 clean。用户已明确授权直接在 master 修改，因此不创建额外合并提交。
