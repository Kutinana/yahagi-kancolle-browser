# 帧率“低耗”档位文案实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 将简中和繁中帧率第二档名称改为“低耗”，日文保持“省電”，且不改变任何帧率行为或持久化值。

**架构：** 只修改 ARB 本地化资源，通过 Flutter gen-l10n 重新生成派生代码；界面继续读取既有 `gameFrameRatePowerSaving` 键。界面测试固定三语显示结果，本地化审计显式登记简繁中文共享的“低耗”术语。

**技术栈：** Flutter、Dart、ARB、Flutter gen-l10n、flutter_test

---

## 文件结构

- 修改：`test/game_frame_rate_settings_section_test.dart`——固定简中、繁中“低耗”和日文“省電”的用户可见行为。
- 修改：`lib/l10n/app_zh.arb`——将简中档位名改为“低耗”。
- 修改：`lib/l10n/app_zh_Hant.arb`——将繁中档位名改为“低耗”。
- 生成：`lib/l10n/app_localizations.dart`——更新模板语言文档注释。
- 生成：`lib/l10n/app_localizations_zh.dart`——更新简中与繁中 getter。
- 修改：`test/localization_resource_audit_test.dart`——登记“低耗”为已审查的简繁中文共享术语。

### 任务 1：更新三语档位显示行为

**文件：**
- 修改：`test/game_frame_rate_settings_section_test.dart:20-40`
- 修改：`lib/l10n/app_zh.arb:432`
- 修改：`lib/l10n/app_zh_Hant.arb:432`
- 生成：`lib/l10n/app_localizations.dart`
- 生成：`lib/l10n/app_localizations_zh.dart`

- [ ] **步骤 1：编写失败的界面测试**

将简中选择、点击目标和简繁本地化预期改为“低耗”，保留日文“省電”：

```dart
expect(find.text('自动'), findsOneWidget);
expect(find.text('低耗'), findsOneWidget);
expect(find.text('高刷'), findsOneWidget);

await tester.tap(find.text('低耗'));
```

```dart
(locale: const Locale('zh'), texts: <String>['游戏帧率', '自动', '低耗', '高刷']),
(
  locale: const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  texts: <String>['遊戲幀率', '自動', '低耗', '高刷'],
),
(
  locale: const Locale('ja'),
  texts: <String>['ゲームフレームレート', '自動', '省電', '高リフレッシュレート'],
),
```

- [ ] **步骤 2：运行测试验证红灯**

运行：

```powershell
flutter test --reporter compact test\game_frame_rate_settings_section_test.dart
```

预期：FAIL；简中界面找不到“低耗”，证明测试捕获了旧文案。

- [ ] **步骤 3：修改最少本地化资源并生成派生代码**

在 `lib/l10n/app_zh.arb` 中写入：

```json
"gameFrameRatePowerSaving": "低耗"
```

在 `lib/l10n/app_zh_Hant.arb` 中写入：

```json
"gameFrameRatePowerSaving": "低耗"
```

不要修改 `lib/l10n/app_ja.arb` 的以下值：

```json
"gameFrameRatePowerSaving": "省電"
```

生成代码：

```powershell
flutter gen-l10n
```

- [ ] **步骤 4：运行界面测试验证绿灯**

运行：

```powershell
flutter test --reporter compact test\game_frame_rate_settings_section_test.dart
```

预期：PASS，文件中的 widget tests 全部通过。

- [ ] **步骤 5：提交用户可见文案变更**

```powershell
git add -- test/game_frame_rate_settings_section_test.dart lib/l10n/app_zh.arb lib/l10n/app_zh_Hant.arb lib/l10n/app_localizations.dart lib/l10n/app_localizations_zh.dart
git commit -m "feat(帧率): 将中文省电档改为低耗（任务1）"
```

### 任务 2：登记共享术语并完成验证

**文件：**
- 修改：`test/localization_resource_audit_test.dart:106-110`

- [ ] **步骤 1：运行本地化审计验证红灯**

运行：

```powershell
flutter test --reporter compact test\localization_resource_audit_test.dart
```

预期：FAIL；`identical translations are limited to reviewed terminology` 的实际集合新增 `gameFrameRatePowerSaving`，但审核集合尚未登记。

- [ ] **步骤 2：添加最少审计登记**

在 `reviewedZhHant` 中、`gameFrameRateHighRefresh` 附近加入：

```dart
// “低耗”是简中和繁中统一采用的帧率档位产品名称。
'gameFrameRatePowerSaving',
```

- [ ] **步骤 3：运行审计与界面测试验证绿灯**

运行：

```powershell
flutter test --reporter compact test\game_frame_rate_settings_section_test.dart test\localization_resource_audit_test.dart
```

预期：PASS，6 项测试全部通过。

- [ ] **步骤 4：分析本次改动文件并检查差异**

运行：

```powershell
flutter analyze lib/l10n/app_localizations.dart lib/l10n/app_localizations_zh.dart test/game_frame_rate_settings_section_test.dart test/localization_resource_audit_test.dart
git diff --check
git diff --stat
```

预期：Flutter analyze 显示 `No issues found!`；`git diff --check` 无输出；差异只包含计划列出的本地化资源、生成代码和测试。

- [ ] **步骤 5：提交术语审计**

```powershell
git add -- test/localization_resource_audit_test.dart
git commit -m "test(本地化): 登记低耗档位术语（任务2）"
```

- [ ] **步骤 6：确认工作树跟踪文件干净**

运行：

```powershell
git status --short --untracked-files=no
git log -3 --oneline
```

预期：跟踪文件无未提交变更；最新两项实现提交分别是中文“低耗”文案和术语审计。
