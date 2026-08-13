import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../layout/adaptive_layout.dart';
import 'display_mode_store.dart';

const _phoneOrientations = <DeviceOrientation>[
  DeviceOrientation.landscapeLeft,
  DeviceOrientation.landscapeRight,
];

const _portraitOrientations = <DeviceOrientation>[
  DeviceOrientation.portraitUp,
  DeviceOrientation.portraitDown,
];

const _sensorOrientations = <DeviceOrientation>[
  DeviceOrientation.portraitUp,
  DeviceOrientation.landscapeLeft,
  DeviceOrientation.portraitDown,
  DeviceOrientation.landscapeRight,
];

DisplayMode _lastMode = DisplayMode.auto;
List<DeviceOrientation> _lastOrientations = const <DeviceOrientation>[];

/// 自动模式：普通手机/折叠屏外屏锁定横屏轴；
/// 近似方形的展开折叠屏与普通宽屏平板跟随系统旋转。
/// 方形屏的工作区仍由自适应布局保持为上下结构。
List<DeviceOrientation> preferredOrientationsFor(Size size, DisplayMode mode) {
  switch (mode) {
    case DisplayMode.landscape:
      return _phoneOrientations;
    case DisplayMode.portrait:
      return _portraitOrientations;
    case DisplayMode.auto:
      return switch (classifyAdaptiveWindow(size)) {
        AdaptiveWindowClass.compact => _phoneOrientations,
        AdaptiveWindowClass.nearSquareLarge => _sensorOrientations,
        AdaptiveWindowClass.wideLarge => _sensorOrientations,
      };
  }
}

/// 自动模式按窗口类别选择方向轴；手动模式覆盖自动判断。
void applyOrientationPolicy(Size size, [DisplayMode mode = DisplayMode.auto]) {
  final orientations = preferredOrientationsFor(size, mode);
  if (mode == _lastMode && _sameOrientations(orientations, _lastOrientations)) {
    return;
  }
  _lastMode = mode;
  _lastOrientations = List<DeviceOrientation>.of(orientations);
  SystemChrome.setPreferredOrientations(orientations).catchError((Object _) {});
}

bool _sameOrientations(List<DeviceOrientation> a, List<DeviceOrientation> b) {
  if (a.length != b.length) {
    return false;
  }
  for (var index = 0; index < a.length; index++) {
    if (a[index] != b[index]) {
      return false;
    }
  }
  return true;
}

Size currentWindowSize() {
  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  return view.physicalSize / view.devicePixelRatio;
}
