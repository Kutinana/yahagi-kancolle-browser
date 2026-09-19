# 海域资料在线更新实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 将海域源资料迁入项目，生成可验证的 GitHub 更新包，并让用户在设置页手动下载、验证、原子启用新版海域资料。

**架构：** `data/sortie/source` 是唯一人工源，生成脚本同时产出应用内置快照和 GitHub Release 包。运行时由 Store 在内置/缓存之间选择，UpdateService 负责可信下载和校验，Controller 向设置页与海域查询页发布同一份活动目录；页面通过资源定位对象区分 `Image.asset` 和 `Image.file`。

**技术栈：** Flutter/Dart、`http`、`crypto`、`archive`、`path_provider`、Python 3、openpyxl、Pillow、GitHub Raw/Releases。

---

## 文件结构

- 创建 `data/sortie/source/kcwiki_出击_敌舰配置.xlsx`：项目内 Excel 源。
- 创建 `data/sortie/source/images/`：封面、路线图和图片清单源。
- 创建 `data/sortie/schema/catalog.schema.json`、`manifest.schema.json`：发布格式约束。
- 创建 `data/sortie/manifest.json`：GitHub 固定更新入口。
- 创建 `tool/build_sortie_release.py`：确定性 ZIP、摘要和清单生成器。
- 创建 `tool/test_build_sortie_release.py`：发布器回归测试。
- 修改 `tool/build_sortie_map_assets.py`：写入版本元数据并支持项目内默认源。
- 创建 `lib/src/toolbox/sortie_map_query/sortie_map_catalog_manifest.dart`：版本与清单模型。
- 创建 `lib/src/toolbox/sortie_map_query/sortie_map_catalog_store.dart`：内置/缓存选择、原子安装、恢复和资源定位。
- 创建 `lib/src/toolbox/sortie_map_query/sortie_map_catalog_update_service.dart`：检查、下载、校验和错误分类。
- 创建 `lib/src/toolbox/sortie_map_query/sortie_map_catalog_controller.dart`：去重更新、活动资料和通知。
- 修改 `lib/src/toolbox/sortie_map_query/sortie_map_models.dart`：解析目录版本元数据并加强结构校验。
- 修改 `lib/src/toolbox/sortie_map_query/sortie_map_query_page.dart`：由 Controller 读取活动目录并加载 asset/file 图片。
- 修改 `lib/src/toolbox/toolbox_page.dart`、`lib/main.dart`：注入同一 Controller。
- 创建 `lib/src/settings/sortie_map_catalog_update_section.dart`；修改数据设置页和本地化资源：提供手动更新入口。
- 创建 `test/sortie_map_catalog_manifest_test.dart`、`sortie_map_catalog_store_test.dart`、`sortie_map_catalog_update_service_test.dart`、`sortie_map_catalog_controller_test.dart`、`sortie_map_catalog_update_section_test.dart`。
- 修改 `.gitignore`、`pubspec.yaml` 和现有海域测试。

### 任务 1：迁移源资料并固定目录格式

**文件：**
- 创建：`data/sortie/source/**`
- 创建：`data/sortie/schema/catalog.schema.json`
- 创建：`data/sortie/schema/manifest.schema.json`
- 修改：`.gitignore`
- 修改：`tool/test_build_sortie_map_assets.py`
- 修改：`tool/build_sortie_map_assets.py`

- [ ] **步骤 1：先扩展生成器测试，要求无参数默认读取项目内源目录，并在目录根写出 `schemaVersion/dataVersion/revision/publishedAt`**

```python
self.assertEqual(catalog["schemaVersion"], 1)
self.assertEqual(catalog["dataVersion"], "2026.09.20")
self.assertEqual(catalog["revision"], 2026092001)
```

- [ ] **步骤 2：运行红灯测试**

运行：`python -m unittest tool.test_build_sortie_map_assets -v`
预期：FAIL，当前目录没有版本元数据和项目内默认路径。

- [ ] **步骤 3：移动并核验源资料**

