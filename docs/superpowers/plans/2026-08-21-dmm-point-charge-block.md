# DMM PT 充值阻断实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 保留 DMM 充值按钮外观但使点击无动作，同时允许玩家用账号既有 PT 完成舰 C 道具结算。

**架构：** 兼容 WebView 在页面捕获阶段吞掉充值按钮点击；Dart 导航策略与 Android 原生 WebView 客户端分别对 `point.dmm.com` 和 `point.dmm.co.jp` 做静默拒绝，形成纵深防护。普通 DMM 游戏购买确认与结算域名继续沿用现有放行规则。

**技术栈：** Flutter、Dart、`webview_flutter`、Android WebView、Kotlin、Flutter Test、JUnit 4

---

## 文件结构

- 修改 `lib/src/browser/game_navigation_policy.dart`：识别并静默拒绝 DMM PT 充值主机。
- 修改 `lib/src/game_webview.dart`：在导航回调中优先执行静默阻断，不写入外部跳转错误。
- 修改 `test/game_navigation_policy_test.dart`：覆盖充值主机、伪装域名和普通结算地址。
- 修改 `lib/src/browser/game_page_alignment_script.dart`：安装幂等的充值按钮捕获监听器。
- 修改 `test/game_page_alignment_script_test.dart`：验证按钮语义选择器和事件吞掉逻辑。
- 修改 `android/app/src/main/kotlin/app/yahagi/kancollebrowser/nativewebview/NativeGameWebViewClient.kt`：原生模式静默拒绝充值主机。
- 修改 `android/app/src/test/kotlin/app/yahagi/kancollebrowser/nativewebview/NativeGameWebViewClientTest.kt`：覆盖原生模式安全边界。

### 任务 1：Dart 导航策略静默阻断充值域名

**文件：**

- 修改：`lib/src/browser/game_navigation_policy.dart`
- 修改：`lib/src/game_webview.dart:1237-1248`
- 测试：`test/game_navigation_policy_test.dart`

- [ ] **步骤 1：编写失败的策略测试**

在 `test/game_navigation_policy_test.dart` 添加：

```dart
test('silently blocks DMM point charging without blocking game checkout', () {
  final policy = GameNavigationPolicy();

  expect(
    policy.shouldSilentlyBlock(
      Uri.parse('https://point.dmm.com/choice/pay?basket_service_type=freegame'),
    ),
    isTrue,
  );
  expect(
    policy.shouldSilentlyBlock(Uri.parse('https://point.dmm.co.jp/choice/pay')),
    isTrue,
  );
  expect(
    policy.shouldSilentlyBlock(
      Uri.parse('https://point.dmm.com.attacker.example/choice/pay'),
    ),
    isFalse,
  );
  expect(
    policy.canNavigate(
      Uri.parse('https://artemis.games.dmm.com/member/pc/purchase'),
    ),
    isTrue,
  );
});
```

- [ ] **步骤 2：运行测试并确认红灯**

运行：

```powershell
flutter test --no-test-assets test/game_navigation_policy_test.dart
```

预期：FAIL，提示 `GameNavigationPolicy` 没有 `shouldSilentlyBlock`。

- [ ] **步骤 3：实现最小策略与静默导航分支**

在 `GameNavigationPolicy` 中增加：

```dart
static const Set<String> _blockedPointChargeHosts = <String>{
  'point.dmm.com',
  'point.dmm.co.jp',
};

bool shouldSilentlyBlock(Uri uri) =>
    uri.scheme == 'https' &&
    uri.userInfo.isEmpty &&
    _blockedPointChargeHosts.contains(uri.host.toLowerCase());
```

并让 `canNavigate` 在该判断为真时返回 `false`。在 `_onNavigationRequest` 中先检查 `shouldSilentlyBlock` 并直接返回 `NavigationDecision.prevent`，不要调用 `onBlockedNavigation`。

- [ ] **步骤 4：运行策略测试并确认绿灯**

运行：

```powershell
flutter test --no-test-assets test/game_navigation_policy_test.dart
```

预期：全部通过。

### 任务 2：充值按钮保持可见但点击无动作

**文件：**

- 修改：`lib/src/browser/game_page_alignment_script.dart`
- 测试：`test/game_page_alignment_script_test.dart`

- [ ] **步骤 1：编写失败的脚本契约测试**

在 `test/game_page_alignment_script_test.dart` 添加：

```dart
test('keeps point charge controls visible but consumes their clicks', () {
  expect(
    gamePageAlignmentScript,
    contains('[data-gtm-action-detail="link_charge-points"]'),
  );
  expect(gamePageAlignmentScript, contains("addEventListener('click'"));
  expect(gamePageAlignmentScript, contains('preventDefault()'));
  expect(gamePageAlignmentScript, contains('stopImmediatePropagation()'));
  expect(gamePageAlignmentScript, isNot(contains('style.display')));
});
```

- [ ] **步骤 2：运行测试并确认红灯**

运行：

```powershell
flutter test --no-test-assets test/game_page_alignment_script_test.dart
```

预期：FAIL，脚本尚未包含充值控件选择器。

- [ ] **步骤 3：安装幂等的捕获监听器**

在呈现脚本中加入：

