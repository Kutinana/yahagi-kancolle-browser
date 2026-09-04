# 装备开发名称本地化实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 让装备开发页的装备名称随简体中文、繁体中文和日文界面切换，消除日文原名造成的字体不一致观感。

**架构：** 数据同步阶段把上游三语言装备名称写入开发快照，领域模型负责按 Locale 选择名称并回退日文原名。所有开发页组件复用这一入口，控制器搜索覆盖原名与全部译名。

**技术栈：** Flutter、Dart、JSON 资源、flutter_test

---

## 文件结构

- 修改 `tool/development_data/development_snapshot_builder.dart`：将本地化装备名写入快照。
- 修改 `tool/development_data/sync.dart`：读取三语言 `items.json` 并计入来源哈希。
- 修改 `assets/data/development/development_snapshot.json`：重新生成含三语言名称的数据。
- 修改 `lib/src/development/development_dataset.dart`：解析名称映射并按 Locale 选名。
- 修改 `lib/src/development/equipment_development_controller.dart`：搜索所有可用名称。
- 修改 `lib/src/development/development_equipment_picker.dart`、`development_output_table.dart`、`equipment_development_page.dart`：传递当前 Locale 并统一显示入口。
- 修改 `test/development/development_snapshot_builder_test.dart` 与相关开发组件测试：覆盖构建、回退、显示及搜索。

### 任务 1：快照写入多语言装备名

- [ ] **步骤 1：编写失败的构建器测试**

在 `development_snapshot_builder_test.dart` 的测试输入加入：

```dart
localizedEquipmentNames: const {
  'zh': {7: '测试主炮'},
  'zh_Hant': {7: '測試主砲'},
  'ja': {7: 'テスト主砲'},
},
```

并断言装备记录包含三语言 `names`；ID 8 缢失翻译时三语言均回退 `api_name`。

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/development/development_snapshot_builder_test.dart`

预期：FAIL，原因是 `localizedEquipmentNames` 尚未定义。

- [ ] **步骤 3：实现最少构建逻辑**

给 `buildDevelopmentSnapshot` 增加：

```dart
Map<String, Map<int, String>> localizedEquipmentNames = const {},
```

输出装备时生成 `names`，各语言缺值回退原始 `name`。

- [ ] **步骤 4：运行测试验证通过**

运行：`flutter test test/development/development_snapshot_builder_test.dart`

预期：全部通过。

### 任务 2：同步并解析本地化名称

- [ ] **步骤 1：编写失败的数据模型测试**

在开发数据集测试中构造含 `names` 的记录，断言：

```dart
expect(item.label(const Locale('zh')), '测试主炮');
expect(item.label(const Locale('zh', 'TW')), '測試主砲');
expect(item.label(const Locale('ja')), 'テスト主砲');
```

- [ ] **步骤 2：运行测试验证失败**

运行对应开发数据集测试，预期因 `label` 不存在而失败。

- [ ] **步骤 3：实现模型与同步输入**

`DevelopmentEquipmentRecord` 保存不可变 `names`，并用语言及国家代码选择 `zh`、`zh_Hant`、`ja`。`sync.dart` 读取三份 `items.json`、纳入哈希，再传给构建器。

- [ ] **步骤 4：重新生成开发快照**

运行：

```powershell
dart run tool/development_data/sync.dart --source-dir "G:\kancolle project\.codex-work\kc-development-tools-d065120" --output assets/data/development/development_snapshot.json
```

预期：生成成功，装备记录含 `names`。

- [ ] **步骤 5：运行模型与同步测试**

运行开发数据相关测试，预期全部通过。

### 任务 3：开发页统一使用本地化名称

- [ ] **步骤 1：编写失败的组件与搜索测试**

断言简体 Locale 下选择器、已选标签和出货表格显示 `测试主炮` 而非日文原名，并断言搜索繁体译名仍能命中同一装备。

- [ ] **步骤 2：运行测试验证失败**

运行对应装备开发测试，预期仍显示原名或缺少 Locale 参数。

- [ ] **步骤 3：实现统一显示入口**

组件从 `Localizations.localeOf(context)` 获取 Locale，并调用 `record.label(locale)`；控制器过滤时匹配 `record.searchableNames`，不再以实时游戏日文主数据覆盖开发页名称。

- [ ] **步骤 4：运行装备开发测试**

运行：`flutter test test/development`

预期：全部通过。

### 任务 4：完整验证与 Debug 构建

- [ ] **步骤 1：格式化修改文件**

运行：`dart format`，仅包含本计划修改的 Dart 文件。

- [ ] **步骤 2：运行静态分析与相关测试**

运行：

```powershell
flutter analyze
flutter test test/development test/font_family_audit_test.dart test/locale_font_mapping_test.dart
```

预期：0 error，全部测试通过。

- [ ] **步骤 3：构建 Debug APK，不安装**

运行：`flutter build apk --debug`

预期：生成 `build/app/outputs/flutter-apk/app-debug.apk`，不执行任何安装命令。

- [ ] **步骤 4：提交实现**

只暂存本计划修改的文件，提交信息：`fix(装备开发): 统一本地化装备名称`。
