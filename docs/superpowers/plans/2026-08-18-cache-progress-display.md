# 本地缓存进度精简显示实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 缓存设置区只显示已下载容量和完成百分比，并隐藏缺失、损坏、过期统计。

**架构：** 保留原生缓存状态与完整性检查数据，只修改 Flutter 展示层。控制器负责格式化容量与百分比；设置组件不再渲染完整性统计文本，但继续依据状态决定是否显示修复按钮。

**技术栈：** Dart、Flutter、flutter_test

---

## 文件结构

- 修改 `lib/src/browser/game_resource_cache_controller.dart`：将完整度文案格式改为“已下载容量（百分比）”。
- 修改 `lib/src/settings/game_resource_cache_section.dart`：移除完整性统计文本渲染。
- 修改 `test/game_resource_cache_controller_test.dart`：锁定已知与未知总量格式。
- 修改 `test/game_resource_cache_section_test.dart`：锁定精简文案和隐藏统计行为。

### 任务 1：精简进度文案

**文件：**
- 修改：`test/game_resource_cache_controller_test.dart`
- 修改：`lib/src/browser/game_resource_cache_controller.dart`

- [ ] **步骤 1：编写失败的测试**

```dart
expect(formatCacheCompleteness(6840000000, 8120000000), '6.84 GB（84.2%）');
expect(controller.completenessLine, '0.00 GB（--）');
```

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/game_resource_cache_controller_test.dart`

预期：FAIL，实际文本仍包含 `/ 8.12 GB` 或 `/ --`。

- [ ] **步骤 3：编写最少实现代码**

```dart
String formatCacheCompleteness(int cachedBytes, int targetBytes) {
  final cachedGb = cachedBytes / 1000000000;
  final percent = targetBytes <= 0
      ? 0.0
      : (cachedBytes / targetBytes * 100).clamp(0.0, 100.0);
  return '${cachedGb.toStringAsFixed(2)} GB（${percent.toStringAsFixed(1)}%）';
}
```

未知总量时由 `completenessLine` 返回 `${cachedGb} GB（--）`。

- [ ] **步骤 4：运行测试验证通过**

运行：`flutter test test/game_resource_cache_controller_test.dart`

预期：全部 PASS。

### 任务 2：隐藏完整性统计

**文件：**
- 修改：`test/game_resource_cache_section_test.dart`
- 修改：`lib/src/settings/game_resource_cache_section.dart`

- [ ] **步骤 1：编写失败的组件测试**

```dart
expect(find.text('6.84 GB（84.2%）'), findsOneWidget);
expect(find.textContaining('/ 8.12 GB'), findsNothing);
await tester.tap(find.byKey(const Key('cache-check-integrity')));
await tester.pump();
expect(find.byKey(const Key('cache-integrity-result')), findsNothing);
expect(find.textContaining('缺失 3'), findsNothing);
expect(find.textContaining('损坏 1'), findsNothing);
expect(find.textContaining('过期 2'), findsNothing);
expect(find.byKey(const Key('cache-repair')), findsOneWidget);
```

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/game_resource_cache_section_test.dart`

预期：FAIL，旧完整性统计仍可见。

- [ ] **步骤 3：编写最少实现代码**

删除构建树中的 `if (_integrityChecked) _integrityResult(l10n, status)`，并删除不再使用的 `_integrityResult` 方法；保留 `_integrityChecked` 和修复按钮条件。

- [ ] **步骤 4：运行测试验证通过**

运行：`flutter test test/game_resource_cache_section_test.dart`

预期：全部 PASS。

### 任务 3：回归验证与提交

**文件：**
- 验证上述四个文件

- [ ] **步骤 1：运行缓存界面回归测试**

运行：`flutter test test/game_resource_cache_controller_test.dart test/game_resource_cache_section_test.dart`

预期：全部 PASS。

- [ ] **步骤 2：构建 Debug APK**

运行：`flutter build apk --debug`

预期：构建成功并生成 `build/app/outputs/flutter-apk/app-debug.apk`。

- [ ] **步骤 3：检查并提交限定文件**

```powershell
git diff --check -- lib/src/browser/game_resource_cache_controller.dart lib/src/settings/game_resource_cache_section.dart test/game_resource_cache_controller_test.dart test/game_resource_cache_section_test.dart
git add -- lib/src/browser/game_resource_cache_controller.dart lib/src/settings/game_resource_cache_section.dart test/game_resource_cache_controller_test.dart test/game_resource_cache_section_test.dart
git commit -m "fix(缓存): 精简缓存进度显示"
```
