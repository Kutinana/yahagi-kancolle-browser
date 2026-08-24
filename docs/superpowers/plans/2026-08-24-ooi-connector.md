# OOI 双连接模式实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在“网络”设置中增加 Yahagi/OOI 游戏连接器切换，OOI 固定使用直连登录模式，并验证登录后 KCSAPI 捕获、现有功能和本地资源缓存互不冲突。

**架构：** 新增独立于代理 `NetworkMode` 的 `GameConnector` 设置和控制器；连接器只决定 WebView 的登录入口，切换后保存设置并立即导航，不修改代理和本地缓存配置。OOI 页面仅执行一个不读取凭据、不自动提交的 DOM 辅助脚本；进入 DMM/舰娘官方域名后，继续沿用当前导航、KCSAPI 捕获和静态资源缓存链路。

**技术栈：** Flutter/Dart、SharedPreferences、webview_flutter、Android WebView/Kotlin、flutter_test、JUnit 4

---

## 文件结构

- 创建 `lib/src/settings/game_connector.dart`：定义连接器枚举、持久化名称、入口 URI 和精确域名判断。
- 创建 `lib/src/settings/game_connector_controller.dart`：加载、保存和串行化切换操作，不接触代理或缓存控制器。
- 创建 `lib/src/browser/ooi_connector_assist.dart`：封装 OOI 直连单选框辅助脚本及精确页面匹配。
- 创建 `lib/src/browser/game_initial_address.dart`：统一两种渲染表面的冷启动入口解析。
- 修改 `lib/src/browser/game_browser_controller.dart`：保存当前首页入口，并支持切换后立即导航。
- 修改 `lib/src/browser/game_navigation_policy.dart`、`lib/src/browser/safe_page_address.dart`：仅允许精确的 OOI HTTPS 页面进入登录 WebView，并保持官方认证跳转策略。
- 修改 `lib/src/game_webview.dart`、`lib/src/native_activity_game_surface.dart`：以连接器入口启动，并在 OOI 页面完成时运行辅助脚本。
- 修改 `lib/main.dart`：初始化和注入连接器控制器。
- 修改 `lib/src/settings/network_settings_page_new.dart`、`lib/src/settings/settings_page.dart`：显示连接器选择区、风险确认和立即切换逻辑。
- 修改 `lib/l10n/app_zh.arb`、`lib/l10n/app_zh_Hant.arb`、`lib/l10n/app_ja.arb`：增加连接器、风险提示和结果文案；生成文件由 `flutter gen-l10n` 更新。
- 修改 `android/app/src/test/kotlin/app/yahagi/kancollebrowser/browser/GameResourceCacheRulesTest.kt`：证明 OOI 登录资源和 KCSAPI 不进缓存、官方静态资源仍可命中缓存。
- 修改 `android/app/src/test/kotlin/app/yahagi/kancollebrowser/capture/CaptureOriginPolicyTest.kt`：证明 OOI 不会成为 KCSAPI 消息可信来源。
- 创建 `docs/testing/ooi-connector-acceptance.md`：记录真机登录、KCSAPI 功能矩阵及冷/热/损坏缓存验收步骤。

### 任务 1：连接器模型与持久化控制器

**文件：**
- 创建：`lib/src/settings/game_connector.dart`
- 创建：`lib/src/settings/game_connector_controller.dart`
- 创建：`test/game_connector_controller_test.dart`

- [ ] **步骤 1：编写失败的模型与控制器测试**

```dart
test('defaults unknown stored values to Yahagi', () {
  expect(GameConnectorCodec.decode(null), GameConnector.yahagi);
  expect(GameConnectorCodec.decode('future'), GameConnector.yahagi);
});

test('OOI has an exact HTTPS entry and does not match lookalikes', () {
  expect(GameConnector.ooi.entryUri, Uri.parse('https://ooi.moe/'));
  expect(GameConnector.ooi.ownsLoginPage(Uri.parse('https://ooi.moe/')), isTrue);
  expect(GameConnector.ooi.ownsLoginPage(Uri.parse('https://evil.ooi.moe/')), isFalse);
  expect(GameConnector.ooi.ownsLoginPage(Uri.parse('http://ooi.moe/')), isFalse);
});

test('change persists before publishing the new connector', () async {
  final store = MemoryGameConnectorStore(GameConnector.yahagi);
  final controller = await GameConnectorController.load(store);
  final result = await controller.change(GameConnector.ooi);
  expect(result, GameConnectorChangeResult.applied);
  expect(store.value, GameConnector.ooi);
  expect(controller.connector, GameConnector.ooi);
});
```

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/game_connector_controller_test.dart`

预期：FAIL，提示 `game_connector.dart` 或 `GameConnectorController` 不存在。

- [ ] **步骤 3：实现最小模型和控制器**

```dart
enum GameConnector { yahagi, ooi }

