# 全局顶部胶囊提示实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 将应用自身的所有临时反馈统一迁移为顶部胶囊提示，并禁止业务代码重新引入底部 SnackBar。

**架构：** 新增由 `TopNoticeController` 驱动的 `TopNoticeHost`，在 `YahagiApp.home` 根部挂载一次，通过继承作用域向主界面和设置组件提供 `TopNotice.show`。Host 使用不参与布局的 `Stack` 悬浮层渲染最新提示；新消息取消旧计时器并替换旧消息，业务调用按中性、成功、错误三种语义迁移。

**技术栈：** Flutter 3 / Dart 3、Material 3、`ChangeNotifier`、Widget Test、Flutter Test

---

## 文件结构

### 新建文件

- `lib/src/widgets/top_notice.dart`：提示数据、语义枚举、Controller、Inherited Scope、Host 和统一 API。
- `test/top_notice_test.dart`：顶部位置、安全区、样式、替换、自动消失、长文本和点击穿透测试。
- `test/top_notice_contract_test.dart`：根部 Host 挂载和禁止直接 SnackBar 调用的源码契约。

### 修改文件

- `lib/main.dart`：挂载唯一 Host，迁移截图过程与结果提示。
- `lib/src/browser/game_refresh_dialog.dart`：迁移 POI 游戏框架重载失败提示。
- `lib/src/capture/capture_mode_selector.dart`：迁移捕获模式切换提示。
- `lib/src/settings/about_dialog.dart`：迁移外部链接失败提示。
- `lib/src/settings/data_settings_page.dart`：迁移缓存、登出、战果和日志提示。
- `lib/src/settings/diagnostic_user_section.dart`：迁移诊断文件提示。
- `lib/src/settings/game_rendering_mode_section.dart`：迁移渲染模式结果提示。
- `lib/src/settings/game_resource_cache_section.dart`：迁移资源缓存失败提示。
- `lib/src/settings/network_settings_section.dart`：迁移网络过程、结果和校验提示。
- `test/prototype_shell_test.dart`、`test/game_refresh_dialog_test.dart`：验证游戏和截图顶部提示。
- `test/about_dialog_test.dart`、`test/data_settings_page_test.dart`、`test/diagnostic_user_section_test.dart`、`test/game_rendering_mode_section_test.dart`、`test/game_resource_cache_section_test.dart`、`test/network_settings_section_test.dart`：挂载测试 Host 并验证代表性语义。

## 固定接口

所有任务统一使用以下签名和测试键：

```dart
enum TopNoticeTone { neutral, success, error }

const topNoticeKey = Key('top-notice');
const topNoticeTextKey = Key('top-notice-text');

abstract final class TopNotice {
  static void show(
    BuildContext context, {
    required String message,
    TopNoticeTone tone = TopNoticeTone.neutral,
    Duration duration = const Duration(seconds: 4),
  });

  static void hide(BuildContext context);
}
```

### 任务 1：用测试驱动顶部提示核心组件

**文件：**
- 创建：`test/top_notice_test.dart`
- 创建：`lib/src/widgets/top_notice.dart`

- [ ] **步骤 1：编写顶部定位、安全区和长文本失败测试**

创建测试辅助壳，并验证提示位于顶部安全区、水平居中、左右边距至少 16、文本最多两行：

```dart
Widget buildApp({EdgeInsets padding = EdgeInsets.zero}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: const Size(400, 800), padding: padding),
      child: TopNoticeHost(
        child: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => TopNotice.show(
                context,
                message: '当前设备的 Android WebView 太旧，不支持对子框架注入。',
                tone: TopNoticeTone.error,
              ),
              child: const Text('show'),
            ),
          ),
        ),
      ),
    ),
  );
}

testWidgets('renders a long notice in the top capsule safe area', (tester) async {
  await tester.pumpWidget(buildApp(padding: const EdgeInsets.only(top: 24)));
  await tester.tap(find.text('show'));
  await tester.pump();

  final rect = tester.getRect(find.byKey(topNoticeKey));
  expect(rect.top, greaterThanOrEqualTo(28));
  expect(rect.center.dx, closeTo(200, 0.5));
  expect(rect.width, lessThanOrEqualTo(368));
  expect(tester.widget<Text>(find.byKey(topNoticeTextKey)).maxLines, 2);
});
```

