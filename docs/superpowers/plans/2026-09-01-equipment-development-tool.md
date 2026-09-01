# 装备开发工具实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在 Yahagi 工具箱中实现原生、离线、可测试的装备开发正向试算与反向配方功能。

**架构：** 构建阶段把授权参考数据转换为带来源元数据的紧凑快照；运行时由 Repository 一次加载并校验。纯 Dart 计算核心负责池匹配、概率叠加、配方反推与装备启用集合，`ChangeNotifier` 控制器管理交互状态，Flutter 页面只负责响应式展示和弹窗。

**技术栈：** Dart 3、Flutter Material、`dart:convert`、现有 `GameState`、Flutter ARB 本地化、`flutter_test`。

---

## 文件结构

### 数据生成

- 创建 `tool/development_data/development_snapshot_builder.dart`：解析授权源数据、展开秘书舰池、校验交叉引用并生成稳定快照。
- 创建 `tool/development_data/sync.dart`：命令行入口，读取固定参考仓库并写入快照。
- 创建 `test/development/development_snapshot_builder_test.dart`：生成器结构、展开规则、稳定性和拒绝非法数据测试。
- 创建 `assets/data/development/development_snapshot.json`：应用内置的正式离线快照。
- 修改 `pubspec.yaml`：注册装备开发数据资产目录。

### 运行时数据与算法

- 创建 `lib/src/development/development_resources.dart`：四项资源值对象与池类型枚举。
- 创建 `lib/src/development/development_dataset.dart`：快照模型、JSON 解析和运行时校验。
- 创建 `lib/src/development/development_repository.dart`：内置快照加载与缓存。
- 创建 `lib/src/development/development_pool_matcher.dart`：兼容池查找、概率合并和正向计算。
- 创建 `lib/src/development/development_recipe_calculator.dart`：最低配方生成、反向枚举和结果排序。
- 创建 `lib/src/development/development_projection.dart`：装备分组、启用集合和显示投影。
- 创建 `test/development/development_dataset_test.dart`：运行时解析与校验测试。
- 创建 `test/development/development_pool_matcher_test.dart`：正向计算测试。
- 创建 `test/development/development_recipe_calculator_test.dart`：反向计算测试。
- 创建 `test/development/development_projection_test.dart`：分组与启用集合测试。
- 创建 `test/development/development_reference_regression_test.dart`：授权参考数据的固定数值回归测试。

### 状态与 UI

- 创建 `lib/src/development/equipment_development_controller.dart`：页面状态、当前旗舰同步、资源提交、目标选择和排序。
- 创建 `lib/src/development/equipment_development_page.dart`：A「指挥仪表盘」响应式页面。
- 创建 `lib/src/development/development_equipment_picker.dart`：底部装备选择面板、类型筛选和搜索按钮。
- 创建 `lib/src/development/development_recipe_table.dart`：推荐配方表、排序和点击回填。
- 创建 `test/development/equipment_development_controller_test.dart`：控制器状态测试。
- 创建 `test/development/equipment_development_page_test.dart`：页面、弹窗、响应式和回填 Widget 测试。

### 集成与说明

- 修改 `lib/src/toolbox/toolbox_page.dart`：将 `other` 模式替换为 `equipmentDevelopment` 并接入页面。
- 修改 `lib/src/toolbox/toolbox_mode_tabs.dart`：显示「装备开发」标签。
- 修改 `lib/main.dart`：初始化并传递 Repository / Controller 所需依赖。
- 修改 `lib/l10n/app_zh.arb`、`lib/l10n/app_zh_Hant.arb`、`lib/l10n/app_ja.arb`：新增装备开发 UI 文案。
- 修改 `assets/data/THIRD_PARTY_DATA.md`：记录参考仓库、固定提交、授权范围和 UI 限制。
- 修改 `test/toolbox_page_test.dart`、`test/prototype_shell_test.dart`、`test/workspace_context_header_test.dart`：更新工具箱模式断言。

