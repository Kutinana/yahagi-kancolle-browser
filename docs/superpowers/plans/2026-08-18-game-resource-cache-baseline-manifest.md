# 游戏资源缓存基础清单实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 保留轻量与完整缓存模式，将完整缓存改为约 5.8 GB 的固定官方资源基础清单，并将统一 LRU 容量提高到十进制 50 GB。

**架构：** 构建期工具把 `cached.json` 转换成经过校验、稳定排序的 Gzip 清单资源；Flutter 独立 Isolate 在完整模式下解析该清单并映射官方域名，轻量模式继续解析 `api_start2`。Android 缓存引擎统一在写入前执行 LRU，下载协调器对单项 404 静默跳过并继续队列。

**技术栈：** Flutter/Dart、Android/Kotlin、Flutter AssetBundle、JSON + Gzip、JUnit、flutter_test。

---

## 文件结构

- 创建 `tool/build_game_resource_baseline_manifest.dart`：转换外部索引。
- 创建 `assets/data/game_resource_baseline_manifest.json.gz`：内置路径、版本和长度。
- 创建 `lib/src/browser/game_resource_baseline_catalog.dart`：加载、校验并映射官方 URL。
- 创建对应 Flutter 测试：覆盖转换、解析、真实资产摘要和消费者集成。
- 修改 manifest consumer/builder、`main.dart` 和 `pubspec.yaml`：完整模式改用固定资产。
- 修改 Android rules/store/engine/coordinator：新增允许路径、50 GB 和统一 LRU。
- 修改本地化文件和设置页测试：说明固定约 5.8 GB 清单和 50 GB 上限。

### 任务 1：构建期基础清单转换器

**文件：**
- 创建：`tool/build_game_resource_baseline_manifest.dart`
- 创建：`test/game_resource_baseline_manifest_tool_test.dart`
- 创建：`assets/data/game_resource_baseline_manifest.json.gz`

- [ ] **步骤 1：编写失败的转换器测试**

```dart
test('converter validates deduplicates and sorts baseline entries', () {
  final converted = convertBaselineIndex(<String, Object?>{
    '/kcs2/img/b.png': <String, Object?>{'version': '?v=2', 'length': 2},
    '/kcs2/img/a.png': <String, Object?>{'version': '?v=1', 'length': 1},
    '/kcsapi/api_port/port': <String, Object?>{'length': 9},
  });
  expect(converted.entryCount, 2);
  expect(converted.targetBytes, 3);
  expect(converted.entries.map((entry) => entry.path), <String>[
    '/kcs2/img/a.png',
    '/kcs2/img/b.png',
  ]);
});
```

- [ ] **步骤 2：运行测试验证红灯**

运行：`flutter test test/game_resource_baseline_manifest_tool_test.dart`

预期：FAIL，转换器尚不存在。

- [ ] **步骤 3：实现最小转换器**

实现 `convertBaselineIndex(Map<String, Object?> source)`。仅接受 5 个允许前缀，规范化版本字符串，将长度限制为非负整数，按路径和版本去重并排序。CLI 输出含 schema、条目数、目标字节、SHA-256 和紧凑 entries 的 Gzip JSON。

- [ ] **步骤 4：验证绿灯并生成真实资产**

运行测试后执行：

```powershell
dart run tool/build_game_resource_baseline_manifest.dart "G:\迅雷下载\cache-2026-01-09\cache\cached.json" assets/data/game_resource_baseline_manifest.json.gz
```

预期：63,434 条、目标约 5.74 GB、压缩体积约 0.8 MB。

- [ ] **步骤 5：提交**

```bash
git add tool/build_game_resource_baseline_manifest.dart test/game_resource_baseline_manifest_tool_test.dart assets/data/game_resource_baseline_manifest.json.gz
git commit -m "feat(缓存): 添加固定基础清单资产"
```

### 任务 2：运行时固定完整清单

**文件：**
- 创建：`lib/src/browser/game_resource_baseline_catalog.dart`
- 创建：`test/game_resource_baseline_catalog_test.dart`
- 修改：`lib/src/browser/game_resource_manifest_consumer.dart`
- 修改：`lib/src/browser/game_resource_manifest_builder.dart`
- 修改：`lib/main.dart`
- 修改：`pubspec.yaml`
- 修改：`test/game_resource_manifest_consumer_test.dart`
- 修改：`test/game_resource_manifest_builder_test.dart`

- [ ] **步骤 1：编写失败的目录解析测试**

断言 `/kcs`、`/kcs2` 使用当前资源域，其他 3 类路径使用 `w00g`，版本参数得到保留，目标字节使用索引真实长度；损坏 Gzip、错误 schema 和非法路径必须拒绝。

- [ ] **步骤 2：运行测试验证红灯**

运行：`flutter test test/game_resource_baseline_catalog_test.dart`

预期：FAIL，目录加载器尚不存在。

- [ ] **步骤 3：实现目录加载器**

提供以下接口：

```dart
static Future<Uint8List> loadCompressed({AssetBundle? bundle});
static GameResourceManifest decode(
  Uint8List compressed, {
  required String resourceOrigin,
});
```