- [ ] **步骤 2：运行测试确认组件尚不存在**

运行：`flutter test test/top_notice_test.dart`

预期：FAIL，报告 `top_notice.dart`、`TopNoticeHost` 和 `TopNotice` 未定义。

- [ ] **步骤 3：补充替换、自动消失、语义和点击穿透测试**

追加消息替换用例：

```dart
testWidgets('new notice replaces the old one and restarts its timer', (tester) async {
  late BuildContext noticeContext;
  await tester.pumpWidget(
    MaterialApp(
      home: TopNoticeHost(
        child: Builder(
          builder: (context) {
            noticeContext = context;
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      ),
    ),
  );
  TopNotice.show(
    noticeContext,
    message: 'first',
    duration: const Duration(seconds: 2),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  TopNotice.show(
    noticeContext,
    message: 'second',
    tone: TopNoticeTone.success,
    duration: const Duration(seconds: 2),
  );
  await tester.pump();

  expect(find.text('first'), findsNothing);
  expect(find.text('second'), findsOneWidget);
  await tester.pump(const Duration(milliseconds: 1500));
  expect(find.text('second'), findsOneWidget);
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(milliseconds: 200));
  expect(find.text('second'), findsNothing);
});
```

追加错误语义用例，断言 `Icons.error_outline_rounded` 且 `topNoticeKey` 的语义节点包含 `isLiveRegion`。点击穿透用例使用以下完整结构：

```dart
testWidgets('notice does not consume pointer events', (tester) async {
  var taps = 0;
  late BuildContext noticeContext;
  await tester.pumpWidget(
    MaterialApp(
      home: TopNoticeHost(
        child: Builder(
          builder: (context) {
            noticeContext = context;
            return Scaffold(
              body: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  key: const Key('underlying-button'),
                  width: 240,
                  height: 44,
                  child: FilledButton(
                    onPressed: () => taps++,
                    child: const Text('under notice'),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
  TopNotice.show(noticeContext, message: 'overlay');
  await tester.pump();
  await tester.tapAt(tester.getCenter(find.byKey(const Key('underlying-button'))));
  expect(taps, 1);
});
```

- [ ] **步骤 4：实现 Controller、Scope 和 API**

创建 `lib/src/widgets/top_notice.dart`：

```dart
import 'dart:async';

import 'package:flutter/material.dart';

const topNoticeKey = Key('top-notice');
const topNoticeTextKey = Key('top-notice-text');

enum TopNoticeTone { neutral, success, error }

@immutable
class TopNoticeData {
  TopNoticeData({required this.message, required this.tone}) : id = Object();

  final Object id;
  final String message;
  final TopNoticeTone tone;
}

class TopNoticeController extends ChangeNotifier {
  Timer? _timer;
  TopNoticeData? _current;

  TopNoticeData? get current => _current;

  void show({
    required String message,
    TopNoticeTone tone = TopNoticeTone.neutral,
    Duration duration = const Duration(seconds: 4),
  }) {
    _timer?.cancel();
    final next = TopNoticeData(message: message, tone: tone);
    _current = next;
    notifyListeners();
    _timer = Timer(duration, () {
      if (identical(_current, next)) hide();
    });
  }

  void hide() {
    _timer?.cancel();
    _timer = null;
    if (_current == null) return;
    _current = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class _TopNoticeScope extends InheritedNotifier<TopNoticeController> {
  const _TopNoticeScope({required super.notifier, required super.child});

  static TopNoticeController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_TopNoticeScope>()?.notifier;
}

abstract final class TopNotice {
  static void show(
    BuildContext context, {
    required String message,
    TopNoticeTone tone = TopNoticeTone.neutral,
    Duration duration = const Duration(seconds: 4),
  }) {
    final controller = _TopNoticeScope.maybeOf(context);
    assert(controller != null, 'TopNoticeHost is missing above this context.');
    controller?.show(message: message, tone: tone, duration: duration);
  }

  static void hide(BuildContext context) {
    final controller = _TopNoticeScope.maybeOf(context);
    assert(controller != null, 'TopNoticeHost is missing above this context.');
    controller?.hide();
  }
}
```

