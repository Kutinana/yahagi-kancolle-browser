# 素战果安全累计与手动校正实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 阻止累计提督经验被重复换算为素战果，并在数据设置中提供本月素战果归零和手动填写能力。

**架构：** `SenkaState` 用追踪版本表达旧缓存是否需要一次性清洗，`SenkaReducer` 只接受单调增加的累计经验，`SenkaController` 以重写每日 `experience`、保留 `eo/quest` 的方式校正本月总额。设置页仅调用控制器并负责确认、输入校验及反馈。

**技术栈：** Flutter、Dart、SharedPreferences、Flutter localization、flutter_test。

---

## 文件结构

- 修改 `lib/src/senka/senka_state.dart`：增加素战果追踪版本及旧缓存迁移函数。
- 修改 `lib/src/senka/senka_reducer.dart`：迁移旧状态并拒绝经验基准回退。
- 修改 `lib/src/senka/senka_controller.dart`：初始化时保存迁移结果，提供读取、归零、手动设置 API。
- 修改 `lib/src/settings/data_settings_page.dart`：增加两个设置入口、确认框和数字输入框。
- 修改 `lib/src/settings/settings_page.dart`、`lib/main.dart`：把现有 `SenkaController` 注入数据设置页。
- 修改 `lib/l10n/app_*.arb` 及运行 `flutter gen-l10n`：添加现有三语言设置文案。
- 修改 `test/senka_reducer_test.dart`、`test/senka_controller_test.dart`、`test/data_settings_page_test.dart`：覆盖数据、持久化和交互。

### 任务 1：旧缓存迁移与经验单调性

**文件：**
- 修改：`lib/src/senka/senka_state.dart`
- 修改：`lib/src/senka/senka_reducer.dart`
- 测试：`test/senka_reducer_test.dart`
- 测试：`test/senka_controller_test.dart`

- [ ] **步骤 1：编写失败的迁移与单调性测试**

```dart
test('旧追踪版本只清零素战果并清除经验基准', () {
  final legacy = SenkaState.fromJson({
    'monthKey': '2026-08',
    'latestExperience': 15222492,
    'days': {
      '2026-08-19': {'experience': 51472.0353, 'eo': 75, 'quest': 80},
    },
    'targetSenka': 4000,
  });
  final migrated = migrateSenkaExperienceTracking(legacy);
  expect(migrated.latestExperience, isNull);
  expect(migrated.day(DateTime(2026, 8, 19)).experience, 0);
  expect(migrated.day(DateTime(2026, 8, 19)).eo, 75);
  expect(migrated.day(DateTime(2026, 8, 19)).quest, 80);
  expect(migrated.targetSenka, 4000);
});

test('较小或相等经验快照不降低基准也不增加素战果', () {
  // 先建立 15,000,000 基准，再输入较小值和相等值，最后输入 15,001,000。
  // 断言最终只增加 0.70，基准为 15,001,000。
});
```

- [ ] **步骤 2：运行测试验证红灯**

运行：`flutter test test/senka_reducer_test.dart test/senka_controller_test.dart`

预期：FAIL，缺少 `migrateSenkaExperienceTracking`，且较小经验会错误回退基准。

- [ ] **步骤 3：实现追踪版本和安全迁移**

```dart
const currentSenkaExperienceTrackingVersion = 1;

SenkaState migrateSenkaExperienceTracking(SenkaState state) {
  if (state.experienceTrackingVersion >=
      currentSenkaExperienceTrackingVersion) return state;
  return state.copyWith(
    experienceTrackingVersion: currentSenkaExperienceTrackingVersion,
    clearLatestExperience: true,
    days: {
      for (final entry in state.days.entries)
        entry.key: SenkaDayRecord(
          eo: entry.value.eo,
          quest: entry.value.quest,
        ),
    },
  );
}
```

`fromJson` 缺少版本字段时读取为 `0`，`forMonth` 使用当前版本，`toJson` 写出版本。Reducer 在处理事件前迁移状态；经验逻辑改为首次值只建基准、`experience <= previous` 直接忽略。

- [ ] **步骤 4：运行专项测试验证绿灯**

运行：`flutter test test/senka_reducer_test.dart test/senka_controller_test.dart`

预期：全部通过。

- [ ] **步骤 5：提交数据层修复**

```powershell
git add lib/src/senka/senka_state.dart lib/src/senka/senka_reducer.dart test/senka_reducer_test.dart test/senka_controller_test.dart
git commit -m "fix(战果): 防止累计经验重复换算"
```

### 任务 2：控制器归零与手动设置

