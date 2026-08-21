# 可靠后台通知实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在不实现设备重启恢复的前提下，用持久化完整快照替换易丢失的进程内通知状态，并修复游戏状态撤销、权限、声音振动、士气与泊地通知错误。

**架构：** Dart 协调器生成完整 `NotificationSnapshot`，Android 原生层持久化后做 Alarm diff，并直接发布带系统 Chronometer 的常驻通知。删除通知前台 Service；应用进程回收后由系统持有通知和 Alarm，AlarmReceiver 可从持久化快照移除已完成任务。

**技术栈：** Flutter/Dart、MethodChannel、Kotlin、AlarmManager、NotificationManager、SharedPreferences、RemoteViews、JUnit。

---

## 文件职责

- 创建 `lib/src/notification/notification_snapshot.dart`：Dart 完整快照、平台能力和应用结果模型。
- 修改 `lib/src/notification/notification_models.dart`：为 Alarm 增加 task/stage/remove 元数据，为常驻任务提供绝对目标时间。
- 修改 `lib/src/notification/notification_port.dart` 与 `method_channel_notification_port.dart`：以 `applySnapshot` 为主接口并暴露平台能力/权限请求，错误不再静默吞掉。
- 修改 `lib/src/notification/game_notification_coordinator.dart`：生成完整快照、稳定士气目标、泊地资格与完整模式。
- 修改 `lib/src/game_state/game_state_controller.dart`、`lib/main.dart`：显式等待缓存恢复后再启动协调器。
- 修改通知设置 controller/page 与本地化资源：显示通知权限、精确闹钟权限和系统设置入口。
- 创建 `android/.../notification/NotificationSnapshot.kt` 与 `NotificationSnapshotStore.kt`：解析、保存、diff 和触发后变换快照。
- 重写 `AppNotificationManager.kt` 与 `NotificationAlarmReceiver.kt`：直接常驻通知、Alarm diff、权限降级、Channel 变体。
- 删除 `NotificationOngoingService.kt` 及 Manifest service 声明。
- 修改两个通知 layout：将倒计时 TextView 换成 Chronometer。
- 扩充 Dart 与 Kotlin 测试，覆盖全部回归场景。

### 任务 1：Dart 快照契约与 Port

**文件：**
- 创建：`lib/src/notification/notification_snapshot.dart`
- 修改：`lib/src/notification/notification_models.dart`
- 修改：`lib/src/notification/notification_port.dart`
- 修改：`lib/src/notification/method_channel_notification_port.dart`
- 测试：`test/notification/notification_snapshot_test.dart`

- [ ] **步骤 1：编写失败测试**

覆盖快照 `toMap`、Alarm 的 `taskId/stage/removeTaskOnFire`、平台能力解析和原生应用结果解析。

- [ ] **步骤 2：运行测试验证红灯**

运行：`flutter test test/notification/notification_snapshot_test.dart`

预期：因 `NotificationSnapshot` 尚不存在而失败。

- [ ] **步骤 3：实现最小快照模型与 Port**

`NotificationPort` 提供：

```dart
Future<NotificationApplyResult> applySnapshot(NotificationSnapshot snapshot);
Future<NotificationPlatformCapabilities> getCapabilities();
Future<bool> requestNotificationPermission();
Future<void> requestExactAlarmPermission();
Future<void> openSystemNotificationSettings();
```

MethodChannel 异常向上抛出 `NotificationPlatformException`，不使用空 catch。

- [ ] **步骤 4：运行测试验证绿灯**

运行：`flutter test test/notification/notification_snapshot_test.dart`

### 任务 2：协调器完整快照与业务失效规则

**文件：**
- 修改：`lib/src/notification/game_notification_coordinator.dart`
- 修改：`test/notification/game_notification_coordinator_test.dart`

- [ ] **步骤 1：为以下行为编写失败测试**

1. 快速建造、快速修复后完整快照不含对应 task 与 Alarm。
2. 明石换下或没有可修理舰时不生成泊地通知。
3. `twentyMinutes/allRepaired/both` 生成正确 Alarm。
4. 士气 fingerprint 不变时目标时间不随 `now` 后移。
5. 总开关关闭应用空快照。

- [ ] **步骤 2：逐个运行测试确认因旧增量接口或旧逻辑失败**

运行：`flutter test test/notification/game_notification_coordinator_test.dart`

- [ ] **步骤 3：实现完整快照生成**

协调器只调用 `applySnapshot`；快照业务 ID 稳定。士气目标账本按 `fleetId + shipIds + cond` fingerprint 复用目标。泊地使用 `AnchorageRepairCalculator.project` 的可修理行与最大剩余时间判断资格和全部完成时间。

- [ ] **步骤 4：运行协调器测试验证绿灯**

### 任务 3：可靠缓存初始化

**文件：**
- 修改：`lib/src/game_state/game_state_controller.dart`
- 修改：`lib/main.dart`
- 修改：`test/game_state_controller_test.dart`
- 修改：`test/game_state_serializer_test.dart`

