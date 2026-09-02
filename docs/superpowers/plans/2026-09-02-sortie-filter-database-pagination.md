# 出击记录筛选数据库分页实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 让出击筛选首次显示全部历史海域和状态，并让筛选结果通过数据库分页读取。

**架构：** `LogbookDatabase` 提供轻量筛选目录和带条件的联合分页查询；`_LogbookTablePageState` 缓存目录、把显示标签映射为海域身份，并在筛选切换时重置分页。查询代次阻止旧异步结果污染新筛选结果。

**技术栈：** Flutter、Dart、sqflite、flutter_test。

---

## 文件结构

- 修改：`lib/src/logbook/logbook_database.dart`——定义出击筛选值对象，查询完整筛选目录，并在联合查询外应用条件和分页。
- 修改：`lib/src/logbook/logbook_page.dart`——加载筛选目录、生成完整候选项、切换筛选时重新查询数据库。
- 修改：`test/logbook_database_test.dart`——覆盖完整目录、联合表去重、条件过滤和分页。
- 修改：`test/logbook_page_test.dart`——复现首批之外海域缺失，并验证选择历史海域后能显示记录。

### 任务 1：数据库筛选目录

**文件：**
- 修改：`lib/src/logbook/logbook_database.dart:12-70,634-681`
- 测试：`test/logbook_database_test.dart`

- [ ] **步骤 1：编写失败的目录测试**

插入 battle 和 resource 记录，其中相同海域跨表重复，另一个海域只存在于旧记录。断言新接口返回去重后的全部海域及完整状态：

```dart
final catalog = await database.getSortieFilterCatalog();
expect(catalog.maps.map((map) => map.mapNo), unorderedEquals(<int>[1, 2]));
expect(catalog.statuses, containsAll(<String>['普通战斗', '资源获得']));
```

- [ ] **步骤 2：运行测试并确认红灯**

运行：

```powershell
flutter test test/logbook_database_test.dart --plain-name "sortie filter catalog includes all historical maps and statuses"
```

预期：编译失败，因为 `getSortieFilterCatalog` 尚不存在。

- [ ] **步骤 3：实现最小目录查询**

增加不可变值对象：

```dart
final class SortieMapIdentity {
  const SortieMapIdentity({
    required this.mapArea,
    required this.mapNo,
    required this.mapName,
    required this.mapDifficulty,
  });

  final int mapArea;
  final int mapNo;
  final String mapName;
  final int mapDifficulty;
}

final class SortieFilterCatalog {
  const SortieFilterCatalog({required this.maps, required this.statuses});
  final List<SortieMapIdentity> maps;
  final List<String> statuses;
}
```

`getSortieFilterCatalog` 使用 `UNION` 查询两个出击表的海域元数据，并使用第二个 `UNION` 查询 battle 的 `node_type` 与 resource 的固定状态“资源获得”。

- [ ] **步骤 4：运行目录测试并确认绿灯**

运行：

```powershell
flutter test test/logbook_database_test.dart --plain-name "sortie filter catalog includes all historical maps and statuses"
```

预期：测试通过。

- [ ] **步骤 5：提交任务 1**

```powershell
git add lib/src/logbook/logbook_database.dart test/logbook_database_test.dart
git commit -m "feat(航海日志): 添加出击筛选目录查询"
```

### 任务 2：数据库条件分页

**文件：**
- 修改：`lib/src/logbook/logbook_database.dart:634-681`
- 测试：`test/logbook_database_test.dart`

- [ ] **步骤 1：编写失败的条件分页测试**

创建 `SortieRecordQuery`，分别验证日期、海域、资源状态、战斗状态和评价条件；再插入超过 50 条匹配记录，确认两页不重不漏：

```dart
final rows = await database.getSortieRecords(
  query: SortieRecordQuery(
    maps: <SortieMapIdentity>[targetMap],
    status: '普通战斗',
    rank: 'S',
  ),
);
expect(rows.every((row) => row['map_no'] == targetMap.mapNo), isTrue);
```

- [ ] **步骤 2：运行测试并确认红灯**

运行：

```powershell
flutter test test/logbook_database_test.dart --plain-name "sortie record query filters the union before pagination"
```

预期：编译失败，因为 `SortieRecordQuery` 和 `query` 参数尚不存在。

- [ ] **步骤 3：实现最小条件查询**

增加：

```dart
final class SortieRecordQuery {
  const SortieRecordQuery({
    this.sinceTimestamp,
    this.maps = const <SortieMapIdentity>[],
    this.status,
    this.rank,
  });
  final int? sinceTimestamp;
  final List<SortieMapIdentity> maps;
  final String? status;
  final String? rank;
}
```

