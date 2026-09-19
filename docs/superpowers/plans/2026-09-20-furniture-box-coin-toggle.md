# 家具箱家具币折算切换实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 让顶部三个家具箱胶囊可独立切换显示实际箱数或家具币折算值。

**架构：** 在 `CompactResourceBar` 的 State 中保存当前处于折算模式的家具箱 ID；点击指定胶囊时切换集合成员。显示阶段根据资源 ID 选择倍率并生成数值文字，图标和筛选弹窗仍使用现有资源规格。

**技术栈：** Flutter、Dart、flutter_test

---

### 任务 1：家具箱折算交互

**文件：**
- 修改：`test/compact_resource_bar_test.dart`
- 修改：`lib/src/fleet/resource_grid.dart`

- [ ] **步骤 1：编写失败的 Widget 测试**

构造 useitem 10/11/12 数量分别为 12/7/3 的 `GameState`，显示三个家具箱后逐一点击，断言得到 `2400币`、`2800币`、`2100币`；再次点击小箱，断言恢复 `12` 且另外两项保持折算状态。

- [ ] **步骤 2：运行测试验证失败**

运行：

```powershell
G:\DevTools\flutter\bin\flutter.bat test test\compact_resource_bar_test.dart --plain-name "furniture boxes independently toggle coin equivalents"
```

预期：FAIL，因为点击家具箱尚未改变显示值。

- [ ] **步骤 3：实现最少交互状态与折算显示**

在 `_CompactResourceBarState` 中增加折算 ID 集合和 ID 到倍率的映射；为 useitem 10/11/12 增加点击切换；向 `_HeaderResourceItem` 和 `_EditableHeaderResourceItem` 传递可选后缀，使折算状态显示 `<数量>币`，缺失数据仍显示 `—`。

- [ ] **步骤 4：运行目标测试验证通过**

运行步骤 2 的命令，预期 PASS。

- [ ] **步骤 5：补充缺失数据与布局回归测试**

点击未抓到 useitem 数据的家具箱，断言仍显示 `—`；使用大数量验证 `FittedBox` 不产生 Flutter 异常。

- [ ] **步骤 6：运行相关测试和静态检查**

```powershell
G:\DevTools\flutter\bin\flutter.bat test test\compact_resource_bar_test.dart test\layout_settings_behavior_test.dart test\fleet_localization_test.dart
G:\DevTools\flutter\bin\flutter.bat analyze lib\src\fleet\resource_grid.dart test\compact_resource_bar_test.dart
```

预期：所有测试通过，静态检查输出 `No issues found!`。

- [ ] **步骤 7：提交实现**

仅在用户要求提交时执行：

```powershell
git add lib/src/fleet/resource_grid.dart test/compact_resource_bar_test.dart
git commit -m "feat(顶部资源): 支持家具箱折算家具币"
```
