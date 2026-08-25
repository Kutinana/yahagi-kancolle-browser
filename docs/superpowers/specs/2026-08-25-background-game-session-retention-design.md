# 后台保持游戏会话设计

## 目标

在“设置 → 画面与声音 → 游戏与声音”中增加“后台保持游戏”开关。开关默认开启；仅当应用已经识别到舰 C 游戏页面并进入后台时，通过 Android 前台服务提高主进程和 WebView 渲染进程的存活优先级。应用回到前台、离开游戏页面或关闭开关时，立即撤销会话保活。

## 用户体验

- 新开关位于“后台播放声音”下方，默认开启并持久化。
- 开关说明明确：进入后台时显示常驻通知并增加耗电，但仍不能保证系统永不回收应用。
- 应用在前台时不显示“游戏会话保持中”通知。
- 已进入舰 C 游戏页并切到后台时，显示低打扰常驻通知：
  - 标题：`矢矧正在后台运行`
  - 正文：`游戏会话保持中 · 点击返回游戏`
- 点击通知返回现有 `MainActivity`。
- 从后台返回前台时撤销会话保活通知。
- 切换到登录页、本地测试页、退出游戏或关闭开关时，不再启动会话保活，并立即撤销已有会话保活。
- 用户从最近任务划掉应用时，游戏页面随 Activity 销毁，服务不得留下孤立常驻通知。

远征、入渠、建造、士气等现有通知继续遵循通知设置。它们可以在应用前台显示，也不因“后台保持游戏”关闭而停止。

## 状态模型

Flutter 侧维护三个独立输入：

1. `enabled`：用户设置，默认 `true`，由 `SharedPreferences` 持久化。
2. `gameActive`：`GameToolbarController.stage == GameSurfaceStage.game`。
3. `appInForeground`：由 Flutter 应用生命周期产生；`resumed` 为前台，`hidden`/`paused` 为后台，短暂的 `inactive` 不改变现状，`detached` 触发停止。所有转换必须去重，避免系统弹窗或通知栏展开造成通知闪烁。

会话保活的唯一判定为：

```text
shouldRetain = enabled && gameActive && !appInForeground
```

状态变化由专用 Coordinator 串行同步到平台端。相同目标状态不重复调用；平台调用失败时保留错误信息并允许下一次状态变化重试，不能影响游戏 WebView 主流程。

## Flutter 组件边界

### `BackgroundGameRetentionController`

- 负责加载、保存和暴露 `enabled`。
- 默认值为 `true`。
- 设置保存失败时恢复旧值并通知界面。
- 不直接判断游戏页面或应用生命周期。

### `BackgroundGameRetentionCoordinator`

- 监听设置 Controller、`GameToolbarController` 和应用生命周期。
- 计算 `shouldRetain` 并调用平台 Port。
- 初始化时应用当前状态；销毁时移除监听并请求停止会话保活。
- 串行化平台调用，避免快速前后台切换造成旧请求覆盖新状态。

### `BackgroundGameRetentionPort`

- 暴露 `setRetaining(bool retaining)`。
- 默认实现使用 MethodChannel。
- Widget、Controller 和 Coordinator 测试使用内存实现，不依赖真实 Android 服务。

## Android 服务设计

扩展现有通知前台服务为统一游戏前台服务，避免游戏会话与任务进度同时产生两条常驻通知。服务保存两个相互独立的需求：

- `sessionRetentionRequested`：Flutter 请求的后台游戏会话保活。
- `progressRefreshRequired`：现有通知快照是否需要 30 秒进度刷新。

服务运行条件为两者任一成立。通知投影规则为：

1. 有进行中的任务时，继续显示现有任务进度卡。
2. 没有任务、但请求会话保活时，显示“游戏会话保持中”。
3. 两者都不成立时，退出前台状态、移除通知并停止服务。

Flutter 在回到前台时将 `sessionRetentionRequested` 设为 `false`；如果仍有任务，服务继续运行并保留任务进度通知。关闭“后台保持游戏”不得停止任务提醒。

服务使用现有低重要性 ongoing notification channel、`specialUse` 前台服务类型和现有通知权限声明。Android 13 及以上通知权限被拒绝时不反复请求权限；平台仍尝试按系统规则启动前台服务，设置页文案说明常驻通知依赖通知权限。

服务必须处理 `onTaskRemoved`：清除会话保活请求；若没有任务进度需求则停止自身，防止游戏 Activity 已消失而通知仍常驻。

## 数据流

```text
游戏页面识别 ─┐
应用生命周期 ─┼─> BackgroundGameRetentionCoordinator
用户设置 ─────┘                 │
                               v
                     MethodChannel Retention Port
                               │
                               v
                    Android 统一游戏前台服务
                               │
                   ┌───────────┴───────────┐
                   v                       v
             会话保持通知            现有任务进度通知
```

## 本地化与界面

为简体中文、繁体中文和日文资源添加：

- 开关标题“后台保持游戏”；
- 开关说明；
- 会话保持通知标题与正文。

开关沿用 `ScreenSettingsPage` 中现有 `buildSwitchTile` 风格，放入“游戏与声音”卡片，位于“后台播放声音”之后，以分隔线隔开。添加稳定 Widget Key，供自动化测试定位。

## 错误处理

- 设置写入失败：Controller 回滚开关值，避免界面与磁盘状态不一致。
- MethodChannel 失败：Coordinator 记录错误但不打断 WebView 页面识别或前后台切换。
- 前台服务启动失败：平台返回结构化错误；下一次生命周期或设置变化可以重试。
- 通知权限缺失：不循环弹权限框，不使开关自动关闭。
- 快速前后台切换：平台请求串行执行，并以最新目标状态为准。

## 测试策略

### Flutter 单元与 Widget 测试

- 新安装默认开启。
- 已保存的关闭状态可以恢复。
- 保存失败会回滚。
- `enabled && game && background` 才请求保活。
- 返回前台、离开游戏页或关闭开关会请求停止。
- 快速状态变化最终同步最新目标。
- 设置项位于“游戏与声音”卡片且默认显示开启。
- 三语本地化资源完整。

### Android JVM 测试

- 服务需求投影正确合并会话保活和任务进度。
- 有任务时优先显示任务进度通知。
- 无任务但有会话请求时显示会话保持通知。
- 两种需求均无时停止服务。
- `onTaskRemoved` 只清除会话需求，不误删仍需送达的任务状态。

### 集成验证

- Flutter 静态分析和相关测试通过。
- Android 单元测试通过。
- Release APK 构建成功。
- 真机验证：进入游戏后按 Home 显示通知且进程不再是普通 cached `oom_adj=900`；返回前台通知消失；关闭开关后再次按 Home 不启动会话保活。

## 非目标

- 不承诺 Android 永不回收进程。
- 本次不处理 beta.2 内存增长根因。
- 不请求忽略系统电池优化。
- 不在登录页、设置页或本地原型页面常驻。
- 不改变现有任务提醒的时间、声音、振动和权限策略。
