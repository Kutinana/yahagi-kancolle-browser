# 保守帧率模式设计

## 背景

Yahagi 当前提供“自动”“低耗”和“高刷”三种游戏帧率模式。“自动”会在加载阶段拦截舰 C 的 `kcs2/js/main.js`，把 CreateJS Ticker 初始化模式改为 `RAF_SYNCHED`；“高刷”则改为未限速的 `RAF`，并允许 Android 使用设备高刷新率。

舰 C 的游戏代码并非严格以 CreateJS tick 事件的 `delta` 推进，部分逻辑依赖 tick 次数或 `Ticker.framerate`。因此，全局启用未限速 `RAF` 存在改变局部动画或逻辑时序的风险。“自动”也没有必要在加载阶段修改游戏脚本。

## 目标

- 将可选帧率模式收敛为“自动”和“低耗”两档。
- “自动”和“低耗”均不拦截、不下载、不改写舰 C 的 `main.js`。
- 完整移除未限速高刷及 Android 高刷新率请求。
- 将旧版高刷配置安全迁移为“自动”。
- 保持自动模式已有的省电、温度约束和前后台运行策略。

## 非目标

- 不实现渲染帧与游戏逻辑 tick 的分离。
- 不改变舰 C 原始资源缓存规则或其他资源补丁。
- 不重新设计整个设置页。
- 不处理与帧率模式无关的现有未提交改动。

## 用户可见行为

设置页只显示两个选项：

- **自动**：正常情况下运行于 `60 FPS + RAF_SYNCHED`；系统进入省电或温度受限状态时切换为 `30 FPS + TIMEOUT`。
- **低耗**：固定运行于 `30 FPS + TIMEOUT`。

“高刷”选项及说明文字从所有语言界面中移除。升级前选择高刷的用户，升级后自动使用“自动”。

## 实现设计

### Flutter 设置与迁移

- 从 `GameFrameRateMode` 删除 `highRefresh`。
- `GameFrameRateMode.fromWireName` 遇到已保存的 `prefer60` 或未知值时返回 `automatic`。
- 旧布尔配置 `game.unlockFrameRate=true` 迁移为 `automatic`；`false` 仍迁移为 `stable30`。
- 旧字符串配置 `followDisplay` 迁移为 `automatic`；`max60` 仍为 `automatic`，`off` 仍为 `stable30`。
- 设置组件删除高刷分段按钮和高刷描述分支。
- 清理不再使用的高刷本地化键与生成资源。

### Flutter 运行策略

- 从 `GameFrameRateTarget` 删除 `highRefresh`。
- 自动模式仅在 `fps60` 与 `fps30` 之间切换。
- 低耗模式始终使用 `fps30`。
- 保留自动模式对省电、温度、前后台状态的现有判断；删除所有返回或请求 `highRefresh` 的路径。

### Android 原生层

- `GameFrameRateMode.AUTO` 与 `STABLE_30` 的 `mainScriptTickerMode` 均为 `null`，因此 WebViewClient 不再因帧率功能拦截 `main.js`。
- 删除 `GameMainScriptTickerMode.HIGH_REFRESH`、`GameFrameRateTarget.HIGH_REFRESH` 及 JavaScript Bridge 的 `highRefresh`/`RAF` 分支。
- 自动模式仍通过 Bridge 设置 `framerate=60` 和 `RAF_SYNCHED`；低耗模式设置 `framerate=30` 和 `TIMEOUT`。
- 删除 `MainActivity` 中为高刷模式设置无限制首选刷新率的分支；两种保留模式统一采用保守的 60 Hz 上限。
- 若 `GameMainScriptPatcher` 和 `GameMainScriptFetcher` 删除帧率补丁后没有其他调用，则连同相关 WebViewClient 注入参数一起删除，避免保留不可达的脚本改写能力。

## 兼容性与错误处理

- 所有历史高刷配置均降级到“自动”，不会造成设置解析错误。
- 原生层收到历史或未知模式字符串时回退到 `AUTO`。
- Flutter 与 Android 的 wire name 集合保持一致，只保留 `auto`、`stable30`、`fps30` 和 `fps60`。
- Bridge 不支持或配置失败时，沿用现有“帧率设置不可用”降级行为。

## 测试策略

遵循测试驱动开发，先修改或新增测试并确认因旧行为而失败，再修改生产代码：

- 设置迁移测试：`prefer60`、`followDisplay` 和旧布尔 `true` 均迁移为自动。
- 设置界面测试：仅显示“自动”和“低耗”，不再显示“高刷”。
- 帧率策略测试：自动只产生 30/60 目标，低耗只产生 30 目标。
- 运行控制器测试：不存在高刷目标或模式。
- Android 单元测试：自动和低耗均不请求 `main.js` 补丁，Bridge 脚本不包含高刷分支。
- 回归测试：运行相关 Flutter 测试、Android 单元测试和静态分析。
- 构建验证：生成 Debug APK，并报告最终产物的绝对路径。

## 完成标准

- 产品界面和代码中不存在可启用的高刷模式。
- 自动与低耗加载舰 C 时不因帧率功能改写 `main.js`。
- 历史高刷用户无错误地迁移到自动。
- 自动省电降帧和低耗固定 30 帧行为通过测试。
- Debug APK 构建成功。
