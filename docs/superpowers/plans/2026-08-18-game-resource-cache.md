# 内置式游戏资源缓存实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在 Android WebView 内实现“无本地缓存、轻度缓存、完整缓存”三档舰 C 静态资源持久缓存、按需补漏、轻度与完整预下载、10 GiB 容量策略和完整性检查。

**架构：** 原生 Kotlin 层负责请求判定、文件索引、官方资源下载、WebView 响应和预下载队列；Dart 层负责持久化用户模式、从 `api_start2` 与玩家持有数据生成清单，并向设置页暴露状态。运行时拦截与预下载共用同一缓存引擎，现有 Gadget 绕过客户端只增加一个受控的普通资源分支。

**技术栈：** Flutter/Dart、Android Kotlin、Android WebView、MethodChannel、`HttpURLConnection`、JSON 文件索引、JUnit 4、Flutter Test。

---

## 文件结构

### Android 原生层

- 创建 `android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameResourceCacheMode.kt`：三档模式及读写语义。
- 创建 `android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameResourceCacheRules.kt`：域名、路径、方法、扩展名和关键文件排除规则。
- 创建 `android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameResourceCacheKey.kt`：跨舰 C 服务器主机的稳定缓存键。
- 创建 `android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameResourceCacheIndex.kt`：JSON 元数据索引及原子保存。
- 创建 `android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameResourceCacheStore.kt`：持久目录、临时文件、原子提交、容量和 LRU。
- 创建 `android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameResourceFetcher.kt`：受限官方资源下载和条件请求。
- 创建 `android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameResourceCacheEngine.kt`：命中、透传缓存、并发合并和校验。
- 创建 `android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameResourceDownloadCoordinator.kt`：预下载队列、暂停、恢复和 10 GiB 策略。
- 创建 `android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameResourceCacheManager.kt`：MethodChannel 与状态汇总。
- 修改 `android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GadgetBypassWebViewClient.kt`：在 Gadget/主脚本逻辑之后接入普通资源缓存。
- 修改 `android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/WebViewProxyManager.kt`：向原生资源下载器公开当前 HTTP/SOCKS 路由。
- 修改 `android/app/src/main/kotlin/app/yahagi/kancollebrowser/MainActivity.kt`：注册缓存管理器并统一 WebViewClient 包装生命周期。

### Flutter 层

- 创建 `lib/src/browser/game_resource_cache_store.dart`：用户模式持久化。
- 创建 `lib/src/browser/game_resource_cache_channel.dart`：原生通道模型和接口。
- 创建 `lib/src/browser/game_resource_cache_controller.dart`：状态、操作和格式化完整度。
- 创建 `lib/src/browser/game_resource_manifest_builder.dart`：从主数据生成轻度与完整清单。
- 创建 `lib/src/browser/game_resource_manifest_consumer.dart`：接收解码后的 `api_start2` 并提交清单。
- 创建 `lib/src/settings/game_resource_cache_section.dart`：三档选择、完整度和维护操作。
- 创建 `assets/data/game_resource_static_catalog.json`：启动与常用 UI 静态资源路径清单。
- 修改 `pubspec.yaml`：登记静态清单资源。
- 修改 `lib/main.dart`：初始化控制器、注册事件消费者并注入设置页。
- 修改 `lib/src/settings/data_settings_page.dart`：挂载缓存设置区。
- 修改 `lib/l10n/app_zh.arb`、`lib/l10n/app_ja.arb`、`lib/l10n/app_zh_Hant.arb`：新增用户文案；随后运行本地化生成。

### 测试

