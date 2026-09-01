# noro6 国内镜像导出实现计划

> **For Codex:** REQUIRED SUB-SKILL: Use subagent-driven-development to implement this plan task-by-task.

**Goal:** 在舰队导出页增加“导出至 noro6（国内镜像）”按钮，以与官方 noro6 完全相同的导入数据打开 `https://noro6.kcwiki.cn/`。

**Architecture:** 为外部舰队工具增加独立的 `noro6Mirror` 目标，官方站和镜像站共用同一个 noro6 导入 JSON 构造过程，只根据目标选择基础 URL。UI 在官方 noro6 与 Jervis 之间增加同样式按钮，并继续通过系统默认浏览器打开。

**Tech Stack:** Flutter、Dart、flutter_test、ARB/gen-l10n、url_launcher

---

### Task 1: 增加国内镜像 URI 目标并复用导入载荷

**Files:**
- Modify: `test/external_fleet_tool_launcher_test.dart`
- Modify: `lib/src/toolbox/external_fleet_tool_launcher.dart`

**Step 1: Write the failing test**

增加测试，要求 `ExternalFleetTool.noro6Mirror` 生成 HTTPS URI，host 为 `noro6.kcwiki.cn`、path 为 `/`、fragment 以 `import:` 开头；同一状态下，官方站与镜像站的 fragment 必须完全相同。

**Step 2: Run test to verify it fails**

Run: `flutter test test/external_fleet_tool_launcher_test.dart`
Expected: FAIL，因为 `noro6Mirror` 尚不存在。

**Step 3: Write minimal implementation**

在枚举中加入 `noro6Mirror`。提取共用的 noro6 导入 JSON 构造函数；官方目标使用 `https://noro6.github.io/kc-web/`，镜像目标使用 `https://noro6.kcwiki.cn/`，两者拼接相同的 `#import:${Uri.encodeComponent(importJson)}`。

**Step 4: Run test to verify it passes**

Run: `flutter test test/external_fleet_tool_launcher_test.dart`
Expected: PASS。

**Step 5: Commit**

Commit message: `feat(工具箱): 添加 noro6 国内镜像导出目标`

### Task 2: 在舰队导出页增加镜像按钮与本地化

**Files:**
- Modify: `test/toolbox_page_test.dart`
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_zh_Hant.arb`
- Modify: `lib/l10n/app_ja.arb`
- Modify: `lib/l10n/app_localizations.dart`
- Modify: `lib/l10n/app_localizations_zh.dart`
- Modify: `lib/l10n/app_localizations_ja.dart`
- Modify: `lib/src/toolbox/fleet_export_page.dart`

**Step 1: Write the failing tests**

增加 widget 测试，要求：
- 文案“导出至 noro6（国内镜像）”可见；
- 按钮 key 为 `fleet-export-noro6-mirror`，位置在官方 noro6 与 Jervis 之间；
- 无母港数据时按钮禁用；
- 点击后收到 host 为 `noro6.kcwiki.cn`、path 为 `/`、包含完整 `#import:` 数据的 URI。

**Step 2: Run tests to verify they fail**

Run: `flutter test test/toolbox_page_test.dart`
Expected: FAIL，因为按钮和本地化文案尚不存在。

**Step 3: Write minimal implementation**

在三份 ARB 增加 `exportToNoro6Mirror`：简中“导出至 noro6（国内镜像）”、繁中“匯出至 noro6（中國鏡像）”、日文“noro6（中国向けミラー）へエクスポート”。运行 `flutter gen-l10n`，并在官方 noro6 与 Jervis 按钮之间增加同样式的镜像按钮，调用 `ExternalFleetTool.noro6Mirror`。

**Step 4: Run tests to verify they pass**

Run: `flutter test test/toolbox_page_test.dart test/external_fleet_tool_launcher_test.dart`
Expected: PASS。

**Step 5: Commit**

Commit message: `feat(工具箱): 添加 noro6 国内镜像导出按钮`

### Task 3: 验证与审查

**Step 1: Format and analyze changed Dart files**

Run: `dart format lib/src/toolbox/external_fleet_tool_launcher.dart lib/src/toolbox/fleet_export_page.dart test/external_fleet_tool_launcher_test.dart test/toolbox_page_test.dart`

Run: `flutter analyze lib/src/toolbox/external_fleet_tool_launcher.dart lib/src/toolbox/fleet_export_page.dart test/external_fleet_tool_launcher_test.dart test/toolbox_page_test.dart`

Expected: PASS。

**Step 2: Run focused tests**

Run: `flutter test test/external_fleet_tool_launcher_test.dart test/toolbox_page_test.dart`
Expected: PASS。

**Step 3: Run repository checks**

Run: `git diff --check`
Expected: PASS。

Run: `flutter test`
Expected: 除已记录的 master 基线失败 `localization_contract_test.dart` 外不得出现新增失败；若上游已修复该基线问题，则必须全量通过。

**Step 4: Review**

先做规格合规审查，再做代码质量审查；修复所有 Critical/Important 问题并重新验证。
