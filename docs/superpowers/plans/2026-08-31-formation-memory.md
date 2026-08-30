# 未卜先知节点阵形记忆实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在未卜先知导航头部显示同一海域节点上次选择的阵形，并跨应用重启保存记录。

**架构：** 新增独立 `FormationMemoryStore` 与内存缓存控制器；`BattleController` 只通过控制器查询和写入节点阵形，并把历史值投影到 `LiveBattle`。显示开关沿用战斗预测设置体系，紧凑与完整导航头部复用同一提示组件。

**技术栈：** Flutter/Dart、`shared_preferences`、Flutter Test、ARB 本地化生成。

---

## 文件结构

- 创建 `lib/src/battle/formation_memory.dart`：节点键、合法阵形判断、存储接口、SharedPreferences 实现、内存实现与缓存控制器。
- 创建 `test/formation_memory_test.dart`：持久化解析、节点隔离、重复写入和写入顺序测试。
- 修改 `lib/src/settings/battle_prediction_settings.dart`：增加显示开关的存储与控制器状态。
- 修改 `lib/src/settings/battle_prediction_settings_section.dart`：渲染默认开启的阵形提示开关。
- 修改 `test/battle_prediction_settings_test.dart` 与 `test/battle_prediction_settings_section_test.dart`：设置读写及界面测试。
- 修改 `lib/src/battle/battle_models.dart`：为导航态增加 `lastFormation`。
- 修改 `lib/src/battle/battle_controller.dart`：到点读取、战果后写入阵形记忆。
- 修改 `test/battle_controller_test.dart`：数据流与边界测试。
- 修改 `lib/src/battle/live_battle_card.dart` 与 `lib/src/battle/detailed_battle_panel.dart`：在 A 位置显示提示标签。
- 修改 `test/live_battle_card_node_test.dart`：紧凑、完整、首次、联合舰队与开战隐藏测试。
- 修改 `lib/l10n/app_zh.arb`、`lib/l10n/app_zh_Hant.arb`、`lib/l10n/app_ja.arb`：设置项及标签文案。
- 修改生成的 `lib/l10n/app_localizations*.dart`：由 `flutter gen-l10n` 更新。
- 修改 `lib/main.dart`：启动时加载阵形控制器并向战斗控制器、界面传入设置状态。

### 任务 1：阵形记忆存储与缓存控制器

**文件：**
- 创建：`lib/src/battle/formation_memory.dart`
- 测试：`test/formation_memory_test.dart`

- [ ] **步骤 1：编写失败的存储与控制器测试**

```dart
test('shared preferences store ignores invalid entries', () async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'battle.formationMemory': '{"1-1-3":5,"bad":5,"1-1-4":99}',
  });
  final values = await SharedPreferencesFormationMemoryStore().load();
  expect(values, <String, int>{'1-1-3': 5});
});

test('controller isolates nodes and skips duplicate saves', () async {
  final store = MemoryFormationMemoryStore(<String, int>{'1-1-3': 5});
  final controller = await FormationMemoryController.load(store);
  expect(controller.formationFor(mapAreaId: 1, mapInfoNo: 1, node: 3), 5);
  expect(controller.formationFor(mapAreaId: 1, mapInfoNo: 1, node: 4), isNull);
  await controller.remember(mapAreaId: 1, mapInfoNo: 1, node: 3, formation: 5);
  expect(store.saveCount, 0);
});
```

- [ ] **步骤 2：运行测试验证因类型缺失而失败**

运行：`flutter test test/formation_memory_test.dart`

预期：FAIL，编译器报告 `SharedPreferencesFormationMemoryStore`、`FormationMemoryController` 未定义。

- [ ] **步骤 3：实现最小存储与缓存控制器**

