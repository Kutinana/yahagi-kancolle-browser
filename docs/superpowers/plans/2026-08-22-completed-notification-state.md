# 通知完成状态与明石正向计时实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 让远征、建造、入渠和疲劳任务到时后保留 100% 的“已完成”常驻状态并发送普通完成通知，同时让明石通知与游戏内计时器共用锚点进行正向计时。

**架构：** Flutter 生成带生命周期和计时模式的完整快照；Android 持久化快照，并在闹钟触发时独立完成 `running → completed/settlementReady` 状态转换。下一次权威游戏状态会删除已处理任务。Android `RemoteViews` 根据 `countdown` 或 `elapsed` 模式绑定系统 Chronometer，完成推送走独立高重要性渠道。

**技术栈：** Flutter/Dart、Kotlin、Android AlarmManager、NotificationManager、RemoteViews、SharedPreferences、JUnit、flutter_test。

---

## 文件结构

- 修改 `lib/src/notification/notification_models.dart`：定义常驻任务状态、计时模式及快照序列化字段。
- 修改 `test/notification/notification_snapshot_test.dart`：锁定 Flutter → Android 快照协议。
- 修改 `lib/src/notification/game_notification_coordinator.dart`：为四类普通任务生成完成状态，为明石生成正向计时状态。
- 修改 `test/notification/game_notification_coordinator_test.dart`：覆盖到时保留、权威状态清除、明石正向计时。
- 修改 `android/app/src/main/kotlin/app/yahagi/kancollebrowser/notification/NotificationSnapshot.kt`：解析、持久化并纯函数转换完成状态。
- 修改 `android/app/src/test/kotlin/app/yahagi/kancollebrowser/notification/NotificationSnapshotTest.kt`：覆盖协议往返、完成转换和幂等性。
- 修改 `android/app/src/main/kotlin/app/yahagi/kancollebrowser/notification/AppNotificationManager.kt`：显示完成/阶段状态，绑定正向 Chronometer，检查提醒渠道。
- 修改 `android/app/src/main/kotlin/app/yahagi/kancollebrowser/notification/NotificationAlarmReceiver.kt`：可靠发布普通提醒后推进持久化状态。
- 修改 `android/app/src/main/kotlin/app/yahagi/kancollebrowser/MainActivity.kt`：返回准确的普通提醒渠道能力。
- 可能修改 `lib/src/settings/notification_settings_page.dart` 与对应测试：保持渠道状态文案准确。

### 任务 1：扩展跨平台快照契约

**文件：**
- 修改：`lib/src/notification/notification_models.dart`
- 测试：`test/notification/notification_snapshot_test.dart`

- [ ] **步骤 1：编写失败的 Flutter 协议测试**

在现有快照测试中为常驻项目增加断言：

```dart
const OngoingTaskItem(
  id: 'expedition:2',
  type: GameNotificationType.expedition,
  title: 'Fleet 2 · Mission 5',
  state: OngoingTaskState.completed,
  clockMode: OngoingClockMode.countdown,
  progress: 1,
  remainingSeconds: 0,
  targetEpochMs: 1700000600000,
)
```

期望映射包含：

```dart
'state': 'completed',
'clockMode': 'countdown',
'anchorEpochMs': null,
```

- [ ] **步骤 2：验证测试因字段不存在而失败**

运行：

```powershell
flutter test test/notification/notification_snapshot_test.dart -r expanded
```

预期：FAIL，指出 `state`、`clockMode` 或 `anchorEpochMs` 未定义。

- [ ] **步骤 3：实现最小 Dart 模型**

新增：

```dart
enum OngoingTaskState { running, settlementReady, completed }
enum OngoingClockMode { countdown, elapsed }
```

`OngoingTaskItem` 增加：

```dart
this.state = OngoingTaskState.running,
this.clockMode = OngoingClockMode.countdown,
this.anchorEpochMs,
```

并在 `toMap()` 中写入三个字段。保留现有字段，避免一次性重构协议。

- [ ] **步骤 4：运行协议测试确认通过**

运行：

```powershell
flutter test test/notification/notification_snapshot_test.dart -r compact
```

预期：全部通过。

- [ ] **步骤 5：提交**

```powershell
git add lib/src/notification/notification_models.dart test/notification/notification_snapshot_test.dart
git commit -m "feat(通知): 扩展常驻任务状态协议"
```

### 任务 2：实现 Android 完成状态转换