## 任务 1：建立可重复的数据快照生成器

**文件：**

- 创建：`tool/development_data/development_snapshot_builder.dart`
- 创建：`tool/development_data/sync.dart`
- 创建：`test/development/development_snapshot_builder_test.dart`

- [ ] **步骤 1：编写失败的生成器测试**

测试必须使用最小内存夹具覆盖舰种、舰级、舰名、直接舰 ID、排除舰 ID、最低资源、负池和池名三语言映射：

```dart
test('builder expands ship selectors and emits deterministic records', () {
  Map<String, Object?> build() => buildDevelopmentSnapshot(
    pools: fixturePools,
    start2: fixtureStart2,
    ctypeNames: const {'1': '綾波型'},
    poolLabels: const {
      '水雷系-测试': {'zh': '水雷系-测试', 'zh_Hant': '水雷系-測試', 'ja': '水雷系-テスト'},
    },
    source: const DevelopmentSourceMetadata(
      repository: 'https://github.com/SkywalkerJi/kc-development-tools',
      commit: 'd065120',
      hashes: {'DevelopmentPool.json': 'abc'},
    ),
    generatedAt: DateTime.utc(2026, 9, 1),
  );
  final output = build();

  expect(output['schema_version'], 1);
  final pools = output['pools'] as List<Object?>;
  expect((pools.single as Map)['ship_ids'], [1, 2]);
  expect(jsonEncode(output), equals(jsonEncode(build())));
});
```

- [ ] **步骤 2：运行测试并确认失败**

运行：

```powershell
flutter test test/development/development_snapshot_builder_test.dart
```

预期：FAIL，提示 `development_snapshot_builder.dart` 或 `buildDevelopmentSnapshot` 不存在。

- [ ] **步骤 3：实现生成器的最小完整接口**

生成器公开以下接口，并对输出数组与 Map 键执行稳定排序：

```dart
class DevelopmentSourceMetadata {
  const DevelopmentSourceMetadata({
    required this.repository,
    required this.commit,
    required this.hashes,
  });
  final String repository;
  final String commit;
  final Map<String, String> hashes;
}

Map<String, Object?> buildDevelopmentSnapshot({
  required List<Object?> pools,
  required Map<String, Object?> start2,
  required Map<String, String> ctypeNames,
  required Map<String, Map<String, String>> poolLabels,
  required DevelopmentSourceMetadata source,
  required DateTime generatedAt,
});
```

`buildDevelopmentSnapshot` 必须拒绝空池、未知装备 ID、资源数组长度不为 4、缺失池名翻译和重复的「池名 + 池 ID」组合。

- [ ] **步骤 4：实现命令行同步入口**

`sync.dart` 接受以下参数并在写入前完成源仓库提交读取与 SHA-256 计算：

```powershell
dart run tool/development_data/sync.dart `
  --source-dir "$env:TEMP\kc-development-tools-analysis" `
  --output assets/data/development/development_snapshot.json
```

未指定参数、源目录缺文件或 Git 提交不可解析时返回非 0 退出码，并打印缺失文件的精确路径。

- [ ] **步骤 5：运行生成器测试并确认通过**

运行：

```powershell
dart format tool/development_data test/development/development_snapshot_builder_test.dart
flutter test test/development/development_snapshot_builder_test.dart
```

预期：PASS，且重复运行测试得到字节稳定的 JSON。

- [ ] **步骤 6：提交生成器**

```powershell
git add tool/development_data test/development/development_snapshot_builder_test.dart
git commit -m "feat(装备开发): 添加离线数据快照生成器"
```

## 任务 2：生成并登记正式离线快照

**文件：**

- 创建：`assets/data/development/development_snapshot.json`
- 修改：`pubspec.yaml`

- [ ] **步骤 1：固定授权参考仓库版本**

确认源目录满足：

