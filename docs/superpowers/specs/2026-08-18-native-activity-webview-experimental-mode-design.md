# 原生直连 WebView 实验模式设计

## 背景

Yahagi 当前通过 Flutter `webview_flutter` 的 Platform View 承载舰队 Collection 游戏页面，并提供以下 3 种渲染模式：

- 高性能模式：Texture Layer + WebGL。
- 标准模式：Hybrid Composition + WebGL。
- 兼容模式：Hybrid Composition + Canvas。

SM-F9460 的诊断记录显示，应用进程 PSS 平均约为 878 MB，峰值约为 1.13 GB，并多次收到 Android 内存压力回调。日志中没有对应的 Flutter、Dart 或 Java 异常栈，进程却多次在没有正常 `stopped` 事件的情况下重新写入 `started`。现有证据指向系统低内存终止，但尚不能区分主要压力来自游戏 WebView、WebGL 图形资源，还是 Flutter Platform View 的额外合成成本。

本设计增加一个可回退的实验模式，在保留现有 Poi 风格布局和 Flutter 业务状态的前提下，让 `MainActivity` 直接承载原生 Android WebView。该模式用于隔离宿主差异，并以真实设备数据判断是否值得继续迁移。

## 目标

- 保留现有 3 种渲染模式，新增「原生直连（实验）」模式。
- 保持当前顶部资源栏、常驻工具栏、侧边功能区和游戏区域布局。
- 实验模式不创建 Flutter `WebViewWidget` 或 Platform View。
- 原生 WebView 作为现有 `MainActivity` 根布局的直接子 View。
- 复用现有 Cookie、代理、资源缓存、Gadget Bypass、API 捕获、音频、帧率和截图能力。
- 为现有模式与实验模式提供可比较的内存、卡顿和退出诊断。
- 创建或运行失败时安全回退，不形成启动循环。

## 非目标

- 不使用 Kotlin 或 Jetpack Compose 重写整个 Poi 游戏页面。
- 不修改现有 3 种模式的渲染与生命周期行为。
- 不在首版同时引入「原生直连 + Canvas」，避免混合实验变量。
- 不迁移正在运行的 WebView 页面实例；切换宿主时允许重新加载。
- 不把 `android:largeHeap="true"` 作为本实验的组成部分。
- 不在收到一次内存压力后自动清缓存、切换渲染器或重载游戏。

## 方案比较

### 方案 A：现有 MainActivity 直接挂载原生 WebView

Flutter 继续绘制现有界面，并在游戏位置渲染空占位区域。Android 将原生 WebView 作为 `MainActivity` 的直接子 View 覆盖到该区域。

优点：

- 只保留 1 个 Flutter Engine，不需要跨 Activity 迁移状态。
- 可以复用现有 Flutter 页面和业务控制器。
- 能够隔离 Platform View 宿主成本，改动范围适合实验验证。
- 失败时可以退回现有模式。

缺点：

- 需要同步 Flutter 游戏区域与 Android View 坐标。
- 原生 WebView 位于 FlutterView 上方，必须处理 Flutter 路由和弹窗遮挡。
- Flutter 与原生两侧需要维护明确的宿主协议。

本设计采用该方案。

### 方案 B：新增独立 NativeGameActivity

新 Activity 同时承载 FlutterView 和原生 WebView。该方案边界更独立，但需要在 2 个 Activity 之间迁移或复制 FlutterEngine 与业务状态，复杂度较高，不适合作为首轮实验。

### 方案 C：原生重写整个 Poi 游戏页面

使用 Kotlin Android View 或 Jetpack Compose 重写顶部栏、工具栏、侧边面板和 WebView。该方案理论宿主开销最低，但会形成两套 UI 和状态同步路径，开发及维护成本远超实验目标。

## 用户可见行为

### 新模式

- 枚举名称：`nativeActivityExperimental`。
- 中文名称：原生直连（实验）。
- 承载方式：`MainActivity` 直接子 View。
- 游戏渲染器：WebGL。
- Flutter 工具栏模糊：关闭。
- 非 Android 平台不显示或不允许选择该模式。