- 创建 `android/app/src/test/kotlin/app/yahagi/kancollebrowser/browser/GameResourceCacheRulesTest.kt`。
- 创建 `android/app/src/test/kotlin/app/yahagi/kancollebrowser/browser/GameResourceCacheStoreTest.kt`。
- 创建 `android/app/src/test/kotlin/app/yahagi/kancollebrowser/browser/GameResourceCacheEngineTest.kt`。
- 创建 `android/app/src/test/kotlin/app/yahagi/kancollebrowser/browser/GameResourceDownloadCoordinatorTest.kt`。
- 修改 `android/app/src/androidTest/kotlin/app/yahagi/kancollebrowser/browser/GadgetBypassWebViewClientTest.kt`。
- 创建 `test/game_resource_cache_store_test.dart`。
- 创建 `test/game_resource_manifest_builder_test.dart`。
- 创建 `test/game_resource_cache_controller_test.dart`。
- 创建 `test/game_resource_cache_section_test.dart`。

## 任务 1：定义模式、允许列表与稳定缓存键

- [ ] **步骤 1：编写失败的 Kotlin 规则测试**

覆盖官方 `wNN*.kancolle-server.com` 静态 GET、`/kcs2/resources/`、`/kcs2/img/`、旧版 `/kcs/sound/`，并拒绝 `kcsapi`、登录域名、PHP、POST、用户信息和未知扩展名。缓存键必须忽略舰 C 服务器主机，但保留路径和完整查询版本。

```kotlin
@Test fun `accepts versioned official static asset`() {
    val url = "https://w17k.kancolle-server.com/kcs2/resources/ship/full/a.png?version=21"
    assertTrue(GameResourceCacheRules.shouldCache(url, "GET"))
    assertEquals("/kcs2/resources/ship/full/a.png?version=21", GameResourceCacheKey.from(url)?.value)
}

@Test fun `rejects dynamic api`() {
    assertFalse(GameResourceCacheRules.shouldCache("https://w17k.kancolle-server.com/kcsapi/api_port/port", "GET"))
}
```

- [ ] **步骤 2：运行规则测试并确认失败**

运行：`cd android; ./gradlew.bat testDebugUnitTest --tests "*GameResourceCacheRulesTest"`

预期：FAIL，提示 `GameResourceCacheRules`、`GameResourceCacheKey` 尚不存在。

- [ ] **步骤 3：实现最小模式、规则和键类型**

```kotlin
enum class GameResourceCacheMode(val wireName: String) {
    NONE("none"), LIGHT("light"), FULL("full");
    val readsCache get() = this != NONE
    val writesCache get() = this != NONE
}

@JvmInline value class GameResourceCacheKey(val value: String) {
    companion object { fun from(url: String): GameResourceCacheKey? }
}

object GameResourceCacheRules {
    fun shouldCache(url: String?, method: String?): Boolean
    fun isAlwaysValidated(url: String): Boolean
    fun mimeTypeFor(url: String): GadgetBypassRules.MimeInfo
}
```

- [ ] **步骤 4：运行测试确认通过**

运行：`cd android; ./gradlew.bat testDebugUnitTest --tests "*GameResourceCacheRulesTest"`

预期：PASS。

- [ ] **步骤 5：提交**

```bash
git add android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameResourceCacheMode.kt android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameResourceCacheRules.kt android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameResourceCacheKey.kt android/app/src/test/kotlin/app/yahagi/kancollebrowser/browser/GameResourceCacheRulesTest.kt
git commit -m "feat(缓存): 添加游戏资源缓存规则"
```

## 任务 2：实现持久索引、原子文件存储与 LRU

- [ ] **步骤 1：编写失败的存储测试**

使用 JUnit 临时目录验证临时文件不算命中、提交后可读、重新创建索引后仍可读、损坏长度会失效、轻度模式可淘汰最旧文件、完整模式只报告超限。

```kotlin
@Test fun `atomic commit survives index reload`() {
    val index = GameResourceCacheIndex(root.resolve("index.json"))
    val store = GameResourceCacheStore(root, index, maxBytes = 10_000)
    store.commit(key, byteArrayOf(1, 2, 3), version = "21", mimeType = "image/png")
    val reloaded = GameResourceCacheStore(root, GameResourceCacheIndex(root.resolve("index.json")), 10_000)
    assertArrayEquals(byteArrayOf(1, 2, 3), reloaded.read(key)?.bytes)
}
```

- [ ] **步骤 2：运行测试并确认失败**

