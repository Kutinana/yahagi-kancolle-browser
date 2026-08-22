# 战前敌方立绘设计

## 背景

「未卜先知」在抵达战斗节点后，会根据 `api_e_deck_info` 提前显示敌方舰名。当前战前预测仅显示文字，没有利用项目已有的舰船立绘能力。

本次为完整模式增加敌方立绘，并在战斗设置中提供持久化开关。简洁模式继续保持纯文字，避免增加高度和图片加载开销。

## 用户体验

- 战斗设置新增「战前敌方立绘」开关，默认开启。
- 开关说明为「仅在未卜先知完整模式显示」。
- 开关切换后立即刷新当前未卜先知卡片，不需要等待下一场战斗。
- 完整模式开启时，每个战前敌舰名称左侧显示小型立绘。
- 完整模式关闭时，恢复当前纯文字列表。
- 简洁模式无论开关状态如何，始终显示当前纯文字列表。
- 简体中文、繁体中文和日文使用各自的本地化文案。

## 布局

普通敌方舰队继续使用单列列表：

- 立绘尺寸约为 56 × 34 dp；
- 立绘位于舰名左侧，与舰名间隔约 8 dp；
- 舰名保持单行，空间不足时使用省略号。

联合舰队继续使用当前双栏三行布局：

- 每格立绘尺寸约为 48 × 30 dp；
- 立绘位于各自舰名左侧，与舰名间隔约 6 dp；
- 不改变随伴舰队与主力舰队的现有顺序。

显示立绘后允许完整模式的预览卡片自然增高。简洁模式的行高和卡片高度不变。

## 数据模型

新增不可变的战前敌舰预览对象，至少包含：

```dart
class EnemyPreviewShip {
  const EnemyPreviewShip({required this.masterId, required this.name});

  final int masterId;
  final String name;
}
```

`LiveBattle` 将纯舰名列表替换为 `List<EnemyPreviewShip>`。`BattleController` 继续从 `api_e_deck_info[*].api_ship_ids` 读取敌舰，但同时保留 master ID 和舰名。每支舰队最多保留前 3 艘，联合舰队的现有排列顺序不变。

界面通过 `masterId` 从 `GameState.masterShips` 查找 `MasterShip`，不按舰名反查，避免重名和本地化差异导致错误匹配。

## 立绘加载与降级

复用现有 `ShipPortrait` 和 `ShipPortraitUriBuilder`，使用当前服务器来源、舰船主数据中的立绘版本和项目现有裁切方式。

只有同时满足以下条件时才显示立绘区域：

- 设置开关已开启；
- 当前为完整模式；
- 能找到对应的 `MasterShip`；
- `ShipPortraitUriBuilder` 能生成有效 URI。

如果任一条件不满足，则该行退回当前纯文字布局。网络图片加载失败时也保持舰名可见，不让图片错误影响战前预测。

### POI 敌舰资源规则修订

敌舰不能复用舰娘的 `ship/remodel` 资源。按照 poi 的实现，master ID 不小于 1500 的敌舰使用 `ship/banner`，资源密钥种子为 `ship_banner`，横向裁切系数为 1.5。现有胶囊尺寸保持不变：单舰队 56 × 34 dp，联合舰队 48 × 30 dp；图片在胶囊内按高度缩放和裁切，舰名继续占据剩余空间。舰娘现有 `ship/remodel` 逻辑不变。

## 设置持久化

扩展 `BattlePredictionSettingsStore` 和 `BattlePredictionSettingsController`，增加 `enemyPortraitsEnabled` 布尔值：

- SharedPreferences 键：`battle.enemyPreviewPortraitsEnabled`；
- 未保存时默认为 `true`；
- 保存成功后更新 Controller 并通知监听者；
- 内存 Store 同样支持默认值和读写，供测试使用。

主信息面板监听 `BattlePredictionSettingsController`。构建 `LiveBattleCard` 时传入当前开关值，保证设置切换后即时刷新。

## 组件边界

- `BattleController`：保留敌舰 master ID 和名称，不处理图片。
- `LiveBattle`：保存不可变的战前敌舰预览数据。
- `OfficialEnemyPreview`：负责单列、联合舰队双栏及可选立绘布局。
- `DetailedBattlePanel`：传入开启立绘的条件和 `GameState`。
- `_CompactBattlePanel`：只传入预览文字，不启用立绘。
- `BattlePredictionSettingsController`：负责开关默认值、持久化和通知。

## 本地化

新增 2 个本地化键：

- `battleEnemyPreviewPortraits`：战前敌方立绘；
- `battleEnemyPreviewPortraitsDesc`：仅在未卜先知完整模式显示。

繁体中文和日文提供对应自然文案，不在 Widget 中硬编码设置文字。

## 测试

- 设置 Store 在没有保存值时默认开启。
- Controller 能持久化开关并通知监听者。
- 战斗设置显示开关，且点击后保存关闭状态。
- `BattleController` 保留敌舰 master ID、舰名、数量限制和联合舰队顺序。
- 完整模式开启时显示敌方立绘。
- 完整模式关闭时保持纯文字。
- 简洁模式在开关开启时仍不显示立绘。
- 缺少主数据或有效立绘 URI 时退回纯文字。
- 普通舰队和联合舰队布局没有溢出。
- 三语本地化资源审计通过。

## 非目标

- 不在实际战斗阶段的敌方 HP 列表中增加立绘。
- 不改变简洁模式布局。
- 不新增图片下载服务或独立磁盘缓存。
- 不改变战斗预测算法和敌舰顺序。
- 不修改我方舰队立绘样式。