实验模式使用 WebGL，以标准模式作为主要对照组。Canvas、资源缓存容量、代理和帧率仍遵循用户设置，但不得在进入实验模式时自动改变。

### 模式切换

从任意现有模式切换到实验模式，或从实验模式切换到现有模式时：

1. 显示现有的模式切换确认提示。
2. 停止当前页面的数据桥接、截图任务和延迟回调。
3. 销毁当前 WebView。
4. 持久化新模式。
5. 创建目标宿主的新 WebView。
6. 重新应用 Cookie、User-Agent、代理、资源缓存、Gadget Bypass、API 捕获、音频和帧率设置。
7. 从现有登录入口重新加载游戏页面。
8. 页面进入 `ready` 后恢复工具栏操作、截图和音频状态。

不尝试把历史记录、JavaScript 对象或正在运行的页面从一个 WebView 实例迁移到另一个实例。

## 总体架构

```text
MainActivity 根布局
├── FlutterView
│   ├── 顶部资源栏
│   ├── 常驻工具栏
│   ├── 右侧功能区
│   └── NativeGameSurfaceSlot（空占位区域）
└── NativeGameWebView
    └── 仅覆盖 NativeGameSurfaceSlot 对应的窗口矩形
```

### Flutter 组件

#### NativeGameSurfaceSlot

负责以下工作：

- 占据现有游戏画面的布局位置。
- 在布局完成后取得自身相对 FlutterView 的矩形。
- 在矩形、设备像素比、窗口尺寸或可见性变化时通知原生宿主。
- 在组件移除、路由被覆盖或模式失效时通知原生宿主隐藏 WebView。
- 不创建 `WebViewController`、`WebViewWidget` 或其他 Platform View。

矩形更新在帧结束后合并发送。相同矩形不重复上报，连续窗口变化只保留最新值。

#### NativeActivityGameBrowserPort

实现现有 `GameBrowserPort` 抽象，通过 MethodChannel 控制原生 WebView。上层控制器继续使用统一接口，不感知实际宿主。

端口至少支持：

- 创建、显示、隐藏和销毁 WebView。
- 打开 URL、刷新、停止加载和后退。
- 执行 JavaScript 并返回结果。
- 清理 WebView 缓存。
- 应用 User-Agent、Cookie、代理、缓存和帧率设置。
- 静音、恢复音频和截图。

#### NativeGameSurfaceVisibilityCoordinator

集中管理原生 WebView 的可见性：

- 游戏路由位于最上层且占位区域有效时显示。
- Flutter 弹窗、全屏页面或下一条路由覆盖游戏页时隐藏。
- 覆盖层关闭后重新上报矩形并显示。
- 页面正在切换宿主或销毁时保持隐藏。

游戏路由通过 `RouteObserver` 的 `didPushNext` 和 `didPopNext` 驱动该状态，避免让每个弹窗单独操作原生 WebView。

### Android 组件

#### ActivityWebViewHost

由 `MainActivity` 持有，每个时刻最多管理 1 个原生 WebView。职责包括：

- 在 Activity 根 `FrameLayout` 中创建和移除 WebView。
- 根据 FlutterView 在窗口中的实际位置映射占位矩形。
- 设置 WebView 的 `FrameLayout.LayoutParams`，不使用硬编码状态栏或导航栏偏移。
- 配置 JavaScript、DOM Storage、Cookie、媒体播放、User-Agent 和硬件加速。
- 接入现有原生代理、资源缓存、Gadget Bypass、帧率及截图管理器。
- 接收 Flutter 命令，并通过 EventChannel 回传状态事件。
- 执行确定性的 WebView 销毁流程。

#### NativeGameWebViewConfigurator

集中配置新实例，保证每次重建使用一致设置。该组件只负责 WebView 配置，不持有 Flutter 业务状态。

#### NativeGameWebViewClient

负责：

- 页面开始、完成和网络错误事件。
- 请求拦截、资源缓存和 Gadget Bypass。
- API 捕获桥接。
- `onRenderProcessGone` 处理。
- 将事件连同当前 `generationId` 回传 Flutter。

## 坐标与层级