运行：`cd android; ./gradlew.bat testDebugUnitTest --tests "*GameResourceCacheStoreTest"`

预期：FAIL，存储类不存在。

- [ ] **步骤 3：实现索引和文件存储**

索引条目固定为以下字段，JSON 写入 `index.json.tmp` 后重命名：

```kotlin
data class GameResourceCacheEntry(
    val key: String,
    val fileName: String,
    val version: String?,
    val mimeType: String,
    val byteLength: Long,
    val etag: String?,
    val lastModified: String?,
    val lastAccessedAt: Long,
    val sha256: String,
)
```

正式文件按 `filesDir/game_resource_cache/files/{sha256}.cache` 规则命名，临时文件放入同卷 `tmp/`，以保证原子移动。`evictLightToFit(requiredBytes)` 排除受保护键并按 `lastAccessedAt` 删除。

- [ ] **步骤 4：运行存储测试确认通过**

运行：`cd android; ./gradlew.bat testDebugUnitTest --tests "*GameResourceCacheStoreTest"`

预期：PASS。

- [ ] **步骤 5：提交**

```bash
git add android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameResourceCacheIndex.kt android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameResourceCacheStore.kt android/app/src/test/kotlin/app/yahagi/kancollebrowser/browser/GameResourceCacheStoreTest.kt
git commit -m "feat(缓存): 添加持久资源存储"
```

## 任务 3：实现官方下载、命中与按需补漏引擎

- [ ] **步骤 1：编写失败的引擎测试**

注入假下载器，验证首次请求下载一次并提交、第二次请求零网络、版本变化重新下载、并发同键只下载一次、失败不覆盖旧文件、关键文件不使用错误版本回退。

```kotlin
@Test fun `second exact request is served from disk`() {
    val first = engine.fetch(url)
    val second = engine.fetch(url)
    assertArrayEquals(first?.bytes, second?.bytes)
    assertEquals(1, fetcher.calls)
    assertEquals(GameResourceResponseSource.CACHE, second?.source)
}
```

- [ ] **步骤 2：运行测试并确认失败**

运行：`cd android; ./gradlew.bat testDebugUnitTest --tests "*GameResourceCacheEngineTest"`

预期：FAIL，引擎类型不存在。

- [ ] **步骤 3：实现下载器和缓存引擎**

```kotlin
data class GameResourceFetchResult(
    val statusCode: Int,
    val reasonPhrase: String,
    val headers: Map<String, String>,
    val bytes: ByteArray,
)

interface GameResourceFetcher {
    fun fetch(url: String, requestHeaders: Map<String, String>, cached: GameResourceCacheEntry?): GameResourceFetchResult?
}

data class GameResourceResponse(
    val bytes: ByteArray,
    val mimeType: String,
    val encoding: String?,
    val statusCode: Int = 200,
    val reasonPhrase: String = "OK",
    val headers: Map<String, String> = emptyMap(),
    val source: GameResourceResponseSource,
)
```

`HttpUrlConnectionGameResourceFetcher` 只允许 HTTPS 官方主机重定向，连接超时 8 秒、读取超时 30 秒、单文件上限 128 MiB。引擎使用每键锁合并并发请求；成功响应先校验长度，再提交缓存。

下载器构造器接收 `() -> Proxy`，由 `WebViewProxyManager` 提供当前原生路由。系统网络返回 `Proxy.NO_PROXY`，HTTP 与 SOCKS 模式返回对应 `Proxy`；这样应用内代理不只作用于 WebView，也作用于缓存缺失和预下载请求。

- [ ] **步骤 4：运行引擎和已有 Gadget 测试**

运行：`cd android; ./gradlew.bat testDebugUnitTest --tests "*GameResourceCacheEngineTest" --tests "*GadgetBypass*Test"`

预期：PASS。

- [ ] **步骤 5：提交**

```bash
git add android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameResourceFetcher.kt android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameResourceCacheEngine.kt android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/WebViewProxyManager.kt android/app/src/test/kotlin/app/yahagi/kancollebrowser/browser/GameResourceCacheEngineTest.kt
git commit -m "feat(缓存): 添加官方资源缓存引擎"
```

