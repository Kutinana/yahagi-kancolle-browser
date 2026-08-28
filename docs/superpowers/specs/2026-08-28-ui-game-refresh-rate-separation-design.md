# UI 与游戏刷新率解耦设计

## 背景

Yahagi 当前在游戏帧率配置完成后，将 Android Activity 的
`preferredRefreshRate` 固定为 `60f`。该属性作用于整个应用窗口，不只作用于游戏
WebView，因此 Flutter 菜单、列表、页面切换和滚动也被限制在 60 Hz。

真机数据已确认：测试设备内屏支持最高 120 Hz，但 Yahagi 前台时系统收到应用的
60 Hz 窗口投票，活动显示模式降为 60 Hz。游戏内部的 CreateJS Ticker 已有独立的
30/60 FPS 控制，不需要依赖 Activity 的窗口刷新率限制。

## 目标

- Flutter UI 请求当前屏幕支持的最高刷新率。
- 60 Hz、90 Hz、120 Hz 等设备均按各自能力工作，不写死 120 Hz。
- 游戏自动模式继续封顶 60 FPS，低耗模式继续固定为 30 FPS。
- 省电模式、温控和其他系统显示策略可以覆盖应用偏好并自动降低刷新率。
- 折叠设备切换屏幕或应用恢复前台后，重新读取当前屏幕能力。
- 游戏帧率设置不得再修改 Activity 或 Flutter UI 的刷新率。

## 非目标

- 不恢复已删除的未限速游戏高刷模式。
- 不修改舰 C 的 `main.js`。
- 不让游戏逻辑或 CreateJS Ticker 运行在 60 FPS 以上。
- 不直接控制 WebView 的底层 `SurfaceControl`。
- 不修改系统刷新率设置、省电设置或温控策略。
- 本次开发不向用户正在使用的手机安装 APK，也不重启或操作手机上的 Yahagi。

## 方案比较

### 方案 A：取消窗口的 60 Hz 偏好

将 `preferredRefreshRate` 清零，让 Android 完全自行选择刷新率。

优点是修改最少，系统适配风险低。缺点是部分设备可能继续将没有明确高刷偏好的应用
保持在 60 Hz，不能稳定满足「UI 使用屏幕最高刷新率」的目标。

### 方案 B：请求当前屏幕最高刷新率

读取当前 `Display` 的受支持模式，过滤无效值后选择最高 `refreshRate`，再写入
Activity 的 `preferredRefreshRate`。

该值属于应用偏好，不会绕过系统的省电、温控或显示策略。Android 仍可选择更低的
实际刷新率。该方案同时适配 60 Hz、90 Hz、120 Hz 及其他刷新率设备。

这是本次采用的方案。

### 方案 C：分别控制 Flutter 与 WebView Surface

为 Flutter Surface 请求高刷，并为 WebView Surface 单独声明 30/60 FPS。

该方案理论上边界最细，但 Yahagi 同时支持 Flutter PlatformView、HCPP 和原生
Activity WebView，底层 Surface 结构并不统一。实现会依赖 Flutter 引擎和 Android
WebView 的内部层级，复杂度和回归风险明显高于收益，因此不采用。

## 架构设计

### UI 刷新率策略

新增一个纯 Kotlin 策略组件，职责仅包括：

1. 接收当前屏幕报告的刷新率集合。
2. 忽略 `NaN`、无限值、零和负数。
3. 返回有效刷新率中的最大值。
4. 没有有效值时返回 `0f`，表示不声明窗口偏好。

Activity 负责从当前 `Display` 读取 `supportedModes`，把各模式的
`refreshRate` 交给策略组件，并将结果写入 `window.attributes.preferredRefreshRate`。
只使用刷新率偏好，不设置 `preferredDisplayModeId`，避免改变屏幕分辨率或绑定某个
具体显示模式。

### 生命周期

Activity 在以下时机应用 UI 刷新率偏好：

- `onCreate`：建立窗口后的首次设置。
- `onResume`：从后台恢复时重新核对当前屏幕能力。
- 切换到另一块显示屏时：重新读取新屏幕的受支持刷新率。

Android 24 和 25 没有显示屏移动回调；这两个版本依靠 Activity 重建或下一次
`onResume` 重新应用。较新版本在显示屏切换回调中立即更新。重复写入相同值时不更新
窗口属性，避免无意义的窗口事务。

### 游戏帧率策略

保留现有游戏链路：

```text
Flutter GameFrameRateRuntimeController
  → Android GameFrameRateManager
  → GameFrameRateBridge
  → 页面内 CreateJS Ticker
```

- 自动模式正常使用 `fps60`，系统省电或温度受限时可降为 `fps30`。
- 低耗模式始终使用 `fps30`。
- `fps60` 使用 `ticker.framerate = 60` 与 `RAF_SYNCHED`。
- `fps30` 使用 `ticker.framerate = 30` 与 `TIMEOUT`。
- Bridge 继续拒绝未知目标，不增加高于 60 FPS 的游戏目标。

### 解耦边界

删除 `GameFrameRateManager.Host` 及 `onFrameRateModeChanged` 回调。创建
`GameFrameRateManager` 时不再传入 Activity，游戏帧率管理器只依赖 Bridge 和系统
约束来源。

解耦后：

- UI 刷新率只由 Activity 的 UI 策略负责。
- 游戏帧率只由游戏运行控制器和 Bridge 负责。
- 用户切换「自动／低耗」时，不产生任何窗口刷新率写入。

## 系统策略与异常处理

- Activity 请求的是当前屏幕最高刷新率，不是强制锁定。系统仍拥有最终决定权。
- 省电模式、温控、厂商策略或多窗口限制导致实际刷新率下降时，不视为错误。
- 当前屏幕不可用或没有有效模式时，清除应用偏好并交由系统选择。
- 折叠换屏后若新屏幕最高刷新率不同，以新屏幕能力为准。
- 游戏 Bridge 配置失败时沿用现有降级行为，不影响 UI 刷新率策略。

## 测试策略

遵循测试驱动开发，先增加失败测试，再修改生产代码。

### Kotlin 单元测试

- `[60]` 返回 `60f`。
- `[60, 90]` 返回 `90f`。
- `[60, 90, 120]` 返回 `120f`。
- 无序、重复刷新率仍返回最大有效值。
- `NaN`、无限值、零和负数被忽略。
- 没有有效刷新率时返回 `0f`。

### 静态契约测试

- `MainActivity` 不再把 `preferredRefreshRate` 固定为 `60f`。
- `GameFrameRateManager` 不再声明 `Host` 或调用
  `onFrameRateModeChanged`。
- 游戏目标枚举仍只包含 `fps30` 和 `fps60`。
- Bridge 脚本仍不包含未限速 `ticker.RAF` 分支。

### 回归验证

- 运行相关 Flutter 测试。
- 运行 Android 全量单元测试。
- 运行 `flutter analyze`。
- 构建 Debug APK，但不执行 `adb install`、`flutter install` 或任何会影响手机上
  现有游戏会话的命令。

## 完成标准

- 生产代码不再存在游戏帧率管理器修改 Activity 刷新率的路径。
- UI 在正常系统状态下请求当前屏幕的最高刷新率。
- 游戏仍只有 30/60 FPS 两档目标。
- 省电和温控可以使系统实际刷新率低于应用请求值。
- 自动化测试、静态分析和 Debug APK 构建通过。
- 最终报告 Debug APK 的绝对路径，由用户自行选择安装时机。
