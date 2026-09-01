# 联合舰队二队旗舰大破提醒例外实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 联合舰队仅二队旗舰大破时不挂起进击弹窗，同时保留其他舰娘的原有大破提醒。

**架构：** 将安全例外限制在 `shouldShowPostBattleWarning` 的逐舰风险过滤中。使用战斗上下文的联合舰队类型、舰队角色和 0 起始位置共同识别二队旗舰，不修改舰娘模型、预测引擎、退避或损管状态。

**技术栈：** Flutter、Dart、`flutter_test`、现有 `LiveBattle` / `BattleShipSnapshot` 模型。

---

## 文件结构

- 修改：`test/battle_result_warning_overlay_test.dart`——覆盖联合舰队二队旗舰安全例外及其边界。
- 修改：`lib/src/capture/battle_result_warning_overlay.dart`——在战后进击弹窗风险判定中排除精确例外。

### 任务 1：以失败测试定义二队旗舰安全例外

**文件：**

- 修改：`test/battle_result_warning_overlay_test.dart:21`
- 测试：`test/battle_result_warning_overlay_test.dart`

- [ ] **步骤 1：扩展测试舰娘工厂**

将 `_heavyDamageShip` 改成可指定舰队角色、位置和名称，但保留现有调用的默认行为：

```dart
BattleShipSnapshot _heavyDamageShip({
  BattleFleetRole fleetRole = BattleFleetRole.main,
  int position = 1,
  String name = 'test',
}) {
  return BattleShipSnapshot(
    masterId: 1,
    name: name,
    side: BattleSide.friend,
    fleetRole: fleetRole,
    position: position,
    initialHp: 20,
    maxHp: 20,
    currentHp: 5,
  );
}
```

- [ ] **步骤 2：添加安全例外和边界测试**

在现有两个纯函数测试后添加：

```dart
group('combined escort flagship warning exception', () {
  const combinedContext = BattleContext(
    node: 4,
    bossNode: 5,
    combinedFleetType: CombinedFleetType.surfaceTaskForce,
  );

  LiveBattle resultBattle({
    BattleContext context = combinedContext,
    List<BattleShipSnapshot> main = const <BattleShipSnapshot>[],
    List<BattleShipSnapshot> escort = const <BattleShipSnapshot>[],
  }) => LiveBattle(
    context: context,
    friendMain: main,
    friendEscort: escort,
    displayStage: BattleDisplayStage.result,
  );

  test('does not warn when only the combined escort flagship is heavy', () {
    final battle = resultBattle(
      escort: <BattleShipSnapshot>[
        _heavyDamageShip(
          fleetRole: BattleFleetRole.escort,
          position: 0,
          name: '二队旗舰',
        ),
      ],
    );

    expect(shouldShowPostBattleWarning(battle), isFalse);
  });

  test('still warns for a combined escort non-flagship', () {
    final battle = resultBattle(
      escort: <BattleShipSnapshot>[
        _heavyDamageShip(
          fleetRole: BattleFleetRole.escort,
          position: 1,
          name: '二队僚舰',
        ),
      ],
    );

    expect(shouldShowPostBattleWarning(battle), isTrue);
  });

  test('still warns for a combined main-fleet ship', () {
    final battle = resultBattle(
      main: <BattleShipSnapshot>[
        _heavyDamageShip(position: 0, name: '一队旗舰'),
      ],
    );

    expect(shouldShowPostBattleWarning(battle), isTrue);
  });

  test('still warns when another ship is heavy with the escort flagship', () {
    final battle = resultBattle(
      escort: <BattleShipSnapshot>[
        _heavyDamageShip(
          fleetRole: BattleFleetRole.escort,
          position: 0,
          name: '二队旗舰',
        ),
        _heavyDamageShip(
          fleetRole: BattleFleetRole.escort,
          position: 2,
          name: '二队僚舰',
        ),
      ],
    );

    expect(shouldShowPostBattleWarning(battle), isTrue);
  });

  test('does not treat an escort-like snapshot as safe outside combined fleet', () {
    final battle = resultBattle(
      context: const BattleContext(node: 4, bossNode: 5),
      escort: <BattleShipSnapshot>[
        _heavyDamageShip(
          fleetRole: BattleFleetRole.escort,
          position: 0,
          name: '普通舰队舰娘',
        ),
      ],
    );

    expect(shouldShowPostBattleWarning(battle), isTrue);
  });
});
```