- [ ] **步骤 5：实现 Host 和胶囊视图**

`TopNoticeHost` 为 StatefulWidget，内部创建并销毁 Controller。根节点为 `_TopNoticeScope`，其 child 用 `AnimatedBuilder` 构建 `Stack(fit: StackFit.expand)`；第一层为业务 child，第二层如下：

```dart
Positioned(
  top: MediaQuery.paddingOf(context).top + 4,
  left: 16,
  right: 16,
  child: IgnorePointer(
    child: Align(
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        reverseDuration: const Duration(milliseconds: 140),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.25),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: notice == null
            ? const SizedBox.shrink()
            : _TopNoticeCapsule(
                key: ValueKey<Object>(notice.id),
                notice: notice,
              ),
      ),
    ),
  ),
)
```

`_TopNoticeCapsule` 使用 `Semantics(key: topNoticeKey, liveRegion: true)`，约束为 `BoxConstraints(maxWidth: 720, minHeight: 36)`，圆角 18、水平内边距 14、垂直内边距 8、文本 `maxLines: 2`。固定颜色与图标：

```dart
final (background, border, foreground, icon) = switch (notice.tone) {
  TopNoticeTone.neutral => (
      const Color(0xff1a3447), const Color(0xff3c586b),
      Colors.white, Icons.info_outline_rounded,
    ),
  TopNoticeTone.success => (
      const Color(0xff173d3b), const Color(0xff4fa79b),
      const Color(0xffb9f1e8), Icons.check_circle_outline_rounded,
    ),
  TopNoticeTone.error => (
      const Color(0xff54292d), const Color(0xff9b464c),
      const Color(0xffffaaa4), Icons.error_outline_rounded,
    ),
};
```

- [ ] **步骤 6：格式化、运行核心测试并提交**

```powershell
dart format lib/src/widgets/top_notice.dart test/top_notice_test.dart
flutter test test/top_notice_test.dart
git add lib/src/widgets/top_notice.dart test/top_notice_test.dart
git commit -m "feat: 添加全局顶部胶囊提示组件"
```

预期：测试 PASS，退出时没有悬挂计时器异常。

### 任务 2：在应用根部挂载唯一 Host

**文件：**
- 创建：`test/top_notice_contract_test.dart`
- 修改：`lib/main.dart:532-606`

- [ ] **步骤 1：编写根部挂载失败测试**

```dart
test('YahagiApp mounts one global TopNoticeHost', () {
  final source = File('lib/main.dart').readAsStringSync();
  expect(RegExp(r'home:\s*TopNoticeHost\(').allMatches(source), hasLength(1));
});
```

- [ ] **步骤 2：运行测试确认 Host 尚未挂载**

运行：`flutter test test/top_notice_contract_test.dart`

预期：FAIL，匹配数量为 0。

- [ ] **步骤 3：挂载 Host，不改变 YahagiShell 参数**

在 `lib/main.dart` 导入 `src/widgets/top_notice.dart`。将 `home: StartupUpdateNotice(` 改为：

```dart
home: TopNoticeHost(
  child: StartupUpdateNotice(
```

在现有 `StartupUpdateNotice` 结束处补齐 Host 的右括号。原有 `StartupUpdateNotice`、`SecondTickScope`、`YahagiShell` 和全部构造参数原样保留。

- [ ] **步骤 4：验证根部挂载并提交**