将 `G:\日常AI工作\kcwiki_出击_敌舰配置.xlsx` 与 `G:\日常AI工作\kcwiki_海域图片` 移入 `data/sortie/source/`；移动前后比较工作簿 SHA-256、图片文件数量与各文件 SHA-256。目标确认完整后才移除源路径。

- [ ] **步骤 4：实现生成参数与 JSON Schema**

```python
catalog = {
    "schemaVersion": 1,
    "dataVersion": data_version,
    "revision": revision,
    "publishedAt": published_at,
    "source": "https://zh.kcwiki.cn/wiki/出击",
    "maps": maps,
}
```

`data/sortie/dist/` 加入 `.gitignore`，源文件和 Schema 不忽略。

- [ ] **步骤 5：运行生成器测试并重新生成内置快照**

运行：`python -m unittest tool.test_build_sortie_map_assets -v`
预期：PASS。

运行：`python tool/build_sortie_map_assets.py --data-version 2026.09.20 --revision 2026092001 --published-at 2026-09-20T00:00:00Z`
预期：输出地图、节点和编成计数，生成 `assets/data/sortie_map_catalog.json` 与图片。

### 任务 2：生成确定性 GitHub 发布包

**文件：**
- 创建：`tool/build_sortie_release.py`
- 创建：`tool/test_build_sortie_release.py`
- 创建：`data/sortie/manifest.json`

- [ ] **步骤 1：编写发布器失败测试**

```python
self.assertEqual(manifest["revision"], 2026092001)
self.assertEqual(manifest["archive"]["sha256"], hashlib.sha256(zip_bytes).hexdigest())
self.assertEqual(zip_file.namelist(), sorted(zip_file.namelist()))
self.assertNotIn("assets/images/sortie_maps/", archived_catalog)
```

- [ ] **步骤 2：运行红灯测试**

运行：`python -m unittest tool.test_build_sortie_release -v`
预期：FAIL，发布器尚不存在。

- [ ] **步骤 3：实现发布器**

发布器读取已生成内置目录，将图片引用规范化为 `covers/<id>.png` 与 `maps/<id>.png`，检查引用齐全，以固定条目顺序和固定时间戳生成 ZIP，然后原子写入 `data/sortie/manifest.json`。

- [ ] **步骤 4：验证发布器**

运行：`python -m unittest tool.test_build_sortie_release -v`
预期：PASS。

运行：`python tool/build_sortie_release.py`
预期：生成 `data/sortie/dist/sortie-data-2026.09.20.zip`，清单计数、字节数和摘要匹配。

### 任务 3：版本模型、目录校验和资源定位

**文件：**
- 创建：`lib/src/toolbox/sortie_map_query/sortie_map_catalog_manifest.dart`
- 修改：`lib/src/toolbox/sortie_map_query/sortie_map_models.dart`
- 测试：`test/sortie_map_catalog_manifest_test.dart`
- 测试：`test/sortie_map_models_test.dart`

- [ ] **步骤 1：编写版本、兼容性和坏目录失败测试**

```dart
expect(manifest.revision, 2026092001);
expect(manifest.isCompatibleWith('1.0.8'), isTrue);
expect(() => parseCatalog(duplicateMapIds), throwsFormatException);
expect(() => parseCatalog(missingImageReference), throwsFormatException);
```

- [ ] **步骤 2：运行红灯测试**

运行：`flutter test test/sortie_map_catalog_manifest_test.dart test/sortie_map_models_test.dart`
预期：FAIL，模型和校验尚未实现。

- [ ] **步骤 3：实现最小模型**

```dart
final class SortieMapCatalogVersion implements Comparable<SortieMapCatalogVersion> {
  const SortieMapCatalogVersion({required this.label, required this.revision});
  final String label;
  final int revision;
  @override
  int compareTo(SortieMapCatalogVersion other) => revision.compareTo(other.revision);
}
```

目录解析校验唯一海域、唯一节点、非空编成结构和安全相对图片引用。

- [ ] **步骤 4：运行模型测试**

运行：`flutter test test/sortie_map_catalog_manifest_test.dart test/sortie_map_models_test.dart`
预期：PASS。

### 任务 4：实现本地存储、ZIP 安装与回退