```powershell
git -C "$env:TEMP\kc-development-tools-analysis" rev-parse --short HEAD
```

预期：输出 `d065120`。若远端已有用户明确要求的新提交，先更新设计数据版本和回归夹具，不静默换源。

- [ ] **步骤 2：运行同步工具生成快照**

```powershell
dart run tool/development_data/sync.dart `
  --source-dir "$env:TEMP\kc-development-tools-analysis" `
  --output assets/data/development/development_snapshot.json
```

预期摘要必须列出 99 个池记录、45 个可选池、46 个已本地化池名、102 件可开发装备、2 个负池和 2 个最低资源池。「空母系-陆攻」只用于特殊门槛记录，不单独出现在秘书舰池选择器中。

- [ ] **步骤 3：注册资产目录**

在 `pubspec.yaml` 的 `flutter.assets` 中增加：

```yaml
    - assets/data/development/
```

- [ ] **步骤 4：验证生成结果可重复**

连续运行同步命令 2 次后执行：

```powershell
git diff --exit-code -- assets/data/development/development_snapshot.json
```

预期：第 2 次生成不产生差异。生成时间使用源提交的提交时间或由命令显式传入，不能每次使用当前时钟破坏稳定性。

- [ ] **步骤 5：提交正式快照**

```powershell
git add pubspec.yaml assets/data/development/development_snapshot.json
git commit -m "feat(装备开发): 内置授权开发池数据快照"
```

## 任务 3：实现运行时数据模型与 Repository

**文件：**

- 创建：`lib/src/development/development_resources.dart`
- 创建：`lib/src/development/development_dataset.dart`
- 创建：`lib/src/development/development_repository.dart`
- 创建：`test/development/development_dataset_test.dart`

- [ ] **步骤 1：编写资源值对象和数据解析失败测试**

```dart
test('dataset parses localized labels and validates references', () {
  final dataset = DevelopmentDataset.fromJson(validSnapshotJson);
  expect(dataset.pool('carrier-other#1').label(const Locale('ja')), '空母系-その他');
  expect(dataset.equipment[20]!.minimumResources, const DevelopmentResources(10, 20, 30, 40));
});

test('dataset rejects a drop rate for unknown equipment', () {
  expect(
    () => DevelopmentDataset.fromJson(snapshotWithUnknownEquipment),
    throwsFormatException,
  );
});
```

- [ ] **步骤 2：运行测试并确认失败**

运行：

```powershell
flutter test test/development/development_dataset_test.dart
```

预期：FAIL，提示 `DevelopmentDataset` 未定义。

- [ ] **步骤 3：实现资源与池类型基础类型**

```dart
enum DevelopmentPoolType { bauxite, ammunition, fuelSteel }

class DevelopmentResources {
  const DevelopmentResources(this.fuel, this.ammo, this.steel, this.bauxite);
  final int fuel;
  final int ammo;
  final int steel;
  final int bauxite;
  List<int> get values => [fuel, ammo, steel, bauxite];
  int get total => fuel + ammo + steel + bauxite;
  DevelopmentResources normalized() => DevelopmentResources(
    _clampResource(fuel), _clampResource(ammo),
    _clampResource(steel), _clampResource(bauxite),
  );
}

int _clampResource(int value) => value < 10 ? 10 : (value > 300 ? 300 : value);
```

实现值相等与 `hashCode`，使测试和控制器能稳定比较资源。

- [ ] **步骤 4：实现快照模型与校验**

`DevelopmentDataset.fromJson` 一次构建以下只读索引：

```dart
final Map<String, DevelopmentPoolRecord> poolsByKey;
final Map<int, DevelopmentEquipmentRecord> equipment;
final Map<int, DevelopmentSecretaryRecord> secretaries;
final Map<String, List<DevelopmentPoolRecord>> poolsByName;
```

解析完成后校验 schema 版本、键唯一性、所有交叉引用、资源长度与有限出货率。

