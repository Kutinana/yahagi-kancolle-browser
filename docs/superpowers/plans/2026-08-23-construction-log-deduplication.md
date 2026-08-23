# 建造日志跨会话去重实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 持久化建造开始记录与船坞的关联，使应用重启后收取舰娘仍更新原日志而不重复插入。

**架构：** SQLite 新增 `pending_construction_logs` 映射表，以船坞 ID 为主键、建造日志 ID 为值。`createship` 在事务中写日志和映射；`getship` 优先使用内存记录 ID，缺失时读取持久化映射，成功更新后删除映射。现有船坞快照匹配保留为其他设备建造的补录路径。

**技术栈：** Dart、Flutter Test、sqflite_common_ffi、SQLite

---

## 文件结构

- 修改：`test/logbook_event_recorder_test.dart`——增加跨 `LogbookEventRecorder` 实例的重复记录回归测试。
- 修改：`test/logbook_database_test.dart`——验证待收取映射写入和完成时清理。
- 修改：`lib/src/logbook/logbook_database.dart`——数据库升级到 v8，创建映射表并提供事务化写入、查询和完成接口。
- 修改：`lib/src/logbook/logbook_event_recorder.dart`——建造开始使用事务化接口，收取时读取持久化映射。

### 任务 1：用失败测试复现跨会话重复记录

**文件：**
- 测试：`test/logbook_event_recorder_test.dart`

- [ ] **步骤 1：编写失败的跨会话测试**

在 `createship` 响应已经暴露舰娘、但收取时船坞没有可还原开始时间的情况下，重新创建记录器：

```dart
test('reuses the persisted construction after recorder restart', () async {
  await recorder.record(createEventWithShip, state);
  recorder = LogbookEventRecorder(database: database);
  await recorder.record(receiveEvent, stateWithDockWithoutTimes);
  final rows = await database.getConstructionRecords();
  expect(rows, hasLength(1));
  expect(rows.single['ship_name'], '雪风');
});
```

- [ ] **步骤 2：运行测试并确认正确失败**

运行：

```powershell
flutter test test/logbook_event_recorder_test.dart --plain-name "reuses the persisted construction after recorder restart" --reporter expanded
```

预期：FAIL，预期 1 条，实际为 2 条。

### 任务 2：持久化船坞与建造日志的关联

**文件：**
- 修改：`lib/src/logbook/logbook_database.dart`
- 测试：`test/logbook_database_test.dart`

- [ ] **步骤 1：编写数据库映射测试**

```dart
final id = await database.insertConstructionStartRecord(
  dockId: 2,
  timestamp: 1000,
  constructionType: '普通建造',
  shipId: 1,
  shipName: '雪风',
  shipType: '驱逐舰',
  fuel: 30,
  ammo: 30,
  steel: 30,
  bauxite: 30,
  developmentMaterial: 1,
  secretaryName: '矢矧改二乙',
);
expect((await database.getPendingConstructionRecordForDock(2))?['id'], id);
await database.updateConstructionResult(
  recordId: id,
  dockId: 2,
  shipId: 1,
  shipName: '雪风',
  shipType: '驱逐舰',
  markCollected: true,
);
expect(await database.getPendingConstructionRecordForDock(2), isNull);
```

- [ ] **步骤 2：运行数据库测试并确认接口缺失导致失败**

```powershell
flutter test test/logbook_database_test.dart --plain-name "construction pending mapping survives until collection" --reporter expanded
```

预期：编译失败，提示新接口尚未定义。

- [ ] **步骤 3：实现 v8 表结构和事务接口**

```sql
CREATE TABLE IF NOT EXISTS pending_construction_logs (
  dock_id INTEGER PRIMARY KEY,
  record_id INTEGER NOT NULL
)
```

`insertConstructionStartRecord` 在一个事务里插入日志并 replace 映射。`getPendingConstructionRecordForDock` 联结并返回日志行。`updateConstructionResult(markCollected: true)` 在同一事务更新日志并删除映射。`clearAll` 先清映射表。

