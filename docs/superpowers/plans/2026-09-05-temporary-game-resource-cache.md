# 临时游戏资源缓存实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 将「无本地缓存」替换为按需读写、7 天过期、1 GB 上限的「临时缓存」，避免近期游戏资源被 WebView 小缓存反复淘汰。

**架构：** Flutter 使用新的 `temporary` 持久化模式并停止为该模式构建预下载清单；Android 缓存引擎继续拦截官方静态资源，但通过动态缓存策略限制临时模式的保留时间和容量。缓存存储负责过期清理与 LRU 收缩，模式切换时立即执行策略，完整缓存模式保持现有行为。

**技术栈：** Flutter/Dart、Kotlin、Android WebView、SharedPreferences、Flutter `gen-l10n`、JUnit 4、Flutter Test。

---

## 文件结构

- 修改 `lib/src/browser/game_resource_cache_store.dart`：新增 `temporary` 模式和旧持久化值迁移。
- 修改 `lib/src/browser/game_resource_cache_channel.dart`：将空状态默认模式改为临时缓存。
- 修改 `lib/src/browser/game_resource_cache_controller.dart`：将控制器默认模式改为临时缓存。
- 修改 `lib/src/browser/game_resource_manifest_consumer.dart`：临时模式不构建或提交预下载清单。
- 修改 `lib/src/settings/game_resource_cache_section.dart`：显示临时缓存并按模式隐藏预下载管理操作。
- 修改 `lib/l10n/app_zh.arb`、`app_zh_Hant.arb`、`app_ja.arb`：更新三个语言的模式名称与说明。
- 重新生成 `lib/l10n/app_localizations*.dart`：同步本地化接口实现。
- 修改 `android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameResourceCacheMode.kt`：新增临时模式及旧值迁移。
- 修改 `android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameResourceCacheStore.kt`：增加动态策略、7 天过期清理和 LRU 收缩。
- 修改 `android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameResourceCacheEngine.kt`：允许模式切换触发存储策略。
- 修改 `android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameResourceCacheManager.kt`：配置模式后立即应用缓存策略。
- 修改 `android/app/src/main/kotlin/app/yahagi/kancollebrowser/MainActivity.kt`：按当前模式向存储提供缓存策略。
- 修改相关 Dart 和 Kotlin 测试：覆盖迁移、按需命中、过期、容量与 UI 行为。

### 任务 1：模式名称与持久化迁移

**文件：**
- 修改：`lib/src/browser/game_resource_cache_store.dart`
- 修改：`lib/src/browser/game_resource_cache_channel.dart`
- 修改：`lib/src/browser/game_resource_cache_controller.dart`
- 修改：`lib/src/browser/game_resource_manifest_consumer.dart`
- 修改：`test/game_resource_cache_store_test.dart`
- 修改：`test/game_resource_cache_controller_test.dart`
- 修改：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameResourceCacheMode.kt`
- 修改：`android/app/src/test/kotlin/app/yahagi/kancollebrowser/browser/GameResourceCacheEngineTest.kt`

- [x] **步骤 1：编写失败的 Dart 迁移测试**

在 `test/game_resource_cache_store_test.dart` 断言空值、`none` 均得到 `temporary`，`light` 仍得到 `full`：

```dart
expect(GameResourceCacheModeWire.fromWireName(null), GameResourceCacheMode.temporary);
expect(GameResourceCacheModeWire.fromWireName('none'), GameResourceCacheMode.temporary);
expect(GameResourceCacheModeWire.fromWireName('light'), GameResourceCacheMode.full);
```

- [x] **步骤 2：运行测试确认失败**

运行：`flutter test test/game_resource_cache_store_test.dart test/game_resource_cache_controller_test.dart`

预期：FAIL，`GameResourceCacheMode.temporary` 尚不存在。

- [x] **步骤 3：实现 Dart 模式迁移**

保留旧枚举值用于源代码兼容，但所有持久化入口迁移到新模式：

```dart
enum GameResourceCacheMode { temporary, full, light, none }