- [ ] **步骤 5：实现 Repository 加载与成功缓存**

```dart
class DevelopmentRepository {
  DevelopmentRepository({this.loadString = rootBundle.loadString});
  final Future<String> Function(String path) loadString;
  Future<DevelopmentDataset>? _load;

  Future<DevelopmentDataset> load() => _load ??= _loadOnce().catchError((Object error) {
    _load = null;
    throw error;
  });
}
```

并发调用只读取一次；失败后清空缓存，下一次调用可以重试。

- [ ] **步骤 6：运行数据测试并提交**

```powershell
dart format lib/src/development test/development/development_dataset_test.dart
flutter test test/development/development_dataset_test.dart
git add lib/src/development test/development/development_dataset_test.dart
git commit -m "feat(装备开发): 添加运行时数据模型与仓库"
```

## 任务 4：用 TDD 实现正向开发池计算

**文件：**

- 创建：`lib/src/development/development_pool_matcher.dart`
- 创建：`test/development/development_pool_matcher_test.dart`

- [ ] **步骤 1：编写池类型与正负概率叠加测试**

```dart
test('pool type uses strict comparisons and documented tie order', () {
  expect(selectDevelopmentPoolType(const DevelopmentResources(10, 10, 10, 11)), DevelopmentPoolType.bauxite);
  expect(selectDevelopmentPoolType(const DevelopmentResources(10, 11, 10, 11)), DevelopmentPoolType.ammunition);
  expect(selectDevelopmentPoolType(const DevelopmentResources(11, 11, 11, 11)), DevelopmentPoolType.fuelSteel);
});

test('forward calculation preserves replacement details', () {
  final result = calculateDevelopmentRates(fixtureDataset, basePool, const DevelopmentResources(10, 10, 10, 10));
  expect(result.details[7], [2, -2]);
  expect(result.totals[7], 0);
});
```

- [ ] **步骤 2：运行测试确认失败**

```powershell
flutter test test/development/development_pool_matcher_test.dart
```

预期：FAIL，提示 `selectDevelopmentPoolType` 未定义。

- [ ] **步骤 3：实现严格的池类型判定**

```dart
DevelopmentPoolType selectDevelopmentPoolType(DevelopmentResources r) {
  if (r.bauxite > r.fuel && r.bauxite > r.ammo && r.bauxite > r.steel) {
    return DevelopmentPoolType.bauxite;
  }
  if (r.ammo > r.fuel && r.ammo > r.steel) {
    return DevelopmentPoolType.ammunition;
  }
  return DevelopmentPoolType.fuelSteel;
}
```

- [ ] **步骤 4：实现兼容池、最低资源过滤和明细合并**

候选池必须满足：池类型绝对值相同、候选 `shipIds` 是基础池的超集、最低资源不高于当前配方。兼容池按舰娘集合大小降序，再按出货率条目数降序，最后按稳定池键排序。

- [ ] **步骤 5：运行测试并提交**

```powershell
dart format lib/src/development/development_pool_matcher.dart test/development/development_pool_matcher_test.dart
flutter test test/development/development_pool_matcher_test.dart
git add lib/src/development/development_pool_matcher.dart test/development/development_pool_matcher_test.dart
git commit -m "feat(装备开发): 实现正向出货率计算"
```

## 任务 5：用 TDD 实现反向配方与装备投影

**文件：**

- 创建：`lib/src/development/development_recipe_calculator.dart`
- 创建：`lib/src/development/development_projection.dart`
- 创建：`test/development/development_recipe_calculator_test.dart`
- 创建：`test/development/development_projection_test.dart`
- 创建：`test/development/development_reference_regression_test.dart`

- [ ] **步骤 1：编写最低配方、九六式陆攻和多目标测试**