解析只在 manifest worker Isolate 内执行。

- [ ] **步骤 4：编写消费者红灯测试**

为 consumer 注入 `baselineLoader`。full 模式断言提交固定 fixture 清单，且 `api_start2` 中额外舰娘、家具和声音不进入完整清单。

- [ ] **步骤 5：运行消费者测试验证红灯**

运行：`flutter test test/game_resource_manifest_consumer_test.dart`

预期：FAIL，当前 full 仍调用理论枚举。

- [ ] **步骤 6：接入固定清单**

full 模式异步加载压缩资产并交给 worker，worker 跳过 `api_start2` 解码；light 保持动态构建。删除 `buildFull` 和仅服务理论全量枚举的分支。在 `pubspec.yaml` 注册资产并在 `main.dart` 注入加载器。

- [ ] **步骤 7：验证并提交**

运行：

```powershell
flutter test test/game_resource_baseline_catalog_test.dart test/game_resource_manifest_builder_test.dart test/game_resource_manifest_consumer_test.dart
```

全部 PASS 后提交 `feat(缓存): 完整模式使用固定基础清单`。

### 任务 3：50 GB 统一 LRU 与静态路径

**文件：**
- 修改：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameResourceCacheRules.kt`
- 修改：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameResourceCacheStore.kt`
- 修改：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameResourceCacheEngine.kt`
- 修改：`android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/GameResourceDownloadCoordinator.kt`
- 修改：相关 Android 单元测试。

- [ ] **步骤 1：编写 Android 红灯测试**

增加断言：默认容量为 `50_000_000_000L`；full 写入空间不足时淘汰最旧文件；`/html/maintenance.png` 和 `/kcscontents/image/a.png` 可缓存；第 1 个 URL 返回 404 时仍请求并缓存第 2 个 URL。

- [ ] **步骤 2：运行测试验证红灯**

运行目标 `GameResourceCache*Test` 与 `GameResourceDownloadCoordinatorTest`，预期容量、full LRU 和新增路径失败。

- [ ] **步骤 3：实现最小 Android 改动**

- 将默认容量改为 `50_000_000_000L`。
- 允许 `/html/` 和 `/kcscontents/` 的受控静态扩展名。
- 所有启用缓存的模式写入前调用 LRU 预留空间。
- 删除 full 模式容量硬阻塞分支。
- 保持 `engine.fetch(url) ?: continue`，单项 404 不提示、不终止队列。

- [ ] **步骤 4：验证并提交**

运行：`android\.\gradlew.bat :app:testDebugUnitTest`

预期：BUILD SUCCESSFUL。提交 `feat(缓存): 使用 50GB 统一 LRU 策略`。

### 任务 4：设置页语义

**文件：**
- 修改：`lib/l10n/app_*.arb`
- 生成：`lib/l10n/app_localizations*.dart`
- 修改：`test/game_resource_cache_section_test.dart`

- [ ] **步骤 1：编写 UI 红灯测试**

完整模式断言显示「约 5.8 GB」和「固定基础资源清单」，容量提示包含「50 GB」，并保留 3 个模式选项。

- [ ] **步骤 2：运行测试验证红灯**

运行：`flutter test test/game_resource_cache_section_test.dart`

预期：FAIL，当前仍显示理论全量和 10 GB。

- [ ] **步骤 3：更新并生成本地化代码**

中文核心文案：

```json
"gameResourceCacheFullDesc": "预下载固定基础资源清单，约 5.8 GB；新内容会在游玩时自动缓存。",
"gameResourceCacheCapacityBlocked": "本地游戏资源缓存已达到 50 GB 上限。"
```

同步其他语言后运行 `flutter gen-l10n`。

- [ ] **步骤 4：验证并提交**

运行设置页和本地化契约测试。提交 `feat(缓存): 更新基础清单与容量说明`。

### 任务 5：集成验证与审查

- [ ] **步骤 1：格式化和静态检查**

运行 `dart format` 和缓存相关 `flutter analyze`，预期无新增问题。

- [ ] **步骤 2：运行全部缓存目标测试**

运行全部 `game_resource_*` Flutter 测试，预期全部 PASS。

- [ ] **步骤 3：运行 Android 全量测试**

运行 `android\.\gradlew.bat :app:testDebugUnitTest`，预期 BUILD SUCCESSFUL。

- [ ] **步骤 4：运行全量 Flutter 测试与 APK 构建**

运行 `flutter test` 和 `flutter build apk --debug`。记录任何已存在且与缓存无关的失败。

- [ ] **步骤 5：代码审查**

检查清单不含游戏二进制、URL 仅指向官方域、真实长度正确、404 不终止队列、50 GB LRU 安全、主线程不解析大清单、模式 epoch 竞态不回归。

- [ ] **步骤 6：修复审查问题并复验**

Critical/Important 问题必须先增加失败测试，再最小修复并复验。

- [ ] **步骤 7：最终提交检查**

仅暂存本计划相关文件，运行 `git diff --cached --check`，确认其他工作区改动仍未被暂存。