```dart
const validFormationIds = <int>{1, 2, 3, 4, 5, 6, 11, 12, 13, 14};

String formationMemoryKey({required int mapAreaId, required int mapInfoNo, required int node}) =>
    '$mapAreaId-$mapInfoNo-$node';

abstract interface class FormationMemoryStore {
  Future<Map<String, int>> load();
  Future<void> save(Map<String, int> formations);
}

final class FormationMemoryController {
  FormationMemoryController._(this._store, this._formations);
  final FormationMemoryStore _store;
  final Map<String, int> _formations;
  Future<void> _pendingSave = Future<void>.value();

  static Future<FormationMemoryController> load(FormationMemoryStore store) async =>
      FormationMemoryController._(store, Map<String, int>.from(await store.load()));

  int? formationFor({required int mapAreaId, required int mapInfoNo, required int node}) =>
      _formations[formationMemoryKey(mapAreaId: mapAreaId, mapInfoNo: mapInfoNo, node: node)];

  Future<void> remember({required int mapAreaId, required int mapInfoNo, required int node, required int formation}) {
    if (!validFormationIds.contains(formation) || mapAreaId <= 0 || mapInfoNo <= 0 || node <= 0) {
      return Future<void>.value();
    }
    final key = formationMemoryKey(mapAreaId: mapAreaId, mapInfoNo: mapInfoNo, node: node);
    if (_formations[key] == formation) return Future<void>.value();
    _formations[key] = formation;
    final snapshot = Map<String, int>.unmodifiable(_formations);
    return _pendingSave = _pendingSave.then((_) => _store.save(snapshot));
  }
}
```

SharedPreferences 实现以 `battle.formationMemory` 保存 JSON；解析时只接收合法三段正整数键和支持的阵形值。内存实现公开 `saveCount` 和不可变快照供测试断言。

- [ ] **步骤 4：运行测试验证通过**

运行：`flutter test test/formation_memory_test.dart`

预期：PASS，输出 `All tests passed!`。

- [ ] **步骤 5：提交存储层**

```powershell
git add lib/src/battle/formation_memory.dart test/formation_memory_test.dart
git commit -m "feat(未卜先知): 添加节点阵形记忆存储"
```

### 任务 2：阵形提示设置

**文件：**
- 修改：`lib/src/settings/battle_prediction_settings.dart`
- 修改：`lib/src/settings/battle_prediction_settings_section.dart`
- 修改：`lib/l10n/app_zh.arb`
- 修改：`lib/l10n/app_zh_Hant.arb`
- 修改：`lib/l10n/app_ja.arb`
- 修改：`test/battle_prediction_settings_test.dart`
- 修改：`test/battle_prediction_settings_section_test.dart`

- [ ] **步骤 1：编写失败的设置测试**

```dart
test('missing last formation hint setting defaults to enabled', () async {
  final store = SharedPreferencesBattlePredictionSettingsStore();
  expect(await store.loadLastFormationHintEnabled(), isTrue);
});

test('controller persists last formation hint visibility', () async {
  final store = MemoryBattlePredictionSettingsStore();
  final controller = await BattlePredictionSettingsController.load(store);
  await controller.setLastFormationHintEnabled(false);
  expect(controller.lastFormationHintEnabled, isFalse);
  expect(await store.loadLastFormationHintEnabled(), isFalse);
});
```

组件测试断言 `Key('battle-last-formation-hint')` 的开关默认开启，点击后控制器与内存存储均为 `false`。

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/battle_prediction_settings_test.dart test/battle_prediction_settings_section_test.dart`

预期：FAIL，报告新增设置方法、属性和控件不存在。

- [ ] **步骤 3：实现设置存储、控制器和界面**

为 `BattlePredictionSettingsStore` 增加：

```dart
Future<bool> loadLastFormationHintEnabled();
Future<void> saveLastFormationHintEnabled(bool enabled);
```

SharedPreferences 键使用 `battle.lastFormationHintEnabled`，缺失时返回 `true`。控制器增加 `lastFormationHintEnabled` 与 `setLastFormationHintEnabled()`。设置页在敌方头像开关之后增加分隔线与 `buildSwitchTile`，标题和说明分别使用新增本地化键：

```json
"battleLastFormationHint": "显示上次选择的阵形",
"battleLastFormationHintDesc": "到达出击节点时，在未卜先知中提示该点上次使用的阵形。"
```

繁体与日文提供等义文本，然后执行 `flutter gen-l10n`。

- [ ] **步骤 4：运行设置测试验证通过**

运行：`flutter test test/battle_prediction_settings_test.dart test/battle_prediction_settings_section_test.dart test/settings_localization_test.dart`

预期：PASS。

- [ ] **步骤 5：提交设置功能**

```powershell
git add lib/src/settings/battle_prediction_settings.dart lib/src/settings/battle_prediction_settings_section.dart lib/l10n test/battle_prediction_settings_test.dart test/battle_prediction_settings_section_test.dart
git commit -m "feat(设置): 添加上次阵形提示开关"
```

### 任务 3：战斗数据流集成

**文件：**
- 修改：`lib/src/battle/battle_models.dart`
- 修改：`lib/src/battle/battle_controller.dart`
- 修改：`test/battle_controller_test.dart`

- [ ] **步骤 1：编写失败的数据流测试**

```dart
test('map navigation exposes the remembered formation for the node', () async {
  final memory = await FormationMemoryController.load(
    MemoryFormationMemoryStore(<String, int>{'1-1-1': 5}),
  );
  final controller = BattleController(gameState: () => state, formationMemory: memory);
  controller.accept(mapStartEvent);
  await controller.idle;
  expect(controller.current!.lastFormation, 5);
});