static GameResourceCacheMode fromWireName(String? value) => switch (value) {
  'full' || 'light' => GameResourceCacheMode.full,
  'temporary' || 'none' || null => GameResourceCacheMode.temporary,
  _ => GameResourceCacheMode.temporary,
};
```

将控制器和 `GameResourceCacheStatus.empty` 的默认值改为 `temporary`。

- [x] **步骤 4：实现 Android 模式迁移**

在 `GameResourceCacheMode.kt` 增加：

```kotlin
TEMPORARY("temporary"),
FULL("full"),
```

保留 `NONE` 和 `LIGHT` 枚举值，避免一次性破坏现有测试和内部调用；持久化解析不再返回这两个旧值。`fromWireName` 将 `null`、`none` 和未知值映射到 `TEMPORARY`，将 `light` 映射到 `FULL`。`TEMPORARY` 与 `FULL` 均允许读取和写入缓存。

- [x] **步骤 5：运行模式相关测试**

运行：`flutter test test/game_resource_cache_store_test.dart test/game_resource_cache_controller_test.dart`

预期：PASS。

- [x] **步骤 6：提交模式迁移**

```bash
git add lib/src/browser/game_resource_cache_store.dart lib/src/browser/game_resource_cache_channel.dart lib/src/browser/game_resource_cache_controller.dart lib/src/browser/game_resource_manifest_consumer.dart test/game_resource_cache_store_test.dart test/game_resource_cache_controller_test.dart android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameResourceCacheMode.kt android/app/src/test/kotlin/app/yahagi/kancollebrowser/browser/GameResourceCacheEngineTest.kt
git commit -m "refactor(缓存): 引入临时资源缓存模式"
```

### 任务 2：缓存策略、过期与容量收缩

**文件：**
- 修改：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameResourceCacheStore.kt`
- 修改：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameResourceCacheEngine.kt`
- 修改：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameResourceCacheManager.kt`
- 修改：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/MainActivity.kt`
- 修改：`android/app/src/test/kotlin/app/yahagi/kancollebrowser/browser/GameResourceCacheStoreTest.kt`
- 修改：`android/app/src/test/kotlin/app/yahagi/kancollebrowser/browser/GameResourceCacheEngineTest.kt`

- [x] **步骤 1：编写失败的存储策略测试**

新增以下完整测试：

```kotlin
@Test
fun `temporary policy expires entries after seven idle days`() {
    var now = 1L
    val root = temporaryFolder.newFolder("expiry")
    val store = GameResourceCacheStore(
        root,
        GameResourceCacheIndex(root.resolve("index.json")),
        clock = { now },
        policyProvider = {
            GameResourceCachePolicy(
                maxBytes = 10,
                maxIdleAgeMs = GameResourceCacheStore.TEMPORARY_MAX_IDLE_AGE_MS,
            )
        },
    )
    val key = GameResourceCacheKey("/kcs2/resources/a.png")
    store.commit(key, byteArrayOf(1), mimeType = "image/png")

    now += GameResourceCacheStore.TEMPORARY_MAX_IDLE_AGE_MS

    assertNull(store.read(key))
    assertFalse(store.contains(key))
}

@Test
fun `enforce policy shrinks cache by least recent access`() {
    var now = 1L
    var policy = GameResourceCachePolicy(maxBytes = 10)
    val root = temporaryFolder.newFolder("shrink")
    val store = GameResourceCacheStore(
        root,
        GameResourceCacheIndex(root.resolve("index.json")),
        clock = { now++ },
        policyProvider = { policy },
    )
    val oldest = GameResourceCacheKey("/kcs2/resources/old.png")
    val newest = GameResourceCacheKey("/kcs2/resources/new.png")
    store.commit(oldest, byteArrayOf(1, 2, 3, 4), mimeType = "image/png")
    store.commit(newest, byteArrayOf(5, 6, 7, 8), mimeType = "image/png")

    policy = GameResourceCachePolicy(maxBytes = 4)
    store.enforcePolicy()

    assertFalse(store.contains(oldest))
    assertTrue(store.contains(newest))
    assertEquals(4, store.totalBytes())
}

