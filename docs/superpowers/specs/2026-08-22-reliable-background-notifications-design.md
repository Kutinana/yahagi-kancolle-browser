# 可靠后台通知修复设计

## 目标

在不实现“设备重启后自动重建提醒”的前提下，使通知在普通的应用后台清理或进程回收后仍能保留，并保证游戏内快速建造、快速修复、舰队换人等状态变化能够及时、原子地更新通知栏内容。

## 非目标

- 不注册 `BOOT_COMPLETED` Receiver。
- 不在设备重启后自动恢复 Alarm 或常驻通知。
- 不在应用进程被系统“强行停止”后绕过 Android 的冻结限制。
- 不在后台主动访问舰 C 服务器；通知只反映应用已经捕获并确认的游戏状态。

## 总体架构

移除当前每秒运行的 `NotificationOngoingService`。Dart 层根据完整游戏状态生成一份不可变的 `NotificationSnapshot`，通过单一 MethodChannel 调用交给 Android。Android 原生层先持久化快照，再按新旧快照差异调度或取消 Alarm，并通过 `NotificationManager` 原子替换常驻通知。

常驻倒计时使用 Android `RemoteViews` 中的系统 `Chronometer`，不依赖 Dart Timer、Handler 或前台 Service 每秒刷新。应用进程被普通后台清理后，已经发布的通知和已经调度的 Alarm 继续由系统持有。Alarm 触发时，Receiver 从原生持久化快照移除已完成任务并重建常驻通知。

```text
游戏 API 事件 / 设置变化
        ↓
GameState + 稳定计时锚点
        ↓
GameNotificationCoordinator
        ↓ 完整快照（不是增量命令）
Android NotificationSnapshotStore
        ↓
Alarm diff + 常驻通知原子替换
```

## 数据模型

### NotificationSnapshot

快照包含：

- `schemaVersion`：快照格式版本。
- `updatedAtEpochMs`：生成时间。
- `alarms`：全部仍有效的一次性提醒。
- `ongoingItems`：全部仍有效的常驻任务。
- `presentation`：进度条、百分比、倒计时、声音、振动设置。

每个 Alarm 除现有 key、类型、标题、正文和触发时间外，增加：

- `taskId`：与常驻任务关联的稳定业务 ID。
- `stage`：`preempt`、`milestone` 或 `complete`。
- `removeTaskOnFire`：触发后是否从常驻快照删除关联任务。

业务 ID 示例：

- `expedition:2`
- `repair:1`
- `construction:3`
- `anchorage:1`
- `morale:2:normal`

Android 使用单个 JSON 文档保存快照。写入成功后才应用系统副作用；如果调度失败，保留快照并把失败原因返回 Dart 诊断层。

## 冷启动与缓存恢复

### 游戏状态就绪屏障

`GameStateController` 增加显式异步初始化入口，加载游戏状态、任务数据和计时锚点。`main()` 必须等待初始化完成后再启动通知协调器，避免协调器先从 `GameState.empty` 覆盖有效的原生通知快照。

### 通知专用快照

通知不再只依赖 `GameStateStore` 的五秒延迟缓存。每次通知相关状态变化都立即生成并保存完整原生快照。已经渲染好的远征名、舰娘名和通知正文属于快照的一部分，因此冷启动不需要先拿到 `api_start2` 才能显示具体名称。

如果冷启动缓存中缺少主数据，协调器不得用“远征”或“远征 37”覆盖原生快照中同一业务任务已有的具体名称。收到完整主数据后再生成新快照。

### 计时锚点

明石和野崎计时器的 anchor、knowledge、reset reason、last observed time 单独持久化。计时器发生 reset、observe 或 clear 时保存；应用初始化时恢复。通知相关的状态写入不使用五秒 debounce。

## 游戏状态同步规则

### 快速建造和快速修复

`createship_speedchange` 和 `nyukyo/speedchange` 更新 GameState 后，协调器重新生成完整快照。新快照不包含已完成任务；Android diff 取消对应完成 Alarm，并从常驻通知删除任务。如果删除后没有任务，直接取消通知 ID 999，不经过 Service。

### 明石泊地修理

通知是否有效必须同时满足：

1. 存在明石计时锚点；
2. `AnchorageRepairCalculator.hasReadyFleet(state)` 当前仍为真；
3. 当前存在可修理目标。

底层全局计时器可以继续保留历史锚点，但通知层不能把“存在历史锚点”等同于“当前正在泊地修理”。明石换下、维修设施失效或没有可修对象时，快照立即移除泊地任务和未触发 Alarm。

泊地模式行为：

