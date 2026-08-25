# 原生模式弹窗快照桥接实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在原生游戏 WebView 隐藏期间用 Flutter 内存快照保留弹窗后的游戏画面，并确保弹窗始终位于顶层。

**架构：** 路由层只对 PopupRoute 请求快照；Flutter Surface 在快照已解码并绘制后隐藏原生 View；Android 复用现有 PixelCopy 回退链返回内存 PNG。失败时继续隐藏而不阻塞 UI。

**技术栈：** Flutter/Dart、Android Kotlin、MethodChannel、PixelCopy、Widget Test、JUnit/Gradle

---

## 文件结构

- 创建 `lib/src/browser/native_game_surface_preview.dart`：内存快照端口和 MethodChannel 协议。
- 修改 `lib/src/browser/native_game_surface_slot.dart`：PopupRoute 覆盖时序及竞态代次。
- 修改 `lib/src/native_activity_game_surface.dart`：快照捕获、预解码与 Flutter 快照层。
- 修改 `android/app/src/main/kotlin/app/yahagi/kancollebrowser/MainActivity.kt`：返回内存 PNG 的截图目的地。
- 修改 `test/native_game_surface_slot_test.dart`：路由时序和快速关闭回归测试。
- 修改 `test/native_activity_game_surface_test.dart`：快照层集成测试。
- 创建 `test/native_game_surface_preview_test.dart`：MethodChannel 协议测试。

### 任务 1：路由挂起时序

- [ ] **步骤 1：编写失败测试**

在 `test/native_game_surface_slot_test.dart` 增加 PopupRoute 测试：`onBeforePopupRouteHidden` 的 Future 未完成时可见性保持 `[true]`；完成后变为 `[true, false]`；关闭后变为 `[true, false, true]` 并调用清理回调。

- [ ] **步骤 2：运行红灯测试**

运行：

```powershell
flutter test test/native_game_surface_slot_test.dart --plain-name "waits for a popup snapshot before hiding and restores before cleanup"
```

预期：FAIL，`NativeGameSurfaceSlot` 尚无快照回调参数。

- [ ] **步骤 3：最小实现**

给 `YahagiGameRouteObserver` 增加同步的当前推送路由标记；给 `NativeGameSurfaceSlot` 增加准备、取消和清理回调。使用整数代次保证弹窗快速关闭后不提交陈旧隐藏。

- [ ] **步骤 4：验证绿灯及路由回归**

```powershell
flutter test test/native_game_surface_slot_test.dart
```

预期：全部通过。

### 任务 2：内存预览通道

- [ ] **步骤 1：编写失败测试**

创建 `test/native_game_surface_preview_test.dart`，模拟 MethodChannel 返回 `Uint8List.fromList(<int>[137, 80, 78, 71])`，断言调用方法为 `captureWebViewPreview` 且端口原样返回字节；空数据必须抛出 `StateError`。

- [ ] **步骤 2：运行红灯测试**

```powershell
flutter test test/native_game_surface_preview_test.dart
```

预期：FAIL，目标库和类型尚不存在。

- [ ] **步骤 3：最小实现**

创建 `NativeGameSurfacePreviewPort` 与 `MethodChannelNativeGameSurfacePreviewPort`，通道沿用 `app.yahagi.kancollebrowser/game_screenshot`，但调用独立方法 `captureWebViewPreview`。

- [ ] **步骤 4：验证绿灯**

```powershell
flutter test test/native_game_surface_preview_test.dart
```

预期：全部通过。

### 任务 3：Flutter 快照层

- [ ] **步骤 1：编写失败集成测试**

在 `test/native_activity_game_surface_test.dart` 注入返回一张 1×1 PNG 的假预览端口，推送 RawDialogRoute，断言隐藏前出现键 `native-game-surface-popup-preview`；弹窗退出且原生端收到 `visible:true` 后该键消失。

- [ ] **步骤 2：运行红灯测试**

```powershell
flutter test test/native_activity_game_surface_test.dart --plain-name "shows a decoded popup preview while the native surface is hidden"
```

预期：FAIL，Surface 尚未接受预览端口或绘制快照。

- [ ] **步骤 3：最小实现**

在 `NativeActivityGameSurface` 注入可选预览端口。捕获字节后用 `MemoryImage` 和 `precacheImage` 预解码，绘制一帧后允许隐藏；恢复时先显示原生 View，再清理 provider。捕获异常仅打印诊断信息。

- [ ] **步骤 4：验证绿灯**

```powershell
flutter test test/native_activity_game_surface_test.dart
```

预期：全部通过。

### 任务 4：Android 内存 PNG 输出

- [ ] **步骤 1：增加可测试的目的地策略**

为截图请求定义 `GALLERY` 与 `MEMORY_PREVIEW` 目的地。现有 `captureWebView` 使用前者，新方法 `captureWebViewPreview` 使用后者；只有前者执行权限检查和 MediaStore 写入。

- [ ] **步骤 2：实现字节返回**

在 `finishScreenshot` 中根据目的地选择：相册路径维持现状；内存预览用 `ByteArrayOutputStream` 编码 PNG 并 `result.success(bytes)`，随后统一回收 Bitmap 和清理单飞状态。

- [ ] **步骤 3：运行 Android 测试与编译**

```powershell
./gradlew.bat :app:testDebugUnitTest
flutter build apk --debug
```

预期：JUnit 通过，Debug APK 构建成功。

### 任务 5：综合验证

- [ ] **步骤 1：格式化和静态分析**

```powershell
dart format lib/src/browser/native_game_surface_preview.dart lib/src/browser/native_game_surface_slot.dart lib/src/native_activity_game_surface.dart test/native_game_surface_preview_test.dart test/native_game_surface_slot_test.dart test/native_activity_game_surface_test.dart
flutter analyze lib/src/browser/native_game_surface_preview.dart lib/src/browser/native_game_surface_slot.dart lib/src/native_activity_game_surface.dart test/native_game_surface_preview_test.dart test/native_game_surface_slot_test.dart test/native_activity_game_surface_test.dart
```

预期：无问题。

- [ ] **步骤 2：相关 Flutter 回归**

```powershell
flutter test test/native_game_surface_preview_test.dart test/native_game_surface_slot_test.dart test/native_activity_game_surface_test.dart test/fleet_air_power_details_test.dart test/fleet_summary_card_test.dart test/expedition_mission_picker_test.dart
```

预期：全部通过。

- [ ] **步骤 3：检查工作区与产物**

```powershell
git diff --check
git status --short
```

预期：仅出现本计划列出的源文件、测试和文档；Debug APK 位于 `build/app/outputs/flutter-apk/app-debug.apk`。