@Test
fun `full policy keeps old entries`() {
    var now = 1L
    val root = temporaryFolder.newFolder("persistent")
    val store = GameResourceCacheStore(
        root,
        GameResourceCacheIndex(root.resolve("index.json")),
        clock = { now },
        policyProvider = { GameResourceCachePolicy(maxBytes = 10) },
    )
    val key = GameResourceCacheKey("/kcs2/resources/a.png")
    store.commit(key, byteArrayOf(1), mimeType = "image/png")

    now += GameResourceCacheStore.TEMPORARY_MAX_IDLE_AGE_MS * 2

    assertArrayEquals(byteArrayOf(1), store.read(key)?.bytes)
}
```

- [x] **步骤 2：运行 Kotlin 测试确认失败**

运行：`android/gradlew.bat :app:testDebugUnitTest --tests "app.yahagi.kancollebrowser.browser.GameResourceCacheStoreTest" --no-daemon`

预期：FAIL，`GameResourceCachePolicy` 和 `enforcePolicy` 尚不存在。

- [x] **步骤 3：实现动态缓存策略**

在 `GameResourceCacheStore.kt` 增加：

```kotlin
data class GameResourceCachePolicy(
    val maxBytes: Long,
    val maxIdleAgeMs: Long? = null,
)

companion object {
    const val DEFAULT_MAX_BYTES = 50_000_000_000L
    const val TEMPORARY_MAX_BYTES = 1_000_000_000L
    const val TEMPORARY_MAX_IDLE_AGE_MS = 7L * 24L * 60L * 60L * 1000L
}
```

构造函数接受 `policyProvider`，`maxBytes` 改为动态 getter。读取、元数据检查与写入前调用统一的过期判断；`enforcePolicy()` 先删除过期条目，再按 `lastAccessedAt` 收缩到当前容量上限。

- [x] **步骤 4：接入模式策略**

`MainActivity.kt` 根据当前模式返回：

```kotlin
when (gameResourceCacheMode) {
    GameResourceCacheMode.TEMPORARY -> GameResourceCachePolicy(
        maxBytes = GameResourceCacheStore.TEMPORARY_MAX_BYTES,
        maxIdleAgeMs = GameResourceCacheStore.TEMPORARY_MAX_IDLE_AGE_MS,
    )
    else -> GameResourceCachePolicy(GameResourceCacheStore.DEFAULT_MAX_BYTES)
}
```

`GameResourceCacheEngine` 暴露 `enforcePolicy()`；`GameResourceCacheManager.configure` 在 `onModeChanged(mode)` 后于 IO 线程执行该方法，再重置预下载协调器状态。

- [x] **步骤 5：运行 Kotlin 缓存测试**

运行：`android/gradlew.bat :app:testDebugUnitTest --tests "app.yahagi.kancollebrowser.browser.GameResourceCacheStoreTest" --tests "app.yahagi.kancollebrowser.browser.GameResourceCacheEngineTest" --no-daemon`

预期：PASS。

- [x] **步骤 6：提交缓存策略**

```bash
git add android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameResourceCacheStore.kt android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameResourceCacheEngine.kt android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameResourceCacheManager.kt android/app/src/main/kotlin/app/yahagi/kancollebrowser/MainActivity.kt android/app/src/test/kotlin/app/yahagi/kancollebrowser/browser/GameResourceCacheStoreTest.kt android/app/src/test/kotlin/app/yahagi/kancollebrowser/browser/GameResourceCacheEngineTest.kt
git commit -m "feat(缓存): 添加七天临时缓存策略"
```

### 任务 3：禁止临时模式预下载

**文件：**
- 修改：`lib/src/browser/game_resource_manifest_consumer.dart`
- 修改：`test/game_resource_manifest_consumer_test.dart`
- 修改：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameResourceDownloadCoordinator.kt`
- 修改：`android/app/src/test/kotlin/app/yahagi/kancollebrowser/browser/GameResourceDownloadCoordinatorTest.kt`