```dart
test('96 land attacker applies its domain minimum before target maxima', () {
  final recipes = deriveMinimumRecipes(
    DevelopmentPoolType.bauxite,
    const {168},
    fixtureEquipment,
  );
  expect(recipes.single, const DevelopmentResources(240, 260, 10, 261));
});

test('multi-target recipe exists only when every target has a positive rate', () {
  final results = calculateRecipes(fixtureDataset, const {7, 8});
  expect(results.every((r) => r.targetRate > 0), isTrue);
  expect(results.map((r) => r.poolKey), isNot(contains('pool-with-only-7')));
});
```

- [ ] **步骤 2：编写分组与启用集合测试**

```dart
test('zero total is replaced before affordability and target checks', () {
  final groups = projectDevelopmentEquipment(
    totals: const {7: 0}, details: const {7: [2, -2]},
    targets: const {7}, resources: const DevelopmentResources(10, 10, 10, 10),
    equipment: fixtureEquipment,
  );
  expect(groups.replaced.single.id, 7);
  expect(groups.replaced.single.rateDetails, [2, -2]);
});
```

- [ ] **步骤 3：运行测试确认失败**

```powershell
flutter test test/development/development_recipe_calculator_test.dart test/development/development_projection_test.dart
```

预期：FAIL，提示反向计算与投影函数未定义。

- [ ] **步骤 4：实现配方生成与评估**

`deriveMinimumRecipes` 先合并目标装备 `broken × 10`，再应用装备 168 的油 240、弹 260、铝 250 特例，最后按目标池调整严格大小关系。油钢池在油、钢都不占优时分别生成抬油与抬钢两个候选。

`DevelopmentRecipeResult` 固定包含：

```dart
class DevelopmentRecipeResult {
  const DevelopmentRecipeResult({
    required this.poolKey,
    required this.poolType,
    required this.resources,
    required this.targetRate,
    required this.failureRate,
  });
  final String poolKey;
  final DevelopmentPoolType poolType;
  final DevelopmentResources resources;
  final double targetRate;
  final double failureRate;
  int get totalResources => resources.total;
}
```

- [ ] **步骤 5：实现装备分组与可选集合**

启用集合遍历全部可选池与 3 类池，准入判断要求所有已选目标出货率大于 0；收集装备时保留出货率 Map 中的零值键，使被负池抵消的装备仍可点击。

- [ ] **步骤 6：添加正式数据回归夹具**

从授权参考数据选取至少 12 组固定输入，覆盖 3 类池、负池、最低资源池、多目标和装备 168。测试只提交输入和规范化数值结果，不依赖 Node、Vue 或远端网络。

- [ ] **步骤 7：运行测试并提交**

```powershell
dart format lib/src/development test/development
flutter test test/development/development_recipe_calculator_test.dart test/development/development_projection_test.dart test/development/development_reference_regression_test.dart
git add lib/src/development test/development
git commit -m "feat(装备开发): 实现配方反推与装备投影"
```

## 任务 6：实现页面控制器

**文件：**

- 创建：`lib/src/development/equipment_development_controller.dart`
- 创建：`test/development/equipment_development_controller_test.dart`

- [ ] **步骤 1：编写初始化、手动覆盖和配方回填测试**

```dart
test('initializes from fleet 1 flagship and preserves manual pool selection', () async {
  final controller = EquipmentDevelopmentController(repository: fakeRepository);
  await controller.initialize(stateWithFlagship(101));
  expect(controller.selectedPoolKey, 'carrier-akagi#1');

  controller.selectPool('gunnery-other#3');
  controller.updateGameState(stateWithFlagship(202));
  expect(controller.selectedPoolKey, 'gunnery-other#3');

  controller.useCurrentFlagship();
  expect(controller.selectedPoolKey, 'torpedo-sendai#2');
});
```

- [ ] **步骤 2：运行测试确认失败**

```powershell
flutter test test/development/equipment_development_controller_test.dart
```

预期：FAIL，提示控制器不存在。