```javascript
const pointChargeSelector =
  '[data-gtm-action-detail="link_charge-points"]';

if (!window.__yahagiMobilePointChargeBlocker) {
  window.__yahagiMobilePointChargeBlocker = (event) => {
    const target = event.target;
    if (!(target instanceof Element) || !target.closest(pointChargeSelector)) {
      return;
    }
    event.preventDefault();
    event.stopImmediatePropagation();
  };
  document.addEventListener(
    'click',
    window.__yahagiMobilePointChargeBlocker,
    true,
  );
}
```

不修改充值按钮样式、文本或可见性。

- [ ] **步骤 4：运行脚本测试并确认绿灯**

运行：

```powershell
flutter test --no-test-assets test/game_page_alignment_script_test.dart
```

预期：全部通过。

### 任务 3：Android 原生 WebView 同步安全边界

**文件：**

- 修改：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/nativewebview/NativeGameWebViewClient.kt`
- 测试：`android/app/src/test/kotlin/app/yahagi/kancollebrowser/nativewebview/NativeGameWebViewClientTest.kt`

- [ ] **步骤 1：编写失败的原生策略测试**

在 `NativeGameWebViewClientTest` 添加：

```kotlin
@Test
fun silentlyBlocksDmmPointChargingButAllowsGameCheckout() {
    val events = mutableListOf<String>()
    val delegate = delegate(events)

    assertTrue(delegate.shouldOverrideUrlLoading("https://point.dmm.com/choice/pay"))
    assertTrue(delegate.shouldOverrideUrlLoading("https://point.dmm.co.jp/choice/pay?x=1"))
    assertFalse(delegate.shouldOverrideUrlLoading("https://artemis.games.dmm.com/member/pc/purchase"))
    assertFalse(delegate.shouldOverrideUrlLoading("https://point.dmm.com.attacker.example/choice/pay"))
    assertTrue(events.isEmpty())
}
```

- [ ] **步骤 2：运行测试并确认红灯**

运行：

```powershell
Set-Location android
./gradlew.bat testDebugUnitTest --tests "app.yahagi.kancollebrowser.nativewebview.NativeGameWebViewClientTest"
```

预期：FAIL，`point.dmm.com` 当前仍作为普通 HTTPS 导航放行。

- [ ] **步骤 3：实现 Android-free 的充值主机识别**

使用 `java.net.URI` 解析 URL，在检查普通 HTTP(S) 放行之前精确拒绝 `point.dmm.com` 与 `point.dmm.co.jp`：

```kotlin
private fun isBlockedDmmPointCharge(url: String?): Boolean = runCatching {
    val uri = URI(url.orEmpty())
    uri.scheme.equals("https", ignoreCase = true) &&
        uri.rawUserInfo == null &&
        uri.host?.lowercase(Locale.ROOT) in BLOCKED_POINT_CHARGE_HOSTS
}.getOrDefault(false)
```

命中时直接返回 `true`，不调用 `sink.navigationBlocked`。

- [ ] **步骤 4：运行原生测试并确认绿灯**

运行：

```powershell
Set-Location android
./gradlew.bat testDebugUnitTest --tests "app.yahagi.kancollebrowser.nativewebview.NativeGameWebViewClientTest"
```

预期：全部通过。

### 任务 4：综合验证与原子提交

**文件：**

- 验证：上述全部生产代码与测试文件

- [ ] **步骤 1：格式化修改文件**

运行：

```powershell
dart format lib/src/browser/game_navigation_policy.dart lib/src/game_webview.dart lib/src/browser/game_page_alignment_script.dart test/game_navigation_policy_test.dart test/game_page_alignment_script_test.dart
```

- [ ] **步骤 2：运行 Flutter 相关回归**

运行：

```powershell
flutter test --no-test-assets test/game_navigation_policy_test.dart test/game_page_alignment_script_test.dart test/game_environment_host_test.dart
```

预期：全部通过。

- [ ] **步骤 3：运行静态检查与 Kotlin 回归**

运行：

```powershell
flutter analyze lib/src/browser/game_navigation_policy.dart lib/src/game_webview.dart lib/src/browser/game_page_alignment_script.dart test/game_navigation_policy_test.dart test/game_page_alignment_script_test.dart
Set-Location android
./gradlew.bat testDebugUnitTest --tests "app.yahagi.kancollebrowser.nativewebview.NativeGameWebViewClientTest"
```

预期：静态检查无问题，JUnit 测试全部通过。

- [ ] **步骤 4：检查差异并提交**

运行：

```powershell
git diff --check
git diff -- lib/src/browser/game_navigation_policy.dart lib/src/game_webview.dart lib/src/browser/game_page_alignment_script.dart test/game_navigation_policy_test.dart test/game_page_alignment_script_test.dart android/app/src/main/kotlin/app/yahagi/kancollebrowser/nativewebview/NativeGameWebViewClient.kt android/app/src/test/kotlin/app/yahagi/kancollebrowser/nativewebview/NativeGameWebViewClientTest.kt
git add -- lib/src/browser/game_navigation_policy.dart lib/src/game_webview.dart lib/src/browser/game_page_alignment_script.dart test/game_navigation_policy_test.dart test/game_page_alignment_script_test.dart android/app/src/main/kotlin/app/yahagi/kancollebrowser/nativewebview/NativeGameWebViewClient.kt android/app/src/test/kotlin/app/yahagi/kancollebrowser/nativewebview/NativeGameWebViewClientTest.kt
git commit -m "fix(支付安全): 阻止 DMM PT 充值跳转"
```

预期：只提交本计划列出的代码与测试文件，不包含工作区其他改动。