- [ ] **步骤 4：运行数据库测试确认通过**

```powershell
flutter test test/logbook_database_test.dart --reporter expanded
```

预期：全部通过。

### 任务 3：让收取事件复用持久化记录

**文件：**
- 修改：`lib/src/logbook/logbook_event_recorder.dart`
- 测试：`test/logbook_event_recorder_test.dart`

- [ ] **步骤 1：建造开始改用 `insertConstructionStartRecord`**

```dart
final recordId = await _database.insertConstructionStartRecord(
  dockId: dockId,
  timestamp: pending.timestamp,
  constructionType: pending.constructionType,
  shipId: shipId > 0 ? shipId : null,
  shipName: master?.name ?? '建造中',
  shipType: shipType ?? '—',
  fuel: pending.fuel,
  ammo: pending.ammo,
  steel: pending.steel,
  bauxite: pending.bauxite,
  developmentMaterial: pending.developmentMaterial,
  secretaryName: pending.secretaryName,
);
```

- [ ] **步骤 2：内存记录 ID 缺失时调用 `getPendingConstructionRecordForDock`**

匹配规则为：船坞一致；已记录舰娘 ID 为空或等于收取舰娘；配方和建造类型一致；能还原开始时间时继续使用 5 秒容差，无法还原时信任持久化船坞映射。

```dart
if (recordId <= 0) {
  final persisted = await _database.getPendingConstructionRecordForDock(
    dockId,
  );
  if (_persistedConstructionMatches(
    persisted,
    currentDock: currentDock,
    master: master,
    shipId: shipId,
  )) {
    recordId = _int(persisted?['id']);
  }
}
```

- [ ] **步骤 3：`getship` 更新传入 `markCollected: true`**

`kdock` 提前揭示舰娘时保持默认 `false`，不能提前删除映射。

```dart
await _database.updateConstructionResult(
  recordId: recordId,
  dockId: dockId,
  shipId: shipId,
  shipName: master?.name ?? '舰娘 ID $shipId',
  shipType: shipType ?? '未知舰种',
  markCollected: true,
);
```

- [ ] **步骤 4：运行回归测试确认由红转绿**

```powershell
flutter test test/logbook_event_recorder_test.dart --reporter expanded
```

预期：全部通过。

### 任务 4：格式化、静态检查与完整验证

**文件：**
- 验证：`lib/src/logbook/logbook_database.dart`
- 验证：`lib/src/logbook/logbook_event_recorder.dart`
- 验证：`test/logbook_database_test.dart`
- 验证：`test/logbook_event_recorder_test.dart`

- [ ] **步骤 1：格式化目标文件**

```powershell
dart format lib/src/logbook/logbook_database.dart lib/src/logbook/logbook_event_recorder.dart test/logbook_database_test.dart test/logbook_event_recorder_test.dart
```

- [ ] **步骤 2：运行静态检查**

```powershell
flutter analyze lib/src/logbook/logbook_database.dart lib/src/logbook/logbook_event_recorder.dart test/logbook_database_test.dart test/logbook_event_recorder_test.dart
```

预期：`No issues found!`

- [ ] **步骤 3：运行完整测试套件**

```powershell
flutter test --reporter compact
```

预期：退出码 0，0 项失败。

- [ ] **步骤 4：核对变更范围**

```powershell
git diff --check
git status --short
```

- [ ] **步骤 5：只提交日志修复相关文件**

```powershell
git add lib/src/logbook/logbook_database.dart lib/src/logbook/logbook_event_recorder.dart test/logbook_database_test.dart test/logbook_event_recorder_test.dart
git add -f docs/superpowers/specs/2026-08-23-construction-log-deduplication-design.md docs/superpowers/plans/2026-08-23-construction-log-deduplication.md
git commit -m "fix: 避免建造日志跨会话重复记录"
```
