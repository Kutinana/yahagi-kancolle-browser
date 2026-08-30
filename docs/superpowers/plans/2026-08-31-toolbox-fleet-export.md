# 工具箱舰队导出实现计划

> **执行要求：** 使用 `executing-plans` 按任务逐项执行，并在每项生产代码之前遵循 `test-driven-development` 的红—绿—重构循环。

**目标：** 在 Yahagi 新增独立「工具箱」工作区，支持把当前母港编成以 DeckBuilder v4 格式复制或通过系统默认浏览器发送至 noro6/Jervis，并保留可扩展的「其他」子页。

**架构：** 纯 Dart 导出器负责把 `GameState` 转为 DeckBuilder v4；独立 URI 构造与启动层负责外部浏览器；Flutter 页面只管理筛选、文本快照与反馈。工具箱使用新工作区索引 10，现有索引不变，标题栏分段按钮沿用项目既有视觉参数。

**技术栈：** Flutter、Dart、`url_launcher`、Flutter Clipboard、ARB/gen-l10n、flutter_test。

---

## 任务 1：DeckBuilder v4 数据契约

**文件：**
- 新建：`test/deck_builder_exporter_test.dart`
- 新建：`lib/src/toolbox/deck_builder_exporter.dart`

1. 先写最小状态测试，断言 `version: 4`、`hqlv` 和舰队/舰娘基本字段；运行 `flutter test test/deck_builder_exporter_test.dart`，确认因导出器不存在而失败。
2. 实现 `DeckBuilderExporter.exportMap(GameState, {bool eventLandBasesOnly = true})` 和 `exportJson`，只满足最小测试；重跑至通过。
3. 增加失败测试，覆盖联合舰队 `f1.t`、舰队与舰娘顺序、缺失舰娘引用跳过。
4. 增加失败测试，覆盖普通槽原始索引、空槽、增设槽、`rf: 0` 和正熟练度 `mas`；实现并验证。
5. 增加失败测试，覆盖活动海域 `areaId >= 30` 默认筛选、关闭筛选、陆航连续编号、空中队原位置和缺失装备；实现并验证。
6. 增加 JSON 往返解析测试，运行该测试文件全部通过。
7. 提交：`feat(工具箱): 实现 DeckBuilder v4 导出器（任务 1/5）`。

## 任务 2：外部舰队工具 URI 与系统浏览器

**文件：**
- 新建：`test/external_fleet_tool_launcher_test.dart`
- 新建：`lib/src/toolbox/external_fleet_tool_launcher.dart`

1. 先写失败测试，定义 `ExternalFleetTool.noro6/jervis`，分别断言 HTTPS 主机、路径和 `predeck` 查询参数可无损解码 JSON。
2. 运行 `flutter test test/external_fleet_tool_launcher_test.dart`，确认因实现缺失失败。
3. 用 `Uri.replace(queryParameters: {'predeck': json})` 实现纯 URI 构造，重跑至通过。
4. 添加可注入的 `ExternalFleetToolLauncher`，默认调用 `launchUrl(..., mode: LaunchMode.externalApplication)`；测试注入回调能收到 URI并返回成功/失败。
5. 提交：`feat(工具箱): 支持外部舰队工具链接（任务 2/5）`。

## 任务 3：本地化与工具箱页面

**文件：**
- 修改：`lib/l10n/app_zh.arb`
- 修改：`lib/l10n/app_zh_Hant.arb`
- 修改：`lib/l10n/app_ja.arb`
- 生成：`lib/l10n/app_localizations.dart`
- 生成：`lib/l10n/app_localizations_zh.dart`
- 生成：`lib/l10n/app_localizations_ja.dart`
- 新建：`lib/src/toolbox/toolbox_mode_tabs.dart`
- 新建：`lib/src/toolbox/toolbox_page.dart`
- 新建：`lib/src/toolbox/fleet_export_page.dart`
- 新建：`test/toolbox_page_test.dart`