Flutter 上报占位区域相对 FlutterView 的逻辑坐标、设备像素比和可见性。Android 读取 FlutterView 在窗口中的实际位置，再计算 WebView 的窗口矩形。该方式统一处理状态栏、导航栏、横竖屏、折叠状态及多窗口偏移。

原生 WebView 位于 FlutterView 上方，但严格裁剪在游戏矩形内。顶部资源栏、常驻工具栏和侧边功能区保持可见且可交互。

Flutter 路由或弹窗需要覆盖游戏区域时，先隐藏原生 WebView，再展示覆盖层；覆盖层关闭后重新计算矩形并恢复。实验模式首版不支持让 Flutter 半透明内容直接叠加在原生 WebView 上。

矩形宽度或高度为 0、超出 FlutterView 有效区域，或坐标数据非法时，Android 隐藏 WebView 并记录诊断事件，不使用上一次矩形继续显示。

## 数据流

Flutter 继续作为业务状态的唯一来源。舰队、任务、战斗、设置和工具栏状态不在 Kotlin 侧复制。

```text
Flutter 业务控制器
        │ GameBrowserPort
        ▼
NativeActivityGameBrowserPort
        │ MethodChannel
        ▼
ActivityWebViewHost ──► NativeGameWebView
        │
        │ EventChannel
        ▼
Flutter 页面状态、API 捕获与诊断
```

每个 WebView 实例使用单调递增的 `generationId`。所有加载、JavaScript、截图和 API 捕获回调都携带该值。Flutter 与 Android 两侧只接受当前实例的事件，旧实例晚到的回调直接丢弃。

原生宿主不得解析或存储舰队业务数据。API 捕获结果继续进入现有 Dart 解析与状态归约流程。

## 生命周期

### 前后台

- 进入后台时保持与现有模式一致的策略：按用户与系统状态静音，不主动销毁或刷新 WebView。
- 恢复前台时重新同步矩形、音频、窗口尺寸和帧率设置。
- 首版不调用会改变实验变量的自动清缓存或自动渲染器切换。

### 窗口变化

横竖屏、折叠/展开、多窗口和侧栏宽度变化只触发布局更新，不重新加载游戏页面。

### 确定性销毁

销毁顺序固定为：

1. 使当前 `generationId` 失效。
2. 隐藏 WebView 并停止接收新命令。
3. 停止加载并断开截图、音频、帧率、代理和资源拦截桥接。
4. 移除 JavaScript 接口及 WebViewClient/WebChromeClient。
5. 加载空白页并清空历史记录。
6. 从父 View 移除，调用 `removeAllViews()` 和 `destroy()`。
7. 清除所有强引用。

Flutter 页面退出、切换宿主和 `MainActivity.onDestroy` 都必须走同一销毁入口。

## 内存压力与失败处理

### 内存压力

实验首版收到 `onTrimMemory` 或 Flutter 内存压力回调时：

- 记录压力级别、当前宿主、渲染器和详细内存分类。
- 立即刷新一条性能采样。
- 不自动清缓存、不切换 Canvas、不重载游戏。

这样可以保留可比较的实验数据。后续自动恢复策略另行设计。

### 创建或配置失败

若原生 WebView 创建、坐标绑定或关键配置失败：

- 销毁所有半初始化对象。
- 记录稳定错误码和失败阶段。
- 向用户显示实验模式不可用提示。
- 将持久化模式切回标准模式并重新创建现有宿主。

### 渲染进程退出

`NativeGameWebViewClient.onRenderProcessGone` 必须消费该事件：

- 立即使当前实例失效并销毁。
- 记录退出是否由崩溃引起及渲染进程优先级信息。
- 显示「游戏渲染进程已退出」提示。
- 提供重新加载按钮；不自动连续重试。

### 启动循环保护

启动实验模式时写入「启动中」标记，进入 `ready` 后清除。若应用连续 2 次启动都发现上次实验模式未达到 `ready`：

- 自动切回标准模式。
- 清除实验模式启动标记。
- 保留诊断记录并向用户说明已安全回退。

## 诊断与可观测性

诊断导出增加以下信息：

