# 战果三页正式接入实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在现有真实战果采集链路上实现三页响应式战果中心、三态奖励计算和本地出击海域统计，并交付 Android Debug 构建。

**架构：** 保留 `SenkaController → SenkaReducer → SenkaState → SenkaStore` 数据流，扩展状态与 reducer 处理奖励、计算输入和出击事件。页面壳只负责三页切换，信息、日历、计算分别由独立视图渲染；计算公式放在纯 Dart 模型中，便于无 Widget 单测。

**技术栈：** Flutter/Dart、Material 3、SharedPreferences、flutter_test、Android Gradle Debug 构建。

---

## 文件结构

- 修改 `lib/src/senka/senka_catalog.dart`：完整 EO、季度、年度、单次任务目录及服务器编号映射。
- 修改 `lib/src/senka/senka_state.dart`：奖励三态、计算输入、出击统计、迁移与序列化。
- 创建 `lib/src/senka/senka_calculation.dart`：实时计算结果和业务日公式。
- 修改 `lib/src/senka/senka_reducer.dart`：真实出击/Boss/胜利统计与 EO 自动完成。
- 修改 `lib/src/senka/senka_controller.dart`：三态循环、输入更新、海域操作。
- 修改 `lib/src/capture/game_capture_path_catalog.dart`：把出击事件分发给战果 consumer。
- 修改 `lib/src/senka/senka_page.dart`：三页切换壳和响应式入口。
- 创建 `lib/src/senka/senka_info_view.dart`：服务器概况、排名、出击统计。
- 创建 `lib/src/senka/senka_calendar_view.dart`：独立月历页。
- 创建 `lib/src/senka/senka_calculator_view.dart`：3∶7 计算布局与奖励矩阵。
- 创建 `lib/src/senka/senka_ui.dart`：共享色板、面板和格式函数。
- 修改 `test/senka_reducer_test.dart`、`test/senka_controller_test.dart`、`test/senka_page_test.dart`，创建 `test/senka_calculation_test.dart`。

### 任务 1：状态、目录和迁移

- [ ] **步骤 1：编写失败测试**

在 `test/senka_controller_test.dart` 和 `test/senka_calculation_test.dart` 添加断言：旧 `completed*Ids` 迁移为完成态，未知状态回退放置；奖励按黄→绿→灰循环；年度和单次目录包含 947、948、949。

```dart
expect(SenkaRewardStatus.fromStorage('bad'), SenkaRewardStatus.deferred);
expect(state.rewardStatus(947), SenkaRewardStatus.deferred);
controller.cycleQuestReward(947);
expect(controller.state.rewardStatus(947), SenkaRewardStatus.planned);
```

- [ ] **步骤 2：确认红灯**

运行 `flutter test test/senka_controller_test.dart test/senka_calculation_test.dart`，预期因类型和方法尚不存在而失败。

- [ ] **步骤 3：最小实现**

实现 `SenkaRewardStatus`、分类目录、状态映射、兼容 JSON 和纯计算模型。状态序列固定为：

```dart
SenkaRewardStatus get next => switch (this) {
  deferred => planned,
  planned => completed,
  completed => deferred,
};
```

- [ ] **步骤 4：确认绿灯并提交**

运行上述测试，预期通过；提交 `feat(战果): 扩展奖励三态与计算状态`。

### 任务 2：真实出击统计

- [ ] **步骤 1：编写失败测试**

在 `test/senka_reducer_test.dart` 依次发送 `api_req_map/start`、Boss `next`、`battleresult`，验证同一海域 `sorties=1`、`boss=1`、S/A 单独累计；演习与缺失上下文不计入。

```dart
expect(state.sortieStats['1-5']?.sorties, 1);
expect(state.sortieStats['1-5']?.boss, 1);
expect(state.sortieStats['1-5']?.sWins, 1);
```

- [ ] **步骤 2：确认红灯**

运行 `flutter test test/senka_reducer_test.dart`，预期因统计字段不存在而失败。

- [ ] **步骤 3：最小实现**

扩展路径目录与 reducer：start 创建上下文并增加出击，start/next 到 Boss 时只增加一次 Boss，Boss 结算读取 `api_win_rank` 增加 S/SS 或 A；上下文只保留当前出击且安全序列化。

- [ ] **步骤 4：确认绿灯并提交**

运行 reducer 测试，预期通过；提交 `feat(战果): 记录本地出击海域统计`。

### 任务 3：控制器与实时计算

- [ ] **步骤 1：编写失败测试**

覆盖当前/目标输入更新、计划值只统计 `planned`、完成值不重复统计、剩余日数/素战果/每日所需/今日剩余两位小数口径、收藏和隐藏持久化。

```dart
expect(result.projectedSenka, 1678);
expect(result.todayRemaining, max(0, result.dailyRequired - today.total));
```

- [ ] **步骤 2：确认红灯**

运行 controller/calculation 测试并确认新断言失败。

- [ ] **步骤 3：最小实现**

新增 `setCurrentSenka`、`setTargetSenka`、`cycleEoReward`、`cycleQuestReward`、`toggleSortieFavorite`、`toggleSortieHidden`；所有更新复用 `_replace` 串行保存。

- [ ] **步骤 4：确认绿灯并提交**

运行专项测试，预期通过；提交 `feat(战果): 接入实时目标计算与海域操作`。

### 任务 4：三页响应式 UI

- [ ] **步骤 1：重写 Widget 失败测试**

在五档尺寸逐页切换，断言页签、最终分组标题、3×2 指标顺序、表头、两位小数、奖励状态语义和无 Flutter overflow；横屏检查信息等宽双栏与计算 3∶7，竖屏检查视觉顺序。

```dart
expect(find.text('战果信息'), findsOneWidget);
expect(find.text('战果日历'), findsOneWidget);
expect(find.text('战果计算'), findsOneWidget);
expect(find.text('季度战果任务'), findsOneWidget);
expect(tester.takeException(), isNull);
```

- [ ] **步骤 2：确认红灯**

运行 `flutter test test/senka_page_test.dart`，预期旧单页结构无法满足新断言。

- [ ] **步骤 3：实现共享 UI 与三页**

拆分 `senka_ui.dart`、`senka_info_view.dart`、`senka_calendar_view.dart`、`senka_calculator_view.dart`。页签使用等宽按钮；宽横屏使用 Row，竖屏/方形使用滚动 Column。完成态使用覆盖整个胶囊的居中横线 `Positioned(left: 0, right: 0, top: ...)`。

- [ ] **步骤 4：确认五档绿灯并提交**

运行 `flutter test test/senka_page_test.dart`，预期所有尺寸通过且无 overflow；提交 `feat(战果): 完成三页响应式战果中心`。

### 任务 5：回归、审查和 Debug 交付

- [ ] **步骤 1：静态检查与格式化**

运行 `dart format lib/src/senka test/senka_*_test.dart`、`flutter analyze`，修复所有本次引入问题。

- [ ] **步骤 2：完整测试**

运行 `flutter test`。既存主分支缺失的计时器文件只作为本地基线依赖，不纳入战果提交；预期测试 0 失败。

- [ ] **步骤 3：Debug 构建**

只运行 `flutter build apk --debug`，预期生成 `build/app/outputs/flutter-apk/app-debug.apk`；禁止运行 release、appbundle、签名或发布脚本。

- [ ] **步骤 4：代码审查与最终提交**

对规格逐条审查数据迁移、三态加算、五档布局和构建范围；运行 `git diff --check`，提交剩余原子改动。把战果提交安全集成回开发主工作区后再次运行 Debug 验证，保留用户所有未提交文件。