**文件：**
- 修改：`lib/src/senka/senka_controller.dart`
- 测试：`test/senka_controller_test.dart`

- [ ] **步骤 1：编写失败的控制器测试**

```dart
test('归零和手动填写只替换本月素战果并继续自动累计', () async {
  final controller = SenkaController(
    store: store,
    now: () => DateTime.utc(2026, 8, 20, 3),
  );
  // 准备两日 experience/eo/quest 与可信 latestExperience。
  await controller.resetBaseSenka();
  expect(controller.monthBaseSenka, 0);
  // EO/quest 保留，latestExperience 保留。
  await controller.setBaseSenka(123.45);
  expect(controller.monthBaseSenka, 123.45);
  // 后续累计经验 +1000 后总额为 124.15。
});
```

另测负数、NaN、Infinity 被拒绝且不保存；有效操作各保存一次。

- [ ] **步骤 2：运行测试验证红灯**

运行：`flutter test test/senka_controller_test.dart`

预期：FAIL，控制器不存在 `monthBaseSenka`、`resetBaseSenka`、`setBaseSenka`。

- [ ] **步骤 3：实现最少控制器 API**

```dart
double get monthBaseSenka => _state.days.values.fold(
  0,
  (sum, record) => sum + record.experience,
);

Future<bool> resetBaseSenka() => setBaseSenka(0);
Future<bool> setBaseSenka(double value) async {
  if (!value.isFinite || value < 0 || _disposed) return false;
  final businessDate = senkaBusinessDate(_now());
  final days = <String, SenkaDayRecord>{
    for (final entry in _state.days.entries)
      entry.key: SenkaDayRecord(eo: entry.value.eo, quest: entry.value.quest),
  };
  final key = dateKey(businessDate);
  final current = days[key] ?? const SenkaDayRecord();
  days[key] = SenkaDayRecord(experience: value, eo: current.eo, quest: current.quest);
  return _replaceForSettings(_state.copyWith(days: days));
}
```

`initialize` 必须组合月份迁移与追踪迁移，并在迁移发生时保存一次。

- [ ] **步骤 4：运行控制器测试验证绿灯**

运行：`flutter test test/senka_controller_test.dart`

预期：全部通过。

- [ ] **步骤 5：提交控制器功能**

```powershell
git add lib/src/senka/senka_controller.dart test/senka_controller_test.dart
git commit -m "feat(战果): 支持本月素战果校正"
```

### 任务 3：设置页交互与本地化

**文件：**
- 修改：`lib/src/settings/data_settings_page.dart`
- 修改：`lib/src/settings/settings_page.dart`
- 修改：`lib/main.dart`
- 修改：`lib/l10n/app_ja.arb`
- 修改：`lib/l10n/app_zh.arb`
- 修改：`lib/l10n/app_zh_Hant.arb`
- 测试：`test/data_settings_page_test.dart`

- [ ] **步骤 1：编写失败的 Widget 测试**

```dart
testWidgets('数据设置可归零并手动填写本月素战果', (tester) async {
  // 传入 SenkaController 后找到 settings-reset-base-senka 与
  // settings-set-base-senka；取消归零不变，确认后归零。
  // 手动输入 123.45 并保存后断言控制器值与成功提示。
});

testWidgets('非法素战果输入保持对话框且不保存', (tester) async {
  // 输入空值、负数、三位小数，断言错误文字存在且状态未变化。
});
```

- [ ] **步骤 2：运行测试验证红灯**

运行：`flutter test test/data_settings_page_test.dart`

预期：FAIL，设置页没有控制器参数、按钮和对话框。

- [ ] **步骤 3：添加控制器注入和两个 ActionTile**

`SettingsPage` 与 `DataSettingsPage` 增加可空 `SenkaController`；`main.dart` 传入现有 `widget.senkaController`。控制器非空时在存储与缓存卡片顶部插入两个操作及分隔线。

- [ ] **步骤 4：实现确认框与数字输入框**

```dart
final input = TextEditingController(
  text: senkaNumber(controller.monthBaseSenka),
);
// TextInputType.numberWithOptions(decimal: true)
// FilteringTextInputFormatter.allow(RegExp(r'^\d*(?:\.\d{0,2})?'))
// 保存前再次验证 finite、>= 0 且完整匹配 ^\d+(?:\.\d{1,2})?$
```

归零使用现有确认框风格。成功提示显示 `0.00` 或新的两位小数；失败提示不得声称保存成功。

- [ ] **步骤 5：增加三语言 ARB 并生成本地化代码**

新增标题、说明、确认标题/正文、输入标签、校验错误、成功/失败提示，运行：

`flutter gen-l10n`

