# POI 引擎跨节点损管状态实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 为默认 POI 战斗预测增加按舰娘及装备实例追踪的出击级损管账本，防止同一损管跨节点重复复活。

**架构：** 新增独立的 `SortieDamageControlLedger`，由 `BattleController` 管理出击生命周期。控制器只在创建 POI 引擎时把已消费 Master ID 序列注入舰船快照，预测完成后用装备实例顺序核对并同步账本；Yahagi 引擎、伤害阶段和预测接口保持不变。

**技术栈：** Dart、Flutter Test、现有 `BattleController`、`PoiBattlePredictionEngine`、PowerShell POI corpus 工具。

---

## 文件结构

- 创建：`lib/src/battle/sortie_damage_control_ledger.dart`，封装出击级损管消费、实例核对、幂等同步和可信状态。
- 创建：`test/sortie_damage_control_ledger_test.dart`，验证账本顺序、重复装备、幂等和异常状态。
- 创建：`test/battle_controller_damage_control_lifecycle_test.dart`，用完整 API 事件验证跨节点、母港、七舰和引擎隔离。
- 修改：`lib/src/battle/battle_controller.dart`，接入账本生命周期、POI 快照注入、预测结果同步和关闭式失败。
- 修改：`test/battle_poi_corpus_test.dart`，把官方夹具数量门槛从 303 更新为 304，并避免把隐藏敌方 HP 当作可核对的服务器沉船数。
- 修改：`tool/run_poi_battle_corpus.ps1`，在执行 Dart 对照前安装依赖并构建官方 POI oracle。

### 任务 1：实现纯损管账本

**文件：**
- 创建：`test/sortie_damage_control_ledger_test.dart`
- 创建：`lib/src/battle/sortie_damage_control_ledger.dart`

- [x] **步骤 1：编写实例顺序与幂等同步失败测试**

```dart
test('synchronizes duplicate damage controls by concrete instance', () {
  final ledger = SortieDamageControlLedger()..beginSortie();
  const ship = BattleShipSnapshot(
    masterId: 1,
    ownedShipId: 1001,
    name: 'test',
    side: BattleSide.friend,
    fleetRole: BattleFleetRole.main,
    position: 0,
    initialHp: 30,
    maxHp: 30,
    currentHp: 6,
    equipmentMasterIds: <int>[42, 42],
    usedDamageControlItemIds: <int>[42, 42],
  );
  const equipment = <int, List<DamageControlEquipmentRef>>{
    1001: <DamageControlEquipmentRef>[
      DamageControlEquipmentRef(instanceId: 501, masterId: 42),
      DamageControlEquipmentRef(instanceId: 502, masterId: 42),
    ],
  };

  ledger.synchronize(ships: const <BattleShipSnapshot>[ship], equipmentByShipId: equipment);
  ledger.synchronize(ships: const <BattleShipSnapshot>[ship], equipmentByShipId: equipment);

  expect(ledger.consumptionsForShip(1001).map((item) => item.instanceId), <int>[501, 502]);
  expect(ledger.usedMasterIdsForShip(1001), <int>[42, 42]);
  expect(ledger.isTrusted, isTrue);
});
```

- [x] **步骤 2：运行测试并确认因类型尚不存在而失败**

运行：`flutter test test/sortie_damage_control_ledger_test.dart`

预期：FAIL，`SortieDamageControlLedger` 和 `DamageControlEquipmentRef` 未定义。

- [x] **步骤 3：实现最小账本 API**

