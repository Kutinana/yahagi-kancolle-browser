# 后台通知可靠性修复实施计划

> **执行要求：** 使用 `executing-plans` 按任务逐项实施；每个行为修复严格遵循红灯测试、最小实现、绿灯回归。

**目标：** 修复远征、建造、入渠、疲劳和泊地修理在高速完成、正常到期、提前提醒、状态刷新及进程恢复场景下的通知丢失、重复、计时漂移和常驻行隐藏问题。

**架构：** Flutter 侧负责从权威游戏状态生成带稳定任务身份的通知快照，并持久化业务计时锚点；Android 侧负责通知调度、投递账本、任务生命周期和常驻通知投影。普通完成通知只有在成功发布后才被消费，完成任务只有在游戏状态明确确认已处理后才退出常驻概览。

**技术栈：** Flutter/Dart、Android Kotlin、MethodChannel、AlarmManager、RemoteViews、SharedPreferences、flutter_test、JUnit/Robolectric、Gradle。

---

## 任务 1：统一提前提醒、定时完成和即时完成的通知身份

**文件：**

- 修改：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/notification/NotificationSnapshot.kt`
- 修改：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/notification/AppNotificationManager.kt`
- 修改：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/notification/NotificationAlarmReceiver.kt`
- 测试：`android/app/src/test/kotlin/app/yahagi/kancollebrowser/notification/NotificationSnapshotTest.kt`

### 1.1 先写失败测试

增加以下断言：

- 同一个 `taskId + deadline` 的提前提醒、定时完成和即时完成得到同一个普通通知 ID。
- 即时完成覆盖提前提醒，不产生第二个随机通知 ID。
- 不同任务或新一轮截止时间不会互相覆盖。

### 1.2 运行 Android 专项测试并确认红灯

运行：

```powershell
./gradlew :app:testDebugUnitTest --tests "app.yahagi.kancollebrowser.notification.NotificationSnapshotTest"
```

预期：现有即时完成通知仍以事件 key/发生时间生成 ID，至少一项新增断言失败。

### 1.3 最小实现

- 新增一个纯函数，根据任务稳定 ID 与本轮截止时间计算普通通知 ID。
- 闹钟调度、广播接收和即时提醒全部调用同一函数。
- 兼容旧快照中缺少新字段的情况，避免升级后崩溃。

### 1.4 运行专项测试并确认绿灯

重复 1.2 的命令，确认新增和既有测试全部通过。

### 1.5 提交

```powershell
git add android/app/src/main/kotlin/app/yahagi/kancollebrowser/notification/NotificationSnapshot.kt android/app/src/main/kotlin/app/yahagi/kancollebrowser/notification/AppNotificationManager.kt android/app/src/main/kotlin/app/yahagi/kancollebrowser/notification/NotificationAlarmReceiver.kt android/app/src/test/kotlin/app/yahagi/kancollebrowser/notification/NotificationSnapshotTest.kt
git commit -m "fix(通知): 统一任务提醒通知身份"
```

## 任务 2：完成提醒投递账本与状态先移除竞态

**文件：**

- 修改：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/notification/NotificationSnapshot.kt`
- 修改：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/notification/AppNotificationManager.kt`
- 修改：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/notification/NotificationAlarmReceiver.kt`
- 修改：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/notification/NotificationProgressService.kt`
- 测试：`android/app/src/test/kotlin/app/yahagi/kancollebrowser/notification/NotificationSnapshotTest.kt`

### 2.1 先把旧的错误预期改成失败测试

- 将“任务到期后从快照消失就取消完成闹钟”的测试改为：未确认成功投递前仍保留并立即投递。
- 增加“成功后消费、失败后保留并重试、超过 24 小时停止重试”的测试。
- 增加“单个提醒失败不会阻塞其他任务”的测试。

### 2.2 运行专项测试并确认红灯

使用任务 1 的 Android 专项测试命令。

### 2.3 最小实现

- 在持久化快照中加入待投递、已投递、失败次数和最近失败时间。
- 快照协调时保留已到期但未确认投递的完成事件，即使新的游戏状态已移除任务。
- `notify()` 成功后再标记已投递；异常时保留待投递状态。
- 使用 1 秒、3 秒、10 秒有限退避；24 小时后丢弃并写诊断日志。
- 确保前台服务或下一次快照能重新驱动待投递项目。

### 2.4 运行专项测试并确认绿灯

重复 Android 专项测试，确认所有投递账本场景通过。

### 2.5 提交

```powershell
git add android/app/src/main/kotlin/app/yahagi/kancollebrowser/notification/NotificationSnapshot.kt android/app/src/main/kotlin/app/yahagi/kancollebrowser/notification/AppNotificationManager.kt android/app/src/main/kotlin/app/yahagi/kancollebrowser/notification/NotificationAlarmReceiver.kt android/app/src/main/kotlin/app/yahagi/kancollebrowser/notification/NotificationProgressService.kt android/app/src/test/kotlin/app/yahagi/kancollebrowser/notification/NotificationSnapshotTest.kt
git commit -m "fix(通知): 防止完成提醒因状态刷新丢失"
```

## 任务 3：Flutter 任务生命周期与高速完成墓碑

**文件：**

- 修改：`lib/src/notification/notification_models.dart`
- 修改：`lib/src/notification/game_notification_coordinator.dart`
- 测试：`test/notification/game_notification_coordinator_test.dart`
- 测试：`test/notification/notification_snapshot_test.dart`

### 3.1 先写失败测试

覆盖：

- 高速建造立即产生高优先级完成提醒，同时常驻行保持 100%/“已完成”。
- 快速修理立即提醒，同时保留本地已完成墓碑，不直接删除常驻行。
- 远征、正常建造、入渠和疲劳在截止时间到达后状态变为 `completed`。
- 后续权威状态确认已处理后才删除墓碑；无关 API 更新不能提前确认。
- 已到期任务即使从最新游戏快照消失，仍生成一次完成事件交给原生层。

### 3.2 运行 Flutter 专项测试并确认红灯

```powershell
flutter test test/notification/game_notification_coordinator_test.dart test/notification/notification_snapshot_test.dart
```

预期：快速修理现有“立即移除常驻行”行为和到期状态移除竞态导致新增断言失败。

### 3.3 最小实现

- 为协调器增加明确的 `running/completed/acknowledged` 生命周期记录。
- 高速完成创建稳定任务墓碑并复用原任务截止时间/轮次身份。
- 按设计文档实现远征、建造、入渠、疲劳、泊地修理的权威确认条件。
- 删除基于 `deadline <= now` 就跳过即时完成的错误分支。

### 3.4 运行专项测试并确认绿灯

重复 3.2 的命令。

### 3.5 提交

```powershell
git add lib/src/notification/notification_models.dart lib/src/notification/game_notification_coordinator.dart test/notification/game_notification_coordinator_test.dart test/notification/notification_snapshot_test.dart
git commit -m "fix(通知): 保留完成任务直到游戏确认"
```

## 任务 4：持久化明石、野崎和普通疲劳计时锚点

**文件：**

- 新建：`lib/src/notification/notification_timer_anchor_store.dart`
- 修改：`lib/src/notification/game_notification_coordinator.dart`
- 修改：`lib/src/fleet/timer_mechanics_service.dart`
- 修改：`lib/src/fleet/global_game_timer.dart`
- 测试：`test/notification/notification_timer_anchor_store_test.dart`
- 测试：`test/notification/game_notification_coordinator_test.dart`
- 测试：`test/timer_mechanics_service_test.dart`

### 4.1 先写失败测试

- 明石计时锚点保存并在协调器重建后恢复。
- 野崎计时锚点保存并恢复，而不是从零重新开始。
- 任务签名不匹配时拒绝使用旧锚点。
- 普通疲劳目标只随舰船士气或舰队组成变化重算。
- 仅 `GameState.updatedAt` 变化时，目标时间保持不变。

### 4.2 运行专项测试并确认红灯

```powershell
flutter test test/notification/notification_timer_anchor_store_test.dart test/notification/game_notification_coordinator_test.dart test/timer_mechanics_service_test.dart
```

### 4.3 最小实现

- 建立版本化 JSON 锚点存储接口和默认持久化实现。
- 保存业务签名、观测时间、观测士气和目标时间，不再用全局 `updatedAt` 代替。
- 协调器启动时恢复匹配锚点；签名变化时清理并等待权威状态重建。
- 明石/野崎继续复用游戏内计时器的同一计时语义。

### 4.4 运行专项测试并确认绿灯

重复 4.2 的命令。

### 4.5 提交

```powershell
git add lib/src/notification/notification_timer_anchor_store.dart lib/src/notification/game_notification_coordinator.dart lib/src/fleet/timer_mechanics_service.dart lib/src/fleet/global_game_timer.dart test/notification/notification_timer_anchor_store_test.dart test/notification/game_notification_coordinator_test.dart test/timer_mechanics_service_test.dart
git commit -m "fix(通知): 持久化后台计时锚点"
```

## 任务 5：串行应用快照并有限重试

**文件：**

- 修改：`lib/src/notification/game_notification_coordinator.dart`
- 修改：`lib/src/notification/notification_port.dart`
- 测试：`test/notification/game_notification_coordinator_test.dart`

### 5.1 先写失败测试

- 两次快速状态更新时，旧快照不会晚于新快照写入原生层。
- 首次调用失败后按 1 秒、3 秒、10 秒重试。
- 重试等待期间出现新快照时，未执行的旧快照被新快照替换。
- 重试耗尽会报告错误，但协调器之后仍能处理新状态。

### 5.2 运行专项测试并确认红灯

```powershell
flutter test test/notification/game_notification_coordinator_test.dart
```

### 5.3 最小实现

- 将未等待的 MethodChannel 调用改为单消费者队列。
- 队列只保留最新待发送快照，并用可注入延时器实现有限退避。
- 仅在原生确认成功后消费 Flutter 侧即时提醒集合。
- `dispose` 时安全取消计时器和后续发送。

### 5.4 运行专项测试并确认绿灯

重复 5.2 的命令。

### 5.5 提交

```powershell
git add lib/src/notification/game_notification_coordinator.dart lib/src/notification/notification_port.dart test/notification/game_notification_coordinator_test.dart
git commit -m "fix(通知): 串行同步快照并重试失败调用"
```

## 任务 6：常驻通知排序与溢出汇总

**文件：**

- 修改：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/notification/NotificationProgressProjection.kt`
- 修改：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/notification/AppNotificationManager.kt`
- 测试：`android/app/src/test/kotlin/app/yahagi/kancollebrowser/notification/NotificationProgressProjectionTest.kt`

### 6.1 先写失败测试

- 超过 5 项时展示前 4 项和 1 条“另有 N 项”。
- 已完成项排在进行中项之前。
- 同状态按截止时间、稳定任务 ID 排序。
- 汇总行携带被隐藏项目中最近的截止时间且不会出现负倒计时。

### 6.2 运行专项测试并确认红灯

```powershell
./gradlew :app:testDebugUnitTest --tests "app.yahagi.kancollebrowser.notification.NotificationProgressProjectionTest"
```

### 6.3 最小实现

- 将排序、截断和汇总生成放入纯投影函数。
- RemoteViews 只负责绑定最多 5 个投影行。
- 汇总文案使用 Android 资源并支持数量替换。

### 6.4 运行专项测试并确认绿灯

重复 6.2 的命令。

### 6.5 提交

```powershell
git add android/app/src/main/kotlin/app/yahagi/kancollebrowser/notification/NotificationProgressProjection.kt android/app/src/main/kotlin/app/yahagi/kancollebrowser/notification/AppNotificationManager.kt android/app/src/main/res/values/strings.xml android/app/src/test/kotlin/app/yahagi/kancollebrowser/notification/NotificationProgressProjectionTest.kt
git commit -m "fix(通知): 汇总常驻列表溢出任务"
```

## 任务 7：修正文案并执行完整回归

**文件：**

- 修改：`lib/src/notification/game_notification_coordinator.dart`
- 修改：相关本地化资源（仅在现有架构要求时）
- 测试：`test/notification/game_notification_coordinator_test.dart`

### 7.1 先写失败测试

断言泊地修理全部完成的标题和正文为设计文档中的中文文案，且舰队名正确插值。

### 7.2 运行测试并确认红灯

```powershell
flutter test test/notification/game_notification_coordinator_test.dart
```

### 7.3 最小实现并运行专项绿灯

替换英文硬编码并复跑专项测试。

### 7.4 执行完整验证

```powershell
flutter test
./gradlew :app:testDebugUnitTest
flutter analyze
./gradlew :app:assembleDebug
git diff --check
adb devices -l
```

验收标准：

- Flutter 和 Android 测试全部通过。
- Debug APK 构建成功。
- `git diff --check` 无新增格式错误。
- 静态检查无本次修改引入的新问题；仓库既有告警单独列出。
- 如无连接设备，明确记录三星 One UI 的横幅、暗色文字、振动和清后台场景尚需真机验收。

### 7.5 最终提交

仅暂存本计划涉及的通知文件和测试，检查 `git diff --cached --stat` 后提交：

```powershell
git commit -m "fix(通知): 完善后台提醒可靠性"
```

