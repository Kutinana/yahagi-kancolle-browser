# 战果计算页 Demo 视觉还原实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在不改变战果数据与三态交互的前提下，把 Flutter 战果计算页恢复为已确认 Demo 的视觉结构和密度。

**架构：** 保留 `SenkaCalculatorView` 的状态输入与控制器调用，只重组其横屏任务分组、左栏视觉层级和页脚。横屏使用固定 3∶7 与双列紧凑任务条；竖屏复用同一组件顺序堆叠。任务条的 44dp 触控层与更紧凑的可见表面分离。

**技术栈：** Flutter Material、Widget Test、现有 SenkaController/SenkaCalculationResult。

---

### 任务 1：锁定 Demo 横屏几何契约

**文件：**
- 修改：`test/senka_page_test.dart`

- [ ] **步骤 1：编写失败的几何测试**

在 1280×680 与 844×390 下进入战果计算页，断言：左右宽度为 3∶7；EO 与季度任务第一、二项同一行且第三项位于下一行（固定两列）；年度组与单次组左右并排；任务视觉表面高度小于现正式版大卡片但命中区不小于 44dp；页脚始终位于任务面板底部并可见。

- [ ] **步骤 2：运行红灯**

运行：`flutter test test/senka_page_test.dart --plain-name "计算页复刻Demo横屏双列紧凑矩阵"`

预期：FAIL，现有 `_taskColumns` 在宽横屏返回 4，年度/单次也纵向排列。

- [ ] **步骤 3：提交测试**

```powershell
git add -- test/senka_page_test.dart
git commit -m "test(战果): 锁定计算页Demo横屏几何"
```

### 任务 2：还原左栏层级与右栏任务结构

**文件：**
- 修改：`lib/src/senka/senka_calculator_view.dart`
- 修改：`lib/src/senka/senka_ui.dart`
- 测试：`test/senka_page_test.dart`

- [ ] **步骤 1：实现固定双列与底部分组**

让横屏 EO/季度固定两列；把年度与单次任务放入同一 `Row` 的两个 `Expanded` 分组卡，内部各为单列。竖屏继续顺序堆叠，并按实际行数计算面板高度。

- [ ] **步骤 2：实现紧凑视觉表面与 44dp 命中层**

每个任务按钮保持 44dp 外层命中区，内部状态表面使用垂直留白形成约 32–34dp 的可见任务条；状态颜色、图标、Tooltip、Semantics 和整宽删除线保持不变。

- [ ] **步骤 3：强化左栏 Demo 层级**

当前/目标输入保持同排；预计战果卡使用金色边框、明显的大数字、进度条和目标差说明；三行两列指标共享无缝分隔表格，顺序保持规格中的「已勾选」「剩余日数/素战果」「每日所需/今日剩余」。

- [ ] **步骤 4：实现固定页脚**

图例靠左，计划 EO 与任务金额位于中部，金色合计靠右；任务滚动只发生在页脚上方。

- [ ] **步骤 5：运行绿灯与五尺寸回归**

运行：`flutter test test/senka_page_test.dart`

预期：全部通过，五档尺寸与 1.3 倍文字无 overflow。

- [ ] **步骤 6：提交实现**

```powershell
git add -- lib/src/senka/senka_calculator_view.dart lib/src/senka/senka_ui.dart test/senka_page_test.dart
git commit -m "fix(战果): 按Demo还原计算页视觉布局"
```

### 任务 3：验证正式工程 Debug 效果

**文件：**
- 验证：`lib/src/senka/**`
- 验证：`test/senka_*.dart`

- [ ] **步骤 1：运行定向测试与静态检查**

```powershell
flutter test test/senka_page_test.dart test/senka_calculation_test.dart test/senka_controller_test.dart test/senka_reducer_test.dart test/localization_contract_test.dart
flutter analyze lib/src/senka test/senka_page_test.dart test/senka_calculation_test.dart test/senka_controller_test.dart test/senka_reducer_test.dart
git diff --check
```

预期：测试全部通过，Analyze 为 `No issues found`，diff check 退出码为 0。

- [ ] **步骤 2：构建并安装 Debug APK**

```powershell
flutter build apk --debug
adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-debug.apk
```

预期：仅生成并安装 `app-debug.apk`，不执行 release 或 appbundle 构建。

- [ ] **步骤 3：模拟器视觉验收**

打开战果计算页，保存横屏截图并对照目标 Demo：左栏层级、EO/季度双列、年度/单次并排、固定页脚均可见，无底部裁切。