## 任务 4：接入 WebView 并保持 Gadget、帧率补丁兼容

- [ ] **步骤 1：扩展 Android WebView 集成测试**

为 `GadgetBypassWebViewClient` 注入假 `GameResourceCacheEngine`，验证调用顺序：主脚本补丁优先、Gadget 绕过其次、普通静态缓存再次、原客户端最终回退；无缓存模式必须直接回退。

- [ ] **步骤 2：运行集成测试并确认失败**

运行：`cd android; ./gradlew.bat connectedDebugAndroidTest -Pandroid.testInstrumentationRunnerArguments.class=app.yahagi.kancollebrowser.browser.GadgetBypassWebViewClientTest`

预期：FAIL，构造器尚不接受普通资源缓存引擎。

- [ ] **步骤 3：修改 WebViewClient**

```kotlin
private fun serveFromGameCache(url: String, headers: Map<String, String>): WebResourceResponse? {
    val response = gameResourceEngine?.fetch(url, headers) ?: return null
    return WebResourceResponse(
        response.mimeType,
        response.encoding,
        response.statusCode,
        response.reasonPhrase,
        response.headers,
        ByteArrayInputStream(response.bytes),
    )
}
```

两个 `shouldInterceptRequest` 重载使用同一私有路由函数，避免规则分叉。

- [ ] **步骤 4：在 MainActivity 注册引擎并统一包装条件**

包装条件改为“Gadget 已启用、帧率需要补丁、资源缓存模式非 none”任一成立；关闭其中一个功能不得拆除其他功能仍需要的客户端包装。

- [ ] **步骤 5：运行 Android 单元和设备测试**

运行：`cd android; ./gradlew.bat testDebugUnitTest connectedDebugAndroidTest`

预期：PASS。

- [ ] **步骤 6：提交**

```bash
git add android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GadgetBypassWebViewClient.kt android/app/src/main/kotlin/app/yahagi/kancollebrowser/MainActivity.kt android/app/src/androidTest/kotlin/app/yahagi/kancollebrowser/browser/GadgetBypassWebViewClientTest.kt
git commit -m "feat(缓存): 接入游戏 WebView 资源缓存"
```

## 任务 5：实现原生管理通道和预下载协调器

- [ ] **步骤 1：编写失败的协调器测试**

验证游戏请求优先、清单去重、暂停后不取新任务、恢复继续、轻度超限调用 LRU、完整超限进入 `capacityBlocked`，以及任务快照可序列化恢复。

- [ ] **步骤 2：运行测试并确认失败**

运行：`cd android; ./gradlew.bat testDebugUnitTest --tests "*GameResourceDownloadCoordinatorTest"`

预期：FAIL，协调器不存在。

- [ ] **步骤 3：实现协调器和管理器**

通道名固定为 `app.yahagi.kancollebrowser/game_resource_cache`，支持：

```text
configure(mode)
status()
setManifest(profile, urls, targetBytes)
startDownload()
pauseDownload()
checkIntegrity()
repair()
clear()
```

状态返回 `mode`、`state`、`cachedBytes`、`targetBytes`、`downloadedBytes`、`bytesPerSecond`、`remainingSeconds`、`missingCount`、`damagedCount` 和 `capacityBlocked`。

- [ ] **步骤 4：运行协调器测试确认通过**

运行：`cd android; ./gradlew.bat testDebugUnitTest --tests "*GameResourceDownloadCoordinatorTest"`

预期：PASS。

- [ ] **步骤 5：提交**

```bash
git add android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameResourceDownloadCoordinator.kt android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameResourceCacheManager.kt android/app/src/main/kotlin/app/yahagi/kancollebrowser/MainActivity.kt android/app/src/test/kotlin/app/yahagi/kancollebrowser/browser/GameResourceDownloadCoordinatorTest.kt
git commit -m "feat(缓存): 添加资源预下载管理通道"
```

## 任务 6：实现 Dart 模式存储、通道与控制器

