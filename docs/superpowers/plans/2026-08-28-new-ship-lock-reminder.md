# 新舰上锁提醒文案实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 让新舰系统通知和应用内弹窗统一显示「{舰名列表}，请不要忘记上锁」。

**架构：** 在 ARB 中新增带舰名占位符的本地化正文，由 Flutter 本地化生成器产出格式化方法。系统通知和应用内弹窗都调用同一个方法，避免两处字符串拼接规则分叉。

**技术栈：** Flutter、Dart、Flutter gen-l10n、flutter_test

---

## 文件结构

- 修改：`lib/l10n/app_zh.arb`，定义简体中文正文模板。
- 修改：`lib/l10n/app_zh_Hant.arb`，定义繁体中文正文模板。
- 修改：`lib/l10n/app_ja.arb`，定义日文正文模板。
- 生成：`lib/l10n/app_localizations.dart` 及各语言实现，提供 `newShipAlertBody(String names)`。
- 修改：`lib/main.dart`，让系统通知和应用内弹窗共用本地化正文。
- 创建：`test/new_ship/new_ship_alert_localization_test.dart`，验证三种语言和多舰名格式。

### 任务 1：统一新舰提醒正文

**文件：**

- 创建：`test/new_ship/new_ship_alert_localization_test.dart`
- 修改：`lib/l10n/app_zh.arb`
- 修改：`lib/l10n/app_zh_Hant.arb`
- 修改：`lib/l10n/app_ja.arb`
- 修改：`lib/l10n/app_localizations.dart`
- 修改：`lib/l10n/app_localizations_zh.dart`
- 修改：`lib/l10n/app_localizations_zh_Hant.dart`
- 修改：`lib/l10n/app_localizations_ja.dart`
- 修改：`lib/main.dart:347-362`
- 修改：`lib/main.dart:1002-1017`

- [ ] **步骤 1：编写失败的本地化测试**

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

void main() {
  test('新舰提醒正文包含舰名和上锁提示', () {
    expect(
      lookupAppLocalizations(const Locale('zh')).newShipAlertBody('雪风'),
      '雪风，请不要忘记上锁',
    );
    expect(
      lookupAppLocalizations(const Locale('zh')).newShipAlertBody('雪风、岛风'),
      '雪风、岛风，请不要忘记上锁',
    );
  });
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/new_ship/new_ship_alert_localization_test.dart`

预期：编译失败，提示 `newShipAlertBody` 尚未定义。

- [ ] **步骤 3：添加最少本地化实现并生成代码**

在简体中文 ARB 中添加：

```json
"newShipAlertBody": "{names}，请不要忘记上锁",
"@newShipAlertBody": {"placeholders": {"names": {"type": "String"}}}
```

繁体中文使用「`{names}，請不要忘記上鎖`」，日文使用「`{names}、ロックをお忘れなく`」。随后运行 `flutter gen-l10n`。

- [ ] **步骤 4：让两种提醒共用格式化方法**

系统通知正文改为：

```dart
body: l10n.newShipAlertBody(names),
```

应用内弹窗正文改为：

```dart
content: Text(l10n.newShipAlertBody(names.join('、'))),
```

- [ ] **步骤 5：运行定向测试验证通过**

运行：`flutter test test/new_ship/new_ship_alert_localization_test.dart test/notification/game_notification_coordinator_test.dart test/localization_resource_audit_test.dart`

预期：全部测试通过，退出码为 0。

- [ ] **步骤 6：运行静态检查**

运行：`flutter analyze`

预期：没有错误，退出码为 0。

- [ ] **步骤 7：提交实现**

```bash
git add lib/main.dart lib/l10n test/new_ship/new_ship_alert_localization_test.dart
git commit -m "feat(新舰提醒): 添加上锁安全提示"
```