```powershell
dart format lib/main.dart test/top_notice_contract_test.dart
flutter test test/top_notice_contract_test.dart test/prototype_shell_test.dart
git add lib/main.dart test/top_notice_contract_test.dart
git commit -m "feat: 在应用壳层挂载顶部提示"
```

预期：两个测试文件 PASS。

### 任务 3：迁移游戏、截图和捕获模式提示

**文件：**
- 修改：`lib/main.dart:921-942`
- 修改：`lib/src/browser/game_refresh_dialog.dart:45-57`
- 修改：`lib/src/capture/capture_mode_selector.dart:32-45`
- 修改：`test/prototype_shell_test.dart:277-283`
- 修改：`test/game_refresh_dialog_test.dart`

- [ ] **步骤 1：先让游戏测试要求顶部提示**

在两个测试文件导入 `top_notice.dart`。`game_refresh_dialog_test.dart` 的测试壳用 `TopNoticeHost` 包住原有 `Builder`。WebView 过旧用例追加：

```dart
expect(find.text('当前设备的 Android WebView 太旧，不支持对子框架注入。'), findsOneWidget);
expect(find.byKey(topNoticeKey), findsOneWidget);
expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
final top = tester.getTopLeft(find.byKey(topNoticeKey)).dy;
expect(top, lessThan(tester.view.physicalSize.height / tester.view.devicePixelRatio / 2));
```

`prototype_shell_test.dart` 的截图用例将 SnackBar 清理改为：

```dart
expect(find.textContaining('yahagi-test.png'), findsOneWidget);
expect(find.byKey(topNoticeKey), findsOneWidget);
TopNotice.hide(tester.element(find.byKey(topNoticeKey)));
await tester.pumpAndSettle();
```

- [ ] **步骤 2：运行测试确认顶部断言失败**

运行：`flutter test test/game_refresh_dialog_test.dart test/prototype_shell_test.dart`

预期：FAIL，找不到 `top-notice` 或错误图标。

- [ ] **步骤 3：迁移截图连续状态**

将截图 SnackBar 逻辑替换为：

```dart
TopNotice.show(context, message: l10n.screenshotSaving);
await WidgetsBinding.instance.endOfFrame;
if (!context.mounted) return;
final result = await widget.gameScreenshotController!.capture();
if (!context.mounted) return;
final message = result.path != null
    ? l10n.screenshotSaved(result.path!)
    : result.errorMessage == null
    ? l10n.screenshotFailed
    : '${l10n.screenshotFailed}\n${result.errorMessage}';
TopNotice.show(
  context,
  message: message,
  tone: result.path != null ? TopNoticeTone.success : TopNoticeTone.error,
);
```

- [ ] **步骤 4：迁移框架重载与捕获模式**

`game_refresh_dialog.dart` 的非成功结果统一调用：

```dart
TopNotice.show(
  context,
  message: message,
  tone: TopNoticeTone.error,
);
```

`capture_mode_selector.dart` 的模式变更说明调用：

```dart
TopNotice.show(
  context,
  message: message,
  tone: TopNoticeTone.neutral,
);
```

`reloaded` 继续静默返回，与现有 POI 对齐行为一致。

- [ ] **步骤 5：格式化、测试并提交**

```powershell
dart format lib/main.dart lib/src/browser/game_refresh_dialog.dart lib/src/capture/capture_mode_selector.dart test/game_refresh_dialog_test.dart test/prototype_shell_test.dart
flutter test test/game_refresh_dialog_test.dart test/prototype_shell_test.dart
git add lib/main.dart lib/src/browser/game_refresh_dialog.dart lib/src/capture/capture_mode_selector.dart test/game_refresh_dialog_test.dart test/prototype_shell_test.dart
git commit -m "refactor: 迁移游戏临时提示到顶部"
```

预期：截图成功为成功胶囊，框架失败和 WebView 过旧为错误胶囊。

### 任务 4：迁移通用设置和诊断提示

