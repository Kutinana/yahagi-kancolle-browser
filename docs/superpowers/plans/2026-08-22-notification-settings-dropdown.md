# 通知设置下拉菜单实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 将通知设置的三组分段按钮改为与开关同排的下拉菜单，并移除通知设置文案中的英文括注和英文时间单位。

**架构：** 在 `NotificationSettingsPage` 内提取一个私有泛型行组件，统一渲染“标题、固定宽度下拉菜单、开关”。继续复用现有控制器和持久化字段，只调整界面与本地化文案。

**技术栈：** Flutter、Material `DropdownButton`、Flutter widget test、ARB 本地化生成。

---

## 文件结构

- 修改：`lib/src/settings/notification_settings_page.dart`——提供单行下拉菜单布局并替换三组分段按钮。
- 修改：`lib/l10n/app_zh.arb`——清理简体中文英文括注和时间单位。
- 修改：`lib/l10n/app_zh_Hant.arb`——清理繁体中文英文括注和时间单位。
- 修改：`lib/l10n/app_ja.arb`——清理日文英文括注和时间单位。
- 生成：`lib/l10n/app_localizations*.dart`——由 `flutter gen-l10n` 同步 ARB 结果。
- 创建：`test/notification_settings_layout_test.dart`——验证布局、交互和目标文案。

### 任务 1：用测试锁定单行下拉菜单行为

**文件：**
- 创建：`test/notification_settings_layout_test.dart`

- [ ] **步骤 1：编写失败的布局与交互测试**

```dart
expect(find.byType(SegmentedButton<int>), findsNothing);
expect(find.byType(SegmentedButton<AnchorageNotificationMode>), findsNothing);
expect(find.byKey(const Key('notification-expedition-menu')), findsOneWidget);
expect(find.byKey(const Key('notification-repair-menu')), findsOneWidget);
expect(find.byKey(const Key('notification-anchorage-menu')), findsOneWidget);

final menuX = tester.getTopLeft(
  find.byKey(const Key('notification-expedition-menu')),
).dx;
final switchX = tester.getTopLeft(
  find.byKey(const Key('notification-expedition-switch')),
).dx;
expect(menuX, lessThan(switchX));

await tester.tap(find.byKey(const Key('notification-expedition-menu')));
await tester.pumpAndSettle();
await tester.tap(find.text('提前 30 秒').last);
await tester.pumpAndSettle();
expect(controller.settings.expeditionPreemptSeconds, 30);
```

- [ ] **步骤 2：运行测试并确认因旧分段按钮布局失败**

运行：`flutter test test/notification_settings_layout_test.dart`

预期：FAIL，找不到 `notification-expedition-menu`，并仍能找到 `SegmentedButton`。

### 任务 2：实现对齐的单行下拉菜单

**文件：**
- 修改：`lib/src/settings/notification_settings_page.dart`
- 测试：`test/notification_settings_layout_test.dart`

- [ ] **步骤 1：添加私有泛型行组件**

```dart
Widget _buildNotificationTypeRow<T>({
  required Key rowKey,
  required Key menuKey,
  required Key switchKey,
  required Widget title,
  required T selected,
  required List<DropdownMenuItem<T>> items,
  required bool enabled,
  required ValueChanged<T> onSelected,
  required bool switchedOn,
  required ValueChanged<bool> onSwitchChanged,
}) {
  return Padding(
    key: rowKey,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(
      children: [
        Expanded(child: title),
        SizedBox(
          width: 132,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              key: menuKey,
              value: selected,
              isExpanded: true,
              items: items,
              onChanged: enabled
                  ? (value) {
                      if (value != null) onSelected(value);
                    }
                  : null,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Switch(
          key: switchKey,
          value: switchedOn,
          onChanged: onSwitchChanged,
          activeThumbColor: const Color(0xffd4a85f),
        ),
      ],
    ),
  );
}
```

- [ ] **步骤 2：替换远征、入渠和泊地的分段按钮**

三行分别绑定：

```dart
controller.setExpeditionPreemptSeconds(value);
controller.setRepairPreemptSeconds(value);
controller.setAnchorageMode(value);
```

开关继续分别绑定现有 `setExpedition`、`setRepair`、`setAnchorage`。

- [ ] **步骤 3：运行布局测试确认通过**

运行：`flutter test test/notification_settings_layout_test.dart`

预期：PASS，三个菜单存在、菜单位于开关左侧、选择后控制器更新。

### 任务 3：清理通知设置本地化文案

**文件：**
- 修改：`lib/l10n/app_zh.arb`
- 修改：`lib/l10n/app_zh_Hant.arb`
- 修改：`lib/l10n/app_ja.arb`
- 生成：`lib/l10n/app_localizations.dart`
- 生成：`lib/l10n/app_localizations_zh.dart`
- 生成：`lib/l10n/app_localizations_ja.dart`
- 测试：`test/notification_settings_layout_test.dart`

- [ ] **步骤 1：先添加本地化断言**

```dart
expect(zh.notificationSectionOngoing, '后台常驻进行中进度');
expect(zh.notificationSectionTypes, '业务通知分类与提醒时机');
expect(zh.notificationExpedition, '远征归还');
expect(zh.notificationPreempt60s, '提前 60 秒');
expect(zh.notificationPreempt120s, '提前 2 分钟');
expect(zh.notificationAnchorage20m, '满 20 分钟首轮');
```

- [ ] **步骤 2：运行测试确认旧英文文案导致失败**

运行：`flutter test test/notification_settings_layout_test.dart`

预期：FAIL，实际值仍包含 `(Type)`、`(Expedition)` 或 `60s`。

- [ ] **步骤 3：修改三份 ARB 并重新生成本地化代码**

运行：`flutter gen-l10n`

预期：`app_localizations*.dart` 中生成的 getter 与 ARB 新值一致。

- [ ] **步骤 4：运行布局和本地化测试确认通过**

运行：`flutter test test/notification_settings_layout_test.dart test/localization_resource_audit_test.dart`

预期：PASS。

### 任务 4：完整验证并提交

**文件：**
- 修改：上述实现、测试和生成文件。

- [ ] **步骤 1：格式化并检查差异**

运行：`dart format lib/src/settings/notification_settings_page.dart test/notification_settings_layout_test.dart`

运行：`git diff --check`

预期：无格式和空白错误。

- [ ] **步骤 2：运行 Flutter 完整测试**

运行：`flutter test`

预期：全部通过，允许仓库已有的显式 skip。

- [ ] **步骤 3：构建 Android debug APK**

运行：`android\\gradlew.bat :app:assembleDebug`

预期：`BUILD SUCCESSFUL`，APK 位于 `build/app/outputs/flutter-apk/app-debug.apk`。

- [ ] **步骤 4：提交到 master**

```bash
git add lib/src/settings/notification_settings_page.dart \
  lib/l10n/app_zh.arb lib/l10n/app_zh_Hant.arb lib/l10n/app_ja.arb \
  lib/l10n/app_localizations.dart lib/l10n/app_localizations_zh.dart \
  lib/l10n/app_localizations_ja.dart test/notification_settings_layout_test.dart \
  docs/superpowers/plans/2026-08-22-notification-settings-dropdown.md
git commit -m "feat(通知): 设置项改用单行下拉菜单"
```