**文件：**
- 修改：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/notification/NotificationSnapshot.kt`
- 测试：`android/app/src/test/kotlin/app/yahagi/kancollebrowser/notification/NotificationSnapshotTest.kt`

- [ ] **步骤 1：编写失败的原生状态转换测试**

测试三种行为：

```kotlin
@Test
fun `complete alarm marks matching ongoing item completed and is idempotent`() {
    val first = NotificationSnapshotTransitions.onAlarmFired(
        snapshotWithRunningItem(),
        key = "expedition_2_complete",
        taskId = "expedition:2",
        stage = "complete",
    )
    val second = NotificationSnapshotTransitions.onAlarmFired(
        first,
        key = "expedition_2_complete",
        taskId = "expedition:2",
        stage = "complete",
    )
    assertEquals("completed", first.ongoingItems.single().state)
    assertEquals(1.0, first.ongoingItems.single().progress, 0.0)
    assertEquals(0, first.ongoingItems.single().remainingSeconds)
    assertEquals(first, second)
}
```

另加 `milestone` 将明石项目改为 `settlementReady`，`preempt` 保持 `running` 的测试。

- [ ] **步骤 2：运行测试确认正确失败**

运行：

```powershell
cd android
.\gradlew.bat :app:testDebugUnitTest --tests "app.yahagi.kancollebrowser.notification.NotificationSnapshotTest"
```

预期：FAIL，`NotificationSnapshotTransitions` 或状态字段不存在。

- [ ] **步骤 3：实现 Kotlin 模型、兼容解析和纯转换函数**

`OngoingNotificationItem` 增加 `state`、`clockMode`、`anchorEpochMs`。旧持久化快照缺少字段时默认使用 `running`、`countdown`、`null`：

```kotlin
state = item.optionalString("state") ?: "running"
clockMode = item.optionalString("clockMode") ?: "countdown"
anchorEpochMs = item.optionalNumber("anchorEpochMs")?.toLong()
```

新增纯函数：

```kotlin
object NotificationSnapshotTransitions {
    fun onAlarmFired(
        previous: NativeNotificationSnapshot,
        key: String,
        taskId: String,
        stage: String,
    ): NativeNotificationSnapshot {
        val nextState = when (stage) {
            "complete" -> "completed"
            "milestone" -> "settlementReady"
            else -> null
        }
        return previous.copy(
            alarms = previous.alarms.filterNot { it.key == key },
            ongoingItems = previous.ongoingItems.map { item ->
                if (item.id != taskId || nextState == null) item else item.copy(
                    state = nextState,
                    progress = if (nextState == "completed") 1.0 else item.progress,
                    remainingSeconds = if (nextState == "completed") 0 else item.remainingSeconds,
                )
            },
        )
    }
}
```

- [ ] **步骤 4：增加 JSON 往返测试并运行**

断言 `NotificationSnapshotCodec.fromJson(NotificationSnapshotCodec.toJson(snapshot)) == snapshot`，并重新运行任务 2 的 Gradle 命令。

预期：全部通过。

- [ ] **步骤 5：提交**

```powershell
git add android/app/src/main/kotlin/app/yahagi/kancollebrowser/notification/NotificationSnapshot.kt android/app/src/test/kotlin/app/yahagi/kancollebrowser/notification/NotificationSnapshotTest.kt
git commit -m "feat(通知): 原生层保留任务完成状态"
```

### 任务 3：让四类任务在 Flutter 快照中保留已完成状态

**文件：**
- 修改：`lib/src/notification/game_notification_coordinator.dart`
- 测试：`test/notification/game_notification_coordinator_test.dart`

- [ ] **步骤 1：为四类任务编写失败测试**

分别构造仍处于权威活动状态、但截止时间早于 `testNow` 的远征、建造、入渠和疲劳数据，断言：

```dart
final item = fakePort.latestSnapshot!.ongoingItems.singleWhere(
  (item) => item.id == 'expedition:2',
);
expect(item.state, OngoingTaskState.completed);
expect(item.progress, 1);
expect(item.remainingSeconds, 0);
expect(
  fakePort.latestSnapshot!.alarms.where((alarm) => alarm.taskId == item.id),
  isEmpty,
);
```

保留并扩展高速建造测试：状态切换为完成时立即发送普通完成通知，同时将 `construction:<dockId>` 保留为 100% 的“已完成”常驻行；舰娘被领取或船坞开始下一次建造后再移除或替换。高速修复立即发送普通完成通知，但由于入渠任务已由游戏确认处理，不保留旧常驻行。重复状态刷新与首次加载缓存状态均不得补发通知。

- [ ] **步骤 2：运行测试确认现有代码会直接删除过期项目**

运行：

```powershell
flutter test test/notification/game_notification_coordinator_test.dart -r expanded
```

预期：FAIL，找不到过期任务对应的常驻项目。

- [ ] **步骤 3：提取统一的截止任务构造逻辑**

新增私有辅助方法，避免四类任务各自实现不同的边界：

```dart
OngoingTaskItem _deadlineItem({
  required String id,
  required GameNotificationType type,
  required String title,
  required DateTime deadline,
  required int totalSeconds,
  required DateTime now,
}) {
  final completed = !deadline.isAfter(now);
  final remaining = completed ? 0 : deadline.difference(now).inSeconds;
  return OngoingTaskItem(
    id: id,
    type: type,
    title: title,
    state: completed ? OngoingTaskState.completed : OngoingTaskState.running,
    progress: completed
        ? 1
        : (1 - remaining / totalSeconds).clamp(0.0, 1.0),
    remainingSeconds: remaining,
    targetEpochMs: deadline.millisecondsSinceEpoch,
    totalDurationSec: totalSeconds,
  );
}
```

只要权威状态仍表明任务存在，就调用该方法；只有未来截止时间才生成 Alarm。

- [ ] **步骤 4：修正疲劳锚点和新任务覆盖**

自然疲劳继续使用 `state.updatedAt` 锚定。野崎刷闪使用 `_nosakiStartedAt()` 产生稳定截止时间，避免每次快照将截止时间向后滑动。同一任务 ID 的新截止时间应生成 `running`，自然覆盖旧 `completed`。

- [ ] **步骤 5：运行协调器与协议测试**

```powershell
flutter test test/notification test/notification_settings_capabilities_test.dart -r compact
```

预期：全部通过。

- [ ] **步骤 6：提交**

```powershell
git add lib/src/notification/game_notification_coordinator.dart test/notification/game_notification_coordinator_test.dart
git commit -m "fix(通知): 到时后保留任务完成状态"
```

### 任务 4：实现明石同源正向计时

**文件：**
- 修改：`lib/src/notification/game_notification_coordinator.dart`
- 修改：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/notification/AppNotificationManager.kt`
- 测试：`test/notification/game_notification_coordinator_test.dart`
- 测试：`android/app/src/test/kotlin/app/yahagi/kancollebrowser/notification/NotificationSnapshotTest.kt`