在现有联合子查询外构造参数化 `WHERE`：海域身份以括号包裹的 `OR` 条件匹配；“资源获得”匹配 resource，其余状态匹配 battle 的 `node_type`；评价匹配大写后的 `rank`。保持原排序和 `LIMIT/OFFSET`。

- [ ] **步骤 4：运行数据库测试并确认绿灯**

运行：

```powershell
flutter test test/logbook_database_test.dart
```

预期：全部通过。

- [ ] **步骤 5：提交任务 2**

```powershell
git add lib/src/logbook/logbook_database.dart test/logbook_database_test.dart
git commit -m "fix(航海日志): 在数据库执行出击筛选分页"
```

### 任务 3：页面接入完整目录和筛选分页

**文件：**
- 修改：`lib/src/logbook/logbook_page.dart:235-580`
- 测试：`test/logbook_page_test.dart:1007-1144,1522-1580`

- [ ] **步骤 1：编写失败的 Widget 测试**

插入 50 条近期同海域记录和 1 条旧海域记录。首次打开面板时断言旧海域已经存在；选择并应用后断言表格显示旧记录：

```dart
await tester.tap(find.byKey(const Key('logbook-filter-button')));
await tester.pumpAndSettle();
expect(optionsFor('map'), contains('历史海域 (9-9)'));
await selectDropdownOption(tester, 'map', '历史海域 (9-9)');
await tester.tap(find.byKey(const Key('logbook-filter-apply')));
await tester.pumpAndSettle();
expect(find.textContaining('历史海域'), findsOneWidget);
```

- [ ] **步骤 2：运行测试并确认红灯**

运行：

```powershell
flutter test test/logbook_page_test.dart --plain-name "sortie filter discovers and loads a map outside the first page"
```

预期：失败，首次候选项不包含旧海域。

- [ ] **步骤 3：实现目录状态和查询映射**

页面保存：

```dart
SortieFilterCatalog? _sortieFilterCatalog;
Map<String, List<SortieMapIdentity>> _sortieMapsByLabel = const {};
int _queryGeneration = 0;
```

初始化和 battle 变更时刷新目录。`_filterFields` 从目录生成海域与状态选项；`_showFilter` 在出击分类中等待目录首次加载。

- [ ] **步骤 4：实现筛选切换分页**

把字符串筛选值转换为 `SortieRecordQuery`。应用筛选时增加 `_queryGeneration`、清空 `_records`、恢复 `_hasMore` 并加载第一页；`_loadMore` 和 `_refreshLatest` 只接纳与当前代次相同的查询结果。

- [ ] **步骤 5：运行 Widget 测试并确认绿灯**

运行：

```powershell
flutter test test/logbook_page_test.dart --plain-name "sortie filter discovers and loads a map outside the first page"
```

预期：测试通过。

- [ ] **步骤 6：提交任务 3**

```powershell
git add lib/src/logbook/logbook_page.dart test/logbook_page_test.dart
git commit -m "fix(航海日志): 完整加载出击筛选候选"
```

### 任务 4：刷新与回归验证

**文件：**
- 修改：`test/logbook_page_test.dart`
- 验证：`lib/src/logbook/logbook_database.dart`
- 验证：`lib/src/logbook/logbook_page.dart`

- [ ] **步骤 1：补充目录刷新测试**

页面加载后插入一个新海域记录，等待数据库变更通知，再次打开筛选并断言新海域出现。重置筛选后断言恢复最近记录。

- [ ] **步骤 2：运行航海日志相关测试**

```powershell
flutter test test/logbook_database_test.dart test/logbook_event_recorder_test.dart test/logbook_page_test.dart --reporter compact
```

预期：全部通过。

- [ ] **步骤 3：运行格式和静态检查**

```powershell
dart format --output=none --set-exit-if-changed lib/src/logbook/logbook_database.dart lib/src/logbook/logbook_page.dart test/logbook_database_test.dart test/logbook_page_test.dart
flutter analyze lib/src/logbook/logbook_database.dart lib/src/logbook/logbook_page.dart test/logbook_database_test.dart test/logbook_page_test.dart
git diff --check
```

预期：全部退出码为 0。

- [ ] **步骤 4：提交任务 4**

```powershell
git add test/logbook_page_test.dart
git commit -m "test(航海日志): 覆盖出击筛选目录刷新"
```

- [ ] **步骤 5：执行全量测试**

```powershell
flutter test --reporter compact
```

预期：全部测试通过，允许项目明确标记的跳过项。
