# 出击制空状态跨昼夜战保留实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 夜战数据缺少航空字段时保留同一场战斗的昼战制空状态。

**架构：** 保持现有 `parseDispSeiku` 的数据包解析职责，在 `BattleController` 组装 `LiveBattle` 时增加会话级回退。只有 `0` 至 `4` 更新状态，其余情况继承当前战斗上一阶段的值，没有上一阶段时使用「未知」。

**技术栈：** Dart、Flutter、`flutter_test`

---

### 任务 1：锁定跨昼夜战行为

**文件：**
- 修改：`test/battle_controller_test.dart`

- [x] **步骤 1：编写失败的测试**

构造包含 `api_disp_seiku: 2` 的昼战数据包，再发送不含 `api_kouku` 的夜战数据包，断言夜战后的 `controller.current!.airSuperiority` 仍为「优势」。另断言只有夜战数据包时为「未知」。

- [x] **步骤 2：运行测试验证失败**

运行：

```bash
flutter test test/battle_controller_test.dart --plain-name "night battle preserves daytime air superiority" --reporter expanded
```

预期：FAIL，实际值为「未知」，期望值为「优势」。

### 任务 2：实现会话级回退

**文件：**
- 修改：`lib/src/battle/battle_controller.dart`
- 测试：`test/battle_controller_test.dart`

- [x] **步骤 1：编写最少实现**

在 `_applyBattlePhase` 中只接受 `0` 至 `4` 的合法制空代码；无合法值时使用 `previousBattle?.airSuperiority ?? '未知'`。

- [x] **步骤 2：运行定向测试验证通过**

运行：

```bash
flutter test test/battle_controller_test.dart --plain-name "night battle preserves daytime air superiority" --reporter expanded
```

预期：PASS。

- [x] **步骤 3：运行相关回归**

运行：

```bash
flutter test test/battle_controller_test.dart test/logbook_database_test.dart test/logbook_page_test.dart --reporter compact
flutter analyze lib/src/battle/battle_controller.dart test/battle_controller_test.dart
```

预期：全部测试通过，静态检查无问题。

- [x] **步骤 4：提交到 master**

```bash
git add lib/src/battle/battle_controller.dart test/battle_controller_test.dart docs/superpowers/specs/2026-09-05-preserve-sortie-air-superiority-design.md docs/superpowers/plans/2026-09-05-preserve-sortie-air-superiority.md
git commit -m "fix(出击记录): 夜战保留昼战制空状态"
```