**文件：**
- 修改：`lib/src/settings/about_dialog.dart`
- 修改：`lib/src/settings/data_settings_page.dart`
- 修改：`lib/src/settings/diagnostic_user_section.dart`
- 修改：`test/about_dialog_test.dart`
- 修改：`test/data_settings_page_test.dart`
- 修改：`test/diagnostic_user_section_test.dart`

- [ ] **步骤 1：为独立组件测试挂载 Host 并添加语义断言**

三个测试文件统一增加测试壳辅助函数，并把现有直接泵送组件传给 `child`：

```dart
Widget withTopNotice(Widget child) => MaterialApp(
  home: TopNoticeHost(
    child: Scaffold(body: child),
  ),
);
```

外部链接失败断言错误图标；数据清理成功和诊断保存成功分别断言 `topNoticeKey` 与 `Icons.check_circle_outline_rounded`。

- [ ] **步骤 2：运行测试确认顶部语义断言失败**

运行：`flutter test test/about_dialog_test.dart test/data_settings_page_test.dart test/diagnostic_user_section_test.dart`

预期：新增顶部提示或语义断言 FAIL。

- [ ] **步骤 3：迁移关于页面与诊断提示**

诊断保存成功：

```dart
TopNotice.show(
  context,
  message: l10n.diagnosticSaveSucceeded(fileName),
  tone: TopNoticeTone.success,
);
```

诊断保存失败、分享失败和外部链接失败使用同一形式，但传入现有文案并设置 `tone: TopNoticeTone.error`。

- [ ] **步骤 4：迁移数据设置页面**

清理任务缓存、登出成功、清理网页缓存和清理日志使用成功语义；登出失败使用错误语义。基础战果操作必须按 bool 映射：

```dart
TopNotice.show(
  context,
  message: saved ? successMessage : l10n.baseSenkaSaveFailed,
  tone: saved ? TopNoticeTone.success : TopNoticeTone.error,
);
```

保留全部 `context.mounted` 检查、确认对话框和异步调用顺序。

- [ ] **步骤 5：格式化、测试并提交**

```powershell
dart format lib/src/settings/about_dialog.dart lib/src/settings/data_settings_page.dart lib/src/settings/diagnostic_user_section.dart test/about_dialog_test.dart test/data_settings_page_test.dart test/diagnostic_user_section_test.dart
flutter test test/about_dialog_test.dart test/data_settings_page_test.dart test/diagnostic_user_section_test.dart
git add lib/src/settings/about_dialog.dart lib/src/settings/data_settings_page.dart lib/src/settings/diagnostic_user_section.dart test/about_dialog_test.dart test/data_settings_page_test.dart test/diagnostic_user_section_test.dart
git commit -m "refactor: 迁移设置与诊断临时提示"
```

预期：全部 PASS，失败路径为错误胶囊，成功路径为成功胶囊。

### 任务 5：迁移渲染、资源缓存和网络提示

**文件：**
- 修改：`lib/src/settings/game_rendering_mode_section.dart`
- 修改：`lib/src/settings/game_resource_cache_section.dart`
- 修改：`lib/src/settings/network_settings_section.dart`
- 修改：`test/game_rendering_mode_section_test.dart`
- 修改：`test/game_resource_cache_section_test.dart`
- 修改：`test/network_settings_section_test.dart`

- [ ] **步骤 1：挂载测试 Host 并添加结果语义断言**

渲染模式成功和网络应用成功断言成功图标；资源缓存失败和网络校验失败断言错误图标。运行：

`flutter test test/game_rendering_mode_section_test.dart test/game_resource_cache_section_test.dart test/network_settings_section_test.dart`

预期：新增断言 FAIL。

- [ ] **步骤 2：迁移渲染模式和资源缓存提示**

```dart
TopNotice.show(
  context,
  message: applied
      ? l10n.gameRenderingModeApplied
      : l10n.gameRenderingModeFailed,
  tone: applied ? TopNoticeTone.success : TopNoticeTone.error,
);
```

资源缓存失败固定调用：

