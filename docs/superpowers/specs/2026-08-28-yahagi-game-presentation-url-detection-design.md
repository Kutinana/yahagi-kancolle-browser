# Yahagi 官方登录与游戏画面识别修复设计

日期：2026-08-28
目标分支：`master`

## 背景

1.0.4 在游戏画面对齐脚本中加入了登录控件检测。该检测遍历整个页面的链接，只要任意链接包含 `/login` 或 `accounts.dmm.`，就拒绝游戏展示模式。正常 DMM 游戏外壳的全局导航也包含这些账号链接，因此四种渲染模式都会撤销固定画布样式和缩放，留下 DMM 顶栏并裁切游戏底部。

四种渲染模式虽然使用不同的 WebView 宿主、合成方式或 Canvas/WebGL 渲染器，但共用同一份页面对齐脚本，因此本次修复只处理共享的 Yahagi 官方页面识别与展示状态，不按渲染模式分别打补丁。

## 范围

本次修改仅覆盖 Yahagi 官方 DMM 登录与游戏链路：

- 精确区分 DMM 账号页、舰 C 游戏候选页和其他网页。
- 将游戏展示结果从布尔值改为 `game`、`web`、`pending` 三态。
- 游戏候选页等待游戏容器出现时不释放既有固定画布状态。
- 删除基于页面全部链接的登录检测。
- 删除导航开始时无条件释放固定画布的行为。
- 增加覆盖 URL 分类、状态解析、延迟游戏容器和四种模式共享路径的回归测试。

以下内容明确不在本次修改范围内：

- OOI 登录页、模式 1/3/4 选择、凭据流程和页面导航。
- OOI `/kancolle` 与 `iframe#externalswf` 的专用适配行为。
- KCSAPI 捕获、资源缓存、代理、帧率和游戏业务数据处理。
- 自动缩放比例公式和 1200×720 固定画布尺寸。

## URL 分类

顶层页面分为三类：

### `account`

- `https://accounts.dmm.com/...`
- `https://accounts.dmm.co.jp/...`

账号页始终使用普通网页展示，并释放固定画布缩放。

### `gameCandidate`

- DMM 官方舰 C gadget 入口，路径精确包含 `/netgame/social/-/gadgets/=/app_id=854854/`。
- `https://osapi.dmm.com/...`。
- `https://kancolle-server.com/...` 或任意 `https://*.kancolle-server.com/...`。

不再使用宽泛的 `pathname.includes('kancolle')`。因此 `https://www.dmm.com/netgame/feature/kancolle.html` 等介绍页面不会被识别为游戏候选页，其他 `app_id` 也不会命中。

### `other`

除上述地址外的页面，包括 DMM 普通页面和外部认证提供方页面。此类页面使用普通网页展示并释放固定画布缩放。

OOI 判断继续位于 Yahagi URL 分类之前，保持现有分支和行为。

## DOM 确认与展示状态

URL 只决定页面是否可能承载游戏，DOM 决定游戏是否已经可用：

| URL 类型 | DOM 条件 | 展示状态 | 动作 |
|---|---|---|---|
| `account` | 任意 | `web` | 清除游戏样式，释放固定画布 |
| `other` | 任意 | `web` | 清除游戏样式，释放固定画布 |
| `gameCandidate` | 可见的 `#game_frame`、`#game-container` 或 1200×720 Canvas | `game` | 应用游戏样式，绑定固定画布 |
| `gameCandidate` | 游戏容器尚未出现 | `pending` | 保持当前平台缩放状态，等待 DOM 变化 |
| `gameCandidate` | 可见的阻塞页面弹窗 | `web` | 暂时让出游戏展示，允许用户交互 |

游戏容器需要连接在当前文档中，并具有非零可见尺寸；隐藏模板节点不算游戏画面。登录判断不再检查普通链接。账号域名是登录页的主判据，现有阻塞弹窗判断继续作为运行时交互保护。

## 状态传播与平台动作

页面脚本返回并通知字符串状态：

- `game`：Flutter PlatformView 或原生 Activity 绑定 1200×720 固定画布。
- `web`：清理游戏专用 CSS 和事件监听，并释放固定画布。
- `pending`：不执行绑定或释放；MutationObserver 在 DOM 改变后再次判断。

Flutter 侧使用枚举解析脚本返回值，不再把 `null`、未知值或加载中状态自动当作 `false`。原生 JavaScript 桥记录 `pending`，但不调用缩放动作，使后续从 `pending` 转为 `game` 时一定重新绑定。

PlatformView 和原生 Activity 的 `onPageStarted` 不再无条件释放固定画布。新文档完成或 DOM 状态变化后，由明确的 `game` 或 `web` 状态决定平台动作。导航 epoch/generation 校验继续阻止旧页面消息影响新页面。

## OOI 不变约束

- `https://ooi.moe/`、`/browser`、`/poi`、`/connector` 原样显示。
- Yahagi 不选择、隐藏、禁用或提交 OOI 登录字段和模式选项。
- `ooi.moe/kancolle` 且存在 `iframe#externalswf` 时继续使用现有 OOI CSS 缩放。
- OOI 游戏展示继续不绑定 DMM 原生固定画布。
- 现有 OOI 连接器、Cookie 隔离、导航白名单和验收测试不得改变。

## 测试设计

先添加失败测试，再实现生产代码：

1. DMM 正常游戏页面包含账号链接和游戏容器时，结果必须为 `game`。
2. `accounts.dmm.com` 和 `accounts.dmm.co.jp` 必须为 `web`。
3. `feature/kancolle.html` 必须为 `web`。
4. `app_id=854854` 尚无游戏容器时必须为 `pending`，且不调用释放缩放。
5. 游戏容器随后出现时必须从 `pending` 转为 `game`。
6. 游戏页面包含普通账号链接时不得退出 `game`。
7. 可见阻塞弹窗打开时为 `web`，关闭后恢复 `game`。
8. OOI 登录页和模式选择保持零注入；OOI `/kancolle` 专用适配保持现有行为。
9. 轻量、均衡、Canvas 兼容和原生独立模式都使用同一状态结果。

自动验证包括相关 Flutter 单测、全量 `flutter test`、`flutter analyze`、相关 Android JVM 单测和 Debug APK 构建。

## 真机验证

通过已连接的无线 ADB 设备执行多轮验证：

1. 清理或隔离测试会话后打开 Yahagi 官方入口，确认登录页完整可操作。
2. 登录后确认 DMM 顶栏消失、游戏画面保持 1200×720 比例且上下不裁切。
3. 依次切换四种渲染模式并重新进入或刷新游戏，确认结果一致。
4. 前后台切换、旋转或窗口尺寸变化、手动适应屏幕、页面刷新后再次确认。
5. 切换至 OOI，确认登录页、模式 1/3/4 和现有专用适配没有变化。
6. 采集脱敏状态日志，至少记录 URL 分类、展示状态、游戏容器类型和最终缩放百分比，不记录 query、fragment、Cookie 或凭据。

## 成功标准

- 正常 DMM 游戏页不再因全局账号链接被判为登录页。
- 四种渲染模式下均无 DMM 顶栏挤占、底部裁切或错误缩放释放。
- DMM 登录页、普通网页和阻塞弹窗仍可正常交互。
- OOI 的登录和游戏路径行为与修改前一致。
- 自动测试、静态检查、Android 测试和真机回归全部通过，或明确记录与本次修改无关的既有问题。