**文件：**
- 创建：`lib/src/toolbox/sortie_map_query/sortie_map_catalog_store.dart`
- 修改：`pubspec.yaml`
- 测试：`test/sortie_map_catalog_store_test.dart`

- [ ] **步骤 1：添加 `archive` 直接依赖并编写 Store 失败测试**

```dart
expect((await store.loadBestAvailable()).source, SortieMapCatalogSource.cache);
expect((await brokenStore.loadBestAvailable()).source, SortieMapCatalogSource.bundled);
expect(() => storage.install(pathTraversalZip, manifest), throwsFormatException);
```

- [ ] **步骤 2：运行红灯测试**

运行：`flutter test test/sortie_map_catalog_store_test.dart`
预期：FAIL，Store 尚不存在。

- [ ] **步骤 3：实现 Store 和 Application Storage**

```dart
sealed class SortieMapResourceLocation { const SortieMapResourceLocation(); }
final class BundledSortieMapResource extends SortieMapResourceLocation { final String assetPath; }
final class CachedSortieMapResource extends SortieMapResourceLocation { final String filePath; }
```

安装时限制条目数、路径、类型、单文件和解压总大小；暂存验证成功后改名为版本目录，原子写 `active.json`，保留上一版本并清理临时目录。

- [ ] **步骤 4：运行 Store 测试**

运行：`flutter test test/sortie_map_catalog_store_test.dart`
预期：PASS，包括写入失败仍保留旧缓存和中断恢复。

### 任务 5：实现网络更新服务和控制器

**文件：**
- 创建：`lib/src/toolbox/sortie_map_query/sortie_map_catalog_update_service.dart`
- 创建：`lib/src/toolbox/sortie_map_query/sortie_map_catalog_controller.dart`
- 测试：`test/sortie_map_catalog_update_service_test.dart`
- 测试：`test/sortie_map_catalog_controller_test.dart`

- [ ] **步骤 1：编写更新服务红灯测试**

```dart
expect(result, isA<SortieMapCatalogUpdated>());
expect(requestedHosts, containsAllInOrder(['raw.githubusercontent.com', 'cdn.jsdelivr.net']));
expect(await storage.activeRevision(), 2026092001);
```

覆盖同版本、降级、最低 App 版本、摘要不符、超限、超时、HTTP错误、存储失败和重复点击只发起一次请求。

- [ ] **步骤 2：运行红灯测试**

运行：`flutter test test/sortie_map_catalog_update_service_test.dart test/sortie_map_catalog_controller_test.dart`
预期：FAIL。

- [ ] **步骤 3：实现允许列表网络服务**

清单地址固定为当前项目 GitHub Raw/jsDelivr；Release URL 只能由固定仓库、合法标签和附件名组成。请求设置总时限、字节上限和 User-Agent；下载后先验证 SHA-256，再交给 Store 安装。

- [ ] **步骤 4：实现 Controller**

```dart
Future<SortieMapCatalogUpdateResult> checkForUpdates() {
  if (_activeCheck case final active?) return active;
  _activeCheck = _performCheck();
  notifyListeners();
  return _activeCheck!;
}
```

- [ ] **步骤 5：运行服务与控制器测试**

运行：`flutter test test/sortie_map_catalog_update_service_test.dart test/sortie_map_catalog_controller_test.dart`
预期：PASS。

### 任务 6：接入海域查询页面并即时刷新

**文件：**
- 修改：`lib/src/toolbox/sortie_map_query/sortie_map_query_page.dart`
- 修改：`lib/src/toolbox/toolbox_page.dart`
- 修改：`lib/main.dart`
- 测试：`test/sortie_map_query_page_test.dart`
- 测试：`test/toolbox_page_test.dart`

- [ ] **步骤 1：编写页面失败测试**

```dart
expect(find.byKey(const Key('sortie-map-file-image')), findsOneWidget);
controller.replaceForTest(updatedCatalog);
await tester.pump();
expect(find.text('8-1 新海域'), findsOneWidget);
expect(store.lastSelection, const SortieMapSelection(mapId: '8-1', nodePoint: 'A'));
```

- [ ] **步骤 2：运行红灯测试**