```dart
TopNotice.show(
  context,
  message: l10n.gameResourceCacheActionFailed,
  tone: TopNoticeTone.error,
);
```

- [ ] **步骤 3：迁移网络设置并重命名错误辅助方法**

将 `_showErrorSnackBar` 重命名为：

```dart
void _showErrorNotice(String message) {
  if (!mounted) return;
  TopNotice.show(
    context,
    message: message,
    tone: TopNoticeTone.error,
  );
}
```

“应用网络设置中”和“清除代理中”保留原有一秒时长与中性语义：

```dart
TopNotice.show(
  context,
  message: message,
  duration: const Duration(seconds: 1),
);
```

网络应用成功、恢复系统网络成功使用成功语义；校验、应用和恢复失败全部调用 `_showErrorNotice`。

- [ ] **步骤 4：格式化、测试并提交**

```powershell
dart format lib/src/settings/game_rendering_mode_section.dart lib/src/settings/game_resource_cache_section.dart lib/src/settings/network_settings_section.dart test/game_rendering_mode_section_test.dart test/game_resource_cache_section_test.dart test/network_settings_section_test.dart
flutter test test/game_rendering_mode_section_test.dart test/game_resource_cache_section_test.dart test/network_settings_section_test.dart
git add lib/src/settings/game_rendering_mode_section.dart lib/src/settings/game_resource_cache_section.dart lib/src/settings/network_settings_section.dart test/game_rendering_mode_section_test.dart test/game_resource_cache_section_test.dart test/network_settings_section_test.dart
git commit -m "refactor: 统一网络与渲染顶部提示"
```

预期：全部 PASS，一秒过程提示仍按一秒消失。

### 任务 6：建立全局契约并完成验证

**文件：**
- 修改：`test/top_notice_contract_test.dart`

- [ ] **步骤 1：编写禁止直接 SnackBar 调用的失败测试**

```dart
test('application UI does not bypass TopNotice with SnackBar', () {
  final files = <File>[
    File('lib/main.dart'),
    ...Directory('lib/src')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart')),
  ];
  final violations = <String>[];
  final forbidden = RegExp(r'\b(?:SnackBar|ScaffoldMessenger)\b');

  for (final file in files) {
    final lines = file.readAsLinesSync();
    for (var index = 0; index < lines.length; index++) {
      if (forbidden.hasMatch(lines[index])) {
        violations.add(
          file.path + ':' + (index + 1).toString() + ': ' + lines[index].trim(),
        );
      }
    }
  }

  expect(violations, isEmpty, reason: violations.join('\n'));
});
```

- [ ] **步骤 2：运行契约测试并清理迁移遗漏**

运行：`flutter test test/top_notice_contract_test.dart`

预期：PASS。若输出文件与行号，按任务 3 至 5 的语义表迁移后重跑，直到违规列表为空。

- [ ] **步骤 3：运行格式、分析和目标回归**

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test test/top_notice_test.dart test/top_notice_contract_test.dart test/game_refresh_dialog_test.dart test/prototype_shell_test.dart test/about_dialog_test.dart test/data_settings_page_test.dart test/diagnostic_user_section_test.dart test/game_rendering_mode_section_test.dart test/game_resource_cache_section_test.dart test/network_settings_section_test.dart
```

预期：格式检查、静态分析和目标测试 PASS。本次新增或修改文件不得新增分析诊断。

- [ ] **步骤 4：运行全量测试确认基线**

运行：`flutter test`

预期：本功能相关测试全部 PASS；仓库当前已知失败不得增加。保存失败数量和测试名称用于交付说明。

- [ ] **步骤 5：提交契约并检查最终状态**

```powershell
git add test/top_notice_contract_test.dart
git commit -m "test: 禁止业务代码绕过顶部提示"
git status --short
git diff --check
git log --oneline -8
```

预期：工作树干净，`git diff --check` 无输出，最近提交包含核心组件、Host、三组迁移和契约测试。
