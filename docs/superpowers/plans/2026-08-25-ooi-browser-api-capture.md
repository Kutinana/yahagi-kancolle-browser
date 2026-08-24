# OOI 浏览器模式 API 抓取实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 让 OOI 模式 1 的 `https://ooi.moe/kcsapi/*` 请求安全进入 Yahagi 现有抓取与业务状态链。

**架构：** 只在 Android `CaptureOriginPolicy` 中精确允许 `https://ooi.moe`，使 document-start 脚本注入、WebMessage listener 与回传校验使用一致的 Origin 白名单。现有抓取脚本、业务解析器、游戏布局和资源缓存保持不变。

**技术栈：** Kotlin、AndroidX WebKit、JUnit、Flutter、ADB/CDP。

---

## 文件结构

- 修改 `android/app/src/test/kotlin/app/yahagi/kancollebrowser/capture/CaptureOriginPolicyTest.kt`：定义 OOI 精确 Origin 的允许与拒绝回归行为。
- 修改 `android/app/src/main/kotlin/app/yahagi/kancollebrowser/capture/CaptureOriginPolicy.kt`：增加 OOI 精确 Host 和 Origin rule。

### 任务 1：用失败测试定义 OOI 精确 Origin

**文件：**
- 修改：`android/app/src/test/kotlin/app/yahagi/kancollebrowser/capture/CaptureOriginPolicyTest.kt`

- [ ] **步骤 1：把现有 OOI 拒绝测试改为精确允许测试**

```kotlin
@Test
fun allowsOnlyExactOoiHttpsOrigin() {
    assertTrue(policy.isAllowed("https://ooi.moe"))
    assertTrue(policy.allowedOriginRules.contains("https://ooi.moe"))
    assertFalse(policy.isAllowed("http://ooi.moe"))
    assertFalse(policy.isAllowed("https://sub.ooi.moe"))
    assertFalse(policy.isAllowed("https://ooi.moe.example.org"))
    assertFalse(policy.isAllowed("https://ooi.moe:8443"))
}
```

- [ ] **步骤 2：运行测试验证红灯**

运行：

```powershell
cd android
.\gradlew.bat :app:testDebugUnitTest --tests app.yahagi.kancollebrowser.capture.CaptureOriginPolicyTest
```

预期：`allowsOnlyExactOoiHttpsOrigin` 因 `https://ooi.moe` 尚未允许而失败。

- [ ] **步骤 3：提交测试红灯**

```powershell
git add android/app/src/test/kotlin/app/yahagi/kancollebrowser/capture/CaptureOriginPolicyTest.kt
git commit -m "test(抓取): 定义 OOI 精确 Origin 行为"
```

### 任务 2：最小实现 OOI 抓取白名单

**文件：**
- 修改：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/capture/CaptureOriginPolicy.kt`
- 测试：`android/app/src/test/kotlin/app/yahagi/kancollebrowser/capture/CaptureOriginPolicyTest.kt`

- [ ] **步骤 1：增加精确 Host 集合和 Origin rule**

```kotlin
private val allowedExactHosts = setOf(
    "ooi.moe",
)

val allowedOriginRules: Set<String> = setOf(
    "https://*.dmm.com",
    "https://*.dmm.co.jp",
    "https://*.kancolle-server.com",
    "https://ooi.moe",
)
```

- [ ] **步骤 2：在现有安全校验后允许精确 Host**

```kotlin
val host = uri.host?.lowercase(Locale.ROOT) ?: return false
if (host in allowedExactHosts) {
    return true
}
return allowedRoots.any { root ->
    host == root || host.endsWith(".$root")
}
```

- [ ] **步骤 3：运行 Android Origin 与缓存回归测试验证绿灯**

```powershell
cd android
.\gradlew.bat :app:testDebugUnitTest --tests app.yahagi.kancollebrowser.capture.CaptureOriginPolicyTest --tests app.yahagi.kancollebrowser.browser.GameResourceCacheRulesTest
```

预期：`BUILD SUCCESSFUL`，OOI 精确 Origin 通过，缓存仍拒绝 OOI。

- [ ] **步骤 4：运行 Flutter 导航与连接器缓存测试**

```powershell
flutter test test/safe_page_address_test.dart test/game_navigation_policy_test.dart test/game_connector_cache_compatibility_test.dart
```

预期：全部测试通过。

- [ ] **步骤 5：提交生产代码**

```powershell
git add android/app/src/main/kotlin/app/yahagi/kancollebrowser/capture/CaptureOriginPolicy.kt
git commit -m "fix(抓取): 支持 OOI 模式 1 API Origin"
```

### 任务 3：Debug 构建与手机实机验证

**文件：**
- 不新增生产文件。

- [ ] **步骤 1：构建 Debug APK**

```powershell
flutter build apk --debug
```

预期：构建成功并生成 `build/app/outputs/flutter-apk/app-debug.apk`。

- [ ] **步骤 2：保留应用数据更新安装**

```powershell
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

预期：`Success`。不卸载、不清除应用数据。

- [ ] **步骤 3：在模式 1 会话检查抓取链**

通过只读 ADB/CDP 检查：

```text
顶层 Origin = https://ooi.moe
游戏 iframe Origin = https://ooi.moe
__yahagiMobileNativeCaptureInstalled = true
/kcsapi/* 请求返回 2xx
Yahagi 状态由 CapturedApiEvent 更新
```

检查过程中不得读取或输出账号、Cookie、token、查询参数或完整响应正文。

- [ ] **步骤 4：回归模式边界**

确认此次 diff 只涉及抓取 Origin 策略及其测试；模式 1、模式 4 和 Yahagi/DMM 的布局代码与资源缓存规则没有修改。