```dart
final class DamageControlEquipmentRef {
  const DamageControlEquipmentRef({required this.instanceId, required this.masterId});
  final int instanceId;
  final int masterId;
}

final class SortieDamageControlLedger {
  final Map<int, List<DamageControlEquipmentRef>> _consumed = <int, List<DamageControlEquipmentRef>>{};
  bool _active = false;
  bool _trusted = true;
  String? _untrustedReason;

  bool get isActive => _active;
  bool get isTrusted => _trusted;
  String? get untrustedReason => _untrustedReason;

  void beginSortie({bool trusted = true, String? reason}) {
    _consumed.clear();
    _active = true;
    _trusted = trusted;
    _untrustedReason = trusted ? null : (reason ?? '跨节点损管状态无法确认');
  }

  void endSortie() {
    _consumed.clear();
    _active = false;
    _trusted = true;
    _untrustedReason = null;
  }

  void markUntrusted(String reason) {
    if (!_active) return;
    _trusted = false;
    _untrustedReason ??= reason;
  }

  List<int> usedMasterIdsForShip(int shipId) => List<int>.unmodifiable(
    (_consumed[shipId] ?? const <DamageControlEquipmentRef>[]).map((item) => item.masterId),
  );

  List<DamageControlEquipmentRef> consumptionsForShip(int shipId) =>
      List<DamageControlEquipmentRef>.unmodifiable(
        _consumed[shipId] ?? const <DamageControlEquipmentRef>[],
      );

  List<BattleShipSnapshot> seedFleet(List<BattleShipSnapshot> ships) =>
      List<BattleShipSnapshot>.unmodifiable(<BattleShipSnapshot>[
        for (final ship in ships)
          if (ship.ownedShipId case final shipId?)
            ship.copyWith(usedDamageControlItemIds: usedMasterIdsForShip(shipId))
          else
            ship,
      ]);

  void synchronize({
    required Iterable<BattleShipSnapshot> ships,
    required Map<int, List<DamageControlEquipmentRef>> equipmentByShipId,
  }) {
    if (!_active || !_trusted) return;
    final pending = <int, List<DamageControlEquipmentRef>>{
      for (final entry in _consumed.entries) entry.key: List<DamageControlEquipmentRef>.from(entry.value),
    };
    String? error;
    for (final ship in ships) {
      final output = ship.usedDamageControlItemIds;
      if (output.isEmpty) continue;
      final shipId = ship.ownedShipId;
      if (shipId == null) {
        error = '损管消费缺少舰娘实例 ID';
        break;
      }
      final existing = pending.putIfAbsent(shipId, () => <DamageControlEquipmentRef>[]);
      if (existing.length > output.length ||
          Iterable<int>.generate(existing.length).any((i) => existing[i].masterId != output[i])) {
        error = '损管消费序列与前序节点不一致';
        break;
      }
      final equipment = equipmentByShipId[shipId] ?? const <DamageControlEquipmentRef>[];
      for (var index = existing.length; index < output.length; index++) {
        final masterId = output[index];
        final match = equipment.where(
          (item) => item.masterId == masterId && !existing.any((used) => used.instanceId == item.instanceId),
        ).firstOrNull;
        if (match == null || (masterId != 42 && masterId != 43)) {
          error = '找不到预测消费对应的损管装备实例';
          break;
        }
        existing.add(match);
      }
      if (error != null) break;
    }
    if (error != null) {
      markUntrusted(error);
      return;
    }
    _consumed
      ..clear()
      ..addAll(pending);
  }
}
```

实现中只接受 Master ID `42` 和 `43`；已有消费序列必须是预测输出的严格前缀或完整相等序列。任何矛盾调用 `markUntrusted`，不得部分追加当前批次。

- [x] **步骤 4：补充异常和位置变化测试并运行绿灯**

覆盖 `[42, 43]`、缺失 `ownedShipId`、找不到实例、前缀矛盾、位置改变但舰娘 ID 不变。

运行：`flutter test test/sortie_damage_control_ledger_test.dart`

预期：全部 PASS。

- [x] **步骤 5：提交任务 1**

```bash
git add lib/src/battle/sortie_damage_control_ledger.dart test/sortie_damage_control_ledger_test.dart
git commit -m "feat(战斗): 添加出击级损管消费账本（任务 1/4）"
```

