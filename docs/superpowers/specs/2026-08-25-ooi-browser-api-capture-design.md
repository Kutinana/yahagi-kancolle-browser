# OOI 浏览器模式 API 抓取设计

## 目标

让 OOI「在浏览器中运行」（模式 1）页面中的 `/kcsapi/*` 请求进入 Yahagi 现有 `CapturedApiEvent` 数据流，同时不改变 OOI 模式 4、Yahagi/DMM 连接、游戏画面布局和资源缓存规则。

## 已验证现状

- OOI 登录页和游戏页运行在同一个游戏 WebView 中，不需要新增账号密码提交接口或 Cookie Bridge。
- 模式 1 可以进入 `https://ooi.moe/kancolle`，其同源游戏 iframe 会请求 `https://ooi.moe/kcsapi/*`。
- `GameCaptureBridge` 使用同一组 Origin 规则控制 document-start 脚本注入和 WebMessage listener，并在消息到达时再次验证 `sourceOrigin`。
- 当前 `CaptureOriginPolicy` 仅允许 DMM 与 `kancolle-server.com`，所以 OOI 页面不会安装抓取脚本。

## 设计

在 `CaptureOriginPolicy` 中增加独立的精确 Host `ooi.moe`：

- `allowedOriginRules` 增加 `https://ooi.moe`，供 document-start 注入和 WebMessage listener 使用。
- `isAllowed()` 在现有 HTTPS、默认端口、无 userInfo/query/fragment 校验之后，允许精确 Host `ooi.moe`。
- 不把 OOI 放入支持子域名的 `allowedRoots`，因此不允许 `*.ooi.moe`。

抓取脚本、消息格式、`CapturedApiEvent`、解析器和业务 reducer 保持不变。现有脚本按 `/kcsapi/` pathname 判断目标，不需要 OOI 专用分支。

## 安全边界

只允许 `https://ooi.moe`。继续拒绝 HTTP、OOI 子域名、相似域名、非默认端口、userinfo、query 和 fragment Origin。不得记录密码、Cookie、`api_token`、`api_starttime` 或完整 API 正文。

OOI 仍不进入 Yahagi 官方游戏资源缓存；此次修改不涉及任何画面缩放、复原按钮或模式识别代码。

## 测试与验收

先修改 `CaptureOriginPolicyTest`，让以下期望在生产代码修改前失败：

- 精确允许 `https://ooi.moe`。
- Origin rules 包含 `https://ooi.moe`。
- 拒绝 HTTP、子域名、相似域名和非默认端口。
- 原有 DMM 与舰 C 官方 Origin 继续允许，通配符 `*` 继续禁止。

完成最小实现后运行 Android 相关单元测试、Flutter 导航与缓存回归测试及 Debug 构建。最后通过 Wi-Fi ADB 在用户已登录的模式 1 会话中确认：OOI 顶层或同源 iframe 安装抓取脚本、`/kcsapi/*` 返回成功、Yahagi 收到 `CapturedApiEvent`，并抽查母港、舰队、远征、入渠和战斗数据。模式 4 与 Yahagi/DMM 分别回归。
