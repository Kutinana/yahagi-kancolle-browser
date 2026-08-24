# OOI 临时登录会话设计

## 目标

Yahagi/DMM 连接继续保留现有 Cookie 自动登录；OOI 连接每次应用冷启动或每次从其他连接器切入时都回到 `https://ooi.moe/`，由用户重新填写账号并选择 OOI 模式。同一次 OOI 使用过程中的刷新、游戏 iframe 重载、WebView 恢复和应用前后台切换继续保留登录。

连接器只改变登录入口。航海日志、游戏状态、任务、舰队、远征、入渠、战斗、设置与本地资源缓存继续共用现有数据和业务链，不按连接器拆库或清空。

## 方案选择

采用 Android 平台级“精确 Origin Cookie 清理”通道。Dart 在需要开始新的 OOI 登录周期时请求清理 `https://ooi.moe`，原生层通过 `CookieManager` 仅使该 Origin 当前存在的 Cookie 过期并刷新 Cookie Store。

不采用 `removeAllCookies()`，因为它会破坏 Yahagi/DMM 自动登录；不采用页面 JavaScript 清理，因为它无法可靠删除 HttpOnly Cookie，也可能在 OOI 自动进入游戏后执行过晚；不硬编码账号、密码或 Cookie 值。

## 生命周期

`GameBrowserController` 记录本次应用进程的初始连接器进入是否已准备：

- 冷启动且初始连接器为 OOI：首次导航前清理 OOI Cookie，然后加载 OOI 根页面。
- 冷启动且初始连接器为 Yahagi：不清理任何 Cookie。
- Yahagi 切换到 OOI：清理 OOI Cookie，然后加载 OOI 根页面。
- OOI 切到 Yahagi再切回 OOI：再次清理 OOI Cookie，然后加载 OOI 根页面。
- OOI 页面刷新、游戏 iframe 刷新、复原尺寸、WebView surface 恢复或应用前后台切换：不清理 OOI Cookie。

控制器对象在同一应用进程的 WebView surface 重建之间保持，因此初始清理只执行一次；冷启动创建新控制器后会重新执行。

## 平台安全与隐私

平台通道只接受规范的 `https://ooi.moe` Origin：HTTPS、默认端口、精确 Host、无 userInfo、path、query 或 fragment。其他 Origin 一律拒绝。

原生层只从 Cookie header 中提取合法 Cookie 名称，并为每个名称设置过期 Cookie；不向 Dart 返回名称或值，不输出日志，不写入诊断。清理同时覆盖 host-only 和 `Domain=ooi.moe`、`Path=/` 的 Cookie。Cookie header 为空时按成功处理。

## 组件

- 新增 Dart `OriginCookieManagerPort`，负责平台通道调用与输入约束。
- 新增 Android `OriginCookieManagerChannel`，负责精确 Origin 验证和定向 Cookie 过期。
- `GameBrowserPort` 增加定向 Cookie 清理能力，Flutter WebView 与 Native Activity WebView 均委托同一平台端口。
- `GameBrowserController` 增加冷启动准备方法，并在切换进入 OOI 时先清理再导航。
- 两套 WebView 启动序列在第一次真实导航前调用控制器的冷启动准备方法。

## 测试与验收

先用失败测试覆盖：冷启动 OOI 清理一次、同进程 surface 重建不重复清理、切换进入 OOI每次清理、切换 Yahagi 不清理、刷新不清理、清理失败时不导航。平台测试覆盖精确 Origin、Cookie 名称清洗、空 Cookie、host-only/domain 两种过期写入和不泄露值。

回归测试必须确认连接器切换不改变本地缓存模式，现有游戏状态与航海日志存储没有清理调用。完成后构建并保留数据更新 Debug APK；实机验证 OOI 当前刷新仍保持登录，而切换到 Yahagi再切回 OOI会显示登录首页，重新登录后 API 抓取继续工作。
