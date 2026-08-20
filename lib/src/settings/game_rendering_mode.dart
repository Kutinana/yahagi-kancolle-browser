enum GameRenderingMode {
  standard,
  compatibility,
  canvasCompatibility,
  nativeActivityExperimental;

  bool get usesActivityWebView => this == nativeActivityExperimental;

  bool get usesPlatformView => !usesActivityWebView;

  bool get usesHybridComposition =>
      this == compatibility || this == canvasCompatibility;

  bool get usesCanvasRenderer => this == canvasCompatibility;

  bool get enablesToolbarBlur => false;

  String get storageName => name;
}

abstract final class GameRenderingModeCodec {
  static GameRenderingMode decode(String? value) {
    for (final mode in GameRenderingMode.values) {
      if (mode.storageName == value) return mode;
    }
    return GameRenderingMode.nativeActivityExperimental;
  }
}