- [ ] **步骤 1：编写明石失败测试**

以 `ancStarted = testNow - 18 minutes` 构造快照，断言：

```dart
expect(item.clockMode, OngoingClockMode.elapsed);
expect(item.anchorEpochMs, ancStarted.millisecondsSinceEpoch);
expect(item.state, OngoingTaskState.running);
```

以 `testNow - 21 minutes` 断言 `state == settlementReady`；预计全部修复截止后断言 `state == completed`。

- [ ] **步骤 2：验证测试失败**

```powershell
flutter test test/notification/game_notification_coordinator_test.dart -r expanded
```

预期：FAIL，当前项目仍使用倒计时且到 20 分钟后消失。

- [ ] **步骤 3：让协调器复用 `_anchorageStartFor(state)`**

明石项目固定写入：

```dart
clockMode: OngoingClockMode.elapsed,
anchorEpochMs: ancStart.millisecondsSinceEpoch,
remainingSeconds: 0,
```

20 分钟后使用 `settlementReady`；仅“预计全部修复”截止后使用 `completed`。进度按所选目标计算并限制在 `0..1`，正向显示始终基于 `ancStart`。

- [ ] **步骤 4：为原生 Chronometer 绑定提取纯计算并测试**

新增可测试的时间模式判断或基准计算函数：

```kotlin
fun elapsedRealtimeBase(nowEpochMs: Long, elapsedRealtimeMs: Long, anchorEpochMs: Long): Long =
    elapsedRealtimeMs - (nowEpochMs - anchorEpochMs).coerceAtLeast(0L)
```

`bindItem` 在 `elapsed` 模式调用：

```kotlin
views.setChronometer(statsId, base, "已修理 %s", true)
views.setChronometerCountDown(statsId, false)
```

`settlementReady` 和 `completed` 在标题/统计文本中追加对应状态，但不创建新计时锚点。

- [ ] **步骤 5：运行 Dart 和 Kotlin 专项测试**

```powershell
flutter test test/notification/game_notification_coordinator_test.dart -r compact
cd android
.\gradlew.bat :app:testDebugUnitTest --tests "app.yahagi.kancollebrowser.notification.NotificationSnapshotTest"
```

预期：全部通过。

- [ ] **步骤 6：提交**