预期：生成的 `AppLocalizations` 包含新增 getter。

- [ ] **步骤 6：运行设置页与本地化测试验证绿灯**

运行：`flutter test test/data_settings_page_test.dart test/localization_contract_test.dart`

预期：全部通过。

- [ ] **步骤 7：提交设置页功能**

```powershell
git add lib/src/settings/data_settings_page.dart lib/src/settings/settings_page.dart lib/main.dart lib/l10n test/data_settings_page_test.dart
git commit -m "feat(设置): 添加素战果归零与手动填写"
```

### 任务 4：完整回归与 Debug 验收

**文件：**
- 验证：`lib/src/senka/`
- 验证：`lib/src/settings/`
- 验证：`test/senka*_test.dart`
- 验证：`test/data_settings_page_test.dart`

- [ ] **步骤 1：运行战果和设置专项测试**

运行：

```powershell
flutter test test/senka_reducer_test.dart test/senka_controller_test.dart test/senka_calculation_test.dart test/senka_page_test.dart test/data_settings_page_test.dart test/localization_contract_test.dart
```

预期：0 failures。

- [ ] **步骤 2：运行相关静态分析**

运行：

```powershell
flutter analyze lib/src/senka lib/src/settings/data_settings_page.dart lib/src/settings/settings_page.dart lib/main.dart test/senka_reducer_test.dart test/senka_controller_test.dart test/data_settings_page_test.dart
```

预期：`No issues found!`。

- [ ] **步骤 3：检查差异和工作树范围**

运行：`git diff --check`，并核对没有修改 release、签名、版本号或用户无关文件。

- [ ] **步骤 4：在当前 Debug 运行环境验收**

热重载或重新运行 Debug 应用，确认数据设置页两个入口可见；旧异常缓存升级后素战果为 `0.00`；手动设置后战果计算页立即刷新；不构建 release APK。

### 任务 5：合并本月累计素战果设置入口

**文件：**
- 修改：`lib/src/settings/data_settings_page.dart`
- 修改：`lib/l10n/app_zh.arb`
- 修改：`lib/l10n/app_zh_Hant.arb`
- 修改：`lib/l10n/app_ja.arb`
- 测试：`test/senka_data_settings_test.dart`

- [ ] **步骤 1：编写失败的布局测试**

断言只存在一条 `settings-base-senka-summary` 信息项，手写按钮 `settings-set-base-senka` 与还原按钮 `settings-reset-base-senka` 位于同一水平行，命中区域不少于 44 dp，并可分别打开原有对话框。

- [ ] **步骤 2：运行测试验证红灯**

运行：`flutter test test/senka_data_settings_test.dart`

预期：FAIL，因为当前两个入口位于上下两条信息项，且不存在合并后的 summary key。

- [ ] **步骤 3：实现最小合并布局**

用一个 `AnimatedBuilder` 构建标题、副标题和右侧两个 `IconButton`；整行不设置 `onTap`，按钮保留原控制器调用与对话框。

- [ ] **步骤 4：生成本地化并验证绿灯**

运行：`flutter gen-l10n`，再运行：`flutter test test/senka_data_settings_test.dart test/localization_contract_test.dart`。

预期：全部通过。

- [ ] **步骤 5：完成相关回归**

运行战果与设置专项测试、精确静态分析及 `git diff --check`，随后重新安装 Debug 版本验收，不构建 release APK。

### 任务 6：校准当前玩家排名变化基准

**文件：**
- 修改：`lib/src/senka/senka_controller.dart`
- 测试：`test/senka_controller_test.dart`

- [ ] **步骤 1：用旧的 51624.2186 本地快照复现负变化**

在归零与手动填写测试中加入两条玩家排名快照和固定排名快照；归零前最新本地基准为 `51624.2186`，断言归零后变化为 `0.00`。

- [ ] **步骤 2：运行聚焦测试验证红灯**

运行：`flutter test test/senka_controller_test.dart --plain-name "归零和手动填写只替换本月素战果并继续自动累计"`。

预期：FAIL，实际变化仍是巨额负数。

- [ ] **步骤 3：实现最新玩家快照基准替换**

在 `setBaseSenka` 生成新日记录后，仅复制并替换 `rankingHistory['player']` 最后一条快照的 `localSenkaAtCapture`，值取校正后的 `monthRecorded`；保留快照其余字段和其他历史。

- [ ] **步骤 4：验证校准后继续自动累计**

断言归零和手动填写后变化均为 `0.00`，后续增加 `0.70` 素战果后变化为 `+0.70`；同时断言固定排名和更早玩家快照未变化。