- [ ] **步骤 3：实现控制器状态接口**

```dart
class EquipmentDevelopmentController extends ChangeNotifier {
  Future<void> initialize(GameState state);
  void updateGameState(GameState state);
  void selectPool(String key);
  void useCurrentFlagship();
  void commitResources(DevelopmentResources value);
  void toggleTarget(int equipmentId);
  void applyRecipe(DevelopmentRecipeResult recipe);
  void setEquipmentTypeFilter(int? typeId);
  void setEquipmentSearch(String value);
  void sortRecipes(DevelopmentRecipeSortField field);
}
```

控制器缓存派生结果，只有池、合法资源、目标或排序变化时重算；名称搜索只重算选择面板投影。

- [ ] **步骤 4：补齐失败与空状态测试**

覆盖 Repository 首次失败后重试、无母港默认池、旗舰无法匹配、无共同配方、非法资源不提交和重复应用同一配方不覆盖手工输入。

- [ ] **步骤 5：运行测试并提交**

```powershell
dart format lib/src/development/equipment_development_controller.dart test/development/equipment_development_controller_test.dart
flutter test test/development/equipment_development_controller_test.dart
git add lib/src/development/equipment_development_controller.dart test/development/equipment_development_controller_test.dart
git commit -m "feat(装备开发): 添加页面状态控制器"
```

## 任务 7：实现 A「指挥仪表盘」主体页面

**文件：**

- 创建：`lib/src/development/equipment_development_page.dart`
- 创建：`test/development/equipment_development_page_test.dart`

- [ ] **步骤 1：编写宽屏、窄屏与顶部条件测试**

```dart
testWidgets('uses command dashboard in wide and stacked layout in narrow view', (tester) async {
  await pumpDevelopmentPage(tester, size: const Size(844, 390));
  expect(find.byKey(const Key('development-wide-dashboard')), findsOneWidget);
  expect(find.byKey(const Key('development-resource-fuel')), findsOneWidget);

  tester.view.physicalSize = const Size(390, 844);
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('development-stacked-dashboard')), findsOneWidget);
  expect(tester.takeException(), isNull);
});
```

- [ ] **步骤 2：运行 Widget 测试确认失败**

```powershell
flutter test test/development/equipment_development_page_test.dart
```

预期：FAIL，提示 `EquipmentDevelopmentPage` 不存在。

- [ ] **步骤 3：实现页面状态壳与响应式骨架**

页面使用 `AnimatedBuilder(animation: controller)`。`LayoutBuilder` 在可用宽度不小于 720 时构建：

```dart
Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Expanded(flex: 6, child: DevelopmentOutcomePanel(controller: controller)),
    const SizedBox(width: 12),
    Expanded(flex: 4, child: DevelopmentTargetPanel(controller: controller)),
  ],
)
```

窄屏使用同一组件的 `Column`，避免维护两套交互逻辑。

- [ ] **步骤 4：实现秘书舰与资源条件卡**

资源输入使用 `TextEditingController`、`inputFormatters: [FilteringTextInputFormatter.digitsOnly]` 和 `TextInputType.number`。输入阶段只在 4 项均为 10–300 的整数时提交；失焦时归一化并同步文本。

「使用当前旗舰」按钮调用 `controller.useCurrentFlagship()`，匹配失败通过现有 `TopNoticeHost` 显示本地化提示。

- [ ] **步骤 5：实现正向结果 4 分组**

装备行复用 `equipmentTypeIconCandidates` 解析图标。分组头显示合计概率；替换组成员显示 `rateDetails` 拼成的正负明细，不写死 `0%`。

- [ ] **步骤 6：运行页面测试并提交**

```powershell
dart format lib/src/development/equipment_development_page.dart test/development/equipment_development_page_test.dart
flutter test test/development/equipment_development_page_test.dart
git add lib/src/development/equipment_development_page.dart test/development/equipment_development_page_test.dart
git commit -m "feat(装备开发): 构建指挥仪表盘主体页面"
```