test('battle result remembers the confirmed friendly formation', () async {
  final store = MemoryFormationMemoryStore();
  final memory = await FormationMemoryController.load(store);
  final controller = BattleController(gameState: () => state, formationMemory: memory);
  controller..accept(mapStartEvent)..accept(dayBattleEvent)..accept(battleResultEvent);
  await controller.idle;
  expect(memory.formationFor(mapAreaId: 1, mapInfoNo: 1, node: 1), 1);
});
```

另加测试验证演习不写入、非法阵形不覆盖有效历史，以及进入战斗后的 `LiveBattle.lastFormation` 为空。

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/battle_controller_test.dart --plain-name "formation memory"`

预期：FAIL，报告 `formationMemory` 参数和 `lastFormation` 字段不存在。

- [ ] **步骤 3：实现最小数据流**

`LiveBattle` 增加 `int? lastFormation` 并在 `copyWith` 保留。`BattleController` 增加可空 `FormationMemoryController? formationMemory`：

```dart
final remembered = formationMemory?.formationFor(
  mapAreaId: _context.mapAreaId,
  mapInfoNo: _context.mapInfoNo,
  node: _context.node,
);
```

仅在 `_mapPaths` 构造导航态 `LiveBattle` 时设置 `lastFormation: remembered`。战斗阶段新建 `LiveBattle` 时不传历史值。`_applyResult` 确认非演习且 `friendFormation` 合法后调用 `unawaited(formationMemory!.remember(...).catchError(...))`，存储错误写入 `debugPrint`，不影响事件队列。

- [ ] **步骤 4：运行数据流测试验证通过**

运行：`flutter test test/battle_controller_test.dart`

预期：PASS。

- [ ] **步骤 5：提交战斗数据流**

```powershell
git add lib/src/battle/battle_models.dart lib/src/battle/battle_controller.dart test/battle_controller_test.dart
git commit -m "feat(未卜先知): 关联节点与上次阵形"
```

### 任务 4：导航头部 A 位置标签

**文件：**
- 修改：`lib/src/battle/live_battle_card.dart`
- 修改：`lib/src/battle/detailed_battle_panel.dart`
- 修改：`lib/l10n/app_zh.arb`
- 修改：`lib/l10n/app_zh_Hant.arb`
- 修改：`lib/l10n/app_ja.arb`
- 修改：`test/live_battle_card_node_test.dart`

- [ ] **步骤 1：编写失败的组件测试**

构造带 `lastFormation: 5` 的导航态并断言完整、紧凑两种模式均出现 `Key('battle-last-formation-pill')` 和“上次：单横阵”。构造 `lastFormation: 14` 的联合舰队并断言“上次：第四警戒”。进入战斗态后断言该 Key 不存在；`showLastFormationHint: false` 时同样不存在。

- [ ] **步骤 2：运行组件测试验证失败**

运行：`flutter test test/live_battle_card_node_test.dart --plain-name "last formation"`

预期：FAIL，报告组件参数或标签 Key 不存在。

- [ ] **步骤 3：实现共享标签并接入两个导航头部**

在 `battle_pills.dart` 增加公开组件：

```dart
class LastFormationPill extends StatelessWidget {
  const LastFormationPill({super.key, required this.formation});
  final int formation;
  @override
  Widget build(BuildContext context) => MetaChip(
    key: const Key('battle-last-formation-pill'),
    label: AppLocalizations.of(context)!.battleLastFormation(formationLabel(formation)),
    color: const Color(0xffffc95c),
  );
}
```