- [ ] **步骤 1：编写失败测试**

验证显式 `initialize()` 完成前 state 不宣称 ready，完成后完整恢复 fleet、master mission、repair/construction；已接收 live event 时缓存不能覆盖实时状态。

- [ ] **步骤 2：运行测试验证红灯**

- [ ] **步骤 3：将构造函数中的异步加载改为幂等 `initialize()` 并在 main 中 await**

通知协调器只在初始化完成后启动。通知相关事件仍立即调用原生快照，不依赖 GameStateStore 五秒 debounce。

- [ ] **步骤 4：运行 state/controller/serializer 测试验证绿灯**

### 任务 4：Android 快照持久化与纯逻辑 diff

**文件：**
- 创建：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/notification/NotificationSnapshot.kt`
- 创建：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/notification/NotificationSnapshotStore.kt`
- 创建：`android/app/src/test/kotlin/app/yahagi/kancollebrowser/notification/NotificationSnapshotTest.kt`

- [ ] **步骤 1：编写失败 JUnit 测试**

覆盖 JSON round-trip、旧/新 Alarm key diff、完成阶段移除 task、里程碑不移除 task、损坏 JSON 返回空快照。

- [ ] **步骤 2：运行测试验证红灯**

运行：`cd android; ./gradlew app:testDebugUnitTest --tests '*NotificationSnapshotTest'`

- [ ] **步骤 3：实现纯 Kotlin 模型、codec 与 diff**

Store 使用专用 SharedPreferences key 原子保存 JSON；不包含开机 Receiver。

- [ ] **步骤 4：运行 Kotlin 测试验证绿灯**

### 任务 5：Android Alarm、常驻通知与 Channel

**文件：**
- 修改：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/notification/AppNotificationManager.kt`
- 修改：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/notification/NotificationAlarmReceiver.kt`
- 删除：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/notification/NotificationOngoingService.kt`
- 修改：`android/app/src/main/AndroidManifest.xml`
- 修改：两个 `notification_ongoing_*.xml`
- 测试：`android/app/src/test/kotlin/app/yahagi/kancollebrowser/notification/NotificationChannelPolicyTest.kt`

- [ ] **步骤 1：编写 Channel 变体与触发策略失败测试**

四种声音/振动组合必须映射到稳定 ID；complete 与 milestone 使用不同 task 删除策略。

- [ ] **步骤 2：运行测试验证红灯**

- [ ] **步骤 3：实现 `applySnapshot`**

保存快照、取消缺失 Alarm、调度新增/变化 Alarm、无精确权限时 `setAndAllowWhileIdle` 降级、直接 notify/cancel 常驻通知。Chronometer 基于 `SystemClock.elapsedRealtime() + (targetEpochMs - now)`。

- [ ] **步骤 4：Receiver 触发后更新持久化快照并重建常驻通知**

- [ ] **步骤 5：删除 Service 和 Manifest 声明并运行 Kotlin 测试**

### 任务 6：MethodChannel 权限状态与设置页

**文件：**
- 修改：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/MainActivity.kt`
- 修改：`lib/src/settings/notification_settings_controller.dart`
- 修改：`lib/src/settings/notification_settings_page.dart`
- 修改：`lib/main.dart`
- 修改：`lib/l10n/app_*.arb` 并重新生成本地化文件
- 测试：`test/settings/notification_settings_test.dart`

- [ ] **步骤 1：编写权限状态 controller 失败测试**

验证刷新能力、等待通知权限回调、精确闹钟请求后重新读取状态，以及系统设置入口调用。

- [ ] **步骤 2：运行测试验证红灯**

- [ ] **步骤 3：实现原生 capability 方法和异步通知权限结果**

返回 `notificationsGranted/exactAlarmsGranted/channelsEnabled`。精确闹钟请求打开 `ACTION_REQUEST_SCHEDULE_EXACT_ALARM`；生命周期 resume 时刷新。

- [ ] **步骤 4：设置页展示状态、降级说明和系统设置按钮**

- [ ] **步骤 5：运行本地化生成与设置测试**

### 任务 7：错误诊断和最终验证

**文件：**
- 修改：相关 Dart Port/Coordinator 和 Android manager。

- [ ] **步骤 1：补充 apply 失败回归测试**

确保失败可记录且不造成未处理异步异常；日志只含任务数、版本、路径和错误码。

- [ ] **步骤 2：运行通知相关测试**

```powershell
flutter test test/notification test/settings/notification_settings_test.dart test/game_state_controller_test.dart test/game_state_serializer_test.dart
```

- [ ] **步骤 3：运行完整验证**

```powershell
flutter test
flutter analyze
flutter build apk --debug
Push-Location android; ./gradlew app:testDebugUnitTest; Pop-Location
```

- [ ] **步骤 4：检查 Manifest 与 diff**

确认无 `NotificationOngoingService`、无 `BOOT_COMPLETED`、无新的警告、无无关改动。
