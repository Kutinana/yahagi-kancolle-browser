# 空母舰种筛选拆分实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在持有与未持有舰娘筛选栏中保留 `BB/BC`，将 `CV/CVL` 拆分为 `CV` 和 `CVL` 两个独立分类。

**架构：** 只拆分共享的 `ShipInventoryCategory.cvCvl` 枚举值和对应匹配映射，使持有与未持有投影自动获得同一行为。页面只更新分类标签；筛选栏继续由现有 `_FilterStrip` 按枚举顺序渲染，不调整布局组件。

**技术栈：** Flutter、Dart、`flutter_test`

---

## 文件结构

- 修改：`test/owned_inventory_projection_test.dart`——验证 `BB/BC` 保持合并以及两类空母的舰种 ID 边界。
- 修改：`test/owned_inventory_page_test.dart`——验证持有与未持有筛选栏的按钮和顺序。
- 修改：`lib/src/inventory/owned_inventory_projection.dart`——拆分空母分类枚举和共享匹配映射。
- 修改：`lib/src/inventory/owned_inventory_page.dart`——输出 `CV`、`CVL` 两个标签。

### 任务 1：用测试锁定目标行为

- [x] 在投影测试中确认 `BB/BC` 仍匹配舰种 ID `8、9、10、12`。
- [x] 在投影测试中确认 `CV` 匹配 `11、18`，`CVL` 匹配 `7`，合计覆盖旧空母分组。
- [x] 在持有与未持有组件测试中确认按钮顺序为 `BB/BC → CV → CVL`，旧 `CV/CVL` key 不存在。
- [x] 先运行新增测试并确认因新枚举值尚不存在而失败。

### 任务 2：实现共享分类拆分

- [x] 将枚举顺序调整为 `all、bbBc、cv、cvl、ca、cl、dd、de、ss、support`。
- [x] 保留 `bbBc` 映射不变，将旧 `cvCvl` 映射拆为 `cv` 和 `cvl`。
- [x] 将页面标签由 `CV/CVL` 拆为 `CV` 和 `CVL`，保留 `BB/BC` 标签。
- [x] 运行三份定向测试并确认绿灯。

### 任务 3：回归验证与提交

- [x] 对两个实现文件和对应测试运行定向静态分析。
- [x] 运行完整 Flutter 测试集。
- [x] 检查格式、差异和提交边界，保留无关工作区文件。
- [x] 在 `master` 提交本次实现与同步后的设计文档。