为 ARB 增加带参数的 `battleLastFormation` 文案：简体 `上次：{formation}`、繁体 `上次：{formation}`、日文 `前回：{formation}`，并执行 `flutter gen-l10n`。

`LiveBattleCard` 增加 `showLastFormationHint`，向紧凑面板传递；`DetailedBattlePanel` 增加同名参数。两个导航头部仅在开关开启且 `battle.lastFormation` 为合法值时把 `LastFormationPill` 插入节点类型标签之前。

- [ ] **步骤 4：运行组件与本地化测试验证通过**

运行：`flutter test test/live_battle_card_node_test.dart test/settings_localization_test.dart`

预期：PASS，无 overflow 异常。

- [ ] **步骤 5：提交界面**

```powershell
git add lib/src/battle/battle_pills.dart lib/src/battle/live_battle_card.dart lib/src/battle/detailed_battle_panel.dart lib/l10n test/live_battle_card_node_test.dart
git commit -m "feat(未卜先知): 显示节点上次阵形"
```

### 任务 5：启动接线、格式化与整体验证

**文件：**
- 修改：`lib/main.dart`
- 修改：`test/prototype_shell_test.dart`（仅当构造签名测试需要显式覆盖）

- [ ] **步骤 1：编写失败的启动接线测试或静态断言**

在现有壳层测试中使用 `MemoryBattlePredictionSettingsStore` 将提示关闭，泵入导航态后断言 `battle-last-formation-pill` 不出现；开启后重新泵入并断言出现。若现有壳层构造无法注入阵形记忆，则增加最小测试构造参数而不改生产行为。

- [ ] **步骤 2：运行壳层测试验证失败**

运行：`flutter test test/prototype_shell_test.dart --plain-name "last formation"`

预期：FAIL，提示启动接线尚未传递设置或阵形控制器。

- [ ] **步骤 3：接入应用启动与信息面板**

在 `main()` 中加载：

```dart
final formationMemoryController = await FormationMemoryController.load(
  SharedPreferencesFormationMemoryStore(),
);
```

构造 `BattleController` 时传入 `formationMemory: formationMemoryController`。`_InformationPanel` 已监听 `BattlePredictionSettingsController`，因此构造 `LiveBattleCard` 时补充：

```dart
showLastFormationHint:
    widget.battlePredictionSettingsController?.lastFormationHintEnabled ?? true,
```

- [ ] **步骤 4：格式化并运行定向验证**

运行：

```powershell
dart format lib/src/battle/formation_memory.dart lib/src/battle/battle_models.dart lib/src/battle/battle_controller.dart lib/src/battle/battle_pills.dart lib/src/battle/live_battle_card.dart lib/src/battle/detailed_battle_panel.dart lib/src/settings/battle_prediction_settings.dart lib/src/settings/battle_prediction_settings_section.dart lib/main.dart test/formation_memory_test.dart test/battle_prediction_settings_test.dart test/battle_prediction_settings_section_test.dart test/battle_controller_test.dart test/live_battle_card_node_test.dart test/prototype_shell_test.dart
flutter analyze
flutter test test/formation_memory_test.dart test/battle_prediction_settings_test.dart test/battle_prediction_settings_section_test.dart test/battle_controller_test.dart test/live_battle_card_node_test.dart test/prototype_shell_test.dart test/settings_localization_test.dart
```

预期：`flutter analyze` 无问题；所有定向测试通过。

- [ ] **步骤 5：运行全量回归**

运行：`flutter test`

预期：与基线一致，`1890` 项以上通过、`7` 项跳过、`0` 失败。

- [ ] **步骤 6：提交启动接线**

```powershell
git add lib/main.dart test/prototype_shell_test.dart
git commit -m "feat(未卜先知): 启用持久化阵形提示"
```

- [ ] **步骤 7：审核与合并准备**

运行：

```powershell
git status --short
git log --oneline master..HEAD
git diff --check master...HEAD
git diff --stat master...HEAD
```

预期：工作区干净，`git diff --check` 无输出。随后使用 requesting-code-review 技能审核变更；审核无阻塞问题后使用 finishing-a-development-branch 技能合并到 `master`。