```powershell
git add lib/src/notification/game_notification_coordinator.dart test/notification/game_notification_coordinator_test.dart android/app/src/main/kotlin/app/yahagi/kancollebrowser/notification/AppNotificationManager.kt android/app/src/test/kotlin/app/yahagi/kancollebrowser/notification/NotificationSnapshotTest.kt
git commit -m "feat(通知): 明石通知改用同源正向计时"
```

### 任务 5：可靠发布普通完成通知并准确诊断渠道

**文件：**
- 修改：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/notification/NotificationAlarmReceiver.kt`
- 修改：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/notification/AppNotificationManager.kt`
- 修改：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/MainActivity.kt`
- 视结果修改：`lib/src/settings/notification_settings_page.dart`
- 测试：`android/app/src/test/kotlin/app/yahagi/kancollebrowser/notification/NotificationSnapshotTest.kt`
- 测试：`test/notification_settings_capabilities_test.dart`

- [ ] **步骤 1：增加提醒渠道能力与完成转换边界测试**

将渠道能力定义为“应用通知权限开启，并且当前会使用的普通提醒渠道至少存在且未被禁用”；常驻低优先级渠道不能单独代表提醒可用。Widget 测试继续断言关闭时展示进入系统设置的入口。

- [ ] **步骤 2：修改接收器的处理顺序**

接收器必须：

```kotlin
AppNotificationManager.initChannels(context)
AppNotificationManager.postAlarmNotification(context, intent)
AppNotificationManager.onAlarmFired(context, key, taskId, stage)
```

普通通知增加：

```kotlin
.setCategory(NotificationCompat.CATEGORY_REMINDER)
.setPriority(NotificationCompat.PRIORITY_HIGH)
.setAutoCancel(true)
.setOnlyAlertOnce(true)
```

通知 ID 继续按 alarm key 稳定生成，与 `ONGOING_NOTIFICATION_ID` 分离。不要在状态转换时取消该普通通知。

- [ ] **步骤 3：替换旧的删除语义**

将 `removeTaskOnFire` 从接收器状态推进逻辑中移除，传递 `stage`。协议字段可以暂时保留一版以兼容旧快照，但不再决定常驻项目删除。

- [ ] **步骤 4：运行通知设置和 Android 测试**

```powershell
flutter test test/notification_settings_capabilities_test.dart test/notification -r compact
cd android
.\gradlew.bat :app:testDebugUnitTest
```

预期：全部通过。

- [ ] **步骤 5：提交**

```powershell
git add android/app/src/main/kotlin/app/yahagi/kancollebrowser/notification/NotificationAlarmReceiver.kt android/app/src/main/kotlin/app/yahagi/kancollebrowser/notification/AppNotificationManager.kt android/app/src/main/kotlin/app/yahagi/kancollebrowser/MainActivity.kt lib/src/settings/notification_settings_page.dart test/notification_settings_capabilities_test.dart
git commit -m "fix(通知): 可靠发布普通完成提醒"
```

### 任务 6：全量验证与真机检查清单

**文件：**
- 修改：仅修复本计划引入的测试或静态分析问题

- [ ] **步骤 1：格式与静态分析**

```powershell
dart format lib/src/notification test/notification test/notification_settings_capabilities_test.dart
flutter analyze lib/src/notification lib/src/settings/notification_settings_page.dart test/notification test/notification_settings_capabilities_test.dart
git diff --check
```

预期：无问题。

- [ ] **步骤 2：完整 Flutter 测试**

```powershell
flutter test -r compact
```

预期：全部通过，允许仓库明确标记的 skip。

- [ ] **步骤 3：Android 单元测试和 Debug APK**

```powershell
cd android
.\gradlew.bat :app:testDebugUnitTest :app:assembleDebug
```

预期：`BUILD SUCCESSFUL`，APK 位于 `build/app/outputs/flutter-apk/app-debug.apk`。

- [ ] **步骤 4：真机验证**

依次使用短时间测试数据确认：

1. 远征、建造、入渠和疲劳任务到时后，常驻项目显示 100% 与“已完成”；
2. 每个任务同时产生可点击、可手动划掉的普通通知；
3. 划掉普通通知后，常驻完成项目仍存在；
4. 进入游戏并收到权威状态后，已处理项目消失；
5. 明石显示正向累计时间，与游戏页面误差不超过系统 Chronometer 的一秒显示边界；
6. 明石 20 分钟后显示“首轮结算就绪”，预计全部修复后显示“等待母港确认”；
7. 从最近任务划掉应用后重复上述到时场景。

- [ ] **步骤 5：提交验证阶段必要修正**

如有本计划引入的修正：

```powershell
git add <本计划实际修改的文件>
git commit -m "fix(通知): 补齐完成状态验证边界"
```

如果没有代码变化，不创建空提交。