- `twentyMinutes`：安排首轮 20 分钟里程碑提醒。
- `allRepaired`：按当前可修理舰的最大预计完成时间安排提醒。
- `both`：同时安排两类提醒；20 分钟提醒触发时不删除仍未全部修满的常驻任务。

### 士气恢复

士气目标时间不再使用每次同步时的 `now + remaining`。协调器维护并持久化目标账本：以舰队 ID、成员 ID 与已观测 Cond 组成 fingerprint。fingerprint 未变化时复用既有目标时间；成员或 Cond 变化时才重算。

## Android 通知行为

### 常驻通知

- 直接使用 `NotificationManager.notify(999, notification)`。
- 保留 `setOngoing(true)`，但不启动前台 Service。
- 每个展示行使用系统 Chronometer 根据绝对目标时间倒数。
- 百分比和进度条展示最近一次确定快照值；倒计时由系统实时更新。
- Alarm Receiver 触发完成阶段后更新持久化快照并重建常驻卡片。

### 权限与降级

设置页展示三个独立状态：

- Android 13+ 通知权限。
- Android 12+ 精确闹钟特殊权限。
- 系统通知 Channel 是否被用户关闭。

通知权限请求等待系统回调后返回真实结果。精确闹钟调度前调用 `canScheduleExactAlarms()`：

- 已授权：`setExactAndAllowWhileIdle()`。
- 未授权：`setAndAllowWhileIdle()` 非精确降级，并在设置页提示可能延迟。

权限恢复或应用回到前台时重新读取能力状态并重新应用当前快照，但不实现开机广播恢复。

### 声音和振动

Android 8+ 的 Channel 行为创建后不可由应用覆盖，因此每个业务类别创建四种稳定 Channel 变体：

- 声音 + 振动
- 仅声音
- 仅振动
- 静音

调度 Alarm 时按当前应用设置选择 Channel。用户在系统设置中的 Channel 选择拥有最终优先级。设置页提供打开应用系统通知设置的入口。

### 全部取消

关闭总开关时应用空快照：Android 从旧快照枚举并取消全部 PendingIntent，删除原生快照并取消常驻通知。`cancelAllAlarms` 不再是空实现。

### 通知点击

点击通知继续打开现有 MainActivity。快照保留 `taskId`，为以后深链到具体页面提供扩展点，但本次不增加页面跳转。

## 错误处理与诊断

- MethodChannel Port 不再吞掉所有异常。
- Android `applySnapshot` 返回精确调度数量、降级数量、取消数量和失败列表。
- Dart 使用现有诊断日志记录快照版本、任务数量、最近游戏 API path 与原生结果；日志不记录 Cookie 或游戏响应正文。
- JSON 损坏时原生删除损坏快照、取消常驻通知并返回可诊断错误，不崩溃。
- 单个 Alarm 调度失败不阻止其他 Alarm 和常驻通知更新。

## 测试设计

### Dart 单元测试

- 冷启动等待缓存加载后才首次应用通知快照。
- 缺少主数据时不以泛化远征名覆盖已有具体名称。
- 快速建造和快速修复从快照移除对应任务与 Alarm。
- 明石换下、维修设施失效和无可修对象时移除泊地通知。
- 三种泊地模式生成正确 Alarm。
- 士气 fingerprint 不变时目标时间稳定，变化时才重算。
- 总开关关闭产生空快照。
- 原生 apply 失败进入诊断路径而不是静默丢失。

### Kotlin/JVM 测试

- 新旧快照 diff 正确计算新增、更新、取消。
- Alarm 触发后按 `removeTaskOnFire` 更新快照。
- 20 分钟里程碑不会错误删除 `both` 模式的泊地任务。
- 四种声音/振动设置映射到正确 Channel ID。
- 损坏 JSON 安全降级。

### 构建与静态验证

- 完整 `flutter test`。
- 完整 `flutter analyze`。
- Android debug APK 构建。
- 检查合并 Manifest 不再声明无必要的通知前台 Service。

### 真机验收

- Android 12、13、14+ 各验证一次。
- 普通划掉最近任务后通知仍存在、倒计时继续。
- 快速建造、快速修复后任务立即消失。
- 明石换下后泊地任务立即消失。
- 拒绝精确闹钟权限后仍收到可能延迟的提醒。
- 拒绝通知权限时设置页明确显示未授权。
- 声音与振动四种组合符合应用设置；系统 Channel 禁用时以系统设置为准。

## 范围确认

本设计修复通知递归、前台服务兼容性、权限、取消、声音振动、士气目标漂移、泊地模式、常驻刷新、缓存恢复、游戏状态撤销和错误可观测性。设备重启恢复明确不在本次范围内。