### 任务 2：接入 POI 跨节点生命周期

**文件：**
- 创建：`test/battle_controller_damage_control_lifecycle_test.dart`
- 修改：`lib/src/battle/battle_controller.dart`

- [ ] **步骤 1：编写跨节点重复使用回归测试**

测试建立一艘 30 HP、装备实例 `501/42` 的舰娘，依次发送：

```dart
test('does not reuse damage control on the next node', () async {
  final state = damageControlState(const <OwnedSlotItem>[
    OwnedSlotItem(instanceId: 501, masterSlotItemId: 42),
  ]);
  final controller = BattleController(gameState: () => state);
  addTearDown(controller.dispose);

  controller
    ..accept(apiEvent('/kcsapi/api_req_map/start', mapData, sequence: 1))
    ..accept(apiEvent('/kcsapi/api_req_sortie/battle', lethalBattle(30, openingHp: 30), sequence: 2));
  await controller.idle;
  expect(controller.current!.friendMain.single.currentHp, 6);

  controller
    ..accept(apiEvent('/kcsapi/api_req_map/next', mapData, sequence: 3))
    ..accept(apiEvent('/kcsapi/api_req_sortie/battle', lethalBattle(6, openingHp: 6), sequence: 4));
  await controller.idle;
  expect(controller.current!.friendMain.single.currentHp, 0);
});

const mapData = <String, Object?>{
  'api_maparea_id': 1,
  'api_mapinfo_no': 1,
  'api_no': 1,
};

CapturedApiEvent apiEvent(String path, Object? data, {required int sequence}) => CapturedApiEvent(
  path: path,
  responseBody: jsonEncode(<String, Object?>{'api_result': 1, 'api_data': data}),
  source: CaptureSource.xhr,
  capturedAt: DateTime.utc(2026, 8, 28),
  sequence: sequence,
);

GameState damageControlState(List<OwnedSlotItem> equipment) => GameState(
  hasPortData: true,
  ships: <int, OwnedShip>{
    1001: OwnedShip(
      id: 1001,
      masterId: 1,
      level: 1,
      currentHp: 30,
      maxHp: 30,
      slotIds: <int>[for (final item in equipment) item.instanceId],
    ),
  },
  slotItems: <int, OwnedSlotItem>{for (final item in equipment) item.instanceId: item},
  fleets: const <Fleet>[
    Fleet(id: 1, name: 'Test', shipIds: <int>[1001]),
  ],
);

Map<String, Object?> lethalBattle(num damage, {required int openingHp}) => <String, Object?>{
  'api_deck_id': 1,
  'api_f_nowhps': <int>[-1, openingHp],
  'api_f_maxhps': const <int>[-1, 30],
  'api_e_nowhps': const <int>[-1, 20],
  'api_e_maxhps': const <int>[-1, 20],
  'api_ship_ke': const <int>[-1, 501],
  'api_hougeki1': <String, Object?>{
    'api_at_eflag': const <int>[1],
    'api_at_list': const <int>[0],
    'api_df_list': const <Object?>[<int>[0]],
    'api_damage': <Object?>[<num>[damage]],
  },
};
```

- [ ] **步骤 2：运行测试并确认旧实现错误复活**

运行：`flutter test test/battle_controller_damage_control_lifecycle_test.dart --plain-name "does not reuse damage control on the next node"`

预期：FAIL，实际 HP 为 6，期望为 0。

- [ ] **步骤 3：实现控制器最小接入**

在 `BattleController` 中增加：

```dart
final SortieDamageControlLedger _sortieDamageControls = SortieDamageControlLedger();
BattlePredictionMethod? _predictionEngineMethod;
```

精确生命周期：

