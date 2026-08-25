# 原生模式弹窗快照桥接设计

## 背景

原生渲染模式把游戏 WebView 作为 `android.R.id.content` 的最后一个原生子 View 挂载。它能稳定呈现 WebGL，但原生 View 的层级高于 Flutter 画布。弹窗期间继续显示 WebView 会让游戏盖住 Flutter 弹窗；直接隐藏 WebView 则会在半透明遮罩后露出暗色空槽。

## 目标

打开制空、索敌、远征选择等 Flutter 弹窗时，保持弹窗位于最上层，并在遮罩后显示打开瞬间的静态游戏画面。关闭弹窗后恢复可交互的原生 WebView。

## 方案

新增仅供合成过渡使用的内存快照通道。`YahagiGameRouteObserver` 在推送会遮挡游戏的 `PopupRoute` 时，向 `NativeGameSurfaceSlot` 暴露当前路由类型。Surface Slot 在发送隐藏请求前等待快照准备完成；`NativeActivityGameSurface` 通过 Android `PixelCopy`/WebView draw 现有回退链获取 PNG 字节，预解码后在 Flutter 游戏槽中显示。下一帧到达后隐藏原生 WebView。

弹窗关闭时先恢复原生 WebView，再移除 Flutter 快照。全屏 `PageRoute`、工作区切换和应用生命周期隐藏不生成快照，继续沿用立即隐藏逻辑。

## 组件边界

- `native_game_surface_slot.dart`：识别 PopupRoute，编排“准备快照—隐藏”和“恢复—清理快照”的顺序，并用代次取消快速开关产生的陈旧操作。
- `native_game_surface_preview.dart`：定义内存 PNG 快照端口及 MethodChannel 实现。
- `native_activity_game_surface.dart`：捕获、预解码、显示和释放 Flutter 快照层。
- `MainActivity.kt`：复用现有截图捕获回退链，增加返回 PNG 字节的预览目的地；不得写入相册。

## 失败与竞态

- 捕获失败或返回无效数据：记录诊断信息并继续隐藏 WebView，视觉退化为当前暗色背景。
- 弹窗在捕获完成前关闭：代次作废旧捕获，不再隐藏已恢复的 WebView，也不保留陈旧快照。
- 多层弹窗：工作区只在第一层 PopupRoute 覆盖时生成一次快照，在最后一层退出后恢复。
- 页面切换和退后台：不等待截图，避免原生 View 短暂盖住新页面或拖延生命周期处理。

## 验证

- Widget 测试验证 PopupRoute 隐藏前等待快照、关闭时恢复后清理、快速关闭会取消陈旧隐藏。
- MethodChannel 测试验证预览方法返回 `Uint8List` 且使用独立方法名。
- 现有测试继续验证全屏页面隐藏、普通菜单不隐藏、弹窗最终隐藏。
- Android 单元测试验证截图目的地选择不触发相册写入；Debug 构建验证 Kotlin/Flutter 通道类型可编译。