## 任务 8：实现目标装备面板、搜索弹窗与推荐表

**文件：**

- 创建：`lib/src/development/development_equipment_picker.dart`
- 创建：`lib/src/development/development_recipe_table.dart`
- 修改：`lib/src/development/equipment_development_page.dart`
- 修改：`test/development/equipment_development_page_test.dart`

- [ ] **步骤 1：编写已确认搜索交互的失败测试**

```dart
testWidgets('picker uses a search button and opens an input dialog', (tester) async {
  await pumpDevelopmentPage(tester);
  await tester.tap(find.byKey(const Key('development-add-target')));
  await tester.pumpAndSettle();

  expect(find.byKey(const Key('development-equipment-search-field')), findsNothing);
  expect(find.byKey(const Key('development-equipment-search-button')), findsOneWidget);

  await tester.tap(find.byKey(const Key('development-equipment-search-button')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('development-equipment-search-field')), findsOneWidget);
});
```

- [ ] **步骤 2：运行测试确认失败**

```powershell
flutter test test/development/equipment_development_page_test.dart --plain-name "picker uses a search button"
```

预期：FAIL，找不到添加按钮或搜索按钮。

- [ ] **步骤 3：实现底部装备面板**

使用 `showModalBottomSheet(isScrollControlled: true)`。标题行包含文本、圆形搜索按钮和关闭按钮；类型筛选使用可换行 `Wrap`。装备条目由控制器提供，禁用条件是「不在 enabled ID 集合且当前未选择」。

- [ ] **步骤 4：实现按钮触发的输入弹窗**

复用 `StandaloneTextInputDialog` 或 `AdaptiveInputDialog`：标题为本地化「搜索装备」，自动聚焦，确认后保存去除首尾空格的搜索词，取消不修改。搜索词非空时圆形按钮使用旧金色激活态。

- [ ] **步骤 5：实现推荐配方表与点击回填**

表头点击调用 `sortRecipes`，行点击调用 `applyRecipe`。表格放入单独的横向 `SingleChildScrollView`，外层纵向滚动仍由页面统一管理。应用行使用 `aria` 对应的 Flutter `Semantics(selected: true)`。

- [ ] **步骤 6：补齐搜索、禁用、无共同配方和回填测试**

测试确认：搜索弹窗确定/取消/清空、类型与名称组合过滤、已选不可用装备仍能取消、点击配方后 4 项资源更新且左栏结果变化。

- [ ] **步骤 7：运行测试并提交**

```powershell
dart format lib/src/development test/development/equipment_development_page_test.dart
flutter test test/development/equipment_development_page_test.dart
git add lib/src/development test/development/equipment_development_page_test.dart
git commit -m "feat(装备开发): 添加目标选择与推荐配方交互"
```

## 任务 9：接入工具箱并完成三语言

**文件：**

- 修改：`lib/src/toolbox/toolbox_page.dart`
- 修改：`lib/src/toolbox/toolbox_mode_tabs.dart`
- 修改：`lib/main.dart`
- 修改：`lib/l10n/app_zh.arb`
- 修改：`lib/l10n/app_zh_Hant.arb`
- 修改：`lib/l10n/app_ja.arb`
- 修改：`test/toolbox_page_test.dart`
- 修改：`test/prototype_shell_test.dart`
- 修改：`test/workspace_context_header_test.dart`

- [ ] **步骤 1：先更新工具箱集成测试**

把所有 `ToolboxMode.other` 断言改为 `ToolboxMode.equipmentDevelopment`，并断言标签显示「装备开发」、点击后出现 `EquipmentDevelopmentPage`，不再出现「其他功能正在开发」。

- [ ] **步骤 2：运行测试确认失败**

```powershell
flutter test test/toolbox_page_test.dart test/prototype_shell_test.dart test/workspace_context_header_test.dart
```