```dart
if (event.path == '/kcsapi/api_port/port' || event.path == '/kcsapi/api_start2/getData') {
  _sortieDamageControls.endSortie();
  _predictionEngineMethod = null;
}
if (event.path == '/kcsapi/api_req_map/start') {
  _sortieDamageControls.beginSortie();
}
if (event.path == '/kcsapi/api_req_map/next' && !_sortieDamageControls.isActive) {
  _sortieDamageControls.beginSortie(trusted: false, reason: '缺少前序出击节点');
}
```

创建引擎时只对 POI 路径调用 `seedFleet`。预测完成且没有解析问题时，用
`GameState.equipmentForShip` 生成 `DamageControlEquipmentRef` 并执行 `synchronize`。

- [ ] **步骤 4：运行跨节点测试和原有控制器测试**

运行：`flutter test test/battle_controller_damage_control_lifecycle_test.dart test/battle_controller_test.dart`

预期：全部 PASS。

- [ ] **步骤 5：提交任务 2**

```bash
git add lib/src/battle/battle_controller.dart test/battle_controller_damage_control_lifecycle_test.dart
git commit -m "fix(战斗): 阻止损管跨节点重复使用（任务 2/4）"
```

### 任务 3：覆盖边界与关闭式失败

**文件：**
- 修改：`test/battle_controller_damage_control_lifecycle_test.dart`
- 修改：`lib/src/battle/battle_controller.dart`

- [ ] **步骤 1：编写要员加女神、七舰和母港重置测试**

断言：

- `[501/42, 502/43]` 在 A 节点恢复 6 HP，B 节点恢复 30 HP；
- 游击部队第 7 舰在 A 节点消耗后，B 节点再次致命为 0 HP；
- 收到 `api_port/port` 后重新 `map/start`，同一测试快照中的要员可作为新出击装备使用；
- 重复同步同一预测不会导致第二件损管提前被标记消费。

要员加女神和母港重置使用以下断言；七舰用例把相同事件目标改为位置 `6`，并断言
前 6 艘舰 HP 不变、第 7 舰从 33 HP 恢复到 6 HP 后在下一节点降为 0 HP：

```dart
test('uses goddess after personnel across nodes', () async {
  final controller = BattleController(
    gameState: () => damageControlState(const <OwnedSlotItem>[
      OwnedSlotItem(instanceId: 501, masterSlotItemId: 42),
      OwnedSlotItem(instanceId: 502, masterSlotItemId: 43),
    ]),
  );
  addTearDown(controller.dispose);
  controller
    ..accept(apiEvent('/kcsapi/api_req_map/start', mapData, sequence: 11))
    ..accept(apiEvent('/kcsapi/api_req_sortie/battle', lethalBattle(30, openingHp: 30), sequence: 12));
  await controller.idle;
  expect(controller.current!.friendMain.single.currentHp, 6);
  controller
    ..accept(apiEvent('/kcsapi/api_req_map/next', mapData, sequence: 13))
    ..accept(apiEvent('/kcsapi/api_req_sortie/battle', lethalBattle(6, openingHp: 6), sequence: 14));
  await controller.idle;
  expect(controller.current!.friendMain.single.currentHp, 30);
});

test('port resets the sortie damage control ledger', () async {
  final state = damageControlState(const <OwnedSlotItem>[
    OwnedSlotItem(instanceId: 501, masterSlotItemId: 42),
  ]);
  final controller = BattleController(gameState: () => state);
  addTearDown(controller.dispose);
  controller
    ..accept(apiEvent('/kcsapi/api_req_map/start', mapData, sequence: 21))
    ..accept(apiEvent('/kcsapi/api_req_sortie/battle', lethalBattle(30, openingHp: 30), sequence: 22));
  await controller.idle;
  controller
    ..accept(apiEvent('/kcsapi/api_port/port', const <String, Object?>{}, sequence: 23))
    ..accept(apiEvent('/kcsapi/api_req_map/start', mapData, sequence: 24))
    ..accept(apiEvent('/kcsapi/api_req_sortie/battle', lethalBattle(30, openingHp: 30), sequence: 25));
  await controller.idle;
  expect(controller.current!.friendMain.single.currentHp, 6);
});
```

