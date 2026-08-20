# Android 游戏触摸输入兼容设计

## 背景

舰队 Collection 的游戏客户端基于 PixiJS。Android WebView 可以把短触摸兼容为鼠标点击，因此普通点击通常可用；但长按会进入 WebView 自身的手势识别流程，游戏无法稳定获得完整的按下、保持、抬起序列。结果是长按工厂无法呼出明石改修入口。

GotoBrowser 没有在 WebView 外层模拟长按。它拦截 `kcs2/js/main.js`，将 PixiJS 输入事件映射从鼠标事件改成原生触摸事件，并追加一段 InteractionManager 兼容补丁。Yahagi 将移植这套输入策略。

## 目标

- Android 游戏画面默认使用 `touchstart`、`touchmove`、`touchend` 处理触摸输入。
- 恢复长按工厂进入明石改修的能力。
- 保持普通点击、拖动和触摸悬停反馈可用。
- 与现有帧率 ticker 补丁共用一次 `main.js` 拦截和下载。
- 游戏脚本结构变化时安全回退，不因触摸补丁失败导致白屏。

## 非目标

- 不在 Flutter 或 Android View 外层模拟点击、长按或坐标变换。
- 不增加用户可见的输入模式开关。
- 不修改非 Android 平台。
- 不复制 GotoBrowser 与触摸无关的静音、字幕或语言补丁。

## 方案

### 主脚本事件映射

扩展现有 `GameMainScriptPatcher`，识别 GotoBrowser 使用的 PixiJS 事件映射片段，把 `down`、`move`、`up` 分别改为：

```javascript
down: void 0 !== document.ontouchstart ? 'touchstart' : 'mousedown'
move: void 0 !== document.ontouchstart ? 'touchmove' : 'mousemove'
up: void 0 !== document.ontouchstart ? 'touchend' : 'mouseup'
over: 'touchover'
out: 'touchout'
```

匹配规则与 GotoBrowser 当前实现保持等价，但封装为可独立测试的 Kotlin 补丁函数。补丁必须幂等；已经包含触摸映射时不得重复追加内容。

### PixiJS InteractionManager 补丁

把 GotoBrowser 的 `touch_event_patch.js` 作为 Android 资源加入项目，并在事件映射成功后追加到 `main.js`。该脚本负责：

- 在触摸按下和抬起时刷新 PixiJS 命中状态。
- 以触摸事件驱动 InteractionManager 更新。
- 用 `touchover` 和 `touchout` 保留原游戏依赖的悬停反馈。

移植内容保持 GotoBrowser 行为，不重新设计手势算法。仅增加一个全局安装标记，保证重复补丁不会重复包装原型方法。

### 拦截管线

`GadgetBypassWebViewClient` 继续作为 `main.js` 的唯一拦截点。处理顺序为：

1. 从资源缓存、绕行端点或网络取得原始脚本。
2. 应用触摸输入补丁。
3. 按当前设置应用帧率 ticker 补丁。
4. 返回合并后的 JavaScript 响应。

即使帧率模式为稳定 30 FPS，仍需拦截并应用触摸补丁。触摸补丁不依赖帧率设置。

### 失败处理

- 无法下载 `main.js`：返回 `null`，让 WebView 使用默认网络加载路径。
- 找不到触摸事件映射：返回未修改的脚本并记录警告，不追加 InteractionManager 补丁。
- 帧率模式不需要修改：只应用触摸补丁。
- 同一脚本再次经过补丁：返回原结果，不重复安装。

## 测试

Android JVM 测试覆盖以下行为：

- 只识别可信的舰 C `kcs2/js/main.js` URL。
- 将鼠标事件映射改为 GotoBrowser 的触摸事件映射。
- 成功映射后追加 InteractionManager 补丁。
- 补丁重复执行时结果不变。
- 找不到事件映射时原脚本保持不变。
- 触摸补丁与两种帧率 ticker 模式可以同时生效。
- 稳定 30 FPS 模式下仍会请求并返回触摸补丁后的脚本。
- 下载或补丁失败时保留默认 WebView 加载回退。

自动化测试无法直接证明真实游戏中的长按计时。最终验收还需在 Android 设备上进入母港，长按工厂按钮，确认明石改修入口出现，并检查普通点击和拖动没有回归。

## 验收标准

- Android 设备上长按工厂能够稳定进入明石改修。
- 母港及各游戏页面的普通点击和拖动保持正常。
- 自动、稳定 30 FPS、高刷新率 3 种帧率模式均启用触摸补丁。
- 脚本匹配失败不会阻断游戏加载。