- [ ] **步骤 3：运行测试并验证红灯**

运行：

```powershell
flutter test test/battle_result_warning_overlay_test.dart --reporter expanded
```

预期：仅「does not warn when only the combined escort flagship is heavy」因实际值为 `true` 而失败；其余新增边界测试和原有测试通过。

### 任务 2：实现最小风险过滤

**文件：**

- 修改：`lib/src/capture/battle_result_warning_overlay.dart:13`
- 测试：`test/battle_result_warning_overlay_test.dart`

- [ ] **步骤 1：在逐舰判定中排除联合舰队二队旗舰**

将 `shouldShowPostBattleWarning` 末尾改为：

```dart
  final isCombinedFleet =
      context.combinedFleetType != CombinedFleetType.none;
  return battle.friendShips.any((ship) {
    if (ship.isEscaped || !ship.isHeavilyDamaged) {
      return false;
    }
    final isEscortFlagship =
        isCombinedFleet &&
        ship.fleetRole == BattleFleetRole.escort &&
        ship.position == 0;
    return !isEscortFlagship;
  });
```

- [ ] **步骤 2：运行测试并验证绿灯**

运行：

```powershell
flutter test test/battle_result_warning_overlay_test.dart --reporter expanded
```

预期：文件内全部测试通过，无失败。

- [ ] **步骤 3：格式化并重跑测试**

```powershell
dart format lib/src/capture/battle_result_warning_overlay.dart test/battle_result_warning_overlay_test.dart
flutter test test/battle_result_warning_overlay_test.dart --reporter compact
```

预期：格式化不改变行为，全部测试通过。

- [ ] **步骤 4：提交测试与最小实现**

```powershell
git add -- lib/src/capture/battle_result_warning_overlay.dart test/battle_result_warning_overlay_test.dart
git commit -m "fix(战斗): 排除联合舰队二队旗舰进击提醒"
```

### 任务 3：回归验证与审查

**文件：**

- 验证：`lib/src/capture/battle_result_warning_overlay.dart`
- 验证：`test/battle_result_warning_overlay_test.dart`
- 验证：`test/fcf_retreat_battle_warning_test.dart`
- 验证：`test/battle_controller_test.dart`
- 验证：`test/battle_controller_damage_control_lifecycle_test.dart`
- 验证：`test/poi_battle_prediction_engine_test.dart`
- 验证：`test/battle_poi_corpus_test.dart`

- [ ] **步骤 1：运行战斗提醒、退避、损管和预测专项测试**

```powershell
flutter test test/battle_result_warning_overlay_test.dart test/fcf_retreat_battle_warning_test.dart test/battle_controller_test.dart test/battle_controller_damage_control_lifecycle_test.dart test/poi_battle_prediction_engine_test.dart --reporter compact
```

预期：全部通过，无失败。

- [ ] **步骤 2：运行 POI 原始战斗数据集**

```powershell
$env:YAHAGI_POI_BATTLE_FIXTURES='G:\kancolle project\.reference\poi-lib-battle-source\tests\fixtures\battle-detail'
flutter test test/battle_poi_corpus_test.dart --reporter compact
```

预期：304 个 fixture、366 个战斗包全部匹配。

- [ ] **步骤 3：运行静态分析和差异检查**

```powershell
flutter analyze lib/src/capture/battle_result_warning_overlay.dart test/battle_result_warning_overlay_test.dart
git diff --check
git status --short --branch
```

预期：静态分析无问题，差异检查无错误，工作区没有本任务未提交变更。

- [ ] **步骤 4：审查最终提交范围**

```powershell
git log -3 --oneline --decorate
git show --stat --oneline HEAD
git show --stat --oneline HEAD~1
```

预期：除规格与计划提交外，本任务仅包含 1 个测试和生产代码原子提交；没有装备开发或其他模块文件混入。