- [ ] **步骤 1：编写失败的 Dart 测试**

覆盖默认 `none`、三档 JSON 往返、切换模式不调用清理、容量格式，以及控制器将原生状态映射为 UI 状态。

```dart
test('formats completeness as one capacity line', () {
  expect(formatCacheCompleteness(6840000000, 8120000000), '6.84 GB / 8.12 GB（84.2%）');
});
```

- [ ] **步骤 2：运行测试并确认失败**

运行：`flutter test test/game_resource_cache_store_test.dart test/game_resource_cache_controller_test.dart`

预期：FAIL，Dart 缓存类型不存在。

- [ ] **步骤 3：实现 Dart API**

```dart
enum GameResourceCacheMode { none, light, full }

abstract interface class GameResourceCachePort {
  Future<bool> configure(GameResourceCacheMode mode);
  Future<GameResourceCacheStatus> status();
  Future<bool> setManifest(GameResourceManifest manifest);
  Future<bool> startDownload();
  Future<bool> pauseDownload();
  Future<bool> checkIntegrity();
  Future<bool> repair();
  Future<bool> clear();
}
```

控制器每秒轮询下载状态，仅在页面可见或任务运行时启用计时器；`dispose` 必须取消计时器。

- [ ] **步骤 4：运行测试确认通过**

运行：`flutter test test/game_resource_cache_store_test.dart test/game_resource_cache_controller_test.dart`

预期：PASS。

- [ ] **步骤 5：提交**

```bash
git add lib/src/browser/game_resource_cache_store.dart lib/src/browser/game_resource_cache_channel.dart lib/src/browser/game_resource_cache_controller.dart test/game_resource_cache_store_test.dart test/game_resource_cache_controller_test.dart
git commit -m "feat(缓存): 添加游戏资源缓存控制器"
```

## 任务 7：生成轻度与完整资源清单

- [ ] **步骤 1：编写失败的清单测试**

夹具包含 `api_mst_shipgraph`、`api_mst_ship`、`api_mst_slotitem`、`api_mst_furniture`、`api_mst_mapinfo` 和版本字段。验证轻度只生成持有舰娘/装备加静态核心资源，完整模式生成所有主数据资源，并保留 `version`。

- [ ] **步骤 2：运行测试并确认失败**

运行：`flutter test test/game_resource_manifest_builder_test.dart`

预期：FAIL，清单构建器不存在。

- [ ] **步骤 3：实现路径生成器和静态清单**

```dart
final class GameResourceManifestBuilder {
  GameResourceManifest buildLight({
    required Map<String, Object?> start2,
    required Set<int> ownedShipMasterIds,
    required Set<int> ownedSlotItemMasterIds,
    required List<String> staticUrls,
  });

  GameResourceManifest buildFull({
    required Map<String, Object?> start2,
    required List<String> staticUrls,
  });
}
```

舰娘资源使用 `api_mst_shipgraph.api_filename` 和 `api_version`；装备使用 `api_mst_slotitem.api_id/api_version`；地图使用 `api_mst_mapinfo` 与 `version.json` 映射；家具、BGM、SE、标题语音和舰娘语音按当前客户端公开路径规则生成。静态 UI 清单从打包 JSON 读取，不在代码中堆叠字符串。

- [ ] **步骤 4：接入事件管线**

`GameResourceManifestConsumer` 只支持 `/kcsapi/api_start2/getData`，使用已解码 `api_data`，结合 `GameStateController.state` 的 `ships.values.map((s) => s.masterId)` 与 `slotItems.values.map((s) => s.masterId)` 构建清单并提交原生层。

- [ ] **步骤 5：运行清单和事件管线测试**

运行：`flutter test test/game_resource_manifest_builder_test.dart test/game_api_event_pipeline_test.dart`

预期：PASS。

- [ ] **步骤 6：提交**

```bash
git add assets/data/game_resource_static_catalog.json pubspec.yaml lib/src/browser/game_resource_manifest_builder.dart lib/src/browser/game_resource_manifest_consumer.dart test/game_resource_manifest_builder_test.dart
git commit -m "feat(缓存): 生成轻度与完整资源清单"
```