- [x] **步骤 1：编写失败的清单测试**

将原轻度清单测试替换为：临时模式收到 `start2` 后不调用 `setManifest`；完整模式仍提交 `full` 清单。Android 侧断言临时模式下 `startDownload()` 返回 `false`。

- [x] **步骤 2：运行测试确认失败**

运行：`flutter test test/game_resource_manifest_consumer_test.dart`

预期：FAIL，临时模式尚未被明确旁路。

- [x] **步骤 3：实现预下载旁路**

`GameResourceManifestConsumer._rebuild` 仅在 `full` 模式构建清单：

```dart
if (mode != GameResourceCacheMode.full) return;
```

删除运行时轻度清单分支；Android `startDownloadInternal` 仅允许 `FULL`：

```kotlin
if (mode != GameResourceCacheMode.FULL || urls.isEmpty()) return false
```

- [x] **步骤 4：运行清单与协调器测试**

运行：`flutter test test/game_resource_manifest_consumer_test.dart`

运行：`android/gradlew.bat :app:testDebugUnitTest --tests "app.yahagi.kancollebrowser.browser.GameResourceDownloadCoordinatorTest" --no-daemon`

预期：PASS。

- [x] **步骤 5：提交预下载边界**

```bash
git add lib/src/browser/game_resource_manifest_consumer.dart test/game_resource_manifest_consumer_test.dart android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameResourceDownloadCoordinator.kt android/app/src/test/kotlin/app/yahagi/kancollebrowser/browser/GameResourceDownloadCoordinatorTest.kt
git commit -m "fix(缓存): 禁止临时模式启动预下载"
```

### 任务 4：设置页与多语言文案

**文件：**
- 修改：`lib/src/settings/game_resource_cache_section.dart`
- 修改：`lib/l10n/app_zh.arb`
- 修改：`lib/l10n/app_zh_Hant.arb`
- 修改：`lib/l10n/app_ja.arb`
- 生成：`lib/l10n/app_localizations.dart`
- 生成：`lib/l10n/app_localizations_zh.dart`
- 生成：`lib/l10n/app_localizations_ja.dart`
- 修改：`test/game_resource_cache_section_test.dart`
- 修改：`test/data_settings_page_test.dart`

- [x] **步骤 1：编写失败的组件测试**

断言设置页显示「临时缓存」和新说明，并在临时模式下隐藏：

```dart
expect(find.byKey(const Key('cache-mode-temporary')), findsOneWidget);
expect(find.text('临时缓存'), findsOneWidget);
expect(find.textContaining('最多保留 7 天'), findsOneWidget);
expect(find.textContaining('不超过 1 GB'), findsOneWidget);
expect(find.byKey(const Key('cache-download-toggle')), findsNothing);
expect(find.byKey(const Key('cache-check-integrity')), findsNothing);
expect(find.byKey(const Key('cache-repair')), findsNothing);
expect(find.byKey(const Key('cache-clear')), findsOneWidget);
```

- [x] **步骤 2：运行测试确认失败**

运行：`flutter test test/game_resource_cache_section_test.dart test/data_settings_page_test.dart`

预期：FAIL，页面仍显示「无本地缓存」。

- [x] **步骤 3：更新界面与 ARB 文案**

复用现有本地化键，避免无意义 API 扩散：

```json
"gameResourceCacheDesc": "资源从舰队 Collection 官方服务器获取；缓存可随时清除。",
"gameResourceCacheNone": "临时缓存",
"gameResourceCacheNoneDesc": "不预下载资源；游玩时按需缓存，缓存最多保留 7 天且占用不超过 1 GB，过期或超出上限时将自动清理。"
```

繁体中文和日文采用等义表述。设置页将该 tile 绑定到 `GameResourceCacheMode.temporary`；下载、检查和修复操作仅在 `full` 模式显示。

- [x] **步骤 4：重新生成本地化代码**

