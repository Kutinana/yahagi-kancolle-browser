# POI 对齐的游戏框架重载修复设计

## 背景

当前「重新载入游戏」功能在 Android 真机上返回 `blocked`。现有脚本从外层 DMM 页面读取 `#game_frame.contentDocument`，但 Android WebView 按同源策略隔离跨域 iframe，因此脚本无法进入包含 `#htmlWrap` 的文档。

POI 的目标行为是仅重新载入 `#htmlWrap` 所代表的游戏框架，不刷新外层 DMM 页面。修复必须保持这一语义，不以整页刷新作为降级方案。

## 目标

- 在受支持的 Android WebView 中，仅重新载入游戏框架 `#htmlWrap`。
- 不刷新外层 DMM 页面，不改变登录页或导航历史。
- 允许从 Flutter 界面发起操作，并获得一次明确的异步结果。
- 当 Android WebView 不支持对子框架注入时，显示明确提示：当前设备的 Android WebView 太旧，不支持对子框架注入。
- 保留 POI 对该操作可能触发猫袭的风险提示。

## 非目标

- 不关闭 WebView 的同源安全策略。
- 不通过固定游戏 URL 重新导航。
- 不在失败时自动执行整页刷新。
- 不改变「刷新页面」功能的现有行为。

## 方案选择

采用专用的子框架消息桥。通过 AndroidX WebKit 的文档开始脚本（Document Start Script）向受信任来源的所有 frame 注入脚本，再通过 WebMessage 与原生层通信。

未采用以下方案：

- 关闭同源安全策略：会扩大整个游戏浏览器的攻击面。
- 固定 URL 重载：依赖 DMM 页面结构和地址，无法可靠保持 POI 语义。
- 失败后整页刷新：可能退出当前演习等流程，不符合用户确认的严格 POI 行为。

## 架构

### 子框架脚本

脚本在受信任来源的每个 frame 中执行，职责如下：

1. 安装一次消息处理器，并以安装标志避免重复注册。
2. 在 DOM 可用后检查当前文档是否包含 `#htmlWrap`。
3. 向原生层报告当前 frame 是否具备重载目标。
4. 收到带请求 ID 的重载命令时，仅由具备 `#htmlWrap` 的 frame 执行。
5. 优先调用与 POI 相同的 `htmlWrap.contentWindow.location.reload()`；若 WebView 对子 iframe 的 Location 访问仍有限制，则以相同 `src` 重新赋值，仅重载该 iframe。
6. 执行后返回请求 ID 和结果，确保原生层只完成对应请求一次。

脚本仅注入以下 HTTPS 来源：

- `*.dmm.com`
- `*.dmm.co.jp`
- `*.kancolle-server.com`

### Android 原生桥

新增独立的游戏框架重载桥，复用项目现有帧率桥和抓包桥采用的 AndroidX WebKit 模式：

- 在 WebView 首次导航前注册 `WebMessageListener` 和 Document Start Script。
- 保存报告存在 `#htmlWrap` 的 frame 对应回复代理。
- 每次操作生成唯一请求 ID，并向候选 frame 发送命令。
- 第一个匹配请求 ID 的成功结果完成调用；重复消息被忽略。
- 在超时、WebView 重建或 Activity 销毁时结束或取消挂起请求。
- 检查 `DOCUMENT_START_SCRIPT` 与 `WEB_MESSAGE_LISTENER` 能力；缺失时返回专用的 `unsupported` 状态。

桥必须直接绑定当前 WebView 实例，不能在操作发生时临时注入。临时注入只对后续导航生效，无法修复已经打开的游戏页面。

### Flutter 接口与界面

现有 `reloadGameFrame()` 接口继续返回枚举结果，并新增 `unsupported` 结果。界面行为如下：

- `reloaded`：关闭确认框，不显示失败提示。
- `unsupported`：显示「当前设备的 Android WebView 太旧，不支持对子框架注入。」
- `gameFrameNotFound` 或 `htmlWrapNotFound`：保留结构未找到提示。
- `blocked` 或超时：显示可诊断的重载失败提示，但不触发整页刷新。

## 数据流

1. 用户在刷新对话框选择「重新载入游戏」。
2. Flutter Controller 对并发点击进行合并，并调用原生端。
3. 原生桥检查 WebView 能力、当前 WebView 代次和候选 frame。
4. 原生桥向候选 frame 广播带请求 ID 的命令。
5. 目标 frame 仅重载 `#htmlWrap`，并回传结果。
6. 原生桥核对请求 ID 后完成 MethodChannel 调用。
7. Flutter 根据结果关闭对话框或显示对应提示。

## 生命周期与错误处理

- WebView 创建时安装桥；WebView 销毁或重建时移除监听器、脚本和旧回复代理。
- 旧 WebView 代次的结果不能完成新 WebView 的请求。
- 同一时刻只允许一个重载请求；重复点击复用同一个 Future。
- 找不到目标 frame 时不执行任何页面导航。
- 超时后返回失败，迟到的消息被请求 ID 校验丢弃。
- 所有失败路径都禁止调用外层 WebView 的 `reload()`。

## 测试策略

### Android 单元测试

- 能力检测缺失时返回 `unsupported`。
- 文档开始脚本包含目标检测、请求 ID 和仅重载 `#htmlWrap` 的逻辑。
- 只接受受信任来源的消息。
- 目标 frame 成功时仅完成一次请求。
- 非目标 frame、错误请求 ID、重复回包和迟到回包均被忽略。
- 超时、WebView 重建和销毁会清理挂起请求。
- 不存在任何失败后调用整页 `reload()` 的路径。

### Flutter 测试

- 原生 wire 状态 `unsupported` 映射为对应枚举。
- 对话框显示指定的旧 WebView 提示。
- 成功、未找到、阻止、超时和重复点击行为保持正确。

### 真机验收

在用户当前已打开游戏的设备上：

1. 安装包含修复的调试包并启动游戏。
2. 记录外层页面 URL、导航状态和目标 frame 就绪状态。
3. 在母港与演习相关页面分别触发「重新载入游戏」。
4. 确认游戏画面重新初始化，外层 DMM 页面未刷新，应用未退回登录页。
5. 检查日志中请求 ID 只有一次成功完成，且没有整页刷新调用。

若安装修复包会结束当前应用进程，需先告知用户；不对游戏账号执行战斗、编成或其他业务操作。

## 验收标准

- 支持该能力的 Android WebView 中，操作只重载 `#htmlWrap`。
- 当前截图中的通用 `blocked` 提示不再由跨域访问触发。
- 不支持该能力时显示用户指定的明确提示。
- 失败时不会自动整页刷新。
- 自动化测试全部通过，并完成一次用户设备上的只读状态检查和手动重载验证。