- [ ] **步骤 2：运行新增测试并确认至少一个因边界未实现而失败**

运行：`flutter test test/battle_controller_damage_control_lifecycle_test.dart`

预期：新增边界用例在完成关闭式失败和引擎隔离前 FAIL。

- [ ] **步骤 3：实现未确认传播和 Yahagi 引擎隔离**

当 POI 预测出现解析问题、账本不可信或中途接入时：

```dart
_session?.markUnconfirmed(
  stage: 'damage-control-ledger',
  message: _sortieDamageControls.untrustedReason ?? '跨节点损管状态无法确认',
);
```

仅当 `!practice` 且当前不是“不可信 POI 出击”时调用 `_emitFriendlyHp`。创建
Yahagi 引擎时使用未注入的原始舰队快照，也不把其输出同步到账本。

- [ ] **步骤 4：运行账本、控制器和两套引擎测试**

运行：

```bash
flutter test test/sortie_damage_control_ledger_test.dart test/battle_controller_damage_control_lifecycle_test.dart test/battle_controller_test.dart test/poi_battle_prediction_engine_test.dart test/yahagi_battle_prediction_engine_test.dart
```

预期：全部 PASS。

- [ ] **步骤 5：提交任务 3**

```bash
git add lib/src/battle/battle_controller.dart test/battle_controller_damage_control_lifecycle_test.dart
git commit -m "fix(战斗): 完善损管状态异常保护（任务 3/4）"
```

### 任务 4：修复 POI 语料门禁并完成全量验证

**文件：**
- 修改：`test/battle_poi_corpus_test.dart`
- 修改：`tool/run_poi_battle_corpus.ps1`

- [ ] **步骤 1：编写或调整语料门禁断言**

把夹具数量断言更新为 304。仅当敌方 `maxHp` 全部已知且大于 0 时，才用
`api_dests` 对照最终沉船数；逐包 HP、等级和 MVP 比较始终保留。

```dart
expect(files, hasLength(304));
expect(processedFiles, 304);
final allEnemyHpKnown = <BattleShipSnapshot>[
  ...prediction.enemyMain,
  ...prediction.enemyEscort,
].every((ship) => !ship.hpUnknown && ship.maxHp > 0);
if (allEnemyHpKnown) {
  expect(localSunkCount, serverSunkCount, reason: fixturePath);
}
```

- [ ] **步骤 2：让工具构建官方 oracle 后运行语料**

在仓库检出后执行：

```powershell
npm ci
npm run build
flutter test test/battle_poi_corpus_test.dart --dart-define=YAHAGI_POI_BATTLE_FIXTURES=$fixtures --dart-define=YAHAGI_POI_BATTLE_ORACLE=$oracle
```

预期：304 个文件、366 个战斗包全部 PASS。

- [ ] **步骤 3：运行全部战斗专项测试**

运行全部文件名包含 `battle`、`prediction`、`damage_control`、`fcf_retreat` 和
`live_battle_card` 的测试。

预期：0 failures。

- [ ] **步骤 4：运行静态分析、完整 Flutter 测试和格式检查**

```bash
dart format --output=none --set-exit-if-changed lib/src/battle test tool
flutter analyze
flutter test
git diff --check
```

预期：所有命令退出码为 0。

- [ ] **步骤 5：提交任务 4**

```bash
git add test/battle_poi_corpus_test.dart tool/run_poi_battle_corpus.ps1
git commit -m "test(战斗): 完善 POI 全量语料门禁（任务 4/4）"
```

- [ ] **步骤 6：代码审查和合并前复验**

对设计提交到最终实现提交做代码审查，修复所有 Critical 和 Important 问题。
在功能分支和最终 `master` 合并结果上分别重新运行关键损管测试与全量战斗测试。
