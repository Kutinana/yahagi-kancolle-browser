# 游戏资源缓存误判与状态提示实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 修复完整清单资源被 6 小时 TTL 误判的问题，并在设置页明确区分“待校验”和“已删除”。

**架构：** Android 缓存引擎仅在调用方没有提供精确长度时对无版本资源应用 TTL。Flutter 设置页继续使用现有状态模型，在用户主动执行完整性检查后展示紧凑结果，并通过本地化文案说明待校验文件仍保留。

**技术栈：** Kotlin、JUnit 4、Flutter、Dart、Flutter Widget Test、ARB 本地化。

---

## 文件结构

- 修改：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameResourceCacheEngine.kt`，收窄 TTL 判定条件。
- 修改：`android/app/src/test/kotlin/app/yahagi/kancollebrowser/browser/GameResourceCacheEngineTest.kt`，覆盖带清单长度与无清单长度的过期边界。
- 修改：`lib/src/settings/game_resource_cache_section.dart`，显示容量标签、完整性结果和待校验说明。
- 修改：`lib/l10n/app_zh.arb`、`lib/l10n/app_zh_Hant.arb`、`lib/l10n/app_ja.arb`，新增容量标签和待校验说明。
- 生成：`lib/l10n/app_localizations.dart`、`lib/l10n/app_localizations_zh.dart`、`lib/l10n/app_localizations_ja.dart`，同步 ARB 接口。
- 修改：`test/game_resource_cache_section_test.dart`，覆盖容量标签和完整性提示。

### 任务 1：修复清单资源 TTL 误判

**文件：**
- 修改：`android/app/src/test/kotlin/app/yahagi/kancollebrowser/browser/GameResourceCacheEngineTest.kt:100-163`
- 修改：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameResourceCacheEngine.kt:126-134`

- [ ] **步骤 1：编写失败的 JVM 回归测试**

```kotlin
@Test
fun `manifest length keeps unversioned resource valid after ttl`() {
    var now = 1L
    val fetcher = QueueFetcher(result(byteArrayOf(1)))
    val engine = engine(fetcher, clock = { now })
    val url = official("/kcs2/resources/a.png")

    engine.fetch(url, expectedLength = 1)
    now += GameResourceCacheEngine.UNVERSIONED_TTL_MS

    assertEquals(
        GameResourceInspectionState.VALID,
        engine.inspectMetadata(url, expectedLength = 1).state,
    )
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：

```powershell
./android/gradlew.bat -p android :app:testDebugUnitTest --tests "app.yahagi.kancollebrowser.browser.GameResourceCacheEngineTest.manifest length keeps unversioned resource valid after ttl" --console=plain
```

预期：FAIL，实际状态为 `OUTDATED`，期望为 `VALID`。

- [ ] **步骤 3：实施最小修复**

```kotlin
entry != null && expectedLength == null && entry.version == null &&
    clock() - entry.lastValidatedAt >= UNVERSIONED_TTL_MS ->
    GameResourceInspectionState.OUTDATED
```

- [ ] **步骤 4：运行引擎测试确认通过**

```powershell
./android/gradlew.bat -p android :app:testDebugUnitTest --tests "app.yahagi.kancollebrowser.browser.GameResourceCacheEngineTest" --console=plain
```

预期：`BUILD SUCCESSFUL`，原有无精确长度 TTL 测试也继续通过。

- [ ] **步骤 5：提交 Android 修复**

```powershell
git add android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameResourceCacheEngine.kt android/app/src/test/kotlin/app/yahagi/kancollebrowser/browser/GameResourceCacheEngineTest.kt
git commit -m "fix(缓存): 避免基础清单资源被误判过期"
```

### 任务 2：明确缓存容量与待校验提示

**文件：**
- 修改：`test/game_resource_cache_section_test.dart:16-77`
- 修改：`lib/src/settings/game_resource_cache_section.dart:83-149`
- 修改：`lib/l10n/app_zh.arb:639-665`
- 修改：`lib/l10n/app_zh_Hant.arb:639-665`
- 修改：`lib/l10n/app_ja.arb:639-665`
- 生成：`lib/l10n/app_localizations.dart`
- 生成：`lib/l10n/app_localizations_zh.dart`
- 生成：`lib/l10n/app_localizations_ja.dart`

- [ ] **步骤 1：编写失败的 Widget 测试**

容量断言改为：

```dart
expect(find.text('已缓存 6.84 GB'), findsOneWidget);
```

完整性检查后断言：

```dart
expect(find.byKey(const Key('cache-integrity-result')), findsOneWidget);
expect(find.textContaining('缺失 3'), findsOneWidget);
expect(find.textContaining('损坏 1'), findsOneWidget);
expect(find.textContaining('待校验 2'), findsOneWidget);
expect(find.textContaining('仍保留在本地'), findsOneWidget);
```

让 `_FakePort.value` 返回 `outdatedCount: 2`。

- [ ] **步骤 2：运行 Widget 测试验证失败**

```powershell
G:\DevTools\flutter\bin\flutter.bat test test/game_resource_cache_section_test.dart
```

预期：FAIL，容量缺少“已缓存”，且完整性结果块尚不存在。

- [ ] **步骤 3：新增本地化文案并生成代码**

三个 ARB 文件新增对应语言的以下键：

```json
"gameResourceCacheStoredSize": "已缓存 {size}",
"gameResourceCacheIntegritySummary": "缺失 {missing} 项 · 损坏 {damaged} 项 · 待校验 {pending} 项",
"gameResourceCachePendingRetained": "待校验资源仍保留在本地，不会自动删除。"
```

将现有 `gameResourceCacheOutdated` 的简体中文值改为“待校验”，繁体中文和日文使用对应自然表达。运行：

```powershell
G:\DevTools\flutter\bin\flutter.bat gen-l10n
```

- [ ] **步骤 4：实现容量标签与结果块**

容量使用：

```dart
l10n.gameResourceCacheStoredSize(controller.completenessLine)
```

仅当 `_integrityChecked` 且存在异常时，在操作区后显示 `cache-integrity-result`，内容为 `gameResourceCacheIntegritySummary(...)`；`outdatedCount > 0` 时额外显示 `gameResourceCachePendingRetained`。

- [ ] **步骤 5：运行 Widget 测试与本地化审计**

```powershell
G:\DevTools\flutter\bin\flutter.bat test test/game_resource_cache_section_test.dart test/localization_resource_audit_test.dart
```

预期：全部测试通过。

- [ ] **步骤 6：提交界面与文案修复**

```powershell
git add lib/src/settings/game_resource_cache_section.dart lib/l10n test/game_resource_cache_section_test.dart
git commit -m "fix(缓存): 明确缓存容量与待校验状态"
```

### 任务 3：完整验证

**文件：**
- 验证：所有本次修改文件。

- [ ] **步骤 1：运行全部 Kotlin 单元测试**

```powershell
./android/gradlew.bat -p android :app:testDebugUnitTest --console=plain
```

预期：`BUILD SUCCESSFUL`。

- [ ] **步骤 2：运行 Flutter 静态分析与全部测试**

```powershell
G:\DevTools\flutter\bin\flutter.bat analyze
G:\DevTools\flutter\bin\flutter.bat test
```

预期：静态分析无错误，全部测试通过。

- [ ] **步骤 3：检查变更范围**

```powershell
git diff HEAD~2 --check
git status --short
```

预期：无空白错误；工作区没有遗漏的实现文件。

