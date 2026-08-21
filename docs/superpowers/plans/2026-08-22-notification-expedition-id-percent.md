# 通知远征编号与百分比实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 修正常驻通知的远征显示编号和倒计时左侧百分比。

**架构：** Flutter 通知协调器复用现有远征编号格式化函数；Android 原生层通过纯函数生成合法的 Chronometer 格式字符串。布局与通知协议保持不变。

**技术栈：** Flutter/Dart、Android/Kotlin、RemoteViews、JUnit

---

### 任务 1：远征显示编号

**文件：**
- 修改：`lib/src/notification/game_notification_coordinator.dart`
- 测试：`test/notification/game_notification_coordinator_test.dart`

- [ ] **步骤 1：编写失败的测试**

为任务 110 构造远征状态，断言常驻标题包含 `远征 B1`；再使用 `displayNumber: 'B-自定义'` 断言母港编号优先。

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/notification/game_notification_coordinator_test.dart`

预期：标题仍包含 `远征 110`，断言失败。

- [ ] **步骤 3：编写最少实现**

导入 `expedition_mission_picker.dart`，使用：

```dart
final displayId = expeditionDisplayId(mission.missionId, masterMission);
```

将远征标题中的内部 ID 替换为 `displayId`。

- [ ] **步骤 4：运行测试验证通过**

运行：`flutter test test/notification/game_notification_coordinator_test.dart`

预期：全部通过。

### 任务 2：倒计时百分比格式

**文件：**
- 修改：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/notification/NotificationSnapshot.kt`
- 修改：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/notification/AppNotificationManager.kt`
- 测试：`android/app/src/test/kotlin/app/yahagi/kancollebrowser/notification/NotificationSnapshotTest.kt`

- [ ] **步骤 1：编写失败的测试**

断言 `NotificationChronometer.countdownFormat(53, true)` 返回 `53%%  %s`，关闭百分比时返回 `%s`。

- [ ] **步骤 2：运行测试验证失败**

运行：`android\\gradlew.bat :app:testDebugUnitTest --tests "*NotificationSnapshotTest"`

预期：`countdownFormat` 尚不存在，编译失败。

- [ ] **步骤 3：编写最少实现**

在 `NotificationChronometer` 添加格式函数，并让 `bindItem` 使用该函数。字面 `%` 必须写成 `%%`，避免被 `String.format` 当作格式说明符。

- [ ] **步骤 4：运行测试验证通过**

运行：`android\\gradlew.bat :app:testDebugUnitTest --tests "*NotificationSnapshotTest"`

预期：全部通过。

### 任务 3：完整验证与提交

**文件：**
- 修改：`docs/superpowers/specs/2026-08-22-notification-expedition-id-percent-design.md`
- 修改：`docs/superpowers/plans/2026-08-22-notification-expedition-id-percent.md`

- [ ] **步骤 1：运行完整验证**

运行：

```powershell
flutter analyze lib/src/notification test/notification
flutter test
cd android
.\gradlew.bat :app:testDebugUnitTest :app:assembleDebug
```

预期：静态检查无问题，Flutter 测试无失败，Android 构建成功。

- [ ] **步骤 2：检查提交范围**

仅暂存上述通知代码、测试与文档，不暂存 Native WebView 工作区改动。

- [ ] **步骤 3：提交到 master**

```powershell
git commit -m "fix(通知): 修正远征编号与进度百分比"
```