## 任务 8：实现设置页交互与本地化

- [ ] **步骤 1：编写失败的组件测试**

验证三档选择、`6.84 GB / 8.12 GB（84.2%）` 单行显示、首次下载确认、移动网络确认、暂停/继续、完整性检查、修复与清空二次确认。

- [ ] **步骤 2：运行测试并确认失败**

运行：`flutter test test/game_resource_cache_section_test.dart test/data_settings_page_test.dart`

预期：FAIL，设置区不存在。

- [ ] **步骤 3：实现设置区并注入 DataSettingsPage**

```dart
GameResourceCacheSection(
  controller: gameResourceCacheController,
  onConfirmInitialDownload: (estimate) => showCacheDownloadDialog(context, estimate),
)
```

主界面完整度严格只显示容量行；缺失文件数放入详情对话框。无缓存模式下保留“检查缓存完整性”和“清空缓存”，隐藏开始下载。

- [ ] **步骤 4：补齐中、日、繁本文案并生成本地化代码**

运行：`flutter gen-l10n`

预期：命令成功，生成的 `app_localizations*.dart` 包含新增键。

- [ ] **步骤 5：运行页面测试确认通过**

运行：`flutter test test/game_resource_cache_section_test.dart test/data_settings_page_test.dart`

预期：PASS。

- [ ] **步骤 6：提交**

```bash
git add lib/src/settings/game_resource_cache_section.dart lib/src/settings/data_settings_page.dart lib/main.dart lib/l10n test/game_resource_cache_section_test.dart test/data_settings_page_test.dart
git commit -m "feat(设置): 添加游戏资源缓存模式"
```

## 任务 9：实现 Wi-Fi 自动更新与移动网络确认边界

- [ ] **步骤 1：编写网络约束测试**

通过可注入网络类型端口验证 Wi-Fi 自动开始差异任务、移动网络保持等待确认、网络切换离开 Wi-Fi 后暂停后台任务，但运行时 WebView 请求仍可下载。

- [ ] **步骤 2：实现 Android 网络状态观察**

使用 `ConnectivityManager.NetworkCallback`，只把批量任务约束为 `TRANSPORT_WIFI`；不要全局阻断缓存引擎的运行时请求。管理器销毁时注销回调。

- [ ] **步骤 3：运行协调器与控制器测试**

运行：`cd android; ./gradlew.bat testDebugUnitTest --tests "*GameResourceDownloadCoordinatorTest"; cd ..; flutter test test/game_resource_cache_controller_test.dart`

预期：PASS。

- [ ] **步骤 4：提交**

```bash
git add android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameResourceDownloadCoordinator.kt android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameResourceCacheManager.kt android/app/src/test/kotlin/app/yahagi/kancollebrowser/browser/GameResourceDownloadCoordinatorTest.kt lib/src/browser/game_resource_cache_controller.dart test/game_resource_cache_controller_test.dart
git commit -m "feat(缓存): 添加网络约束自动更新"
```

## 任务 10：全量验证与实机验收

- [ ] **步骤 1：运行格式化与静态检查**

运行：`dart format lib test && flutter analyze`

预期：无格式差异，`flutter analyze` 无新增问题。

- [ ] **步骤 2：运行 Flutter 全量测试**

运行：`flutter test`

预期：全部通过。

- [ ] **步骤 3：运行 Android 单元测试**

运行：`cd android; ./gradlew.bat testDebugUnitTest`

预期：全部通过。

- [ ] **步骤 4：构建 Debug APK**

运行：`flutter build apk --debug`

预期：生成 `build/app/outputs/flutter-apk/app-debug.apk`。

- [ ] **步骤 5：实机验证**

在同一舰娘立绘 URL 上记录首次下载和第二次访问：第二次必须由本地命中且网络下载字节为 0。依次验证三档切换、应用重启、Wi-Fi 转移动网络、暂停续传、完整性检查、损坏单文件修复和清空缓存。