extension GameConnectorDefinition on GameConnector {
  String get storageName => name;
  Uri get entryUri => switch (this) {
    GameConnector.yahagi => GameLaunchConfig.dmmGameEntry,
    GameConnector.ooi => Uri.parse('https://ooi.moe/'),
  };

  bool ownsLoginPage(Uri uri) => this == GameConnector.ooi &&
      uri.scheme == 'https' && uri.host.toLowerCase() == 'ooi.moe' &&
      !uri.hasPort && uri.userInfo.isEmpty;
}

abstract interface class GameConnectorStore {
  Future<GameConnector> load();
  Future<void> save(GameConnector connector);
}

enum GameConnectorChangeResult { unchanged, applied, busy, saveFailed }

final class GameConnectorController extends ChangeNotifier {
  static Future<GameConnectorController> load(GameConnectorStore store) async =>
      GameConnectorController._(store, await store.load());

  Future<GameConnectorChangeResult> change(GameConnector target) async {
    if (_busy) return GameConnectorChangeResult.busy;
    if (target == _connector) return GameConnectorChangeResult.unchanged;
    _busy = true;
    notifyListeners();
    try {
      await _store.save(target);
      _connector = target;
      return GameConnectorChangeResult.applied;
    } catch (_) {
      return GameConnectorChangeResult.saveFailed;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
```

持久化键固定为 `game.connector`，未知值回退 `GameConnector.yahagi`；`SharedPreferences.setString` 返回 `false` 时抛出 `StateError`，由控制器转换为 `saveFailed`。

- [ ] **步骤 4：运行测试验证通过**

运行：`flutter test test/game_connector_controller_test.dart`

预期：PASS。

- [ ] **步骤 5：提交**

```bash
git add lib/src/settings/game_connector.dart lib/src/settings/game_connector_controller.dart test/game_connector_controller_test.dart
git commit -m "feat(网络): 添加游戏连接器设置"
```

### 任务 2：让浏览器入口可切换并限制 OOI 导航边界

**文件：**
- 修改：`lib/src/browser/game_browser_controller.dart`
- 修改：`lib/src/browser/game_navigation_policy.dart`
- 修改：`lib/src/browser/safe_page_address.dart`
- 修改：`test/game_browser_controller_test.dart`
- 修改：`test/game_navigation_policy_test.dart`
- 修改：`test/safe_page_address_test.dart`

- [ ] **步骤 1：编写失败的入口切换测试**

```dart
test('switchHome navigates immediately and home uses the selected connector', () async {
  final port = RecordingGameBrowserPort();
  final controller = GameBrowserController(
    homeUri: GameConnector.yahagi.entryUri,
    port: port,
  );
  await controller.switchHome(GameConnector.ooi.entryUri);
  await controller.goHome();
  expect(controller.homeUri, GameConnector.ooi.entryUri);
  expect(port.loadedUris, [GameConnector.ooi.entryUri, GameConnector.ooi.entryUri]);
});

test('allows only the exact OOI HTTPS origin', () {
  final policy = GameNavigationPolicy();
  expect(policy.canNavigate(Uri.parse('https://ooi.moe/')), isTrue);
  expect(policy.canNavigate(Uri.parse('http://ooi.moe/')), isFalse);
  expect(policy.canNavigate(Uri.parse('https://login.ooi.moe/')), isFalse);
  expect(policy.canNavigate(Uri.parse('https://ooi.moe.evil.test/')), isFalse);
});
```

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/game_browser_controller_test.dart test/game_navigation_policy_test.dart test/safe_page_address_test.dart`

预期：FAIL，提示 `homeUri`、`switchHome` 不存在，且 OOI 导航被拒绝。

- [ ] **步骤 3：实现动态首页和精确 OOI 白名单**

```dart
GameBrowserController._(this._port, this._homeUri)
    : _displayAddress = _homeUri.toString();

Uri _homeUri;
Uri get homeUri => _homeUri;
bool get isOfficialGamePage {
  final uri = Uri.tryParse(_displayAddress);
  return uri != null && uri.scheme == 'https' &&
      uri.host.toLowerCase().endsWith('.kancolle-server.com');
}

Future<void> switchHome(Uri target) async {
  _homeUri = target;
  _mode = GameBrowserMode.realWeb;
  _errorMessage = null;
  notifyListeners();
  await _readyPort()?.loadUri(target);
}

Future<void> goHome() async {
  final port = _readyPort();
  if (port != null) await port.loadUri(_homeUri);
}
```

将 `enterDmmLoginTest()` 保留为兼容别名并委托给 `switchHome(GameLaunchConfig.dmmGameEntry)`；`logoutAndClearSession()` 清理后加载 `_homeUri`。在 `SafePageAddress.canNavigateInGameWebView` 中只额外接受 `scheme == https && host == ooi.moe && !hasPort`，不得接受子域、HTTP、userinfo 或自定义端口。

- [ ] **步骤 4：运行测试验证通过**

运行：`flutter test test/game_browser_controller_test.dart test/game_navigation_policy_test.dart test/safe_page_address_test.dart`

预期：PASS。

- [ ] **步骤 5：提交**

```bash
git add lib/src/browser/game_browser_controller.dart lib/src/browser/game_navigation_policy.dart lib/src/browser/safe_page_address.dart test/game_browser_controller_test.dart test/game_navigation_policy_test.dart test/safe_page_address_test.dart
git commit -m "feat(浏览器): 支持切换游戏登录入口"
```

### 任务 3：OOI 直连模式辅助脚本

**文件：**
- 创建：`lib/src/browser/ooi_connector_assist.dart`
- 创建：`test/ooi_connector_assist_test.dart`
- 修改：`lib/src/game_webview.dart`
- 修改：`lib/src/native_activity_game_surface.dart`
- 修改：`test/native_activity_game_surface_test.dart`

- [ ] **步骤 1：编写失败的脚本契约测试**

```dart
test('assist script selects connector mode without submitting credentials', () {
  expect(OoiConnectorAssist.shouldRun('https://ooi.moe/'), isTrue);
  expect(OoiConnectorAssist.shouldRun('https://ooi.moe.evil.test/'), isFalse);
  expect(OoiConnectorAssist.script, contains('input[name="mode"][value="4"]'));
  expect(OoiConnectorAssist.script, contains('target.checked = true'));
  expect(OoiConnectorAssist.script, isNot(contains('.submit(')));
  expect(OoiConnectorAssist.script, isNot(contains('password')));
  expect(OoiConnectorAssist.script, isNot(contains('click()')));
});
```

在原生表面测试中，发送 `pageFinished(url: 'https://ooi.moe/')`，断言记录端口只执行一次 `OoiConnectorAssist.script`；对 DMM 和官方游戏页断言不执行。

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/ooi_connector_assist_test.dart test/native_activity_game_surface_test.dart`

预期：FAIL，提示 `OoiConnectorAssist` 不存在或没有执行脚本。

- [ ] **步骤 3：实现幂等且无凭据读取的脚本**

```dart
abstract final class OoiConnectorAssist {
  static bool shouldRun(String rawUrl) {
    final uri = Uri.tryParse(rawUrl);
    return uri != null && uri.scheme == 'https' &&
        uri.host.toLowerCase() == 'ooi.moe' && !uri.hasPort &&
        uri.userInfo.isEmpty;
  }

  static const script = r'''(() => {
    const target = document.querySelector('input[name="mode"][value="4"]');
    if (!target) return 'missing';
    target.checked = true;
    target.dispatchEvent(new Event('change', { bubbles: true }));
    for (const value of ['1', '3']) {
      const option = document.querySelector(`input[name="mode"][value="${value}"]`);
      const row = option && (option.closest('label') || option.parentElement);
      if (row) row.style.display = 'none';
      if (option) option.disabled = true;
    }
    return 'ready';
  })();''';
}
```

在 Flutter WebView 的 `_finishPage` 和原生表面的 `_finishPage` 中，仅当 `shouldRun(url)` 为真时调用各自端口的 `runJavaScript`。脚本不得读取、记录、保存账号或密码，不得自动提交表单。

- [ ] **步骤 4：运行测试验证通过**

运行：`flutter test test/ooi_connector_assist_test.dart test/native_activity_game_surface_test.dart`

预期：PASS。

- [ ] **步骤 5：提交**

```bash
git add lib/src/browser/ooi_connector_assist.dart lib/src/game_webview.dart lib/src/native_activity_game_surface.dart test/ooi_connector_assist_test.dart test/native_activity_game_surface_test.dart
git commit -m "feat(浏览器): 添加 OOI 直连登录辅助"
```

### 任务 4：初始化连接器并覆盖两种渲染表面的冷启动

**文件：**
- 创建：`lib/src/browser/game_initial_address.dart`
- 修改：`lib/main.dart`
- 修改：`lib/src/game_webview.dart`
- 修改：`lib/src/native_activity_game_surface.dart`
- 修改：`test/game_environment_host_test.dart`
- 修改：`test/native_activity_game_surface_test.dart`

- [ ] **步骤 1：编写失败的冷启动测试**

```dart
test('OOI is the initial address after a fresh surface start', () {
  final browser = GameBrowserController(homeUri: GameConnector.ooi.entryUri);
  expect(resolveInitialGameAddress(browser), GameConnector.ooi.entryUri);
});
```

再在现有 `NativeActivityGameSurface` 启动测试中把浏览器构造改为 `GameBrowserController(homeUri: GameConnector.ooi.entryUri)`，完成 `created` 事件后断言 `port.loadedUris.single == GameConnector.ooi.entryUri`。测试不得依赖 `displayAddress` 恢复旧页面，因为重建后的唯一启动真相是 `browserController.homeUri`。

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/game_environment_host_test.dart test/native_activity_game_surface_test.dart`

预期：FAIL，实际初始地址仍为 DMM。

- [ ] **步骤 3：注入并使用连接器控制器**

```dart
final gameConnectorController = await GameConnectorController.load(
  SharedPreferencesGameConnectorStore(),
);
final browserController = GameBrowserController(
  homeUri: gameConnectorController.connector.entryUri,
);

Uri resolveInitialGameAddress(GameBrowserController controller) =>
    controller.homeUri;
```

把两个表面的 `initialAddress` 统一改为 `widget.browserController.homeUri`；将 `gameConnectorController` 依次传入 `YahagiApp`、`YahagiShell` 和 `SettingsPage`。连接器切换不调用 `GameEnvironmentHost.restart`，因此不会触发应用重启、缓存重配或下载任务中断。

- [ ] **步骤 4：运行测试验证通过**

运行：`flutter test test/game_environment_host_test.dart test/native_activity_game_surface_test.dart`

预期：PASS，Yahagi 和 OOI 两种初始入口都通过。

- [ ] **步骤 5：提交**

```bash
git add lib/main.dart lib/src/browser/game_initial_address.dart lib/src/game_webview.dart lib/src/native_activity_game_surface.dart test/game_environment_host_test.dart test/native_activity_game_surface_test.dart
git commit -m "feat(启动): 按连接器打开游戏入口"
```

### 任务 5：网络设置 UI、运行中确认和第三方风险提示

**文件：**
- 修改：`lib/src/settings/network_settings_page_new.dart`
- 修改：`lib/src/settings/settings_page.dart`
- 创建：`test/game_connector_section_test.dart`
- 修改：`lib/l10n/app_zh.arb`
- 修改：`lib/l10n/app_zh_Hant.arb`
- 修改：`lib/l10n/app_ja.arb`
- 生成：`lib/l10n/app_localizations*.dart`

- [ ] **步骤 1：编写失败的组件测试**

```dart
testWidgets('selecting OOI confirms third-party risk then navigates immediately', (tester) async {
  await tester.pumpWidget(buildApp(connector: GameConnector.yahagi));
  await tester.tap(find.byKey(const Key('game-connector-ooi')));
  await tester.pumpAndSettle();
  expect(find.textContaining('第三方'), findsOneWidget);
  await tester.tap(find.byKey(const Key('confirm-game-connector-change')));
  await tester.pumpAndSettle();
  expect(controller.connector, GameConnector.ooi);
  expect(browserPort.loadedUris.last, GameConnector.ooi.entryUri);
});

testWidgets('cancelling an active-game switch preserves connector and page', (tester) async {
  browser.onPageFinished('https://w17k.kancolle-server.com/kcs2/index.html');
  await tester.tap(find.byKey(const Key('game-connector-ooi')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('cancel-game-connector-change')));
  expect(controller.connector, GameConnector.yahagi);
  expect(browserPort.loadedUris, isEmpty);
});
```

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/game_connector_section_test.dart`

预期：FAIL，连接器 UI 尚不存在。

- [ ] **步骤 3：实现连接器设置区**

在“网络设置”卡片前增加“游戏连接”卡片，两个 `RadioListTile<GameConnector>` 的键分别为 `game-connector-yahagi` 和 `game-connector-ooi`。确认规则如下：

```dart
final isGameActive = browserController.isOfficialGamePage;
final needsConfirmation = isGameActive || target == GameConnector.ooi;
if (needsConfirmation && !await showGameConnectorConfirmation(...)) return;
final result = await gameConnectorController.change(target);
if (result == GameConnectorChangeResult.applied) {
  await browserController.switchHome(target.entryUri);
}
```

OOI 确认框明确写明“账号凭据将提交给第三方站点 ooi.moe；Yahagi 不读取、不保存、不自动填写凭据”。游戏已进入官方页面时再写明“切换会中断当前游戏页面并返回登录入口”。保存失败时不导航；导航失败时保留已保存选择并显示可重试提示。

- [ ] **步骤 4：生成本地化并运行测试**

运行：`flutter gen-l10n`

运行：`flutter test test/game_connector_section_test.dart test/network_settings_section_test.dart`

预期：PASS，原有代理设置测试不变。

- [ ] **步骤 5：提交**

```bash
git add lib/src/settings/network_settings_page_new.dart lib/src/settings/settings_page.dart test/game_connector_section_test.dart lib/l10n
git commit -m "feat(设置): 添加 Yahagi 与 OOI 连接切换"
```

### 任务 6：本地缓存与 KCSAPI 安全回归

**文件：**
- 修改：`android/app/src/test/kotlin/app/yahagi/kancollebrowser/browser/GameResourceCacheRulesTest.kt`
- 修改：`android/app/src/test/kotlin/app/yahagi/kancollebrowser/browser/GameResourceCacheEngineTest.kt`
- 修改：`android/app/src/test/kotlin/app/yahagi/kancollebrowser/capture/CaptureOriginPolicyTest.kt`
- 修改：`test/game_resource_cache_controller_test.dart`

- [ ] **步骤 1：增加 OOI 与缓存隔离测试**

```kotlin
@Test
fun `OOI login and API traffic never enter the resource cache`() {
    assertFalse(GameResourceCacheRules.shouldCache("https://ooi.moe/", "GET"))
    assertFalse(GameResourceCacheRules.shouldCache("https://ooi.moe/static/app.js", "GET"))
    assertFalse(GameResourceCacheRules.shouldCache("https://ooi.moe/connector", "POST"))
    assertFalse(GameResourceCacheRules.shouldCache(
        "https://w17k.kancolle-server.com/kcsapi/api_port/port", "POST",
    ))
    assertTrue(GameResourceCacheRules.shouldCache(
        "https://w17k.kancolle-server.com/kcs2/resources/ship/full/a.png", "GET",
    ))
}
```

在 `GameResourceCacheEngineTest` 用现有测试服务器/存储假件证明：OOI 请求返回 `null` 且不增加索引，随后官方静态资源仍能写入并从热缓存读取。

- [ ] **步骤 2：增加捕获来源边界测试**

```kotlin
@Test
fun `OOI is a login page not a capture origin`() {
    val policy = CaptureOriginPolicy()
    assertFalse(policy.isAllowed("https://ooi.moe"))
    assertFalse(policy.allowedOriginRules.contains("https://ooi.moe"))
    assertTrue(policy.isAllowed("https://w01y.kancolle-server.com"))
}
```

在 Dart 控制器测试中先把缓存模式设为 `full`，模拟连接器切换（不得调用缓存控制器），断言缓存 store、native port 的配置调用次数和 status 全部不变。

- [ ] **步骤 3：运行隔离测试**

运行：`android\gradlew.bat -p android :app:testDebugUnitTest --tests "app.yahagi.kancollebrowser.browser.GameResourceCacheRulesTest" --tests "app.yahagi.kancollebrowser.browser.GameResourceCacheEngineTest" --tests "app.yahagi.kancollebrowser.capture.CaptureOriginPolicyTest"`

运行：`flutter test test/game_resource_cache_controller_test.dart test/game_connector_controller_test.dart`

预期：全部 PASS。若只增加断言即可通过，说明现有白名单已正确隔离，不为“制造代码变化”放宽缓存或捕获域名。

- [ ] **步骤 4：提交回归测试**

```bash
git add android/app/src/test/kotlin/app/yahagi/kancollebrowser/browser/GameResourceCacheRulesTest.kt android/app/src/test/kotlin/app/yahagi/kancollebrowser/browser/GameResourceCacheEngineTest.kt android/app/src/test/kotlin/app/yahagi/kancollebrowser/capture/CaptureOriginPolicyTest.kt test/game_resource_cache_controller_test.dart
git commit -m "test(缓存): 覆盖 OOI 连接兼容性"
```

### 任务 7：全量验证与真机验收手册

**文件：**
- 创建：`docs/testing/ooi-connector-acceptance.md`
- 修改：`docs/superpowers/specs/2026-08-24-ooi-connector-design.md`（仅在实现与设计发生可解释差异时同步）

- [ ] **步骤 1：运行静态检查和全量自动化测试**

运行：`dart format --output=none --set-exit-if-changed lib test`

运行：`flutter analyze`

运行：`flutter test`

运行：`android\gradlew.bat -p android :app:testDebugUnitTest`

预期：格式检查、分析、Flutter 全量测试和 Android 单元测试均为 0 失败；基线允许的 7 项 skip 不得增加。

- [ ] **步骤 2：编写真机验收矩阵**

手册必须逐项记录“环境、步骤、期望、实际、证据/日志”，至少覆盖：

1. Yahagi 连接 + 缓存关闭：DMM 登录、进入游戏、母港/编成/出击 KCSAPI 正常。
2. OOI 连接 + 缓存关闭：只显示直连模式，手动登录后进入官方页面；账号密码未出现在日志或诊断导出。
3. OOI 连接 + 空的完整缓存：首次资源下载、`api_start2`、`api_port`、舰队/任务/装备/战斗面板更新正常。
4. OOI 连接 + 热缓存：官方静态资源出现本地命中，OOI HTML/JS/CSS 和 `/kcsapi/` 命中数始终为 0。
5. OOI 连接 + 清空重建：清空后能重新下载，连接器选择仍为 OOI。
6. OOI 连接 + 过期或损坏缓存：严格校验文件回源修复，登录和 KCSAPI 不受影响。
7. 游戏运行中 OOI→Yahagi、Yahagi→OOI：弹确认，取消不改变页面；确认立即中断并进入目标登录页。
8. 两种渲染模式：兼容 WebView 与原生 Activity WebView 都完成上述入口和 KCSAPI 验证。
9. 网络组合：系统网络、HTTP 代理、SOCKS5 代理分别确认连接器切换不重置代理设置。

- [ ] **步骤 3：记录功能验收门槛**

只有以下关键事件均被现有 `GameApiEventPipeline` 接收并更新 UI，才能把 OOI 标记从“实验性”改为“可用”：`api_start2`、`api_port/port`、`api_get_member/basic`、`ship_deck`、`slot_item`、`questlist`、`battle`、`battleresult`。任一缺失都在手册中记录请求 URL、HTTP 状态、捕获模式和渲染模式，不得把“能进入游戏”写成“全部功能通过”。

- [ ] **步骤 4：提交验收手册**

```bash
git add docs/testing/ooi-connector-acceptance.md docs/superpowers/specs/2026-08-24-ooi-connector-design.md
git commit -m "docs(测试): 添加 OOI 连接验收矩阵"
```

- [ ] **步骤 5：最终工作树检查**

运行：`git status --short`

运行：`git log --oneline --decorate -8`

预期：没有未提交的功能文件；提交按“设置模型→浏览器入口→OOI 辅助→启动注入→设置 UI→缓存回归→验收手册”的顺序可独立审查。
