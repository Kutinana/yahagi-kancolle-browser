import 'package:flutter/foundation.dart';

enum GameSurfaceStage { localPrototype, login, game }

final class GameToolbarController extends ChangeNotifier {
  GameToolbarController({bool initiallyVisible = false})
    : _isVisible = initiallyVisible;

  GameSurfaceStage _stage = GameSurfaceStage.localPrototype;
  bool _isVisible;

  GameSurfaceStage get stage => _stage;
  bool get isVisible => _isVisible;

  void onStageChanged(GameSurfaceStage stage) {
    if (_stage == stage) {
      return;
    }
    _stage = stage;
    notifyListeners();
  }

  void toggle() {
    if (_isVisible) {
      collapse();
    } else {
      reveal();
    }
  }

  void reveal() {
    _setVisible(true);
  }

  void collapse() {
    _setVisible(false);
  }

  void _setVisible(bool visible) {
    if (_isVisible == visible) {
      return;
    }
    _isVisible = visible;
    notifyListeners();
  }
}
