# 通知进度定时刷新实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 每 30 秒刷新常驻通知的真实百分比和进度条，并在目标时间把倒计时安全切换为“已完成”。

**架构：** 用纯 Kotlin 时间投影从持久化快照计算当前显示状态；一个无唤醒锁的轻量前台服务只在动态任务存在时复用现有常驻通知并定时重建。AlarmManager 继续承担完成消息投递。

**技术栈：** Android/Kotlin、Foreground Service、Handler、RemoteViews、JUnit

---

### 任务 1：时间投影与刷新调度

**文件：**
- 创建：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/notification/NotificationProgressProjection.kt`
- 测试：`android/app/src/test/kotlin/app/yahagi/kancollebrowser/notification/NotificationProgressProjectionTest.kt`

- [ ] **步骤 1：编写失败测试**

覆盖从 20% 开始的任务在剩余 100 秒中经过 30 秒后变为 44%、倒计时到期变成完成且为 100%、刷新延迟取 `min(30 秒, 最近完成时间)`，以及完成任务不再需要刷新。

- [ ] **步骤 2：运行测试验证失败**

运行：`android\gradlew.bat :app:testDebugUnitTest --tests "*NotificationProgressProjectionTest"`

预期：因 `NotificationProgressProjection` 尚不存在而编译失败。

- [ ] **步骤 3：实现最少纯函数**

提供：

```kotlin
fun project(item: OngoingNotificationItem, capturedAtEpochMs: Long, nowEpochMs: Long): OngoingNotificationItem
fun nextRefreshDelayMs(snapshot: NativeNotificationSnapshot, nowEpochMs: Long): Long?
```

进度按 `initial + (1 - initial) * elapsed / remainingWindow` 计算并钳制到 `0..1`；倒计时到期投影为完成。刷新间隔上限为 30,000ms。

- [ ] **步骤 4：运行测试验证通过**

再次运行任务 1 的测试，预期全部通过。

### 任务 2：常驻通知刷新服务

**文件：**
- 创建：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/notification/NotificationProgressService.kt`
- 修改：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/notification/AppNotificationManager.kt`
- 修改：`android/app/src/main/AndroidManifest.xml`

- [ ] **步骤 1：扩充失败测试**

为“仅动态任务需要服务”和“关闭通知、空列表、仅完成任务无需服务”添加纯逻辑断言并确认失败。

- [ ] **步骤 2：实现服务生命周期**

服务启动后立即以前台方式发布现有 ID 999，之后使用 `Handler.postDelayed` 按纯函数给出的延迟刷新；不申请唤醒锁。无需刷新时分离前台状态并停止自己。

- [ ] **步骤 3：接入快照和闹钟更新**

`applySnapshot` 与 `onAlarmFired` 在重建常驻通知后同步服务状态。渲染前先调用时间投影，Chronometer 只对尚未完成的倒计时启用。

- [ ] **步骤 4：声明 Android 前台服务**

加入 `FOREGROUND_SERVICE`、`FOREGROUND_SERVICE_SPECIAL_USE` 权限以及 `specialUse` 服务和用途 property；不加入启动广播。

- [ ] **步骤 5：运行 Android 单元测试与构建**

运行：`android\gradlew.bat :app:testDebugUnitTest :app:assembleDebug`

预期：测试通过且 `BUILD SUCCESSFUL`。

### 任务 3：回归验证与提交

**文件：**
- 修改：本计划涉及的通知代码、测试、Manifest 和设计文档。

- [ ] **步骤 1：运行通知静态检查和 Flutter 测试**

```powershell
flutter analyze lib/src/notification test/notification
flutter test
```

- [ ] **步骤 2：运行完整 Android 验证**

```powershell
android\gradlew.bat :app:testDebugUnitTest :app:assembleDebug
```

- [ ] **步骤 3：检查提交范围并提交到 master**

只暂存通知代码、测试、Manifest 和本次文档，不包含 Native WebView 工作区文件；提交信息使用 `fix(通知): 每30秒刷新后台进度`。

