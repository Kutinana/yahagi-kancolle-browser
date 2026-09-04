# 秘书舰适用范围标签实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在开发工作台的秘书舰双栏选择器中恢复本地化的完整适用舰娘或舰级说明。

**架构：** 同步工具根据上游固定版本的结构化条件和名称表生成多语言描述，并随开发池写入内置快照。运行时数据模型只负责选择正确语言，选择器负责组合池名与描述，不承担规则翻译。

**技术栈：** Dart、Flutter、flutter_test、JSON 快照生成工具

---

### 任务 1：锁定描述生成行为

**文件：**
- 修改：`test/development/development_snapshot_builder_test.dart`
- 修改：`tool/development_data/development_snapshot_builder.dart`

- [ ] **步骤 1：编写失败的测试**

为舰名条件和数字舰级条件断言生成 `zh`、`zh_Hant`、`ja` 三种描述，其中简体示例为 `利托里奥、罗马、扎拉` 与 `西北风级`。

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/development/development_snapshot_builder_test.dart`

预期：FAIL，池数据中不存在 `descriptions`。

- [ ] **步骤 3：编写最少实现代码**

扩展生成器输入，接收三种语言的舰名、舰级与舰种名称表；按结构化条件生成本地化描述并写入池数据。

- [ ] **步骤 4：运行测试验证通过**

运行：`flutter test test/development/development_snapshot_builder_test.dart`

预期：PASS。

### 任务 2：接入同步脚本和运行时模型

**文件：**
- 修改：`tool/development_data/sync.dart`
- 修改：`lib/src/development/development_dataset.dart`
- 修改：`test/development/development_dataset_test.dart`
- 修改：`assets/data/development/development_snapshot.json`

- [ ] **步骤 1：编写失败的模型测试**

断言 `DevelopmentPoolRecord.description(Locale)` 能选择简体、繁体、日文描述。

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/development/development_dataset_test.dart`

预期：FAIL，模型尚无 `description`。

- [ ] **步骤 3：实现并重新生成快照**

同步脚本读取上游 `public/data/i18n` 名称表与 `stypeNames.ts`，生成新快照；模型解析 `descriptions` 并按 locale 返回值。

- [ ] **步骤 4：运行测试验证通过**

运行：`flutter test test/development/development_dataset_test.dart test/development/development_snapshot_builder_test.dart`

预期：PASS。

### 任务 3：选择器显示完整标签

**文件：**
- 修改：`lib/src/development/development_secretary_picker.dart`
- 修改：`test/development/development_secretary_picker_test.dart`

- [ ] **步骤 1：编写失败的组件测试**

断言右栏出现 `意（利托里奥、罗马、扎拉）`，顶部已选项出现 `炮战系-意（利托里奥、罗马、扎拉）`。

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/development/development_secretary_picker_test.dart`

预期：FAIL，只找到简称。

- [ ] **步骤 3：实现最少显示逻辑**

新增统一的完整标签组合函数，右栏使用去掉系别的池名加描述，顶部使用完整池名加描述；文本保持单行省略。

- [ ] **步骤 4：运行专项测试和静态检查**

运行：`flutter test test/development`，随后运行：`dart analyze lib/src/development test/development tool/development_data`

预期：全部通过且无诊断。

