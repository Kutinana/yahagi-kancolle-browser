# 舰队疲劳恢复倒计时实现计划

> **For Codex:** 使用 executing-plans 技能逐项执行；每项先写失败测试，再实现并提交。

**目标：** 让首页编队简报与舰队中心的「最低疲劳」可点击切换为恢复至 Cond 49 的倒计时，两个入口共享且持久化显示偏好，并与系统通知共用同一目标时间。

**架构：** 新增 `MoraleRecoveryTimerController`，从通知协调器中接管各舰队自然疲劳锚点的计算与查询。通知协调器仍统一持久化现有 `NotificationTimerAnchors`，但通过共享控制器读写 `moraleByFleet`，通知开关只影响发布、不再清空锚点。布局控制器增加全局显示模式，并把模式、切换回调和控制器传给两个舰队界面。

**技术栈：** Flutter/Dart、ChangeNotifier、SharedPreferences、flutter_test。

---

## 任务一：实现共享疲劳恢复计时控制器

**文件：**

- 新建：`lib/src/fleet/morale_recovery_timer_controller.dart`
- 新建：`test/morale_recovery_timer_controller_test.dart`
- 修改：`lib/src/notification/notification_timer_anchor_store.dart`

1. 先写测试：Cond 40 生成 9 分钟目标；相同舰队签名与 Cond 的刷新不推迟目标；Cond 或编成改变时重建；Cond 49、空舰队、舰船数据缺失时清除；合法持久化锚点可恢复，签名不符会替换。
2. 运行 `flutter test test/morale_recovery_timer_controller_test.dart`，确认因控制器不存在而失败。
3. 实现控制器：监听 `GameStateController`，维护 `Map<int, MoraleNotificationTimerAnchor>`；使用 `state.updatedAt` 和 `ceil((49-minCond)/3) * 3 minutes`；暴露 `targetForFleet(int)`、`replaceAnchors(...)` 和锚点变化回调。
4. 再运行测试，确认通过。
5. 提交：`feat(舰队): 添加疲劳恢复计时控制器`

## 任务二：让通知模块消费共享计时状态

**文件：**

- 修改：`lib/src/notification/game_notification_coordinator.dart`
- 修改：`test/notification/game_notification_coordinator_test.dart`

1. 增加回归测试：关闭通知时仍保留疲劳目标；重新启用通知不重置目标；预提醒、完成提醒、常驻通知读取同一目标。
2. 运行相关测试并确认新用例失败。
3. 在协调器中创建并公开 `moraleRecoveryTimerController`，启动/销毁时管理监听；将原 `_normalMoraleTarget` 与 `_reconcileMoraleTimerAnchors` 迁移到共享控制器；通过既有 `_replaceTimerAnchors` 回调持久化变化。
4. 运行 `flutter test test/notification/game_notification_coordinator_test.dart test/morale_recovery_timer_controller_test.dart`。
5. 提交：`refactor(通知): 共享疲劳恢复计时状态`

## 任务三：持久化疲劳指标显示偏好

**文件：**

- 修改：`lib/src/settings/layout_settings_store.dart`
- 修改：`lib/src/settings/layout_settings_controller.dart`
- 修改：`test/layout_settings_controller_test.dart`
- 修改：`test/layout_settings_store_test.dart`

1. 写失败测试：默认 `minimumCondition`；切换为 `recoveryCountdown` 后同步通知监听者并保存；重新加载恢复上次模式。
2. 定义 `FleetMoraleMetricMode` 与可选的 `FleetMoraleMetricSettingsStore` 接口；SharedPreferences 使用独立键保存枚举字符串。
3. 在布局控制器加载、暴露并切换模式；不支持新接口的测试假存储保持默认值。
4. 运行 `flutter test test/layout_settings_controller_test.dart test/layout_settings_store_test.dart`。
5. 提交：`feat(设置): 记住疲劳指标显示模式`

## 任务四：接入首页与舰队中心

**文件：**

- 新建：`lib/src/fleet/morale_recovery_display.dart`
- 修改：`lib/src/fleet/fleet_summary_card.dart`
- 修改：`lib/src/fleet/fleet_information_center.dart`
- 修改：`lib/src/app.dart`
- 修改：`lib/l10n/app_zh.arb`
- 修改：`lib/l10n/app_zh_Hant.arb`
- 修改：`lib/l10n/app_ja.arb`
- 修改生成的本地化 Dart 文件
- 修改：`test/fleet_summary_card_test.dart`
- 修改：`test/fleet_information_center_test.dart`

1. 写组件失败测试：两处均能点击切换；倒计时格式为 `MM:SS`/`H:MM:SS`；归零显示「已恢复」；空舰队或数据不完整显示 `—`；最低疲劳模式保持原值。
2. 新建纯展示格式函数，避免两处出现不同的倒计时规则。
3. 给两个组件增加可选参数（默认保持旧行为），将指标格包装为完整可点击语义区域，并由 `SecondTickBuilder` 的 `now` 刷新数值。
4. 在 `app.dart` 将布局模式、切换回调与通知协调器公开的共享控制器传给首页及舰队中心；两个入口读取同一布局控制器状态。
5. 增加简中、繁中、日文本地化并运行 `flutter gen-l10n`。
6. 运行 `flutter test test/fleet_summary_card_test.dart test/fleet_information_center_test.dart`。
7. 提交：`feat(舰队): 支持点击查看疲劳恢复倒计时`

## 任务五：回归验证与收尾

**文件：**

- 如验证暴露问题，仅修改对应实现或测试文件

1. 运行 `dart format lib test`（仅格式化本次涉及文件更优）。
2. 运行 `flutter analyze`。
3. 运行疲劳、通知、布局相关定向测试。
4. 运行 `flutter test` 全量测试。
5. 检查 `git diff --check` 与 `git status --short`，确认没有测试缓存或无关文件进入提交。
6. 如需修复验证问题，先补回归测试并提交：`fix(舰队): 修正疲劳倒计时回归问题`。
7. 使用 finishing-a-development-branch 技能向用户交付分支状态与集成选项。