运行：`flutter test test/sortie_map_query_page_test.dart test/toolbox_page_test.dart`
预期：FAIL。

- [ ] **步骤 3：注入 Controller 并实现资源组件**

`main()` 初始化 Store/Controller，向设置页和 `ToolboxPage` 传递同一实例。页面监听 Controller，更新时保留有效选择，缺失节点回退 A/首节点；`_CatalogImage` 根据资源定位使用 `Image.asset` 或 `Image.file`。

- [ ] **步骤 4：运行页面测试**

运行：`flutter test test/sortie_map_query_page_test.dart test/toolbox_page_test.dart`
预期：PASS。

### 任务 7：设置页更新入口与本地化

**文件：**
- 创建：`lib/src/settings/sortie_map_catalog_update_section.dart`
- 修改：`lib/src/settings/data_settings_page.dart`
- 修改：`lib/src/settings/settings_page.dart`
- 修改：`lib/l10n/app_zh.arb`、`app_zh_Hant.arb`、`app_ja.arb`
- 生成：`lib/l10n/app_localizations*.dart`
- 测试：`test/sortie_map_catalog_update_section_test.dart`

- [ ] **步骤 1：编写设置区块失败测试**

```dart
expect(find.text('海域资料'), findsOneWidget);
await tester.tap(find.byKey(const Key('sortie-catalog-check-updates')));
expect(find.textContaining('已立即生效'), findsOneWidget);
```

- [ ] **步骤 2：运行红灯测试**

运行：`flutter test test/sortie_map_catalog_update_section_test.dart`
预期：FAIL。

- [ ] **步骤 3：实现区块与三语文案**

展示版本、来源、上次检查时间和检查按钮；区分最新、成功、不兼容、网络、验证、存储错误。运行 `flutter gen-l10n` 生成本地化代码。

- [ ] **步骤 4：运行设置测试**

运行：`flutter test test/sortie_map_catalog_update_section_test.dart`
预期：PASS。

### 任务 8：整体验证、严格审查、提交和 GitHub 发布

**文件：**
- 修改：所有上述文件

- [ ] **步骤 1：完整自动化验证**

运行：`python -m unittest tool.test_build_sortie_map_assets tool.test_build_sortie_release -v`

运行：`flutter test test/sortie_map_catalog_manifest_test.dart test/sortie_map_catalog_store_test.dart test/sortie_map_catalog_update_service_test.dart test/sortie_map_catalog_controller_test.dart test/sortie_map_catalog_update_section_test.dart test/sortie_map_catalog_test.dart test/sortie_map_models_test.dart test/sortie_map_query_page_test.dart test/sortie_map_selection_store_test.dart test/toolbox_page_test.dart`

运行：`flutter analyze lib/src/toolbox/sortie_map_query lib/src/settings/sortie_map_catalog_update_section.dart lib/src/settings/data_settings_page.dart lib/src/settings/settings_page.dart lib/main.dart test/sortie_map_catalog*_test.dart test/sortie_map_query_page_test.dart`

预期：全部退出码为 0，无失败、无分析问题。

- [ ] **步骤 2：设备验证**

在现有 DEBUG 会话中 Hot Restart，验证设置页状态、同版本检查、海域页面横竖屏/HD/折叠屏布局、选择记忆及缓存图片加载。本任务不构建 APK/AAB。

- [ ] **步骤 3：魔鬼审查与修复**

让独立审查代理检查安全边界、原子性、回退、并发、路径穿越、下载限制、版本比较、UI刷新和测试缺口；逐项修复后重新执行步骤 1，并取得 `[APPROVED]`。

- [ ] **步骤 4：精确提交**

只暂存本计划涉及的新文件和必要集成 hunks；用 `git diff --cached --check`、`git diff --cached --name-only` 和 `git show --stat` 确认未混入其他工作。

- [ ] **步骤 5：推送与发布资料**

推送 `master` 到 `origin`。创建 `sortie-data-2026.09.20` Release 并上传 `data/sortie/dist/sortie-data-2026.09.20.zip`；从公开 Raw 清单和 Release 地址重新下载，核对 SHA-256 后报告完成。
