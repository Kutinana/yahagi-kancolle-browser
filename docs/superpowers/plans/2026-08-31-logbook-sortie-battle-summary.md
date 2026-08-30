# 航海日志出击战斗摘要列实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在航海日志出击记录的「状态」和「评价」之间显示双方阵形、制空状态和顿号分隔的大破舰娘，并可靠持久化这些数据。

**架构：** 扩展现有 SQLite `battle_logs` 表并在 `insertBattleRecord` 中从 `LiveBattle` 投影新字段；联合查询为资源记录补齐默认列。UI 继续使用 `FrozenDataTable`，复用战斗模块的阵形文案和制空配色，并为大破舰娘文本计算自适应行高。

**技术栈：** Flutter、Dart、sqflite_common_ffi、flutter_test

---

## 文件结构

- 修改 `lib/src/logbook/logbook_database.dart`：数据库 v10 迁移、新字段写入和出击联合查询。
- 修改 `lib/src/logbook/logbook_page.dart`：新增四列、方案 A 胶囊与大破舰娘换行行高。
- 修改 `test/logbook_database_test.dart`：持久化和 v9 升级回归测试。
- 修改 `test/logbook_page_test.dart`：列顺序、胶囊样式、顿号分隔和行高测试。

### 任务 1：战斗摘要持久化

**文件：**
- 修改：`test/logbook_database_test.dart`
- 修改：`lib/src/logbook/logbook_database.dart`

- [ ] **步骤 1：编写失败的数据库测试**

  构造包含双方阵形、制空状态以及主力/护卫大破舰娘的 `LiveBattle`，断言数据库行包含 `friend_formation = 1`、`enemy_formation = 5`、`air_superiority = '优势'` 和按舰队顺序编码的 `heavy_damage_ship_names_json`。

- [ ] **步骤 2：运行测试验证失败**

  运行：`flutter test test/logbook_database_test.dart --plain-name "battle records persist formation air state and heavy damage ships"`

  预期：FAIL，新字段尚不存在。

- [ ] **步骤 3：实现最小数据库变更**

  将 schema 升为 10，在建表和升级路径增加四列，并在 `insertBattleRecord` 中写入：

  ```dart
  'friend_formation': battle.friendFormation,
  'enemy_formation': battle.enemyFormation,
  'air_superiority': battle.airSuperiority ?? '未知',
  'heavy_damage_ship_names_json': jsonEncode(<String>[
    for (final ship in battle.friendShips)
      if (ship.isHeavilyDamaged) ship.name,
  ]),
  ```

  同时在 `getSortieRecords` 的 battle/resource 两侧投影一致字段。

- [ ] **步骤 4：运行数据库测试验证通过**

  运行：`flutter test test/logbook_database_test.dart`

  预期：PASS。

### 任务 2：方案 A 表格呈现

**文件：**
- 修改：`test/logbook_page_test.dart`
- 修改：`lib/src/logbook/logbook_page.dart`

- [ ] **步骤 1：编写失败的 Widget 测试**

  插入具有多艘大破舰娘的记录，断言标题顺序为「状态、我方阵形、敌方阵形、制空状态、大破舰娘、评价」，显示 `矢矧改二乙、雪风改二`，双方阵形和制空状态使用语义胶囊，并且长舰名记录行高大于 44。

- [ ] **步骤 2：运行测试验证失败**

  运行：`flutter test test/logbook_page_test.dart --plain-name "sortie shows formation air state and separated heavy damage ships"`

  预期：FAIL，新列与组件尚不存在。

- [ ] **步骤 3：实现最小 UI 变更**

  在 `_tableSpec` 的状态与评价之间加入 96、96、102、166 宽度的四列；使用 `formationLabel`、`airSuperiorityPillColors` 和本地紧凑胶囊组件。解析大破舰娘 JSON 后使用 `join('、')`，通过 `TextPainter` 计算大破列所需高度并传给 `FrozenDataTable.rowHeights`。

- [ ] **步骤 4：运行 Widget 测试验证通过**

  运行：`flutter test test/logbook_page_test.dart`

  预期：PASS。

### 任务 3：回归验证与审查

**文件：**
- 复核：上述全部变更文件

- [ ] **步骤 1：格式化与静态检查**

  运行：`dart format lib/src/logbook/logbook_database.dart lib/src/logbook/logbook_page.dart test/logbook_database_test.dart test/logbook_page_test.dart`

  运行：`flutter analyze`

  预期：无 error/warning。

- [ ] **步骤 2：运行航海日志与完整战斗语料测试**

  运行：`flutter test test/logbook_database_test.dart test/logbook_event_recorder_test.dart test/logbook_page_test.dart test/battle_poi_corpus_test.dart`

  预期：全部 PASS。

- [ ] **步骤 3：审查变更**

  检查 schema 升级兼容性、资源行默认值、阵形/制空映射、大破边界、长文本布局及无关改动；修复所有必须修复和重要问题后重新运行验证。

- [ ] **步骤 4：提交 master**

  ```text
  feat(航海日志): 增加出击战斗摘要列
  ```