运行：`flutter gen-l10n`

预期：`app_localizations*.dart` 与三个 ARB 文件一致。

- [x] **步骤 5：运行设置页测试**

运行：`flutter test test/game_resource_cache_section_test.dart test/data_settings_page_test.dart`

预期：PASS。

- [x] **步骤 6：提交设置页与文案**

```bash
git add lib/src/settings/game_resource_cache_section.dart lib/l10n/app_zh.arb lib/l10n/app_zh_Hant.arb lib/l10n/app_ja.arb lib/l10n/app_localizations.dart lib/l10n/app_localizations_zh.dart lib/l10n/app_localizations_ja.dart test/game_resource_cache_section_test.dart test/data_settings_page_test.dart
git commit -m "feat(设置): 将无缓存改为临时缓存"
```

### 任务 5：回归验证与收尾

**文件：**
- 修改：`docs/superpowers/specs/2026-09-05-temporary-game-resource-cache-design.md`
- 修改：`docs/superpowers/plans/2026-09-05-temporary-game-resource-cache.md`

- [x] **步骤 1：运行格式化与静态检查**

运行：`dart format lib/src/browser/game_resource_cache_store.dart lib/src/browser/game_resource_cache_channel.dart lib/src/browser/game_resource_cache_controller.dart lib/src/browser/game_resource_manifest_consumer.dart lib/src/settings/game_resource_cache_section.dart test/game_resource_cache_store_test.dart test/game_resource_cache_controller_test.dart test/game_resource_manifest_consumer_test.dart test/game_resource_cache_section_test.dart test/data_settings_page_test.dart`

运行：`flutter analyze`

预期：无错误。

- [x] **步骤 2：运行缓存相关 Flutter 测试**

运行：`flutter test test/game_resource_cache_store_test.dart test/game_resource_cache_controller_test.dart test/game_resource_manifest_consumer_test.dart test/game_resource_cache_section_test.dart test/data_settings_page_test.dart test/game_connector_cache_compatibility_test.dart`

预期：全部通过。

- [x] **步骤 3：运行缓存相关 Android 测试**

运行：`android/gradlew.bat :app:testDebugUnitTest --tests "app.yahagi.kancollebrowser.browser.GameResourceCacheStoreTest" --tests "app.yahagi.kancollebrowser.browser.GameResourceCacheEngineTest" --tests "app.yahagi.kancollebrowser.browser.GameResourceDownloadCoordinatorTest" --no-daemon`

预期：全部通过。若宿主机继续报 `Unable to establish loopback connection`，记录环境阻塞并改用已连接设备上的 Android instrumentation 测试验证可运行部分。

- [ ] **步骤 4：构建 Debug APK（被宿主机 Gradle 回环连接异常阻塞）**

运行：`flutter build apk --debug`

预期：生成 `build/app/outputs/flutter-apk/app-debug.apk`。

- [x] **步骤 5：检查变更范围**

运行：`git diff --check 23220e3..HEAD`、`git status --short`。

预期：无空白错误；不包含用户现有的 `test/ship_equipment_compatibility_drawer_test.dart`。

- [x] **步骤 6：提交规格勘误与计划状态**

```bash
git add -f docs/superpowers/specs/2026-09-05-temporary-game-resource-cache-design.md docs/superpowers/plans/2026-09-05-temporary-game-resource-cache.md
git commit -m "docs(缓存): 完成临时缓存实施记录"
```

## 实施记录

- 2026-09-05：缓存相关 Flutter 测试 25 项通过。
- 2026-09-05：缓存核心 Kotlin 源码使用项目锁定的 Kotlin 2.2.20 独立编译通过，相关 JUnit 测试 50 项通过。
- 2026-09-05：`flutter analyze` 返回成功；项目仍有 81 条既有 warning/info，本次改动文件未新增诊断。
- 2026-09-05：Gradle 单测与 Debug APK 构建在任务执行前被宿主机 `Unable to establish loopback connection` 阻塞，未进入 Kotlin/Android 构建阶段。