预期：FAIL，提示新枚举或本地化 getter 不存在。

- [ ] **步骤 3：添加三语言 UI 文案并生成本地化代码**

3 份 ARB 使用相同键集合，至少包括：

```json
{
  "equipmentDevelopment": "装备开发",
  "developmentSecretary": "秘书舰",
  "developmentUseCurrentFlagship": "使用当前旗舰",
  "developmentAddTarget": "添加目标装备",
  "developmentSearchEquipment": "搜索装备",
  "developmentNoCommonRecipe": "没有可同时开发这些装备的配方"
}
```

繁体中文和日文提供自然翻译，不回退简体中文。运行：

```powershell
flutter gen-l10n
```

- [ ] **步骤 4：接入工具箱与应用依赖**

`ToolboxMode` 改为：

```dart
enum ToolboxMode { fleetExport, equipmentDevelopment }
```

`ToolboxPage` 在新模式构建 `EquipmentDevelopmentPage`。Repository 在应用依赖初始化阶段创建一次；Controller 由页面持有并在 `dispose` 时释放，避免每次 `GameState` 更新重置手工选择。

- [ ] **步骤 5：运行集成测试并提交**

```powershell
dart format lib/main.dart lib/src/toolbox lib/l10n test/toolbox_page_test.dart test/prototype_shell_test.dart test/workspace_context_header_test.dart
flutter test test/toolbox_page_test.dart test/prototype_shell_test.dart test/workspace_context_header_test.dart
git add lib/main.dart lib/src/toolbox lib/l10n test/toolbox_page_test.dart test/prototype_shell_test.dart test/workspace_context_header_test.dart
git commit -m "feat(工具箱): 接入装备开发工具与三语言文案"
```

## 任务 10：补充授权说明并完成全量验证

**文件：**

- 修改：`assets/data/THIRD_PARTY_DATA.md`

- [ ] **步骤 1：补充第三方数据说明**

新增「装备开发资料」章节，明确：

- 来源仓库 `https://github.com/SkywalkerJi/kc-development-tools`；
- 固定提交 `d065120`；
- 使用开发池、池名称翻译和必要 Master 派生数据；
- 作者已确认 Yahagi 可以使用，要求不照抄原项目 UI；
- Yahagi 使用独立 Dart 算法和 Flutter 页面；
- 数据可能滞后，实际结果以游戏为准。

- [ ] **步骤 2：运行格式与静态分析**

```powershell
dart format --output=none --set-exit-if-changed lib tool test
flutter analyze lib/src/development lib/src/toolbox lib/main.dart tool/development_data test/development
```

预期：全部退出码为 0，无 warning 或 error。

- [ ] **步骤 3：运行装备开发与工具箱测试**

```powershell
flutter test test/development test/toolbox_page_test.dart test/prototype_shell_test.dart test/workspace_context_header_test.dart
```

预期：全部 PASS。

- [ ] **步骤 4：运行全量 Flutter 测试**

```powershell
flutter test
```

预期：全部 PASS。若存在与本次无关的已知失败，记录精确测试名与本次变更前后的对比，不把它描述为本次通过。

- [ ] **步骤 5：检查数据与工作树**

```powershell
git diff --check
git status --short
```

确认没有误提交 `.superpowers/` 原型、临时克隆、构建产物或未授权源文件。

- [ ] **步骤 6：提交授权说明和验证修正**

```powershell
git add assets/data/THIRD_PARTY_DATA.md
git commit -m "docs(装备开发): 补充数据授权与来源说明"
```

- [ ] **步骤 7：在真实横竖屏环境验收**

优先对现有 Flutter 调试进程执行热重载，验证 844 × 390 横屏与 390 × 844 纵屏：无溢出、搜索按钮弹窗符合确认原型、配方点击回填正确。用户确认界面后再按项目发布流程构建 Debug APK。