- 当前宿主：`platformView` 或 `activityDirect`。
- 当前游戏渲染器：`webgl` 或 `canvas`。
- 当前 `generationId`。
- WebView 创建、可见、隐藏、就绪和销毁事件。
- `onRenderProcessGone` 的退出详情。
- `onTrimMemory` 级别。
- Java Heap、Native Heap、Graphics、Private Other、PSS 和系统可用内存。
- 当前游戏矩形及窗口尺寸，不记录页面内容。

诊断不得包含登录密钥、Cookie、完整 API 正文或截图。

## 测试策略

### Dart 自动化测试

- 第四种模式的编码、解码、保存和旧设置兼容。
- 非 Android 平台不能选择实验模式。
- 实验模式不创建 `WebViewWidget`。
- `NativeGameSurfaceSlot` 在矩形或可见性变化时正确上报。
- 相同矩形不重复上报，连续变化只保留最新值。
- 路由覆盖时隐藏，恢复后重新显示。
- `generationId` 能过滤旧实例事件。
- 模式切换顺序、失败回退和现有 3 种模式行为不回归。

### Kotlin 自动化测试

- FlutterView 相对坐标到窗口坐标的映射。
- 非法、越界和零尺寸矩形会隐藏 WebView。
- 宿主状态机保证最多存在 1 个 WebView。
- 销毁流程可重复调用且不会残留引用。
- 创建失败能完整清理半初始化状态。
- 渲染进程退出被消费并产生可恢复状态。
- 连续 2 次未就绪会触发启动循环回退。

### 真实设备功能验证

至少验证：

- 登录、进入母港、出击、刷新和网页后退。
- 资源缓存、代理和 Gadget Bypass。
- API 捕获及顶部资源栏更新。
- 游戏静音、截图和帧率设置。
- 侧栏开关、横竖屏、折叠/展开和多窗口。
- Flutter 弹窗出现时 WebView 隐藏，关闭后恢复。
- 反复切换现有模式与实验模式不会残留 WebView。

## 性能实验与成功标准

在同一台 SM-F9460 上，以标准模式和原生直连实验模式分别执行至少 3 轮相同的 60 分钟场景。每轮使用相同的游戏阶段、侧栏状态、帧率、缓存和网络设置。

记录：

- PSS 平均值、中位数和峰值。
- Java Heap、Native Heap、Graphics 和 Private Other。
- `lowMemory` 次数。
- 超过 16 ms、33 ms 和 100 ms 的帧数。
- WebView 渲染进程退出次数。
- 应用进程非正常重启次数及 Android 退出原因。

实验模式只有满足以下全部条件，才进入正式推广评估：

- 登录、游戏、抓包、缓存、音频和截图没有关键回归。
- PSS 中位数至少下降 15%，或稳定减少至少 150 MB。
- PSS 峰值尽量保持在 900 MB 以下。
- 3 轮对照测试均没有应用进程闪退。
- 额外的 2 小时连续运行测试没有非正常重启。

若内存没有明显下降，则保留或移除实验入口，不继续大规模原生化；后续排查重点转向 WebGL、Chromium Graphics、Private Other 和游戏资源生命周期。

## 发布与回退

- 新模式标记为实验功能，不设为默认值。
- 升级用户继续使用原有模式，不自动迁移。
- 实验模式只在 Android 显示。
- 诊断页面明确显示当前宿主与渲染器。
- 出现严重兼容问题时，可以隐藏实验入口；已保存该模式的用户启动时自动回退标准模式。

## 影响范围

预计涉及：

- Flutter 渲染模式模型、设置页和模式控制器。
- 游戏页面宿主选择与 `GameBrowserPort` 实现。
- 游戏区域布局和路由可见性协调。
- Android `MainActivity` 根布局与 WebView 宿主。
- 现有代理、缓存、Gadget Bypass、API 捕获、截图、音频和帧率桥接。
- 诊断事件、运行时内存采样和导出格式。
- Dart、Widget、Kotlin 及真实设备验证。

现有工作区中的其他未提交功能不属于本设计范围，实现和提交时必须保持隔离。