1. 给三种 ARB 增加工具箱、舰队导出、其他、筛选、文本、刷新、复制、系统浏览器、等待数据、开发中及成功/失败反馈文案，运行 `flutter gen-l10n`。
2. 先写页面失败测试：有母港数据时默认展示舰队导出、活动陆航开关默认开启、首次生成文本，且不出现舰队/舰娘/陆航数量统计。
3. 运行 `flutter test test/toolbox_page_test.dart`，确认页面类型缺失导致失败。
4. 实现 `ToolboxMode`、`ToolboxPage` 和 `FleetExportPage` 的最小版本，通过依赖注入接收外部启动与复制回调；文本快照只在首次、刷新或目标按钮点击时更新。
5. 增加失败测试：无母港数据时禁用目标按钮并显示等待状态；刷新使用最新状态；复制反馈；启动失败保留文本并提示。
6. 增加失败测试：切换到「其他」显示开发中；窄屏单栏和横屏双栏均无溢出。
7. 实现响应式布局和与现有页面一致的面板/按钮样式，运行页面测试及本地化审计测试。
8. 提交：`feat(工具箱): 添加舰队导出页面（任务 3/5）`。

## 任务 4：工作区导航和标题栏接入

**文件：**
- 修改：`lib/main.dart`
- 修改：`lib/src/layout/workspace_context_header.dart`
- 修改：`lib/src/settings/layout_settings_store.dart`
- 修改：`test/workspace_context_header_test.dart`
- 修改：`test/workspace_navigation_order_test.dart`
- 修改：`test/layout_settings_behavior_test.dart`
- 修改：`test/prototype_shell_test.dart`

1. 先写标题栏失败测试：索引 10 显示「工具箱」和右上「舰队导出／其他」分段按钮，点击回调改变选中模式。
2. 先写菜单失败测试：默认顺序中 `tools` 位于 `owned-inventory` 与 `settings` 之间；旧自定义顺序归一化后补入 `tools` 且保留旧项相对顺序。
3. 先写 Shell 失败测试：点击「工具箱」展示 `ToolboxPage`，现有 0–9 索引行为不变。
4. 分别运行上述测试，确认失败原因是入口/索引尚未接入。
5. 在 `_PrototypeShellState` 增加非持久化 `ToolboxMode` 状态，把 `ToolboxPage` 接到索引 10，并将状态传给 `WorkspaceContextHeader`。
6. 在 `_workspaceDestinations` 和默认菜单顺序中加入稳定 ID `tools`；不重编号已有工作区。
7. 实现 `ToolboxModeTabs`，复用现有 38 px 金色胶囊视觉参数并接入标题栏。
8. 运行四个相关测试文件至全部通过。
9. 提交：`feat(导航): 接入工具箱工作区（任务 4/5）`。

## 任务 5：完整验证与收尾

**文件：**
- 仅在验证发现问题时修改对应实现或测试文件。

1. 运行 `dart format lib/src/toolbox test/deck_builder_exporter_test.dart test/external_fleet_tool_launcher_test.dart test/toolbox_page_test.dart lib/main.dart lib/src/layout/workspace_context_header.dart lib/src/settings/layout_settings_store.dart`。
2. 运行定向测试：`flutter test test/deck_builder_exporter_test.dart test/external_fleet_tool_launcher_test.dart test/toolbox_page_test.dart test/workspace_context_header_test.dart test/workspace_navigation_order_test.dart test/layout_settings_behavior_test.dart test/prototype_shell_test.dart`。
3. 运行 `flutter analyze`，要求 0 error。
4. 运行完整 `flutter test`，要求除仓库既有显式 skip 外全部通过。
5. 用 `rg` 检查页面无硬编码中文/日文、无舰队/舰娘/陆航统计文案、无已删除副标题。
6. 检查 `git diff --check`、`git status --short` 和提交历史，确保未提交忽略夹具或无关文件。
7. 如验证促成修复，提交：`test(工具箱): 完善舰队导出回归验证（任务 5/5）`。
8. 使用 `verification-before-completion` 和 `finishing-a-development-branch` 完成最终核验与分支交付。
